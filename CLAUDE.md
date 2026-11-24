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

## Tweaks and design
- Tweak list: Claude Doc "Garage Tweaks" (https://claude.ai/artifact/H7KC76c17EGpK8D5WgPNX6). Never recreate it.
- Design canvas: "Garage Design" (https://claude.ai/artifact/3ZJBxuALy947Q1bvTKBu7W). Put UI mockups and other design work there, not in repo files.
- Add each requested change under its area heading as `[ ]` open.
- When you build something, mark it `[~]` with bold "Pending Test & Approval" and a yellow inline note (what was built, the commit, what is untested). Only I mark things done: once I say an item passed, delete its line and note. Never leave `[x]`.
- `[?]` is for decisions: mock options in Garage Design first and wait for my pick.
- Re-read the doc before every edit. Don't reword my items. Update the "Last updated · Tokens used · Check" line each edit.
- Full rules live in memory (garage-tweaks-doc-rules).
- If the Claude Docs or artifact tools aren't available in this session, say so. Don't guess at the doc's contents.

@AGENTS.md
