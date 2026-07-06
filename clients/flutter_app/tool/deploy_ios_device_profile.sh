#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVICE_ID="${1:-${KOLKHOZ_IOS_DEVICE_ID:-00008110-000C515934E3A01E}}"
FLUTTER="${FLUTTER:-/opt/homebrew/bin/flutter}"

cd "$APP_DIR"

echo "Deploying Kolkhoz to iOS device $DEVICE_ID in profile mode."
echo "Do not use debug mode for physical iPhone home-screen installs."

"$FLUTTER" build ios --profile -d "$DEVICE_ID"
"$FLUTTER" install --profile -d "$DEVICE_ID"

echo "Installed profile build on $DEVICE_ID."
