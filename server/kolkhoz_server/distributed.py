"""Distributed coordination boundaries for production Kolkhoz deployments.

This module deliberately contains no game rules.  Gateways may fan events through
``RealtimeBus`` and workers may use ``SessionLeaseRepository`` to ensure that one
fenced owner mutates a session at a time.
"""

from __future__ import annotations

import json
import queue
import threading
import time
from collections import OrderedDict, deque
from collections.abc import Callable, Mapping
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Any, Protocol


@dataclass(frozen=True, slots=True)
class RealtimeMessage:
    topic: str
    event_id: str
    payload: Mapping[str, Any]


class RealtimeSubscription(Protocol):
    def poll(self, timeout_seconds: float = 0.0) -> RealtimeMessage | None: ...

    def close(self) -> None: ...


class RealtimeSubscriberOverflow(RuntimeError):
    """A local realtime consumer fell behind its bounded mailbox."""


class RealtimeBus(Protocol):
    def publish(self, message: RealtimeMessage) -> None: ...

    def subscribe(self, topic: str) -> RealtimeSubscription: ...


class RedisRealtimeBus:
    """Gateway-wide Redis subscription multiplexer.

    A single Redis pubsub is owned by one reader thread and fans messages into
    bounded local mailboxes.  WebSocket count therefore does not determine
    Redis connection count.  The reader also owns all subscribe commands so
    redis-py's PubSub object is never concurrently operated on.
    """

    def __init__(
        self,
        client: Any,
        *,
        namespace: str = "kolkhoz:realtime",
        subscriber_buffer_size: int = 64,
        reconnect_delay_seconds: float = 0.05,
    ) -> None:
        if subscriber_buffer_size <= 0:
            raise ValueError("subscriber_buffer_size must be positive")
        self._client = client
        self._namespace = namespace.rstrip(":")
        self._subscriber_buffer_size = subscriber_buffer_size
        self._reconnect_delay_seconds = reconnect_delay_seconds
        self._lock = threading.RLock()
        self._subscribers: dict[str, set[_MultiplexedSubscription]] = {}
        self._commands: queue.Queue[tuple[str, str] | None] = queue.Queue()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    @classmethod
    def from_url(
        cls, url: str, *, namespace: str = "kolkhoz:realtime"
    ) -> RedisRealtimeBus:
        import redis

        return cls(
            redis.Redis.from_url(url, decode_responses=True), namespace=namespace
        )

    def publish(self, message: RealtimeMessage) -> None:
        body = json.dumps(
            {
                "topic": message.topic,
                "eventId": message.event_id,
                "payload": message.payload,
            },
            separators=(",", ":"),
        )
        self._client.publish(self._channel(message.topic), body)

    def subscribe(self, topic: str) -> RealtimeSubscription:
        channel = self._channel(topic)
        subscription = _MultiplexedSubscription(
            self, topic, self._subscriber_buffer_size
        )
        with self._lock:
            if self._stop.is_set():
                raise RuntimeError("realtime bus is closed")
            subscribers = self._subscribers.setdefault(topic, set())
            first = not subscribers
            subscribers.add(subscription)
            self._ensure_reader_locked()
            if first:
                self._commands.put(("subscribe", channel))
        return subscription

    def close(self) -> None:
        with self._lock:
            if self._stop.is_set():
                return
            self._stop.set()
            subscriptions = [
                item for group in self._subscribers.values() for item in group
            ]
            self._subscribers.clear()
            self._commands.put(None)
            thread = self._thread
        for subscription in subscriptions:
            subscription._close_from_bus()
        if thread is not None and thread is not threading.current_thread():
            thread.join(timeout=2)

    @property
    def local_subscriber_count(self) -> int:
        with self._lock:
            return sum(len(group) for group in self._subscribers.values())

    def _ensure_reader_locked(self) -> None:
        if self._thread is None:
            self._thread = threading.Thread(
                target=self._run, name="redis-realtime-multiplexer", daemon=True
            )
            self._thread.start()

    def _remove(self, subscription: _MultiplexedSubscription) -> None:
        with self._lock:
            subscribers = self._subscribers.get(subscription.topic)
            if not subscribers:
                return
            subscribers.discard(subscription)
            if not subscribers:
                self._subscribers.pop(subscription.topic, None)
                self._commands.put(("unsubscribe", self._channel(subscription.topic)))

    def _run(self) -> None:
        pubsub: Any | None = None
        while not self._stop.is_set():
            try:
                if pubsub is None:
                    pubsub = self._client.pubsub(ignore_subscribe_messages=True)
                    with self._lock:
                        channels = [self._channel(topic) for topic in self._subscribers]
                    if channels:
                        pubsub.subscribe(*channels)
                self._drain_commands(pubsub)
                raw = pubsub.get_message(timeout=0.1)
                if raw is not None:
                    self._fan_out(raw)
            except Exception:
                if pubsub is not None:
                    try:
                        pubsub.close()
                    except Exception:
                        pass
                pubsub = None
                self._stop.wait(self._reconnect_delay_seconds)
        if pubsub is not None:
            try:
                pubsub.close()
            except Exception:
                pass

    def _drain_commands(self, pubsub: Any) -> None:
        while True:
            try:
                command = self._commands.get_nowait()
            except queue.Empty:
                return
            if command is None:
                return
            operation, channel = command
            if operation == "subscribe":
                pubsub.subscribe(channel)
            else:
                pubsub.unsubscribe(channel)

    def _fan_out(self, raw: Mapping[str, Any]) -> None:
        data = raw.get("data")
        if isinstance(data, bytes):
            data = data.decode("utf-8")
        decoded = json.loads(data)
        message = RealtimeMessage(
            topic=decoded["topic"],
            event_id=decoded["eventId"],
            payload=decoded["payload"],
        )
        with self._lock:
            subscribers = tuple(self._subscribers.get(message.topic, ()))
        for subscription in subscribers:
            subscription._offer(message)

    def _channel(self, topic: str) -> str:
        if not topic or any(character.isspace() for character in topic):
            raise ValueError(
                "realtime topic must be non-empty and contain no whitespace"
            )
        return f"{self._namespace}:{topic}"


class _MultiplexedSubscription:
    def __init__(self, bus: RedisRealtimeBus, topic: str, capacity: int) -> None:
        self._bus = bus
        self.topic = topic
        self._capacity = capacity
        self._messages: deque[RealtimeMessage] = deque()
        self._event_ids: OrderedDict[str, None] = OrderedDict()
        self._condition = threading.Condition()
        self._closed = False
        self._overflowed = False

    def poll(self, timeout_seconds: float = 0.0) -> RealtimeMessage | None:
        deadline = time.monotonic() + max(0.0, timeout_seconds)
        with self._condition:
            while not self._messages and not self._closed:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                self._condition.wait(remaining)
            if self._overflowed:
                raise RealtimeSubscriberOverflow("realtime subscriber buffer overflow")
            return self._messages.popleft() if self._messages else None

    def close(self) -> None:
        with self._condition:
            self._closed = True
            self._condition.notify_all()
        self._bus._remove(self)

    def _close_from_bus(self) -> None:
        with self._condition:
            self._closed = True
            self._condition.notify_all()

    def _offer(self, message: RealtimeMessage) -> None:
        with self._condition:
            if self._closed or message.event_id in self._event_ids:
                return
            self._event_ids[message.event_id] = None
            while len(self._event_ids) > self._capacity * 4:
                self._event_ids.popitem(last=False)
            if len(self._messages) >= self._capacity:
                self._overflowed = True
                self._closed = True
                self._condition.notify_all()
                return
            self._messages.append(message)
            self._condition.notify()


@dataclass(frozen=True, slots=True)
class SessionLease:
    session_id: str
    owner_id: str
    fencing_token: int
    expires_at: datetime


class SessionLeaseRepository(Protocol):
    def acquire(
        self, session_id: str, owner_id: str, ttl: timedelta
    ) -> SessionLease | None: ...

    def renew(self, lease: SessionLease, ttl: timedelta) -> SessionLease | None: ...

    def release(self, lease: SessionLease) -> bool: ...


class PostgresSessionLeaseRepository:
    """PostgreSQL leases with monotonically increasing fencing tokens.

    A downstream durable write must include the returned fencing token.  An old
    worker can therefore be rejected even if it resumes after its lease expires.
    """

    def __init__(
        self,
        connection_factory: Callable[[], Any] | None = None,
        *,
        pool: Any | None = None,
    ) -> None:
        if connection_factory is None and pool is None:
            raise ValueError("connection_factory or pool is required")
        self._connection_factory = connection_factory
        self._pool = pool

    def acquire(
        self, session_id: str, owner_id: str, ttl: timedelta
    ) -> SessionLease | None:
        seconds = _ttl_seconds(ttl)
        sql = """
            INSERT INTO game_session_leases
                (session_id, owner_id, fencing_token, expires_at)
            VALUES (%s, %s, 1, clock_timestamp() + (%s * interval '1 second'))
            ON CONFLICT (session_id) DO UPDATE SET
                owner_id = EXCLUDED.owner_id,
                fencing_token = game_session_leases.fencing_token + 1,
                expires_at = EXCLUDED.expires_at
            WHERE game_session_leases.expires_at <= clock_timestamp()
               OR game_session_leases.owner_id = EXCLUDED.owner_id
            RETURNING session_id, owner_id, fencing_token, expires_at
        """
        return self._fetch_lease(sql, (session_id, owner_id, seconds))

    def renew(self, lease: SessionLease, ttl: timedelta) -> SessionLease | None:
        sql = """
            UPDATE game_session_leases
               SET expires_at = clock_timestamp() + (%s * interval '1 second')
             WHERE session_id = %s AND owner_id = %s AND fencing_token = %s
               AND expires_at > clock_timestamp()
            RETURNING session_id, owner_id, fencing_token, expires_at
        """
        return self._fetch_lease(
            sql,
            (_ttl_seconds(ttl), lease.session_id, lease.owner_id, lease.fencing_token),
        )

    def release(self, lease: SessionLease) -> bool:
        sql = """
            UPDATE game_session_leases SET expires_at = clock_timestamp()
             WHERE session_id = %s AND owner_id = %s AND fencing_token = %s
        """
        with self._connection() as connection:
            with connection.transaction(), connection.cursor() as cursor:
                cursor.execute(
                    sql, (lease.session_id, lease.owner_id, lease.fencing_token)
                )
                return cursor.rowcount == 1

    def _fetch_lease(
        self, sql: str, parameters: tuple[Any, ...]
    ) -> SessionLease | None:
        with self._connection() as connection:
            with connection.transaction(), connection.cursor() as cursor:
                cursor.execute(sql, parameters)
                row = cursor.fetchone()
            return None if row is None else SessionLease(*row)

    @contextmanager
    def _connection(self):
        if self._pool is not None:
            with self._pool.connection() as connection:
                yield connection
            return
        connection = self._connection_factory()
        try:
            yield connection
        finally:
            connection.close()


def _ttl_seconds(ttl: timedelta) -> float:
    seconds = ttl.total_seconds()
    if seconds <= 0:
        raise ValueError("lease TTL must be positive")
    return seconds


class EnqueueResult(Enum):
    ACCEPTED = "accepted"
    DUPLICATE = "duplicate"
    FULL = "full"
    OVERSIZED = "oversized"


class BoundedIdempotencyWindow:
    """Thread-safe TTL/LRU window with an explicit maximum memory footprint."""

    def __init__(
        self,
        capacity: int,
        ttl_seconds: float,
        *,
        clock: Callable[[], float] = time.monotonic,
    ):
        if capacity <= 0 or ttl_seconds <= 0:
            raise ValueError("capacity and TTL must be positive")
        self._capacity = capacity
        self._ttl = ttl_seconds
        self._clock = clock
        self._entries: OrderedDict[str, float] = OrderedDict()
        self._lock = threading.Lock()

    def register(self, event_id: str) -> bool:
        """Return true exactly once within the configured window."""
        now = self._clock()
        with self._lock:
            while self._entries and next(iter(self._entries.values())) <= now:
                self._entries.popitem(last=False)
            expiry = self._entries.get(event_id)
            if expiry is not None and expiry > now:
                self._entries.move_to_end(event_id)
                return False
            self._entries[event_id] = now + self._ttl
            self._entries.move_to_end(event_id)
            while len(self._entries) > self._capacity:
                self._entries.popitem(last=False)
            return True

    def __len__(self) -> int:
        with self._lock:
            return len(self._entries)


class BoundedEventBuffer:
    """Non-blocking connection buffer that sheds load instead of growing memory."""

    def __init__(
        self,
        capacity: int,
        max_message_bytes: int,
        idempotency: BoundedIdempotencyWindow,
    ):
        if capacity <= 0 or max_message_bytes <= 0:
            raise ValueError("capacity and maximum message size must be positive")
        self._capacity = capacity
        self._max_message_bytes = max_message_bytes
        self._idempotency = idempotency
        self._items: deque[RealtimeMessage] = deque()
        self._lock = threading.Lock()

    def enqueue(self, message: RealtimeMessage) -> EnqueueResult:
        encoded_size = len(
            json.dumps(message.payload, separators=(",", ":")).encode("utf-8")
        )
        if encoded_size > self._max_message_bytes:
            return EnqueueResult.OVERSIZED
        with self._lock:
            if len(self._items) >= self._capacity:
                return EnqueueResult.FULL
            if not self._idempotency.register(message.event_id):
                return EnqueueResult.DUPLICATE
            self._items.append(message)
            return EnqueueResult.ACCEPTED

    def drain(self, limit: int) -> list[RealtimeMessage]:
        if limit <= 0:
            return []
        with self._lock:
            return [self._items.popleft() for _ in range(min(limit, len(self._items)))]

    def __len__(self) -> int:
        with self._lock:
            return len(self._items)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)
