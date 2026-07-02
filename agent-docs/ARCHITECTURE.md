# Kolkhoz Architecture

The C engine under `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/` is the source of truth
for rules and app behavior. The native SwiftUI app uses that engine through
`KolkhozCEngineAdapter` for offline play and through online session snapshots/actions for
multiplayer. The older React/boardgame.io code remains in the repo, but should not be
used to infer current iOS behavior when it differs from the C engine.

## Directory Structure

```text
kolkhoz/
├── ios/
│   └── KolkhozSwiftUI/
│       ├── Package.swift
│       ├── project.yml
│       ├── KolkhozSwiftUI.xcodeproj/
│       └── Sources/
│           ├── KolkhozCore/
│           │   ├── Models.swift
│           │   ├── KolkhozHeadlessEngine.swift
│           │   ├── KolkhozOnlineSession.swift
│           │   └── KolkhozOnlineHTTPRouter.swift
│           ├── KolkhozCEngine/
│           │   ├── include/
│           │   └── *.c
│           ├── KolkhozAppFeature/
│           │   ├── GameStore.swift
│           │   ├── KolkhozRootView.swift
│           │   ├── Lobby/
│           │   │   └── LobbyView.swift
│           │   ├── Board/
│           │   │   ├── GameBoardView.swift
│           │   │   └── GameSections.swift
│           │   ├── Cards/
│           │   │   └── CardViews.swift
│           │   ├── Design/
│           │   │   ├── Controls.swift
│           │   │   ├── GameIcon.swift
│           │   │   └── KolkhozStyle.swift
│           │   └── Resources/
│           ├── KolkhozSwiftUIApp/
│           │   └── KolkhozSwiftUIApp.swift
│           └── KolkhozSmokeTests/
│               └── main.swift
├── src/                         # Legacy web app source
├── docs/                        # Generated legacy web build output
├── agent-docs/
├── package.json
└── README.md
```

## Module Responsibilities

### `KolkhozCEngine`

Portable C rules engine. This is the runtime rules implementation for local play,
online sessions, and eventual non-iOS clients.

### `KolkhozCore`

Foundation-only Swift models and adapters with no SwiftUI dependency.

| File | Purpose |
|------|---------|
| `Models.swift` | Suits, cards, variants, players, state, phases, animation events, errors |
| `KolkhozHeadlessEngine.swift` | `KolkhozCEngineAdapter`, C action/snapshot types, saved-game bridge |
| `KolkhozOnlineSession.swift` | Online session store, redaction, client protocols, local client |
| `KolkhozOnlineHTTPRouter.swift` | Minimal HTTP routing for the online server |

### `KolkhozAppFeature`

SwiftUI feature module for the playable app.

| File | Purpose |
|------|---------|
| `GameStore.swift` | `@MainActor ObservableObject` bridge around C, online, and scripted preview runtimes |
| `KolkhozRootView.swift` | Owns lobby/game mode, selected preset, custom variants, language |
| `Lobby/LobbyView.swift` | Start screen, preset selector, custom variant controls, rules panel |
| `Board/GameBoardView.swift` | Main board shell, nav rail/top bar, panel selection, animation overlay |
| `Board/GameSections.swift` | Player panels, jobs, assignment, swap, plot, requisition, game over, hand tray |
| `Cards/CardViews.swift` | Card faces, backs, pips, face-card art, suit marks |
| `Design/` | Shared panel chrome, colors, fonts, icons, buttons, progress bars |

### `KolkhozSwiftUIApp`

The iOS app entry point. `KolkhozSwiftUIApp` opens `KolkhozRootView`.

### `KolkhozSmokeTests`

Plain Swift executable tests for environments where XCTest is not set up. These cover
basic dealing, follow-suit validation, play-card state mutation, deterministic game
completion, saved-game replay, and online session transport.

## Data Flow

```text
User gesture in SwiftUI
    |
    v
GameStore action
    |
    v
KolkhozCEngineAdapter applies a C action
    |
    v
C engine advances automatic AI turns and phase transitions
    |
    v
GameStore copies adapter state into @Published state
    |
    v
SwiftUI re-renders views
    |
    v
Queued KolkhozAnimationEvent values drive overlays
```

Views do not mutate `KolkhozState` directly. They call `GameStore`, which calls the C
runtime or online client and then publishes the new state. Scripted preview/tutorial
states use a lightweight `ScriptedGameRuntime`, not the old Swift rules engine.

## Engine Pattern

`KolkhozCEngineAdapter` is the Swift runtime wrapper around the C state:

```swift
public final class KolkhozCEngineAdapter {
    public var snapshot: KolkhozEngineSnapshot { ... }
    public private(set) var state: KolkhozState
}
```

Public methods are the user-facing moves:

- `newGame(seed:variants:controllers:)`
- `setTrump(_:)`
- `playCard(_:)`
- `swap(handCard:plotCard:revealed:)`
- `undoSwap()`
- `confirmSwap()`
- `assign(card:to:)`
- `submitAssignments()`
- `continueAfterRequisition()`

The shared action type is `KolkhozEngineAction`; offline play applies it directly to the
C adapter, and online play sends the same action to the session/server.

## Phase Ownership

Phase flow is owned by the C engine. Keep Swift phase logic limited to adapting C
snapshots into `KolkhozState`, redacting online views, and rendering the correct UI.

## UI Architecture

`GameBoardView` chooses the action panel from `state.phase`, while users can manually
switch display panels with the nav rail/top bar:

- `game`: player columns, trick slots, and hand tray.
- `jobs`: work gauges and drag assignment UI.
- `plot`: swap UI, requisition plot view, or normal plot overview.
- `north`: exiled card history by year.
- `options`: in-game menu and rules.

Animation targets are captured with `GeometryReader` in a named coordinate space.
`GameStore.animationEvents` are consumed one at a time by `LandscapeGameAreaView`.

## AI System

Runtime AI is deterministic for a given seed and implemented in the C engine:

- Trump: pick the suit with the strongest hand score.
- Swap: trade the lowest hand card for a significantly better plot card.
- Trick: play the lowest legal card, unless trying to win a late first trick.
- Assignment: choose the highest-priority legal suit and assign all trick cards there.

Do not add a parallel Swift AI/rules implementation for app gameplay. Future training
tooling should bind to the C engine contract directly.

## Build System

Swift Package Manager builds package targets:

```bash
swift run KolkhozSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
```

`project.yml` is the XcodeGen source for the checked-in Xcode project:

```bash
xcodegen generate
xcodebuild -project KolkhozSwiftUI.xcodeproj -scheme KolkhozSwiftUIApp -destination 'generic/platform=iOS Simulator' build
```

## Testing Architecture

`Sources/KolkhozSmokeTests/main.swift` defines simple `expect` checks and exits nonzero
on failure. It currently verifies:

- New game deals 20 worker cards in normal years.
- Legal human cards respect lead suit.
- Card play actions mutate C engine state.
- A deterministic game can reach `gameOver`.
- Saved games restore from the C action log.
- Online sessions redact private state and validate submitted actions.
