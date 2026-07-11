from __future__ import annotations

from server.kolkhoz_server.matchmaking import BotProfile, MatchmakingSession
from server.kolkhoz_server.population import (
    PROFILE_BOT_TARGET_WAIT_SECONDS,
    IntervalClaim,
    PopulationScheduler,
)


class Repository:
    def __init__(self) -> None:
        self.claimed: set[tuple[str, int]] = set()
        self.sessions: list[MatchmakingSession] = []
        self.bots = [
            BotProfile("a", "heuristicAI", 900),
            BotProfile("b", "mediumAI", 1100),
            BotProfile("c", "neuralAI", 1400),
            BotProfile("d", "heuristicAI", 1000),
            BotProfile("e", "mediumAI", 1200),
            BotProfile("f", "neuralAI", 1500),
        ]
        self.active: set[str] = set()
        self.uses = {"a": 4, "b": 0, "c": 2, "d": 0, "e": 1, "f": 0}
        self.seed_calls = []
        self.fill_calls = []
        self.created_target = None
        self.created_before = None

    def claim_interval(self, kind, epoch, *, owner_id, now, lease_seconds):
        key = (kind, epoch)
        if key in self.claimed:
            return None
        self.claimed.add(key)
        return IntervalClaim(kind, epoch, owner_id, len(self.claimed))

    def seed_lobby(self, spec, profiles, **kwargs):
        self.seed_calls.append((spec, tuple(profiles), kwargs["idempotency_key"]))
        return f"seed-{len(self.seed_calls)}"

    def open_fill_sessions(self, *, now, created_before, limit):
        self.created_before = created_before
        return self.sessions[:limit]

    def profiles(self, *, limit):
        return self.bots[:limit]

    def create_profiles(self, *, count, target_rating, exclude_user_ids, now):
        self.created_target = target_rating
        return []

    def active_profile_bot_user_ids(self, now):
        return set(self.active)

    def ratings(self, user_ids):
        ratings = {"low-human": 850, "high-human": 1450}
        ratings.update({bot.user_id: bot.rating for bot in self.bots})
        return {key: value for key, value in ratings.items() if key in user_ids}

    def bot_use_counts(self, user_ids):
        return {key: self.uses.get(key, 0) for key in user_ids}

    def claim_bot_seat(self, session_id, player_id, profile, **kwargs):
        self.fill_calls.append(
            (session_id, player_id, profile.user_id, kwargs["idempotency_key"])
        )
        self.active.add(profile.user_id)
        return True


def test_replicas_execute_each_interval_once_and_seed_ranked_and_casual() -> None:
    repository = Repository()
    first = PopulationScheduler(repository, owner_id="one").tick(now=900.0)
    second = PopulationScheduler(repository, owner_id="two").tick(now=900.0)

    assert first.seeded_session_ids == ("seed-1", "seed-2")
    assert second.seeded_session_ids == ()
    assert [call[0].ranked for call in repository.seed_calls] == [True, False]
    assert len({call[0].open_human_seats for call in repository.seed_calls}) == 2
    assert len(
        {profile.user_id for call in repository.seed_calls for profile in call[1]}
    ) == sum(len(call[1]) for call in repository.seed_calls)
    assert all(
        call[2].startswith("population-seed:1:") for call in repository.seed_calls
    )


def test_fill_is_bounded_waits_90_seconds_and_matches_bot_rating() -> None:
    repository = Repository()
    repository.sessions = [
        MatchmakingSession("low", 1, False, True, (1, 2), ("low-human",)),
        MatchmakingSession("high", 2, True, True, (2, 3), ("high-human",)),
    ]
    result = PopulationScheduler(repository, owner_id="worker", batch_size=2).tick(
        now=1000.0
    )

    assert repository.created_before == 1000 - PROFILE_BOT_TARGET_WAIT_SECONDS
    assert result.filled_seats == (
        ("low", 1, "a"),
        ("high", 2, "c"),
    )
    assert all(
        call[3].startswith("population-fill:33:") for call in repository.fill_calls
    )


def test_active_profile_is_never_reused_and_one_bot_fills_at_most_one_table() -> None:
    repository = Repository()
    repository.active = {"a", "b", "c", "d", "e"}
    repository.sessions = [
        MatchmakingSession("one", 1, False, True, (1,), ("low-human",)),
        MatchmakingSession("two", 2, False, True, (1,), ("low-human",)),
    ]
    result = PopulationScheduler(repository).tick(now=1000)

    assert result.filled_seats == (("one", 1, "f"),)
    assert len({call[2] for call in repository.fill_calls}) == len(
        repository.fill_calls
    )


def test_new_interval_runs_again_with_stable_different_idempotency_keys() -> None:
    repository = Repository()
    scheduler = PopulationScheduler(repository, owner_id="worker")
    scheduler.tick(now=900)
    scheduler.tick(now=1800)

    keys = [call[2] for call in repository.seed_calls]
    assert len(keys) == 4
    assert len(set(keys)) == 4
