# Kolkhoz

Kolkhoz is a Soviet-themed trick-taking card game. The current source of truth is the
portable C engine wrapped by the native SwiftUI app in `ios/KolkhozSwiftUI/`.

## Current Status

The SwiftUI app is playable with:

- 4-player gameplay: 1 human and 3 AI opponents.
- Offline play backed by the C engine.
- Online session/server foundations using portable engine actions and redacted snapshots.
- Full 5-year campaign.
- Native SwiftUI lobby, board, card, swap, assignment, plot, requisition, and game-over screens.
- Pixel-art card, icon, and UI resources.
- Deterministic engine support through seeded randomness.
- Plain Swift smoke tests.

## Quick Start

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
```

To open in Xcode:

```bash
cd ios/KolkhozSwiftUI
xcodegen generate
open KolkhozSwiftUI.xcodeproj
```

Then select the `KolkhozSwiftUIApp` scheme and run on an iPhone simulator or device.

If SwiftPM reports duplicate modules through both `/Users/wtheisen/Dropbox/...` and
`/Users/wtheisen/Library/CloudStorage/Dropbox/...`, run commands through one canonical
path or clear the SwiftPM module cache.

## Game Flow

1. **Planning** - Reveal jobs and set trump. Year 5 is famine and has no trump.
2. **Swap** - In years 2-5, each player may swap one hand card with a hidden or revealed plot card when the swap variant is enabled.
3. **Trick** - Play 4 tricks in normal years and 3 tricks in famine. Players must follow the lead suit if able.
4. **Assignment** - The trick winner assigns captured cards to jobs. Legal target jobs are the suits present in the completed trick.
5. **Year end** - Remaining hand cards move to hidden plots.
6. **Requisition** - Failed jobs may reveal and exile matching plot cards.
7. Repeat for 5 years. **Highest final plot score wins**.

## Special Cards

Special cards apply only when `nomenclature` is enabled and the card is in the trump suit:

- **Jack, Drunkard** - Contributes 0 work hours. If its assigned job fails, the Drunkard is exiled instead of player plot cards for that job.
- **Queen, Informant** - If its assigned job fails, matching hidden plot cards are all revealed.
- **King, Party Official** - If its assigned job fails, two matching revealed plot cards are exiled instead of one.

Famine has no trump, so trump special-card effects do not apply in year 5.

## Swift Architecture

```text
ios/KolkhozSwiftUI/
  Package.swift
  project.yml
  Sources/
    KolkhozCEngine/
      KolkhozCEngine.c          # Portable C rules engine
      include/KolkhozCEngine.h  # Public C API
    KolkhozCore/
      Models.swift              # State, cards, variants, phases, errors
      KolkhozHeadlessEngine.swift # Swift C adapter, snapshots, actions, saved games
      KolkhozOnlineSession.swift # Authoritative online sessions and client protocols
      KolkhozOnlineHTTPRouter.swift # HTTP transport routing helpers
    KolkhozAppFeature/
      GameStore.swift           # SwiftUI adapter around C/online runtimes
      KolkhozRootView.swift     # Lobby/game switch
      Lobby/LobbyView.swift     # Presets, custom variants, rules
      Lobby/OnlineLobbyView.swift # Host/join online setup
      Board/                    # Board shell, navigation, phase screens
      Cards/CardViews.swift     # Card rendering
      Design/                  # Shared colors, controls, icons
      Resources/               # Pixel art and UI assets
    KolkhozSwiftUIApp/
      KolkhozSwiftUIApp.swift   # App entry point
    KolkhozSmokeTests/
      main.swift                # Smoke tests
```

## Data Flow

```text
SwiftUI gesture
    -> GameStore action
    -> KolkhozCEngineAdapter applies a portable action
    -> C engine processes automatic AI turns
    -> GameStore publishes copied state and animation events
    -> SwiftUI re-renders
```

Views should call `GameStore`; game rules and state mutations belong in the C engine.

## Key Files

- `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/` - Portable C rules engine.
- `ios/KolkhozSwiftUI/Sources/KolkhozCore/KolkhozHeadlessEngine.swift` - Swift C adapter, snapshots, actions, saved games.
- `ios/KolkhozSwiftUI/Sources/KolkhozCore/KolkhozOnlineSession.swift` - Online session state, redaction, and client protocols.
- `ios/KolkhozSwiftUI/Sources/KolkhozCore/Models.swift` - State and model definitions.
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/GameStore.swift` - MainActor state bridge.
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/` - Phase UI and player interactions.
- `agent-docs/` - Agent-oriented architecture, state, and phase references.
