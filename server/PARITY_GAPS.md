# Greenfield server parity gaps

Audit snapshot: 2026-07-11. The canonical 25-route surface is executable through
`Gateway` and `OnlineApplication`; `server/tests/test_route_parity.py` proves that each
route dispatches with realistic auth, seat, lobby, social, action, revision, and
reaction inputs. That is route coverage, not full behavioral parity. The gaps below
must be closed before the legacy server can be retired.

## P0: gameplay correctness and durability

| Missing behavior | Legacy evidence | Greenfield owner |
|---|---|---|
| Reject actions and reactions before the lobby starts; validate that the submitted action belongs to the authenticated player and is currently legal. | `online_server.py:2320-2338`, `online_server.py:2361-2366` | `kolkhoz_server/api.py:339-398` currently forwards actions to the engine and accepts reactions without the lobby-start checks. Add command validation inside the shard-owned game/session aggregate, not in a gateway-only precheck. |
| Incremental action polling must return cached, viewer-specific projected updates and a full `resyncUpdate` when the requested revision is outside the cache. It must reject negative/future revisions. | `online_server.py:2381-2418` | `kolkhoz_server/api.py:360-371` currently returns raw event payloads, always returns `resyncUpdate: null`, and accepts unknown revisions. The durable event log plus projection/cache owner should implement this. |
| Persist and restore reactions, seat last-seen state, timeout counts, autopilot/abandonment, turn owner/deadline, bot profiles, lobby countdown, and finished-result idempotency as one recoverable session lifecycle. | `online_server.py:2488-2533`, `online_server.py:3058-3188`, `online_server.py:3239-3329`, `online_server.py:3362-3421` | `kolkhoz_server/lobby.py` persists some read-model fields and reactions; `kolkhoz_server/runtime.py` replays gameplay events only. Define lifecycle domain events and rebuild both gameplay and session aggregate under the same session owner. |
| Wire finished C-engine games into the durable results transaction (stats, ranked/casual rating, progression, achievements, abandonment-adjusted rank), exactly once. | `online_server.py:3362-3421`, `online_store.py:888-1147` | `kolkhoz_server/results.py:73-104` and `:217-293` implement a results boundary, but `OnlineApplication`/`GameRuntime` never call it. Completion needs a game-over event consumer with an idempotency key. |
| Active-game leave must abandon the seat, enable autopilot, persist penalties, continue automatic play, and return `penalty` plus an update. Pre-start leave must return the legacy response and expire an empty player-created lobby. | `online_server.py:1945-1999`, `online_server.py:3131-3150` | `kolkhoz_server/api.py:400-413` always releases the seat and returns only `{left, playerID}`. Put leave semantics in the shard-owned session command and use `results.py` for penalties. |

## P0: multi-instance ownership and failure handling

| Missing behavior | Legacy/current contract evidence | Greenfield owner |
|---|---|---|
| Production requests must acquire/renew a distributed session lease before mutating a game, fence stale owners, and retry or redirect when ownership moves. A process-local hash shard is not sufficient across replicas. | Legacy has only process-local ownership (`online_server.py:2420-2430`), which is the architecture being replaced. | `kolkhoz_server/distributed.py:101-186` has PostgreSQL lease primitives, but `kolkhoz_server/runtime.py:142-267` does not use them. Integrate lease epoch/fencing into every durable commit. |
| Realtime publication must survive gateway/worker separation and reconnect by revision without losing committed events. | Legacy polling contract is `online_server.py:2381-2418`; greenfield objective requires a separate realtime boundary. | `kolkhoz_server/distributed.py:35-99` supplies Redis pub/sub, but production runtime must publish only after commit and clients must catch up from the event store after loss. Pub/sub alone is lossy. |
| Commands accepted by one gateway must reach the current game owner across hosts with bounded retry, backpressure, deduplication, and poison-message handling. | No legacy equivalent; required to scale beyond one process safely. | `kolkhoz_server/distributed.py:207-280` provides deduplication and a bounded in-memory buffer, but there is no durable cross-host command transport wired into `OnlineApplication`. |

## P1: session and lobby parity

| Missing behavior | Legacy evidence | Greenfield owner |
|---|---|---|
| Presence must track `(user, device, session)` leases, return the complete metrics payload plus `activeSession`, and prevent the same account from silently taking over an active game on another device. | `online_server.py:979-1099` | `kolkhoz_server/api.py:80-94`, `:265-285` currently count users and rotate a token from any active row; the device header and `sessionID` body are ignored. Add a durable/TTL presence and device-lease repository. |
| Session join must enforce online bans and private/invite authorization when joining by session ID, while preserving case-insensitive invite-code access. | `online_server.py:1237-1274`, `online_server.py:2638-2651` | `kolkhoz_server/api.py:219-263` claims any open human seat. Add authorization policy before the serialized seat claim; keep normalized invite lookup in `lobby.py`. |
| Invitations must be host-only, pre-start-only, comrade-only, exclude seated users, clear prior declines on reinvite, and decline must return 404 unless an invite is actually pending. | `online_server.py:1276-1358` | `kolkhoz_server/api.py:126-138`, `:319-337` stores arbitrary user IDs and decline is unconditional. Compose `SocialService` authorization with a serialized session invite command. |
| Matchmaking must support `comradesOnly`, online bans, browser visibility, rating bands/order, ranked seed creation, and population/profile-bot filling. | `online_server.py:1360-1492`, `online_server.py:1620-1934` | `kolkhoz_server/api.py:287-317` chooses the first open lobby and ignores `comradesOnly` and ratings. `kolkhoz_server/matchmaking.py` should become the selection owner and operate on indexed durable lobby data. |
| Kick must validate a genuinely occupied human seat and preserve atomic rollback if persistence or lobby synchronization fails. | `online_server.py:2001-2077` | `kolkhoz_server/api.py:415-449` serializes release but does not prove a transaction spans validation, release, countdown reset, and response projection. Implement one repository transaction/session command. |
| Lobby listings and updates must include real player profiles, seat presence, turn owner, and deadline. | `online_server.py:2873-2892`, `online_server.py:3774-3800` | `kolkhoz_server/api.py:451-515` hard-codes `playerProfiles: []`, `turnDeadlineAt: null`, and listing turn fields to null. Populate from the session read model and profile repository. |
| Background deadline processing must query due sessions rather than depend on a client poll; two timeouts trigger autopilot/abandonment and durable ban escalation. | `online_server.py:880-910`, `online_server.py:3282-3329`, `online_store.py:815-887` | `kolkhoz_server/session.py` models timeouts and `results.py` models abandonment, but production needs a due-deadline scheduler feeding fenced session commands. |
| Server population lobbies and stable profile bots must be created/fill seats without global scans, including rating-matched controllers and humanized action pacing. | `online_server.py:647-746`, `online_server.py:1620-1934`, `online_server.py:3196-3237` | `kolkhoz_server/ai.py` owns model selection/automatic actions; add an independently scalable population scheduler and durable bot-profile assignment read model. |

## P1: response and operational parity

| Missing behavior | Legacy evidence | Greenfield owner |
|---|---|---|
| Health must expose deployed git SHA and C-engine SHA; metrics must retain route/store latency, lock/queue pressure replacements, connected seats, presence, policy SHA, and persistence health. | `online_server.py:970-977`, `online_server.py:1104-1142` | `kolkhoz_server/runtime.py:124-140` and `kolkhoz_server/metrics.py`; enrich production probes and define shard/lease/command-lag metrics suitable for autoscaling. |
| Production PostgreSQL must be the only authoritative lobby/event store. SQLite is test/dev only, and schema migration/deploy wiring must start the compatibility application plus distributed dependencies. | Legacy deployment starts one server process; parity target is the new architecture. | `kolkhoz_server/production.py`, `server/postgres_schema.sql`, `server/lobby_schema.sql`, `server/distributed_schema.sql`, and `server/deploy/`. Verify a clean PostgreSQL bootstrap and multi-process smoke test. |

## Route inventory caveat

`GET /leaderboard` and `GET /profiles/{userID}` are present in the greenfield canonical
matrix and are tested here, but they are not routed by the audited legacy
`online_server.py:381-520`. They are additive greenfield API routes, not demonstrated
legacy parity. Keep them only if the Flutter/public API contract actually needs them;
do not count them as evidence that the 23 legacy-routed operations are semantically
complete.
