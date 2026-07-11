from __future__ import annotations

import json
import sqlite3
import threading
import time
from contextlib import closing
from pathlib import Path
from typing import Protocol

from .model import GameRecord, JsonObject, StoredEvent


class RevisionConflict(RuntimeError):
    def __init__(self, expected: int, actual: int) -> None:
        super().__init__(f"stale revision: expected {expected}, current {actual}")
        self.expected = expected
        self.actual = actual


class GameNotFound(KeyError):
    pass


class EventStore(Protocol):
    def create_game(
        self, session_id: str, seed: int, variants: JsonObject
    ) -> GameRecord: ...

    def game(self, session_id: str) -> GameRecord: ...

    def events(self, session_id: str, *, after_revision: int = 0) -> list[StoredEvent]: ...

    def append(
        self,
        session_id: str,
        *,
        expected_revision: int,
        kind: str,
        payload: JsonObject,
    ) -> StoredEvent: ...

    def close(self) -> None: ...


SCHEMA = """
pragma journal_mode = wal;
pragma synchronous = normal;

create table if not exists games (
    session_id text primary key,
    seed integer not null,
    variants_json text not null,
    revision integer not null default 0,
    created_at real not null,
    updated_at real not null
);

create table if not exists game_events (
    session_id text not null references games(session_id) on delete cascade,
    revision integer not null,
    kind text not null,
    payload_json text not null,
    created_at real not null,
    primary key (session_id, revision)
);
"""


class SQLiteEventStore:
    """Durable reference adapter with atomic expected-revision commits.

    Each operation checks out its own SQLite connection. There is no process-wide
    Python lock; SQLite/PostgreSQL is responsible for transactional concurrency.
    """

    def __init__(self, path: str | Path) -> None:
        self.path = str(path)
        self._local = threading.local()
        connection = self._connect()
        try:
            connection.executescript(SCHEMA)
        finally:
            connection.close()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.path,
            timeout=5,
            isolation_level=None,
            check_same_thread=False,
        )
        connection.row_factory = sqlite3.Row
        connection.execute("pragma foreign_keys = on")
        return connection

    def create_game(
        self, session_id: str, seed: int, variants: JsonObject
    ) -> GameRecord:
        now = time.time()
        with closing(self._connect()) as connection, connection:
            connection.execute(
                "insert into games values (?, ?, ?, 0, ?, ?)",
                (session_id, seed, json.dumps(variants, sort_keys=True), now, now),
            )
        return GameRecord(session_id, seed, dict(variants), 0)

    def game(self, session_id: str) -> GameRecord:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "select session_id, seed, variants_json, revision from games where session_id = ?",
                (session_id,),
            ).fetchone()
        if row is None:
            raise GameNotFound(session_id)
        return GameRecord(
            str(row["session_id"]),
            int(row["seed"]),
            json.loads(str(row["variants_json"])),
            int(row["revision"]),
        )

    def events(
        self, session_id: str, *, after_revision: int = 0
    ) -> list[StoredEvent]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                select session_id, revision, kind, payload_json, created_at
                  from game_events
                 where session_id = ? and revision > ?
                 order by revision
                """,
                (session_id, after_revision),
            ).fetchall()
        return [
            StoredEvent(
                str(row["session_id"]),
                int(row["revision"]),
                str(row["kind"]),
                json.loads(str(row["payload_json"])),
                float(row["created_at"]),
            )
            for row in rows
        ]

    def append(
        self,
        session_id: str,
        *,
        expected_revision: int,
        kind: str,
        payload: JsonObject,
    ) -> StoredEvent:
        now = time.time()
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            updated = connection.execute(
                """
                update games
                   set revision = revision + 1, updated_at = ?
                 where session_id = ? and revision = ?
                """,
                (now, session_id, expected_revision),
            )
            if updated.rowcount != 1:
                row = connection.execute(
                    "select revision from games where session_id = ?", (session_id,)
                ).fetchone()
                if row is None:
                    raise GameNotFound(session_id)
                raise RevisionConflict(expected_revision, int(row["revision"]))
            revision = expected_revision + 1
            connection.execute(
                "insert into game_events values (?, ?, ?, ?, ?)",
                (session_id, revision, kind, json.dumps(payload, sort_keys=True), now),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
        return StoredEvent(session_id, revision, kind, dict(payload), now)

    def close(self) -> None:
        pass
