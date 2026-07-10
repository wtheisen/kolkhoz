#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ "${1:-}" = "--check" ]; then
  flutter test test/layout_screenshot_test.dart test/lobby_screenshot_test.dart
else
  flutter test --update-goldens \
    test/layout_screenshot_test.dart \
    test/lobby_screenshot_test.dart
  printf '\nScreenshots written to test/layout_goldens/\n'
fi
