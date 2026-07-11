from __future__ import annotations

import re
import sys
import threading
import time
from collections import defaultdict, deque
from contextlib import contextmanager
from typing import Iterator


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    return values[min(len(values) - 1, int((len(values) - 1) * percentile))]


class MetricBucket:
    def __init__(self, capacity: int = 2048) -> None:
        self.count = 0
        self.total = 0.0
        self.minimum: float | None = None
        self.maximum = 0.0
        self.samples: deque[float] = deque(maxlen=capacity)

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
    """Bounded, thread-safe process metrics with low-cardinality labels."""

    def __init__(self, *, max_series: int = 512, sample_capacity: int = 2048) -> None:
        self.started_at = time.time()
        self._max_series = max_series
        self._sample_capacity = sample_capacity
        self._routes: dict[str, MetricBucket] = {}
        self._statuses: dict[str, int] = defaultdict(int)
        self._observations: dict[str, MetricBucket] = {}
        self._counters: dict[str, float] = defaultdict(float)
        self._gauges: dict[str, float] = {}
        self._lock = threading.Lock()

    def _bounded_key(self, collection: dict[str, object], key: str) -> str:
        return (
            key if key in collection or len(collection) < self._max_series else "other"
        )

    def record_route(
        self, method: str, route: str, status: int, elapsed: float
    ) -> None:
        key = f"{method} {route}"
        with self._lock:
            key = self._bounded_key(self._routes, key)
            self._routes.setdefault(key, MetricBucket(self._sample_capacity)).record(
                elapsed
            )
            status_key = self._bounded_key(self._statuses, f"{key} {status}")
            self._statuses[status_key] += 1

    def observe(self, name: str, elapsed: float) -> None:
        with self._lock:
            key = self._bounded_key(self._observations, name)
            self._observations.setdefault(
                key, MetricBucket(self._sample_capacity)
            ).record(max(0.0, elapsed))

    def increment(self, name: str, value: float = 1.0) -> None:
        with self._lock:
            key = self._bounded_key(self._counters, name)
            self._counters[key] += value

    def gauge(self, name: str, value: float) -> None:
        with self._lock:
            key = self._bounded_key(self._gauges, name)
            self._gauges[key] = value

    @contextmanager
    def timed(self, name: str, *, error_counter: str | None = None) -> Iterator[None]:
        started = time.perf_counter()
        try:
            yield
        except Exception:
            if error_counter:
                self.increment(error_counter)
            raise
        finally:
            self.observe(name, time.perf_counter() - started)

    def snapshot(self, runtime: object) -> dict[str, object]:
        service = runtime.metrics_state()
        with self._lock:
            routes = {
                key: value.snapshot() for key, value in sorted(self._routes.items())
            }
            statuses = dict(sorted(self._statuses.items()))
            operations = {
                key: value.snapshot()
                for key, value in sorted(self._observations.items())
            }
            counters = dict(sorted(self._counters.items()))
            gauges = dict(sorted(self._gauges.items()))
        return {
            "startedAt": self.started_at,
            "uptimeSeconds": time.time() - self.started_at,
            "process": {
                "activeThreads": threading.active_count(),
                "python": sys.version.split()[0],
            },
            "service": service,
            "routes": routes,
            "routeStatuses": statuses,
            "operations": operations,
            "counters": counters,
            "gauges": gauges,
            "sessionLockWaits": {},
            "storeCalls": {
                k: v for k, v in operations.items() if k.startswith("store.")
            },
            "backgroundTick": operations.get(
                "scheduler.tick", MetricBucket().snapshot()
            ),
        }

    def prometheus(self, runtime: object) -> str:
        snapshot = self.snapshot(runtime)
        lines = [
            "# HELP kolkhoz_uptime_seconds Process uptime.",
            "# TYPE kolkhoz_uptime_seconds gauge",
        ]
        lines.append(f"kolkhoz_uptime_seconds {snapshot['uptimeSeconds']:.6f}")
        for name, value in snapshot["counters"].items():
            metric = _metric_name(name) + "_total"
            lines.extend((f"# TYPE {metric} counter", f"{metric} {value}"))
        for name, value in snapshot["gauges"].items():
            metric = _metric_name(name)
            lines.extend((f"# TYPE {metric} gauge", f"{metric} {value}"))
        for name, value in snapshot["operations"].items():
            metric = _metric_name(name) + "_seconds"
            lines.extend(
                (
                    f"# TYPE {metric} summary",
                    f'{metric}{{quantile="0.5"}} {value["p50Ms"] / 1000:.9f}',
                    f'{metric}{{quantile="0.95"}} {value["p95Ms"] / 1000:.9f}',
                    f'{metric}{{quantile="0.99"}} {value["p99Ms"] / 1000:.9f}',
                    f"{metric}_count {value['count']}",
                    f"{metric}_sum {value['meanMs'] * value['count'] / 1000:.9f}",
                )
            )
        for key, count in snapshot["routeStatuses"].items():
            method, route, status = (
                key.split(" ", 2) if key != "other" else ("other", "other", "0")
            )
            lines.append(
                'kolkhoz_http_requests_total{method="%s",route="%s",status="%s"} %s'
                % (method, route.replace('"', ""), status, count)
            )
        return "\n".join(lines) + "\n"


def _metric_name(name: str) -> str:
    return "kolkhoz_" + re.sub(r"[^a-zA-Z0-9_:]", "_", name).lower()
