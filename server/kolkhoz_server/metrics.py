from __future__ import annotations

import sys
import threading
import time
from collections import defaultdict, deque


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    return values[min(len(values) - 1, int((len(values) - 1) * percentile))]


class MetricBucket:
    def __init__(self) -> None:
        self.count = 0
        self.total = 0.0
        self.minimum: float | None = None
        self.maximum = 0.0
        self.samples: deque[float] = deque(maxlen=2048)

    def record(self, elapsed: float) -> None:
        self.count += 1
        self.total += elapsed
        self.minimum = elapsed if self.minimum is None else min(self.minimum, elapsed)
        self.maximum = max(self.maximum, elapsed)
        self.samples.append(elapsed)

    def snapshot(self) -> dict[str, object]:
        samples = sorted(self.samples)
        return {
            "count": self.count,
            "meanMs": self.total * 1000 / self.count if self.count else 0.0,
            "minMs": (self.minimum or 0.0) * 1000,
            "maxMs": self.maximum * 1000,
            "p50Ms": _percentile(samples, 0.50) * 1000,
            "p95Ms": _percentile(samples, 0.95) * 1000,
            "p99Ms": _percentile(samples, 0.99) * 1000,
        }


class ServerMetrics:
    def __init__(self) -> None:
        self.started_at = time.time()
        self._routes: dict[str, MetricBucket] = defaultdict(MetricBucket)
        self._statuses: dict[str, int] = defaultdict(int)
        self._lock = threading.Lock()

    def record_route(
        self, method: str, route: str, status: int, elapsed: float
    ) -> None:
        key = f"{method} {route}"
        with self._lock:
            self._routes[key].record(elapsed)
            self._statuses[f"{key} {status}"] += 1

    def snapshot(self, runtime: object) -> dict[str, object]:
        with self._lock:
            routes = {
                key: value.snapshot() for key, value in sorted(self._routes.items())
            }
            statuses = dict(sorted(self._statuses.items()))
        return {
            "startedAt": self.started_at,
            "uptimeSeconds": time.time() - self.started_at,
            "process": {
                "activeThreads": threading.active_count(),
                "python": sys.version.split()[0],
            },
            "service": runtime.metrics_state(),
            "routes": routes,
            "routeStatuses": statuses,
            "sessionLockWaits": {},
            "storeCalls": {},
            "backgroundTick": MetricBucket().snapshot(),
        }
