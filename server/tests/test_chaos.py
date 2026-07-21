"""Bounded failure-injection tests for distributed server invariants.

These tests intentionally use local adapters.  They exercise ownership, fencing,
idempotency, recovery, and backpressure without requiring PostgreSQL or Redis.
"""

from __future__ import annotations

import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from server.kolkhoz_server.distributed import (
    BoundedEventBuffer,
    BoundedIdempotencyWindow,
    EnqueueResult,
    RedisRealtimeBus,
    RealtimeMessage,
    SessionLease,
)
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.lobby import SeatRecord, SeatUnavailable
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import LeaseLost, RevisionConflict, SQLiteEventStore
from server.tests.in_memory_lobby import InMemoryLobbyRepository


class _Engine:
    def __init__(self, seed: int) -> None:
        self.value = seed
        self.closed = False

    def apply(self, action: dict[str, object]) -> None:
        self.value += int(action["delta"])

    def view(self, viewer_id: int | None = None) -> dict[str, object]:
        return {"value": self.value, "viewerID": viewer_id}

    def close(self) -> None:
        self.closed = True


class _Factory:
    def create(self, seed: int, variants: dict[str, object]) -> _Engine:
        return _Engine(seed)


class _LeaseRepository:
    """Thread-safe fake with monotonic fencing and an injectable clock."""

    def __init__(self) -> None:
        self.now = datetime(2030, 1, 1, tzinfo=timezone.utc)
        self._leases: dict[str, SessionLease] = {}
        self._tokens: dict[str, int] = {}
        self._lock = threading.Lock()

    def acquire(
        self, session_id: str, owner_id: str, ttl: timedelta
    ) -> SessionLease | None:
        with self._lock:
            current = self._leases.get(session_id)
            if current is not None and current.expires_at > self.now:
                if current.owner_id != owner_id:
                    return None
                return current
            token = self._tokens.get(session_id, 0) + 1
            lease = SessionLease(session_id, owner_id, token, self.now + ttl)
            self._tokens[session_id] = token
            self._leases[session_id] = lease
            return lease

    def renew(self, lease: SessionLease, ttl: timedelta) -> SessionLease | None:
        with self._lock:
            current = self._leases.get(lease.session_id)
            if current != lease or current.expires_at <= self.now:
                return None
            renewed = SessionLease(
                lease.session_id, lease.owner_id, lease.fencing_token, self.now + ttl
            )
            self._leases[lease.session_id] = renewed
            return renewed

    def release(self, lease: SessionLease) -> bool:
        with self._lock:
            if self._leases.get(lease.session_id) != lease:
                return False
            self._leases.pop(lease.session_id)
            return True

    def advance(self, seconds: float) -> None:
        self.now += timedelta(seconds=seconds)


class _FencedStore(SQLiteEventStore):
    """SQLite test adapter emulating PostgreSQL's durable fencing check."""

    def __init__(self, path: Path) -> None:
        super().__init__(path)
        self.highest_fence: dict[str, int] = {}
        self._fence_lock = threading.Lock()

    def append(self, session_id: str, **kwargs):  # type: ignore[no-untyped-def]
        token = kwargs.get("fencing_token")
        with self._fence_lock:
            highest = self.highest_fence.get(session_id, 0)
            if token is not None and token < highest:
                raise LeaseLost(f"stale fencing token for session {session_id}")
            if token is not None:
                self.highest_fence[session_id] = token
        return super().append(session_id, **kwargs)


def _runtime(path: Path, **kwargs: object) -> GameRuntime:
    shard_count = int(kwargs.pop("shard_count", 8))
    return GameRuntime(
        SQLiteEventStore(path),
        engine_factory=_Factory(),
        shard_count=shard_count,
        **kwargs,
    )


def test_many_sessions_progress_concurrently_without_cross_session_corruption(
    tmp_path: Path,
) -> None:
    runtime = _runtime(tmp_path / "many.sqlite3")
    session_count = 192
    try:
        with ThreadPoolExecutor(max_workers=32) as pool:
            list(
                pool.map(
                    lambda index: runtime.create_game(
                        seed=index, session_id=f"game-{index}"
                    ),
                    range(session_count),
                )
            )
        with ThreadPoolExecutor(max_workers=32) as pool:
            updates = list(
                pool.map(
                    lambda index: runtime.submit_action(
                        f"game-{index}", expected_revision=0, action={"delta": 7}
                    ),
                    range(session_count),
                )
            )
        assert [update.revision for update in updates] == [1] * session_count
        assert [update.state["value"] for update in updates] == [
            index + 7 for index in range(session_count)
        ]
    finally:
        runtime.close()


def test_same_revision_race_commits_exactly_one_command(tmp_path: Path) -> None:
    runtime = _runtime(tmp_path / "race.sqlite3", shard_count=1)
    runtime.create_game(seed=0, session_id="race")
    barrier = threading.Barrier(17)

    def submit(index: int) -> tuple[str, int]:
        barrier.wait()
        try:
            update = runtime.submit_action(
                "race", expected_revision=0, action={"delta": index + 1}
            )
            return ("accepted", int(update.state["value"]))
        except RevisionConflict:
            return ("conflict", 0)

    try:
        with ThreadPoolExecutor(max_workers=16) as pool:
            futures = [pool.submit(submit, index) for index in range(16)]
            barrier.wait()
            results = [future.result(timeout=5) for future in futures]
        assert sum(result[0] == "accepted" for result in results) == 1
        assert sum(result[0] == "conflict" for result in results) == 15
        assert len(runtime.events("race")) == 1
        assert runtime.state("race").revision == 1
    finally:
        runtime.close()


def test_owner_death_expires_then_new_worker_takes_over_and_replays(
    tmp_path: Path,
) -> None:
    path = tmp_path / "takeover.sqlite3"
    leases = _LeaseRepository()
    first = GameRuntime(
        SQLiteEventStore(path),
        engine_factory=_Factory(),
        shard_count=1,
        lease_repository=leases,
        owner_id="worker-a",
        lease_ttl_seconds=5,
    )
    second = GameRuntime(
        SQLiteEventStore(path),
        engine_factory=_Factory(),
        shard_count=1,
        lease_repository=leases,
        owner_id="worker-b",
        lease_ttl_seconds=5,
    )
    try:
        first.create_game(seed=10, session_id="takeover")
        first.submit_action("takeover", expected_revision=0, action={"delta": 2})
        # Reads may be served from replayable durable state without ownership;
        # mutations must be rejected while another worker holds the lease.
        assert second.state("takeover").state["value"] == 12
        with pytest.raises(ServerError, match="another worker"):
            second.submit_action("takeover", expected_revision=1, action={"delta": 100})
        leases.advance(6)
        recovered = second.state("takeover")
        assert recovered.revision == 1
        assert recovered.state["value"] == 12
        assert (
            second.submit_action(
                "takeover", expected_revision=1, action={"delta": 3}
            ).state["value"]
            == 15
        )
    finally:
        first.close()
        second.close()


def test_stale_fencing_token_is_rejected_after_takeover(tmp_path: Path) -> None:
    store = _FencedStore(tmp_path / "fencing.sqlite3")
    store.create_game("fenced", 0, {})
    store.append(
        "fenced",
        expected_revision=0,
        kind="action",
        payload={"delta": 1},
        fencing_token=2,
    )
    with pytest.raises(LeaseLost, match="stale fencing token"):
        store.append(
            "fenced",
            expected_revision=1,
            kind="action",
            payload={"delta": 100},
            fencing_token=1,
        )
    assert store.game("fenced").revision == 1


def test_duplicate_event_delivery_and_queue_saturation_are_bounded() -> None:
    buffer = BoundedEventBuffer(3, 256, BoundedIdempotencyWindow(16, 60))
    first = RealtimeMessage("session:x", "event-1", {"revision": 1})
    assert buffer.enqueue(first) is EnqueueResult.ACCEPTED
    assert buffer.enqueue(first) is EnqueueResult.DUPLICATE
    assert (
        buffer.enqueue(RealtimeMessage("session:x", "event-2", {}))
        is EnqueueResult.ACCEPTED
    )
    assert (
        buffer.enqueue(RealtimeMessage("session:x", "event-3", {}))
        is EnqueueResult.ACCEPTED
    )
    assert (
        buffer.enqueue(RealtimeMessage("session:x", "event-4", {}))
        is EnqueueResult.FULL
    )
    assert len(buffer) == 3
    assert [item.event_id for item in buffer.drain(10)] == [
        "event-1",
        "event-2",
        "event-3",
    ]


class _PubSub:
    def __init__(self, fail_first_read: bool = False) -> None:
        self.fail_first_read = fail_first_read
        self.channels: set[str] = set()
        self.messages: list[dict[str, str]] = []
        self.closed = False

    def subscribe(self, *channels: str) -> None:
        self.channels.update(channels)

    def unsubscribe(self, channel: str) -> None:
        self.channels.discard(channel)

    def get_message(self, timeout: float = 0) -> dict[str, str] | None:
        if self.fail_first_read:
            self.fail_first_read = False
            raise ConnectionError("injected redis disconnect")
        if self.messages:
            return self.messages.pop(0)
        time.sleep(min(timeout, 0.002))
        return None

    def close(self) -> None:
        self.closed = True


class _Redis:
    def __init__(self) -> None:
        self.pubsubs: list[_PubSub] = []

    def pubsub(self, **_kwargs: object) -> _PubSub:
        pubsub = _PubSub(fail_first_read=not self.pubsubs)
        self.pubsubs.append(pubsub)
        return pubsub

    def publish(self, channel: str, body: str) -> None:
        for pubsub in self.pubsubs:
            if not pubsub.closed and channel in pubsub.channels:
                pubsub.messages.append({"data": body})


def test_redis_reconnect_resubscribes_and_fans_out_once_per_subscriber() -> None:
    redis = _Redis()
    bus = RedisRealtimeBus(redis, namespace="chaos", reconnect_delay_seconds=0.001)
    left = bus.subscribe("session:x")
    right = bus.subscribe("session:x")
    try:
        deadline = time.monotonic() + 1
        while len(redis.pubsubs) < 2 and time.monotonic() < deadline:
            time.sleep(0.001)
        assert len(redis.pubsubs) >= 2
        message = RealtimeMessage("session:x", "9", {"revision": 9})
        bus.publish(message)
        assert left.poll(1) == message
        assert right.poll(1) == message
        # At-least-once Redis delivery is deduplicated in each local mailbox.
        redis.publish(
            "chaos:session:x",
            json.dumps(
                {"topic": "session:x", "eventId": "9", "payload": {"revision": 9}}
            ),
        )
        assert left.poll(0.05) is None
        assert right.poll(0.05) is None
    finally:
        left.close()
        right.close()
        bus.close()


def _lobby(path: Path) -> tuple[InMemoryLobbyRepository, str]:
    repository = InMemoryLobbyRepository()
    record = repository.new_session(
        seed=1,
        variants={},
        controllers=["human"] * 4,
        ranked=False,
        browser_joinable=True,
        created_by_user_id="user-0",
        ttl_seconds=3600,
    )
    repository.create(
        record,
        [
            SeatRecord(
                player_id=index,
                controller="human",
                occupied=index == 0,
                user_id="user-0" if index == 0 else None,
                token_hash="token" if index == 0 else None,
                last_seen_at=0.0 if index == 0 else None,
                timeouts=0,
                abandoned=False,
                autopilot=False,
            )
            for index in range(4)
        ],
    )
    repository.set_status(record.session_id, "active", now=1)
    repository.set_turn_deadline(record.session_id, 0, deadline_at=100, now=10)
    return repository, record.session_id


def test_scheduler_duplicate_claims_and_stale_consumption_are_fenced(
    tmp_path: Path,
) -> None:
    repository, session_id = _lobby(tmp_path / "scheduler.sqlite3")
    barrier = threading.Barrier(9)

    def claim(owner: str):  # type: ignore[no-untyped-def]
        barrier.wait()
        return repository.claim_due_turns(
            owner=owner, now=100, lease_seconds=5, limit=1
        )

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(claim, f"scheduler-{index}") for index in range(8)]
        barrier.wait()
        claims = [claim for future in futures for claim in future.result(timeout=5)]
    assert len(claims) == 1
    stale = claims[0]
    takeover = repository.claim_due_turns(
        owner="takeover", now=106, lease_seconds=5, limit=1
    )[0]
    assert takeover.fencing_token > stale.fencing_token
    with pytest.raises(SeatUnavailable, match="stale timeout claim"):
        repository.consume_timeout(stale, now=106)
    result = repository.consume_timeout(takeover, now=106)
    assert result.timeouts == 1
    assert repository.seats(session_id)[0].timeouts == 1


def test_engine_replay_after_repeated_restart_matches_durable_history(
    tmp_path: Path,
) -> None:
    path = tmp_path / "replay.sqlite3"
    expected = 11
    for revision, delta in enumerate((2, 3, 5)):
        runtime = _runtime(path, shard_count=3)
        try:
            if revision == 0:
                runtime.create_game(seed=1, session_id="replay")
            before = runtime.state("replay")
            assert before.revision == revision
            update = runtime.submit_action(
                "replay", expected_revision=revision, action={"delta": delta}
            )
            assert update.revision == revision + 1
        finally:
            runtime.close()
    recovered = _runtime(path, shard_count=7)
    try:
        state = recovered.state("replay")
        assert state.revision == 3
        assert state.state["value"] == expected
        assert [event.revision for event in recovered.events("replay")] == [1, 2, 3]
    finally:
        recovered.close()
