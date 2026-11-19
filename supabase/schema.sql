-- Garage Glass schema
-- Run this in the Supabase SQL editor (Project > SQL Editor > New query)

create extension if not exists "pgcrypto";

-- ============ VEHICLES ============
create table if not exists vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,                 -- e.g. "Tacoma"
  make text not null default '',
  model text not null default '',
  year int not null,
  color text,                         -- hex accent color for the card
  icon text default 'truck',          -- lucide icon key: 'truck' | 'car'
  current_mileage int not null default 0,
  mileage_updated_at timestamptz not null default now(),
  avg_daily_miles numeric not null default 25,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table vehicles enable row level security;

create policy "vehicles are owned by user" on vehicles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ MAINTENANCE TYPES (custom, per-vehicle or global to the user) ============
create table if not exists maintenance_types (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid references vehicles(id) on delete cascade, -- null = applies to all of the user's vehicles
  name text not null,                 -- e.g. "Oil Change"
  category text not null default 'custom', -- 'oil'|'tires'|'wash'|'upgrade'|'inspection'|'custom'
  icon text default 'wrench',
  interval_miles int,                 -- null = not mileage based
  interval_days int,                  -- null = not time based
  baseline_mileage int,               -- manually-set "starts counting from" point, used when no log exists yet
  baseline_date timestamptz,          -- e.g. battery check dated to purchase instead of today
  created_at timestamptz not null default now()
);

-- Safe to run standalone against a table created before these columns existed.
alter table maintenance_types add column if not exists baseline_mileage int;
alter table maintenance_types add column if not exists baseline_date timestamptz;

alter table maintenance_types enable row level security;

create policy "maintenance_types are owned by user" on maintenance_types
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ MAINTENANCE LOGS (actual events performed) ============
create table if not exists maintenance_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  maintenance_type_id uuid references maintenance_types(id) on delete set null,
  title text not null,                -- freeform label, defaults to type name
  notes text default '',
  cost numeric,
  mileage_at int not null,
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table maintenance_logs enable row level security;

create policy "maintenance_logs are owned by user" on maintenance_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ MILEAGE LOGS (odometer check-ins, independent of maintenance) ============
create table if not exists mileage_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  mileage int not null,
  note text default '',
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table mileage_logs enable row level security;

create policy "mileage_logs are owned by user" on mileage_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Keep vehicles.current_mileage in sync whenever a higher mileage is logged.
-- mileage_logs and maintenance_logs use different column names (mileage vs
-- mileage_at, recorded_at vs performed_at), so each needs its own function —
-- a single shared function referencing the wrong column name on either table
-- throws "record new has no field ..." and silently rolls back the insert.
-- The vehicle's odometer is always derived from its newest log (by date), so
-- editing or deleting a bad entry corrects it. (The old version only ever
-- ratcheted upward with greatest(), so one typo'd mileage stuck forever.)
-- If a vehicle has no logs at all, its manually-entered mileage is left alone.
create or replace function recompute_vehicle_mileage(vid uuid)
returns void as $$
declare
  latest record;
begin
  select mileage, at into latest from (
    select mileage_at as mileage, performed_at as at from maintenance_logs where vehicle_id = vid
    union all
    select mileage, recorded_at as at from mileage_logs where vehicle_id = vid
  ) readings
  order by at desc, mileage desc
  limit 1;

  if found then
    update vehicles set current_mileage = latest.mileage, mileage_updated_at = latest.at where id = vid;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function trg_recompute_vehicle_mileage()
returns trigger as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform recompute_vehicle_mileage(old.vehicle_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform recompute_vehicle_mileage(new.vehicle_id);
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_bump_vehicle_mileage on mileage_logs;
drop trigger if exists trg_bump_vehicle_mileage_maint on maintenance_logs;
drop trigger if exists trg_recompute_mileage_from_mileage_logs on mileage_logs;
drop trigger if exists trg_recompute_mileage_from_maintenance_logs on maintenance_logs;

create trigger trg_recompute_mileage_from_mileage_logs
  after insert or update or delete on mileage_logs
  for each row execute function trg_recompute_vehicle_mileage();

create trigger trg_recompute_mileage_from_maintenance_logs
  after insert or update or delete on maintenance_logs
  for each row execute function trg_recompute_vehicle_mileage();

drop function if exists bump_vehicle_mileage_from_mileage_log();
drop function if exists bump_vehicle_mileage_from_maintenance_log();
drop function if exists bump_vehicle_mileage();

create index if not exists idx_maintenance_logs_vehicle on maintenance_logs(vehicle_id, performed_at desc);
create index if not exists idx_mileage_logs_vehicle on mileage_logs(vehicle_id, recorded_at desc);
create index if not exists idx_maintenance_types_vehicle on maintenance_types(vehicle_id);

-- ============ OWNER'S MANUAL (one PDF per vehicle, stored in Storage) ============
-- Safe to run standalone even if the tables above already exist.

alter table vehicles add column if not exists manual_uploaded_at timestamptz;

insert into storage.buckets (id, name, public)
values ('manuals', 'manuals', false)
on conflict (id) do nothing;

-- Files live at "<user_id>/<vehicle_id>.pdf" — these policies restrict
-- every operation to files inside the caller's own user_id folder.
drop policy if exists "manuals: users manage own files" on storage.objects;
create policy "manuals: users manage own files" on storage.objects
  for all
  using (bucket_id = 'manuals' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'manuals' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============ MAINTENANCE PHOTOS (receipts, before/after shots per log entry) ============
-- Safe to run standalone even if the tables above already exist.

create table if not exists maintenance_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  maintenance_log_id uuid not null references maintenance_logs(id) on delete cascade,
  storage_path text not null,
  created_at timestamptz not null default now()
);

alter table maintenance_photos enable row level security;

drop policy if exists "maintenance_photos are owned by user" on maintenance_photos;
create policy "maintenance_photos are owned by user" on maintenance_photos
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_maintenance_photos_log on maintenance_photos(maintenance_log_id);

insert into storage.buckets (id, name, public)
values ('maintenance-photos', 'maintenance-photos', false)
on conflict (id) do nothing;

-- Files live at "<user_id>/<maintenance_log_id>/<random>.jpg" — same
-- per-user-folder restriction as the manuals bucket above.
drop policy if exists "maintenance-photos: users manage own files" on storage.objects;
create policy "maintenance-photos: users manage own files" on storage.objects
  for all
  using (bucket_id = 'maintenance-photos' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'maintenance-photos' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============ OBD: TRIPS, READINGS, TROUBLE CODES (iOS app) ============
-- Safe to run standalone even if the tables above already exist.
-- The iOS app records drives from an OBD adapter. A trip's distance is also
-- written as a mileage_logs row by the app, so the odometer trigger above keeps
-- vehicles.current_mileage in sync; nothing here touches vehicles directly.
--
-- This file has no explicit GRANT statements (same as the rest of the schema).
-- After running it, check the new tables' grants in the Supabase dashboard
-- (Table Editor > the table > Policies/Privileges) or with:
--   select table_name, grantee, privilege_type
--   from information_schema.role_table_grants
--   where table_schema = 'public' and table_name in ('trips', 'obd_readings', 'dtc_events')
--   order by 1, 2, 3;
-- and confirm `authenticated` can select, insert, update and delete.

create table if not exists trips (
  id uuid primary key default gen_random_uuid(), -- the app supplies this, so a retried upload can't create a duplicate
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  distance_miles numeric not null default 0,
  avg_speed_mph numeric,                          -- distance over time spent moving
  max_speed_mph numeric,
  max_rpm numeric,
  max_coolant_c numeric,
  fuel_used_pct numeric,                          -- fuel level drop, in points of a full tank; null if unknown
  distance_source text not null default 'obd',    -- 'obd' (integrated vehicle speed) | 'gps'
  created_at timestamptz not null default now(),
  constraint trips_end_after_start check (ended_at >= started_at)
);

alter table trips enable row level security;

drop policy if exists "trips are owned by user" on trips;
create policy "trips are owned by user" on trips
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_trips_vehicle on trips(vehicle_id, started_at desc);

-- Sampled values from a trip, not every reading the gauges show: one sample of
-- each value every ~15 s while driving (a few thousand rows per hour at most).
create table if not exists obd_readings (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  trip_id uuid references trips(id) on delete cascade,
  recorded_at timestamptz not null,
  pid smallint not null,                          -- OBD-II service 01 PID, e.g. 12 = 0x0C engine RPM
  value double precision not null                 -- in the PID's standard unit (km/h, °C, %, rpm, V)
);

alter table obd_readings enable row level security;

drop policy if exists "obd_readings are owned by user" on obd_readings;
create policy "obd_readings are owned by user" on obd_readings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_obd_readings_trip on obd_readings(trip_id, recorded_at);
create index if not exists idx_obd_readings_vehicle on obd_readings(vehicle_id, recorded_at desc);
-- Lets the app re-send a batch after a dropped connection without duplicating rows.
create unique index if not exists idx_obd_readings_dedupe on obd_readings(trip_id, recorded_at, pid);

create table if not exists dtc_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  code text not null,                             -- e.g. 'P0456'
  first_seen timestamptz not null default now(),
  cleared_at timestamptz
);

alter table dtc_events enable row level security;

drop policy if exists "dtc_events are owned by user" on dtc_events;
create policy "dtc_events are owned by user" on dtc_events
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- At most one open (not yet cleared) event per code per vehicle. A code that
-- comes back after being cleared gets a new row.
create unique index if not exists idx_dtc_events_open on dtc_events(vehicle_id, code) where cleared_at is null;
create index if not exists idx_dtc_events_vehicle on dtc_events(vehicle_id, first_seen desc);
