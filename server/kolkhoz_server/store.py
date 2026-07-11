from __future__ import annotations

import json
import queue
import sqlite3
import threading
import time
from contextlib import closing
from contextlib import contextmanager
from pathlib import Path
from typing import Callable, Iterator, Protocol

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

    def events(
        self, session_id: str, *, after_revision: int = 0
    ) -> list[StoredEvent]: ...

    def append(
        self,
        session_id: str,
        *,
        expected_revision: int,
        kind: str,
        payload: JsonObject,
    ) -> StoredEvent: ...

    def close(self) -> None: ...


class ConnectionPool:
    """Small bounded DB-API pool with no global query lock."""

    def __init__(self, connect: Callable[[], object], *, size: int = 8) -> None:
        if size < 1:
            raise ValueError("pool size must be positive")
        self._connect = connect
        self._available: queue.LifoQueue[object] = queue.LifoQueue(maxsize=size)
        self._all: list[object] = []
        self._creation_lock = threading.Lock()
        self._size = size
        self._closed = False

    @contextmanager
    def connection(self) -> Iterator[object]:
        if self._closed:
            raise RuntimeError("connection pool is closed")
        try:
            connection = self._available.get_nowait()
        except queue.Empty:
            with self._creation_lock:
                if len(self._all) < self._size:
                    connection = self._connect()
                    self._all.append(connection)
                else:
                    connection = None
            if connection is None:
                connection = self._available.get(timeout=5)
        try:
            yield connection
        finally:
            if not self._closed:
                self._available.put(connection)

    def close(self) -> None:
        self._closed = True
        for connection in self._all:
            connection.close()  # type: ignore[attr-defined]
        self._all.clear()


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

    def events(self, session_id: str, *, after_revision: int = 0) -> list[StoredEvent]:
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


class PostgresEventStore:
    """Pooled production event store using PostgreSQL as session authority."""

    def __init__(self, database_url: str, *, pool_size: int = 8) -> None:
        try:
            import psycopg
            from psycopg.types.json import Jsonb
        except ImportError as error:
            raise RuntimeError("PostgreSQL requires psycopg[binary]>=3.2") from error

        self._jsonb = Jsonb
        self._pool = ConnectionPool(
            lambda: psycopg.connect(
                database_url,
                autocommit=False,
                prepare_threshold=None,
                connect_timeout=5,
                options="-c statement_timeout=5000 -c lock_timeout=3000",
            ),
            size=pool_size,
        )

    def create_game(
        self, session_id: str, seed: int, variants: JsonObject
    ) -> GameRecord:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_games (session_id, seed, variants)
                values (%s::uuid, %s, %s)
                """,
                (session_id, seed, self._jsonb(variants)),
            )
        return GameRecord(session_id, seed, dict(variants), 0)

    def game(self, session_id: str) -> GameRecord:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                """
                select session_id::text, seed, variants, revision
                  from server_games where session_id = %s::uuid
                """,
                (session_id,),
            ).fetchone()
        if row is None:
            raise GameNotFound(session_id)
        return GameRecord(str(row[0]), int(row[1]), dict(row[2]), int(row[3]))

    def events(self, session_id: str, *, after_revision: int = 0) -> list[StoredEvent]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select session_id::text, revision, kind, payload,
                       extract(epoch from created_at)
                  from server_game_events
                 where session_id = %s::uuid and revision > %s
                 order by revision
                """,
                (session_id, after_revision),
            ).fetchall()
        return [
            StoredEvent(
                str(row[0]), int(row[1]), str(row[2]), dict(row[3]), float(row[4])
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
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_games
                   set revision = revision + 1, updated_at = now()
                 where session_id = %s::uuid and revision = %s
                returning revision, extract(epoch from updated_at)
                """,
                (session_id, expected_revision),
            ).fetchone()
            if row is None:
                current = connection.execute(  # type: ignore[attr-defined]
                    "select revision from server_games where session_id = %s::uuid",
                    (session_id,),
                ).fetchone()
                if current is None:
                    raise GameNotFound(session_id)
                raise RevisionConflict(expected_revision, int(current[0]))
            revision, created_at = int(row[0]), float(row[1])
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_game_events
                    (session_id, revision, kind, payload, created_at)
                values (%s::uuid, %s, %s, %s, to_timestamp(%s))
                """,
                (session_id, revision, kind, self._jsonb(payload), created_at),
            )
        return StoredEvent(session_id, revision, kind, dict(payload), created_at)

    def close(self) -> None:
        self._pool.close()
