from __future__ import annotations

import hashlib
import re
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Callable, Iterator, Protocol

from .store import ConnectionPool


Profile = dict[str, object]


class SocialRepository(Protocol):
    """Durable social data boundary; implementations own their transactions."""

    def ensure_comrade_code(
        self, *, user_id: str, display_name: str, updated_at: float
    ) -> str: ...

    def leaderboard(self, *, limit: int = 100) -> list[Profile]: ...

    def public_profile(self, *, user_id: str) -> Profile: ...

    def comrades_for_user(self, *, user_id: str) -> dict[str, object]: ...

    def send_comrade_request_by_code(
        self, *, user_id: str, comrade_code: str, updated_at: float
    ) -> Profile: ...

    def send_comrade_request_to_user(
        self, *, user_id: str, comrade_user_id: str, updated_at: float
    ) -> Profile: ...

    def respond_to_comrade_request(
        self,
        *,
        user_id: str,
        requester_user_id: str,
        accept: bool,
        updated_at: float,
    ) -> Profile | None: ...

    def remove_comrade(self, *, user_id: str, comrade_user_id: str) -> None: ...


class PresenceReader(Protocol):
    def statuses(self, user_ids: set[str]) -> dict[str, dict[str, bool]]: ...


class NullPresenceReader:
    def statuses(self, user_ids: set[str]) -> dict[str, dict[str, bool]]:
        return {}


class SocialService:
    """Transport-neutral API contract used by HTTP and realtime gateways."""

    def __init__(
        self,
        repository: SocialRepository,
        *,
        presence: PresenceReader | None = None,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.repository = repository
        self.presence = presence or NullPresenceReader()
        self.clock = clock

    def leaderboard(self) -> dict[str, object]:
        return {
            "players": [
                _public_profile_response(profile, rank=rank)
                for rank, profile in enumerate(self.repository.leaderboard(), start=1)
            ]
        }

    def public_profile(self, user_id: str) -> dict[str, object]:
        return _public_profile_response(
            self.repository.public_profile(user_id=_required(user_id, "userID"))
        )

    def comrades(self, *, user_id: str) -> dict[str, object]:
        user_id = _required(user_id, "userID")
        self.repository.ensure_comrade_code(
            user_id=user_id, display_name="Player", updated_at=self.clock()
        )
        value = self.repository.comrades_for_user(user_id=user_id)
        profiles = [
            profile
            for key in ("comrades", "incoming_requests", "outgoing_requests")
            for profile in value.get(key, [])
            if isinstance(profile, dict)
        ]
        user_ids = {
            str(profile.get("user_id") or profile.get("userID"))
            for profile in profiles
            if profile.get("user_id") or profile.get("userID")
        }
        statuses = self.presence.statuses(user_ids)
        for profile in profiles:
            profile_id = str(profile.get("user_id") or profile.get("userID") or "")
            profile.update(statuses.get(profile_id, {}))
        return _comrades_response(value)

    def send_request(
        self, request: dict[str, object], *, user_id: str
    ) -> dict[str, object]:
        user_id = _required(user_id, "userID")
        target = str(request.get("userID") or "").strip()
        if target:
            profile = self.repository.send_comrade_request_to_user(
                user_id=user_id, comrade_user_id=target, updated_at=self.clock()
            )
        else:
            code = _required(str(request.get("comradeCode") or ""), "comrade code")
            profile = self.repository.send_comrade_request_by_code(
                user_id=user_id, comrade_code=code, updated_at=self.clock()
            )
        key = "comrade" if profile.get("accepted") is True else "request"
        return {key: _comrade_profile_response(profile)}

    def respond(self, request: dict[str, object], *, user_id: str) -> dict[str, object]:
        requester = _required(str(request.get("userID") or ""), "userID")
        profile = self.repository.respond_to_comrade_request(
            user_id=_required(user_id, "userID"),
            requester_user_id=requester,
            accept=bool(request.get("accept")),
            updated_at=self.clock(),
        )
        if profile is None:
            return {"accepted": False}
        return {"accepted": True, "comrade": _comrade_profile_response(profile)}

    def remove(self, request: dict[str, object], *, user_id: str) -> dict[str, object]:
        self.repository.remove_comrade(
            user_id=_required(user_id, "userID"),
            comrade_user_id=_required(str(request.get("userID") or ""), "userID"),
        )
        return {"removed": True}


_PROFILE_COLUMNS = """
    p.user_id::text, p.display_name, p.avatar_url, p.comrade_code,
    s.games_played, s.wins_total, s.offline_games, s.offline_wins,
    s.online_games, s.online_wins, s.rating, s.peak_rating, s.rating_games,
    s.casual_games, s.casual_wins, s.ranked_games, s.ranked_wins,
    s.casual_rating, s.casual_peak_rating, s.casual_rating_games
"""


class PostgresSocialRepository:
    """Pooled PostgreSQL adapter for existing Supabase profile/social tables."""

    def __init__(
        self,
        database_url: str | None = None,
        *,
        pool: ConnectionPool | None = None,
        pool_size: int = 8,
    ) -> None:
        if pool is not None:
            self._pool = pool
            return
        if not database_url:
            raise ValueError("database_url is required")
        try:
            import psycopg
        except ImportError as error:
            raise RuntimeError("PostgreSQL requires psycopg[binary]>=3.2") from error
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

    def close(self) -> None:
        self._pool.close()

    @contextmanager
    def _cursor(self) -> Iterator[object]:
        with self._pool.connection() as connection, connection.transaction():
            with connection.cursor() as cursor:
                yield cursor

    def ensure_comrade_code(
        self, *, user_id: str, display_name: str, updated_at: float
    ) -> str:
        with self._cursor() as cursor:
            cursor.execute(
                """insert into public.profiles (user_id, display_name, comrade_code, updated_at)
                   values (%s, %s, %s, %s)
                   on conflict (user_id) do update set
                     display_name = coalesce(nullif(public.profiles.display_name, ''), excluded.display_name),
                     comrade_code = coalesce(public.profiles.comrade_code, excluded.comrade_code),
                     updated_at = greatest(public.profiles.updated_at, excluded.updated_at)
                   returning comrade_code""",
                (
                    user_id,
                    display_name,
                    _fallback_code(user_id),
                    _timestamp(updated_at),
                ),
            )
            return str(cursor.fetchone()[0])

    def leaderboard(self, *, limit: int = 100) -> list[Profile]:
        with self._cursor() as cursor:
            cursor.execute(
                f"""select {_PROFILE_COLUMNS}
                      from public.profiles p join public.profile_stats s on s.user_id = p.user_id
                     where s.online_games > 0
                     order by s.rating desc, s.online_wins desc, s.online_games desc,
                              lower(p.display_name), p.user_id
                     limit %s""",
                (max(1, min(int(limit), 100)),),
            )
            return [_profile(row) for row in cursor.fetchall()]

    def public_profile(self, *, user_id: str) -> Profile:
        with self._cursor() as cursor:
            return self._profile_for_user(cursor, user_id)

    def comrades_for_user(self, *, user_id: str) -> dict[str, object]:
        with self._cursor() as cursor:
            code = self._code_for_user(cursor, user_id)
            cursor.execute(
                f"""select {_PROFILE_COLUMNS}
                      from public.user_comrades c
                      join public.profiles p on p.user_id = c.comrade_user_id
                      left join public.profile_stats s on s.user_id = p.user_id
                     where c.user_id = %s order by lower(p.display_name), p.comrade_code""",
                (user_id,),
            )
            comrades = [_profile(row) for row in cursor.fetchall()]
            incoming = self._requests(cursor, user_id, incoming=True)
            outgoing = self._requests(cursor, user_id, incoming=False)
        return {
            "user_id": user_id,
            "comrade_code": code,
            "comrades": comrades,
            "incoming_requests": incoming,
            "outgoing_requests": outgoing,
        }

    def _requests(
        self, cursor: object, user_id: str, *, incoming: bool
    ) -> list[Profile]:
        joined = "r.requester_user_id" if incoming else "r.addressee_user_id"
        filtered = "r.addressee_user_id" if incoming else "r.requester_user_id"
        cursor.execute(
            f"""select {_PROFILE_COLUMNS}, r.created_at
                  from public.user_comrade_requests r
                  join public.profiles p on p.user_id = {joined}
                  left join public.profile_stats s on s.user_id = p.user_id
                 where {filtered} = %s order by r.created_at desc""",
            (user_id,),
        )
        return [_profile(row, requested_at=20) for row in cursor.fetchall()]

    def send_comrade_request_by_code(
        self, *, user_id: str, comrade_code: str, updated_at: float
    ) -> Profile:
        code = _normalize_code(comrade_code)
        if not code:
            raise ValueError("missing comrade code")
        with self._cursor() as cursor:
            self._code_for_user(cursor, user_id)
            cursor.execute(
                "select user_id::text from public.profiles where upper(comrade_code) = %s",
                (code,),
            )
            row = cursor.fetchone()
            if row is None:
                raise ValueError("comrade code not found")
            return self._send(cursor, user_id, str(row[0]), _timestamp(updated_at))

    def send_comrade_request_to_user(
        self, *, user_id: str, comrade_user_id: str, updated_at: float
    ) -> Profile:
        with self._cursor() as cursor:
            self._code_for_user(cursor, user_id)
            return self._send(cursor, user_id, comrade_user_id, _timestamp(updated_at))

    def _send(
        self, cursor: object, user_id: str, target: str, now: datetime
    ) -> Profile:
        if not target:
            raise ValueError("missing userID")
        if target == user_id:
            raise ValueError("cannot add yourself as a comrade")
        self._profile_for_user(cursor, target)
        cursor.execute(
            "select 1 from public.user_comrades where user_id = %s and comrade_user_id = %s",
            (user_id, target),
        )
        if cursor.fetchone() is not None:
            raise ValueError("already comrades")
        cursor.execute(
            """delete from public.user_comrade_requests
                where requester_user_id = %s and addressee_user_id = %s
                returning requester_user_id""",
            (target, user_id),
        )
        if cursor.fetchone() is not None:
            self._link(cursor, user_id, target, now)
            self._link(cursor, target, user_id, now)
            profile = self._profile_for_user(cursor, target)
            profile["accepted"] = True
            return profile
        cursor.execute(
            """insert into public.user_comrade_requests
                 (requester_user_id, addressee_user_id, created_at) values (%s, %s, %s)
                 on conflict (requester_user_id, addressee_user_id)
                 do update set created_at = excluded.created_at""",
            (user_id, target, now),
        )
        profile = self._profile_for_user(cursor, target)
        profile["accepted"] = False
        return profile

    def respond_to_comrade_request(
        self, *, user_id: str, requester_user_id: str, accept: bool, updated_at: float
    ) -> Profile | None:
        with self._cursor() as cursor:
            cursor.execute(
                """delete from public.user_comrade_requests
                    where requester_user_id = %s and addressee_user_id = %s
                    returning requester_user_id""",
                (requester_user_id, user_id),
            )
            if cursor.fetchone() is None:
                raise ValueError("comrade request not found")
            if not accept:
                return None
            now = _timestamp(updated_at)
            self._link(cursor, user_id, requester_user_id, now)
            self._link(cursor, requester_user_id, user_id, now)
            return self._profile_for_user(cursor, requester_user_id)

    def remove_comrade(self, *, user_id: str, comrade_user_id: str) -> None:
        pairs = (user_id, comrade_user_id, comrade_user_id, user_id)
        with self._cursor() as cursor:
            cursor.execute(
                """delete from public.user_comrades
                    where (user_id = %s and comrade_user_id = %s)
                       or (user_id = %s and comrade_user_id = %s)""",
                pairs,
            )
            cursor.execute(
                """delete from public.user_comrade_requests
                    where (requester_user_id = %s and addressee_user_id = %s)
                       or (requester_user_id = %s and addressee_user_id = %s)""",
                pairs,
            )

    @staticmethod
    def _link(cursor: object, user_id: str, target: str, now: datetime) -> None:
        cursor.execute(
            """insert into public.user_comrades (user_id, comrade_user_id, created_at)
                values (%s, %s, %s) on conflict (user_id, comrade_user_id) do nothing""",
            (user_id, target, now),
        )

    def _code_for_user(self, cursor: object, user_id: str) -> str:
        cursor.execute(
            "select comrade_code from public.profiles where user_id = %s", (user_id,)
        )
        row = cursor.fetchone()
        if row is not None and row[0]:
            return str(row[0])
        code = _fallback_code(user_id)
        cursor.execute(
            """insert into public.profiles (user_id, display_name, comrade_code)
                values (%s, 'Player', %s) on conflict (user_id) do update
                set comrade_code = coalesce(public.profiles.comrade_code, excluded.comrade_code)
                returning comrade_code""",
            (user_id, code),
        )
        return str(cursor.fetchone()[0])

    def _profile_for_user(self, cursor: object, user_id: str) -> Profile:
        cursor.execute(
            f"""select {_PROFILE_COLUMNS} from public.profiles p
                  left join public.profile_stats s on s.user_id = p.user_id
                 where p.user_id = %s""",
            (user_id,),
        )
        row = cursor.fetchone()
        if row is None:
            raise ValueError("comrade profile not found")
        return _profile(row)


def _profile(row: object, *, requested_at: int | None = None) -> Profile:
    stats = {
        key: row[index] or default
        for index, (key, default) in enumerate(
            (
                ("games_played", 0),
                ("wins_total", 0),
                ("offline_games", 0),
                ("offline_wins", 0),
                ("online_games", 0),
                ("online_wins", 0),
                ("rating", 1000),
                ("peak_rating", 1000),
                ("rating_games", 0),
                ("casual_games", 0),
                ("casual_wins", 0),
                ("ranked_games", 0),
                ("ranked_wins", 0),
                ("casual_rating", 1000),
                ("casual_peak_rating", 1000),
                ("casual_rating_games", 0),
            ),
            start=4,
        )
    }
    result: Profile = {
        "userID": row[0],
        "displayName": row[1],
        "avatarURL": row[2],
        "comradeCode": row[3],
        "stats": stats,
    }
    if requested_at is not None and row[requested_at] is not None:
        result["requestedAt"] = row[requested_at].timestamp()
    return result


def _public_profile_response(profile: Profile, *, rank: int | None = None) -> Profile:
    result: Profile = {
        "userID": profile.get("userID") or profile.get("user_id"),
        "displayName": profile.get("displayName") or profile.get("display_name"),
        "avatarURL": profile.get("avatarURL") or profile.get("avatar_url"),
        "stats": profile.get("stats") if isinstance(profile.get("stats"), dict) else {},
    }
    if rank is not None:
        result["rank"] = rank
    return result


def _comrade_profile_response(profile: Profile) -> Profile:
    return {
        "userID": profile.get("user_id") or profile.get("userID"),
        "displayName": profile.get("display_name") or profile.get("displayName"),
        "avatarURL": profile.get("avatar_url") or profile.get("avatarURL"),
        "comradeCode": profile.get("comrade_code") or profile.get("comradeCode"),
        "requestedAt": profile.get("requested_at") or profile.get("requestedAt"),
        "isOnline": bool(profile.get("isOnline")),
        "inGame": bool(profile.get("inGame")),
        "inLobby": bool(profile.get("inLobby")),
        "stats": profile.get("stats") if isinstance(profile.get("stats"), dict) else {},
    }


def _comrades_response(value: dict[str, object]) -> dict[str, object]:
    def profiles(snake: str, camel: str) -> list[Profile]:
        values = value.get(snake, value.get(camel, []))
        return [
            _comrade_profile_response(item) for item in values if isinstance(item, dict)
        ]

    return {
        "userID": value.get("user_id") or value.get("userID"),
        "comradeCode": value.get("comrade_code") or value.get("comradeCode"),
        "comrades": profiles("comrades", "comrades"),
        "incomingRequests": profiles("incoming_requests", "incomingRequests"),
        "outgoingRequests": profiles("outgoing_requests", "outgoingRequests"),
    }


def _required(value: str, name: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError(f"missing {name}")
    return value


def _normalize_code(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


def _fallback_code(user_id: str) -> str:
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest().upper()[:5]


def _timestamp(value: float) -> datetime:
    return datetime.fromtimestamp(value, tz=timezone.utc)
