#!/bin/bash
# Garage iOS: first-time setup on a Mac. Creates your local config, generates
# the Xcode project and opens it. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")"
source ./scripts-common.sh

ensure_xcodegen
ensure_local_config
generate_and_open
