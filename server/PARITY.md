# Production parity inventory

Audit snapshot: 2026-07-11. The route inventory is derived from the legacy
`research/kolkhoz_research/online_server.py` router and the Flutter-compatible
contracts in this directory.

An `[x]` route means the canonical route resolves and has an executable gateway-level
contract test. It does **not** by itself prove every legacy side effect. Behavioral
status and remaining retirement blockers are listed separately below and in
`PARITY_GAPS.md`.

## Infrastructure

- [x] Stable session-to-shard routing and ordered, bounded shard mailboxes
- [x] Concurrent execution across shards
- [x] Expected-revision action commits and fenced PostgreSQL session leases
- [x] Authoritative C-engine recovery by durable action replay
- [x] Post-commit Redis publication and revision-based reconnect catch-up
- [x] Flutter WebSocket migration contract with durable reconnect semantics
- [x] One Redis subscription multiplexer per gateway with bounded client buffers
- [x] Shared, bounded PostgreSQL connection pool
- [x] ASGI HTTP/WebSocket process and deployment wiring
- [x] Durable Redis Streams command transport primitives, retries, deduplication, and DLQ
- [x] Production engine mutations routed through the cross-host command transport
- [x] Atomic durable receipts for create/action/delete/controller commands
- [x] Clean, repeatable PostgreSQL bootstrap smoke gate
- [x] Multi-process PostgreSQL/Redis/gateway/worker/scheduler failure-injection gate
- [ ] Sustained 10K/100K staging soak and regional-failure release gate

## Public and authenticated routes

- [x] `GET /health`
- [x] `GET /metrics`
- [x] `POST /presence`
- [x] `POST /active-session/sync`
- [x] `GET /leaderboard`
- [x] `GET /profiles/{userID}`
- [x] `GET /comrades`
- [x] `POST /comrades`
- [x] `POST /comrades/respond`
- [x] `POST /comrades/remove`

## Session routes

- [x] `GET /sessions`
- [x] `POST /sessions`
- [x] `GET /sessions/invites`
- [x] `POST /sessions/matchmake`
- [x] `GET /sessions/{session}`
- [x] `POST /sessions/{session}/invites`
- [x] `POST /sessions/{session}/invites/decline`
- [x] `POST /sessions/{session}/join`
- [x] `POST /sessions/{session}/players/{player}/leave`
- [x] `POST /sessions/{session}/players/{player}/kick`
- [x] `GET /sessions/{session}/state`
- [x] `GET /sessions/{session}/actions`
- [x] `GET /sessions/{session}/players/{player}/actions`
- [x] `POST /sessions/{session}/actions`
- [x] `POST /sessions/{session}/reactions`

## Session behavior

- [x] Fail-closed Supabase bearer verification with a bounded short-lived cache
- [x] Seat-token issuance, hashing, authentication, and last-seen tracking
- [x] Invite-code lookup and case normalization
- [x] Lobby countdown and start transition
- [x] Comrade-only invitations and private-session authorization
- [x] Ranked matchmaking selection and rating proximity
- [x] Stable profile bots and independently leased population scheduler
- [x] Heuristic and policy AI automatic turns
- [x] Reactions and bounded, per-viewer incremental updates/resync
- [x] Indexed deadline claims, timeout strikes, autopilot, abandonment, and bans
- [x] Active leave penalties and pre-start empty-lobby expiry
- [x] Finished-game statistics, ratings, progression, and idempotency boundary
- [x] Crash recovery with identical authoritative C-engine state
- [x] Privacy-safe per-viewer snapshots and updates
- [x] Device lease enforcement that rejects an active-game takeover from another device
- [x] Production startup fails closed when Supabase auth configuration is absent
- [x] Atomic kick, last-seat leave/delete, abandonment, and finished-result transactions

## Route inventory caveat

`GET /leaderboard` and `GET /profiles/{userID}` are in the greenfield canonical matrix,
but were not routed by the audited legacy router. They are additive Flutter/public API
operations, not evidence of parity for the 23 legacy-routed operations.

The current Flutter app still consumes Supabase `game_updates`. The required transport
migration is specified in `FLUTTER_REALTIME_MIGRATION.md`; the server intentionally does
not dual-write the legacy Supabase session authority.
