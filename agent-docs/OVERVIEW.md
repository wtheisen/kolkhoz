# Kolkhoz - Agent Quick Start Guide

The authoritative gameplay implementation is the C engine in `engine/KolkhozCEngine/`.
The primary standalone app surface is the Flutter client in `app/`.
The research harness in `research/` talks to the same C engine through `ctypes`.
The authoritative online runtime and deployment live in `server/`. Those are the four
active repo owners: engine, app, server, and research.

The old React/boardgame.io/Vite web app and the transitional native Apple app have been
removed. Do not revive either one, and do not add compatibility layers for retired
client contracts.

## Tech Stack

- **C** - Rules, legal actions, phase flow, AI, scoring, policy features, deterministic simulation.
- **Flutter/Dart** - Standalone app UI, app state, animations, asset presentation, and FFI bridge.
- **Python/PostgreSQL/Redis** - Authoritative online API, durable sessions, distributed commands, and realtime transport.
- **Python/Torch** - Research orchestration, C-engine benchmarks, C MLP training, Torch/MPS training, dashboards.
- **Xcode projects under Flutter** - Apple platform build wrappers for the Flutter app.

## Quick Commands

```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
```

```bash
cd app
dart run tool/sync_policy_assets.dart
./tool/build_c_engine_macos.sh
flutter analyze
flutter test
flutter build macos --debug
```

For a physical iPhone install that can launch from the home screen, never use an iOS
debug build. Use the profile deploy wrapper:

```bash
cd app
./tool/deploy_ios_device_profile.sh
```

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

For the PostgreSQL/Redis-backed online server, configure the environment described in
`server/deploy/README.md`, then run:

```bash
python3 -m server.kolkhoz_server.production
```

## Project Layout

```text
engine/
  KolkhozCEngine/
    KolkhozCEngine.c
    include/KolkhozCEngine.h
app/
  lib/src/app/                   # Ownership-rooted Flutter application
    remote_connection/          # Shared transport and heartbeat
    profile/                    # Profile models, controllers, and views
    settings/                   # Settings values, persistence, sound, timing
    views/main_menu/            # Create, join, settings, and menu controller
    views/game/                 # Game controller, local/remote engines, and views
    views/shared/               # Cross-screen visual primitives
  assets/ui/                     # Pixel art, cards, icons, chrome, fonts
  native/macos/                  # Local C engine dylib for macOS Flutter tests/builds
  tool/build_c_engine_macos.sh
policies/                        # Canonical promoted runtime AI models
research/
  kolkhoz_research/              # Python C-engine wrapper, training, benchmarks
  configs/
  dashboard/
  runs/                          # ignored local runs and candidate outputs
server/                          # Distributed online server and deployment tooling
training/
  rl/runs/                       # ignored legacy promoted/baseline JSON models
agent-docs/
```

Ignored generated output is not source. Rebuild Flutter/Xcode products, Dart tool state,
Python caches, `research/.build/`, and the local macOS C-engine dylib when needed. Do
not delete `research/runs/`, `training/rl/runs/`, or `research/history/current_experiment.json`
as generic cleanup; use `python3 -m research.kolkhoz_research.cli cleanup-artifacts`
so promoted baselines and active/recent research state stay protected.

## Game Flow

1. **Planning** - Reveal jobs and set trump. With Final Year Trump, the leftover fifth-year deal card is revealed for trump; Saboteur means no trump.
2. **Pass (optional)** - When enabled in Custom, players pass one hand card in years 2-5, alternating left then right by year. Default Kolkhoz skips this phase.
3. **Swap** - In years 2-5, each player may swap one hand card with a hidden or revealed plot card when `allowSwap` is enabled.
4. **Trick** - Play 4 tricks in normal years, 3 tricks in famine. Players must follow the lead suit if able.
5. **Assignment** - Every completed trick enters assignment. The brigade leader assigns trick cards to one of the suits present in that trick.
6. **Year end** - After the final trick, remaining hand cards move to hidden plots.
7. **Requisition** - Failed jobs may reveal and exile matching plot cards.
8. Repeat for 5 years. **Highest final plot score wins**.

Default Kolkhoz includes the Saboteur variant. Saboteur is a dedicated `wrecker-0` worker
card that matches every crop suit. It can follow any suit, can make any crop assignment
target legal, adds 0 work hours, and still causes any job bucket containing it to be
processed as failed during requisition.

Default Kolkhoz also enables Final Year Trump, Highest Cards Requisition, and Lotto
Rewards. Passing remains available in Custom games. Lotto job piles contain ranks 1-4
plus one seeded random rank from 5-K
per crop. Highest Cards Requisition takes a vulnerable player's highest cards across all
active failed crops, with a quota equal to the number of those crops; Party Official adds
one and Drunkard removes its crop before the quota is counted.

## Key Files To Read First

1. `engine/KolkhozCEngine/KolkhozCEngine.c` - source rules engine.
2. `engine/KolkhozCEngine/include/KolkhozCEngine.h` - public C API.
3. `app/lib/src/app/app.dart` - Flutter application composition.
4. `app/lib/src/app/navigation/app_navigation_controller.dart` - destination and return-path owner.
5. `app/lib/src/app/remote_connection/remote_connection.dart` - shared transport and heartbeat.
6. `app/lib/src/app/profile/profile_controller/profile_controller.dart` - identity, profile, comrades, and recent-games owner.
7. `app/lib/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart` - browser, tournament, and invitation owner.
8. `app/lib/src/app/views/game/game_controller/game_controller.dart` - game lifecycle and engine selection.
9. `app/lib/src/app/views/game/game_controller/game_engine.dart` - shared local/remote runtime contract.
10. `app/lib/src/app/views/game/game_controller/local_game_engine/local_game_engine_factory.dart` - local runtime construction and restoration.
11. `app/lib/src/app/views/game/game_controller/local_game_engine/local_game_engine.dart` - local match owner.
12. `app/lib/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart` - native C-engine lifecycle.
13. `app/lib/src/app/views/game/game_controller/remote_game_engine/remote_game_engine_factory.dart` - remote runtime construction.
14. `app/lib/src/app/views/game/game_controller/remote_game_engine/remote_game_engine.dart` - remote match owner.
15. `app/lib/src/app/views/game/game_controller/remote_game_engine/game_remote_connection.dart` - match protocol.
16. `app/lib/src/app/views/game/game_controller/models/` - projected and terminal game models.
17. `app/lib/src/app/views/game/game_view.dart` - active-game shell.
18. `app/lib/src/app/views/main_menu/` - create, join, and settings surfaces.
19. `research/kolkhoz_research/c_engine.py` - Python C-engine wrapper.
20. `server/kolkhoz_server/production.py` - production online composition.
21. `research/kolkhoz_research/cli.py` - training and benchmark commands.

## Common Tasks

### Changing Game Rules

1. Update `engine/KolkhozCEngine/`.
2. Update Dart/Python FFI bindings only when the C API or snapshot shape changes.
3. Add or update Flutter/research tests around the changed behavior.
4. Run C syntax check, Flutter tests, and research smoke as relevant.

### Changing Flutter

1. Keep Flutter standalone: bind to the C engine and render Dart runtime models directly.
2. Keep visual constants and assets in Flutter-owned files.
3. Run `flutter analyze`, `flutter test`, and `flutter build macos --debug`.
4. For physical iPhone deploys, run `./tool/deploy_ios_device_profile.sh`; do not use
   `flutter build ios --debug` or `flutter install --debug` for home-screen installs.

### Changing Training Or Benchmarking

1. Keep rules and legal actions in the C engine.
2. Keep orchestration, records, dashboards, and model-backend selection in `research/`.
3. Validate with `python3 -m research.kolkhoz_research.cli engine-smoke --games 8` plus a targeted benchmark/training smoke.

### Cleaning Local Output

1. It is fine to remove ignored build/cache output such as Flutter `build/`,
   `.dart_tool/`, Python `__pycache__/`, `.ruff_cache/`, `node_modules/`, and
   `research/.build/`.
2. Treat model/run directories as research artifacts, not generic caches.
3. Prefer the research cleanup command for run artifacts:
   `python3 -m research.kolkhoz_research.cli cleanup-artifacts --include-files`
   first, then rerun with `--delete` only if the selected files are expected.

### Modifying Phase Transitions

- Update phase flow in `engine/KolkhozCEngine/`.
- Update projections/bindings only if exported C state changes.
- Verify with Flutter tests and a C-engine research smoke.

## Build Notes

The C engine is source of truth. Flutter owns the app UI through Dart visual constants,
assets, and direct C-engine projections. Research tooling should call the C engine
directly; do not add a parallel rules implementation for training.
