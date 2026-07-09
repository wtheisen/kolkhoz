from __future__ import annotations

import hashlib
import threading
from datetime import UTC, datetime
from typing import Any

from .ratings import DEFAULT_MU, DEFAULT_SIGMA, RatingInput, rate_multiplayer


AI_PROFILES = {
    "heuristicAI": "Easy AI",
    "mediumAI": "Medium AI",
    "neuralAI": "Hard AI",
}
BAN_STRIKES = 3


def seat_token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class OnlineSessionStore:
    def close(self) -> None:
        pass

    def create_session(
        self,
        *,
        session_id: str,
        seed: int,
        variants: dict[str, object],
        controllers: list[str],
        occupied_seats: set[int],
        seat_tokens: dict[int, str],
        seat_user_ids: dict[int, str],
        action_log_count: int,
        created_at: float,
        expires_at: float,
        policy_model_sha: str | None,
        created_by_user_id: str | None,
    ) -> None:
        pass

    def join_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        seat_token: str,
        user_id: str | None,
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def append_action(
        self,
        *,
        session_id: str,
        revision: int,
        player_id: int,
        action: dict[str, object],
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def touch_session(
        self,
        *,
        session_id: str,
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def update_turn_state(
        self,
        *,
        session_id: str,
        turn_player_id: int | None,
        turn_deadline_at: float | None,
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def touch_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def record_seat_timeout(
        self,
        *,
        session_id: str,
        player_id: int,
        timeouts: int,
        autopilot: bool,
        updated_at: float,
        expires_at: float,
        revision: int,
    ) -> None:
        pass

    def online_ban_for_user(
        self,
        *,
        user_id: str,
        checked_at: float,
    ) -> dict[str, object] | None:
        return None

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
        return None

    def abandon_active_sessions(self, *, updated_at: float) -> None:
        pass

    def finish_session(
        self,
        *,
        session_id: str,
        results: list[dict[str, object]],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> None:
        pass

    def profiles_for_user_ids(
        self,
        user_ids: list[str],
    ) -> dict[str, dict[str, object]]:
        return {}

    def profiles_for_ai_controllers(
        self,
        controllers: list[str],
    ) -> dict[str, dict[str, object]]:
        return {}

    def ensure_comrade_code(
        self,
        *,
        user_id: str,
        display_name: str,
        updated_at: float,
    ) -> str:
        return _fallback_comrade_code(user_id)

    def comrades_for_user(
        self,
        *,
        user_id: str,
    ) -> dict[str, object]:
        return {
            "user_id": user_id,
            "comrade_code": _fallback_comrade_code(user_id),
            "comrades": [],
            "incoming_requests": [],
            "outgoing_requests": [],
        }

    def send_comrade_request_by_code(
        self,
        *,
        user_id: str,
        comrade_code: str,
        updated_at: float,
    ) -> dict[str, object]:
        raise ValueError("comrade profiles are not configured")

    def send_comrade_request_to_user(
        self,
        *,
        user_id: str,
        comrade_user_id: str,
        updated_at: float,
    ) -> dict[str, object]:
        raise ValueError("comrade profiles are not configured")

    def respond_to_comrade_request(
        self,
        *,
        user_id: str,
        requester_user_id: str,
        accept: bool,
        updated_at: float,
    ) -> dict[str, object] | None:
        raise ValueError("comrade profiles are not configured")

    def remove_comrade(
        self,
        *,
        user_id: str,
        comrade_user_id: str,
    ) -> None:
        pass


class PostgresOnlineSessionStore(OnlineSessionStore):
    def __init__(self, database_url: str) -> None:
        try:
            import psycopg
            from psycopg.types.json import Jsonb
        except ImportError as error:
            raise RuntimeError(
                "Postgres online persistence requires psycopg. "
                "Install psycopg or run serve-online without --database-url."
            ) from error

        self._psycopg = psycopg
        self._jsonb = Jsonb
        self._connection = psycopg.connect(database_url, autocommit=True)
        self._lock = threading.RLock()

    def close(self) -> None:
        with self._lock:
            self._connection.close()

    def create_session(
        self,
        *,
        session_id: str,
        seed: int,
        variants: dict[str, object],
        controllers: list[str],
        occupied_seats: set[int],
        seat_tokens: dict[int, str],
        seat_user_ids: dict[int, str],
        action_log_count: int,
        created_at: float,
        expires_at: float,
        policy_model_sha: str | None,
        created_by_user_id: str | None,
    ) -> None:
        now = _pg_timestamp(created_at)
        expires = _pg_timestamp(expires_at)
        status = (
            "open"
            if any(
                controller == "human" and player_id not in occupied_seats
                for player_id, controller in enumerate(controllers)
            )
            else "active"
        )
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                insert into public.game_sessions (
                    session_id,
                    seed,
                    variants,
                    controllers,
                    status,
                    action_log_count,
                    created_at,
                    updated_at,
                    expires_at,
                    policy_model_sha,
                    created_by
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    session_id,
                    seed,
                    self._jsonb(variants),
                    controllers,
                    status,
                    action_log_count,
                    now,
                    now,
                    expires,
                    policy_model_sha,
                    created_by_user_id,
                ),
            )
            for player_id in range(len(controllers)):
                token = seat_tokens.get(player_id)
                user_id = seat_user_ids.get(player_id)
                cursor.execute(
                    """
                    insert into public.game_seats (
                        session_id,
                        player_id,
                        controller,
                        occupied,
                        user_id,
                        seat_token_hash,
                        joined_at,
                        last_seen_at
                    )
                    values (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        session_id,
                        player_id,
                        controllers[player_id],
                        player_id in occupied_seats,
                        user_id,
                        seat_token_hash(token) if token is not None else None,
                        now if player_id in occupied_seats else None,
                        now if player_id in occupied_seats else None,
                    ),
                )
            self._insert_update(cursor, session_id, action_log_count, "created", now)

    def join_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        seat_token: str,
        user_id: str | None,
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_seats
                   set occupied = true,
                       user_id = %s,
                       seat_token_hash = %s,
                       joined_at = %s,
                       last_seen_at = %s,
                       disconnected_at = null,
                       autopilot = false
                 where session_id = %s and player_id = %s
                """,
                (
                    user_id,
                    seat_token_hash(seat_token),
                    now,
                    now,
                    session_id,
                    player_id,
                ),
            )
            self._touch_session(cursor, session_id, now, expires_at)
            cursor.execute(
                """
                update public.game_sessions
                   set status = case
                       when exists (
                           select 1
                             from public.game_seats
                            where game_seats.session_id = game_sessions.session_id
                              and game_seats.controller = 'human'
                              and not game_seats.occupied
                       ) then 'open'
                       else 'active'
                   end
                 where session_id = %s
                """,
                (session_id,),
            )
            self._insert_update(cursor, session_id, None, "seat_joined", now)

    def append_action(
        self,
        *,
        session_id: str,
        revision: int,
        player_id: int,
        action: dict[str, object],
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                insert into public.game_actions (
                    session_id,
                    revision,
                    player_id,
                    action,
                    created_at
                )
                values (%s, %s, %s, %s, %s)
                """,
                (session_id, revision, player_id, self._jsonb(action), now),
            )
            cursor.execute(
                """
                update public.game_sessions
                   set action_log_count = %s,
                       updated_at = %s,
                       expires_at = %s
                 where session_id = %s
                """,
                (revision, now, _pg_timestamp(expires_at), session_id),
            )
            self._insert_update(cursor, session_id, revision, "action", now)

    def touch_session(
        self,
        *,
        session_id: str,
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            self._touch_session(cursor, session_id, now, expires_at)

    def update_turn_state(
        self,
        *,
        session_id: str,
        turn_player_id: int | None,
        turn_deadline_at: float | None,
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        deadline = (
            _pg_timestamp(turn_deadline_at)
            if turn_deadline_at is not None
            else None
        )
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_sessions
                   set turn_player_id = %s,
                       turn_deadline_at = %s,
                       updated_at = %s,
                       expires_at = %s
                 where session_id = %s
                """,
                (turn_player_id, deadline, now, _pg_timestamp(expires_at), session_id),
            )

    def touch_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_seats
                   set last_seen_at = %s,
                       disconnected_at = null,
                       autopilot = false
                 where session_id = %s and player_id = %s
                """,
                (now, session_id, player_id),
            )
            self._touch_session(cursor, session_id, now, expires_at)

    def record_seat_timeout(
        self,
        *,
        session_id: str,
        player_id: int,
        timeouts: int,
        autopilot: bool,
        updated_at: float,
        expires_at: float,
        revision: int,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_seats
                   set timeouts = %s,
                       autopilot = %s,
                       disconnected_at = coalesce(disconnected_at, %s)
                 where session_id = %s and player_id = %s
                """,
                (timeouts, autopilot, now, session_id, player_id),
            )
            self._touch_session(cursor, session_id, now, expires_at)
            self._insert_update(
                cursor,
                session_id,
                revision,
                "autopilot" if autopilot else "timeout",
                now,
            )

    def online_ban_for_user(
        self,
        *,
        user_id: str,
        checked_at: float,
    ) -> dict[str, object] | None:
        now = _pg_timestamp(checked_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                select online_abandon_strikes, online_banned_until
                  from public.profile_stats
                 where user_id = %s
                """,
                (user_id,),
            )
            row = cursor.fetchone()
            if row is None or row[1] is None or row[1] <= now:
                return None
            return {
                "strikes": row[0],
                "banned_until": row[1].timestamp(),
            }

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
        now = _pg_timestamp(updated_at)
        penalty: dict[str, object] | None = None
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_seats
                   set abandoned = true,
                       autopilot = true,
                       disconnected_at = coalesce(disconnected_at, %s)
                 where session_id = %s and player_id = %s
                """,
                (now, session_id, player_id),
            )
            if isinstance(user_id, str) and user_id:
                cursor.execute(
                    """
                    insert into public.profiles (user_id, display_name, updated_at)
                    values (%s, 'Player', %s)
                    on conflict (user_id) do nothing
                    """,
                    (user_id, now),
                )
                cursor.execute(
                    """
                    insert into public.profile_stats (user_id)
                    values (%s)
                    on conflict (user_id) do nothing
                    """,
                    (user_id,),
                )
                cursor.execute(
                    """
                    update public.profile_stats
                       set online_abandon_strikes = online_abandon_strikes + 1,
                           online_banned_until = case
                               when online_abandon_strikes + 1 >= %s
                               then %s + interval '3 days'
                               else online_banned_until
                           end,
                           updated_at = %s
                     where user_id = %s
                 returning online_abandon_strikes, online_banned_until
                    """,
                    (BAN_STRIKES, now, now, user_id),
                )
                row = cursor.fetchone()
                if row is not None:
                    penalty = {
                        "strikes": row[0],
                        "banned_until": row[1].timestamp() if row[1] is not None else None,
                    }
            self._touch_session(cursor, session_id, now, expires_at)
            self._insert_update(cursor, session_id, revision, "abandoned", now)
        return penalty

    def abandon_active_sessions(self, *, updated_at: float) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_sessions
                   set status = 'abandoned',
                       updated_at = %s
                 where status in ('open', 'active')
                """,
                (now,),
            )

    def finish_session(
        self,
        *,
        session_id: str,
        results: list[dict[str, object]],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                update public.game_sessions
                   set status = 'finished',
                       updated_at = %s,
                       expires_at = %s
                 where session_id = %s
                """,
                (now, _pg_timestamp(expires_at), session_id),
            )
            human_results = [
                result
                for result in results
                if isinstance(result.get("user_id"), str) and result.get("user_id")
            ]
            for result in results:
                user_id = result.get("user_id")
                if not isinstance(user_id, str) or not user_id:
                    continue
                cursor.execute(
                    """
                    insert into public.profiles (user_id, display_name, updated_at)
                    values (%s, 'Player', %s)
                    on conflict (user_id) do nothing
                    """,
                    (user_id, now),
                )
                cursor.execute(
                    """
                    insert into public.profile_stats (user_id)
                    values (%s)
                    on conflict (user_id) do nothing
                    """,
                    (user_id,),
                )
            ai_results = _aggregate_ai_results(results)
            for ai_key in ai_results:
                cursor.execute(
                    """
                    insert into public.ai_profile_stats (ai_key, display_name)
                    values (%s, %s)
                    on conflict (ai_key) do update
                       set display_name = excluded.display_name
                    """,
                    (ai_key, AI_PROFILES[ai_key]),
                )
            if ranked:
                ratings = _load_ratings(cursor, human_results, ai_results)
                rating_inputs = _rating_inputs(human_results, ai_results, ratings)
                rating_outputs = rate_multiplayer(rating_inputs)
            else:
                ratings = {}
                rating_outputs = {}
            for result in human_results:
                user_id = str(result["user_id"])
                won = bool(result.get("won"))
                key = _user_rating_key(user_id)
                output = rating_outputs.get(key)
                if not ranked:
                    mu = None
                    sigma = None
                    rating = None
                elif output is None:
                    mu, sigma = ratings.get(key, (DEFAULT_MU, DEFAULT_SIGMA))
                    rating = None
                else:
                    mu = output.mu
                    sigma = output.sigma
                    rating = output.display_rating
                cursor.execute(
                    """
                    update public.profile_stats
                       set games_played = games_played + 1,
                           wins_total = wins_total + %s,
                           online_games = online_games + 1,
                           online_wins = online_wins + %s,
                           rating = coalesce(%s, rating),
                           peak_rating = greatest(peak_rating, coalesce(%s, rating)),
                           rating_games = rating_games + %s,
                           rating_mu = coalesce(%s, rating_mu),
                           rating_sigma = coalesce(%s, rating_sigma),
                           rating_version = case when %s then 2 else rating_version end,
                           updated_at = %s
                     where user_id = %s
                    """,
                    (
                        1 if won else 0,
                        1 if won else 0,
                        rating,
                        rating,
                        1 if ranked else 0,
                        mu,
                        sigma,
                        ranked,
                        now,
                        user_id,
                    ),
                )
            for ai_key, result in ai_results.items():
                won = bool(result.get("won"))
                output = rating_outputs.get(_ai_rating_key(ai_key))
                if not ranked:
                    mu = None
                    sigma = None
                    rating = None
                elif output is None:
                    mu, sigma = ratings.get(
                        _ai_rating_key(ai_key),
                        (DEFAULT_MU, DEFAULT_SIGMA),
                    )
                    rating = None
                else:
                    mu = output.mu
                    sigma = output.sigma
                    rating = output.display_rating
                cursor.execute(
                    """
                    update public.ai_profile_stats
                       set games_played = games_played + 1,
                           wins_total = wins_total + %s,
                           online_games = online_games + 1,
                           online_wins = online_wins + %s,
                           rating = coalesce(%s, rating),
                           peak_rating = greatest(peak_rating, coalesce(%s, rating)),
                           rating_games = rating_games + %s,
                           rating_mu = coalesce(%s, rating_mu),
                           rating_sigma = coalesce(%s, rating_sigma),
                           rating_version = case when %s then 2 else rating_version end,
                           updated_at = %s
                     where ai_key = %s
                    """,
                    (
                        1 if won else 0,
                        1 if won else 0,
                        rating,
                        rating,
                        1 if ranked else 0,
                        mu,
                        sigma,
                        ranked,
                        now,
                        ai_key,
                    ),
                )
            self._insert_update(cursor, session_id, None, "finished", now)

    def profiles_for_user_ids(
        self,
        user_ids: list[str],
    ) -> dict[str, dict[str, object]]:
        if not user_ids:
            return {}
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                select
                    profiles.user_id::text,
                    profiles.display_name,
                    profiles.avatar_url,
                    profile_stats.games_played,
                    profile_stats.wins_total,
                    profile_stats.offline_games,
                    profile_stats.offline_wins,
                    profile_stats.online_games,
                    profile_stats.online_wins,
                    profile_stats.rating,
                    profile_stats.peak_rating,
                    profile_stats.rating_games
                  from public.profiles
                  left join public.profile_stats
                    on profile_stats.user_id = profiles.user_id
                 where profiles.user_id = any(%s::uuid[])
                """,
                (user_ids,),
            )
            profiles: dict[str, dict[str, object]] = {}
            for row in cursor.fetchall():
                user_id = row[0]
                profiles[user_id] = {
                    "display_name": row[1],
                    "avatar_url": row[2],
                    "stats": {
                        "games_played": row[3] or 0,
                        "wins_total": row[4] or 0,
                        "offline_games": row[5] or 0,
                        "offline_wins": row[6] or 0,
                        "online_games": row[7] or 0,
                        "online_wins": row[8] or 0,
                        "rating": row[9] or 1000,
                        "peak_rating": row[10] or 1000,
                        "rating_games": row[11] or 0,
                    },
                }
            return profiles

    def profiles_for_ai_controllers(
        self,
        controllers: list[str],
    ) -> dict[str, dict[str, object]]:
        ai_keys = sorted(
            {controller for controller in controllers if controller in AI_PROFILES}
        )
        if not ai_keys:
            return {}
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                select
                    ai_key,
                    display_name,
                    games_played,
                    wins_total,
                    online_games,
                    online_wins,
                    rating,
                    peak_rating,
                    rating_games
                  from public.ai_profile_stats
                 where ai_key = any(%s::text[])
                """,
                (ai_keys,),
            )
            profiles: dict[str, dict[str, object]] = {}
            for row in cursor.fetchall():
                profiles[row[0]] = {
                    "display_name": row[1],
                    "avatar_url": None,
                    "stats": {
                        "games_played": row[2] or 0,
                        "wins_total": row[3] or 0,
                        "offline_games": 0,
                        "offline_wins": 0,
                        "online_games": row[4] or 0,
                        "online_wins": row[5] or 0,
                        "rating": row[6] or 1000,
                        "peak_rating": row[7] or 1000,
                        "rating_games": row[8] or 0,
                    },
                }
            return profiles

    def ensure_comrade_code(
        self,
        *,
        user_id: str,
        display_name: str,
        updated_at: float,
    ) -> str:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                insert into public.profiles (
                    user_id,
                    display_name,
                    comrade_code,
                    updated_at
                )
                values (%s, %s, %s, %s)
                on conflict (user_id) do update
                   set display_name = coalesce(nullif(public.profiles.display_name, ''), excluded.display_name),
                       comrade_code = coalesce(public.profiles.comrade_code, excluded.comrade_code),
                       updated_at = greatest(public.profiles.updated_at, excluded.updated_at)
                returning comrade_code
                """,
                (user_id, display_name, _fallback_comrade_code(user_id), now),
            )
            row = cursor.fetchone()
            return str(row[0])

    def comrades_for_user(
        self,
        *,
        user_id: str,
    ) -> dict[str, object]:
        with self._lock, self._connection.cursor() as cursor:
            code = self._comrade_code_for_user(cursor, user_id)
            cursor.execute(
                """
                select
                    profiles.user_id::text,
                    profiles.display_name,
                    profiles.avatar_url,
                    profiles.comrade_code,
                    profile_stats.games_played,
                    profile_stats.wins_total,
                    profile_stats.offline_games,
                    profile_stats.offline_wins,
                    profile_stats.online_games,
                    profile_stats.online_wins,
                    profile_stats.rating,
                    profile_stats.peak_rating,
                    profile_stats.rating_games
                  from public.user_comrades
                  join public.profiles
                    on profiles.user_id = user_comrades.comrade_user_id
                  left join public.profile_stats
                    on profile_stats.user_id = profiles.user_id
                 where user_comrades.user_id = %s
                 order by lower(profiles.display_name), profiles.comrade_code
                """,
                (user_id,),
            )
            comrades = [self._comrade_profile_json(row) for row in cursor.fetchall()]
            cursor.execute(
                """
                select
                    profiles.user_id::text,
                    profiles.display_name,
                    profiles.avatar_url,
                    profiles.comrade_code,
                    profile_stats.games_played,
                    profile_stats.wins_total,
                    profile_stats.offline_games,
                    profile_stats.offline_wins,
                    profile_stats.online_games,
                    profile_stats.online_wins,
                    profile_stats.rating,
                    profile_stats.peak_rating,
                    profile_stats.rating_games,
                    user_comrade_requests.created_at
                  from public.user_comrade_requests
                  join public.profiles
                    on profiles.user_id = user_comrade_requests.requester_user_id
                  left join public.profile_stats
                    on profile_stats.user_id = profiles.user_id
                 where user_comrade_requests.addressee_user_id = %s
                 order by user_comrade_requests.created_at desc
                """,
                (user_id,),
            )
            incoming = [
                self._comrade_profile_json(row, requested_at_index=13)
                for row in cursor.fetchall()
            ]
            cursor.execute(
                """
                select
                    profiles.user_id::text,
                    profiles.display_name,
                    profiles.avatar_url,
                    profiles.comrade_code,
                    profile_stats.games_played,
                    profile_stats.wins_total,
                    profile_stats.offline_games,
                    profile_stats.offline_wins,
                    profile_stats.online_games,
                    profile_stats.online_wins,
                    profile_stats.rating,
                    profile_stats.peak_rating,
                    profile_stats.rating_games,
                    user_comrade_requests.created_at
                  from public.user_comrade_requests
                  join public.profiles
                    on profiles.user_id = user_comrade_requests.addressee_user_id
                  left join public.profile_stats
                    on profile_stats.user_id = profiles.user_id
                 where user_comrade_requests.requester_user_id = %s
                 order by user_comrade_requests.created_at desc
                """,
                (user_id,),
            )
            outgoing = [
                self._comrade_profile_json(row, requested_at_index=13)
                for row in cursor.fetchall()
            ]
            return {
                "user_id": user_id,
                "comrade_code": code,
                "comrades": comrades,
                "incoming_requests": incoming,
                "outgoing_requests": outgoing,
            }

    def send_comrade_request_by_code(
        self,
        *,
        user_id: str,
        comrade_code: str,
        updated_at: float,
    ) -> dict[str, object]:
        normalized = _normalize_comrade_code(comrade_code)
        if not normalized:
            raise ValueError("missing comrade code")
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            self._comrade_code_for_user(cursor, user_id)
            cursor.execute(
                """
                select user_id::text
                  from public.profiles
                 where upper(comrade_code) = %s
                """,
                (normalized,),
            )
            row = cursor.fetchone()
            if row is None:
                raise ValueError("comrade code not found")
            comrade_user_id = str(row[0])
            return self._send_comrade_request_to_user(
                cursor,
                user_id,
                comrade_user_id,
                now,
            )

    def send_comrade_request_to_user(
        self,
        *,
        user_id: str,
        comrade_user_id: str,
        updated_at: float,
    ) -> dict[str, object]:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            self._comrade_code_for_user(cursor, user_id)
            return self._send_comrade_request_to_user(
                cursor,
                user_id,
                comrade_user_id,
                now,
            )

    def _send_comrade_request_to_user(
        self,
        cursor: Any,
        user_id: str,
        comrade_user_id: str,
        now: datetime,
    ) -> dict[str, object]:
        if not comrade_user_id:
            raise ValueError("missing userID")
        if comrade_user_id == user_id:
            raise ValueError("cannot add yourself as a comrade")
        self._profile_for_user(cursor, comrade_user_id)
        cursor.execute(
            """
            select 1
              from public.user_comrades
             where user_id = %s and comrade_user_id = %s
            """,
            (user_id, comrade_user_id),
        )
        if cursor.fetchone() is not None:
            raise ValueError("already comrades")
        cursor.execute(
            """
            delete from public.user_comrade_requests
             where requester_user_id = %s and addressee_user_id = %s
         returning requester_user_id
            """,
            (comrade_user_id, user_id),
        )
        if cursor.fetchone() is not None:
            self._insert_comrade_link(cursor, user_id, comrade_user_id, now)
            self._insert_comrade_link(cursor, comrade_user_id, user_id, now)
            profile = self._profile_for_user(cursor, comrade_user_id)
            profile["accepted"] = True
            return profile
        cursor.execute(
            """
            insert into public.user_comrade_requests (
                requester_user_id,
                addressee_user_id,
                created_at
            )
            values (%s, %s, %s)
            on conflict (requester_user_id, addressee_user_id)
            do update set created_at = excluded.created_at
            """,
            (user_id, comrade_user_id, now),
        )
        profile = self._profile_for_user(cursor, comrade_user_id)
        profile["accepted"] = False
        return profile

    def respond_to_comrade_request(
        self,
        *,
        user_id: str,
        requester_user_id: str,
        accept: bool,
        updated_at: float,
    ) -> dict[str, object] | None:
        now = _pg_timestamp(updated_at)
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                delete from public.user_comrade_requests
                 where requester_user_id = %s and addressee_user_id = %s
             returning requester_user_id
                """,
                (requester_user_id, user_id),
            )
            if cursor.fetchone() is None:
                raise ValueError("comrade request not found")
            if not accept:
                return None
            self._insert_comrade_link(cursor, user_id, requester_user_id, now)
            self._insert_comrade_link(cursor, requester_user_id, user_id, now)
            return self._profile_for_user(cursor, requester_user_id)

    def remove_comrade(
        self,
        *,
        user_id: str,
        comrade_user_id: str,
    ) -> None:
        with self._lock, self._connection.cursor() as cursor:
            cursor.execute(
                """
                delete from public.user_comrades
                 where (user_id = %s and comrade_user_id = %s)
                    or (user_id = %s and comrade_user_id = %s)
                """,
                (user_id, comrade_user_id, comrade_user_id, user_id),
            )
            cursor.execute(
                """
                delete from public.user_comrade_requests
                 where (requester_user_id = %s and addressee_user_id = %s)
                    or (requester_user_id = %s and addressee_user_id = %s)
                """,
                (user_id, comrade_user_id, comrade_user_id, user_id),
            )

    @staticmethod
    def _insert_comrade_link(
        cursor: Any,
        user_id: str,
        comrade_user_id: str,
        created_at: datetime,
    ) -> None:
        cursor.execute(
            """
            insert into public.user_comrades (
                user_id,
                comrade_user_id,
                created_at
            )
            values (%s, %s, %s)
            on conflict (user_id, comrade_user_id) do nothing
            """,
            (user_id, comrade_user_id, created_at),
        )

    def _comrade_code_for_user(self, cursor: Any, user_id: str) -> str:
        cursor.execute(
            """
            select comrade_code
              from public.profiles
             where user_id = %s
            """,
            (user_id,),
        )
        row = cursor.fetchone()
        if row is not None and isinstance(row[0], str) and row[0]:
            return row[0]
        code = _fallback_comrade_code(user_id)
        cursor.execute(
            """
            insert into public.profiles (user_id, display_name, comrade_code)
            values (%s, 'Player', %s)
            on conflict (user_id) do update
               set comrade_code = coalesce(public.profiles.comrade_code, excluded.comrade_code)
            returning comrade_code
            """,
            (user_id, code),
        )
        row = cursor.fetchone()
        return str(row[0])

    def _profile_for_user(self, cursor: Any, user_id: str) -> dict[str, object]:
        cursor.execute(
            """
            select
                profiles.user_id::text,
                profiles.display_name,
                profiles.avatar_url,
                profiles.comrade_code,
                profile_stats.games_played,
                profile_stats.wins_total,
                profile_stats.offline_games,
                profile_stats.offline_wins,
                profile_stats.online_games,
                profile_stats.online_wins,
                profile_stats.rating,
                profile_stats.peak_rating,
                profile_stats.rating_games
              from public.profiles
              left join public.profile_stats
                on profile_stats.user_id = profiles.user_id
             where profiles.user_id = %s
            """,
            (user_id,),
        )
        row = cursor.fetchone()
        if row is None:
            raise ValueError("comrade profile not found")
        return self._comrade_profile_json(row)

    @staticmethod
    def _comrade_profile_json(
        row: object,
        *,
        requested_at_index: int | None = None,
    ) -> dict[str, object]:
        profile = {
            "userID": row[0],
            "displayName": row[1],
            "avatarURL": row[2],
            "comradeCode": row[3],
            "stats": {
                "games_played": row[4] or 0,
                "wins_total": row[5] or 0,
                "offline_games": row[6] or 0,
                "offline_wins": row[7] or 0,
                "online_games": row[8] or 0,
                "online_wins": row[9] or 0,
                "rating": row[10] or 1000,
                "peak_rating": row[11] or 1000,
                "rating_games": row[12] or 0,
            },
        }
        if requested_at_index is not None and row[requested_at_index] is not None:
            profile["requestedAt"] = row[requested_at_index].timestamp()
        return profile

    def _touch_session(
        self,
        cursor: Any,
        session_id: str,
        updated_at: object,
        expires_at: float,
    ) -> None:
        cursor.execute(
            """
            update public.game_sessions
               set updated_at = %s,
                   expires_at = %s
             where session_id = %s
            """,
            (updated_at, _pg_timestamp(expires_at), session_id),
        )

    def _insert_update(
        self,
        cursor: Any,
        session_id: str,
        revision: int | None,
        event_type: str,
        created_at: object,
    ) -> None:
        cursor.execute(
            """
            insert into public.game_updates (
                session_id,
                revision,
                event_type,
                payload,
                created_at
            )
            values (%s, %s, %s, %s, %s)
            """,
            (
                session_id,
                revision,
                event_type,
                self._jsonb({"sessionID": session_id, "revision": revision}),
                created_at,
            ),
        )


def _pg_timestamp(seconds: float) -> datetime:
    return datetime.fromtimestamp(seconds, tz=UTC)


def _fallback_comrade_code(user_id: str) -> str:
    digest = hashlib.sha256(user_id.encode("utf-8")).hexdigest().upper()
    return digest[:5]


def _normalize_comrade_code(value: object) -> str:
    return "".join(character for character in str(value).upper() if character.isalnum())


def _aggregate_ai_results(
    results: list[dict[str, object]],
) -> dict[str, dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for result in results:
        controller = result.get("controller")
        if isinstance(controller, str) and controller in AI_PROFILES:
            grouped.setdefault(controller, []).append(result)
    aggregated: dict[str, dict[str, object]] = {}
    for controller, items in grouped.items():
        aggregated[controller] = {
            "controller": controller,
            "score": sum(_float_value(item.get("score")) for item in items)
            / len(items),
            "rank": sum(_float_value(item.get("rank"), fallback=4.0) for item in items)
            / len(items),
            "won": any(bool(item.get("won")) for item in items),
        }
    return aggregated


def _load_ratings(
    cursor: Any,
    human_results: list[dict[str, object]],
    ai_results: dict[str, dict[str, object]],
) -> dict[str, tuple[float, float]]:
    ratings: dict[str, tuple[float, float]] = {}
    user_ids = sorted(
        {
            str(result["user_id"])
            for result in human_results
            if isinstance(result.get("user_id"), str)
        }
    )
    if user_ids:
        cursor.execute(
            """
            select user_id::text, rating_mu, rating_sigma
              from public.profile_stats
             where user_id = any(%s::uuid[])
            """,
            (user_ids,),
        )
        for row in cursor.fetchall():
            ratings[_user_rating_key(row[0])] = (
                _float_value(row[1], fallback=DEFAULT_MU),
                _float_value(row[2], fallback=DEFAULT_SIGMA),
            )
    ai_keys = sorted(ai_results)
    if ai_keys:
        cursor.execute(
            """
            select ai_key, rating_mu, rating_sigma
              from public.ai_profile_stats
             where ai_key = any(%s::text[])
            """,
            (ai_keys,),
        )
        for row in cursor.fetchall():
            ratings[_ai_rating_key(row[0])] = (
                _float_value(row[1], fallback=DEFAULT_MU),
                _float_value(row[2], fallback=DEFAULT_SIGMA),
            )
    return ratings


def _rating_inputs(
    human_results: list[dict[str, object]],
    ai_results: dict[str, dict[str, object]],
    ratings: dict[str, tuple[float, float]],
) -> list[RatingInput]:
    inputs: list[RatingInput] = []
    for result in human_results:
        user_id = result.get("user_id")
        if not isinstance(user_id, str) or not user_id:
            continue
        key = _user_rating_key(user_id)
        mu, sigma = ratings.get(key, (DEFAULT_MU, DEFAULT_SIGMA))
        inputs.append(
            RatingInput(
                key=key,
                rank=_float_value(result.get("rank"), fallback=4.0),
                score=_float_value(result.get("score")),
                mu=mu,
                sigma=sigma,
            )
        )
    for ai_key, result in sorted(ai_results.items()):
        key = _ai_rating_key(ai_key)
        mu, sigma = ratings.get(key, (DEFAULT_MU, DEFAULT_SIGMA))
        inputs.append(
            RatingInput(
                key=key,
                rank=_float_value(result.get("rank"), fallback=4.0),
                score=_float_value(result.get("score")),
                mu=mu,
                sigma=sigma,
            )
        )
    return inputs


def _user_rating_key(user_id: str) -> str:
    return f"user:{user_id}"


def _ai_rating_key(ai_key: str) -> str:
    return f"ai:{ai_key}"


def _float_value(value: object, *, fallback: float = 0.0) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return fallback
