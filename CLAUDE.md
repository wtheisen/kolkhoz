# Claude Code Guidelines

## Before You Start

Read the agent documentation in `agent-docs/`:
1. `OVERVIEW.md` - Project structure and quick start
2. `ARCHITECTURE.md` - How the codebase is organized
3. `GAME_STATE.md` - State shape and state mutations
4. `PHASES.md` - Game phase flow and transitions

## Code Principles

**Keep it simple.** This is a card game, not enterprise software. Prefer straightforward
solutions over clever abstractions.

**Follow the current owners:**
- **C engine** - Keep rules, legal actions, phase flow, AI, scoring, policy features, and deterministic simulation in `engine/KolkhozCEngine/`.
- **Flutter** - Keep app state, layout, animation, controls, and assets in `clients/flutter_app/`.
- **Research** - Keep training, benchmarking, promotion gates, seed mining, and dashboards in `research/`.

**Write minimal code:**
- Fix what's broken, don't refactor what works
- No premature abstractions or "just in case" code
- If three lines work, don't write a utility function
- Delete dead code, don't comment it out

**Test before committing:**
```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
cd clients/flutter_app
flutter analyze
flutter test
flutter build macos --debug
```

For research changes:
```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

## Frontend Work

Use Flutter/web UI skills when changing app screens or layout. The Flutter app is the
visual and behavioral app source of truth.

## Common Patterns

**Game logic** goes in `engine/KolkhozCEngine/`.

**Flutter models, adapters, and UI** go in `clients/flutter_app/lib/`.

**Flutter assets** go in `clients/flutter_app/ios_resources/`.

**Research and model training** go in `research/`.

**State changes** happen by applying portable engine actions through the Dart FFI bridge.
Flutter widgets should render projected state and call store actions.

## When Debugging

Check the phase flow in `agent-docs/PHASES.md`. Most bugs are phase transition issues,
C snapshot/projection issues, or Flutter UI state that drifted from the C engine.
