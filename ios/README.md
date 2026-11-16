# Garage for iPhone

Native SwiftUI app. Same Supabase project, account and data as the web app.
Personal use only; installed straight from Xcode.

## First install (Mac + iPhone)

1. Run `./setup.sh` in this folder. It creates `Config/Config.local.xcconfig`
   (Supabase host, publishable key and your signing team), generates
   `Garage.xcodeproj` and opens it. The Supabase values are copied from the
   web app's `.env.local` when that file exists.
2. Plug in the iPhone, pick it at the top of the Xcode window, press ⌘R.
3. First time only, on the phone: Settings › Privacy & Security › Developer Mode › on.

Use the paid developer team for signing. A free Apple ID's install stops
working after 7 days.

## Updating

Run `./update.sh`, then press ⌘R in Xcode.

## Layout

- `project.yml`: the XcodeGen recipe. The Xcode project is generated from it
  and is not committed, so new files are picked up by re-running `./update.sh`.
- `Garage/`: the app (SwiftUI).
- `Packages/GarageCore/`: pure Swift models and logic ported from the web
  app's `src/lib`. Run its tests with `swift test` inside that folder.
- `Config/`: build settings. `Config.local.xcconfig` is never committed.

## Demo mode

Launch with the `-demo` argument (Xcode › Product › Scheme › Edit Scheme ›
Arguments) to run on built-in sample data with no sign-in. Debug builds only.

## Secrets

Only the Supabase publishable (anon) key belongs in this app, and only in
`Config/Config.local.xcconfig`. Never add the service-role key.
