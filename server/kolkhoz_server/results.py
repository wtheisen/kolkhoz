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
    def finish_session(
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

    def abandon_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        user_id: str | None,
        updated_at: float,
        expires_at: float,
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
            self._json_value = json_value or (lambda value: value)
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

    def abandon_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        user_id: str | None,
        updated_at: float,
        expires_at: float,
        revision: int,
    ) -> dict[str, object] | None:
        now = _timestamp(updated_at)
        penalty = None
        with self._cursor() as cursor:
            cursor.execute(
                """update server_seats
                      set abandoned = true, autopilot = true,
                          timeouts = greatest(timeouts, 2),
                          last_seen_at = %s
                    where session_id = %s and player_id = %s""",
                (now, session_id, player_id),
            )
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
            cursor.execute(
                """update server_sessions
                      set updated_at = %s, expires_at = %s
                    where session_id = %s""",
                (now, _timestamp(expires_at), session_id),
            )
            self._insert_update(cursor, session_id, revision, "abandoned", now)
        return penalty

    def finish_session(
        self,
        *,
        session_id: str,
        results: list[Result],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> bool:
        """Persist a complete result exactly once; return False for a retry."""
        now = _timestamp(updated_at)
        with self._cursor() as cursor:
            cursor.execute(
                """update server_sessions
                      set status = 'finished', updated_at = %s, expires_at = %s
                    where session_id = %s and status <> 'finished'
                returning session_id""",
                (now, _timestamp(expires_at), session_id),
            )
            if cursor.fetchone() is None:
                return False

            human_results = [result for result in results if _user_id(result)]
            for result in human_results:
                user_id = _user_id(result)
                assert user_id is not None
                self._ensure_human(cursor, user_id, now)
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
        return True

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
