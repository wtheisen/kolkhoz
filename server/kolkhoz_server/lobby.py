from __future__ import annotations

import json
import secrets
import sqlite3
import time
import uuid
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from .model import JsonObject


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    invite_code: str
    seed: int
    variants: JsonObject
    controllers: list[str]
    ranked: bool
    browser_joinable: bool
    status: str
    created_by_user_id: str | None
    created_at: float
    updated_at: float
    expires_at: float
    lobby_countdown_ends_at: float | None


@dataclass(frozen=True)
class SeatRecord:
    player_id: int
    controller: str
    occupied: bool
    user_id: str | None
    token_hash: str | None
    last_seen_at: float | None
    timeouts: int
    abandoned: bool
    autopilot: bool


class SeatUnavailable(RuntimeError):
    pass


class LobbyRepository(Protocol):
    def create(self, record: SessionRecord, seats: list[SeatRecord]) -> None: ...
    def session(self, session_id_or_invite: str) -> SessionRecord: ...
    def seats(self, session_id: str) -> list[SeatRecord]: ...
    def list_open(self, now: float) -> list[SessionRecord]: ...
    def occupy_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        user_id: str,
        token_hash: str,
        now: float,
    ) -> None: ...


LOBBY_SCHEMA = """
create table if not exists server_sessions (
    session_id text primary key,
    invite_code text not null unique collate nocase,
    seed integer not null,
    variants_json text not null,
    controllers_json text not null,
    ranked integer not null,
    browser_joinable integer not null,
    status text not null,
    created_by_user_id text,
    created_at real not null,
    updated_at real not null,
    expires_at real not null,
    lobby_countdown_ends_at real
);
create index if not exists server_sessions_browser_idx
    on server_sessions (status, browser_joinable, expires_at, updated_at desc);

create table if not exists server_seats (
    session_id text not null references server_sessions(session_id) on delete cascade,
    player_id integer not null,
    controller text not null,
    occupied integer not null default 0,
    user_id text,
    token_hash text,
    last_seen_at real,
    timeouts integer not null default 0,
    abandoned integer not null default 0,
    autopilot integer not null default 0,
    primary key (session_id, player_id)
);
create unique index if not exists server_active_user_seat_idx
    on server_seats (user_id) where occupied = 1 and user_id is not null;

create table if not exists server_session_invites (
    session_id text not null references server_sessions(session_id) on delete cascade,
    user_id text not null,
    declined integer not null default 0,
    created_at real not null,
    primary key (session_id, user_id)
);

create table if not exists server_presence (
    user_id text primary key,
    last_seen_at real not null
);

create table if not exists server_device_leases (
    user_id text not null,
    device_id text not null,
    session_id text not null,
    last_seen_at real not null,
    primary key (user_id, device_id)
);
"""


class SQLiteLobbyRepository:
    def __init__(self, path: str | Path) -> None:
        self.path = str(path)
        with closing(self._connect()) as connection:
            connection.executescript(LOBBY_SCHEMA)

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.path, timeout=5, isolation_level=None, check_same_thread=False
        )
        connection.row_factory = sqlite3.Row
        connection.execute("pragma foreign_keys = on")
        connection.execute("pragma journal_mode = wal")
        return connection

    def create(self, record: SessionRecord, seats: list[SeatRecord]) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                insert into server_sessions values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.session_id,
                    record.invite_code,
                    record.seed,
                    json.dumps(record.variants, sort_keys=True),
                    json.dumps(record.controllers),
                    record.ranked,
                    record.browser_joinable,
                    record.status,
                    record.created_by_user_id,
                    record.created_at,
                    record.updated_at,
                    record.expires_at,
                    record.lobby_countdown_ends_at,
                ),
            )
            connection.executemany(
                "insert into server_seats values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    (
                        record.session_id,
                        seat.player_id,
                        seat.controller,
                        seat.occupied,
                        seat.user_id,
                        seat.token_hash,
                        seat.last_seen_at,
                        seat.timeouts,
                        seat.abandoned,
                        seat.autopilot,
                    )
                    for seat in seats
                ],
            )

    def session(self, session_id_or_invite: str) -> SessionRecord:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                select * from server_sessions
                 where session_id = ? or invite_code = ? collate nocase
                """,
                (session_id_or_invite, session_id_or_invite),
            ).fetchone()
        if row is None:
            raise KeyError(session_id_or_invite)
        return self._session(row)

    def seats(self, session_id: str) -> list[SeatRecord]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "select * from server_seats where session_id = ? order by player_id",
                (session_id,),
            ).fetchall()
        return [self._seat(row) for row in rows]

    def list_open(self, now: float) -> list[SessionRecord]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                select sessions.*
                  from server_sessions sessions
                 where sessions.status = 'open'
                   and sessions.browser_joinable = 1
                   and sessions.expires_at > ?
                   and exists (
                       select 1 from server_seats seats
                        where seats.session_id = sessions.session_id
                          and seats.controller = 'human' and seats.occupied = 0
                   )
                 order by sessions.updated_at desc
                """,
                (now,),
            ).fetchall()
        return [self._session(row) for row in rows]

    def occupy_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        user_id: str,
        token_hash: str,
        now: float,
    ) -> None:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            updated = connection.execute(
                """
                update server_seats
                   set occupied = 1, user_id = ?, token_hash = ?, last_seen_at = ?,
                       abandoned = 0, autopilot = 0
                 where session_id = ? and player_id = ?
                   and controller = 'human' and occupied = 0
                """,
                (user_id, token_hash, now, session_id, player_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            connection.execute(
                "update server_sessions set updated_at = ? where session_id = ?",
                (now, session_id),
            )
            connection.commit()
        except sqlite3.IntegrityError as error:
            connection.rollback()
            raise SeatUnavailable("user already has an active seat") from error
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def release_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            updated = connection.execute(
                """
                update server_seats
                   set occupied = 0, user_id = null, token_hash = null,
                       last_seen_at = null, autopilot = 0, abandoned = 0
                 where session_id = ? and player_id = ? and occupied = 1
                """,
                (session_id, player_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            connection.execute(
                "update server_sessions set updated_at = ? where session_id = ?",
                (now, session_id),
            )

    def set_status(
        self,
        session_id: str,
        status: str,
        *,
        now: float,
        countdown_ends_at: float | None = None,
    ) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                update server_sessions
                   set status = ?, updated_at = ?, lobby_countdown_ends_at = ?
                 where session_id = ?
                """,
                (status, now, countdown_ends_at, session_id),
            )

    def invite(self, session_id: str, user_ids: set[str], *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            connection.executemany(
                """
                insert into server_session_invites values (?, ?, 0, ?)
                on conflict(session_id, user_id) do update set declined = 0, created_at = excluded.created_at
                """,
                [(session_id, user_id, now) for user_id in user_ids],
            )

    def invites_for_user(self, user_id: str) -> list[SessionRecord]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                select sessions.* from server_sessions sessions
                join server_session_invites invites using (session_id)
                where invites.user_id = ? and invites.declined = 0
                  and sessions.status = 'open' and sessions.expires_at > ?
                order by invites.created_at desc
                """,
                (user_id, time.time()),
            ).fetchall()
        return [self._session(row) for row in rows]

    def decline_invite(self, session_id: str, user_id: str) -> None:
        with closing(self._connect()) as connection, connection:
            updated = connection.execute(
                """
                update server_session_invites set declined = 1
                 where session_id = ? and user_id = ? and declined = 0
                """,
                (session_id, user_id),
            )
            if updated.rowcount != 1:
                raise KeyError("session invite not found")

    def mark_presence(self, user_id: str, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                insert into server_presence values (?, ?)
                on conflict(user_id) do update set last_seen_at = excluded.last_seen_at
                """,
                (user_id, now),
            )

    def online_user_ids(self, *, since: float) -> set[str]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "select user_id from server_presence where last_seen_at >= ?", (since,)
            ).fetchall()
        return {str(row[0]) for row in rows}

    @staticmethod
    def new_session(
        *,
        seed: int,
        variants: JsonObject,
        controllers: list[str],
        ranked: bool,
        browser_joinable: bool,
        created_by_user_id: str | None,
        ttl_seconds: float,
    ) -> SessionRecord:
        now = time.time()
        return SessionRecord(
            str(uuid.uuid4()),
            "".join(
                secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6)
            ),
            seed,
            dict(variants),
            list(controllers),
            ranked,
            browser_joinable,
            "open",
            created_by_user_id,
            now,
            now,
            now + ttl_seconds,
            None,
        )

    @staticmethod
    def _session(row: sqlite3.Row) -> SessionRecord:
        return SessionRecord(
            str(row["session_id"]),
            str(row["invite_code"]),
            int(row["seed"]),
            json.loads(str(row["variants_json"])),
            json.loads(str(row["controllers_json"])),
            bool(row["ranked"]),
            bool(row["browser_joinable"]),
            str(row["status"]),
            str(row["created_by_user_id"]) if row["created_by_user_id"] else None,
            float(row["created_at"]),
            float(row["updated_at"]),
            float(row["expires_at"]),
            float(row["lobby_countdown_ends_at"])
            if row["lobby_countdown_ends_at"] is not None
            else None,
        )

    @staticmethod
    def _seat(row: sqlite3.Row) -> SeatRecord:
        return SeatRecord(
            int(row["player_id"]),
            str(row["controller"]),
            bool(row["occupied"]),
            str(row["user_id"]) if row["user_id"] else None,
            str(row["token_hash"]) if row["token_hash"] else None,
            float(row["last_seen_at"]) if row["last_seen_at"] is not None else None,
            int(row["timeouts"]),
            bool(row["abandoned"]),
            bool(row["autopilot"]),
        )
