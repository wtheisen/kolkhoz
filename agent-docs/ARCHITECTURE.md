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
| `lib/src/app/app.dart` | Application composition and top-level Flutter widget |
| `lib/src/app/navigation/app_navigation_controller.dart` | Destination, settings-section, game-return, and tutorial navigation state |
| `lib/src/app/remote_connection/remote_connection.dart` | Application-owned authenticated HTTP/WebSocket transport and heartbeat |
| `lib/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart` | Session-browser refresh, tournament state, invitation polling, and menu workflow state |
| `lib/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart` | Menu, browser, leaderboard, tournament, and replay endpoints |
| `lib/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart` | Browser, invitation, tournament, challenge, replay, and server-status contracts |
| `lib/src/app/profile/profile_controller/profile_remote_connection.dart` | Profile, social, identity, and account endpoints |
| `lib/src/app/profile/profile_controller/profile_controller.dart` | Identity startup, profile synchronization, comrades mutations, recent games, and account-operation state |
| `lib/src/app/profile/models/profile_remote_models.dart` | Player-profile, comrade, and social response contracts |
| `lib/src/app/views/game/game_controller/game_controller.dart` | Game lifecycle facade and engine selection |
| `lib/src/app/views/game/game_controller/game_engine.dart` | Shared local/remote runtime contract for mode, projection, actions, and disposal |
| `lib/src/app/views/game/game_controller/game_presentation_transition.dart` | Controller-owned queued transition between two projected table models |
| `lib/src/app/views/game/game_controller/models/engine_values.dart` | Engine-neutral cards, actions, variants, controllers, and portable numeric protocol values |
| `lib/src/app/views/game/game_controller/models/game_serialization.dart` | Engine-neutral JSON encoding for variants, controllers, cards, and actions |
| `lib/src/app/views/game/game_controller/local_game_engine/local_game_engine.dart` | Local action routing, AI pacing, undo, projection, and autosave cadence |
| `lib/src/app/views/game/game_controller/local_game_engine/local_game_engine_factory.dart` | Local player composition, native-engine construction, autosave restoration, and policy ownership |
| `lib/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart` | Exclusive native C-engine lifecycle, actions, and cloning |
| `lib/src/app/views/game/game_controller/remote_game_engine/remote_game_engine.dart` | Online authoritative state, revision ordering, reactions, and rollback |
| `lib/src/app/views/game/game_controller/remote_game_engine/remote_game_engine_factory.dart` | Remote-engine construction from the game connection |
| `lib/src/app/views/game/game_controller/remote_game_engine/game_remote_connection.dart` | Per-match HTTP/WebSocket protocol |
| `lib/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart` | Active-match action and projected engine snapshot contracts |
| `lib/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart` | Active-session updates, presence, reactions, series, and revision contracts |
| `lib/src/app/views/game/game_controller/models/` | Lobby, UI, projection, table, terminal-record, and replay models |
| `lib/src/app/views/game/game_view.dart` | Active-game shell |
| `lib/src/app/views/game/views/components/card_motion_plan.dart` | Pure card-zone change planning and immutable staged motion instructions |
| `lib/src/app/views/game/views/` | Independently imported brigade, fields, north, plots, log, settings, and component views |
| `lib/src/app/views/main_menu/` | Independently imported create, join, settings, leaderboard, and lobby views |
| `lib/src/app/profile/` | Profile values, identity, progression, commerce, and profile views |
| `lib/src/app/views/main_menu/settings/` | Settings composition plus separate profile, account, comrades, rules, and admin view owners |
| `lib/src/app/settings/` | Application settings, persistence, animation timing, and sound |
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
app.dart owns application composition, settings, and RemoteConnection
    |
    +-- AppNavigationController  -> destinations, settings section, and game return path
    +-- MainMenuController       -> session browser, tournaments, and invitations
        +-- MenuRemoteConnection -> menu/profile-independent endpoints
    +-- ProfileController        -> identity, profile sync, comrades, and recent games
        +-- ProfileRemoteConnection -> profile/social endpoints
    +-- GameRemoteConnection     -> one active online match
    |
    v
GameController owns a lobby, four GamePlayers, and exactly one optional GameEngine
    |
    +-- LocalGameEngine  --> one NativeGameEngine --> C engine
    |
    +-- RemoteGameEngine --> GameRemoteConnection --> server C engine
    |
    v
GameController queues committed projected updates and publishes one transition at a time
    |
    v
Flutter derives an immutable CardMotionPlan, runs its stages, and completes the
current controller-owned transition
    |
    +-- game over -------------> FinishedGameLobby snapshot
```

Flutter widgets do not mutate game state or call FFI directly. They report intent to the
controller and render its projected state. `GameController` stores one `GameEngine` and
uses that contract for mode, projection, action submission, and disposal. The controller,
not either engine, owns the client update queue, the currently presented model, input
gating, and transition completion. It narrows to `LocalGameEngine` or `RemoteGameEngine`
only for capabilities unique to that runtime, such as local undo/AI pacing or online
presence/reactions. There is no session, runtime, or channel compatibility layer.

Portable game values and serialization live under `game_controller/models/`. Remote
connections and projections depend on those values, never on the local C-engine bridge.
Only the local engine and controller composition may import the native bridge.

`ProfileController` is the application-facing profile API. Its identity runtime and
profile transport are private. It owns debounced profile saves, comrades loading and
mutations, and recent-game loading; app composition only applies loaded values to local
settings. `MainMenuController` owns the session browser's refresh lifecycle and state,
weekly-tournament mutations, invitation polling, and invitation dismissal.
`AppNavigationController` owns application destinations, the selected settings section,
the game's launch origin and return destination, and tutorial visibility. `app.dart`
composes these owners and presents dialogs, but does not duplicate their state in its
widget state.

`LocalGameEngine` routes human, Central Planner, and AI commands directly to its owned
`NativeGameEngine`; it also owns undo snapshots, automatic-step pacing, projection, and
autosave inputs. `LocalGameEngineFactory` owns concrete player adapters, policy loading,
native construction, and autosave replay, so `GameController` does not import those
implementation details. `RemoteGameEngineFactory` similarly owns remote runtime assembly.
`RemoteGameEngine` owns the redacted match projection, selection rollback, reactions,
and authoritative revision ordering. Its
`GameRemoteConnection` owns active-match requests and realtime transport.

Authoritative server revisions and client presentation acknowledgements are deliberately
separate. Local and remote engines emit presentation-neutral committed updates.
`GameController` captures their projected models in a FIFO of
`GamePresentationTransition` values and exposes only the current transition to Flutter.
Completing a transition advances only that controller's local queue; it never blocks the
server, either engine, or another client. Remote transport code does not know about card
flights, animation timing, or assignment choreography.

The controller lifecycle is `lobby -> starting -> playing -> finishing -> finished`. It begins
without an engine. `startGame()` freezes the lobby's four seats and variants and creates
a `LocalGameEngine`; autosave restoration rehydrates that same owner. Online handoff
creates a `RemoteGameEngine`. Spectators remain controller-owned
and never enter the engine or action router. Online lobby/start state remains authoritative
on the server and is mirrored into the client controller through `RemoteGameEngine`.
`OnlineSessionUpdate` remains a transport model. The controller maps its roster once
through `online_lobby_projection.dart`; lobby widgets and table projection consume
`GameSeat`, `PlayerProfile`, and `PlayerPresence` without inspecting wire types or
downcasting players.

The setup screen is a local draft and does not contact the server as seats or variants
change. Tapping **Start Online Game** is the authority handoff: `GameController` freezes
its current `GameLobby`, creates the server session from that single configuration, and
switches to `RemoteGameEngine`. After a successful handoff, lobby membership and match
execution are server-owned; the Flutter controller keeps only presentation and transport
responsibilities. If no online seats are selected, `startGame()` keeps the match entirely
local instead.

`HumanPlayer`, `HeuristicAIPlayer`, and `NeuralAIPlayer` are executable only inside a
`LocalGameEngine`. Online handoff replaces all four with
`ServerGamePlayer` projections populated from the authoritative session update. The local
viewer can submit the server-provided legal actions, but remote humans and AI seats never
choose actions in Flutter. Online Central Planner reveals are advanced and recorded by the
server's automatic router; clients only animate the resulting revision stream.

At game over, the controller captures a `TerminalGameRecord` before disposing the native
pointer. The record stores the seed, frozen variants and controllers, participant
identities, applied engine actions, final result, and build/schema identity. It is the
authoritative audit/replay contract embedded in saved match logs. `FinishedGameLobby`
keeps that record beside a detached final Flutter table model used only for result-screen
presentation. Online games build the same record from the authoritative server action
stream and retain their transport runtime for reactions, rematches, and series updates.

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

Gameplay motion is split by ownership under
`app/lib/src/app/views/game/views/components/`: `card_motion_plan.dart` derives
immutable flight stages, `card_motion_resolver.dart` maps semantic zones to measured
geometry, `card_motion_tracking.dart` owns the frame geometry registry,
`card_flight.dart` renders one flight, and `card_motion.dart` runs plans and reports
presentation completion. Shared timing, curves, and reduced-motion behavior live in
`app/lib/src/app/settings/game_motion.dart`; gameplay widgets should consume that policy
instead of defining local animation durations.

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
