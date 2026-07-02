# Kolkhoz SwiftUI

Native SwiftUI implementation of Kolkhoz for iOS.

## Open in Xcode

1. Run `xcodegen generate` if `KolkhozSwiftUI.xcodeproj` is missing or stale.
2. Open `KolkhozSwiftUI.xcodeproj` in Xcode.
3. Select the `KolkhozSwiftUIApp` scheme.
3. Choose an iPhone simulator or device.
4. Run.

The app is split into:

- `KolkhozCEngine`: portable C rules engine.
- `KolkhozCore`: Foundation-only Swift models, C adapter, saved-game, and online session code.
- `KolkhozAppFeature`: SwiftUI store and game screens.
- `KolkhozSwiftUIApp`: app entry point.
- `KolkhozSmokeTests`: plain Swift smoke tests for environments without XCTest.

## Local Verification

```bash
swift run KolkhozSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
xcodegen generate
xcodebuild -project KolkhozSwiftUI.xcodeproj -scheme KolkhozSwiftUIApp -destination 'generic/platform=iOS Simulator' build
```

Full iOS simulator/device builds require Xcode. This machine currently has Command Line Tools selected, so `xcodebuild` cannot run until full Xcode is selected with `xcode-select`.

## Policy Training

The old Swift-engine trainer and policy benchmark targets have been removed. New
training work should bind directly to the C engine contract instead of restoring a
parallel Swift rules engine.
