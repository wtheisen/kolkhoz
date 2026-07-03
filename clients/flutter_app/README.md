# Kolkhoz Flutter Client

This is the Flutter client for Kolkhoz. The default entrypoint is a standalone
local game backed by the shared C engine.

## Data Sources

The app owns its visual constants in Dart and loads iOS resource artwork as
Flutter assets:

- `ios_resources/`

## Commands

```bash
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter pub get
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter run -d macos
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter analyze
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter test
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter build ios --simulator --debug
/Users/wtheisen/.codex/flutter-sdk/flutter/bin/flutter build macos --debug
xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Run commands from this directory. If Flutter is on your `PATH`, the shorter
`flutter` form works too.

The macOS project builds and bundles `native/macos/libkolkhoz_c_engine.dylib`
automatically. The iOS project compiles the shared C engine source directly into
the Runner target and uses Dart FFI through the process library.

On this machine, `flutter build ios --simulator --debug` can fail before app
compilation if Flutter's cached `Flutter.framework` has protected
`com.apple.provenance` metadata. The `xcodebuild` command above was used to
verify the iOS simulator app build with signing disabled.
