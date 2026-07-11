from __future__ import annotations

import hashlib
import threading
import time
import uuid
from dataclasses import dataclass
from typing import Callable, Mapping, Protocol, Sequence

from .matchmaking import (
    DEFAULT_RATING,
    LOBBY_SEED_INTERVAL_SECONDS,
    OPEN_SEAT_FILL_INTERVAL_SECONDS,
    BotProfile,
    MatchmakingSession,
    PopulationPlanner,
    PopulationSeed,
    bot_fill_choices,
    target_bot_rating,
)
from .store import ConnectionPool


PROFILE_BOT_TARGET_WAIT_SECONDS = 90
DEFAULT_BATCH_SIZE = 256
DEFAULT_LEASE_SECONDS = 25


@dataclass(frozen=True)
class IntervalClaim:
    job_kind: str
    interval_epoch: int
    owner_id: str
    fencing_token: int


@dataclass(frozen=True)
class PopulationTickResult:
    seeded_session_ids: tuple[str, ...] = ()
    filled_seats: tuple[tuple[str, int, str], ...] = ()


class PopulationRepository(Protocol):
    """Atomic persistence boundary for a horizontally replicated scheduler."""

    def claim_interval(
        self,
        job_kind: str,
        interval_epoch: int,
        *,
        owner_id: str,
        now: float,
        lease_seconds: float,
    ) -> IntervalClaim | None: ...

    def seed_lobby(
        self,
        spec: PopulationSeed,
        profiles: Sequence[BotProfile],
        *,
        idempotency_key: str,
        now: float,
        claim: IntervalClaim,
    ) -> str | None: ...

    def open_fill_sessions(
        self, *, now: float, created_before: float, limit: int
    ) -> Sequence[MatchmakingSession]: ...

    def profiles(self, *, limit: int) -> Sequence[BotProfile]: ...

    def create_profiles(
        self,
        *,
        count: int,
        target_rating: int,
        exclude_user_ids: set[str],
        now: float,
    ) -> Sequence[BotProfile]: ...

    def active_profile_bot_user_ids(self, now: float) -> set[str]: ...

    def ratings(self, user_ids: set[str]) -> Mapping[str, int]: ...

    def bot_use_counts(self, user_ids: set[str]) -> Mapping[str, int]: ...

    def claim_bot_seat(
        self,
        session_id: str,
        player_id: int,
        profile: BotProfile,
        *,
        idempotency_key: str,
        now: float,
        claim: IntervalClaim,
    ) -> bool: ...


class PopulationScheduler:
    """Runs deterministic population jobs without process-global state or locks.

    Interval keys make retries idempotent. Repository fencing prevents a scheduler
    whose lease expired mid-tick from mutating a later owner's work.
    """

    def __init__(
        self,
        repository: PopulationRepository,
        *,
        owner_id: str | None = None,
        batch_size: int = DEFAULT_BATCH_SIZE,
        lease_seconds: float = DEFAULT_LEASE_SECONDS,
        planner: PopulationPlanner | None = None,
        on_filled: Callable[[str], None] | None = None,
    ) -> None:
        if batch_size < 1:
            raise ValueError("batch_size must be positive")
        self.repository = repository
        self.owner_id = owner_id or str(uuid.uuid4())
        self.batch_size = batch_size
        self.lease_seconds = lease_seconds
        self.planner = planner or PopulationPlanner()
        self.on_filled = on_filled
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def tick(self, *, now: float) -> PopulationTickResult:
        seeded = self._seed(now)
        filled = self._fill(now)
        return PopulationTickResult(tuple(seeded), tuple(filled))

    def _seed(self, now: float) -> list[str]:
        epoch = int(now // LOBBY_SEED_INTERVAL_SECONDS)
        claim = self.repository.claim_interval(
            "population-seed",
            epoch,
            owner_id=self.owner_id,
            now=now,
            lease_seconds=self.lease_seconds,
        )
        if claim is None:
            return []
        specs = self.planner.seed_specs(now=now, seed_sequence=epoch)
        bot_count = sum(4 - spec.open_human_seats for spec in specs)
        profiles = self._profiles(bot_count, now=now, target_rating=DEFAULT_RATING)
        use_counts = self.repository.bot_use_counts(
            {profile.user_id for profile in profiles}
        )
        selected_ids: set[str] = set()
        session_ids: list[str] = []
        for index, spec in enumerate(specs):
            selected = self.planner.choose_profiles(
                profiles,
                count=4 - spec.open_human_seats,
                now=now,
                use_counts=use_counts,
                exclude_user_ids=selected_ids,
            )
            if len(selected) != 4 - spec.open_human_seats:
                continue
            selected_ids.update(profile.user_id for profile in selected)
            key = f"population-seed:{epoch}:{index}"
            session_id = self.repository.seed_lobby(
                spec,
                selected,
                idempotency_key=key,
                now=now,
                claim=claim,
            )
            if session_id is not None:
                session_ids.append(session_id)
        return session_ids

    def _fill(self, now: float) -> list[tuple[str, int, str]]:
        epoch = int(now // OPEN_SEAT_FILL_INTERVAL_SECONDS)
        claim = self.repository.claim_interval(
            "population-fill",
            epoch,
            owner_id=self.owner_id,
            now=now,
            lease_seconds=self.lease_seconds,
        )
        if claim is None:
            return []
        sessions = list(
            self.repository.open_fill_sessions(
                now=now,
                created_before=now - PROFILE_BOT_TARGET_WAIT_SECONDS,
                limit=self.batch_size,
            )
        )
        if not sessions:
            return []
        seated_ids = {
            user_id for session in sessions for user_id in session.seated_user_ids
        }
        ratings = dict(self.repository.ratings(seated_ids))
        profiles = self._profiles(
            len(sessions),
            now=now,
            target_rating=target_bot_rating(sessions, ratings),
        )
        active = self.repository.active_profile_bot_user_ids(now)
        rating_ids = seated_ids | {profile.user_id for profile in profiles}
        ratings.update(self.repository.ratings(rating_ids - ratings.keys()))
        choices = bot_fill_choices(sessions, profiles, ratings, active_user_ids=active)
        filled: list[tuple[str, int, str]] = []
        for choice in choices:
            key = f"population-fill:{epoch}:{choice.session_id}:{choice.player_id}"
            if self.repository.claim_bot_seat(
                choice.session_id,
                choice.player_id,
                choice.profile,
                idempotency_key=key,
                now=now,
                claim=claim,
            ):
                filled.append(
                    (choice.session_id, choice.player_id, choice.profile.user_id)
                )
                if self.on_filled is not None:
                    try:
                        self.on_filled(choice.session_id)
                    except Exception:
                        # The owning worker observes the durable controller change
                        # on its next command; this replica may not hold its lease.
                        pass
        return filled

    def start(self, *, interval_seconds: float = 1.0) -> None:
        if interval_seconds <= 0:
            raise ValueError("interval_seconds must be positive")
        if self._thread is not None:
            raise RuntimeError("population scheduler is already running")
        self._stop.clear()

        def run() -> None:
            while not self._stop.wait(interval_seconds):
                self.tick(now=time.time())

        self._thread = threading.Thread(
            target=run,
            name=f"kolkhoz-population-{self.owner_id}",
            daemon=True,
        )
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None

    def _profiles(
        self, count: int, *, now: float, target_rating: int
    ) -> list[BotProfile]:
        profiles = list(self.repository.profiles(limit=max(count * 2, 8)))
        active = self.repository.active_profile_bot_user_ids(now)
        available = [profile for profile in profiles if profile.user_id not in active]
        if len(available) < count:
            available.extend(
                self.repository.create_profiles(
                    count=count - len(available),
                    target_rating=target_rating,
                    exclude_user_ids=active | {p.user_id for p in profiles},
                    now=now,
                )
            )
        return available


class PostgresPopulationRepository:
    """Pooled PostgreSQL scheduler adapter with transactional fencing.

    Candidate reads are bounded and use partial indexes. Seat claims lock only one
    selected seat and one bot profile; replicas never scan or lock every session.
    """

    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    def claim_interval(
        self,
        job_kind: str,
        interval_epoch: int,
        *,
        owner_id: str,
        now: float,
        lease_seconds: float,
    ) -> IntervalClaim | None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(  # type: ignore[attr-defined]
                """
                insert into population_intervals (
                    job_kind, interval_epoch, owner_id, fencing_token, expires_at
                ) values (%s, %s, %s, 1, to_timestamp(%s + %s))
                on conflict (job_kind) do update
                   set interval_epoch = excluded.interval_epoch,
                       owner_id = excluded.owner_id,
                       fencing_token = population_intervals.fencing_token + 1,
                       expires_at = excluded.expires_at
                 where population_intervals.interval_epoch < excluded.interval_epoch
                    or (population_intervals.interval_epoch = excluded.interval_epoch
                        and population_intervals.expires_at <= to_timestamp(%s))
                returning fencing_token
                """,
                (job_kind, interval_epoch, owner_id, now, lease_seconds, now),
            ).fetchone()
        if row is None:
            return None
        return IntervalClaim(job_kind, interval_epoch, owner_id, int(row[0]))

    def seed_lobby(
        self,
        spec: PopulationSeed,
        profiles: Sequence[BotProfile],
        *,
        idempotency_key: str,
        now: float,
        claim: IntervalClaim,
    ) -> str | None:
        session_id = str(uuid.uuid5(uuid.NAMESPACE_URL, idempotency_key))
        digest = hashlib.sha256(idempotency_key.encode()).digest()
        seed = int.from_bytes(digest[:8], "big") & ((1 << 63) - 1)
        invite_code = (
            hashlib.sha256((idempotency_key + ":invite").encode())
            .hexdigest()[:10]
            .upper()
        )
        token_hashes = [
            hashlib.sha256(f"{idempotency_key}:{player_id}".encode()).hexdigest()
            for player_id in range(4)
        ]
        controllers = [profile.controller for profile in profiles] + [
            "human"
        ] * spec.open_human_seats
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            valid = connection.execute(  # type: ignore[attr-defined]
                """
                select 1 from population_intervals
                 where job_kind = %s and interval_epoch = %s and owner_id = %s
                   and fencing_token = %s and expires_at > to_timestamp(%s)
                """,
                (
                    claim.job_kind,
                    claim.interval_epoch,
                    claim.owner_id,
                    claim.fencing_token,
                    now,
                ),
            ).fetchone()
            if valid is None:
                return None
            connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_games (session_id, seed, variants, created_at, updated_at)
                values (
                    %s::uuid, %s,
                    jsonb_build_object(
                        'variants', '{}'::jsonb,
                        'controllers', %s::jsonb,
                        'populationKind', %s
                    ),
                    to_timestamp(%s), to_timestamp(%s)
                )
                on conflict (session_id) do nothing
                """,
                (
                    session_id,
                    seed,
                    __import__("json").dumps(controllers),
                    spec.population_kind,
                    now,
                    now,
                ),
            )
            inserted = connection.execute(  # type: ignore[attr-defined]
                """
                insert into server_sessions (
                    session_id, invite_code, seed, variants, controllers, ranked,
                    browser_joinable, status, created_by_user_id, created_at,
                    updated_at, expires_at
                ) values (%s::uuid, %s, %s, '{}'::jsonb, %s::jsonb, %s, true,
                          'open', %s, to_timestamp(%s), to_timestamp(%s),
                          to_timestamp(%s + 86400))
                on conflict (session_id) do nothing returning session_id
                """,
                (
                    session_id,
                    invite_code,
                    seed,
                    __import__("json").dumps(controllers),
                    spec.ranked,
                    profiles[0].user_id if profiles else None,
                    now,
                    now,
                    now,
                ),
            ).fetchone()
            if inserted is None:
                return None
            for player_id, controller in enumerate(controllers):
                profile = profiles[player_id] if player_id < len(profiles) else None
                connection.execute(  # type: ignore[attr-defined]
                    """
                    insert into server_seats (
                        session_id, player_id, controller, occupied, user_id,
                        token_hash, last_seen_at
                    ) values (%s::uuid, %s, %s, %s, %s,
                              case when %s then %s else null end,
                              case when %s then to_timestamp(%s) else null end)
                    """,
                    (
                        session_id,
                        player_id,
                        controller,
                        profile is not None,
                        profile.user_id if profile else None,
                        profile is not None,
                        token_hashes[player_id],
                        profile is not None,
                        now,
                    ),
                )
                if profile is not None:
                    self._record_use(connection, profile.user_id, now)
        return session_id

    def open_fill_sessions(
        self, *, now: float, created_before: float, limit: int
    ) -> Sequence[MatchmakingSession]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select s.session_id::text, extract(epoch from s.created_at), s.ranked,
                       array_agg(seat.player_id order by seat.player_id)
                           filter (where seat.controller = 'human' and not seat.occupied),
                       array_agg(seat.user_id order by seat.player_id)
                           filter (where seat.occupied and seat.user_id is not null)
                  from server_sessions s join server_seats seat using (session_id)
                 where s.status = 'open' and s.browser_joinable
                   and s.expires_at > to_timestamp(%s)
                   and s.created_at <= to_timestamp(%s)
                   and exists (select 1 from server_seats open_seat
                                where open_seat.session_id = s.session_id
                                  and open_seat.controller = 'human'
                                  and not open_seat.occupied)
                 group by s.session_id
                 order by s.created_at, s.session_id
                 limit %s
                """,
                (now, created_before, limit),
            ).fetchall()
        return [
            MatchmakingSession(
                str(row[0]),
                float(row[1]),
                bool(row[2]),
                True,
                tuple(int(value) for value in (row[3] or ())),
                tuple(str(value) for value in (row[4] or ())),
            )
            for row in rows
        ]

    def profiles(self, *, limit: int) -> Sequence[BotProfile]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select b.user_id, b.controller, coalesce(s.rating, %s)
                  from public.server_bot_profiles b
                  left join public.profile_stats s on s.user_id = b.user_id
                 where b.active order by b.use_count, b.user_id limit %s
                """,
                (DEFAULT_RATING, limit),
            ).fetchall()
        return [BotProfile(str(r[0]), str(r[1]), int(r[2])) for r in rows]

    def create_profiles(
        self,
        *,
        count: int,
        target_rating: int,
        exclude_user_ids: set[str],
        now: float,
    ) -> Sequence[BotProfile]:
        # Profile creation remains an explicit provisioning concern. The scheduler
        # consumes an elastic pre-provisioned pool instead of creating auth users in
        # its latency-sensitive transaction.
        return []

    def active_profile_bot_user_ids(self, now: float) -> set[str]:
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                """
                select distinct seat.user_id
                  from server_seats seat join server_sessions s using (session_id)
                  join public.server_bot_profiles b on b.user_id::text = seat.user_id
                 where seat.occupied and s.status in ('open', 'active')
                   and s.expires_at > to_timestamp(%s)
                """,
                (now,),
            ).fetchall()
        return {str(row[0]) for row in rows}

    def ratings(self, user_ids: set[str]) -> Mapping[str, int]:
        if not user_ids:
            return {}
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                "select user_id, rating from public.profile_stats where user_id::text = any(%s)",
                (list(user_ids),),
            ).fetchall()
        return {str(row[0]): int(row[1]) for row in rows}

    def bot_use_counts(self, user_ids: set[str]) -> Mapping[str, int]:
        if not user_ids:
            return {}
        with self._pool.connection() as connection:
            rows = connection.execute(  # type: ignore[attr-defined]
                "select user_id, use_count from public.server_bot_profiles where user_id::text = any(%s)",
                (list(user_ids),),
            ).fetchall()
        return {str(row[0]): int(row[1]) for row in rows}

    def claim_bot_seat(
        self,
        session_id: str,
        player_id: int,
        profile: BotProfile,
        *,
        idempotency_key: str,
        now: float,
        claim: IntervalClaim,
    ) -> bool:
        token_hash = hashlib.sha256(idempotency_key.encode()).hexdigest()
        try:
            with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
                valid = connection.execute(  # type: ignore[attr-defined]
                    """
                    select 1 from population_intervals
                     where job_kind = %s and interval_epoch = %s and owner_id = %s
                       and fencing_token = %s and expires_at > to_timestamp(%s)
                    """,
                    (
                        claim.job_kind,
                        claim.interval_epoch,
                        claim.owner_id,
                        claim.fencing_token,
                        now,
                    ),
                ).fetchone()
                if valid is None:
                    return False
                updated = connection.execute(  # type: ignore[attr-defined]
                    """
                    update server_seats seat
                       set controller = %s, occupied = true, user_id = %s,
                           token_hash = %s, last_seen_at = to_timestamp(%s)
                      from server_sessions session
                     where seat.session_id = %s::uuid and seat.player_id = %s
                       and session.session_id = seat.session_id
                       and session.status = 'open' and session.browser_joinable
                       and seat.controller = 'human' and not seat.occupied
                       and not exists (
                           select 1 from server_seats occupied
                           join server_sessions active using (session_id)
                           where occupied.user_id = %s and occupied.occupied
                             and active.status in ('open', 'active')
                       )
                    """,
                    (
                        profile.controller,
                        profile.user_id,
                        token_hash,
                        now,
                        session_id,
                        player_id,
                        profile.user_id,
                    ),
                )
                if updated.rowcount != 1:
                    raise _SeatClaimLost
                connection.execute(  # type: ignore[attr-defined]
                    """
                    update server_games
                       set variants = jsonb_set(
                               variants,
                               array['controllers', %s],
                               to_jsonb(%s::text),
                               false
                           ),
                           updated_at = to_timestamp(%s)
                     where session_id = %s::uuid
                    """,
                    (str(player_id), profile.controller, now, session_id),
                )
                self._record_use(connection, profile.user_id, now)
        except _SeatClaimLost:
            return False
        return True

    @staticmethod
    def _record_use(connection: object, user_id: str, now: float) -> None:
        connection.execute(  # type: ignore[attr-defined]
            """
            update public.server_bot_profiles
               set use_count = use_count + 1, last_used_at = to_timestamp(%s)
             where user_id = %s
            """,
            (now, user_id),
        )


class _SeatClaimLost(RuntimeError):
    pass
