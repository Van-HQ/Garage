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
  created_at timestamptz not null default now()
);

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
create or replace function bump_vehicle_mileage_from_mileage_log()
returns trigger as $$
begin
  update vehicles
    set current_mileage = greatest(current_mileage, new.mileage),
        mileage_updated_at = new.recorded_at
    where id = new.vehicle_id and new.mileage >= current_mileage;
  return new;
end;
$$ language plpgsql security definer;

create or replace function bump_vehicle_mileage_from_maintenance_log()
returns trigger as $$
begin
  update vehicles
    set current_mileage = greatest(current_mileage, new.mileage_at),
        mileage_updated_at = new.performed_at
    where id = new.vehicle_id and new.mileage_at >= current_mileage;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_bump_vehicle_mileage on mileage_logs;
create trigger trg_bump_vehicle_mileage
  after insert on mileage_logs
  for each row execute function bump_vehicle_mileage_from_mileage_log();

drop trigger if exists trg_bump_vehicle_mileage_maint on maintenance_logs;
create trigger trg_bump_vehicle_mileage_maint
  after insert on maintenance_logs
  for each row execute function bump_vehicle_mileage_from_maintenance_log();

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
