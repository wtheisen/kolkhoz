from __future__ import annotations

import tempfile
import threading
import time
import unittest
from pathlib import Path

from server.kolkhoz_server.lobby import (
    SeatRecord,
    SeatUnavailable,
    SQLiteLobbyRepository,
)


class LobbyRepositoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repository = SQLiteLobbyRepository(
            Path(self.temporary.name) / "lobby.sqlite3"
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def make_session(self):
        record = self.repository.new_session(
            seed=1,
            variants={},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="host",
            ttl_seconds=3600,
        )
        seats = [
            SeatRecord(index, "human", False, None, None, None, 0, False, False)
            for index in range(4)
        ]
        self.repository.create(record, seats)
        return record

    def test_invite_lookup_is_case_insensitive_and_listing_uses_metadata(self) -> None:
        record = self.make_session()
        loaded = self.repository.session(record.invite_code.lower())
        listings = self.repository.list_open(time.time())

        self.assertEqual(loaded.session_id, record.session_id)
        self.assertEqual([value.session_id for value in listings], [record.session_id])

    def test_concurrent_join_claims_exactly_one_seat(self) -> None:
        record = self.make_session()
        barrier = threading.Barrier(3)
        outcomes: list[str] = []

        def join(user_id: str) -> None:
            barrier.wait()
            try:
                self.repository.occupy_seat(
                    record.session_id,
                    0,
                    user_id=user_id,
                    token_hash=user_id,
                    now=time.time(),
                )
                outcomes.append("joined")
            except SeatUnavailable:
                outcomes.append("conflict")

        threads = [
            threading.Thread(target=join, args=(f"user-{index}",)) for index in range(2)
        ]
        for thread in threads:
            thread.start()
        barrier.wait()
        for thread in threads:
            thread.join()

        self.assertCountEqual(outcomes, ["joined", "conflict"])
        self.assertEqual(
            sum(seat.occupied for seat in self.repository.seats(record.session_id)), 1
        )

    def test_presence_counts_only_authenticated_user_rows(self) -> None:
        self.repository.mark_presence("user-1", now=100)
        self.repository.mark_presence("user-2", now=200)
        self.assertEqual(self.repository.online_user_ids(since=150), {"user-2"})

    def test_invite_decline_is_durable(self) -> None:
        record = self.make_session()
        self.repository.invite(record.session_id, {"guest"}, now=time.time())
        self.assertEqual(len(self.repository.invites_for_user("guest")), 1)
        self.repository.decline_invite(record.session_id, "guest")
        self.assertEqual(self.repository.invites_for_user("guest"), [])
