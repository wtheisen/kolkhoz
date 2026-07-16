#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
APP_BUNDLE="$APP_DIR/build/macos/Build/Products/Debug/kolkhoz_app.app"

case "${1:-}" in
  --verify)
    command -v flutter >/dev/null
    test -f "$APP_DIR/pubspec.yaml"
    echo "Flutter and the Kolkhoz app workspace are ready."
    exit 0
    ;;
  --logs)
    exec log stream --style compact --predicate 'process == "kolkhoz_app"'
    ;;
  --telemetry)
    exec log show --style compact --last 10m --predicate 'process == "kolkhoz_app"'
    ;;
  --debug)
    set -x
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
flutter build macos --debug --dart-define=KOLKHOZ_ART_STYLE=field_plan
open -n "$APP_BUNDLE"
