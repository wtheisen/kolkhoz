# Codex Guidelines

## Before You Start

Read the agent documentation in `agent-docs/`:
1. `OVERVIEW.md` - Project structure and quick start
2. `ARCHITECTURE.md` - How the codebase is organized
3. `GAME_STATE.md` - State shape and state mutations
4. `PHASES.md` - Game phase flow and transitions

### Isolated World-Depth Research

For tasks scoped entirely to `research/world_depth/` that do not modify production
Flutter, engine, server, or Figma assets, read only:

1. `design/field-plan-world/DEPTH_CARD_PIPELINE.md`
2. `research/world_depth/AGENTS.md`
3. `research/world_depth/BRIEF.md`
4. The JSON configuration named by that brief

The four game documents above are not required for those isolated research tasks. If
the work expands into production code or assets, stop and read the normal documentation
before continuing.

For any task that generates raster masters, segments depth, creates or edits depth
cards, changes the Figma world file, or exports world plates, always read
`design/field-plan-world/DEPTH_CARD_PIPELINE.md` even when the task is not otherwise
isolated to `research/world_depth/`.

## Code Principles

**Keep it simple.** This is a card game, not enterprise software. Prefer straightforward
solutions over clever abstractions.

**Follow the current owners:**
- **C engine** - Keep rules, legal actions, phase flow, AI, scoring, policy features, and deterministic simulation in `engine/KolkhozCEngine/`.
- **Flutter** - Keep app state, layout, animation, controls, and assets in `app/`.
- **Server** - Keep the authoritative online API, session execution, persistence, realtime transport, matchmaking, and deployment in `server/`.
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
cd app
dart run tool/sync_policy_assets.dart
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

## iPhone Deployment

Never deploy physical iPhones with Flutter debug builds. On iOS 14+, debug-mode Flutter
apps cannot be launched from the home screen; they only launch from Flutter tooling,
Flutter IDE plugins, or Xcode. For a device install the user can open normally, use:

```bash
cd app
./tool/deploy_ios_device_profile.sh
```

Pass a device id as the first argument only when targeting a different iPhone.

## Common Patterns

**Game logic** goes in `engine/KolkhozCEngine/`.

**Flutter models, adapters, and UI** go in `app/lib/`.

**Flutter assets** go in `app/assets/ui/`.

**Online server behavior and operations** go in `server/`.

**Research and model training** go in `research/`.

**State changes** happen by applying portable engine actions through the Dart FFI bridge.
Flutter widgets should render projected state and call store actions.

## When Debugging

Check the phase flow in `agent-docs/PHASES.md`. Most bugs are phase transition issues,
C snapshot/projection issues, or Flutter UI state that drifted from the C engine.
