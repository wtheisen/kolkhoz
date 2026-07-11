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
from .store import ConnectionPool


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


@dataclass(frozen=True)
class DueTurn:
    session_id: str
    player_id: int
    deadline_at: float
    claim_owner: str
    fencing_token: int


@dataclass(frozen=True)
class TimeoutResult:
    timeouts: int
    forced_autopilot: bool


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
    def release_seat(self, session_id: str, player_id: int, *, now: float) -> None: ...
    def release_seat_and_delete_if_empty(
        self, session_id: str, player_id: int, *, now: float
    ) -> bool: ...
    def kick_seat(
        self,
        session_id: str,
        target_player_id: int,
        *,
        host_user_id: str,
        now: float,
    ) -> None: ...
    def set_status(
        self,
        session_id: str,
        status: str,
        *,
        now: float,
        countdown_ends_at: float | None = None,
    ) -> None: ...
    def delete_session(self, session_id: str) -> None: ...
    def append_reaction(
        self,
        session_id: str,
        *,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> dict[str, object]: ...
    def reactions(self, session_id: str) -> list[dict[str, object]]: ...
    def invite(self, session_id: str, user_ids: set[str], *, now: float) -> None: ...
    def invites_for_user(self, user_id: str) -> list[SessionRecord]: ...
    def decline_invite(self, session_id: str, user_id: str) -> None: ...
    def mark_presence(self, user_id: str, *, now: float) -> None: ...
    def acquire_device_lease(
        self,
        user_id: str,
        device_id: str,
        session_id: str,
        *,
        now: float,
        ttl_seconds: float,
    ) -> bool: ...
    def online_user_ids(self, *, since: float) -> set[str]: ...
    def metrics_state(self, *, now: float, presence_since: float) -> JsonObject: ...
    def set_turn_deadline(
        self,
        session_id: str,
        player_id: int | None,
        *,
        deadline_at: float | None,
        now: float,
    ) -> None: ...
    def turn_state(self, session_id: str) -> tuple[int | None, float | None]: ...
    def claim_due_turns(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[DueTurn]: ...
    def consume_timeout(self, claim: DueTurn, *, now: float) -> TimeoutResult: ...
    def touch_seat(self, session_id: str, player_id: int, *, now: float) -> None: ...


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
    lobby_countdown_ends_at real,
    turn_player_id integer,
    turn_deadline_at real,
    scheduler_claim_owner text,
    scheduler_claim_until real,
    scheduler_fencing_token integer not null default 0
);
create index if not exists server_sessions_browser_idx
    on server_sessions (status, browser_joinable, expires_at, updated_at desc);
create index if not exists server_sessions_due_turn_idx
    on server_sessions (turn_deadline_at, session_id)
    where status = 'active' and turn_deadline_at is not null;

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

create table if not exists server_reactions (
    session_id text not null references server_sessions(session_id) on delete cascade,
    revision integer not null,
    player_id integer not null,
    reaction_id text not null,
    year integer not null,
    phase integer not null,
    created_at real not null,
    primary key (session_id, revision)
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
                insert into server_sessions (
                    session_id, invite_code, seed, variants_json, controllers_json,
                    ranked, browser_joinable, status, created_by_user_id, created_at,
                    updated_at, expires_at, lobby_countdown_ends_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

    def set_ranked(self, session_id: str, ranked: bool, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                "update server_sessions set ranked = ?, updated_at = ? where session_id = ?",
                (ranked, now, session_id),
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
        connection = self._connect()
        try:
            connection.execute("begin immediate")
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
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def release_seat_and_delete_if_empty(
        self, session_id: str, player_id: int, *, now: float
    ) -> bool:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
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
            remaining = connection.execute(
                "select 1 from server_seats where session_id = ? and occupied = 1 limit 1",
                (session_id,),
            ).fetchone()
            if remaining is None:
                connection.execute(
                    "delete from server_sessions where session_id = ? and status = 'open'",
                    (session_id,),
                )
                deleted = connection.total_changes > 1
            else:
                connection.execute(
                    "update server_sessions set updated_at = ? where session_id = ?",
                    (now, session_id),
                )
                deleted = False
            connection.commit()
            return deleted
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def kick_seat(
        self,
        session_id: str,
        target_player_id: int,
        *,
        host_user_id: str,
        now: float,
    ) -> None:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            updated = connection.execute(
                """
                update server_seats
                   set occupied = 0, user_id = null, token_hash = null,
                       last_seen_at = null, autopilot = 0, abandoned = 0
                 where session_id = ? and player_id = ? and occupied = 1
                   and exists (
                       select 1 from server_sessions
                        where session_id = ? and status = 'open'
                          and created_by_user_id = ?
                   )
                """,
                (session_id, target_player_id, session_id, host_user_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {target_player_id} is unavailable")
            connection.execute(
                "update server_sessions set updated_at = ? where session_id = ?",
                (now, session_id),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def abandon_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            updated = connection.execute(
                """
                update server_seats
                   set abandoned = 1, autopilot = 1,
                       timeouts = max(timeouts, 2), last_seen_at = ?
                 where session_id = ? and player_id = ? and occupied = 1
                """,
                (now, session_id, player_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

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

    def delete_session(self, session_id: str) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                "delete from server_sessions where session_id = ?", (session_id,)
            )

    def append_reaction(
        self,
        session_id: str,
        *,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> dict[str, object]:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            revision = int(
                connection.execute(
                    "select coalesce(max(revision), 0) + 1 from server_reactions where session_id = ?",
                    (session_id,),
                ).fetchone()[0]
            )
            connection.execute(
                "insert into server_reactions values (?, ?, ?, ?, ?, ?, ?)",
                (session_id, revision, player_id, reaction_id, year, phase, now),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
        return {
            "revision": revision,
            "playerID": player_id,
            "reactionID": reaction_id,
            "year": year,
            "phase": phase,
            "createdAt": now,
        }

    def reactions(self, session_id: str) -> list[dict[str, object]]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "select * from server_reactions where session_id = ? order by revision",
                (session_id,),
            ).fetchall()
        return [
            {
                "revision": int(row["revision"]),
                "playerID": int(row["player_id"]),
                "reactionID": str(row["reaction_id"]),
                "year": int(row["year"]),
                "phase": int(row["phase"]),
                "createdAt": float(row["created_at"]),
            }
            for row in rows
        ]

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

    def invite_access(self, session_id: str, user_id: str) -> tuple[bool, bool]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "select user_id, declined from server_session_invites where session_id = ?",
                (session_id,),
            ).fetchall()
        return bool(rows), any(
            str(row["user_id"]) == user_id and not bool(row["declined"]) for row in rows
        )

    def consume_invite(self, session_id: str, user_id: str) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                "delete from server_session_invites where session_id = ? and user_id = ?",
                (session_id, user_id),
            )

    def mark_presence(self, user_id: str, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                insert into server_presence values (?, ?)
                on conflict(user_id) do update set last_seen_at = excluded.last_seen_at
                """,
                (user_id, now),
            )

    def acquire_device_lease(
        self,
        user_id: str,
        device_id: str,
        session_id: str,
        *,
        now: float,
        ttl_seconds: float,
    ) -> bool:
        cutoff = now - max(0.0, ttl_seconds)
        with closing(self._connect()) as connection:
            connection.execute("begin immediate")
            conflict = connection.execute(
                """
                select 1 from server_device_leases
                 where user_id = ? and session_id = ? and device_id <> ?
                   and last_seen_at >= ?
                 limit 1
                """,
                (user_id, session_id, device_id, cutoff),
            ).fetchone()
            if conflict is not None:
                connection.rollback()
                return False
            connection.execute(
                """
                insert into server_device_leases values (?, ?, ?, ?)
                on conflict(user_id, device_id) do update set
                    session_id = excluded.session_id,
                    last_seen_at = excluded.last_seen_at
                """,
                (user_id, device_id, session_id, now),
            )
            connection.execute(
                """
                delete from server_device_leases
                 where user_id = ? and session_id = ? and device_id <> ?
                   and last_seen_at < ?
                """,
                (user_id, session_id, device_id, cutoff),
            )
            connection.commit()
            return True

    def online_user_ids(self, *, since: float) -> set[str]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                "select user_id from server_presence where last_seen_at >= ?", (since,)
            ).fetchall()
        return {str(row[0]) for row in rows}

    def metrics_state(self, *, now: float, presence_since: float) -> JsonObject:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                select
                    (select count(*) from server_sessions
                      where status in ('open', 'active') and expires_at > ?),
                    (select count(*) from server_seats where occupied = 1),
                    (select count(*) from server_seats
                      where occupied = 1 and abandoned = 0 and last_seen_at >= ?),
                    (select count(*) from server_presence where last_seen_at >= ?)
                """,
                (now, presence_since, presence_since),
            ).fetchone()
        return {
            "activeSessions": int(row[0]),
            "activeSeats": int(row[1]),
            "connectedSeatedHumanSeats": int(row[2]),
            "citizensOnline": int(row[3]),
        }

    def active_for_user(self, user_id: str) -> tuple[SessionRecord, SeatRecord] | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                select seats.session_id, seats.player_id
                  from server_seats seats join server_sessions sessions using (session_id)
                 where seats.user_id = ? and seats.occupied = 1
                   and sessions.status in ('open', 'active') and sessions.expires_at > ?
                 order by sessions.updated_at desc limit 1
                """,
                (user_id, time.time()),
            ).fetchone()
        if row is None:
            return None
        session = self.session(str(row["session_id"]))
        seat = next(
            value
            for value in self.seats(session.session_id)
            if value.player_id == int(row["player_id"])
        )
        return session, seat

    def replace_seat_token(
        self, session_id: str, player_id: int, *, token_hash: str, now: float
    ) -> None:
        with closing(self._connect()) as connection, connection:
            updated = connection.execute(
                """
                update server_seats set token_hash = ?, last_seen_at = ?
                 where session_id = ? and player_id = ? and occupied = 1
                """,
                (token_hash, now, session_id, player_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

    def touch_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with closing(self._connect()) as connection, connection:
            updated = connection.execute(
                """
                update server_seats
                   set last_seen_at = ?, autopilot = case when abandoned then autopilot else 0 end
                 where session_id = ? and player_id = ? and occupied = 1
                """,
                (now, session_id, player_id),
            )
            if updated.rowcount != 1:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

    def set_turn_deadline(
        self,
        session_id: str,
        player_id: int | None,
        *,
        deadline_at: float | None,
        now: float,
    ) -> None:
        if (player_id is None) != (deadline_at is None):
            raise ValueError(
                "player_id and deadline_at must both be set or both be null"
            )
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                update server_sessions
                   set turn_player_id = ?, turn_deadline_at = ?, updated_at = ?,
                       scheduler_claim_owner = null, scheduler_claim_until = null
                 where session_id = ?
                """,
                (player_id, deadline_at, now, session_id),
            )

    def turn_state(self, session_id: str) -> tuple[int | None, float | None]:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "select turn_player_id, turn_deadline_at from server_sessions where session_id = ?",
                (session_id,),
            ).fetchone()
        if row is None:
            raise KeyError(session_id)
        return (
            int(row["turn_player_id"]) if row["turn_player_id"] is not None else None,
            float(row["turn_deadline_at"])
            if row["turn_deadline_at"] is not None
            else None,
        )

    def claim_due_turns(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[DueTurn]:
        if not owner or lease_seconds <= 0 or limit <= 0:
            raise ValueError("owner, lease_seconds, and limit must be positive")
        connection = self._connect()
        claimed: list[DueTurn] = []
        try:
            connection.execute("begin immediate")
            rows = connection.execute(
                """
                select session_id, turn_player_id, turn_deadline_at
                  from server_sessions
                 where status = 'active' and turn_deadline_at <= ?
                   and (scheduler_claim_until is null or scheduler_claim_until <= ?)
                 order by turn_deadline_at, session_id limit ?
                """,
                (now, now, limit),
            ).fetchall()
            for row in rows:
                token_row = connection.execute(
                    """
                    update server_sessions
                       set scheduler_claim_owner = ?, scheduler_claim_until = ?,
                           scheduler_fencing_token = scheduler_fencing_token + 1
                     where session_id = ?
                    returning scheduler_fencing_token
                    """,
                    (owner, now + lease_seconds, row["session_id"]),
                ).fetchone()
                claimed.append(
                    DueTurn(
                        str(row["session_id"]),
                        int(row["turn_player_id"]),
                        float(row["turn_deadline_at"]),
                        owner,
                        int(token_row[0]),
                    )
                )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
        return claimed

    def consume_timeout(self, claim: DueTurn, *, now: float) -> TimeoutResult:
        connection = self._connect()
        try:
            connection.execute("begin immediate")
            valid = connection.execute(
                """
                update server_sessions
                   set turn_player_id = null, turn_deadline_at = null,
                       scheduler_claim_owner = null, scheduler_claim_until = null,
                       updated_at = ?
                 where session_id = ? and turn_player_id = ? and turn_deadline_at <= ?
                   and scheduler_claim_owner = ? and scheduler_fencing_token = ?
                returning session_id
                """,
                (
                    now,
                    claim.session_id,
                    claim.player_id,
                    now,
                    claim.claim_owner,
                    claim.fencing_token,
                ),
            ).fetchone()
            if valid is None:
                raise SeatUnavailable("stale timeout claim")
            seat = connection.execute(
                """
                update server_seats
                   set timeouts = timeouts + 1,
                       autopilot = case when timeouts + 1 >= 2 then 1 else autopilot end,
                       abandoned = case when timeouts + 1 >= 2 then 1 else abandoned end
                 where session_id = ? and player_id = ? and occupied = 1
                returning timeouts, autopilot
                """,
                (claim.session_id, claim.player_id),
            ).fetchone()
            if seat is None:
                raise SeatUnavailable("timeout seat unavailable")
            connection.commit()
            return TimeoutResult(int(seat[0]), bool(seat[1]))
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

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
                secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(5)
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


class PostgresLobbyRepository:
    """Pooled PostgreSQL lobby metadata adapter.

    PostgreSQL arbitrates seat ownership and reaction revisions. The adapter has no
    process-wide lock, so unrelated sessions can progress on separate pool
    connections while conflicting claims for one seat remain atomic.
    """

    def __init__(self, pool: ConnectionPool) -> None:
        try:
            from psycopg.types.json import Jsonb
        except ImportError as error:
            raise RuntimeError("PostgreSQL requires psycopg[binary]>=3.2") from error
        self._pool = pool
        self._jsonb = Jsonb

    def create(self, record: SessionRecord, seats: list[SeatRecord]) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_sessions (
                    session_id, invite_code, seed, variants, controllers, ranked,
                    browser_joinable, status, created_by_user_id, created_at,
                    updated_at, expires_at, lobby_countdown_ends_at
                ) values (
                    %s::uuid, upper(%s), %s, %s, %s, %s, %s, %s, %s,
                    to_timestamp(%s), to_timestamp(%s), to_timestamp(%s),
                    case when %s is null then null else to_timestamp(%s) end
                )
                """,
                (
                    record.session_id,
                    record.invite_code,
                    record.seed,
                    self._jsonb(record.variants),
                    self._jsonb(record.controllers),
                    record.ranked,
                    record.browser_joinable,
                    record.status,
                    record.created_by_user_id,
                    record.created_at,
                    record.updated_at,
                    record.expires_at,
                    record.lobby_countdown_ends_at,
                    record.lobby_countdown_ends_at,
                ),
            )
            for seat in seats:
                connection.execute(  # type: ignore[attr-defined]
                    """
                    insert into server_seats (
                        session_id, player_id, controller, occupied, user_id,
                        token_hash, last_seen_at, timeouts, abandoned, autopilot
                    ) values (
                        %s::uuid, %s, %s, %s, %s, %s,
                        case when %s is null then null else to_timestamp(%s) end,
                        %s, %s, %s
                    )
                    """,
                    (
                        record.session_id,
                        seat.player_id,
                        seat.controller,
                        seat.occupied,
                        seat.user_id,
                        seat.token_hash,
                        seat.last_seen_at,
                        seat.last_seen_at,
                        seat.timeouts,
                        seat.abandoned,
                        seat.autopilot,
                    ),
                )

    def session(self, session_id_or_invite: str) -> SessionRecord:
        try:
            normalized_session_id = str(uuid.UUID(session_id_or_invite))
        except ValueError:
            normalized_session_id = None
        predicate = (
            "session_id = %s::uuid"
            if normalized_session_id is not None
            else "invite_code = upper(%s)"
        )
        lookup = normalized_session_id or session_id_or_invite
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                f"""
                select session_id::text, invite_code, seed, variants, controllers,
                       ranked, browser_joinable, status, created_by_user_id,
                       extract(epoch from created_at), extract(epoch from updated_at),
                       extract(epoch from expires_at),
                       extract(epoch from lobby_countdown_ends_at)
                  from server_sessions
                 where {predicate}
                 limit 1
                """,
                (lookup,),
            ).fetchone()
        if row is None:
            raise KeyError(session_id_or_invite)
        return self._session_row(row)

    def seats(self, session_id: str) -> list[SeatRecord]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select player_id, controller, occupied, user_id, token_hash,
                       extract(epoch from last_seen_at), timeouts, abandoned, autopilot
                  from server_seats where session_id = %s::uuid order by player_id
                """,
                (session_id,),
            ).fetchall()
        return [self._seat_row(row) for row in rows]

    def list_open(self, now: float) -> list[SessionRecord]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select sessions.session_id::text, sessions.invite_code, sessions.seed,
                       sessions.variants, sessions.controllers, sessions.ranked,
                       sessions.browser_joinable, sessions.status,
                       sessions.created_by_user_id,
                       extract(epoch from sessions.created_at),
                       extract(epoch from sessions.updated_at),
                       extract(epoch from sessions.expires_at),
                       extract(epoch from sessions.lobby_countdown_ends_at)
                  from server_sessions sessions
                 where sessions.status = 'open' and sessions.browser_joinable
                   and sessions.expires_at > to_timestamp(%s)
                   and exists (
                       select 1 from server_seats seats
                        where seats.session_id = sessions.session_id
                          and seats.controller = 'human' and not seats.occupied
                   )
                 order by sessions.updated_at desc
                """,
                (now,),
            ).fetchall()
        return [self._session_row(row) for row in rows]

    def occupy_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        user_id: str,
        token_hash: str,
        now: float,
    ) -> None:
        try:
            with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
                row = connection.execute(  # type: ignore[attr-defined]
                    """
                    update server_seats
                       set occupied = true, user_id = %s, token_hash = %s,
                           last_seen_at = to_timestamp(%s), abandoned = false,
                           autopilot = false
                     where session_id = %s::uuid and player_id = %s
                       and controller = 'human' and not occupied
                    returning player_id
                    """,
                    (user_id, token_hash, now, session_id, player_id),
                ).fetchone()
                if row is None:
                    raise SeatUnavailable(f"seat {player_id} is unavailable")
                connection.execute(  # type: ignore[attr-defined]
                    "update server_sessions set updated_at = to_timestamp(%s) where session_id = %s::uuid",
                    (now, session_id),
                )
        except SeatUnavailable:
            raise
        except Exception as error:
            if getattr(error, "sqlstate", None) == "23505":
                raise SeatUnavailable("user already has an active seat") from error
            raise

    def release_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats
                   set occupied = false, user_id = null, token_hash = null,
                       last_seen_at = null, autopilot = false, abandoned = false
                 where session_id = %s::uuid and player_id = %s and occupied
                returning player_id
                """,
                (session_id, player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            connection.execute(  # type: ignore[attr-defined]
                "update server_sessions set updated_at = to_timestamp(%s) where session_id = %s::uuid",
                (now, session_id),
            )

    def release_seat_and_delete_if_empty(
        self, session_id: str, player_id: int, *, now: float
    ) -> bool:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats
                   set occupied = false, user_id = null, token_hash = null,
                       last_seen_at = null, autopilot = false, abandoned = false
                 where session_id = %s::uuid and player_id = %s and occupied
                returning player_id
                """,
                (session_id, player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            deleted = connection.execute(  # type: ignore[attr-defined]
                """
                delete from server_sessions sessions
                 where sessions.session_id = %s::uuid and sessions.status = 'open'
                   and not exists (
                       select 1 from server_seats seats
                        where seats.session_id = sessions.session_id and seats.occupied
                   )
                returning session_id
                """,
                (session_id,),
            ).fetchone()
            if deleted is not None:
                return True
            connection.execute(  # type: ignore[attr-defined]
                "update server_sessions set updated_at = to_timestamp(%s) where session_id = %s::uuid",
                (now, session_id),
            )
            return False

    def kick_seat(
        self,
        session_id: str,
        target_player_id: int,
        *,
        host_user_id: str,
        now: float,
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats seats
                   set occupied = false, user_id = null, token_hash = null,
                       last_seen_at = null, autopilot = false, abandoned = false
                  from server_sessions sessions
                 where seats.session_id = %s::uuid and seats.player_id = %s
                   and seats.occupied and sessions.session_id = seats.session_id
                   and sessions.status = 'open'
                   and sessions.created_by_user_id = %s
                returning seats.player_id
                """,
                (session_id, target_player_id, host_user_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {target_player_id} is unavailable")
            connection.execute(  # type: ignore[attr-defined]
                "update server_sessions set updated_at = to_timestamp(%s) where session_id = %s::uuid",
                (now, session_id),
            )

    def abandon_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats
                   set abandoned = true, autopilot = true,
                       timeouts = greatest(timeouts, 2), last_seen_at = to_timestamp(%s)
                 where session_id = %s::uuid and player_id = %s and occupied
                returning player_id
                """,
                (now, session_id, player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

    def set_status(
        self,
        session_id: str,
        status: str,
        *,
        now: float,
        countdown_ends_at: float | None = None,
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                update server_sessions
                   set status = %s, updated_at = to_timestamp(%s),
                       lobby_countdown_ends_at = case when %s is null then null else to_timestamp(%s) end
                 where session_id = %s::uuid
                """,
                (status, now, countdown_ends_at, countdown_ends_at, session_id),
            )

    def set_ranked(self, session_id: str, ranked: bool, *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                update server_sessions set ranked = %s, updated_at = to_timestamp(%s)
                 where session_id = %s::uuid
                """,
                (ranked, now, session_id),
            )

    def delete_session(self, session_id: str) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                "delete from server_sessions where session_id = %s::uuid", (session_id,)
            )

    def append_reaction(
        self,
        session_id: str,
        *,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> dict[str, object]:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            revision_row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_sessions
                   set reaction_revision = reaction_revision + 1
                 where session_id = %s::uuid
                returning reaction_revision
                """,
                (session_id,),
            ).fetchone()
            if revision_row is None:
                raise KeyError(session_id)
            revision = int(revision_row[0])
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_reactions
                    (session_id, revision, player_id, reaction_id, year, phase, created_at)
                values (%s::uuid, %s, %s, %s, %s, %s, to_timestamp(%s))
                """,
                (session_id, revision, player_id, reaction_id, year, phase, now),
            )
        return {
            "revision": revision,
            "playerID": player_id,
            "reactionID": reaction_id,
            "year": year,
            "phase": phase,
            "createdAt": now,
        }

    def reactions(self, session_id: str) -> list[dict[str, object]]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select revision, player_id, reaction_id, year, phase,
                       extract(epoch from created_at)
                  from server_reactions where session_id = %s::uuid order by revision
                """,
                (session_id,),
            ).fetchall()
        return [
            {
                "revision": int(row[0]),
                "playerID": int(row[1]),
                "reactionID": str(row[2]),
                "year": int(row[3]),
                "phase": int(row[4]),
                "createdAt": float(row[5]),
            }
            for row in rows
        ]

    def invite(self, session_id: str, user_ids: set[str], *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            for user_id in user_ids:
                connection.execute(  # type: ignore[attr-defined]
                    """
                    insert into server_session_invites
                        (session_id, user_id, declined, created_at)
                    values (%s::uuid, %s, false, to_timestamp(%s))
                    on conflict (session_id, user_id) do update
                       set declined = false, created_at = excluded.created_at
                    """,
                    (session_id, user_id, now),
                )

    def invites_for_user(self, user_id: str) -> list[SessionRecord]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select sessions.session_id::text, sessions.invite_code, sessions.seed,
                       sessions.variants, sessions.controllers, sessions.ranked,
                       sessions.browser_joinable, sessions.status,
                       sessions.created_by_user_id,
                       extract(epoch from sessions.created_at),
                       extract(epoch from sessions.updated_at),
                       extract(epoch from sessions.expires_at),
                       extract(epoch from sessions.lobby_countdown_ends_at)
                  from server_session_invites invites
                  join server_sessions sessions using (session_id)
                 where invites.user_id = %s and not invites.declined
                   and sessions.status = 'open' and sessions.expires_at > now()
                 order by invites.created_at desc
                """,
                (user_id,),
            ).fetchall()
        return [self._session_row(row) for row in rows]

    def decline_invite(self, session_id: str, user_id: str) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_session_invites set declined = true
                 where session_id = %s::uuid and user_id = %s and not declined
                returning user_id
                """,
                (session_id, user_id),
            ).fetchone()
            if row is None:
                raise KeyError("session invite not found")

    def invite_access(self, session_id: str, user_id: str) -> tuple[bool, bool]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select user_id, declined from server_session_invites
                 where session_id = %s::uuid
                """,
                (session_id,),
            ).fetchall()
        return bool(rows), any(
            str(row[0]) == user_id and not bool(row[1]) for row in rows
        )

    def consume_invite(self, session_id: str, user_id: str) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                "delete from server_session_invites where session_id = %s::uuid and user_id = %s",
                (session_id, user_id),
            )

    def mark_presence(self, user_id: str, *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_presence (user_id, last_seen_at)
                values (%s, to_timestamp(%s))
                on conflict (user_id) do update set last_seen_at = excluded.last_seen_at
                """,
                (user_id, now),
            )

    def acquire_device_lease(
        self,
        user_id: str,
        device_id: str,
        session_id: str,
        *,
        now: float,
        ttl_seconds: float,
    ) -> bool:
        cutoff = now - max(0.0, ttl_seconds)
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                "select pg_advisory_xact_lock(hashtextextended(%s, 0))", (user_id,)
            )
            conflict = connection.execute(  # type: ignore[attr-defined]
                """
                select 1 from server_device_leases
                 where user_id = %s and session_id = %s::uuid and device_id <> %s
                   and last_seen_at >= to_timestamp(%s)
                 limit 1
                """,
                (user_id, session_id, device_id, cutoff),
            ).fetchone()
            if conflict is not None:
                return False
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_device_leases
                    (user_id, device_id, session_id, last_seen_at)
                values (%s, %s, %s::uuid, to_timestamp(%s))
                on conflict(user_id, device_id) do update set
                    session_id = excluded.session_id,
                    last_seen_at = excluded.last_seen_at
                """,
                (user_id, device_id, session_id, now),
            )
            connection.execute(  # type: ignore[attr-defined]
                """
                delete from server_device_leases
                 where user_id = %s and session_id = %s::uuid and device_id <> %s
                   and last_seen_at < to_timestamp(%s)
                """,
                (user_id, session_id, device_id, cutoff),
            )
            return True

    def online_user_ids(self, *, since: float) -> set[str]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                "select user_id from server_presence where last_seen_at >= to_timestamp(%s)",
                (since,),
            ).fetchall()
        return {str(row[0]) for row in rows}

    def metrics_state(self, *, now: float, presence_since: float) -> JsonObject:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                """
                select
                    (select count(*) from server_sessions
                      where status in ('open', 'active') and expires_at > to_timestamp(%s)),
                    (select count(*) from server_seats where occupied),
                    (select count(*) from server_seats
                      where occupied and not abandoned and last_seen_at >= to_timestamp(%s)),
                    (select count(*) from server_presence
                      where last_seen_at >= to_timestamp(%s))
                """,
                (now, presence_since, presence_since),
            ).fetchone()
        return {
            "activeSessions": int(row[0]),
            "activeSeats": int(row[1]),
            "connectedSeatedHumanSeats": int(row[2]),
            "citizensOnline": int(row[3]),
        }

    def active_for_user(self, user_id: str) -> tuple[SessionRecord, SeatRecord] | None:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                """
                select seats.session_id::text, seats.player_id
                  from server_seats seats join server_sessions sessions using (session_id)
                 where seats.user_id = %s and seats.occupied
                   and sessions.status in ('open', 'active') and sessions.expires_at > now()
                 order by sessions.updated_at desc limit 1
                """,
                (user_id,),
            ).fetchone()
        if row is None:
            return None
        session = self.session(str(row[0]))
        seat = next(
            value
            for value in self.seats(session.session_id)
            if value.player_id == int(row[1])
        )
        return session, seat

    def replace_seat_token(
        self, session_id: str, player_id: int, *, token_hash: str, now: float
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats set token_hash = %s, last_seen_at = to_timestamp(%s)
                 where session_id = %s::uuid and player_id = %s and occupied
                returning player_id
                """,
                (token_hash, now, session_id, player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

    def touch_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats
                   set last_seen_at = to_timestamp(%s),
                       autopilot = case when abandoned then autopilot else false end
                 where session_id = %s::uuid and player_id = %s and occupied
                returning player_id
                """,
                (now, session_id, player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable(f"seat {player_id} is unavailable")

    def set_turn_deadline(
        self,
        session_id: str,
        player_id: int | None,
        *,
        deadline_at: float | None,
        now: float,
    ) -> None:
        if (player_id is None) != (deadline_at is None):
            raise ValueError(
                "player_id and deadline_at must both be set or both be null"
            )
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """
                update server_sessions
                   set turn_player_id = %s,
                       turn_deadline_at = case when %s is null then null else to_timestamp(%s) end,
                       updated_at = to_timestamp(%s), scheduler_claim_owner = null,
                       scheduler_claim_until = null
                 where session_id = %s::uuid
                """,
                (player_id, deadline_at, deadline_at, now, session_id),
            )

    def turn_state(self, session_id: str) -> tuple[int | None, float | None]:
        with self._pool.connection() as connection:
            row = connection.execute(  # type: ignore[attr-defined]
                """
                select turn_player_id, extract(epoch from turn_deadline_at)
                  from server_sessions where session_id = %s::uuid
                """,
                (session_id,),
            ).fetchone()
        if row is None:
            raise KeyError(session_id)
        return (
            int(row[0]) if row[0] is not None else None,
            float(row[1]) if row[1] is not None else None,
        )

    def claim_due_turns(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[DueTurn]:
        if not owner or lease_seconds <= 0 or limit <= 0:
            raise ValueError("owner, lease_seconds, and limit must be positive")
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                with due as (
                    select session_id
                      from server_sessions
                     where status = 'active' and turn_deadline_at <= to_timestamp(%s)
                       and (scheduler_claim_until is null
                            or scheduler_claim_until <= to_timestamp(%s))
                     order by turn_deadline_at, session_id
                     for update skip locked limit %s
                )
                update server_sessions sessions
                   set scheduler_claim_owner = %s,
                       scheduler_claim_until = to_timestamp(%s) + (%s * interval '1 second'),
                       scheduler_fencing_token = scheduler_fencing_token + 1
                  from due where sessions.session_id = due.session_id
                returning sessions.session_id::text, sessions.turn_player_id,
                          extract(epoch from sessions.turn_deadline_at),
                          sessions.scheduler_fencing_token
                """,
                (now, now, limit, owner, now, lease_seconds),
            ).fetchall()
        return [
            DueTurn(str(row[0]), int(row[1]), float(row[2]), owner, int(row[3]))
            for row in rows
        ]

    def consume_timeout(self, claim: DueTurn, *, now: float) -> TimeoutResult:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            valid = connection.execute(  # type: ignore[attr-defined]
                """
                update server_sessions
                   set turn_player_id = null, turn_deadline_at = null,
                       scheduler_claim_owner = null, scheduler_claim_until = null,
                       updated_at = to_timestamp(%s)
                 where session_id = %s::uuid and turn_player_id = %s
                   and turn_deadline_at <= to_timestamp(%s)
                   and scheduler_claim_owner = %s and scheduler_fencing_token = %s
                returning session_id
                """,
                (
                    now,
                    claim.session_id,
                    claim.player_id,
                    now,
                    claim.claim_owner,
                    claim.fencing_token,
                ),
            ).fetchone()
            if valid is None:
                raise SeatUnavailable("stale timeout claim")
            seat = connection.execute(  # type: ignore[attr-defined]
                """
                update server_seats
                   set timeouts = timeouts + 1,
                       autopilot = case when timeouts + 1 >= 2 then true else autopilot end,
                       abandoned = case when timeouts + 1 >= 2 then true else abandoned end
                 where session_id = %s::uuid and player_id = %s and occupied
                returning timeouts, autopilot
                """,
                (claim.session_id, claim.player_id),
            ).fetchone()
            if seat is None:
                raise SeatUnavailable("timeout seat unavailable")
            return TimeoutResult(int(seat[0]), bool(seat[1]))

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
        return SQLiteLobbyRepository.new_session(
            seed=seed,
            variants=variants,
            controllers=controllers,
            ranked=ranked,
            browser_joinable=browser_joinable,
            created_by_user_id=created_by_user_id,
            ttl_seconds=ttl_seconds,
        )

    @staticmethod
    def _session_row(row: object) -> SessionRecord:
        return SessionRecord(
            str(row[0]),  # type: ignore[index]
            str(row[1]),  # type: ignore[index]
            int(row[2]),  # type: ignore[index]
            dict(row[3]),  # type: ignore[index]
            list(row[4]),  # type: ignore[index]
            bool(row[5]),  # type: ignore[index]
            bool(row[6]),  # type: ignore[index]
            str(row[7]),  # type: ignore[index]
            str(row[8]) if row[8] else None,  # type: ignore[index]
            float(row[9]),  # type: ignore[index]
            float(row[10]),  # type: ignore[index]
            float(row[11]),  # type: ignore[index]
            float(row[12]) if row[12] is not None else None,  # type: ignore[index]
        )

    @staticmethod
    def _seat_row(row: object) -> SeatRecord:
        return SeatRecord(
            int(row[0]),  # type: ignore[index]
            str(row[1]),  # type: ignore[index]
            bool(row[2]),  # type: ignore[index]
            str(row[3]) if row[3] else None,  # type: ignore[index]
            str(row[4]) if row[4] else None,  # type: ignore[index]
            float(row[5]) if row[5] is not None else None,  # type: ignore[index]
            int(row[6]),  # type: ignore[index]
            bool(row[7]),  # type: ignore[index]
            bool(row[8]),  # type: ignore[index]
        )
