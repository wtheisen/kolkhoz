# Claude Code Guidelines

## Before You Start

Read the agent documentation in `agent-docs/`:
1. `OVERVIEW.md` - Project structure and quick start
2. `ARCHITECTURE.md` - How the codebase is organized
3. `GAME_STATE.md` - State shape and state mutations
4. `PHASES.md` - Game phase flow and transitions

## Code Principles

**Keep it simple.** This is a card game, not enterprise software. Prefer straightforward solutions over clever abstractions.

**Follow the frameworks:**
- **C engine** - Keep rules, legal actions, phase flow, and scoring in `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/`.
- **SwiftUI** - Keep app state in `GameStore`; views render state and call store actions.
- **Swift Package Manager/XcodeGen** - Keep package and project wiring in sync.

**Write minimal code:**
- Fix what's broken, don't refactor what works
- No premature abstractions or "just in case" code
- If three lines work, don't write a utility function
- Delete dead code, don't comment it out

**Test before committing:**
```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
```

## Frontend Work

Use the iOS/SwiftUI UI skills when changing app screens or layout. The current SwiftUI
app is the visual reference for future downloadable clients.

## Common Patterns

**Game logic** goes in `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/`.

**Swift models and adapters** go in `ios/KolkhozSwiftUI/Sources/KolkhozCore/`.

**UI components** go in `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/`.

**State changes** happen by applying portable engine actions through the C adapter or
online session. Views should not mutate `KolkhozState` directly.

## When Debugging

Check the phase flow in `agent-docs/PHASES.md`. Most bugs are phase transition issues,
snapshot/adaptation issues, or UI state that drifted from the C engine.
