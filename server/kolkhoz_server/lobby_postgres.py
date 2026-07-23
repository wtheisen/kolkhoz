from __future__ import annotations

import uuid

from .lobby import (
    DueTurn,
    LifecycleIntent,
    SeatRecord,
    SeatUnavailable,
    SessionRecord,
    TimeoutResult,
    new_session_record,
)
from .model import JsonObject
from .store import ConnectionPool


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
            for user_id in {seat.user_id for seat in seats if seat.user_id is not None}:
                self._release_finished_seats(connection, user_id)
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_sessions (
                    session_id, invite_code, seed, variants, controllers, ranked,
                    browser_joinable, status, created_by_user_id, created_at,
                    updated_at, expires_at, lobby_countdown_ends_at
                ) values (
                    %s::uuid, upper(%s), %s, %s, %s, %s, %s, %s, %s,
                    to_timestamp(%s), to_timestamp(%s), to_timestamp(%s),
                    case when %s::double precision is null then null else to_timestamp(%s) end
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
                        case when %s::double precision is null then null else to_timestamp(%s) end,
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
            connection.execute(  # type: ignore[attr-defined]
                """insert into server_lifecycle_intents
                       (session_id, operation, seed, variants, controllers, next_attempt_at)
                     values (%s::uuid, 'provision', %s, %s, %s, to_timestamp(%s))
                     on conflict (session_id, operation) do nothing""",
                (
                    record.session_id,
                    record.seed,
                    self._jsonb(record.variants),
                    self._jsonb(record.controllers),
                    record.created_at,
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

    def list_watchable(self, now: float) -> list[SessionRecord]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """select session_id::text, invite_code, seed, variants,
                          controllers, ranked, browser_joinable, status,
                          created_by_user_id, extract(epoch from created_at),
                          extract(epoch from updated_at), extract(epoch from expires_at),
                          extract(epoch from lobby_countdown_ends_at)
                     from server_sessions
                    where status = 'active' and browser_joinable and not ranked
                      and expires_at > to_timestamp(%s)
                    order by updated_at desc""",
                (now,),
            ).fetchall()
        return [self._session_row(row) for row in rows]

    def automatic_due_sessions(self, *, now: float, limit: int) -> list[str]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """select session_id::text from server_sessions
                    where status = 'active' and turn_player_id is null
                      and expires_at > to_timestamp(%s)
                      and updated_at <= to_timestamp(%s)
                    order by updated_at, session_id limit %s""",
                (now, now - 1, limit),
            ).fetchall()
        return [str(row[0]) for row in rows]

    def activate_ready_sessions(self, *, now: float) -> list[str]:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            rows = connection.execute(  # type: ignore[attr-defined]
                """update server_sessions sessions
                      set status = 'active', updated_at = to_timestamp(%s),
                          lobby_countdown_ends_at = null
                    where sessions.status = 'open'
                      and sessions.lobby_countdown_ends_at is not null
                      and sessions.lobby_countdown_ends_at <= to_timestamp(%s)
                      and not exists (
                          select 1 from server_seats seats
                           where seats.session_id = sessions.session_id
                             and seats.controller = 'human' and not seats.occupied
                      )
                returning sessions.session_id::text""",
                (now, now),
            ).fetchall()
        return [str(row[0]) for row in rows]

    def finish_session(self, session_id: str, *, now: float, expires_at: float) -> bool:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """update server_sessions
                      set status = 'finished', updated_at = to_timestamp(%s),
                          expires_at = to_timestamp(%s), turn_player_id = null,
                          turn_deadline_at = null
                    where session_id = %s::uuid and status = 'active'
                returning session_id""",
                (now, expires_at, session_id),
            ).fetchone()
            if row is not None:
                connection.execute(  # type: ignore[attr-defined]
                    """insert into server_lifecycle_intents
                           (session_id, operation, next_attempt_at)
                         values (%s::uuid, 'invalidate', to_timestamp(%s))
                         on conflict (session_id, operation) do update
                           set state = 'pending', next_attempt_at = excluded.next_attempt_at""",
                    (session_id, now),
                )
        return row is not None

    def expire_sessions(self, *, now: float, limit: int) -> list[str]:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            rows = connection.execute(  # type: ignore[attr-defined]
                """with expired as (
                       select session_id from server_sessions
                        where status in ('open', 'active') and expires_at <= to_timestamp(%s)
                        order by expires_at, session_id
                        for update skip locked limit %s
                   ), updated as (
                       update server_sessions sessions
                          set status = 'expired', updated_at = to_timestamp(%s),
                              turn_player_id = null, turn_deadline_at = null
                         from expired where sessions.session_id = expired.session_id
                       returning sessions.session_id
                   )
                   insert into server_lifecycle_intents
                       (session_id, operation, next_attempt_at)
                   select session_id, 'invalidate', to_timestamp(%s) from updated
                   on conflict (session_id, operation) do update
                       set state = 'pending', next_attempt_at = excluded.next_attempt_at
                   returning session_id::text""",
                (now, limit, now, now),
            ).fetchall()
            session_ids = [str(row[0]) for row in rows]
            if session_ids:
                connection.execute(  # type: ignore[attr-defined]
                    """update server_seats
                          set occupied = false, user_id = null, token_hash = null,
                              last_seen_at = null, autopilot = false, abandoned = false
                        where session_id = any(%s::uuid[])""",
                    (session_ids,),
                )
        return session_ids

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
                self._release_finished_seats(connection, user_id)
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

    @staticmethod
    def _release_finished_seats(connection: object, user_id: str) -> None:
        connection.execute(  # type: ignore[attr-defined]
            """update server_seats seat
                  set occupied = false, user_id = null, token_hash = null,
                      last_seen_at = null, autopilot = false, abandoned = false
                  from server_sessions session
                 where seat.session_id = session.session_id
                   and seat.user_id = %s
                   and session.status in ('finished', 'expired')""",
            (user_id,),
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
                connection.execute(  # type: ignore[attr-defined]
                    """insert into server_lifecycle_intents
                           (session_id, operation, next_attempt_at)
                         values (%s::uuid, 'delete', to_timestamp(%s))
                         on conflict (session_id, operation) do update
                           set state = 'pending', next_attempt_at = excluded.next_attempt_at""",
                    (session_id, now),
                )
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
                       lobby_countdown_ends_at = case when %s::double precision is null then null else to_timestamp(%s) end
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
                """insert into server_lifecycle_intents
                       (session_id, operation, next_attempt_at)
                     values (%s::uuid, 'delete', now())
                     on conflict (session_id, operation) do update
                       set state = 'pending', next_attempt_at = excluded.next_attempt_at""",
                (session_id,),
            )
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
                    (select count(*) from (
                        select user_id::text from server_presence
                         where last_seen_at >= to_timestamp(%s)
                        union
                        select user_id::text
                          from public.server_bot_profiles where active
                    ) citizens)
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
                 where seats.user_id = %s and seats.occupied and not seats.abandoned
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

    def touch_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        now: float,
        session_ttl_seconds: float | None = None,
    ) -> None:
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
            if session_ttl_seconds is not None:
                connection.execute(  # type: ignore[attr-defined]
                    """update server_sessions
                          set expires_at = greatest(
                              expires_at, to_timestamp(%s)
                          )
                        where session_id = %s::uuid
                          and status in ('open', 'active')""",
                    (now + session_ttl_seconds, session_id),
                )

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
                       turn_deadline_at = case when %s::double precision is null then null else to_timestamp(%s) end,
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
            existing = connection.execute(  # type: ignore[attr-defined]
                """select timeouts, forced_autopilot, state
                     from server_timeout_transitions
                    where session_id = %s::uuid and fencing_token = %s""",
                (claim.session_id, claim.fencing_token),
            ).fetchone()
            if existing is not None:
                return TimeoutResult(
                    int(existing[0]), bool(existing[1]), str(existing[2]) == "completed"
                )
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
            connection.execute(  # type: ignore[attr-defined]
                """insert into server_timeout_transitions
                       (session_id, fencing_token, player_id, timeouts,
                        forced_autopilot, state)
                     values (%s::uuid, %s, %s, %s, %s, 'pending')""",
                (
                    claim.session_id,
                    claim.fencing_token,
                    claim.player_id,
                    int(seat[0]),
                    bool(seat[1]),
                ),
            )
            return TimeoutResult(int(seat[0]), bool(seat[1]))

    def complete_timeout(self, claim: DueTurn) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """update server_timeout_transitions set state = 'completed'
                    where session_id = %s::uuid and fencing_token = %s and player_id = %s
                    returning session_id""",
                (claim.session_id, claim.fencing_token, claim.player_id),
            ).fetchone()
            if row is None:
                raise SeatUnavailable("timeout transition unavailable")

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
        return new_session_record(
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

    def complete_lifecycle_intent(
        self, session_id: str, operation: str, *, fencing_token: int | None = None
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """delete from server_lifecycle_intents
                    where session_id = %s::uuid and operation = %s
                      and (%s::bigint is null or fencing_token = %s)""",
                (session_id, operation, fencing_token, fencing_token),
            )

    def claim_lifecycle_intents(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[LifecycleIntent]:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            rows = connection.execute(  # type: ignore[attr-defined]
                """with due as (
                       select session_id, operation from server_lifecycle_intents
                        where state = 'pending' and next_attempt_at <= to_timestamp(%s)
                          and (claim_until is null or claim_until <= to_timestamp(%s))
                        order by next_attempt_at, session_id
                        for update skip locked limit %s
                   )
                   update server_lifecycle_intents intents
                      set claim_owner = %s,
                          claim_until = to_timestamp(%s) + (%s * interval '1 second'),
                          fencing_token = fencing_token + 1, attempts = attempts + 1
                     from due where intents.session_id = due.session_id
                               and intents.operation = due.operation
                   returning intents.session_id::text, intents.operation, intents.seed,
                             intents.variants, intents.controllers, intents.fencing_token""",
                (now, now, limit, owner, now, lease_seconds),
            ).fetchall()
        return [
            LifecycleIntent(
                str(row[0]),
                str(row[1]),
                None if row[2] is None else int(row[2]),
                None if row[3] is None else dict(row[3]),
                None if row[4] is None else list(row[4]),
                int(row[5]),
            )
            for row in rows
        ]

    def retry_lifecycle_intent(
        self, intent: LifecycleIntent, *, now: float, delay_seconds: float
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(  # type: ignore[attr-defined]
                """update server_lifecycle_intents
                      set next_attempt_at = to_timestamp(%s), claim_owner = null,
                          claim_until = null
                    where session_id = %s::uuid and operation = %s
                      and fencing_token = %s""",
                (
                    now + delay_seconds,
                    intent.session_id,
                    intent.operation,
                    intent.fencing_token,
                ),
            )
