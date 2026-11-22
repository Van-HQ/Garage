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
- After pushing iOS updates, end the reply with `~/Desktop/Projects/Garage/ios/update.sh` and a reminder to press ⌘R.

## CarPlay

- Code: `Garage/CarPlay/CarPlaySceneDelegate.swift` (Care list + live Drive tabs), routed by `Garage/App/AppDelegate.swift`. The scene manifest is in `project.yml`.
- Simulator builds pick up `Garage/Garage.entitlements` automatically. Test with the Simulator's I/O > External Displays > CarPlay.
- Device builds do not use the entitlement until the matching profile exists. Once Apple's approved category is on the App ID and a profile is generated, add `CODE_SIGN_ENTITLEMENTS = Garage/Garage.entitlements` to `Config/Config.local.xcconfig`. The key in the entitlements file must match the approved category, or signing fails.
- Tabs: Care, Drive, Codes. `OBDSession` asks the connected car for trouble codes every 60 s and keeps `alerts` (hot coolant at 110 °C / 230 °F, or a trouble code the car reports). The rules live in `GarageCore/OBD/DriveAlerts.swift`. CarPlay shows each alert once as a full-screen `CPAlertTemplate`; an alert can fire again after its cause clears.

## GPS distance fallback

- `Garage/Data/LocationSpeedSource.swift` supplies GPS speed while an OBD connection is up. `TripController` uses it only when the car hasn't reported speed for 5 s, so the two sources never double-count. A trip's `distance_source` is `obd`, `gps` or `mixed`.
- Needs the "location" background mode (in `project.yml`) so GPS keeps running with the phone locked.

## CarPlay pop-ups

- Tabs: Care (open check-engine codes first), Drive, Codes. Everything that wants a full-screen pop-up goes through one queue in `CarPlaySceneDelegate` (drive alerts, last trip summary, newly overdue maintenance), so they never collide.
- The trip summary is saved when a trip ends (`CarPlayMemory`) and shown once, if under 12 h old. A drive normally ends after CarPlay disconnects, so it usually appears on the next connection.
- Maintenance pop-ups fire on the change to overdue, not on every connect. The first run only records a baseline.
- Open codes: every code read is reconciled into `dtc_events` (new codes added, codes the car no longer reports cleared), so Care and CarPlay show them without the adapter.

