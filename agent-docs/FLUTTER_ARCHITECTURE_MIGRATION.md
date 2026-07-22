# Flutter Ownership Architecture Migration

## Objective

Convert the Flutter app from its flat, session/channel-heavy source layout into a
feature-owned hierarchy that mirrors runtime ownership. Delete the old architecture
instead of retaining compatibility shims. The C engine remains the sole rules authority
for local play and the server's C engine remains authoritative for online play.

## Implementation Status

Completed on 2026-07-22. Production Dart source is rooted beneath `lib/src/app/`;
the legacy session/channel stack and flat compatibility files were deleted. The app now
uses one shared `RemoteConnection`, feature-owned remote connections, and a
`GameController` that stores one typed `GameEngine` implemented by `LocalGameEngine` or
`RemoteGameEngine`. Main-menu and game surfaces are normal imported Dart libraries with
no production `part` coupling.

The deterministic verification gates pass: C syntax, policy asset synchronization,
Flutter analysis, targeted engine/transport/controller/profile tests, macOS debug build,
and the eight-game research engine smoke test. The repository-wide Flutter run reaches
302 passing tests but is not green in this checkout because two golden baselines are
absent, another golden suite differs from its stored images, the bundled neural-policy
test exceeds its 30-second timeout, and two lobby tests use an ambiguous text finder.
The tournament lobby test also fails only in the combined run and passes when isolated.

## Target Ownership Tree

```text
app/lib/src/app/
├── app.dart
├── remote_connection/
│   ├── remote_connection.dart
│   ├── remote_status.dart
│   ├── remote_error.dart
│   └── push_remote_connection.dart
├── settings/
│   ├── settings.dart
│   ├── settings_store.dart
│   ├── animation_speed.dart
│   └── game_sound.dart
├── profile/
│   ├── models/
│   ├── views/
│   └── profile_controller/
│       ├── profile_controller.dart
│       ├── profile_remote_connection.dart
│       ├── player_identity.dart
│       ├── progression.dart
│       └── commerce.dart
└── views/
    ├── shared/
    ├── main_menu/
    │   ├── main_menu_view.dart
    │   ├── main_menu_controller/
    │   │   ├── menu_remote_connection.dart
    │   │   └── menu_remote_models.dart
    │   ├── create_game/
    │   ├── join_game/
    │   └── settings/
    └── game/
        ├── game_view.dart
        ├── game_controller/
        │   ├── game_controller.dart
        │   ├── game_engine.dart
        │   ├── models/
        │   ├── local_game_engine/
        │   │   ├── local_game_engine.dart
        │   │   ├── c_engine_bridge.dart
        │   │   ├── c_engine_action_codec.dart
        │   │   ├── local_game_projection.dart
        │   │   ├── game_undo_snapshot.dart
        │   │   ├── saved_game_store.dart
        │   │   └── policy_model.dart
        │   └── remote_game_engine/
        │       ├── remote_game_engine.dart
        │       ├── game_remote_connection.dart
        │       ├── game_state_models.dart
        │       ├── game_session_models.dart
        │       └── game_realtime.dart
        └── views/
            ├── brigade/
            ├── fields/
            ├── north/
            ├── plots/
            ├── game_log/
            ├── settings/
            └── components/
```

Directories containing only one small file are optional. They should be created when a
real owned subsystem exists, not merely to make the tree symmetrical.

## Ownership Rules

1. A file lives beneath the narrowest component that owns its lifecycle.
2. The root `RemoteConnection` owns shared authenticated transport and application
   heartbeat, not feature endpoints.
3. Menu, profile, and active-game remote protocols live beneath the controller or engine
   that operates them.
4. `GameController` owns at most one `GameEngine`; it replaces the local engine with a
   remote engine only at the explicit online-authority handoff.
5. `LocalGameEngine` owns the native engine pointer, local AI routing, undo, local
   projection, and autosave inputs.
6. `RemoteGameEngine` owns the redacted remote match cache and presentation ordering;
   its `GameRemoteConnection` owns match HTTP/WebSocket protocol state.
7. Game views render projected models and report game intent through controller callbacks.
   They do not call FFI or own remote transports.
8. Feature remote calls use the connection owned by that feature; there is no global
   online client.
9. Use normal Dart imports. Remove `part` relationships as feature modules become
   independent.
10. Shared values live at the nearest common owner. Avoid a global `shared` dumping
    ground.

## Runtime Ownership

### Application

`app.dart` owns the current application destination and optional active `GameController`.
The settings store, profile runtimes, and `RemoteConnection` are application-scoped
collaborators created there.

### Remote transport

`RemoteConnection` owns the base URL, access-token provider, device identity, shared HTTP
client, WebSocket construction, connectivity status, error translation, and application
presence heartbeat. It is kept alive while the application is alive.

`MainMenuRemoteConnection`, `ProfileRemoteConnection`, and `GameRemoteConnection` use the
root connection but own their feature protocols and models. `GameRemoteConnection` is
created for one online match and disposed when that match ends or is left.

### Game

`game_engine.dart` defines the small `GameEngine` interface consumed by
`GameController`. The controller owns presentation state, selections, active surface,
animation acknowledgements, and the game-over transition.

`LocalGameEngine` and `RemoteGameEngine` implement the same application-facing contract.
Local authority is the native C pointer. Remote authority is the server; the remote
engine contains only a redacted, ordered client projection.

## Dependency Direction

```text
app.dart
  ├── RemoteConnection
  ├── SettingsStore
  ├── profile controllers
  └── GameController

AppView -> immutable app state + callbacks
MainMenuView -> immutable menu state + callbacks
GameView -> GameViewModel + GameController callbacks

GameController -> GameEngine contract
LocalGameEngine -> local C-engine internals
RemoteGameEngine -> owned GameRemoteConnection
GameRemoteConnection -> application RemoteConnection
```

Forbidden dependencies:

```text
widget -> raw remote DTO
widget -> HTTP/WebSocket
widget -> C FFI
widget -> settings/profile persistence
LocalGameEngine -> RemoteConnection
RemoteGameEngine -> C FFI
RemoteConnection -> Flutter view
feature A -> feature B's private remote connection
```

## Current-to-Target Mapping

| Current source | Target owner |
|---|---|
| `kolkhoz_app.dart` | `app.dart`, `app_controller.dart`, `app_view.dart` |
| `online_game_client.dart` | root transport plus menu/profile/game remote connections |
| `online_game_models.dart` | feature-owned remote model files |
| `app_settings.dart` | settings model/controller/store plus profile-owned values |
| `player_identity.dart` | profile controller subtree and profile settings view |
| `commerce.dart` | profile controller subtree |
| `push_notifications.dart` | root remote connection subtree |
| `game_controller.dart` | nested game controller and `GameEngine` contract |
| `game_engine.dart` | local game engine implementation |
| `local_game_session.dart` | local game engine orchestration |
| `game_channel_local.dart` | folded into local game engine |
| `online_game_session.dart` | remote game engine presentation behavior |
| `game_channel_online.dart` | game remote connection |
| `game_channel_online_realtime.dart` | remote game engine realtime helper |
| `local_game_projection.dart` | local game engine subtree |
| `online_table_projection.dart` | remote game engine subtree |
| `board_view.dart` | `game_view.dart` plus independently owned game surfaces |
| `board/*` | corresponding `game/views/*` subtrees |
| `lobby/*`, `online_lobby_panel.dart` | main-menu view subtrees |

## Conversion Phases

### Phase 1: Move shared remote transport

- Move authenticated HTTP, WebSocket construction, connectivity, and heartbeat behavior
  directly into the application-scoped `RemoteConnection`.
- Move menu/profile/game endpoint implementations into their final feature owners.
- Move callers in the same slice and delete the superseded methods and types.
- Do not add export shims, compatibility constructors, or delegation wrappers for the old
  architecture.

Gate: existing online model, retry, push, identity, and commerce tests pass.

### Phase 2: Unify game authority

- Define `GameEngine` in `game_controller.dart`.
- Adapt the native `GameEngine` and local-session behavior into `LocalGameEngine`.
- Remove the local in-memory channel after behavior is covered by the local engine.
- Introduce `RemoteGameEngine` around existing online session behavior.
- Move match polling/realtime behavior behind its owned `GameRemoteConnection`.
- Replace `_localSession` and `_onlineSession` with one `_engine` in `GameController`.

Gate: local engine tests, online action retry tests, parity gates, terminal-record tests,
and controller/widget tests pass.

### Phase 3: Extract application owners

- Keep destination and active-game ownership in the application composition root.
- Split settings persistence from setting values.
- Move identity, progression, commerce, and cloud synchronization beneath profile.
- Move presence heartbeat from the root widget to `RemoteConnection`.
- Move menu protocols beneath the main-menu controller directory.

Gate: settings, profile, identity, commerce, push, lobby, and store tests pass.

### Phase 4: Move into the nested tree

- Move one owner at a time and update all production and test imports immediately.
- Move private engine details beneath their owning engine.
- Move remote models to the feature connection that parses them.
- Delete the old files as part of the same owner move.

Gate after every owner move: `flutter analyze` and its targeted tests pass.

### Phase 5: Make views independent

- Replace main-menu `part` files with imported standalone widgets.
- Split `KolkhozBoard` into the game shell and owned surface modules.
- Move brigade, fields, north, plots, log, settings, and end-game views beneath their
  feature directories.
- Pass immutable presentation values and callbacks rather than parent-private state.

Gate: widget tests and screenshot/golden tests pass with no intentional visual changes.

### Phase 6: Remove the old architecture

- Delete session/channel compatibility classes after all callers use engines and feature
  connections.
- Delete legacy flat-path export shims.
- Keep remote DTO definitions beside the remote engine until feature-specific models are
  worth extracting; do not reintroduce a global client to share them.
- Update `agent-docs/ARCHITECTURE.md`, `OVERVIEW.md`, and file references.
- Confirm no rules or phase logic moved out of the C engine.

Final gate:

```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
cd app
dart run tool/sync_policy_assets.dart
flutter analyze
flutter test
flutter build macos --debug
cd ..
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

## Migration Safety

- No gameplay behavior changes are included in this migration.
- No server API changes are required merely to reorganize the Flutter client.
- New owners receive the real implementation; do not preserve obsolete architectural
  layers merely to keep old imports working.
- Avoid broad file moves while a behavioral seam is still changing.
- Do not mix visual redesign with view extraction.
- Delete superseded code as soon as its callers have moved.
- Preserve online revision ordering and presentation acknowledgement semantics exactly.
- Preserve native engine disposal and cloned-engine undo ownership exactly.

## Completion Criteria

- The production Flutter source is rooted under `lib/src/app/` according to the target
  ownership tree.
- The application has one shared `RemoteConnection` and feature-owned remote protocols.
- `GameController` owns one local or remote `GameEngine` through one contract.
- The old local/online session and channel hierarchy is removed.
- Main-menu and game views are independent imported modules with no `part` coupling.
- FFI types stay behind the local game engine and its projections.
- Analysis, targeted behavior tests, engine smoke tests, and the macOS build pass. Golden
  suites additionally require their checked-in baselines to be present.
