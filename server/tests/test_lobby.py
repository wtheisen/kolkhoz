from __future__ import annotations

import tempfile
import threading
import time
import unittest
from contextlib import closing, contextmanager
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

    def test_create_releases_same_user_seat_from_finished_session(self) -> None:
        first = self.repository.new_session(
            seed=1,
            variants={},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="host",
            ttl_seconds=3600,
        )
        occupied = SeatRecord(
            0, "human", True, "host", "token", time.time(), 0, False, False
        )
        empty = [
            SeatRecord(index, "human", False, None, None, None, 0, False, False)
            for index in range(1, 4)
        ]
        self.repository.create(first, [occupied, *empty])
        self.repository.set_status(first.session_id, "active", now=time.time())
        self.assertTrue(
            self.repository.finish_session(
                first.session_id, now=time.time(), expires_at=time.time() + 3600
            )
        )
        self.assertTrue(self.repository.seats(first.session_id)[0].occupied)

        second = self.repository.new_session(
            seed=2,
            variants={},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="host",
            ttl_seconds=3600,
        )
        self.repository.create(second, [occupied, *empty])

        self.assertFalse(self.repository.seats(first.session_id)[0].occupied)
        self.assertTrue(self.repository.seats(second.session_id)[0].occupied)

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

    def test_join_releases_same_user_seat_from_finished_session(self) -> None:
        first = self.make_session()
        self.repository.occupy_seat(
            first.session_id,
            0,
            user_id="returning-user",
            token_hash="old-token",
            now=time.time(),
        )
        self.repository.set_status(first.session_id, "finished", now=time.time())
        second = self.make_session()

        self.repository.occupy_seat(
            second.session_id,
            0,
            user_id="returning-user",
            token_hash="new-token",
            now=time.time(),
        )

        self.assertFalse(self.repository.seats(first.session_id)[0].occupied)
        self.assertTrue(self.repository.seats(second.session_id)[0].occupied)

    def test_abandoned_membership_does_not_block_a_new_active_seat(self) -> None:
        first = self.make_session()
        self.repository.occupy_seat(
            first.session_id,
            0,
            user_id="returning-user",
            token_hash="old-token",
            now=time.time(),
        )
        self.repository.set_status(first.session_id, "active", now=time.time())
        self.repository.abandon_seat(first.session_id, 0, now=time.time())
        second = self.make_session()

        self.repository.occupy_seat(
            second.session_id,
            0,
            user_id="returning-user",
            token_hash="new-token",
            now=time.time(),
        )

        old_seat = self.repository.seats(first.session_id)[0]
        self.assertTrue(old_seat.occupied)
        self.assertTrue(old_seat.abandoned)
        self.assertIsNone(self.repository.active_for_user("missing-user"))
        active = self.repository.active_for_user("returning-user")
        self.assertIsNotNone(active)
        self.assertEqual(active[0].session_id, second.session_id)

    def test_presence_counts_only_authenticated_user_rows(self) -> None:
        self.repository.mark_presence("user-1", now=100)
        self.repository.mark_presence("user-2", now=200)
        self.assertEqual(self.repository.online_user_ids(since=150), {"user-2"})

    def test_citizens_online_includes_active_profile_bots_without_duplicates(
        self,
    ) -> None:
        record = self.make_session()
        with self.repository._connect() as connection:
            connection.execute(
                """update server_seats
                      set controller = 'heuristicAI', occupied = 1,
                          user_id = 'bot-1'
                    where session_id = ? and player_id = 1""",
                (record.session_id,),
            )
            connection.commit()
        self.repository.mark_presence("human-1", now=200)
        self.repository.mark_presence("bot-1", now=200)

        metrics = self.repository.metrics_state(now=200, presence_since=150)

        self.assertEqual(metrics["citizensOnline"], 2)
        self.repository.set_status(record.session_id, "finished", now=201)
        metrics = self.repository.metrics_state(now=201, presence_since=150)
        self.assertEqual(metrics["citizensOnline"], 2)

    def test_fresh_device_lease_blocks_takeover_but_stale_lease_expires(self) -> None:
        record = self.make_session()
        self.assertTrue(
            self.repository.acquire_device_lease(
                "host", "phone", record.session_id, now=100, ttl_seconds=60
            )
        )
        self.assertFalse(
            self.repository.acquire_device_lease(
                "host", "tablet", record.session_id, now=159, ttl_seconds=60
            )
        )
        self.assertTrue(
            self.repository.acquire_device_lease(
                "host", "tablet", record.session_id, now=161, ttl_seconds=60
            )
        )

    def test_concurrent_device_takeover_has_exactly_one_winner(self) -> None:
        record = self.make_session()
        barrier = threading.Barrier(3)
        outcomes: list[bool] = []

        def acquire(device_id: str) -> None:
            barrier.wait()
            outcomes.append(
                self.repository.acquire_device_lease(
                    "host", device_id, record.session_id, now=100, ttl_seconds=60
                )
            )

        threads = [
            threading.Thread(target=acquire, args=(value,)) for value in ("a", "b")
        ]
        for thread in threads:
            thread.start()
        barrier.wait()
        for thread in threads:
            thread.join()
        self.assertCountEqual(outcomes, [True, False])

    def test_invite_decline_is_durable(self) -> None:
        record = self.make_session()
        self.repository.invite(record.session_id, {"guest"}, now=time.time())
        self.assertEqual(len(self.repository.invites_for_user("guest")), 1)
        self.repository.decline_invite(record.session_id, "guest")
        self.assertEqual(self.repository.invites_for_user("guest"), [])

    def test_last_seat_release_deletes_lobby_in_same_transaction(self) -> None:
        record = self.make_session()
        self.repository.occupy_seat(
            record.session_id,
            0,
            user_id="host",
            token_hash="token",
            now=100,
        )

        deleted = self.repository.release_seat_and_delete_if_empty(
            record.session_id, 0, now=101
        )

        self.assertTrue(deleted)
        with self.assertRaises(KeyError):
            self.repository.session(record.session_id)
        self.assertEqual(self.repository.seats(record.session_id), [])

    def test_kick_rolls_back_seat_release_when_metadata_update_fails(self) -> None:
        record = self.make_session()
        self.repository.occupy_seat(
            record.session_id,
            0,
            user_id="host",
            token_hash="host-token",
            now=100,
        )
        self.repository.occupy_seat(
            record.session_id,
            1,
            user_id="guest",
            token_hash="guest-token",
            now=100,
        )
        with closing(self.repository._connect()) as connection, connection:
            connection.execute(
                """
                create trigger fail_lifecycle_update before update on server_sessions
                begin select raise(abort, 'injected failure'); end
                """
            )

        with self.assertRaisesRegex(Exception, "injected failure"):
            self.repository.kick_seat(
                record.session_id, 1, host_user_id="host", now=101
            )

        guest = self.repository.seats(record.session_id)[1]
        self.assertTrue(guest.occupied)
        self.assertEqual(guest.user_id, "guest")


class PostgresLobbyRepositoryTests(unittest.TestCase):
    @staticmethod
    def repository(connection: FakeConnection) -> PostgresLobbyRepository:
        repository = PostgresLobbyRepository.__new__(PostgresLobbyRepository)
        repository._pool = FakePool(connection)
        repository._jsonb = lambda value: value
        return repository

    def test_seat_claim_is_one_conditional_update_in_a_transaction(self) -> None:
        connection = FakeConnection([FakeResult(), FakeResult(row=(2,)), FakeResult()])
        repository = self.repository(connection)

        repository.occupy_seat(
            "00000000-0000-0000-0000-000000000001",
            2,
            user_id="user-1",
            token_hash="hash",
            now=123.0,
        )

        claim_sql, claim_parameters = connection.executions[1]
        self.assertIn("and controller = 'human' and not occupied", claim_sql)
        self.assertIn("returning player_id", claim_sql)
        self.assertEqual(claim_parameters[-1], 2)

    def test_metrics_count_recent_people_and_all_active_profile_bots(self) -> None:
        connection = FakeConnection([FakeResult(row=(1, 2, 3, 16))])
        repository = self.repository(connection)

        metrics = repository.metrics_state(now=200, presence_since=150)

        self.assertEqual(metrics["citizensOnline"], 16)
        sql, parameters = connection.executions[0]
        self.assertIn("from public.server_bot_profiles where active", sql)
        self.assertEqual(parameters, (200, 150, 150))

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

    def test_device_lease_serializes_by_user_and_rejects_fresh_conflict(self) -> None:
        connection = FakeConnection([FakeResult(), FakeResult(row=(1,))])
        repository = self.repository(connection)

        acquired = repository.acquire_device_lease(
            "user-1",
            "tablet",
            "00000000-0000-0000-0000-000000000001",
            now=123,
            ttl_seconds=60,
        )

        self.assertFalse(acquired)
        self.assertIn("pg_advisory_xact_lock", connection.executions[0][0])
        self.assertIn("device_id <>", connection.executions[1][0])

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

    def test_kick_is_conditioned_on_open_session_and_host_in_one_statement(
        self,
    ) -> None:
        connection = FakeConnection([FakeResult(row=(1,)), FakeResult()])
        repository = self.repository(connection)

        repository.kick_seat(
            "00000000-0000-0000-0000-000000000001",
            1,
            host_user_id="host",
            now=123,
        )

        kick_sql, parameters = connection.executions[0]
        self.assertIn("from server_sessions sessions", kick_sql)
        self.assertIn("sessions.status = 'open'", kick_sql)
        self.assertIn("sessions.created_by_user_id = %s", kick_sql)
        self.assertEqual(parameters[-1], "host")
