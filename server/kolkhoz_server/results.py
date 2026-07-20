from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from math import exp, log1p, sqrt
from typing import Callable, Iterator, Protocol

from .store import ConnectionPool


AI_PROFILES = {
    "heuristicAI": "Easy AI",
    "mediumAI": "Medium AI",
    "neuralAI": "Hard AI",
}
BAN_STRIKES = 3
BAN_DAYS = 3

DEFAULT_MU = 25.0
DEFAULT_SIGMA = DEFAULT_MU / 3.0
MIN_SIGMA = 2.0
BETA = DEFAULT_MU / 6.0
TAU = DEFAULT_MU / 300.0
DISPLAY_SCALE = 32.0
DISPLAY_MIN = 100
DISPLAY_MAX = 3000

TARGETS = {
    "achievement.first_game": 1,
    "achievement.clear_victory": 1,
    "achievement.medalist": 1,
    "achievement.no_requisition": 1,
    "achievement.saboteur_exiled": 1,
    "achievement.first_win": 1,
    "achievement.century": 1,
    "challenge.games_5": 5,
    "challenge.wins_3": 3,
    "challenge.score_500": 500,
    "challenge.medals_25": 25,
    "challenge.games_10": 10,
    "challenge.wins_5": 5,
    "challenge.score_1000": 1000,
}
UNLOCK_REWARDS = {
    "challenge.games_5": "unlock.card_back.harvest",
    "challenge.wins_3": "unlock.card_back.granary",
    "challenge.score_500": "unlock.card_back.winter",
}

Result = dict[str, object]
Progression = dict[str, object]


@dataclass(frozen=True)
class RatingInput:
    key: str
    rank: float
    score: float
    mu: float = DEFAULT_MU
    sigma: float = DEFAULT_SIGMA


@dataclass(frozen=True)
class RatingOutput:
    key: str
    mu: float
    sigma: float
    display_rating: int


class ResultsRepository(Protocol):
    def recent_games(self, *, user_id: str, limit: int = 5) -> list[Result]: ...

    def session_results(self, *, session_id: str, user_id: str) -> list[Result]: ...

    def claim_daily_attempt(
        self, *, challenge_date: str, user_id: str, session_id: str
    ) -> bool: ...

    def daily_challenge(self, *, challenge_date: str, user_id: str) -> Result: ...
    def create_series(self, *, session_id: str, best_of: int) -> Result: ...
    def continue_series(
        self, *, source_session_id: str, session_id: str
    ) -> Result | None: ...
    def series_status(self, *, session_id: str) -> Result | None: ...

    def record_session_results(
        self,
        *,
        session_id: str,
        results: list[Result],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> bool: ...

    def online_ban_for_user(
        self, *, user_id: str, checked_at: float
    ) -> dict[str, object] | None: ...

    def record_abandonment(
        self,
        *,
        session_id: str,
        player_id: int,
        user_id: str | None,
        updated_at: float,
        revision: int,
    ) -> dict[str, object] | None: ...


class PostgresResultsRepository:
    """Transactional result, rating, progression, and discipline persistence.

    Connections are checked out per operation. PostgreSQL row locks and uniqueness
    constraints provide coordination across processes; no process-global query lock
    or in-memory result authority is used.
    """

    def __init__(
        self,
        database_url: str | None = None,
        *,
        pool: ConnectionPool | None = None,
        pool_size: int = 8,
        json_value: Callable[[object], object] | None = None,
    ) -> None:
        if pool is not None:
            self._pool = pool
            if json_value is None:
                from psycopg.types.json import Jsonb

                json_value = Jsonb
            self._json_value = json_value
            self._owns_pool = False
            return
        if not database_url:
            raise ValueError("database_url is required")
        try:
            import psycopg
            from psycopg.types.json import Jsonb
        except ImportError as error:
            raise RuntimeError("PostgreSQL requires psycopg[binary]>=3.2") from error
        self._pool = ConnectionPool(
            lambda: psycopg.connect(
                database_url,
                autocommit=False,
                prepare_threshold=None,
                connect_timeout=5,
                options=(
                    "-c statement_timeout=5000 -c lock_timeout=3000 "
                    "-c idle_in_transaction_session_timeout=5000"
                ),
            ),
            size=pool_size,
        )
        self._json_value = Jsonb
        self._owns_pool = True

    def close(self) -> None:
        if self._owns_pool:
            self._pool.close()

    @contextmanager
    def _cursor(self) -> Iterator[object]:
        with self._pool.connection() as connection, connection.transaction():
            with connection.cursor() as cursor:
                yield cursor

    def online_ban_for_user(
        self, *, user_id: str, checked_at: float
    ) -> dict[str, object] | None:
        with self._cursor() as cursor:
            cursor.execute(
                """select online_abandon_strikes, online_banned_until
                     from public.profile_stats
                    where user_id = %s""",
                (user_id,),
            )
            row = cursor.fetchone()
        checked = _timestamp(checked_at)
        if row is None or row[1] is None or row[1] <= checked:
            return None
        return {"strikes": int(row[0]), "banned_until": row[1].timestamp()}

    def record_abandonment(
        self,
        *,
        session_id: str,
        player_id: int,
        user_id: str | None,
        updated_at: float,
        revision: int,
    ) -> dict[str, object] | None:
        now = _timestamp(updated_at)
        penalty = None
        with self._cursor() as cursor:
            if user_id:
                self._ensure_human(cursor, user_id, now)
                cursor.execute(
                    f"""update public.profile_stats
                           set online_abandon_strikes = online_abandon_strikes + 1,
                               online_banned_until = case
                                 when online_abandon_strikes + 1 >= %s
                                 then %s + interval '{BAN_DAYS} days'
                                 else online_banned_until end,
                               updated_at = %s
                         where user_id = %s
                     returning online_abandon_strikes, online_banned_until""",
                    (BAN_STRIKES, now, now, user_id),
                )
                row = cursor.fetchone()
                if row is not None:
                    penalty = {
                        "strikes": int(row[0]),
                        "banned_until": (
                            row[1].timestamp() if row[1] is not None else None
                        ),
                    }
            self._insert_update(cursor, session_id, revision, "abandoned", now)
        return penalty

    def record_session_results(
        self,
        *,
        session_id: str,
        results: list[Result],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> bool:
        """Persist a complete result exactly once; lifecycle belongs to lobby."""
        now = _timestamp(updated_at)
        with self._cursor() as cursor:
            cursor.execute(
                """insert into server_result_commits (session_id, recorded_at)
                   values (%s, %s) on conflict (session_id) do nothing
                returning session_id""",
                (session_id, now),
            )
            if cursor.fetchone() is None:
                return False

            human_results = [result for result in results if _user_id(result)]
            for result in human_results:
                user_id = _user_id(result)
                assert user_id is not None
                self._ensure_human(cursor, user_id, now)
                cursor.execute(
                    """insert into server_game_results (
                           session_id, user_id, player_id, score, rank, won,
                           ranked, completed_at
                       ) values (%s, %s, %s, %s, %s, %s, %s, %s)
                       on conflict (session_id, user_id) do nothing""",
                    (
                        session_id,
                        user_id,
                        int(result.get("player_id", 0)),
                        int(result.get("score", 0)),
                        int(result.get("rank", 4)),
                        bool(result.get("won", False)),
                        ranked,
                        now,
                    ),
                )
                self._record_progression(
                    cursor,
                    session_id=session_id,
                    user_id=user_id,
                    result=result,
                    updated_at=now,
                )

            ai_results = aggregate_ai_results(results)
            for ai_key in ai_results:
                cursor.execute(
                    """insert into public.ai_profile_stats (ai_key, display_name)
                       values (%s, %s)
                       on conflict (ai_key) do update
                          set display_name = excluded.display_name""",
                    (ai_key, AI_PROFILES[ai_key]),
                )

            ratings = self._load_ratings(
                cursor, human_results, ai_results, casual=not ranked
            )
            outputs = rate_multiplayer(
                rating_inputs(human_results, ai_results, ratings)
            )
            for result in human_results:
                user_id = _user_id(result)
                assert user_id is not None
                self._update_stats(
                    cursor,
                    table="profile_stats",
                    identity_column="user_id",
                    identity=user_id,
                    result=result,
                    rating=outputs.get(_user_key(user_id)),
                    ranked=ranked,
                    updated_at=now,
                )
            for ai_key, result in ai_results.items():
                self._update_stats(
                    cursor,
                    table="ai_profile_stats",
                    identity_column="ai_key",
                    identity=ai_key,
                    result=result,
                    rating=outputs.get(_ai_key(ai_key)),
                    ranked=ranked,
                    updated_at=now,
                )
            self._insert_update(cursor, session_id, None, "finished", now)
            self._record_series_round(cursor, session_id, results, now)
        return True

    def create_series(self, *, session_id: str, best_of: int) -> Result:
        if best_of not in (3, 5):
            raise ValueError("best_of must be 3 or 5")
        series_id = str(__import__("uuid").uuid4())
        with self._cursor() as cursor:
            cursor.execute(
                "insert into server_series (series_id, best_of) values (%s, %s)",
                (series_id, best_of),
            )
            cursor.execute(
                """insert into server_series_rounds
                          (series_id, round_number, session_id)
                   values (%s, 1, %s)""",
                (series_id, session_id),
            )
        return self.series_status(session_id=session_id) or {}

    def continue_series(
        self, *, source_session_id: str, session_id: str
    ) -> Result | None:
        with self._cursor() as cursor:
            cursor.execute(
                """select r.series_id, r.round_number, s.completed
                     from server_series_rounds r join server_series s using (series_id)
                    where r.session_id = %s""",
                (source_session_id,),
            )
            row = cursor.fetchone()
            if row is None:
                return None
            if bool(row[2]):
                raise ValueError("series is complete")
            cursor.execute(
                """insert into server_series_rounds
                          (series_id, round_number, session_id)
                   values (%s, %s, %s)""",
                (row[0], int(row[1]) + 1, session_id),
            )
        return self.series_status(session_id=session_id)

    def series_status(self, *, session_id: str) -> Result | None:
        with self._cursor() as cursor:
            cursor.execute(
                """select s.series_id::text, s.best_of, s.completed,
                          s.winner_player_id, current.round_number
                     from server_series_rounds current
                     join server_series s using (series_id)
                    where current.session_id = %s""",
                (session_id,),
            )
            row = cursor.fetchone()
            if row is None:
                return None
            cursor.execute(
                """select winner_player_id, count(*)
                     from server_series_rounds
                    where series_id = %s and completed_at is not null
                      and winner_player_id is not null
                    group by winner_player_id""",
                (row[0],),
            )
            wins = {str(int(value[0])): int(value[1]) for value in cursor.fetchall()}
        return {
            "seriesID": row[0],
            "bestOf": int(row[1]),
            "completed": bool(row[2]),
            "winnerPlayerID": row[3],
            "roundNumber": int(row[4]),
            "wins": wins,
        }

    def _record_series_round(
        self, cursor: object, session_id: str, results: list[Result], now: datetime
    ) -> None:
        winner = next((value for value in results if bool(value.get("won"))), None)
        cursor.execute(
            """update server_series_rounds
                  set winner_player_id = %s, scores = %s, completed_at = %s
                where session_id = %s and completed_at is null
            returning series_id""",
            (
                None if winner is None else int(winner.get("player_id", 0)),
                self._json_value(
                    [
                        {
                            "playerID": int(value.get("player_id", 0)),
                            "score": int(value.get("score", 0)),
                        }
                        for value in results
                    ]
                ),
                now,
                session_id,
            ),
        )
        row = cursor.fetchone()
        if row is None:
            return
        series_id = row[0]
        cursor.execute(
            """select s.best_of, r.winner_player_id, count(*)
                 from server_series s join server_series_rounds r using (series_id)
                where s.series_id = %s and r.completed_at is not null
                  and r.winner_player_id is not null
                group by s.best_of, r.winner_player_id
                order by count(*) desc limit 1""",
            (series_id,),
        )
        standing = cursor.fetchone()
        if standing is None or int(standing[2]) < int(standing[0]) // 2 + 1:
            return
        cursor.execute(
            """update server_series set completed = true, winner_player_id = %s,
                      updated_at = %s where series_id = %s""",
            (int(standing[1]), now, series_id),
        )

    def recent_games(self, *, user_id: str, limit: int = 5) -> list[Result]:
        with self._cursor() as cursor:
            cursor.execute(
                """select session_id::text, player_id, score, rank, won, ranked,
                          extract(epoch from completed_at)
                     from server_game_results
                    where user_id = %s
                    order by completed_at desc
                    limit %s""",
                (user_id, max(1, min(limit, 20))),
            )
            rows = cursor.fetchall()
        return [
            {
                "sessionID": row[0],
                "playerID": int(row[1]),
                "score": int(row[2]),
                "rank": int(row[3]),
                "won": bool(row[4]),
                "ranked": bool(row[5]),
                "completedAt": float(row[6]),
            }
            for row in rows
        ]

    def session_results(self, *, session_id: str, user_id: str) -> list[Result]:
        with self._cursor() as cursor:
            cursor.execute(
                """select r.player_id, r.score, r.rank, r.won, r.ranked,
                          extract(epoch from r.completed_at), r.user_id::text,
                          coalesce(p.display_name, 'Player')
                     from server_game_results r
                     left join public.profiles p on p.user_id = r.user_id
                    where r.session_id = %s
                      and exists (
                        select 1 from server_game_results mine
                         where mine.session_id = r.session_id and mine.user_id = %s
                      )
                    order by r.player_id""",
                (session_id, user_id),
            )
            rows = cursor.fetchall()
        return [
            {
                "playerID": int(row[0]),
                "score": int(row[1]),
                "rank": int(row[2]),
                "won": bool(row[3]),
                "ranked": bool(row[4]),
                "completedAt": float(row[5]),
                "userID": row[6],
                "displayName": row[7],
            }
            for row in rows
        ]

    def claim_daily_attempt(
        self, *, challenge_date: str, user_id: str, session_id: str
    ) -> bool:
        with self._cursor() as cursor:
            self._ensure_human(cursor, user_id, datetime.now(timezone.utc))
            cursor.execute(
                """insert into server_daily_challenge_attempts
                          (challenge_date, user_id, session_id)
                   values (%s::date, %s, %s) on conflict (session_id) do nothing
                returning session_id""",
                (challenge_date, user_id, session_id),
            )
            return cursor.fetchone() is not None

    def daily_challenge(self, *, challenge_date: str, user_id: str) -> Result:
        with self._cursor() as cursor:
            cursor.execute(
                """select a.session_id::text, r.score, r.rank,
                          extract(epoch from r.completed_at)
                     from server_daily_challenge_attempts a
                     left join server_game_results r
                       on r.session_id = a.session_id and r.user_id = a.user_id
                    where a.challenge_date = %s::date and a.user_id = %s
                    order by r.score desc nulls last, r.completed_at asc nulls last
                    limit 1""",
                (challenge_date, user_id),
            )
            mine = cursor.fetchone()
            cursor.execute(
                """select coalesce(p.display_name, 'Player'), max(r.score),
                          min(r.completed_at) filter (
                            where r.score = best.best_score
                          )
                     from server_daily_challenge_attempts a
                     join server_game_results r
                       on r.session_id = a.session_id and r.user_id = a.user_id
                     left join public.profiles p on p.user_id = a.user_id
                     join lateral (
                       select max(r2.score) as best_score
                         from server_daily_challenge_attempts a2
                         join server_game_results r2
                           on r2.session_id = a2.session_id and r2.user_id = a2.user_id
                        where a2.challenge_date = a.challenge_date
                          and a2.user_id = a.user_id
                     ) best on true
                    where a.challenge_date = %s::date
                    group by a.user_id, p.display_name, best.best_score
                    order by max(r.score) desc, min(r.completed_at) asc limit 20""",
                (challenge_date,),
            )
            leaders = cursor.fetchall()
        return {
            "attempt": None
            if mine is None
            else {
                "sessionID": mine[0],
                "score": mine[1],
                "rank": mine[2],
                "completedAt": None if mine[3] is None else float(mine[3]),
            },
            "leaders": [
                {
                    "displayName": row[0],
                    "score": int(row[1]),
                    "completedAt": float(row[2]),
                }
                for row in leaders
            ],
        }

    def _ensure_human(self, cursor: object, user_id: str, now: datetime) -> None:
        cursor.execute(
            """insert into public.profiles (user_id, display_name, updated_at)
               values (%s, 'Player', %s) on conflict (user_id) do nothing""",
            (user_id, now),
        )
        cursor.execute(
            """insert into public.profile_stats (user_id)
               values (%s) on conflict (user_id) do nothing""",
            (user_id,),
        )

    def _record_progression(
        self,
        cursor: object,
        *,
        session_id: str,
        user_id: str,
        result: Result,
        updated_at: datetime,
    ) -> None:
        cursor.execute(
            """select exists(select 1 from server_linked_identities where player_id=%s)
                      or exists(select 1 from server_recovery_emails where player_id=%s)""",
            (user_id, user_id),
        )
        if not bool(cursor.fetchone()[0]):
            return
        cursor.execute(
            """insert into server_progression_events (session_id, user_id)
               values (%s, %s) on conflict (session_id, user_id) do nothing
               returning user_id""",
            (session_id, user_id),
        )
        if cursor.fetchone() is None:
            return
        cursor.execute(
            """select progress, completed, unlocks
                 from public.profile_progression
                where user_id = %s for update""",
            (user_id,),
        )
        row = cursor.fetchone()
        current = None
        if row is not None:
            current = {
                "progress": row[0] or {},
                "completed": row[1] or [],
                "unlocks": row[2] or [],
            }
        progression = evaluate_online_progression(current, result)
        cursor.execute(
            """insert into public.profile_progression
                      (user_id, progress, completed, unlocks, updated_at)
               values (%s, %s, %s, %s, %s)
               on conflict (user_id) do update set
                 progress = excluded.progress, completed = excluded.completed,
                 unlocks = excluded.unlocks, updated_at = excluded.updated_at""",
            (
                user_id,
                self._json_value(progression["progress"]),
                progression["completed"],
                progression["unlocks"],
                updated_at,
            ),
        )

    def _load_ratings(
        self,
        cursor: object,
        human_results: list[Result],
        ai_results: dict[str, Result],
        *,
        casual: bool,
    ) -> dict[str, tuple[float, float]]:
        ratings: dict[str, tuple[float, float]] = {}
        prefix = "casual_" if casual else ""
        user_ids = sorted({_user_id(result) for result in human_results})
        if user_ids:
            cursor.execute(
                f"""select user_id::text, {prefix}rating_mu, {prefix}rating_sigma
                       from public.profile_stats where user_id = any(%s::uuid[])""",
                (user_ids,),
            )
            for user_id, mu, sigma in cursor.fetchall():
                ratings[_user_key(str(user_id))] = (
                    _float(mu, DEFAULT_MU),
                    _float(sigma, DEFAULT_SIGMA),
                )
        ai_keys = sorted(ai_results)
        if ai_keys:
            cursor.execute(
                f"""select ai_key, {prefix}rating_mu, {prefix}rating_sigma
                       from public.ai_profile_stats where ai_key = any(%s::text[])""",
                (ai_keys,),
            )
            for ai_key, mu, sigma in cursor.fetchall():
                ratings[_ai_key(str(ai_key))] = (
                    _float(mu, DEFAULT_MU),
                    _float(sigma, DEFAULT_SIGMA),
                )
        return ratings

    def _update_stats(
        self,
        cursor: object,
        *,
        table: str,
        identity_column: str,
        identity: str,
        result: Result,
        rating: RatingOutput | None,
        ranked: bool,
        updated_at: datetime,
    ) -> None:
        # table/column are internal constants, never transport or user input.
        won = bool(result.get("won"))
        value = rating.display_rating if rating else None
        mu = rating.mu if rating else None
        sigma = rating.sigma if rating else None
        cursor.execute(
            f"""update public.{table}
                   set games_played = games_played + 1,
                       wins_total = wins_total + %s,
                       online_games = online_games + 1,
                       online_wins = online_wins + %s,
                       casual_games = casual_games + %s,
                       casual_wins = casual_wins + %s,
                       ranked_games = ranked_games + %s,
                       ranked_wins = ranked_wins + %s,
                       casual_rating = coalesce(%s, casual_rating),
                       casual_peak_rating = greatest(casual_peak_rating, coalesce(%s, casual_rating)),
                       casual_rating_games = casual_rating_games + %s,
                       casual_rating_mu = coalesce(%s, casual_rating_mu),
                       casual_rating_sigma = coalesce(%s, casual_rating_sigma),
                       casual_rating_version = case when %s then 2 else casual_rating_version end,
                       rating = coalesce(%s, rating),
                       peak_rating = greatest(peak_rating, coalesce(%s, rating)),
                       rating_games = rating_games + %s,
                       rating_mu = coalesce(%s, rating_mu),
                       rating_sigma = coalesce(%s, rating_sigma),
                       rating_version = case when %s then 2 else rating_version end,
                       updated_at = %s
                 where {identity_column} = %s""",
            (
                int(won),
                int(won),
                int(not ranked),
                int(not ranked and won),
                int(ranked),
                int(ranked and won),
                None if ranked else value,
                None if ranked else value,
                int(not ranked),
                None if ranked else mu,
                None if ranked else sigma,
                not ranked,
                value if ranked else None,
                value if ranked else None,
                int(ranked),
                mu if ranked else None,
                sigma if ranked else None,
                ranked,
                updated_at,
                identity,
            ),
        )

    @staticmethod
    def _insert_update(
        cursor: object,
        session_id: str,
        revision: int | None,
        update_type: str,
        created_at: datetime,
    ) -> None:
        cursor.execute(
            """insert into server_session_updates
                      (session_id, revision, kind, created_at)
               values (%s, %s, %s, %s)""",
            (session_id, revision, update_type, created_at),
        )


def aggregate_ai_results(results: list[Result]) -> dict[str, Result]:
    grouped: dict[str, list[Result]] = {}
    for result in results:
        controller = result.get("controller")
        user_id = result.get("user_id")
        if (
            isinstance(controller, str)
            and controller in AI_PROFILES
            and (not isinstance(user_id, str) or not user_id)
        ):
            grouped.setdefault(controller, []).append(result)
    return {
        controller: {
            "controller": controller,
            "score": sum(_float(item.get("score")) for item in items) / len(items),
            "rank": sum(_float(item.get("rank"), 4.0) for item in items) / len(items),
            "won": any(bool(item.get("won")) for item in items),
        }
        for controller, items in grouped.items()
    }


def display_rating(mu: float, sigma: float) -> int:
    value = round(
        1000.0
        + (mu - DEFAULT_MU) * DISPLAY_SCALE
        - (sigma - DEFAULT_SIGMA) * (DISPLAY_SCALE / 4.0)
    )
    return max(DISPLAY_MIN, min(DISPLAY_MAX, value))


def rate_multiplayer(participants: list[RatingInput]) -> dict[str, RatingOutput]:
    if len(participants) < 2:
        return {
            item.key: RatingOutput(
                item.key, item.mu, item.sigma, display_rating(item.mu, item.sigma)
            )
            for item in participants
        }
    deltas = {item.key: 0.0 for item in participants}
    counts = {item.key: 0 for item in participants}
    for index, left in enumerate(participants):
        for right in participants[index + 1 :]:
            actual = (
                1.0
                if left.rank < right.rank
                else 0.0
                if left.rank > right.rank
                else 0.5
            )
            variance = sqrt(
                left.sigma * left.sigma + right.sigma * right.sigma + 2.0 * BETA * BETA
            )
            exponent = max(-30.0, min(30.0, (right.mu - left.mu) / variance))
            expected = 1.0 / (1.0 + exp(exponent))
            uncertainty = sqrt(left.sigma * left.sigma + right.sigma * right.sigma)
            uncertainty /= sqrt(2.0) * DEFAULT_SIGMA
            uncertainty = max(0.65, min(1.5, uncertainty))
            margin_scale = 1.0 + min(0.35, log1p(abs(left.score - right.score)) / 20.0)
            scale = 2.4 * uncertainty * margin_scale
            deltas[left.key] += scale * (actual - expected)
            deltas[right.key] += scale * ((1.0 - actual) - (1.0 - expected))
            counts[left.key] += 1
            counts[right.key] += 1
    outputs = {}
    for item in participants:
        mu = max(1.0, item.mu + deltas[item.key] / max(1, counts[item.key]))
        sigma = max(
            MIN_SIGMA,
            sqrt(item.sigma * item.sigma + TAU * TAU) * 0.985,
        )
        outputs[item.key] = RatingOutput(item.key, mu, sigma, display_rating(mu, sigma))
    return outputs


def rating_inputs(
    human_results: list[Result],
    ai_results: dict[str, Result],
    ratings: dict[str, tuple[float, float]],
) -> list[RatingInput]:
    inputs = []
    for result in human_results:
        user_id = _user_id(result)
        if user_id:
            mu, sigma = ratings.get(_user_key(user_id), (DEFAULT_MU, DEFAULT_SIGMA))
            inputs.append(
                RatingInput(
                    _user_key(user_id),
                    _float(result.get("rank"), 4.0),
                    _float(result.get("score")),
                    mu,
                    sigma,
                )
            )
    for ai_name, result in sorted(ai_results.items()):
        mu, sigma = ratings.get(_ai_key(ai_name), (DEFAULT_MU, DEFAULT_SIGMA))
        inputs.append(
            RatingInput(
                _ai_key(ai_name),
                _float(result.get("rank"), 4.0),
                _float(result.get("score")),
                mu,
                sigma,
            )
        )
    return inputs


def evaluate_online_progression(
    current: Progression | None, result: Result
) -> Progression:
    current = current or {}
    raw = current.get("progress")
    progress = {
        str(key): max(value, 0)
        for key, value in (raw.items() if isinstance(raw, dict) else ())
        if isinstance(value, int)
    }
    completed = {
        value for value in current.get("completed", []) if isinstance(value, str)
    }
    unlocks = {value for value in current.get("unlocks", []) if isinstance(value, str)}

    def add(item: str, amount: int) -> None:
        progress[item] = progress.get(item, 0) + max(amount, 0)

    won = bool(result.get("won"))
    score = _integer(result.get("score"))
    medals = _integer(result.get("medals"))
    for item in ("achievement.first_game", "challenge.games_5", "challenge.games_10"):
        add(item, 1)
    add("challenge.score_500", score)
    add("challenge.score_1000", score)
    add("challenge.medals_25", medals)
    if won:
        add("achievement.first_win", 1)
        add("challenge.wins_5", 1)
        if bool(result.get("full_five_year_game")):
            add("challenge.wins_3", 1)
        if _integer(result.get("margin")) >= 25:
            add("achievement.clear_victory", 1)
    if score >= 100:
        add("achievement.century", 1)
    if medals >= 5:
        add("achievement.medalist", 1)
    if bool(result.get("saboteur_exiled")):
        add("achievement.saboteur_exiled", 1)
    if _integer(result.get("exiled_plot_cards")) == 0:
        add("achievement.no_requisition", 1)
    for item, target in TARGETS.items():
        progress[item] = min(progress.get(item, 0), target)
        if progress[item] >= target:
            completed.add(item)
            reward = UNLOCK_REWARDS.get(item)
            if reward:
                unlocks.add(reward)
    return {
        "progress": progress,
        "completed": sorted(completed),
        "unlocks": sorted(unlocks),
    }


def _user_id(result: Result) -> str | None:
    value = result.get("user_id")
    return value if isinstance(value, str) and value else None


def _user_key(user_id: str) -> str:
    return f"user:{user_id}"


def _ai_key(ai_key: str) -> str:
    return f"ai:{ai_key}"


def _float(value: object, fallback: float = 0.0) -> float:
    return float(value) if isinstance(value, (int, float)) else fallback


def _integer(value: object) -> int:
    return value if isinstance(value, int) else 0


def _timestamp(value: float) -> datetime:
    return datetime.fromtimestamp(value, tz=timezone.utc)
