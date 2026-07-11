from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Mapping, Protocol, Sequence


PLAYER_COUNT = 4
DEFAULT_RATING = 1000
IDEAL_RATING_DELTA = 300
ACCEPTABLE_RATING_DELTA = 600
LOBBY_SEED_INTERVAL_SECONDS = 15 * 60
OPEN_SEAT_FILL_INTERVAL_SECONDS = 30
OPEN_SEAT_ROTATION = (3, 2, 1)


@dataclass(frozen=True)
class MatchmakingSession:
    session_id: str
    created_at: float
    ranked: bool
    browser_joinable: bool
    open_seats: tuple[int, ...]
    seated_user_ids: tuple[str, ...]


@dataclass(frozen=True)
class BotProfile:
    user_id: str
    controller: str
    rating: int | None = None


@dataclass(frozen=True)
class MatchRequest:
    user_id: str
    ranked_only: bool = False
    comrades_only: bool = False
    comrade_user_ids: frozenset[str] = frozenset()


@dataclass(frozen=True)
class MatchChoice:
    session_id: str
    player_id: int


@dataclass(frozen=True)
class PopulationSeed:
    ranked: bool
    open_human_seats: int
    population_kind: str = "open_lobby_seed"


@dataclass(frozen=True)
class BotSeatChoice:
    session_id: str
    player_id: int
    profile: BotProfile


class MatchmakingRepository(Protocol):
    """Read model used before an atomic seat claim in the repository."""

    def open_sessions(self, now: float) -> Sequence[MatchmakingSession]: ...

    def ratings(self, user_ids: set[str]) -> Mapping[str, int]: ...


class ProfileBotRepository(Protocol):
    """Read model used to select bots; the caller atomically claims the result."""

    def active_profile_bot_user_ids(self, now: float) -> set[str]: ...

    def profiles(self) -> Sequence[BotProfile]: ...


def rating_key(
    session: MatchmakingSession,
    player_rating: int,
    ratings: Mapping[str, int],
) -> tuple[int, int, int]:
    seat_ratings = [
        ratings.get(user_id, DEFAULT_RATING) for user_id in session.seated_user_ids
    ]
    if not seat_ratings:
        return (0, 0, 0)
    max_delta = max(abs(rating - player_rating) for rating in seat_ratings)
    average_delta = int(abs(sum(seat_ratings) / len(seat_ratings) - player_rating))
    if max_delta <= IDEAL_RATING_DELTA:
        band = 0
    elif max_delta <= ACCEPTABLE_RATING_DELTA:
        band = 1
    else:
        band = 2
    return (band, max_delta, average_delta)


class Matchmaker:
    def __init__(self, repository: MatchmakingRepository) -> None:
        self.repository = repository

    def choose(self, request: MatchRequest, *, now: float) -> MatchChoice | None:
        candidates = [
            session
            for session in self.repository.open_sessions(now)
            if session.browser_joinable
            and session.open_seats
            and request.user_id not in session.seated_user_ids
            and (not request.ranked_only or session.ranked)
            and (
                not request.comrades_only
                or bool(request.comrade_user_ids.intersection(session.seated_user_ids))
            )
        ]
        user_ids = {request.user_id}
        user_ids.update(
            user_id for session in candidates for user_id in session.seated_user_ids
        )
        ratings = dict(self.repository.ratings(user_ids))
        player_rating = ratings.get(request.user_id, DEFAULT_RATING)
        scored = [
            (
                rating_key(session, player_rating, ratings),
                len(session.open_seats),
                session.created_at,
                session.session_id,
                session,
            )
            for session in candidates
        ]
        if any(score[0][0] < 2 for score in scored):
            scored = [score for score in scored if score[0][0] < 2]
        if not scored:
            return None
        session = min(scored, key=lambda score: score[:4])[4]
        return MatchChoice(session.session_id, session.open_seats[0])


def available_profiles(
    profiles: Sequence[BotProfile], active_user_ids: set[str]
) -> list[BotProfile]:
    available: list[BotProfile] = []
    seen = set(active_user_ids)
    for profile in profiles:
        if profile.user_id in seen or profile.controller == "human":
            continue
        available.append(profile)
        seen.add(profile.user_id)
    return available


def target_bot_rating(
    sessions: Sequence[MatchmakingSession], ratings: Mapping[str, int]
) -> int:
    table_ratings = []
    for session in sessions:
        seated = [
            ratings.get(user_id, DEFAULT_RATING) for user_id in session.seated_user_ids
        ]
        if seated:
            table_ratings.append(round(sum(seated) / len(seated)))
    return (
        round(sum(table_ratings) / len(table_ratings))
        if table_ratings
        else DEFAULT_RATING
    )


def bot_fill_choices(
    sessions: Sequence[MatchmakingSession],
    profiles: Sequence[BotProfile],
    ratings: Mapping[str, int],
    *,
    active_user_ids: set[str] | None = None,
) -> list[BotSeatChoice]:
    bots = available_profiles(profiles, active_user_ids or set())
    scored: list[
        tuple[
            tuple[int, int, int], int, float, str, int, MatchmakingSession, BotProfile
        ]
    ] = []
    for session in sessions:
        if not session.browser_joinable or not session.open_seats:
            continue
        for index, profile in enumerate(bots):
            if profile.user_id in session.seated_user_ids:
                continue
            profile_rating = (
                profile.rating
                if profile.rating is not None
                else ratings.get(profile.user_id, DEFAULT_RATING)
            )
            scored.append(
                (
                    rating_key(session, profile_rating, ratings),
                    len(session.open_seats),
                    session.created_at,
                    session.session_id,
                    index,
                    session,
                    profile,
                )
            )
    if any(score[0][0] < 2 for score in scored):
        scored = [score for score in scored if score[0][0] < 2]
    scored.sort(key=lambda score: score[:5])
    choices: list[BotSeatChoice] = []
    used_sessions: set[str] = set()
    used_profiles: set[str] = set()
    for *_, session, profile in scored:
        if session.session_id in used_sessions or profile.user_id in used_profiles:
            continue
        choices.append(
            BotSeatChoice(session.session_id, session.open_seats[0], profile)
        )
        used_sessions.add(session.session_id)
        used_profiles.add(profile.user_id)
    return choices


class PopulationPlanner:
    """Pure deterministic population decisions, safe to run on any scheduler replica."""

    def seed_specs(
        self, *, now: float, seed_sequence: int
    ) -> tuple[PopulationSeed, ...]:
        epoch = int(now // LOBBY_SEED_INTERVAL_SECONDS)
        choices = sorted(
            OPEN_SEAT_ROTATION,
            key=lambda seats: hashlib.sha256(
                f"{epoch}:{seed_sequence}:{seats}".encode()
            ).hexdigest(),
        )[:2]
        return tuple(
            PopulationSeed(ranked=ranked, open_human_seats=seats)
            for ranked, seats in zip((True, False), choices, strict=True)
        )

    def choose_profiles(
        self,
        profiles: Sequence[BotProfile],
        *,
        count: int,
        now: float,
        use_counts: Mapping[str, int],
        exclude_user_ids: set[str] | None = None,
    ) -> list[BotProfile]:
        excluded = exclude_user_ids or set()
        epoch = int(now // OPEN_SEAT_FILL_INTERVAL_SECONDS)
        candidates = [
            profile for profile in profiles if profile.user_id not in excluded
        ]
        candidates.sort(
            key=lambda profile: (
                use_counts.get(profile.user_id, 0),
                hashlib.sha256(f"{epoch}:{profile.user_id}".encode()).hexdigest(),
            )
        )
        return candidates[:count]
