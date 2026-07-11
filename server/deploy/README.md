# Server deployment

The live DigitalOcean procedure is authoritative and documented in
[`digitalocean/README.md`](digitalocean/README.md). The generic unit and environment
files in this directory are templates for another single-host installation.

## Install

From a checked-out release at `/opt/kolkhoz-server`:

```bash
python3 -m venv /opt/kolkhoz-server/.venv
/opt/kolkhoz-server/.venv/bin/pip install -r server/deploy/requirements.txt
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/postgres_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/lobby_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/distributed_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/command_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/population_schema.sql
sudo install -o root -g root -m 0600 \
  server/deploy/kolkhoz-server.env.example /etc/kolkhoz-server.env
sudo install -o root -g root -m 0644 \
  server/deploy/kolkhoz-server.service /etc/systemd/system/kolkhoz-server.service
```

Edit `/etc/kolkhoz-server.env` with the production database URL, then start the
service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kolkhoz-server
sudo systemctl status kolkhoz-server
curl --fail --silent http://127.0.0.1:18787/health
```

The database role needs `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on the `server_*`,
`game_session_leases`, and `population_*` tables plus the existing profile/social
tables. Schema migration should run as a separate privileged deployment step, never
automatically at process startup.

Before deploying, the complete schema composition can be verified against a
disposable local PostgreSQL container (never the configured production database):

```bash
server/tools/postgres_smoke.sh
```

The smoke applies the existing Supabase migration history, applies every new server
schema twice to prove rerunnability, and exercises game/event, lobby, lease, command,
population, and result writes. Docker is the only host dependency.

## Capacity settings

`KOLKHOZ_SHARDS` controls the number of single-owner game mailboxes in this process.
`KOLKHOZ_DB_POOL_SIZE` bounds concurrent PostgreSQL connections. Begin with values near
the available CPU count and tune them from queue latency and database saturation; more
shards do not make one game concurrent.

Redis Streams partitions route mutations to game workers. A single-host deployment may
omit `KOLKHOZ_COMMAND_PARTITIONS` and consume all partitions. In a multi-host deployment,
assign every partition exactly once across the live worker set; use stable worker
identities and coordinated reassignment during failover. Overlapping assignments cause
lease contention, while missing assignments cause command timeouts. The PostgreSQL
session lease and fencing token remain the final stale-owner safety boundary.

The three `KOLKHOZ_RUN_*` flags permit independent process roles. At larger scale, run
gateway-only replicas with all three disabled, a partitioned game-worker pool with only
`KOLKHOZ_RUN_COMMAND_WORKER=true`, and small independently elected deadline/population
scheduler pools. The all-enabled defaults are a single-host convenience, not the
million-connection topology.

The ASGI process exposes the compatibility HTTP API and
`/sessions/{sessionID}/realtime` WebSockets. `REDIS_URL` is required: Redis Pub/Sub
fans committed revisions to connections on every gateway replica. Put TLS, connection
limits, and request-rate limits at the reverse proxy.

Scale gateways as independent service instances behind a WebSocket-capable load
balancer; connections are not sticky because durable revision catch-up repairs a
reconnect on any replica. Keep one Uvicorn worker per process and scale processes or
hosts instead: per-process connection buffers are bounded by
`KOLKHOZ_REALTIME_BUFFER_SIZE` (default 64), and slow consumers are closed with 1013.
Capacity planning for hundreds of thousands of sockets must include OS file-descriptor
limits, load-balancer limits, Redis fanout capacity, and regional sharding; no single
Python process is intended to own the aggregate connection population.

## Rollback

Stop `kolkhoz-server`, restore the previous application release, and restart it. The
event tables are append-only by revision, so an application rollback does not require
discarding games. Do not remove the schema while any release may need replay recovery.
