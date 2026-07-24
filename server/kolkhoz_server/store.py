from __future__ import annotations

import json
import queue
import sqlite3
import threading
import time
from contextlib import closing
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING, Callable, Iterator, Protocol

from .model import (
    ENGINE_REPLAY_CONTRACT_VERSION,
    GameRecord,
    JsonObject,
    StoredEvent,
)

if TYPE_CHECKING:
    from .metrics import ServerMetrics


class RevisionConflict(RuntimeError):
    def __init__(self, expected: int, actual: int) -> None:
        super().__init__(f"stale revision: expected {expected}, current {actual}")
        self.expected = expected
        self.actual = actual


class GameNotFound(KeyError):
    pass


class LeaseLost(RuntimeError):
    pass


class EventStore(Protocol):
    def create_game(
        self,
        session_id: str,
        seed: int,
        variants: JsonObject,
        *,
        engine_build_sha: str = "unknown",
        engine_sha256: str = "unknown",
        engine_contract_version: int = ENGINE_REPLAY_CONTRACT_VERSION,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> GameRecord: ...

    def command_receipt(self, command_id: str) -> JsonObject | None: ...

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
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
    ) -> StoredEvent: ...

    def delete_game(
        self,
        session_id: str,
        *,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> None: ...

    def set_controller_override(
        self,
        session_id: str,
        player_id: int,
        controller: str,
        *,
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
    ) -> None: ...

    def close(self) -> None: ...


class ConnectionPool:
    """Small bounded DB-API pool with no global query lock."""

    def __init__(
        self,
        connect: Callable[[], object],
        *,
        size: int = 8,
        metrics: ServerMetrics | None = None,
    ) -> None:
        if size < 1:
            raise ValueError("pool size must be positive")
        self._connect = connect
        self._available: queue.LifoQueue[object] = queue.LifoQueue(maxsize=size)
        self._all: list[object] = []
        self._creation_lock = threading.Lock()
        self._size = size
        self._closed = False
        self._metrics = metrics

    @contextmanager
    def connection(self) -> Iterator[object]:
        started = time.perf_counter()
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
            if self._metrics is not None:
                self._metrics.observe(
                    "store.pool_checkout", time.perf_counter() - started
                )
            operation_started = time.perf_counter()
            yield connection
        except Exception:
            if self._metrics is not None:
                self._metrics.increment("store.errors")
            raise
        finally:
            if self._metrics is not None and "operation_started" in locals():
                self._metrics.observe(
                    "store.call", time.perf_counter() - operation_started
                )
            if not self._closed:
                # psycopg starts a transaction even for SELECT. Read repositories
                # intentionally do not commit, so return every pooled connection to
                # an idle boundary before another request checks it out. Without
                # this, a later transaction becomes a savepoint and its writes are
                # visible only on that one connection until shutdown rolls them back.
                rollback = getattr(connection, "rollback", None)
                try:
                    if rollback is not None:
                        rollback()
                except Exception:
                    # A broken connection must not poison the bounded pool. The
                    # next checkout can create its replacement.
                    try:
                        connection.close()  # type: ignore[attr-defined]
                    finally:
                        with self._creation_lock:
                            self._all.remove(connection)
                    if self._metrics is not None:
                        self._metrics.increment("store.connection_discarded")
                else:
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
    engine_build_sha text not null default 'unknown',
    engine_sha256 text not null default 'unknown',
    engine_contract_version integer not null default 1,
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

create table if not exists game_command_receipts (
    command_id text primary key,
    session_id text not null,
    fencing_token integer not null,
    result_json text not null,
    completed_at real not null
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
            columns = {
                str(row["name"])
                for row in connection.execute("pragma table_info(games)").fetchall()
            }
            for name, definition in (
                ("engine_build_sha", "text not null default 'unknown'"),
                ("engine_sha256", "text not null default 'unknown'"),
                ("engine_contract_version", "integer not null default 1"),
            ):
                if name not in columns:
                    connection.execute(f"alter table games add column {name} {definition}")
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
        self,
        session_id: str,
        seed: int,
        variants: JsonObject,
        *,
        engine_build_sha: str = "unknown",
        engine_sha256: str = "unknown",
        engine_contract_version: int = ENGINE_REPLAY_CONTRACT_VERSION,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> GameRecord:
        now = time.time()
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """insert into games (
                       session_id, seed, variants_json, revision,
                       engine_build_sha, engine_sha256, engine_contract_version,
                       created_at, updated_at
                   ) values (?, ?, ?, 0, ?, ?, ?, ?, ?)""",
                (
                    session_id,
                    seed,
                    json.dumps(variants, sort_keys=True),
                    engine_build_sha,
                    engine_sha256,
                    engine_contract_version,
                    now,
                    now,
                ),
            )
            self._insert_sqlite_receipt(
                connection, command_id, session_id, fencing_token, command_result, now
            )
        return GameRecord(
            session_id,
            seed,
            dict(variants),
            0,
            engine_build_sha,
            engine_sha256,
            engine_contract_version,
        )

    def command_receipt(self, command_id: str) -> JsonObject | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "select result_json from game_command_receipts where command_id = ?",
                (command_id,),
            ).fetchone()
        return json.loads(str(row["result_json"])) if row is not None else None

    def game(self, session_id: str) -> GameRecord:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """select session_id, seed, variants_json, revision,
                          engine_build_sha, engine_sha256, engine_contract_version
                     from games where session_id = ?""",
                (session_id,),
            ).fetchone()
        if row is None:
            raise GameNotFound(session_id)
        return GameRecord(
            str(row["session_id"]),
            int(row["seed"]),
            json.loads(str(row["variants_json"])),
            int(row["revision"]),
            str(row["engine_build_sha"]),
            str(row["engine_sha256"]),
            int(row["engine_contract_version"]),
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
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
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
            self._insert_sqlite_receipt(
                connection,
                command_id,
                session_id,
                fencing_token,
                command_result,
                now,
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

    def delete_game(
        self,
        session_id: str,
        *,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute("delete from games where session_id = ?", (session_id,))
            self._insert_sqlite_receipt(
                connection,
                command_id,
                session_id,
                fencing_token,
                command_result,
                time.time(),
            )

    def set_controller_override(
        self,
        session_id: str,
        player_id: int,
        controller: str,
        *,
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
    ) -> None:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            row = connection.execute(
                "select variants_json from games where session_id = ?",
                (session_id,),
            ).fetchone()
            if row is None:
                raise GameNotFound(session_id)
            variants = json.loads(str(row["variants_json"]))
            controllers = list(variants.get("controllers") or ("human",) * 4)
            if not 0 <= player_id < len(controllers):
                raise ValueError("invalid player ID")
            controllers[player_id] = controller
            variants["controllers"] = controllers
            connection.execute(
                "update games set variants_json = ?, updated_at = ? where session_id = ?",
                (json.dumps(variants, sort_keys=True), time.time(), session_id),
            )
            self._insert_sqlite_receipt(
                connection,
                command_id,
                session_id,
                fencing_token,
                command_result,
                time.time(),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    @staticmethod
    def _insert_sqlite_receipt(
        connection: sqlite3.Connection,
        command_id: str | None,
        session_id: str,
        fencing_token: int | None,
        command_result: JsonObject | None,
        completed_at: float,
    ) -> None:
        if command_id is None:
            return
        if fencing_token is None or command_result is None:
            raise ValueError("command receipt requires fencing token and result")
        connection.execute(
            "insert into game_command_receipts values (?, ?, ?, ?, ?)",
            (
                command_id,
                session_id,
                fencing_token,
                json.dumps(command_result, sort_keys=True),
                completed_at,
            ),
        )


class PostgresEventStore:
    """Pooled production event store using PostgreSQL as session authority."""

    def __init__(
        self,
        database_url: str | None = None,
        *,
        pool_size: int = 8,
        pool: ConnectionPool | None = None,
    ) -> None:
        if pool is not None:
            self._pool = pool
            self._owns_pool = False
            try:
                from psycopg.types.json import Jsonb
            except ImportError as error:
                raise RuntimeError(
                    "PostgreSQL requires psycopg[binary]>=3.2"
                ) from error
            self._jsonb = Jsonb
            return
        if not database_url:
            raise ValueError("database_url is required")
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
        self._owns_pool = True

    def create_game(
        self,
        session_id: str,
        seed: int,
        variants: JsonObject,
        *,
        engine_build_sha: str = "unknown",
        engine_sha256: str = "unknown",
        engine_contract_version: int = ENGINE_REPLAY_CONTRACT_VERSION,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> GameRecord:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_games (
                    session_id, seed, variants, engine_build_sha,
                    engine_sha256, engine_contract_version
                )
                values (%s::uuid, %s, %s, %s, %s, %s)
                """,
                (
                    session_id,
                    seed,
                    self._jsonb(variants),
                    engine_build_sha,
                    engine_sha256,
                    engine_contract_version,
                ),
            )
            self._insert_postgres_receipt(
                connection, command_id, session_id, fencing_token, command_result
            )
        return GameRecord(
            session_id,
            seed,
            dict(variants),
            0,
            engine_build_sha,
            engine_sha256,
            engine_contract_version,
        )

    def command_receipt(self, command_id: str) -> JsonObject | None:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                "select result_json from game_command_receipts where command_id = %s",
                (command_id,),
            ).fetchone()
        return dict(row[0]) if row is not None else None

    def game(self, session_id: str) -> GameRecord:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                """
                select session_id::text, seed, variants, revision,
                       engine_build_sha, engine_sha256, engine_contract_version
                  from server_games where session_id = %s::uuid
                """,
                (session_id,),
            ).fetchone()
        if row is None:
            raise GameNotFound(session_id)
        return GameRecord(
            str(row[0]),
            int(row[1]),
            dict(row[2]),
            int(row[3]),
            str(row[4]),
            str(row[5]),
            int(row[6]),
        )

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
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
    ) -> StoredEvent:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_games
                   set revision = revision + 1,
                       fencing_token = greatest(
                           fencing_token, coalesce(%s, fencing_token)
                       ),
                       updated_at = now()
                 where session_id = %s::uuid and revision = %s
                   and (%s is null or fencing_token <= %s)
                returning revision, extract(epoch from updated_at)
                """,
                (
                    fencing_token,
                    session_id,
                    expected_revision,
                    fencing_token,
                    fencing_token,
                ),
            ).fetchone()
            if row is None:
                current = connection.execute(  # type: ignore[attr-defined]
                    "select revision, fencing_token from server_games where session_id = %s::uuid",
                    (session_id,),
                ).fetchone()
                if current is None:
                    raise GameNotFound(session_id)
                if (
                    int(current[0]) == expected_revision
                    and fencing_token is not None
                    and int(current[1]) > fencing_token
                ):
                    raise LeaseLost(f"stale fencing token for session {session_id}")
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
            self._insert_postgres_receipt(
                connection, command_id, session_id, fencing_token, command_result
            )
        return StoredEvent(session_id, revision, kind, dict(payload), created_at)

    def close(self) -> None:
        if self._owns_pool:
            self._pool.close()

    def delete_game(
        self,
        session_id: str,
        *,
        command_id: str | None = None,
        fencing_token: int | None = None,
        command_result: JsonObject | None = None,
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                "delete from server_games where session_id = %s::uuid", (session_id,)
            )
            self._insert_postgres_receipt(
                connection, command_id, session_id, fencing_token, command_result
            )

    def set_controller_override(
        self,
        session_id: str,
        player_id: int,
        controller: str,
        *,
        fencing_token: int | None = None,
        command_id: str | None = None,
        command_result: JsonObject | None = None,
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_games
                   set variants = jsonb_set(
                           variants,
                           array['controllers', %s],
                           to_jsonb(%s::text),
                           false
                       ),
                       fencing_token = greatest(
                           fencing_token, coalesce(%s, fencing_token)
                       ),
                       updated_at = now()
                 where session_id = %s::uuid
                   and (%s is null or fencing_token <= %s)
                   and jsonb_typeof(variants->'controllers') = 'array'
                   and jsonb_array_length(variants->'controllers') > %s
                returning revision
                """,
                (
                    str(player_id),
                    controller,
                    fencing_token,
                    session_id,
                    fencing_token,
                    fencing_token,
                    player_id,
                ),
            ).fetchone()
            if row is None:
                current = connection.execute(  # type: ignore[attr-defined]
                    "select fencing_token from server_games where session_id = %s::uuid",
                    (session_id,),
                ).fetchone()
                if current is None:
                    raise GameNotFound(session_id)
                if fencing_token is not None and int(current[0]) > fencing_token:
                    raise LeaseLost(f"stale fencing token for session {session_id}")
                raise ValueError("invalid player ID or missing controllers")
            self._insert_postgres_receipt(
                connection, command_id, session_id, fencing_token, command_result
            )

    def _insert_postgres_receipt(
        self,
        connection: object,
        command_id: str | None,
        session_id: str,
        fencing_token: int | None,
        command_result: JsonObject | None,
    ) -> None:
        if command_id is None:
            return
        if fencing_token is None or command_result is None:
            raise ValueError("command receipt requires fencing token and result")
        connection.execute(  # type: ignore[attr-defined]
            """
            insert into game_command_receipts
                (command_id, session_id, fencing_token, result_json)
            values (%s, %s, %s, %s)
            """,
            (command_id, session_id, fencing_token, self._jsonb(command_result)),
        )
