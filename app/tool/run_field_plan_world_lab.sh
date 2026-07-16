#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "$0")/.." && pwd)"
config_root="${TMPDIR:-/tmp}/kolkhoz-field-plan-world-lab-flutter-config"
keychain_service="com.kolkhoz.figma.world-depth"
keychain_account="access-token"
store_access_token=false

mkdir -p "$config_root"
export XDG_CONFIG_HOME="$config_root"

flutter config --build-dir=build/field_plan_world_lab >/dev/null

cd "$app_root"

if [[ -n "${FIGMA_ACCESS_TOKEN:-}" ]]; then
  store_access_token=true
elif [[ -z "${FIGMA_OAUTH_TOKEN:-}" ]] && command -v security >/dev/null 2>&1; then
  FIGMA_ACCESS_TOKEN="$(
    security find-generic-password \
      -s "$keychain_service" \
      -a "$keychain_account" \
      -w 2>/dev/null || true
  )"
  export FIGMA_ACCESS_TOKEN
fi

if [[ -z "${FIGMA_ACCESS_TOKEN:-}" && -z "${FIGMA_OAUTH_TOKEN:-}" ]]; then
  cat >&2 <<'EOF'
The world lab requires a Figma token so it cannot build stale depth plates.

Create a token with file_content:read, then run once with:
  FIGMA_ACCESS_TOKEN='TOKEN' ./tool/run_field_plan_world_lab.sh

The launcher stores that token in macOS Keychain for future runs.
EOF
  exit 1
fi

dart run tool/sync_world_depth_plates.dart

if [[ "$store_access_token" == true ]] && command -v security >/dev/null 2>&1; then
  security add-generic-password \
    -U \
    -s "$keychain_service" \
    -a "$keychain_account" \
    -w "$FIGMA_ACCESS_TOKEN" >/dev/null
fi

exec flutter run \
  --device-id macos \
  --target lib/field_plan_world_lab.dart \
  --dart-define=KOLKHOZ_ART_STYLE=field_plan \
  --dart-define=KOLKHOZ_FIELD_PLAN_EDITOR=true \
  "$@"
