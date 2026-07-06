#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"
OUT_DIR="$APP_DIR/native/macos"

mkdir -p "$OUT_DIR"

clang \
  -dynamiclib \
  -O2 \
  -std=c11 \
  -I"$REPO_ROOT/engine/KolkhozCEngine/include" \
  "$REPO_ROOT/engine/KolkhozCEngine/KolkhozCEngine.c" \
  -o "$OUT_DIR/libkolkhoz_c_engine.dylib"

echo "$OUT_DIR/libkolkhoz_c_engine.dylib"
