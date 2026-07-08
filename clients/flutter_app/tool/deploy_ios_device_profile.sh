#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"
DEVICE_ID="${1:-${KOLKHOZ_IOS_DEVICE_ID:-00008110-000C515934E3A01E}}"
ENV_FILE="${KOLKHOZ_ONLINE_ENV_FILE:-$REPO_ROOT/.env.kolkhoz-online}"
FLUTTER="${FLUTTER:-flutter}"

if ! command -v "$FLUTTER" >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/flutter ]]; then
    FLUTTER="/opt/homebrew/bin/flutter"
  fi
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DART_DEFINES=()
if [[ -n "${KOLKHOZ_SUPABASE_URL:-}" && -n "${KOLKHOZ_SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_URL=$KOLKHOZ_SUPABASE_URL")
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=$KOLKHOZ_SUPABASE_PUBLISHABLE_KEY")
else
  echo "Warning: Supabase env values not found; cloud profiles will be disabled." >&2
  echo "Set KOLKHOZ_ONLINE_ENV_FILE or create $ENV_FILE from .env.example to enable them." >&2
fi

cd "$APP_DIR"

echo "Deploying Kolkhoz to iOS device $DEVICE_ID in profile mode."
echo "Do not use debug mode for physical iPhone home-screen installs."

"$FLUTTER" build ios --profile -d "$DEVICE_ID" "${DART_DEFINES[@]}"
"$FLUTTER" install --profile -d "$DEVICE_ID"

echo "Installed profile build on $DEVICE_ID."
