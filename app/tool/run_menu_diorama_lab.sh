#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "$0")/.." && pwd)"
config_root="${TMPDIR:-/tmp}/kolkhoz-menu-diorama-lab-flutter-config"

mkdir -p "$config_root"
export XDG_CONFIG_HOME="$config_root"

flutter config --build-dir=build/menu_diorama_lab >/dev/null

cd "$app_root"

exec flutter run \
  --device-id macos \
  --target lib/menu_diorama_lab.dart \
  --dart-define=KOLKHOZ_ART_STYLE=field_plan \
  "$@"
