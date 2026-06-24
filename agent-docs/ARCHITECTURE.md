# Kolkhoz Architecture

The native SwiftUI implementation in `ios/KolkhozSwiftUI/` is the source of truth for
rules and app behavior. The older React/boardgame.io code remains in the repo, but should
not be used to infer current iOS behavior when it differs from Swift.

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
│           │   └── KolkhozEngine.swift
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
├── docs/                        # Legacy web build output
├── agent-docs/
├── package.json
└── README.md
```

## Module Responsibilities

### `KolkhozCore`

Foundation-only game logic with no SwiftUI dependency.

| File | Purpose |
|------|---------|
| `Models.swift` | Suits, cards, variants, players, state, phases, animation events, errors |
| `KolkhozEngine.swift` | New game setup, AI turns, moves, phase transitions, requisition, scoring |

### `KolkhozAppFeature`

SwiftUI feature module for the playable app.

| File | Purpose |
|------|---------|
| `GameStore.swift` | `@MainActor ObservableObject` bridge around `KolkhozEngine` |
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
basic dealing, follow-suit validation, animation events, and deterministic game
completion.

## Data Flow

```text
User gesture in SwiftUI
    |
    v
GameStore action
    |
    v
KolkhozEngine method mutates KolkhozState
    |
    v
Engine processes automatic AI turns
    |
    v
GameStore copies engine.state into @Published state
    |
    v
SwiftUI re-renders views
    |
    v
Queued KolkhozAnimationEvent values drive overlays
```

Views do not mutate `KolkhozState` directly. They call `GameStore`, which calls the
engine and then publishes the new state.

## Engine Pattern

`KolkhozEngine` is a mutable class:

```swift
public final class KolkhozEngine {
    public private(set) var state: KolkhozState
    private var random: SeededGenerator
    private var animationEvents: [KolkhozAnimationEvent] = []
}
```

Public methods are the user-facing moves:

- `newGame(seed:variants:)`
- `setTrump(_:)`
- `playCard(_:)`
- `swap(handCard:plotCard:revealed:)`
- `undoSwap()`
- `confirmSwap()`
- `assign(card:to:)`
- `submitAssignments()`
- `continueAfterRequisition()`

Private helpers handle AI, phase transitions, scoring, and special card behavior.

## Phase Ownership

Phase flow is centralized in these methods:

- `processAutomaticTurns()` - loops through automatic AI planning, swap, trick, and assignment turns.
- `advanceFromPlanning()` - enters swap or trick after trump selection.
- `resolveCurrentTrick()` - determines winner and enters assignment.
- `advanceAfterAssignments()` - either returns to trick or ends the year.
- `performRequisition()` - records requisition events and exiled cards.
- `transitionToNextYear()` - resets year state, reveals jobs, deals hands, or finishes game.
- `finishGame()` - calculates final scores and winner.

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

AI is deterministic for a given seed and implemented directly in `KolkhozEngine`:

- Trump: pick the suit with the strongest hand score.
- Swap: trade the lowest hand card for a significantly better plot card.
- Trick: play the lowest legal card, unless trying to win a late first trick.
- Assignment: choose the highest-priority legal suit and assign all trick cards there.

There is no MCTS or boardgame.io AI in the Swift implementation.

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
- Card play animation events are emitted.
- A deterministic game can reach `gameOver`.
