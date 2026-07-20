# Production server parity gaps

Audit snapshot: 2026-07-11. The canonical 25-route matrix dispatches through
`OnlineApplication`, and the implementation now covers the major gameplay, projection,
AI, deadline, population, results, lease, and realtime paths. This file records the
remaining retirement and scale gates; implemented items have been removed rather than
left as stale gaps.

## Remaining durability and release gates

| Remaining limitation | Current evidence | Required closure |
|---|---|---|
| Automatic advancement may append several individually fenced/CAS-protected actions before returning one aggregate `advanced` count. A crash can change that count on redelivery even though durable game state cannot duplicate or go backward. | Create, player action, delete, and controller changes commit their canonical command receipt atomically with the mutation. A fault-injection test kills the worker after commit and proves exactly-once redelivery. Each automatic action is independently revisioned and replayable. | Treat the count as advisory, or give a multi-action advancement batch its own durable transaction/result record if a future client depends on an exactly-once count. |

## P1: compatibility and operations

| Remaining limitation | Current evidence | Required closure |
|---|---|---|
| The verified laptop-scale distributed stack is not a sustained production-capacity or regional-failure soak. | Compose now runs PostgreSQL, Redis, HAProxy, two gateways, disjoint partition workers, and dedicated deadline/population/lifecycle roles. Live drills passed owner kill/takeover, same-session continuation, WebSocket catch-up, bounded Redis/PostgreSQL interruption, readiness recovery, and rolling restarts. A 32-game/8-WebSocket real-C sample completed without errors, but its p95 command lag was about three seconds under deliberately tight one-CPU container limits. | Run sustained 10K then 100K tests on production-shaped infrastructure, measure reconnect storms and database/broker saturation, tune capacity assumptions, and exercise multi-region failover before traffic migration. |

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
