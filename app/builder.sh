#!/usr/bin/env bash
set -euo pipefail

OPEN_APP=1
CLEAN_BUILD=1
STOP_STALE=1
REQUIRE_SUPABASE=1
ART_STYLE=legacy
EXTRA_ARGS=()

usage() {
  cat <<'USAGE'
Usage: ./builder.sh [options] [extra flutter build args]

Builds the macOS debug app from the physical repo path, includes Supabase
dart-defines from .env.kolkhoz-online, and keeps local build folders out of
Dropbox sync.

Options:
  --no-open                 Build only; do not open the app afterward.
  --no-clean                Keep existing build caches for a faster build.
  --no-stop-stale           Do not stop stale Flutter/Xcode/app processes first.
  --allow-missing-supabase  Build even if Supabase env values are missing.
  --new-art                 Build with the incremental field-plan art direction.
  --legacy-art              Build with the current pixel-art direction (default).
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      OPEN_APP=1
      ;;
    --no-open)
      OPEN_APP=0
      ;;
    --clean)
      CLEAN_BUILD=1
      ;;
    --no-clean)
      CLEAN_BUILD=0
      ;;
    --stop-stale)
      STOP_STALE=1
      ;;
    --no-stop-stale)
      STOP_STALE=0
      ;;
    --allow-missing-supabase)
      REQUIRE_SUPABASE=0
      ;;
    --new-art)
      ART_STYLE=field_plan
      ;;
    --legacy-art)
      ART_STYLE=legacy
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      EXTRA_ARGS+=("$1")
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd -P "$APP_DIR/.." && pwd)"
ENV_FILE="${KOLKHOZ_ONLINE_ENV_FILE:-$REPO_ROOT/.env.kolkhoz-online}"
FLUTTER_BIN="${FLUTTER_BIN:-${FLUTTER:-flutter}}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  for candidate in \
    "$HOME/.codex/flutter-sdk/flutter/bin/flutter" \
    "/opt/homebrew/bin/flutter" \
    "/usr/local/bin/flutter"
  do
    if [[ -x "$candidate" ]]; then
      FLUTTER_BIN="$candidate"
      break
    fi
  done
fi

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "Could not find Flutter. Set FLUTTER_BIN to your flutter executable." >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DART_DEFINES=()
DART_DEFINES+=("--dart-define=KOLKHOZ_ART_STYLE=$ART_STYLE")
if [[ -n "${KOLKHOZ_SUPABASE_URL:-}" && -n "${KOLKHOZ_SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_URL=$KOLKHOZ_SUPABASE_URL")
  DART_DEFINES+=("--dart-define=KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=$KOLKHOZ_SUPABASE_PUBLISHABLE_KEY")
elif [[ "$REQUIRE_SUPABASE" == "1" ]]; then
  echo "Missing KOLKHOZ_SUPABASE_URL or KOLKHOZ_SUPABASE_PUBLISHABLE_KEY." >&2
  echo "Create $ENV_FILE from $REPO_ROOT/.env.example, or pass --allow-missing-supabase." >&2
  exit 1
else
  echo "Warning: building without Supabase dart-defines." >&2
fi

mark_dropbox_ignored() {
  local dirs=(
    "build"
    ".dart_tool"
    "macos/Flutter/ephemeral"
    "ios/Flutter/ephemeral"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    if [[ -x /usr/bin/xattr ]]; then
      /usr/bin/xattr -w com.dropbox.ignored 1 "$dir" 2>/dev/null || true
    fi
  done
}

stop_stale_processes() {
  pkill -f "kolkhoz_app.app/Contents/MacOS/kolkhoz_app" 2>/dev/null || true
  pkill -f "kolkhoz/app.*flutter_tools.snapshot run -d macos" 2>/dev/null || true
  pkill -f "kolkhoz/app.*flutter_tools.snapshot build macos" 2>/dev/null || true
  pkill -f "kolkhoz/app.*Runner.xcworkspace" 2>/dev/null || true
  pkill -f "codesign --force.*kolkhoz_app.app" 2>/dev/null || true
}

cd "$APP_DIR"

echo "Repo: $REPO_ROOT"
echo "App:  $APP_DIR"
echo "Flutter: $FLUTTER_BIN"
echo "Env: $ENV_FILE"
echo "Art: $ART_STYLE"

if [[ "$STOP_STALE" == "1" ]]; then
  stop_stale_processes
fi

if [[ "$CLEAN_BUILD" == "1" ]]; then
  "$FLUTTER_BIN" clean
  rm -rf build .dart_tool macos/Flutter/ephemeral ios/Flutter/ephemeral
fi

mark_dropbox_ignored

dart run tool/sync_policy_assets.dart
"$FLUTTER_BIN" pub get

BUILD_ARGS=(build macos --debug "${DART_DEFINES[@]}")
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  BUILD_ARGS+=("${EXTRA_ARGS[@]}")
fi

"$FLUTTER_BIN" "${BUILD_ARGS[@]}"

APP_BUNDLE="$APP_DIR/build/macos/Build/Products/Debug/kolkhoz_app.app"
echo "Built $APP_BUNDLE"

if [[ "$OPEN_APP" == "1" ]]; then
  open "$APP_BUNDLE"
fi
