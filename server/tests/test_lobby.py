from __future__ import annotations

import tempfile
import threading
import time
import unittest
from contextlib import contextmanager
from pathlib import Path

from server.kolkhoz_server.lobby import (
    PostgresLobbyRepository,
    SeatRecord,
    SeatUnavailable,
    SQLiteLobbyRepository,
)


class FakeResult:
    def __init__(self, *, row=None, rows=None) -> None:
        self._row = row
        self._rows = rows or []

    def fetchone(self):
        return self._row

    def fetchall(self):
        return self._rows


class FakeConnection:
    def __init__(self, responses) -> None:
        self.responses = list(responses)
        self.executions = []

    @contextmanager
    def transaction(self):
        yield

    def execute(self, sql, parameters):
        self.executions.append((" ".join(sql.split()), parameters))
        return self.responses.pop(0) if self.responses else FakeResult()


class FakePool:
    def __init__(self, connection) -> None:
        self.value = connection

    @contextmanager
    def connection(self):
        yield self.value


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


class PostgresLobbyRepositoryTests(unittest.TestCase):
    @staticmethod
    def repository(connection: FakeConnection) -> PostgresLobbyRepository:
        repository = PostgresLobbyRepository.__new__(PostgresLobbyRepository)
        repository._pool = FakePool(connection)
        repository._jsonb = lambda value: value
        return repository

    def test_seat_claim_is_one_conditional_update_in_a_transaction(self) -> None:
        connection = FakeConnection([FakeResult(row=(2,)), FakeResult()])
        repository = self.repository(connection)

        repository.occupy_seat(
            "00000000-0000-0000-0000-000000000001",
            2,
            user_id="user-1",
            token_hash="hash",
            now=123.0,
        )

        claim_sql, claim_parameters = connection.executions[0]
        self.assertIn("and controller = 'human' and not occupied", claim_sql)
        self.assertIn("returning player_id", claim_sql)
        self.assertEqual(claim_parameters[-1], 2)

    def test_failed_conditional_seat_claim_reports_unavailable(self) -> None:
        connection = FakeConnection([FakeResult(row=None)])
        repository = self.repository(connection)

        with self.assertRaises(SeatUnavailable):
            repository.occupy_seat(
                "00000000-0000-0000-0000-000000000001",
                0,
                user_id="user-1",
                token_hash="hash",
                now=123.0,
            )

    def test_reaction_revision_uses_atomic_session_counter(self) -> None:
        connection = FakeConnection([FakeResult(row=(7,)), FakeResult()])
        repository = self.repository(connection)

        reaction = repository.append_reaction(
            "00000000-0000-0000-0000-000000000001",
            player_id=1,
            reaction_id="wave",
            year=2,
            phase=3,
            now=456.0,
        )

        revision_sql, _ = connection.executions[0]
        self.assertIn("reaction_revision = reaction_revision + 1", revision_sql)
        self.assertEqual(reaction["revision"], 7)

    def test_open_listing_maps_json_and_epoch_columns(self) -> None:
        row = (
            "00000000-0000-0000-0000-000000000001",
            "ABC234",
            12,
            {"wrecker": True},
            ["human", "ai", "ai", "ai"],
            False,
            True,
            "open",
            "host",
            1.0,
            2.0,
            3.0,
            None,
        )
        connection = FakeConnection([FakeResult(rows=[row])])
        repository = self.repository(connection)

        records = repository.list_open(2.5)

        self.assertEqual(records[0].invite_code, "ABC234")
        self.assertEqual(records[0].variants, {"wrecker": True})
        listing_sql, _ = connection.executions[0]
        self.assertIn("exists ( select 1 from server_seats", listing_sql)
