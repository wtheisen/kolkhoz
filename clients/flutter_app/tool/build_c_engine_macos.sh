#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"
OUT_DIR="$APP_DIR/native/macos"

mkdir -p "$OUT_DIR"

if [[ "${KOLKHOZ_SKIP_POLICY_ASSET_UPDATE:-0}" != "1" ]]; then
  PYTHONDONTWRITEBYTECODE=1 "${PYTHON:-python3}" "$SCRIPT_DIR/update_neural_policy_asset.py"
fi

clang \
  -dynamiclib \
  -O2 \
  -std=c11 \
  -I"$REPO_ROOT/engine/KolkhozCEngine/include" \
  "$REPO_ROOT/engine/KolkhozCEngine/KolkhozCEngine.c" \
  -o "$OUT_DIR/libkolkhoz_c_engine.dylib"

echo "$OUT_DIR/libkolkhoz_c_engine.dylib"
