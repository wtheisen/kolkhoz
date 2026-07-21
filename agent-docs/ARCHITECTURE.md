# Kolkhoz Architecture

The C engine under `engine/KolkhozCEngine/` is the source of truth for rules, legal
actions, phase flow, AI, scoring, policy features, and deterministic simulation. The
Flutter app in `app/` is the primary app surface and binds to the engine
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
├── app/
│   ├── lib/
│   ├── assets/ui/
│   ├── ios/
│   ├── macos/
│   ├── native/
│   └── test/
├── policies/                   # Canonical promoted runtime AI models
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

### `app`

Standalone Flutter client backed by the C engine. It renders Dart runtime models
projected from the engine, owns app assets, and should not depend on JSON presentation
contracts, retired platform models, token files, or fixture repositories.

Important files:

| File | Purpose |
|------|---------|
| `lib/src/c_engine_bridge.dart` | Dart FFI bindings to the C API |
| `lib/src/game_engine.dart` | Exclusive native engine lifecycle, frozen match config, actions, cloning, and Flutter state projection |
| `lib/src/game_state_snapshot.dart` | Portable completed engine state with a versioned JSON representation |
| `lib/src/game_lobby.dart` | Four-seat pre-game configuration and spectator roster |
| `lib/src/online_lobby_projection.dart` | Single online boundary that maps wire roster fields into app-domain seats |
| `lib/src/player_profile.dart` | Transport-independent seated-player profile value |
| `lib/src/player_presence.dart` | Transport-independent seated-player presence value |
| `lib/src/finished_game_lobby.dart` | Immutable final projection, result, roster, variants, log, reactions, and online metadata for postgame UI |
| `lib/src/game_channel.dart` | Shared commands and events consumed by `GameController` |
| `lib/src/game_channel_local.dart` | In-memory channel and exclusive local `GameEngine` ownership |
| `lib/src/game_channel_online.dart` | Active-match HTTP command, retry, refresh, and update transport |
| `lib/src/game_channel_online_realtime.dart` | WebSocket connection, reconnect, and frame decoding |
| `lib/src/game_controller.dart` | Match setup, four-player ownership, action routing, presentation pacing, and local/online state publication |
| `lib/src/player.dart` | Shared `GamePlayer` contract |
| `lib/src/player_human.dart` | Human player adapter for UI-driven decisions |
| `lib/src/player_ai_heuristic.dart` | Deterministic C-engine heuristic player adapter |
| `lib/src/player_ai_neural.dart` | Medium and hard neural-policy player adapter with heuristic fallback |
| `lib/src/player_server.dart` | Read-only server-owned online player adapter |
| `lib/src/game_undo_snapshot.dart` | Controller undo snapshot state and cloned-engine ownership |
| `lib/src/table_view_projection.dart` | C engine state to Flutter table model |
| `lib/src/online_game_models.dart` | Dart online API models/client |
| `lib/src/board/` | Board panels and controls |
| `assets/ui/` | Pixel art, cards, icons, chrome, fonts |

Promoted runtime policy files live in top-level `policies/`. The app copies them into
its ignored asset-staging directory before Flutter builds; the server and research load
the canonical files directly.

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

`server/kolkhoz_server/lobby.py` defines session/seat records and the repository contract;
`lobby_postgres.py` is the only durable lobby implementation. Unit tests use a disposable
in-memory repository under `server/tests/` rather than maintaining a second SQL dialect.
PostgreSQL schema and distributed-stack smoke tests remain the production persistence
gate.

### Generated And Historical Artifacts

Generated tool output is intentionally outside the active architecture. Flutter build
directories, Dart tool state, Xcode ephemeral files, Python caches, `research/.build/`,
and the local `app/native/macos/libkolkhoz_c_engine.dylib` are
regenerable.

`research/runs/` and `training/rl/runs/` are ignored, but they are not arbitrary caches.
Research history, configs, and scripts may reference specific model files there as
baselines or opponents. Use the research artifact cleanup CLI before deleting run or
model files.

## App Data Flow

```text
GameController owns a lobby, four GamePlayers, and one GameChannel
    |
    +-- LocalGameChannel -------> one GameEngine
    |
    +-- OnlineGameChannel ------> HTTP + WebSocket server transport
    |
    +-- Central Planner action --> reward/trump reveal
    |
    +-- HumanPlayer ------------> Flutter interaction
    |
    +-- AI GamePlayer ----------> heuristic or policy decision
    |
    v
GameChannel publishes ordered GameEvents
    |
    v
GameController publishes projected Dart model objects
    |
    v
Flutter re-renders views and acknowledges presentation completion
    |
    +-- game over -------------> FinishedGameLobby snapshot
```

Flutter widgets do not mutate game state or consume forced actions directly. They call
the controller with human actions and render its projected state. The controller sends
portable `GameCommand` objects through its current channel and consumes ordered
`GameEvent` objects. Local, Central Planner, and AI commands use the in-memory channel;
online gameplay commands use the server-backed channel.

Authoritative server revisions and client presentation acknowledgements are deliberately
separate. `OnlineGameChannel` preserves every committed action needed for animation and
publishes only the next presentation-ready state; newer full snapshots wait as deferred
state. A client acknowledgement advances only that channel's local delivery queue; it
never blocks the server or another client.

The controller lifecycle is `lobby -> starting -> playing -> finishing -> finished`. It begins
without a local engine. `startGame()` freezes the lobby's four seats and variants and is
the only new-match path that creates a `GameEngine`; autosave restoration may rehydrate
an existing match directly through `LocalGameChannel`. Spectators remain controller-owned
and never enter the engine or action router. Online lobby/start state remains authoritative
on the server and is mirrored into the client controller through `OnlineGameChannel`.
`OnlineSessionUpdate` remains a transport model. The controller maps its roster once
through `online_lobby_projection.dart`; lobby widgets and table projection consume
`GameSeat`, `PlayerProfile`, and `PlayerPresence` without inspecting wire types or
downcasting players.

The setup screen is a local draft and does not contact the server as seats or variants
change. Tapping **Start Online Game** is the authority handoff: `GameController` freezes
its current `GameLobby`, creates the server session from that single configuration, and
switches to `OnlineGameChannel`. After a successful handoff, lobby membership and match
execution are server-owned; the Flutter controller keeps only presentation and transport
responsibilities. If no online seats are selected, `startGame()` keeps the match entirely
local instead.

`HumanPlayer`, `HeuristicAIPlayer`, and `NeuralAIPlayer` are executable only while a
`LocalGameChannel` owns the engine. Online handoff replaces all four with
`ServerGamePlayer` projections populated from the authoritative session update. The local
viewer can submit the server-provided legal actions, but remote humans and AI seats never
choose actions in Flutter. Online Central Planner reveals are advanced and recorded by the
server's automatic router; clients only animate the resulting revision stream.

At game over, `GameEngine.snapshot()` produces a portable `GameStateSnapshot` before the
controller disposes the native pointer. The controller places that state in a
`FinishedGameLobby` before publishing the `finished` lifecycle. The snapshot owns
everything the result screen, share action, saved log, and postgame panels need, and its
versioned JSON shape is embedded in saved match logs. Online games build the same state
object from the authoritative server projection and retain their transport runtime for
reactions, rematches, and series updates.

The online runtime follows the same ownership boundary. When an authoritative engine
reaches `gameOver`, its shard captures the public immutable final JSON and closes
the C engine immediately. Finished reads, reactions, and result screens use that terminal
snapshot. Durable events remain the restart source of truth; a replacement worker replays
once, captures the same terminal JSON, and releases the reconstructed engine again.

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
cd app
dart run tool/sync_policy_assets.dart
flutter analyze
flutter test
flutter build macos --debug
```

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```
