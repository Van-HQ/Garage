# Garage
Vehicle maintenance tracker for my 2024 Toyota Tacoma TRD Sport and RAV4 XLE.

## Stack
- Web app: Next.js 16 + Supabase (SSR auth) + Vercel. Repo: Van-HQ/Garage.
- Native iOS app planned in `ios/` (see `ios/CLAUDE.md`).
- Every table has RLS by `user_id`. New tables need an owner policy in a migration under `supabase/`.
- The repo's schema has no explicit GRANT statements. Check table grants in the Supabase dashboard after creating a table. Don't assume.
- Next.js 16 has breaking changes. Read `AGENTS.md` and the bundled docs before writing web code.

## Features
- Digital owner's manuals, mileage-based maintenance schedule, monthly mileage tracker.

## Planned: native iOS
- Native Swift app with live OBD over Bluetooth LE (OBDLink CX, vLinker MC+ or Veepeak BLE). No WiFi adapters.
- CarPlay needs Apple's entitlement and the paid developer program. Build the phone gauges first.
- Reuse the existing vehicle and maintenance tables. Trip distance writes to `mileage_logs`.

## Note
Verified against the repo on 2026-11-15: table names, RLS, and storage paths match `supabase/schema.sql`. The earlier GRANT line was removed because the repo doesn't show it; confirm in Supabase before relying on it.

@AGENTS.md
