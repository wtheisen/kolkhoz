#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
FLUTTER_RUN=(
  flutter run
  -d macos
  --debug
  --dart-define=KOLKHOZ_ART_STYLE=field_plan
)

case "${1:-}" in
  --verify)
    command -v flutter >/dev/null
    test -f "$APP_DIR/pubspec.yaml"
    echo "Flutter and the Kolkhoz app workspace are ready."
    exit 0
    ;;
  --logs)
    ;;
  --telemetry)
    exec log stream --style compact --predicate 'process == "kolkhoz_app"'
    ;;
  --debug)
    FLUTTER_RUN+=(--verbose)
    ;;
  "")
    ;;
  *)
    echo "Usage: $0 [--verify|--debug|--logs|--telemetry]" >&2
    exit 2
    ;;
esac

pkill -x kolkhoz_app 2>/dev/null || true

cd "$APP_DIR"
exec "${FLUTTER_RUN[@]}"
