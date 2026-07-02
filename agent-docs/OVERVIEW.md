# Kolkhoz - Agent Quick Start Guide

The authoritative gameplay implementation is the C engine wrapped by the native SwiftUI
app in `ios/KolkhozSwiftUI/`.

The old React/boardgame.io/Vite web app has been removed. Do not revive it or use it as
the basis for future clients. The iOS SwiftUI app is the current visual reference.

## Tech Stack

### iOS app
- **C** - Source rules engine used by local and online gameplay
- **Swift 6** - App code, C engine adapter, online sessions, and transitional tooling
- **SwiftUI** - Native UI
- **Swift Package Manager** - Package targets and smoke tests
- **XcodeGen** - Generates the iOS Xcode project from `project.yml`

### Shared native foundations
- **JSON contracts** - Platform-neutral table/view-model fixtures in `shared/app-contracts/`
- **Design tokens** - Shared colors, spacing, card metrics, typography scale, and motion constants in `shared/design/tokens.json`
- **Flutter direction** - Planned native renderer for Android, macOS, Windows, and Linux using the C engine through FFI

## Quick Commands

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSmokeTests
swift run KolkhozContractSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
xcodegen generate
xcodebuild -project KolkhozSwiftUI.xcodeproj -scheme KolkhozSwiftUIApp -destination 'generic/platform=iOS Simulator' build
```

If SwiftPM reports duplicate modules through both `/Users/wtheisen/Dropbox/...` and
`/Users/wtheisen/Library/CloudStorage/Dropbox/...`, clean the SwiftPM module cache or
run all commands through one canonical path.

## Project Layout

```text
ios/KolkhozSwiftUI/
  Package.swift
  project.yml
  Sources/
    KolkhozCore/
      Models.swift              # Foundation-only game state models
      KolkhozHeadlessEngine.swift # C engine adapter and snapshot/action bridge
      KolkhozOnlineSession.swift # Local session model and async client protocol
      KolkhozOnlineHTTPRouter.swift # HTTP route parsing and responses
    KolkhozCEngine/             # C rules engine source and public headers
    KolkhozAppFeature/
      GameStore.swift           # MainActor ObservableObject adapter over C/online runtimes
      KolkhozRootView.swift     # Lobby/game switch and app-wide state
      Lobby/LobbyView.swift     # Presets, custom variants, rules
      Board/GameBoardView.swift # Board shell, navigation, animations
      Board/BrigadeView.swift   # Player columns and trick slots
      Board/JobsView.swift      # Job gauges and assignment UI
      Board/PlotView.swift      # Plot storage, swap, and requisition UI
      Cards/CardViews.swift     # Card rendering
      Design/                  # Shared colors, controls, icons
      Resources/               # Pixel art, cards, icons, chrome
    KolkhozSwiftUIApp/
      KolkhozSwiftUIApp.swift   # App entry point
    KolkhozSmokeTests/
      main.swift                # Plain Swift smoke tests
    KolkhozContractSmokeTests/
      main.swift                # Shared contract fixture smoke tests
shared/
  app-contracts/
    README.md
    schemas/table-view-model.schema.json
    fixtures/                  # Canonical renderer fixtures
  design/tokens.json           # Visual constants derived from SwiftUI
```

## Game Flow

1. **Planning** - Reveal jobs and set trump. Year 5 is famine: no trump.
2. **Swap** - In years 2-5, each player may swap one hand card with a hidden or revealed plot card when `allowSwap` is enabled.
3. **Trick** - Play 4 tricks in normal years, 3 tricks in famine. Players must follow the lead suit if able.
4. **Assignment** - Every completed trick enters assignment. The brigade leader assigns trick cards to one of the suits present in that trick.
5. **Year end** - After the final trick, remaining hand cards move to hidden plots.
6. **Requisition** - Failed jobs may reveal and exile matching plot cards.
7. Repeat for 5 years. **Highest final plot score wins**.

## Key Files to Read First

1. `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/` - Source rules engine.
2. `ios/KolkhozSwiftUI/Sources/KolkhozCore/KolkhozHeadlessEngine.swift` - Swift C adapter, actions, snapshots, saved games.
3. `ios/KolkhozSwiftUI/Sources/KolkhozCore/Models.swift` - Swift state model reference used by UI.
4. `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/GameStore.swift` - SwiftUI state bridge.
5. `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/` - Phase-specific UI.
6. `shared/app-contracts/README.md` - Platform-neutral presentation contract notes.
7. `agent-docs/CROSS_PLATFORM_NATIVE_APP_PLAN.md` - Native cross-platform roadmap.

## Common Tasks

### Changing game rules
1. Update the C engine in `Sources/KolkhozCEngine/`.
2. Update the Swift adapter in `KolkhozHeadlessEngine.swift` only if the C API or snapshot shape changes.
3. Update or add a smoke test in `Sources/KolkhozSmokeTests/main.swift`.
4. Run `swift run KolkhozSmokeTests`.

### Changing shared contracts
1. Update `shared/app-contracts/` or `shared/design/tokens.json`.
2. Keep the JSON shape renderer-neutral; do not add a UI DSL.
3. Run `swift run KolkhozContractSmokeTests`.

### Changing UI
1. Update views in `Sources/KolkhozAppFeature/`.
2. Keep state mutations inside the C runtime or online session; views should call `GameStore`.
3. Verify with `swift build --target KolkhozSwiftUIApp` and, when possible, an Xcode simulator build.

### Modifying phase transitions
- Update the C phase flow in `Sources/KolkhozCEngine/`.
- Update `KolkhozHeadlessEngine.swift` only when the C snapshot/action shape changes.
- Re-run `swift run KolkhozSmokeTests`.

## Build Notes

The C engine is source of truth. Do not reintroduce a parallel Swift rules engine into
app runtime paths. Future downloadable clients should bind to the C engine contracts
instead of reviving retired UI implementations. Flutter clients should mirror iOS through
shared presentation contracts, design tokens, assets, and screenshot fixtures.
