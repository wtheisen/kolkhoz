# Kolkhoz greenfield server

This directory is the independent replacement for the legacy
`research/kolkhoz_research/online_server.py` runtime. It preserves the Flutter-facing
online API while replacing process-wide game locking with partitioned, single-owner
execution. The authoritative game rules remain in the C engine.

The design target includes 10K, 100K, and eventually 1M concurrent connections. Those
figures are capacity goals, not measured production results; see `PARITY_GAPS.md` and
`tools/README.md` for the current evidence boundary.

## Request and state flow

1. `asgi.py` accepts compatibility HTTP requests and authenticated session WebSockets.
2. `api.py` applies route/auth/session contracts without owning game rules.
3. `runtime.py` hashes a session to a bounded, single-threaded mailbox. Commands for one
   game are ordered; unrelated shards run concurrently.
4. `engine.py` owns one authoritative C-engine instance per loaded game. Process memory
   is a disposable cache rebuilt from `store.py`'s revisioned event log.
5. PostgreSQL expected-revision writes and `distributed.py` lease fencing reject stale
   owners. `events.py` publishes only committed revisions.
6. Redis Pub/Sub wakes WebSocket gateways. `distributed.py` multiplexes subscriptions
   through one reader per gateway and bounds each connection buffer; reconnects catch up
   from durable revisions rather than trusting lossy Pub/Sub.

Incremental animation catch-up does not require a sticky gateway. For gaps within the
32-action retention contract, any gateway deterministically replays the durable event
log and applies its local viewer-specific projector after each requested revision. This
keeps private snapshots isolated by viewer. Older gaps return one current full resync;
the cache window and response size therefore remain bounded. This is deterministic
replay, not a claim that long histories have constant replay cost; durable engine
snapshots are a future optimization if game histories grow materially.

`commands.py` implements the intended cross-host Redis Streams command plane, including
partitioning, backpressure, retry, failover claim, result deduplication, and dead-letter
handling. It is tested but is **not yet wired into `production.py`**, so production HTTP
mutations still execute in the gateway's local runtime and rely on PostgreSQL leases.
That is a retirement blocker, documented in `PARITY_GAPS.md`.

## File layout

| Path | Responsibility |
|---|---|
| `kolkhoz_server/asgi.py` | Production HTTP, WebSocket, CORS, reconnect/catch-up transport |
| `kolkhoz_server/gateway.py` | Small threaded SQLite development/test gateway |
| `kolkhoz_server/api.py`, `routes.py` | Flutter-compatible route dispatch and response contracts |
| `kolkhoz_server/runtime.py`, `session.py` | Partitioned session ownership, bounded mailboxes, lifecycle model |
| `kolkhoz_server/engine.py`, `contracts.py` | C-engine adapter, legal actions, privacy-safe projections |
| `kolkhoz_server/store.py` | SQLite reference store, pooled PostgreSQL event store, revision CAS |
| `kolkhoz_server/lobby.py`, `social.py`, `results.py` | Durable session/seat, profile/social, rating/progression read models |
| `kolkhoz_server/distributed.py`, `events.py` | PostgreSQL leases/fencing, Redis realtime multiplexer, bounded buffers |
| `kolkhoz_server/commands.py` | Redis Streams cross-host command transport primitives |
| `kolkhoz_server/ai.py` | Heuristic/policy automatic turns and shared model cache |
| `kolkhoz_server/matchmaking.py`, `population.py` | Indexed matchmaking and independently leased bot-lobby population |
| `kolkhoz_server/scheduler.py` | Indexed, lease-claimed turn deadlines and timeout/autopilot processing |
| `kolkhoz_server/lifecycle.py` | Fenced provisioning/deletion saga reconciliation after process failure |
| `kolkhoz_server/metrics.py`, `observability/` | Bounded Prometheus metrics, starter SLOs, and alerts |
| `kolkhoz_server/production.py` | PostgreSQL/Redis composition and ASGI process lifecycle |
| `*_schema.sql` | Event, lobby, lease, command, and population PostgreSQL schemas |
| `deploy/` | Uvicorn/systemd environment, dependencies, and deployment guide |
| `deploy/staging/` | Real multi-role Compose topology, smoke test, and chaos drill |
| `tools/` | Disposable PostgreSQL schema smoke test and scale/failure harness |
| `tests/` | Contracts, real C replay, concurrency, chaos, transport, and parity tests |

## Run locally

The development gateway uses SQLite and legacy `/games` vertical-slice routes. It is
not the production compatibility transport:

```bash
python3 -m server.kolkhoz_server.gateway \
  --database /tmp/kolkhoz-server.sqlite3
```

Production is intended to use PostgreSQL, Redis, Supabase auth, all schemas, and
Uvicorn. Follow `deploy/README.md`; the process entry point is:

```bash
python3 -m server.kolkhoz_server.production
```

Until the fail-closed auth startup gap in `PARITY_GAPS.md` is fixed, operators must set
both `KOLKHOZ_SUPABASE_URL` and `KOLKHOZ_SUPABASE_PUBLISHABLE_KEY`; omitting them
disables the verifier instead of refusing startup.

The production WebSocket endpoint is:

```text
/sessions/{sessionID}/realtime?viewerID={playerID}&afterRevision={revision}
```

It requires bearer and seat-token headers. Slow/overflowing clients are closed and
must reconnect with their last applied revision.

## Verify

From the repository root:

```bash
ruff check server
python3 -m unittest discover -s server/tests -q
pytest -q server/tests
server/tools/postgres_smoke.sh
python3 -m server.tools.scale_harness \
  --players 10000 --operations 1000 --concurrency 64
```

The Python suites exercise route contracts, per-session ordering, concurrent shards,
revision conflicts, lease fencing/takeover, bounded overload, viewer-safe incremental
updates, Redis fanout behavior, deadline/population claims, command redelivery/DLQ, and
real C-engine replay. The PostgreSQL smoke and scale harness have narrower scopes
described in their own READMEs; passing them is not a 100K/1M production certification.
