#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "$0")/.." && pwd)"
config_root="${TMPDIR:-/tmp}/kolkhoz-static-hero-panels-lab-flutter-config"

mkdir -p "$config_root"
export XDG_CONFIG_HOME="$config_root"

flutter config --build-dir=build/static_hero_panels_lab >/dev/null

cd "$app_root"

exec flutter run \
  --device-id macos \
  --target lib/static_hero_panels_lab.dart \
  "$@"
