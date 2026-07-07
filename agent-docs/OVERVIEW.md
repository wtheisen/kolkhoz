# Kolkhoz - Agent Quick Start Guide

The authoritative gameplay implementation is the C engine in `engine/KolkhozCEngine/`.
The primary standalone app surface is the Flutter client in `clients/flutter_app/`.
The research harness in `research/` talks to the same C engine through `ctypes`.
Those are the three active repo owners: engine, app, and research.

The old React/boardgame.io/Vite web app and the transitional native Apple app have been
removed. Do not revive either one, and do not add compatibility layers for retired
client contracts.

## Tech Stack

- **C** - Rules, legal actions, phase flow, AI, scoring, policy features, deterministic simulation.
- **Flutter/Dart** - Standalone app UI, app state, animations, asset presentation, and FFI bridge.
- **Python/Torch** - Research orchestration, C-engine benchmarks, C MLP training, Torch/MPS training, dashboards.
- **Xcode projects under Flutter** - Apple platform build wrappers for the Flutter app.

## Quick Commands

```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
```

```bash
cd clients/flutter_app
./tool/build_c_engine_macos.sh
flutter analyze
flutter test
flutter build macos --debug
```

For a physical iPhone install that can launch from the home screen, never use an iOS
debug build. Use the profile deploy wrapper:

```bash
cd clients/flutter_app
./tool/deploy_ios_device_profile.sh
```

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

For a local-network online play server that the Flutter app can join by URL:

```bash
python3 -m research.kolkhoz_research.cli serve-online --host 0.0.0.0 --port 8787
```

## Project Layout

```text
engine/
  KolkhozCEngine/
    KolkhozCEngine.c
    include/KolkhozCEngine.h
clients/
  flutter_app/
    lib/                         # Flutter runtime, board UI, C FFI projection
    ios_resources/               # Pixel art, cards, icons, chrome, fonts
    native/macos/                # Local C engine dylib for macOS Flutter tests/builds
    tool/build_c_engine_macos.sh
research/
  kolkhoz_research/              # Python C-engine wrapper, training, benchmarks
  kolkhoz_research/online_server.py # Local HTTP online session server for Flutter
  configs/
  dashboard/
  runs/                          # ignored local runs and candidate outputs
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

1. **Planning** - Reveal jobs and set trump. Year 5 is famine: no trump.
2. **Swap** - In years 2-5, each player may swap one hand card with a hidden or revealed plot card when `allowSwap` is enabled.
3. **Trick** - Play 4 tricks in normal years, 3 tricks in famine. Players must follow the lead suit if able.
4. **Assignment** - Every completed trick enters assignment. The brigade leader assigns trick cards to one of the suits present in that trick.
5. **Year end** - After the final trick, remaining hand cards move to hidden plots.
6. **Requisition** - Failed jobs may reveal and exile matching plot cards.
7. Repeat for 5 years. **Highest final plot score wins**.

Default Kolkhoz includes the Saboteur variant. Saboteur is a dedicated `wrecker-14` worker
card that matches every crop suit. It can follow any suit, can make any crop assignment
target legal, adds 14 work hours, and still causes any job bucket containing it to be
processed as failed during requisition.

## Key Files To Read First

1. `engine/KolkhozCEngine/KolkhozCEngine.c` - source rules engine.
2. `engine/KolkhozCEngine/include/KolkhozCEngine.h` - public C API.
3. `clients/flutter_app/lib/src/c_engine_bridge.dart` - Dart FFI bindings.
4. `clients/flutter_app/lib/src/live_game_store.dart` - Flutter game store.
5. `clients/flutter_app/lib/src/table_view_projection.dart` - C state to Flutter model projection.
6. `clients/flutter_app/lib/src/board/` and `clients/flutter_app/lib/src/board_view.dart` - app UI.
7. `research/kolkhoz_research/c_engine.py` - Python C-engine wrapper.
8. `research/kolkhoz_research/cli.py` - training and benchmark commands.

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
