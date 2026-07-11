# Greenfield server parity gaps

Audit snapshot: 2026-07-11. The canonical 25-route matrix dispatches through
`OnlineApplication`, and the implementation now covers the major gameplay, projection,
AI, deadline, population, results, lease, and realtime paths. This file records the
remaining retirement and scale gates; implemented items have been removed rather than
left as stale gaps.

## Remaining durability and release gates

| Remaining limitation | Current evidence | Required closure |
|---|---|---|
| Automatic advancement may append several individually fenced/CAS-protected actions before returning one aggregate `advanced` count. A crash can change that count on redelivery even though durable game state cannot duplicate or go backward. | Create, player action, delete, and controller changes commit their canonical command receipt atomically with the mutation. A fault-injection test kills the worker after commit and proves exactly-once redelivery. Each automatic action is independently revisioned and replayable. | Treat the count as advisory, or give a multi-action advancement batch its own durable transaction/result record if a future client depends on an exactly-once count. |
| Session creation and deletion are compensated operations across the lobby and event-store repositories, not one PostgreSQL transaction. | Critical existing-session transitions are atomic: kick authorization/release, last-seat release/cascade, abandonment/results, finish/progression, and controller override. Creation deletes its lobby row if game provisioning fails; empty-lobby deletion removes lobby state before the game-store command. | Add a durable provisioning/deletion saga and reconciliation sweep before claiming recovery from arbitrary process death at every instruction boundary. |

## P1: compatibility and operations

| Remaining limitation | Current evidence | Required closure |
|---|---|---|
| Operational metrics are useful but not yet a complete production autoscaling/SLO surface. | Health exposes git/C-engine provenance when available; metrics expose shard depth/capacity, overloads, sessions, connected seats, presence, policy SHA, and persistence status. Route/store latency histograms, lease loss, command lag/DLQ, Redis health, and scheduler lag are absent or incomplete. | Export the missing counters/histograms and define alert/SLO thresholds from deployed evidence. |
| The clean PostgreSQL schema gate and deterministic Redis/two-runtime tests are not a production-stack soak. | `server/tools/postgres_smoke.sh` applies every schema twice and exercises CAS, results, progression, leases, command receipts, and population. Chaos tests cover bounded queues, fencing/takeover, reconnect/deduplication, scheduler races, and repeated C replay. | Run PostgreSQL, Redis, multiple gateways/workers/schedulers, reconnect storms, owner death, database interruption, and rolling deploys in CI/staging before traffic migration. |

## Capacity envelope: design target, not a production claim

The architecture removes a process-wide gameplay lock: sessions are independently
owned, mailbox and connection buffers are bounded, PostgreSQL writes use CAS/fencing,
and gateway realtime fanout is multiplexed. Those are prerequisites for horizontal
scale, not proof of a particular concurrent-player count.

`server.tools.scale_harness` provides two deliberately separate forms of evidence:

- Executed locally: sampled in-process operations using SQLite and a counter engine,
  plus bounded-overload and cold-replay checks. Network, TLS, Supabase, PostgreSQL,
  Redis, WebSockets, and full C-engine workload are excluded.
- Modeled only: replica arithmetic for 10K, 100K, and 1M concurrent connections.
  With the default unvalidated assumptions of 25K connections per gateway, 10K games
  per worker, four players per game, 30% operating headroom, and N+1 capacity, the
  model yields:

| Concurrent connections | Active games | Gateway instances | Game-worker instances | Evidence |
|---:|---:|---:|---:|---|
| 10,000 | 2,500 | 2 | 2 | Modeled, not measured |
| 100,000 | 25,000 | 7 | 5 | Modeled, not measured |
| 1,000,000 | 250,000 | 59 | 37 | Modeled, not measured |

These counts exclude PostgreSQL/Redis replicas, schedulers, regional routing, and
observability infrastructure. At 1M connections, validate regional partitioning,
database partition/retention strategy, Redis or broker fanout limits, load-balancer and
file-descriptor ceilings, reconnect storms, and correlated regional failure. Change
the model inputs only after distributed soak and failure tests establish measured
per-instance limits.
