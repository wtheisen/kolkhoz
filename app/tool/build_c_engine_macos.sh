#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
OUT_DIR="$APP_DIR/native/macos"

mkdir -p "$OUT_DIR"

if [[ "${KOLKHOZ_SKIP_POLICY_ASSET_UPDATE:-0}" != "1" ]]; then
  PYTHONDONTWRITEBYTECODE=1 "${PYTHON:-python3}" "$SCRIPT_DIR/update_neural_policy_asset.py"
fi

(
  cd "$APP_DIR"
  "${DART:-dart}" run tool/sync_policy_assets.dart
)

ENGINE_SOURCES=()
while IFS= read -r source; do
  ENGINE_SOURCES+=("$source")
done < <(find "$REPO_ROOT/engine/KolkhozCEngine" -maxdepth 1 -name '*.c' -print | sort)

clang \
  -dynamiclib \
  -O2 \
  -std=c11 \
  -I"$REPO_ROOT/engine/KolkhozCEngine/include" \
  "${ENGINE_SOURCES[@]}" \
  -o "$OUT_DIR/libkolkhoz_c_engine.dylib"

echo "$OUT_DIR/libkolkhoz_c_engine.dylib"
