# Kolkhoz Architecture

The C engine under `engine/KolkhozCEngine/` is the source of truth for rules, legal
actions, phase flow, AI, scoring, policy features, and deterministic simulation. The
Flutter app in `clients/flutter_app/` is the primary app surface and binds to the engine
through Dart FFI. The research harness in `research/` binds to the same engine through
Python `ctypes`. The online runtime in `server/` uses the same C engine behind its
durable session/event model. Keep the architecture organized around those four owners.

The legacy web app and transitional native Apple app have been removed. Current and future
clients should not derive architecture from those retired implementations.

## Directory Structure

```text
kolkhoz/
├── engine/
│   └── KolkhozCEngine/
│       ├── KolkhozCEngine.c
│       └── include/
│           └── KolkhozCEngine.h
├── clients/
│   └── flutter_app/
│       ├── lib/
│       ├── ios_resources/
│       ├── ios/
│       ├── macos/
│       ├── native/
│       └── test/
├── research/
│   ├── kolkhoz_research/
│   ├── configs/
│   ├── dashboard/
│   └── runs/                  # ignored local experiments and candidate outputs
├── server/
│   ├── kolkhoz_server/        # authoritative online runtime
│   ├── deploy/                # production and staging operations
│   └── tests/                 # contracts, concurrency, and failure gates
├── training/
│   └── rl/runs/               # ignored legacy promoted/baseline JSON models
├── agent-docs/
└── README.md
```

## Module Responsibilities

### `engine/KolkhozCEngine`

Portable C rules engine. This is the runtime rules implementation for local play,
server sessions, research simulation, policy features, legal actions, automatic AI
turns, and scoring.

### `clients/flutter_app`

Standalone Flutter client backed by the C engine. It renders Dart runtime models
projected from the engine, owns app assets, and should not depend on JSON presentation
contracts, retired platform models, token files, or fixture repositories.

Important files:

| File | Purpose |
|------|---------|
| `lib/src/c_engine_bridge.dart` | Dart FFI bindings to the C API |
| `lib/src/live_game_store.dart` | Local/online app store and stepwise engine advancement |
| `lib/src/table_view_projection.dart` | C engine state to Flutter table model |
| `lib/src/online_game_models.dart` | Dart online API models/client |
| `lib/src/board/` | Board panels and controls |
| `ios_resources/` | Pixel art, cards, icons, chrome, fonts |

### `research`

Python research harness for engine smoke tests, C MLP training, Torch/MPS training,
paired benchmarks, model-pool tournaments, seed mining, dashboard views, and artifact
cleanup.

Important files:

| File | Purpose |
|------|---------|
| `kolkhoz_research/c_engine.py` | Builds/loads the C engine shared library with `ctypes` |
| `kolkhoz_research/cli.py` | Main research command surface |
| `kolkhoz_research/benchmark.py` | Paired candidate-vs-baseline and tournament logic |
| `kolkhoz_research/training.py` | C MLP training path |
| `kolkhoz_research/torch_policy.py` | Torch/MPS training and benchmark path |

### `server`

Authoritative online runtime. It owns the Flutter-compatible HTTP/WebSocket API,
single-owner partitioned game execution, PostgreSQL event persistence and fencing,
Redis command/realtime transport, matchmaking, deadlines, population, social/results
services, and deployment. Game rules remain in the C engine; do not add a parallel
Python rules implementation.

### Generated And Historical Artifacts

Generated tool output is intentionally outside the active architecture. Flutter build
directories, Dart tool state, Xcode ephemeral files, Python caches, `research/.build/`,
and the local `clients/flutter_app/native/macos/libkolkhoz_c_engine.dylib` are
regenerable.

`research/runs/` and `training/rl/runs/` are ignored, but they are not arbitrary caches.
Research history, configs, and scripts may reference specific model files there as
baselines or opponents. Use the research artifact cleanup CLI before deleting run or
model files.

## App Data Flow

```text
User gesture in Flutter
    |
    v
LiveGameStore action
    |
    v
Dart FFI C action
    |
    v
C engine applies the move and advances automatic steps
    |
    v
TableViewProjection copies C state into Dart model objects
    |
    v
Flutter re-renders views
```

Flutter widgets do not mutate game state directly. They call the store, which submits
portable C-engine actions and publishes a new projected model.

## Research Data Flow

```text
Python CLI
    |
    v
CEngine ctypes wrapper
    |
    v
C engine simulations, legal actions, object tokens, action features
    |
    v
C MLP or Torch/MPS model backend
    |
    v
benchmarks, tournaments, run records, dashboard output
```

## Engine Pattern

The C API exposes:

- engine allocation/init/free;
- legal action enumeration;
- manual and automatic action application;
- state accessors for Flutter projection;
- policy action features and object tokens for research;
- deterministic benchmark and policy-matchup entrypoints.

Add C API surface only when a real Flutter or research caller needs it.

## Phase Ownership

Phase flow is owned by the C engine. Keep Flutter phase logic limited to rendering the
current phase and exposing available actions. Keep research code limited to consuming C
legal actions and features.

## UI Architecture

`KolkhozBoard` chooses action surfaces from the projected table phase, while users can
manually switch panels with the board rail:

- `game`: player columns, trick slots, and hand tray.
- `jobs`: work gauges and assignment UI.
- `plot`: swap UI, requisition plot view, or normal plot overview.
- `north`: exiled card history by year.
- `options`: in-game menu and rules.

Animation belongs to Flutter. The C engine should stay unaware of animation speed,
motion targets, or view timing.

## AI And Training

Runtime heuristic AI is deterministic for a given seed and implemented in the C engine.
Research models train and evaluate against C-engine simulations. Do not add a parallel
Dart or Python rules implementation.

Historical JSON policies under `training/rl/runs/` exist only as model inputs for the
current research harness. New training code, benchmark logic, dashboards, and promotion
records belong under `research/`.

## Verification

```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
```

```bash
cd clients/flutter_app
flutter analyze
flutter test
flutter build macos --debug
```

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```
