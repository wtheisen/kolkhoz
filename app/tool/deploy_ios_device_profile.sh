#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
DEVICE_ID="${1:-${KOLKHOZ_IOS_DEVICE_ID:-00008110-000C515934E3A01E}}"
ENV_FILE="${KOLKHOZ_ONLINE_ENV_FILE:-$REPO_ROOT/.env.kolkhoz-online}"
FLUTTER="${FLUTTER:-flutter}"
BETA_BUILD="${KOLKHOZ_BETA:-true}"

if [[ "$BETA_BUILD" != "true" && "$BETA_BUILD" != "false" ]]; then
  echo "KOLKHOZ_BETA must be true or false." >&2
  exit 1
fi

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
DART_DEFINES+=("--dart-define=KOLKHOZ_BETA=$BETA_BUILD")
if [[ -n "${KOLKHOZ_SUPABASE_URL:-}" && -n "${KOLKHOZ_SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_URL=$KOLKHOZ_SUPABASE_URL")
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=$KOLKHOZ_SUPABASE_PUBLISHABLE_KEY")
else
  echo "Refusing to deploy without Supabase configuration." >&2
  echo "Existing accounts cannot be migrated safely without KOLKHOZ_SUPABASE_URL and KOLKHOZ_SUPABASE_PUBLISHABLE_KEY." >&2
  echo "Set KOLKHOZ_ONLINE_ENV_FILE or create $ENV_FILE from .env.example." >&2
  exit 1
fi

cd "$APP_DIR"

"${DART:-dart}" run tool/sync_policy_assets.dart

echo "Deploying Kolkhoz to iOS device $DEVICE_ID in profile mode."
echo "Beta full-game access: $BETA_BUILD"
echo "Art style: $ART_STYLE"
echo "Do not use debug mode for physical iPhone home-screen installs."

"$FLUTTER" build ios --profile -d "$DEVICE_ID" "${DART_DEFINES[@]}"
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_DIR/build/ios/iphoneos/Runner.app"

echo "Installed profile build in place on $DEVICE_ID."
