from server.kolkhoz_server.metrics import ServerMetrics


class Runtime:
    def metrics_state(self):
        return {"activeSessions": 2}


def test_registry_is_bounded_thread_safe_shape_and_prometheus_safe():
    metrics = ServerMetrics(max_series=2, sample_capacity=2)
    for index in range(10):
        metrics.record_route("GET", f"/unsafe/{index}", 200, index / 1000)
        metrics.observe(f"operation.{index}", index / 1000)
        metrics.increment(f"counter.{index}")
        metrics.gauge(f"gauge.{index}", index)

    snapshot = metrics.snapshot(Runtime())
    assert len(snapshot["routes"]) <= 3
    assert len(snapshot["operations"]) <= 3
    assert "other" in snapshot["operations"]
    assert snapshot["service"] == {"activeSessions": 2}
    rendered = metrics.prometheus(Runtime())
    assert "kolkhoz_http_requests_total" in rendered
    assert "/unsafe/9" not in rendered
