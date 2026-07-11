# Production parity inventory

This checklist is derived from the current `research/kolkhoz_research/online_server.py`
router and store. A route is not complete until its response/error contract and
durable behavior are covered by a gateway-level test.

## Infrastructure

- [x] Stable session-to-shard routing
- [x] Single-threaded command ownership within each shard
- [x] Concurrent execution across shards
- [x] Expected-revision durable action commits
- [x] Engine recovery by replay
- [x] Realtime publication boundary with revision catch-up semantics
- [x] PostgreSQL connection pool adapter
- [ ] Distributed realtime adapter
- [x] Metrics and health reporting
- [ ] Production process/deployment wiring

## Public and authenticated routes

- [x] `GET /health`
- [x] `GET /metrics`
- [ ] `POST /presence`
- [ ] `POST /active-session/sync`
- [ ] `GET /leaderboard`
- [ ] `GET /profiles/{userID}`
- [ ] `GET /comrades`
- [ ] `POST /comrades`
- [ ] `POST /comrades/respond`
- [ ] `POST /comrades/remove`

## Session routes

- [ ] `GET /sessions`
- [ ] `POST /sessions`
- [ ] `GET /sessions/invites`
- [ ] `POST /sessions/matchmake`
- [ ] `GET /sessions/{session}`
- [ ] `POST /sessions/{session}/invites`
- [ ] `POST /sessions/{session}/invites/decline`
- [ ] `POST /sessions/{session}/join`
- [ ] `POST /sessions/{session}/players/{player}/leave`
- [ ] `POST /sessions/{session}/players/{player}/kick`
- [ ] `GET /sessions/{session}/state`
- [ ] `GET /sessions/{session}/actions`
- [ ] `GET /sessions/{session}/players/{player}/actions`
- [ ] `POST /sessions/{session}/actions`
- [ ] `POST /sessions/{session}/reactions`

## Session behavior

- [ ] Supabase bearer verification and authenticated-only operations
- [ ] Seat-token issuance, hashing, authentication, and device leases
- [ ] Invite-code lookup and case normalization
- [ ] Lobby countdown and start transition
- [ ] Comrade-only invitations and private-session authorization
- [ ] Ranked matchmaking and rating proximity
- [ ] Server profile bots and population lobbies
- [ ] Heuristic and policy AI automatic turns
- [ ] Reactions and per-viewer incremental updates
- [ ] Turn deadlines, timeout strikes, autopilot, abandonment, and bans
- [ ] Leave/kick rollback and empty-lobby expiry
- [ ] Finished-game statistics, ratings, progression, and idempotency
- [ ] Crash recovery with identical C-engine state
- [ ] Privacy-safe per-viewer state projection
