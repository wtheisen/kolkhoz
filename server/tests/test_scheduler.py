from __future__ import annotations

import unittest

from server.kolkhoz_server.lobby import SeatRecord
from server.kolkhoz_server.model import GameUpdate
from server.kolkhoz_server.scheduler import DeadlineScheduler
from server.tests.in_memory_lobby import InMemoryLobbyRepository


class FakeRuntime:
    def __init__(self, waiting: int = 0) -> None:
        self.waiting = waiting
        self.controllers: dict[int, str] = {}
        self.advances: list[float | None] = []

    def state(self, session_id: str, viewer_id: int | None = None) -> GameUpdate:
        return GameUpdate(
            session_id, len(self.advances), {"waitingPlayer": self.waiting}
        )

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

    def advance_and_state(
        self, session_id: str, *, viewer_id: int | None = None, now: float | None = None
    ) -> GameUpdate:
        started_at = 0.0 if now is None else now
        self.advance_automatic(session_id, now=started_at)
        self.advance_automatic(session_id, now=started_at + 10.0)
        return self.state(session_id, viewer_id)

    def consume_timeout(self, claim, repository, *, now):  # type: ignore[no-untyped-def]
        result = repository.consume_timeout(claim, now=now)
        self.set_autopilot(claim.session_id, claim.player_id)
        self.advance_automatic(claim.session_id, now=now)
        self.advance_automatic(claim.session_id, now=now + 10.0)
        if not result.forced_autopilot:
            self.set_autopilot(claim.session_id, claim.player_id, "human")
        return self.state(claim.session_id)


class SchedulerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = InMemoryLobbyRepository()
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

    def test_timeout_transition_can_resume_after_claim_is_consumed(self) -> None:
        self.due()
        claim = self.repository.claim_due_turns(
            owner="worker", now=100.0, lease_seconds=10.0, limit=1
        )[0]

        first = self.repository.consume_timeout(claim, now=100.0)
        resumed = self.repository.consume_timeout(claim, now=101.0)
        self.repository.complete_timeout(claim)
        completed = self.repository.consume_timeout(claim, now=102.0)

        self.assertEqual(first.timeouts, 1)
        self.assertFalse(first.completed)
        self.assertEqual(resumed, first)
        self.assertTrue(completed.completed)
        self.assertEqual(self.repository.seats(self.session_id)[0].timeouts, 1)

    def test_scheduler_forces_move_and_sets_next_ninety_second_deadline(self) -> None:
        self.due()
        runtime = FakeRuntime()
        observed: list[tuple[str, int | None]] = []
        scheduler = DeadlineScheduler(
            self.repository,
            runtime,
            owner_id="scheduler",
            clock=lambda: 100.0,
            on_state=lambda session_id, state: observed.append(
                (session_id, state.get("waitingPlayer"))
            ),
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
        self.assertEqual(observed, [(self.session_id, 1)])
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

    def test_scheduler_activates_ready_countdown_without_a_get_request(self) -> None:
        record = self.repository.new_session(
            seed=2,
            variants={},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="ready-0",
            ttl_seconds=3600,
        )
        self.repository.create(
            record,
            [
                SeatRecord(
                    index,
                    "human",
                    True,
                    f"ready-{index}",
                    f"ready-token-{index}",
                    0.0,
                    0,
                    False,
                    False,
                )
                for index in range(4)
            ],
        )
        self.repository.set_status(
            record.session_id,
            "open",
            now=1.0,
            countdown_ends_at=99.0,
        )
        runtime = FakeRuntime(waiting=0)

        DeadlineScheduler(self.repository, runtime).run_once(now=100.0)

        self.assertEqual(self.repository.session(record.session_id).status, "active")
        self.assertEqual(runtime.advances, [100.0, 110.0])


if __name__ == "__main__":
    unittest.main()
