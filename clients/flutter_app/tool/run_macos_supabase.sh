#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$app_root/../.." && pwd)"
env_file="${KOLKHOZ_ONLINE_ENV_FILE:-$repo_root/.env.kolkhoz-online}"
flutter_bin="${FLUTTER_BIN:-flutter}"

if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  bundled_flutter="$HOME/.codex/flutter-sdk/flutter/bin/flutter"
  if [[ -x "$bundled_flutter" ]]; then
    flutter_bin="$bundled_flutter"
  fi
fi

if [[ -f "$env_file" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
fi

if [[ -z "${KOLKHOZ_SUPABASE_URL:-}" || -z "${KOLKHOZ_SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  echo "Missing KOLKHOZ_SUPABASE_URL or KOLKHOZ_SUPABASE_PUBLISHABLE_KEY." >&2
  echo "Create $env_file from .env.example first." >&2
  exit 1
fi

cd "$app_root"
"$flutter_bin" run -d macos \
  --dart-define="KOLKHOZ_SUPABASE_URL=$KOLKHOZ_SUPABASE_URL" \
  --dart-define="KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=$KOLKHOZ_SUPABASE_PUBLISHABLE_KEY" \
  "$@"
