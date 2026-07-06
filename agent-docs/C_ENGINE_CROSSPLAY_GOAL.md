# C Engine Cross-Play Goal

## Objective

Use the C engine as the authoritative game engine for every Kolkhoz client and service,
then layer Flutter clients and future backend transport on the same portable action and
state model.

## Architecture

```text
C engine
  deterministic rules, legal actions, scoring, state accessors
    |
    v
Bindings
  Dart FFI for Flutter, Python ctypes for research, future server binding
    |
    v
Clients and services
  render projected state, submit portable actions, replay action logs
```

The C engine owns game rules. Clients and servers submit `KCAction`-equivalent actions
and render projected state. No platform should reimplement rules.

## Server Shape

The first production server should be intentionally small:

- HTTP for create/join/session metadata.
- WebSocket or server-sent events for submitted actions and state broadcasts.
- In-memory sessions first, then durable persistence.
- Action-log replay for deterministic recovery.
- Viewer-redacted snapshots for hidden information.

Persistence, matchmaking, accounts, and ratings can come later. The critical first
server milestone is one authoritative process hosting one complete game through the C
engine.

## Client Boundary

The client boundary above C state is a thin per-client projection into local runtime
models. Flutter should project directly from the C engine through Dart FFI; do not add a
JSON presentation contract or fixture repository between the engine and UI.

## Online Work Remaining

- Define the server runtime language/binding around `engine/KolkhozCEngine/`.
- Port or replace the removed transitional HTTP session contract with a C-engine-backed service.
- Keep hidden state server-side and send viewer-redacted snapshots.
- Preserve action-log replay for reconnects.
- Add conformance tests around shared action logs so clients and server stay in sync.
