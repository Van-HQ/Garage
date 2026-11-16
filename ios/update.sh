#!/bin/bash
# Garage iOS: get the latest code and open it in Xcode, ready for ⌘R.
set -euo pipefail
cd "$(dirname "$0")"
source ./scripts-common.sh

echo "→ Getting the latest code"
git pull --ff-only

ensure_xcodegen
ensure_local_config
generate_and_open
