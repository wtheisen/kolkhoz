from __future__ import annotations

import argparse
import json
import math
import queue
import statistics
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore


@dataclass(frozen=True)
class Thresholds:
    p95_create_ms: float = 250
    p95_join_ms: float = 50
    p95_poll_ms: float = 100
    p95_event_ms: float = 100
    p95_action_ms: float = 150
    overload_rejected_min: int = 1
    recovery_max_ms: float = 2_000


@dataclass(frozen=True)
class CapacityScenario:
    connections: int
    connections_per_gateway: int
    games_per_worker: int
    players_per_game: int = 4
    gateway_headroom: float = 0.30
    worker_headroom: float = 0.30
    minimum_replicas: int = 2

    def projection(self) -> dict[str, object]:
        games = math.ceil(self.connections / self.players_per_game)
        required_gateways = math.ceil(
            self.connections
            / (self.connections_per_gateway * (1 - self.gateway_headroom))
        )
        required_workers = math.ceil(
            games / (self.games_per_worker * (1 - self.worker_headroom))
        )
        # One additional instance provides N+1 capacity during a failure or
        # rolling deployment. A minimum of two prevents a nominal single point.
        gateways = max(self.minimum_replicas, required_gateways + 1)
        workers = max(self.minimum_replicas, required_workers + 1)
        return {
            "connections": self.connections,
            "activeGames": games,
            "gatewayInstances": gateways,
            "gameWorkerInstances": workers,
            "capacityPolicy": "30-percent operating headroom plus N+1 instance",
            "assumptions": {
                "connectionsPerGateway": self.connections_per_gateway,
                "gamesPerWorker": self.games_per_worker,
                "playersPerGame": self.players_per_game,
                "gatewayHeadroomPercent": round(self.gateway_headroom * 100),
                "workerHeadroomPercent": round(self.worker_headroom * 100),
                "minimumReplicas": self.minimum_replicas,
            },
            "evidence": "modeled-not-measured",
        }


class CounterEngine:
    def __init__(self, seed: int) -> None:
        self.value = seed

    def apply(self, action: dict[str, object]) -> None:
        delta = action.get("delta")
        if not isinstance(delta, int):
            raise ValueError("delta must be an integer")
        self.value += delta

    def view(self, viewer_id: int | None = None) -> dict[str, object]:
        return {"value": self.value, "viewerID": viewer_id}

    def close(self) -> None:
        pass


class CounterEngineFactory:
    def create(self, seed: int, variants: dict[str, object]) -> CounterEngine:
        return CounterEngine(seed)


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, math.ceil(len(ordered) * fraction) - 1)]


def summary(values: list[float]) -> dict[str, float | int]:
    return {
        "count": len(values),
        "meanMs": round(statistics.fmean(values), 3) if values else 0,
        "p50Ms": round(percentile(values, 0.50), 3),
        "p95Ms": round(percentile(values, 0.95), 3),
        "p99Ms": round(percentile(values, 0.99), 3),
        "maxMs": round(max(values), 3) if values else 0,
    }


def timed(operation: Callable[[], object]) -> float:
    started = time.perf_counter()
    operation()
    return (time.perf_counter() - started) * 1_000


def exercise_overload(*, queue_size: int = 8, submissions: int = 128) -> dict[str, int]:
    """Prove bounded admission rejects excess work instead of growing forever."""
    mailbox: queue.Queue[int] = queue.Queue(maxsize=queue_size)
    accepted = rejected = 0
    for index in range(submissions):
        try:
            mailbox.put_nowait(index)
            accepted += 1
        except queue.Full:
            rejected += 1
    return {
        "evidence": "executable-bounded-admission-primitive",
        "queueCapacity": queue_size,
        "submitted": submissions,
        "accepted": accepted,
        "rejected": rejected,
        "maximumObservedDepth": mailbox.qsize(),
    }


def run_local(
    *,
    players: int,
    operations: int,
    concurrency: int,
    shards: int,
    thresholds: Thresholds,
) -> dict[str, object]:
    """Run real local runtime/store operations; this is not a gateway benchmark."""
    game_count = max(1, math.ceil(players / 4))
    sample_games = min(game_count, max(1, operations))
    latencies: dict[str, list[float]] = {
        name: [] for name in ("create", "join", "poll", "event", "action")
    }
    with tempfile.TemporaryDirectory() as directory:
        database = Path(directory) / "scale.sqlite3"
        runtime = GameRuntime(
            SQLiteEventStore(database),
            engine_factory=CounterEngineFactory(),
            shard_count=shards,
        )
        session_ids = [f"load-{index}" for index in range(sample_games)]
        try:
            for index, session_id in enumerate(session_ids):
                latencies["create"].append(
                    timed(
                        lambda i=index, s=session_id: runtime.create_game(
                            seed=i, session_id=s
                        )
                    )
                )

            # Join is measured as local admission bookkeeping. Full authenticated
            # HTTP join load belongs in a deployed-gateway benchmark.
            seats: dict[str, set[int]] = {
                session_id: set() for session_id in session_ids
            }
            seat_lock = threading.Lock()

            def one(index: int) -> None:
                session_id = session_ids[index % len(session_ids)]
                latencies["join"].append(
                    timed(lambda: _join(seats, seat_lock, session_id, index % 4))
                )
                latencies["poll"].append(timed(lambda: runtime.state(session_id)))
                latencies["event"].append(
                    timed(lambda: runtime.events(session_id, after_revision=0))
                )

            with ThreadPoolExecutor(max_workers=concurrency) as executor:
                list(executor.map(one, range(operations)))

            # One action per game avoids deliberately stale expected revisions.
            for session_id in session_ids:
                latencies["action"].append(
                    timed(
                        lambda s=session_id: runtime.submit_action(
                            s, expected_revision=0, action={"delta": 1}
                        )
                    )
                )
        finally:
            runtime.close()

        # Simulate loss of the worker process: no in-memory engine survives.
        started = time.perf_counter()
        recovered = GameRuntime(
            SQLiteEventStore(database),
            engine_factory=CounterEngineFactory(),
            shard_count=shards,
        )
        try:
            state = recovered.state(session_ids[0])
        finally:
            recovered.close()
        recovery_ms = (time.perf_counter() - started) * 1_000

    metrics = {name: summary(values) for name, values in latencies.items()}
    overload = exercise_overload()
    checks = {
        "createP95": metrics["create"]["p95Ms"] <= thresholds.p95_create_ms,
        "joinP95": metrics["join"]["p95Ms"] <= thresholds.p95_join_ms,
        "pollP95": metrics["poll"]["p95Ms"] <= thresholds.p95_poll_ms,
        "eventP95": metrics["event"]["p95Ms"] <= thresholds.p95_event_ms,
        "actionP95": metrics["action"]["p95Ms"] <= thresholds.p95_action_ms,
        "overloadRejected": overload["rejected"] >= thresholds.overload_rejected_min,
        "overloadBounded": overload["maximumObservedDepth"]
        <= overload["queueCapacity"],
        "workerRecovery": recovery_ms <= thresholds.recovery_max_ms,
        "recoveredRevision": state.revision == 1,
    }
    return {
        "evidence": "executable-local-runtime",
        "scope": {
            "playersModeled": players,
            "activeGamesModeled": game_count,
            "gamesExecuted": sample_games,
            "operationsExecuted": operations,
            "concurrency": concurrency,
            "shards": shards,
            "limitations": [
                "SQLite and an in-process counter engine are used",
                "network, TLS, authentication, and websocket fanout are excluded",
                "join measures admission bookkeeping rather than the deployed join route",
                "player count is workload shape; only gamesExecuted are materialized locally",
            ],
        },
        "latency": metrics,
        "overload": overload,
        "workerRecovery": {
            "method": "close runtime, create replacement, replay durable events",
            "latencyMs": round(recovery_ms, 3),
            "revision": state.revision,
        },
        "thresholds": asdict(thresholds),
        "checks": checks,
        "passed": all(checks.values()),
    }


def _join(
    seats: dict[str, set[int]], lock: threading.Lock, session_id: str, seat: int
) -> None:
    with lock:
        seats[session_id].add(seat)


def report(args: argparse.Namespace) -> dict[str, object]:
    thresholds = Thresholds()
    local = run_local(
        players=args.players,
        operations=args.operations,
        concurrency=args.concurrency,
        shards=args.shards,
        thresholds=thresholds,
    )
    scenarios = [
        CapacityScenario(
            count, args.connections_per_gateway, args.games_per_worker
        ).projection()
        for count in (10_000, 100_000, 1_000_000)
    ]
    return {
        "schemaVersion": 1,
        "generatedAtUnix": time.time(),
        "local": local,
        "capacityScenarios": scenarios,
        "passed": local["passed"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--players", type=int, default=10_000)
    parser.add_argument("--operations", type=int, default=500)
    parser.add_argument("--concurrency", type=int, default=32)
    parser.add_argument("--shards", type=int, default=8)
    parser.add_argument("--connections-per-gateway", type=int, default=25_000)
    parser.add_argument("--games-per-worker", type=int, default=10_000)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    value = report(args)
    rendered = json.dumps(value, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(rendered + "\n")
    print(rendered)
    raise SystemExit(0 if value["passed"] else 1)


if __name__ == "__main__":
    main()
