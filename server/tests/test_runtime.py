from __future__ import annotations

import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from server.kolkhoz_server.events import EventHub
from server.kolkhoz_server.ai import AutomaticAdvancer, ModelCache
from server.kolkhoz_server.distributed import SessionLease
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.runtime import GameRuntime, GatewayRuntimeContext
from server.kolkhoz_server.store import (
    ConnectionPool,
    RevisionConflict,
    SQLiteEventStore,
)


class FakeEngine:
    def __init__(self, seed: int, delay: float, tracker: "EngineTracker") -> None:
        self.value = seed
        self.delay = delay
        self.tracker = tracker
        self.closed = False

    def apply(self, action: dict[str, object]) -> None:
        thread_id = threading.get_ident()
        self.tracker.thread_ids.add(thread_id)
        with self.tracker.active_lock:
            self.tracker.active += 1
            self.tracker.max_active = max(self.tracker.max_active, self.tracker.active)
        try:
            if self.delay:
                time.sleep(self.delay)
            delta = action.get("delta")
            if not isinstance(delta, int):
                raise ValueError("delta must be an integer")
            self.value += delta
        finally:
            with self.tracker.active_lock:
                self.tracker.active -= 1

    def view(self, viewer_id: int | None = None) -> dict[str, object]:
        return {"value": self.value, "viewerID": viewer_id}

    def close(self) -> None:
        self.closed = True


class EngineTracker:
    def __init__(self) -> None:
        self.thread_ids: set[int] = set()
        self.active = 0
        self.max_active = 0
        self.active_lock = threading.Lock()


class FakeEngineFactory:
    def __init__(self, delay: float = 0) -> None:
        self.delay = delay
        self.tracker = EngineTracker()

    def create(self, seed: int, variants: dict[str, object]) -> FakeEngine:
        return FakeEngine(seed, self.delay, self.tracker)


class AutomaticFakeEngine(FakeEngine):
    def __init__(
        self, seed: int, controllers: list[str], tracker: EngineTracker
    ) -> None:
        super().__init__(seed, 0, tracker)
        self.controllers = list(controllers)
        self.waiting = 0

    def apply(self, action: dict[str, object]) -> None:
        super().apply(action)
        self.waiting = 1

    def waiting_player(self) -> int:
        return self.waiting

    def legal_actions(self) -> list[dict[str, object]]:
        return [{"playerID": self.waiting, "delta": 10}]

    def heuristic_action(self) -> dict[str, object]:
        return self.legal_actions()[0]

    def policy_action(self, model: object) -> dict[str, object]:
        return self.legal_actions()[0]

    def apply_ai_action(self, action: dict[str, object]) -> None:
        FakeEngine.apply(self, action)
        self.waiting = 0

    def controller(self, player_id: int) -> str:
        return self.controllers[player_id]

    def set_controller(self, player_id: int, controller: str) -> None:
        self.controllers[player_id] = controller


class AutomaticFakeFactory:
    def __init__(self) -> None:
        self.tracker = EngineTracker()

    def create(self, seed: int, variants: dict[str, object]) -> AutomaticFakeEngine:
        controllers = variants.get("controllers", ["human"] * 4)
        return AutomaticFakeEngine(seed, list(controllers), self.tracker)


class RuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.database = Path(self.temporary.name) / "events.sqlite3"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_gateway_runtime_context_has_no_engine_shards(self) -> None:
        store = SQLiteEventStore(self.database)
        context = GatewayRuntimeContext(store, EventHub(), "gateway-a")

        self.assertEqual(context.metrics_state()["shards"], 0)
        self.assertEqual(context.owner_id, "gateway-a")
        self.assertEqual(context.health_state()["status"], "ok")
        self.assertEqual(context.health_state()["engineSHA256"], "remote")
        context.close()
        store.close()

    def test_create_is_idempotent_for_lifecycle_reconciliation(self) -> None:
        runtime = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=FakeEngineFactory(),
            shard_count=1,
        )
        try:
            first = runtime.create_game(
                seed=9, variants={"controllers": ["human"] * 4}, session_id="same"
            )
            repeated = runtime.create_game(
                seed=9, variants={"controllers": ["human"] * 4}, session_id="same"
            )
            self.assertEqual(repeated, first)
            with self.assertRaisesRegex(ValueError, "different settings"):
                runtime.create_game(seed=10, session_id="same")
        finally:
            runtime.close()

    def runtime(
        self, *, factory: FakeEngineFactory | None = None, shards: int = 4
    ) -> GameRuntime:
        return GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=factory or FakeEngineFactory(),
            shard_count=shards,
        )

    def test_committed_actions_are_ordered_and_revisioned(self) -> None:
        runtime = self.runtime()
        try:
            created = runtime.create_game(seed=10, session_id="ordered")
            first = runtime.submit_action(
                "ordered", expected_revision=0, action={"delta": 2}
            )
            second = runtime.submit_action(
                "ordered", expected_revision=1, action={"delta": 5}
            )
        finally:
            runtime.close()

        self.assertEqual(created.revision, 0)
        self.assertEqual(first.revision, 1)
        self.assertEqual(second.revision, 2)
        self.assertEqual(second.state["value"], 17)

    def test_stale_revision_does_not_mutate_live_engine(self) -> None:
        runtime = self.runtime()
        try:
            runtime.create_game(seed=1, session_id="stale")
            runtime.submit_action("stale", expected_revision=0, action={"delta": 3})
            with self.assertRaises(RevisionConflict):
                runtime.submit_action(
                    "stale", expected_revision=0, action={"delta": 100}
                )
            state = runtime.state("stale")
        finally:
            runtime.close()

        self.assertEqual(state.revision, 1)
        self.assertEqual(state.state["value"], 4)

    def test_different_shards_execute_concurrently(self) -> None:
        factory = FakeEngineFactory(delay=0.2)
        runtime = self.runtime(factory=factory, shards=2)
        try:
            left = "left"
            right = next(
                f"right-{index}"
                for index in range(100)
                if runtime.shard_index(f"right-{index}") != runtime.shard_index(left)
            )
            runtime.create_game(seed=0, session_id=left)
            runtime.create_game(seed=0, session_id=right)
            barrier = threading.Barrier(3)

            def submit(session_id: str) -> None:
                barrier.wait()
                runtime.submit_action(
                    session_id, expected_revision=0, action={"delta": 1}
                )

            threads = [
                threading.Thread(target=submit, args=(value,))
                for value in (left, right)
            ]
            for thread in threads:
                thread.start()
            barrier.wait()
            for thread in threads:
                thread.join()
        finally:
            runtime.close()

        self.assertGreaterEqual(factory.tracker.max_active, 2)

    def test_runtime_recovers_engine_by_replaying_events(self) -> None:
        first = self.runtime()
        first.create_game(seed=7, session_id="recover")
        first.submit_action("recover", expected_revision=0, action={"delta": 4})
        first.submit_action("recover", expected_revision=1, action={"delta": 6})
        first.close()

        second = self.runtime()
        try:
            recovered = second.state("recover")
        finally:
            second.close()

        self.assertEqual(recovered.revision, 2)
        self.assertEqual(recovered.state["value"], 17)

    def test_committed_event_is_published_to_realtime_boundary(self) -> None:
        hub = EventHub()
        runtime = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=FakeEngineFactory(),
            shard_count=1,
            event_hub=hub,
        )
        try:
            runtime.create_game(seed=0, session_id="live")
            with hub.subscribe("live") as subscription:
                runtime.submit_action("live", expected_revision=0, action={"delta": 1})
                event = subscription.get(timeout=1)
        finally:
            runtime.close()

        self.assertEqual(event.revision, 1)
        self.assertEqual(event.payload, {"delta": 1})

    def test_runtime_persists_automatic_actions_on_same_session_shard(self) -> None:
        factory = AutomaticFakeFactory()
        runtime = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=factory,
            shard_count=2,
            automatic_advancer=AutomaticAdvancer(ModelCache({}, lambda path: object())),
        )
        try:
            runtime.create_game(
                seed=0,
                session_id="automatic",
                variants={"controllers": ["human", "heuristicAI", "human", "human"]},
            )
            runtime.submit_action(
                "automatic",
                expected_revision=0,
                action={"playerID": 0, "delta": 1},
            )
            scheduled = runtime.advance_automatic("automatic", now=100)
            applied = runtime.advance_automatic("automatic", now=110)
            state = runtime.state("automatic")
            events = runtime.events("automatic")
        finally:
            runtime.close()

        self.assertEqual(scheduled, 0)
        self.assertEqual(applied, 1)
        self.assertEqual(state.revision, 2)
        self.assertEqual(state.state["value"], 11)
        self.assertEqual(events[-1].payload["source"], "automatic")

    def test_human_turn_automatic_check_does_not_renew_session_lease(self) -> None:
        leases = FakeLeaseRepository()
        runtime = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=AutomaticFakeFactory(),
            shard_count=1,
            automatic_advancer=AutomaticAdvancer(ModelCache({}, lambda path: object())),
            lease_repository=leases,
        )
        try:
            runtime.create_game(seed=0, session_id="human-turn")
            renewals = leases.renew_calls
            self.assertEqual(runtime.advance_automatic("human-turn"), 0)
            self.assertEqual(leases.renew_calls, renewals)
        finally:
            runtime.close()

    def test_distributed_lease_allows_only_one_mutating_runtime_owner(self) -> None:
        leases = FakeLeaseRepository()
        first = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=FakeEngineFactory(),
            shard_count=1,
            lease_repository=leases,
            owner_id="worker-a",
        )
        second = GameRuntime(
            SQLiteEventStore(self.database),
            engine_factory=FakeEngineFactory(),
            shard_count=1,
            lease_repository=leases,
            owner_id="worker-b",
        )
        first.create_game(seed=0, session_id="leased")
        try:
            with self.assertRaisesRegex(ServerError, "another worker"):
                second.submit_action("leased", expected_revision=0, action={"delta": 1})
        finally:
            first.close()
        try:
            accepted = second.submit_action(
                "leased", expected_revision=0, action={"delta": 1}
            )
        finally:
            second.close()

        self.assertEqual(accepted.revision, 1)


class ConnectionPoolTests(unittest.TestCase):
    def test_pool_allows_bounded_parallel_leases(self) -> None:
        created: list[FakeConnection] = []

        def connect() -> "FakeConnection":
            connection = FakeConnection()
            created.append(connection)
            return connection

        pool = ConnectionPool(connect, size=2)
        barrier = threading.Barrier(3)
        leased: list[FakeConnection] = []

        def lease() -> None:
            with pool.connection() as connection:
                leased.append(connection)  # type: ignore[arg-type]
                barrier.wait()
                barrier.wait()

        threads = [threading.Thread(target=lease) for _ in range(2)]
        for thread in threads:
            thread.start()
        barrier.wait()
        self.assertEqual(len(created), 2)
        self.assertIsNot(leased[0], leased[1])
        barrier.wait()
        for thread in threads:
            thread.join()
        self.assertTrue(all(connection.rollbacks == 1 for connection in created))
        pool.close()
        self.assertTrue(all(connection.closed for connection in created))

    def test_pool_discards_connection_when_idle_rollback_fails(self) -> None:
        created: list[FakeConnection] = []

        def connect() -> FakeConnection:
            connection = FakeConnection(fail_rollback=not created)
            created.append(connection)
            return connection

        pool = ConnectionPool(connect, size=1)
        with pool.connection():
            pass
        with pool.connection() as replacement:
            self.assertIs(replacement, created[1])
        self.assertTrue(created[0].closed)
        pool.close()


class FakeConnection:
    def __init__(self, *, fail_rollback: bool = False) -> None:
        self.closed = False
        self.rollbacks = 0
        self.fail_rollback = fail_rollback

    def rollback(self) -> None:
        self.rollbacks += 1
        if self.fail_rollback:
            raise RuntimeError("connection lost")

    def close(self) -> None:
        self.closed = True


class FakeLeaseRepository:
    def __init__(self) -> None:
        self.current: dict[str, SessionLease] = {}
        self.tokens: dict[str, int] = {}
        self.renew_calls = 0

    def acquire(
        self, session_id: str, owner_id: str, ttl: timedelta
    ) -> SessionLease | None:
        existing = self.current.get(session_id)
        if existing is not None and existing.owner_id != owner_id:
            return None
        token = self.tokens.get(session_id, 0) + int(existing is None)
        self.tokens[session_id] = token
        lease = SessionLease(
            session_id,
            owner_id,
            token,
            datetime.now(timezone.utc) + ttl,
        )
        self.current[session_id] = lease
        return lease

    def renew(self, lease: SessionLease, ttl: timedelta) -> SessionLease | None:
        self.renew_calls += 1
        if self.current.get(lease.session_id) != lease:
            return None
        renewed = SessionLease(
            lease.session_id,
            lease.owner_id,
            lease.fencing_token,
            datetime.now(timezone.utc) + ttl,
        )
        self.current[lease.session_id] = renewed
        return renewed

    def release(self, lease: SessionLease) -> bool:
        if self.current.get(lease.session_id) != lease:
            return False
        self.current.pop(lease.session_id)
        return True


if __name__ == "__main__":
    unittest.main()
