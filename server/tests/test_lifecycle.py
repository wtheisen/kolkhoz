from __future__ import annotations

import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from server.kolkhoz_server.lifecycle import LifecycleReconciler
from server.kolkhoz_server.lobby import SeatRecord, SQLiteLobbyRepository


class _Store:
    def __init__(self) -> None:
        self.games: set[str] = set()

    def game(self, session_id: str) -> object:
        if session_id not in self.games:
            raise KeyError(session_id)
        return object()


class _Runtime:
    def __init__(self) -> None:
        self.store = _Store()
        self.fail_create = False

    def create_game(self, *, session_id: str, **unused: object) -> None:
        if self.fail_create:
            raise RuntimeError("injected create failure")
        self.store.games.add(session_id)

    def delete_game(self, session_id: str) -> None:
        if session_id not in self.store.games:
            raise KeyError(session_id)
        self.store.games.remove(session_id)


class LifecycleReconcilerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repository = SQLiteLobbyRepository(
            Path(self.temporary.name) / "lifecycle.sqlite3"
        )
        self.runtime = _Runtime()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def create_lobby(self):
        record = self.repository.new_session(
            seed=7,
            variants={"wrecker": True},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            created_by_user_id="host",
            ttl_seconds=100,
        )
        self.repository.create(
            record,
            [
                SeatRecord(i, "human", False, None, None, None, 0, False, False)
                for i in range(4)
            ],
        )
        return record

    def test_crash_after_lobby_create_is_reconciled_and_intent_completed(self) -> None:
        record = self.create_lobby()
        reconciler = LifecycleReconciler(
            self.repository,
            self.runtime,
            owner_id="worker",
            clock=lambda: record.created_at,
        )

        self.assertEqual(reconciler.run_once(), 1)
        self.assertIn(record.session_id, self.runtime.store.games)
        self.assertEqual(reconciler.run_once(), 0)

    def test_intent_insert_failure_rolls_back_lobby_and_seats(self) -> None:
        with closing(self.repository._connect()) as connection, connection:
            connection.execute(
                """create trigger fail_provision_intent
                     before insert on server_lifecycle_intents
                     begin select raise(abort, 'injected intent failure'); end"""
            )
        with self.assertRaisesRegex(Exception, "injected intent failure"):
            self.create_lobby()
        with closing(self.repository._connect()) as connection:
            self.assertEqual(
                connection.execute("select count(*) from server_sessions").fetchone()[
                    0
                ],
                0,
            )
            self.assertEqual(
                connection.execute("select count(*) from server_seats").fetchone()[0],
                0,
            )

    def test_failed_event_create_is_retried_after_bounded_backoff(self) -> None:
        record = self.create_lobby()
        self.runtime.fail_create = True
        reconciler = LifecycleReconciler(
            self.repository, self.runtime, owner_id="worker", retry_seconds=2
        )

        with self.assertLogs(level="ERROR"):
            self.assertEqual(reconciler.run_once(now=record.created_at), 0)
        self.runtime.fail_create = False
        self.assertEqual(reconciler.run_once(now=record.created_at + 1), 0)
        self.assertEqual(reconciler.run_once(now=record.created_at + 2), 1)

    def test_failure_after_event_create_schedules_orphan_deletion(self) -> None:
        record = self.create_lobby()
        self.runtime.store.games.add(record.session_id)
        # Mirrors API rollback when event creation returned but intent completion failed.
        self.repository.delete_session(record.session_id)

        reconciler = LifecycleReconciler(
            self.repository, self.runtime, owner_id="worker"
        )
        self.assertEqual(reconciler.run_once(now=record.created_at + 1), 2)
        self.assertNotIn(record.session_id, self.runtime.store.games)

    def test_crash_after_lobby_delete_converges_event_store_delete(self) -> None:
        record = self.create_lobby()
        self.runtime.store.games.add(record.session_id)
        self.repository.occupy_seat(
            record.session_id, 0, user_id="host", token_hash="x", now=record.created_at
        )
        self.repository.complete_lifecycle_intent(record.session_id, "provision")
        self.repository.release_seat_and_delete_if_empty(
            record.session_id, 0, now=record.created_at + 1
        )

        reconciler = LifecycleReconciler(
            self.repository, self.runtime, owner_id="worker"
        )
        self.assertEqual(reconciler.run_once(now=record.created_at + 1), 1)
        self.assertNotIn(record.session_id, self.runtime.store.games)

    def test_delete_intent_failure_rolls_back_last_seat_release(self) -> None:
        record = self.create_lobby()
        self.repository.occupy_seat(
            record.session_id, 0, user_id="host", token_hash="x", now=record.created_at
        )
        with closing(self.repository._connect()) as connection, connection:
            connection.execute(
                """create trigger fail_delete_intent before insert on server_lifecycle_intents
                     when new.operation = 'delete'
                     begin select raise(abort, 'injected delete intent failure'); end"""
            )
        with self.assertRaisesRegex(Exception, "injected delete intent failure"):
            self.repository.release_seat_and_delete_if_empty(
                record.session_id, 0, now=record.created_at + 1
            )
        self.assertTrue(self.repository.seats(record.session_id)[0].occupied)


if __name__ == "__main__":
    unittest.main()
