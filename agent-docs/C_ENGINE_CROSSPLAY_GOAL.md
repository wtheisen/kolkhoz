# C Engine Cross-Play Goal

## Objective

Make the C engine the authoritative game engine for every Kolkhoz client, then layer
offline iOS play, online iOS play, and future downloadable Android/desktop clients on
the same portable action and state model.

## Architecture

```text
C engine
  deterministic rules, legal actions, scoring, snapshots
    |
    v
Platform bindings
  Swift/iOS first, then server, Flutter/Dart FFI for Android and desktop
    |
    v
Clients and server
  render snapshots, submit portable actions, replay action logs
```

The C engine owns game rules. Clients and servers submit `KCAction`-equivalent actions
and render projected state. No platform should reimplement rules once its binding is
ready.

## Execution Plan

1. Port iOS offline play to the C engine.
   - Add a C-backed Swift adapter with the app's move surface.
   - Convert C snapshots into existing `KolkhozState` so the SwiftUI board can migrate
     without a broad UI rewrite.
   - Keep smoke tests around representative C action logs and online sessions.

2. Add iOS online bindings.
   - Treat online play as action submission plus snapshot rendering.
   - Use controller ownership to distinguish local, remote, and AI seats.
   - Add viewer-specific redacted snapshots before exposing hidden state to clients.

3. Add an authoritative server framework.
   - Own game sessions and seat assignment.
   - Validate submitted actions against the C engine.
   - Persist and replay action logs for reconnects.
   - Broadcast per-viewer state updates over a live transport.

4. Expand to other clients.
   - Reuse the C action/state contracts for Flutter Android and desktop bindings.
   - Keep conformance tests around shared action logs so every platform stays in sync.

## Server Shape

The first server should be intentionally small:

- HTTP for create/join/session metadata.
- WebSocket for submitted actions and state broadcasts.
- In-memory sessions at first.
- Action-log replay for deterministic recovery.

Persistence, matchmaking, accounts, and ratings can come later. The critical first
server milestone is one authoritative process hosting one complete game through the C
engine.

## Immediate Slice

Build the C-backed Swift offline adapter first. That gives the iOS app a local source of
truth that already behaves like a future online client: render state, submit portable
actions, and let the engine decide what happens next.

## Offline iOS Migration

Normal offline `GameStore` play is C-backed. Autosave stores the C engine seed,
variants, controllers, and portable action log, then restores by replaying those actions
through the C engine.

Scripted tutorial and preview states use a lightweight `ScriptedGameRuntime` because
they start from handcrafted `KolkhozState` values rather than a C seed/action log. Those
paths are not authoritative gameplay sources.

The next migration target is online binding work: redacted snapshots, session
membership, and a server-owned action log.

## Online Session Foundation

`KolkhozAuthoritativeSession` is the first server-side framework layer. It owns a
C-backed engine, validates submitted portable actions against legal actions, appends the
accepted action log, and returns viewer-redacted snapshots.

`KolkhozEngineSnapshot.redacted(for:)` is the shared client projection boundary. It keeps
the server snapshot authoritative while hiding opponent hands, opponent hidden plots,
future job pile order, accumulated hidden rewards, and non-viewer final scores before
game over.

The next server step is transport: wrap `KolkhozAuthoritativeSession` with HTTP
create/join endpoints and a WebSocket action/update stream.

`KolkhozOnlineSessionService` now provides the in-process server registry for
create/join/state/legal-action/action-submit flows. `KolkhozOnlineClient` is the iOS-side
binding over a `KolkhozOnlineTransport`, with in-memory and HTTP transport
implementations available for tests and future network use.

`KolkhozOnlineServer` hosts the HTTP transport:

```bash
cd ios/KolkhozSwiftUI
PORT=8787 swift run KolkhozOnlineServer
```

Initial endpoints:

- `GET /health`
- `POST /sessions`
- `POST /sessions/{sessionID}/join`
- `GET /sessions/{sessionID}/state?viewerID={playerID}`
- `GET /sessions/{sessionID}/players/{playerID}/actions`
- `POST /sessions/{sessionID}/actions`

Remaining production work is to add a live push stream for updates, such as WebSocket or
server-sent events, so clients do not need to poll state after each turn.
