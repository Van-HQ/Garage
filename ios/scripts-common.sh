# Shared by setup.sh and update.sh. Not meant to be run on its own.

# XcodeGen turns project.yml into Garage.xcodeproj. No Homebrew needed: if it
# isn't installed, download the official build into ~/.garage-tools (one time).
ensure_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then return; fi
  local tools="$HOME/.garage-tools"
  if [ ! -x "$tools/xcodegen/bin/xcodegen" ]; then
    echo "→ Downloading XcodeGen (one time)"
    mkdir -p "$tools"
    curl -fsSL -o "$tools/xcodegen.zip" https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    unzip -q -o "$tools/xcodegen.zip" -d "$tools"
    rm -f "$tools/xcodegen.zip"
  fi
  export PATH="$tools/xcodegen/bin:$PATH"
}

# Config/Config.local.xcconfig holds the Supabase host, the publishable key and
# your signing team. It is never committed. Values are read from the web app's
# .env.local when it exists, so there is nothing to type on this Mac.
ensure_local_config() {
  local cfg="Config/Config.local.xcconfig"
  if [ -f "$cfg" ]; then return; fi

  local host="" key="" team=""
  if [ -f ../.env.local ]; then
    host=$(sed -n 's|^NEXT_PUBLIC_SUPABASE_URL=https://||p' ../.env.local | tr -d '"/\r' | head -1)
    key=$(sed -n 's|^NEXT_PUBLIC_SUPABASE_ANON_KEY=||p' ../.env.local | tr -d '"\r' | head -1)
  fi
  if [ -z "$host" ]; then
    read -r -p "Supabase project host (like abcd1234.supabase.co): " host || true
  fi
  if [ -z "$key" ]; then
    read -r -p "Supabase publishable (anon) key: " key || true
  fi

  # The Team ID is the "OU" on the Apple Development certificate Xcode already made.
  team=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)

  {
    echo "// Created by setup.sh. Your own settings; never committed."
    echo "SUPABASE_HOST = $host"
    echo "SUPABASE_PUBLISHABLE_KEY = $key"
    if [ -n "$team" ]; then echo "DEVELOPMENT_TEAM = $team"; fi
  } > "$cfg"
  echo "→ Wrote $cfg"
  if [ -n "$team" ]; then
    echo "→ Using Team ID $team (change DEVELOPMENT_TEAM in $cfg to use a different team)"
  else
    echo "→ No Team ID found. Pick your team in Xcode under Signing & Capabilities."
  fi
}

generate_and_open() {
  echo "→ Generating Garage.xcodeproj"
  xcodegen generate --quiet
  echo "→ Opening Xcode. Pick your iPhone at the top, then press ⌘R."
  open Garage.xcodeproj
}
