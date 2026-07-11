# Kolkhoz Greenfield Server

This directory is an isolated implementation of the server shape intended for
large concurrent populations. It does not import or wrap the legacy
`online_server.py` or `online_store.py` runtime.

The hot path has four boundaries:

1. `gateway.py` accepts transport requests and contains no game rules.
2. `runtime.py` hashes each session to one worker shard. A shard is a
   single-threaded mailbox, so commands for one game are ordered without locks.
3. `engine.py` adapts the authoritative C engine. An engine instance is owned by
   one shard and can be rebuilt by replaying durable actions.
4. `store.py` commits actions with an expected revision. Process memory is a
   cache; SQLite is used for the executable vertical slice, while the contract
   is deliberately compatible with a pooled PostgreSQL implementation.

`events.py` is the realtime boundary. Gateways subscribe to committed session
events and can expose them through WebSockets or another push transport without
coupling connections to game workers.

## Run

From the repository root:

```bash
python3 -m server.kolkhoz_server.gateway --database /tmp/kolkhoz-server.sqlite3
```

Create and inspect a game:

```bash
curl -s -X POST http://127.0.0.1:8790/games \
  -H 'content-type: application/json' \
  -d '{"seed":42}'

curl -s http://127.0.0.1:8790/games/GAME_ID
```

The action endpoint accepts the existing portable engine action JSON plus the
client's expected revision:

```text
POST /games/{session_id}/actions
{"expectedRevision": 0, "action": {...}}
```

## Verify

```bash
python3 -m unittest discover -s server/tests -v
```

The tests prove ordering within a game, concurrency across shards, optimistic
revision conflicts, event delivery, and recovery by action replay after a
runtime restart.
