from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from server.kolkhoz_server.lobby import (
    SQLiteLobbyRepository,
    SeatRecord,
)
from server.kolkhoz_server.model import GameUpdate
from server.kolkhoz_server.scheduler import DeadlineScheduler


class FakeRuntime:
    def __init__(self, waiting: int = 0) -> None:
        self.waiting = waiting
        self.controllers: dict[int, str] = {}
        self.advances: list[float | None] = []

    def state(self, session_id: str, viewer_id: int | None = None) -> GameUpdate:
        return GameUpdate(
            session_id, len(self.advances), {"waitingPlayer": self.waiting}
        )

    def serialize(self, session_id: str, operation):  # type: ignore[no-untyped-def]
        return operation()

    def set_autopilot(
        self, session_id: str, player_id: int, controller: str = "heuristicAI"
    ) -> None:
        self.controllers[player_id] = controller

    def advance_automatic(self, session_id: str, *, now: float | None = None) -> int:
        self.advances.append(now)
        if len(self.advances) % 2 == 0:
            self.waiting = 1
            return 1
        return 0


class SchedulerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repository = SQLiteLobbyRepository(
            Path(self.temporary.name) / "lobby.sqlite3"
        )
        record = self.repository.new_session(
            seed=1,
            variants={},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="user-0",
            ttl_seconds=3600,
        )
        self.session_id = record.session_id
        self.repository.create(
            record,
            [
                SeatRecord(
                    index,
                    "human",
                    index in (0, 1),
                    f"user-{index}" if index in (0, 1) else None,
                    f"token-{index}" if index in (0, 1) else None,
                    0.0 if index in (0, 1) else None,
                    0,
                    False,
                    False,
                )
                for index in range(4)
            ],
        )
        self.repository.set_status(self.session_id, "active", now=1.0)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def due(self, deadline: float = 100.0) -> None:
        self.repository.set_turn_deadline(
            self.session_id, 0, deadline_at=deadline, now=deadline - 90
        )

    def test_claims_are_exclusive_and_recover_after_lease_expiry(self) -> None:
        self.due()
        first = self.repository.claim_due_turns(
            owner="one", now=100.0, lease_seconds=10.0, limit=8
        )
        concurrent = self.repository.claim_due_turns(
            owner="two", now=100.0, lease_seconds=10.0, limit=8
        )
        recovered = self.repository.claim_due_turns(
            owner="two", now=111.0, lease_seconds=10.0, limit=8
        )

        self.assertEqual(len(first), 1)
        self.assertEqual(concurrent, [])
        self.assertEqual(len(recovered), 1)
        self.assertGreater(recovered[0].fencing_token, first[0].fencing_token)

    def test_two_timeouts_force_abandon_and_autopilot(self) -> None:
        self.due()
        first = self.repository.claim_due_turns(
            owner="worker", now=100.0, lease_seconds=10.0, limit=1
        )[0]
        first_result = self.repository.consume_timeout(first, now=100.0)
        self.due(200.0)
        second = self.repository.claim_due_turns(
            owner="worker", now=200.0, lease_seconds=10.0, limit=1
        )[0]
        second_result = self.repository.consume_timeout(second, now=200.0)

        seat = self.repository.seats(self.session_id)[0]
        self.assertEqual(first_result.timeouts, 1)
        self.assertFalse(first_result.forced_autopilot)
        self.assertEqual(second_result.timeouts, 2)
        self.assertTrue(second_result.forced_autopilot)
        self.assertTrue(seat.autopilot)
        self.assertTrue(seat.abandoned)

    def test_scheduler_forces_move_and_sets_next_ninety_second_deadline(self) -> None:
        self.due()
        runtime = FakeRuntime()
        scheduler = DeadlineScheduler(
            self.repository, runtime, owner_id="scheduler", clock=lambda: 100.0
        )

        self.assertEqual(scheduler.run_once(), 1)

        seat = self.repository.seats(self.session_id)[0]
        next_claim = self.repository.claim_due_turns(
            owner="later", now=189.9, lease_seconds=10, limit=1
        )
        due_claim = self.repository.claim_due_turns(
            owner="later", now=190.0, lease_seconds=10, limit=1
        )
        self.assertEqual(seat.timeouts, 1)
        self.assertEqual(runtime.controllers[0], "human")
        self.assertEqual(runtime.advances, [100.0, 110.0])
        self.assertEqual(next_claim, [])
        self.assertEqual(due_claim[0].player_id, 1)

    def test_stale_engine_waiting_player_does_not_record_timeout(self) -> None:
        self.due()
        runtime = FakeRuntime(waiting=1)
        scheduler = DeadlineScheduler(self.repository, runtime, owner_id="scheduler")

        self.assertEqual(scheduler.run_once(now=100.0), 0)
        self.assertEqual(self.repository.seats(self.session_id)[0].timeouts, 0)
        self.assertEqual(
            self.repository.claim_due_turns(
                owner="later", now=189.9, lease_seconds=10, limit=1
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
