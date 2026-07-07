#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"

cd "$REPO_ROOT"

echo "==> Rebuilding Flutter macOS C engine dylib"
clients/flutter_app/tool/build_c_engine_macos.sh

echo "==> Checking C engine syntax"
ENGINE_SOURCES=()
while IFS= read -r source; do
  ENGINE_SOURCES+=("$source")
done < <(find engine/KolkhozCEngine -maxdepth 1 -name '*.c' | sort)

clang -std=c11 \
  -I engine/KolkhozCEngine/include \
  -fsyntax-only "${ENGINE_SOURCES[@]}"

echo "==> Checking Flutter formatting"
(
  cd clients/flutter_app
  "$DART_BIN" format --set-exit-if-changed lib test
)

echo "==> Running Flutter analyzer"
(
  cd clients/flutter_app
  "$FLUTTER_BIN" analyze
)

echo "==> Running Flutter tests"
(
  cd clients/flutter_app
  "$FLUTTER_BIN" test
)

echo "==> Building Flutter macOS debug app"
(
  cd clients/flutter_app
  "$FLUTTER_BIN" build macos --debug
)

echo "==> Flutter source-of-truth gate checks passed"
