# Garage iOS (native Swift)

Native SwiftUI port of the Garage web app (Next.js in the repo root). Personal use only, never published to the App Store. Lives in `ios/` inside Van-HQ/Garage.

## Stack
- SwiftUI, one phone target, XcodeGen (`ios/project.yml`). Copy the Forge iOS setup pattern (`setup.sh`, `update.sh`, `README.md`).
- Supabase Swift SDK against the existing Supabase project. Reuse the existing tables, auth, and storage buckets. Do not redesign the backend.
- OBD over CoreBluetooth (BLE only). No WiFi adapters. Candidate dongles: OBDLink CX, Vgate vLinker MC+, Veepeak OBDCheck BLE. Confirm Toyota compatibility before buying.
- CarPlay scene uses CarPlay template classes only. No custom drawing there.

## Existing backend (do not change without asking)
- Tables with per-user RLS (`auth.uid() = user_id`): `vehicles`, `maintenance_types`, `maintenance_logs`, `mileage_logs`, `maintenance_photos`.
- Storage: bucket `manuals` at `<user_id>/<vehicle_id>.pdf`; bucket `maintenance-photos` at `<user_id>/<maintenance_log_id>/<random>.jpg`. Both restricted to the caller's own user_id folder.
- Mileage: `mileage_logs` inserts fire triggers that recompute each vehicle's current mileage. Write trip distance as `mileage_logs` rows. Never set vehicle mileage directly from the app.
- Source of truth for behavior: `src/lib/` in the web repo (`maintenance-status.ts`, `mileage-trend.ts`, `cost.ts`, `useGarageData.ts`) and `src/lib/types.ts`.

## New tables (OBD feature)
- `obd_readings` (vehicle_id, timestamp, pid, value), `trips` (vehicle_id, start/end time, distance, summary stats), `dtc_events` (vehicle_id, code, first_seen, cleared_at).
- Every new table needs: `user_id uuid references auth.users`, RLS enabled, and an owner policy matching the existing ones. Add the migration to `supabase/` in the repo, not only in the dashboard.
- Check the table's access grants in the Supabase dashboard after creating it. The repo's schema has no explicit GRANT statements, so don't assume they're needed or unneeded. Verify first.
- Sample PIDs at a set rate and batch inserts. Do not write every PID at 1 Hz.

## Rules
- Never commit Supabase keys. Keep the URL and publishable key in a local config file that is gitignored (for example `ios/Garage/Config.local.xcconfig`). Ship a `.example` file with placeholder values.
- The app holds only the publishable key. No service-role key in the app, ever.
- Free Apple ID builds expire every 7 days. Use the paid developer account for this app.
- Build the phone app against a simulated OBD source first (`OBDDataSource` protocol with a simulator and a BLE implementation). CarPlay is a bonus after the phone app works.
- CarPlay entitlement approval is uncertain. Don't block other work on it.
- Odometer: OBD often lacks it. Fall back to GPS distance and let the user enter odometer manually in the existing maintenance flow.

## Workflow
- Small changes: make them directly. Large changes: show a plan or diff first. Architectural decisions: decide independently and say what you chose.
- Debugging: give two or three options before picking one.
- Commit often in small commits. Prefer solid foundations over quick prototypes.
- After each task, explain what changed and why.
- After pushing iOS updates, end the reply with `~/Desktop/Garage/ios/update.sh` and a reminder to press ⌘R.
