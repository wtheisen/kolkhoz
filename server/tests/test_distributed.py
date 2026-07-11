from __future__ import annotations

import json
import threading
from datetime import datetime, timedelta, timezone

from server.kolkhoz_server.distributed import (
    BoundedEventBuffer,
    BoundedIdempotencyWindow,
    EnqueueResult,
    PostgresSessionLeaseRepository,
    RealtimeMessage,
    RedisRealtimeBus,
    SessionLease,
)


class FakePubSub:
    def __init__(self) -> None:
        self.channel = None
        self.messages = []
        self.closed = False

    def subscribe(self, channel):
        self.channel = channel

    def get_message(self, timeout=0):
        return self.messages.pop(0) if self.messages else None

    def close(self):
        self.closed = True


class FakeRedis:
    def __init__(self) -> None:
        self.published = []
        self.subscription = FakePubSub()

    def publish(self, channel, body):
        self.published.append((channel, body))

    def pubsub(self, **_kwargs):
        return self.subscription


def test_redis_bus_preserves_event_identity_and_topic():
    redis = FakeRedis()
    bus = RedisRealtimeBus(redis, namespace="test")
    message = RealtimeMessage("session:abc", "event-7", {"revision": 9})

    bus.publish(message)
    channel, body = redis.published[0]
    assert channel == "test:session:abc"
    redis.subscription.messages.append({"data": json.dumps(json.loads(body)).encode()})

    subscription = bus.subscribe("session:abc")
    assert subscription.poll() == message
    subscription.close()
    assert redis.subscription.closed


class FakeCursor:
    def __init__(self, row=None, rowcount=0):
        self.row = row
        self.rowcount = rowcount
        self.executions = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def execute(self, sql, parameters):
        self.executions.append((sql, parameters))

    def fetchone(self):
        return self.row


class FakeConnection:
    def __init__(self, cursor):
        self._cursor = cursor
        self.closed = False

    def transaction(self):
        return self._cursor

    def cursor(self):
        return self._cursor

    def close(self):
        self.closed = True


def test_postgres_lease_operations_are_fenced_and_close_connections():
    expires = datetime(2030, 1, 1, tzinfo=timezone.utc)
    acquire_cursor = FakeCursor(("game-1", "worker-a", 42, expires))
    acquire_connection = FakeConnection(acquire_cursor)
    repository = PostgresSessionLeaseRepository(lambda: acquire_connection)

    lease = repository.acquire("game-1", "worker-a", timedelta(seconds=15))

    assert lease == SessionLease("game-1", "worker-a", 42, expires)
    sql, parameters = acquire_cursor.executions[0]
    assert "fencing_token = game_session_leases.fencing_token + 1" in sql
    assert "expires_at <= clock_timestamp()" in sql
    assert parameters == ("game-1", "worker-a", 15.0)
    assert acquire_connection.closed

    renew_cursor = FakeCursor(("game-1", "worker-a", 42, expires))
    renew_connection = FakeConnection(renew_cursor)
    repository = PostgresSessionLeaseRepository(lambda: renew_connection)
    assert repository.renew(lease, timedelta(seconds=20)) == lease
    renew_sql, renew_parameters = renew_cursor.executions[0]
    assert "fencing_token = %s" in renew_sql
    assert renew_parameters == (20.0, "game-1", "worker-a", 42)

    release_cursor = FakeCursor(rowcount=1)
    repository = PostgresSessionLeaseRepository(lambda: FakeConnection(release_cursor))
    assert repository.release(lease)
    assert release_cursor.executions[0][1] == ("game-1", "worker-a", 42)


def test_idempotency_window_is_ttl_and_memory_bounded():
    now = [10.0]
    window = BoundedIdempotencyWindow(2, 5, clock=lambda: now[0])
    assert window.register("a")
    assert not window.register("a")
    assert window.register("b")
    assert window.register("c")
    assert len(window) == 2
    assert window.register("a")  # oldest key was evicted
    now[0] = 20.0
    assert window.register("a")  # retained key expired


def test_event_buffer_rejects_duplicates_oversize_and_overload():
    window = BoundedIdempotencyWindow(10, 60)
    buffer = BoundedEventBuffer(2, 20, window)
    first = RealtimeMessage("game", "1", {"value": "a"})
    second = RealtimeMessage("game", "2", {"value": "b"})

    assert buffer.enqueue(first) is EnqueueResult.ACCEPTED
    assert buffer.enqueue(first) is EnqueueResult.DUPLICATE
    assert buffer.enqueue(second) is EnqueueResult.ACCEPTED
    assert buffer.enqueue(RealtimeMessage("game", "3", {})) is EnqueueResult.FULL
    assert (
        buffer.enqueue(RealtimeMessage("game", "4", {"value": "x" * 30}))
        is EnqueueResult.OVERSIZED
    )
    assert buffer.drain(1) == [first]
    assert len(buffer) == 1


def test_event_buffer_remains_bounded_under_concurrent_producers():
    buffer = BoundedEventBuffer(64, 100, BoundedIdempotencyWindow(1_000, 60))
    barrier = threading.Barrier(9)
    results = []
    results_lock = threading.Lock()

    def produce(worker: int) -> None:
        barrier.wait()
        local = [
            buffer.enqueue(
                RealtimeMessage("game", f"{worker}:{index}", {"index": index})
            )
            for index in range(100)
        ]
        with results_lock:
            results.extend(local)

    threads = [threading.Thread(target=produce, args=(worker,)) for worker in range(8)]
    for thread in threads:
        thread.start()
    barrier.wait()
    for thread in threads:
        thread.join()

    assert len(buffer) == 64
    assert results.count(EnqueueResult.ACCEPTED) == 64
    assert results.count(EnqueueResult.FULL) == 736
