"""Distributed coordination boundaries for production Kolkhoz deployments.

This module deliberately contains no game rules.  Gateways may fan events through
``RealtimeBus`` and workers may use ``SessionLeaseRepository`` to ensure that one
fenced owner mutates a session at a time.
"""

from __future__ import annotations

import json
import threading
import time
from collections import OrderedDict, deque
from collections.abc import Callable, Mapping
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


class RealtimeBus(Protocol):
    def publish(self, message: RealtimeMessage) -> None: ...

    def subscribe(self, topic: str) -> RealtimeSubscription: ...


class RedisRealtimeBus:
    """Small redis-py adapter; callers inject a client for testing and pooling."""

    def __init__(self, client: Any, *, namespace: str = "kolkhoz:realtime") -> None:
        self._client = client
        self._namespace = namespace.rstrip(":")

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
        pubsub = self._client.pubsub(ignore_subscribe_messages=True)
        pubsub.subscribe(self._channel(topic))
        return _RedisSubscription(pubsub)

    def _channel(self, topic: str) -> str:
        if not topic or any(character.isspace() for character in topic):
            raise ValueError(
                "realtime topic must be non-empty and contain no whitespace"
            )
        return f"{self._namespace}:{topic}"


class _RedisSubscription:
    def __init__(self, pubsub: Any) -> None:
        self._pubsub = pubsub

    def poll(self, timeout_seconds: float = 0.0) -> RealtimeMessage | None:
        raw = self._pubsub.get_message(timeout=max(0.0, timeout_seconds))
        if raw is None:
            return None
        data = raw["data"]
        if isinstance(data, bytes):
            data = data.decode("utf-8")
        decoded = json.loads(data)
        return RealtimeMessage(
            topic=decoded["topic"],
            event_id=decoded["eventId"],
            payload=decoded["payload"],
        )

    def close(self) -> None:
        self._pubsub.close()


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

    def __init__(self, connection_factory: Callable[[], Any]) -> None:
        self._connection_factory = connection_factory

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
        connection = self._connection_factory()
        try:
            with connection.transaction(), connection.cursor() as cursor:
                cursor.execute(
                    sql, (lease.session_id, lease.owner_id, lease.fencing_token)
                )
                return cursor.rowcount == 1
        finally:
            connection.close()

    def _fetch_lease(
        self, sql: str, parameters: tuple[Any, ...]
    ) -> SessionLease | None:
        connection = self._connection_factory()
        try:
            with connection.transaction(), connection.cursor() as cursor:
                cursor.execute(sql, parameters)
                row = cursor.fetchone()
            return None if row is None else SessionLease(*row)
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
