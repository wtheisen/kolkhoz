# Scaling the Kolkhoz online server

The current production deployment runs one combined server process and one dedicated
Redis process on a small VPS. This is the minimum-cost topology, not a different
architecture from the distributed design. The same server can be separated into
gateways, game workers, and schedulers through environment configuration as traffic
grows.

This document is a scaling roadmap, not a claim that the current deployment has
sustained 10,000 or more concurrent players. Promote each tier only after the load and
failure gates below pass on production-shaped infrastructure.

## Why the architecture scales horizontally

- A game is owned by one bounded shard mailbox at a time; there is no process-wide
  gameplay lock.
- Redis Streams partitions route mutations to game workers while preserving ordering
  for one session.
- PostgreSQL leases and fencing tokens reject a stale worker after ownership changes.
- Every committed action has an expected revision and is replayable from the durable
  event log.
- Gateways do not require sticky sessions. A WebSocket can reconnect to any gateway and
  catch up from its last durable revision.
- One Redis subscription multiplexer per gateway fans committed revisions to bounded
  connection buffers.
- Deadline, population, and lifecycle work use independently leased schedulers, so
  replicas can take over after a failure.
- PostgreSQL and Redis connections, shard queues, command streams, authentication
  caches, and WebSocket buffers all have explicit bounds.

The C engine remains authoritative in every topology. Scaling changes where a session
runs, not the rules or state representation.

## Current single-VPS topology

```text
Internet
   |
Caddy (TLS)
   |
combined Kolkhoz process
   |-- HTTP and WebSocket gateway
   |-- all command partitions
   |-- game shard mailboxes
   |-- deadline scheduler
   |-- population scheduler
   `-- lifecycle reconciler
   |
   +-- dedicated loopback Redis
   `-- Supabase PostgreSQL
```

The current VPS has 1 vCPU and about 1 GB RAM. The server is deliberately capped and is
suitable for production correctness at the present load, not capacity certification.
The first response to ordinary growth should be a larger VPS and measurement, not a
new orchestration platform.

## Scaling stages

### Stage 1: larger single host

Move the existing deployment to a VPS with more CPU, memory, network bandwidth, and
file descriptors. Keep one process initially and tune only from observed saturation:

- `KOLKHOZ_SHARDS`: independent in-process game mailboxes; start near available CPU.
- `KOLKHOZ_DB_POOL_SIZE`: bounded PostgreSQL connections for that process.
- `KOLKHOZ_AUTH_CACHE_CAPACITY`: verified-user cache bound.
- `KOLKHOZ_REALTIME_BUFFER_SIZE`: per-connection update buffer.
- `KOLKHOZ_COMMAND_PARTITION_COUNT`: stable global partition count.
- `KOLKHOZ_COMMAND_PARTITION_CAPACITY`: bounded pending commands per partition.
- `KOLKHOZ_DEADLINE_BATCH_SIZE`, `KOLKHOZ_POPULATION_BATCH_SIZE`, and
  `KOLKHOZ_LIFECYCLE_BATCH_SIZE`: bounded scheduler work per tick.

Do not raise every limit together. Add CPU before shards, database capacity before pool
connections, and Redis memory before stream capacity. Keep at least 30% operating
headroom and enough capacity to lose one process or host.

### Stage 2: separate gateways and workers

Run ordinary systemd services, containers, or managed container instances on multiple
VMs. Kubernetes is optional; the architecture only requires a load balancer, shared
PostgreSQL, and shared Redis.

```text
                    +--> gateway A --+
TLS load balancer --+--> gateway B --+--> Redis realtime/commands
                    +--> gateway C --+            |
                                                   v
                         worker A: partitions 0-63 +--> PostgreSQL
                         worker B: partitions 64-127
                         worker C: partitions 128-191
                         worker D: partitions 192-255

                         deadline schedulers (2+)
                         population schedulers (2+)
                         lifecycle reconcilers (2+)
```

Gateway processes disable background roles:

```text
KOLKHOZ_RUN_COMMAND_WORKER=false
KOLKHOZ_RUN_DEADLINE_SCHEDULER=false
KOLKHOZ_RUN_POPULATION_SCHEDULER=false
KOLKHOZ_RUN_LIFECYCLE_RECONCILER=false
```

Worker processes enable only command execution and receive disjoint partition lists:

```text
KOLKHOZ_RUN_COMMAND_WORKER=true
KOLKHOZ_RUN_DEADLINE_SCHEDULER=false
KOLKHOZ_RUN_POPULATION_SCHEDULER=false
KOLKHOZ_RUN_LIFECYCLE_RECONCILER=false
KOLKHOZ_COMMAND_PARTITIONS=0,1,2,3
```

Dedicated scheduler processes enable one scheduler role each. Run at least two replicas
of each role; leases ensure only one replica owns a claim while another can take over.

Choose `KOLKHOZ_COMMAND_PARTITION_COUNT` before distributing workers and keep it stable.
Every partition must have exactly one live worker assignment. Missing partitions cause
timeouts; overlapping assignments waste work and create lease contention, although
PostgreSQL fencing still prevents stale commits.

### Stage 3: managed data services and independent capacity

Move PostgreSQL and Redis off the application hosts before they compete materially with
gateways or workers.

PostgreSQL should provide:

- automated backups and point-in-time recovery;
- a tested failover replica;
- connection pooling with a global budget across every process;
- latency, lock, connection, storage, and replication-lag alerts;
- periodic restore drills;
- retention or partitioning for event/receipt tables only after measured growth makes
  it necessary.

Redis should provide persistence appropriate for command streams, memory headroom,
replication/failover, stream-lag alerts, and a `noeviction` policy for commands. At
higher scale, separate command transport from realtime fanout so a reconnect storm
cannot starve mutations. The current code uses one `REDIS_URL`; separate command and
realtime URLs would be a deliberate code/config extension before that split.

### Stage 4: regional cells

A million simultaneous connections should not be treated as one global deployment.
Use regional cells, each with its own gateways, workers, command transport, and bounded
database ownership. Route a session to a home region and keep all mutations for that
session there.

Global services should be limited to account/profile discovery, matchmaking placement,
and routing metadata. Do not attempt active-active writes for one game across regions.
Cross-region failover requires an explicit session-home transfer protocol, durable
replication evidence, and fencing that prevents the old region from resuming writes.
This regional control plane is not implemented today and is a required engineering
stage before claiming million-player resilience.

## Provisional capacity model

The repository's arithmetic model assumes four players per game, 25,000 connections
per gateway, 10,000 active games per worker, 30% headroom, and one extra replica. These
inputs are unvalidated planning assumptions:

| Concurrent connections | Active games | Gateway replicas | Worker replicas | Status |
| ---: | ---: | ---: | ---: | --- |
| 10,000 | 2,500 | 2 | 2 | Modeled, not measured |
| 100,000 | 25,000 | 7 | 5 | Modeled, not measured |
| 1,000,000 | 250,000 | 59 | 37 | Modeled, not measured |

These counts exclude PostgreSQL, Redis, load balancers, schedulers, observability, and
regional routing. Replace model inputs only with repeatable deployed benchmark results.

## Safe rollout procedure

1. Provision N+1 capacity and confirm `/ready` on every new process.
2. Start new workers with a planned, non-overlapping partition assignment.
3. Stop or drain the old owner for those partitions; wait for its lease to expire.
4. Verify command lag, lease losses, dead letters, and session progress before moving
   another partition group.
5. Add gateways to the load balancer and verify WebSocket reconnect/catch-up.
6. Drain old gateways rather than killing all connections simultaneously.
7. Keep the previous application release available until error rates and queue latency
   remain normal through a full traffic cycle.

Application rollbacks do not require deleting event data. A reverted worker rebuilds
game state by replaying committed revisions. Schema changes must remain backward
compatible for every release participating in a rolling deployment.

## Capacity and failure gates

Before promoting a tier, run the real PostgreSQL/Redis/gateway/worker stack, not only
the in-process scale model:

```bash
cd server/deploy/staging
docker compose up --build -d --wait
python3 smoke.py
python3 chaos.py

python3 -m server.tools.distributed_load \
  --base-url http://127.0.0.1:18080 \
  --staging-identities 100 --staging-offset 100 \
  --games 100 --concurrency 32 --actions-per-game 1 \
  --websockets 25 --websocket-seconds 10 \
  --output /tmp/kolkhoz-distributed-load.json
```

For each target tier, measure steady traffic and a reconnect storm, then repeat while:

- killing a worker and waiting for fenced takeover;
- removing a gateway during active WebSockets;
- interrupting Redis and PostgreSQL within their expected failure windows;
- rolling every application process;
- saturating one command partition without allowing unbounded memory growth.

Do not promote when readiness is lost, commands enter the DLQ, shard queues reject
normal traffic, PostgreSQL/Redis approach their connection or memory ceilings, or p95
command completion exceeds the product objective. The current starter objective is
99.9% accepted commands within two seconds.

## What to monitor

Scrape `/metrics/prometheus` from every process and aggregate by role and deployment:

- HTTP non-5xx rate and route latency;
- active WebSockets, reconnect rate, subscriber overflows, and buffer pressure;
- command completion latency, stream lag, retries, and dead letters;
- shard queue depth and overload rejections;
- PostgreSQL pool usage, query latency, errors, and lease loss;
- Redis memory, clients, command-stream depth, and Pub/Sub health;
- scheduler claim delay, timeout processing, and lifecycle retries;
- host CPU, memory, network, file descriptors, and event-loop lag.

See [`server/observability/README.md`](server/observability/README.md) and
[`server/observability/prometheus-alerts.yml`](server/observability/prometheus-alerts.yml)
for the existing metrics and starter alerts.

## Known engineering gates

- Sustained 10K and 100K tests have not yet run on production-shaped infrastructure.
- Regional session placement and failover are not implemented.
- Command and realtime Redis use the same URL today.
- Durable engine snapshots may be worthwhile if replay histories become materially
  longer; current games recover from the event log.
- Automatic advancement's aggregate `advanced` count is advisory across crash
  redelivery, although individual actions remain fenced, revisioned, and replayable.

These are validation and future-scale gates, not reasons to redesign the current
single-VPS service. The existing role separation and durability boundaries allow the
system to grow incrementally while keeping the same API and authoritative C engine.
