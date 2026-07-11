from __future__ import annotations

from server.kolkhoz_server.matchmaking import (
    BotProfile,
    Matchmaker,
    MatchmakingSession,
    MatchRequest,
    PopulationPlanner,
    available_profiles,
    bot_fill_choices,
    rating_key,
    target_bot_rating,
)


class Repository:
    def __init__(self, sessions, ratings):
        self.sessions = sessions
        self.profile_ratings = ratings

    def open_sessions(self, now):
        return self.sessions

    def ratings(self, user_ids):
        return {
            user_id: self.profile_ratings[user_id]
            for user_id in user_ids
            if user_id in self.profile_ratings
        }


def session(
    session_id, *, users=(), seats=(1,), ranked=False, created=1.0, visible=True
):
    return MatchmakingSession(session_id, created, ranked, visible, seats, users)


def test_rating_bands_match_legacy_thresholds() -> None:
    table = session("table", users=("host",))
    assert rating_key(table, 1000, {"host": 1300}) == (0, 300, 300)
    assert rating_key(table, 1000, {"host": 1600}) == (1, 600, 600)
    assert rating_key(table, 1000, {"host": 1601}) == (2, 601, 601)


def test_matchmaker_prefers_rating_band_before_fullness() -> None:
    fuller_far = session("fuller", users=("far",), seats=(1,), created=1)
    emptier_close = session("close", users=("close",), seats=(1, 2), created=2)
    repository = Repository(
        [fuller_far, emptier_close], {"player": 500, "far": 1600, "close": 550}
    )
    assert (
        Matchmaker(repository).choose(MatchRequest("player"), now=10).session_id
        == "close"
    )


def test_matchmaker_filters_ranked_comrades_visibility_and_existing_player() -> None:
    sessions = [
        session("hidden", users=("friend",), ranked=True, visible=False),
        session("casual", users=("friend",)),
        session("stranger", users=("other",), ranked=True),
        session("already", users=("player", "friend"), ranked=True),
        session("match", users=("friend",), ranked=True, seats=(2, 3)),
    ]
    choice = Matchmaker(Repository(sessions, {})).choose(
        MatchRequest(
            "player",
            ranked_only=True,
            comrades_only=True,
            comrade_user_ids=frozenset({"friend"}),
        ),
        now=10,
    )
    assert choice is not None
    assert (choice.session_id, choice.player_id) == ("match", 2)


def test_matchmaker_prefers_fullest_then_oldest_for_equal_ratings() -> None:
    sessions = [
        session("empty", users=("a",), seats=(1, 2), created=0),
        session("new", users=("b",), seats=(1,), created=2),
        session("old", users=("c",), seats=(3,), created=1),
    ]
    choice = Matchmaker(Repository(sessions, {})).choose(MatchRequest("player"), now=10)
    assert choice is not None
    assert choice.session_id == "old"


def test_profile_availability_deduplicates_and_excludes_active_and_human() -> None:
    profiles = [
        BotProfile("active", "heuristicAI"),
        BotProfile("bot", "heuristicAI"),
        BotProfile("bot", "randomAI"),
        BotProfile("person", "human"),
    ]
    assert available_profiles(profiles, {"active"}) == [
        BotProfile("bot", "heuristicAI")
    ]


def test_target_rating_averages_each_table_then_all_tables() -> None:
    sessions = [session("a", users=("a", "b")), session("b", users=("c",))]
    assert target_bot_rating(sessions, {"a": 800, "b": 1000, "c": 1200}) == 1050
    assert target_bot_rating([], {}) == 1000


def test_fill_selects_nearest_unique_bot_once_per_table() -> None:
    sessions = [
        session("low", users=("low-human",), seats=(1, 2)),
        session("high", users=("high-human",), seats=(2, 3)),
    ]
    profiles = [
        BotProfile("high-bot", "heuristicAI", 1450),
        BotProfile("low-bot", "heuristicAI", 950),
    ]
    choices = bot_fill_choices(
        sessions, profiles, {"low-human": 900, "high-human": 1500}
    )
    assert [
        (choice.session_id, choice.player_id, choice.profile.user_id)
        for choice in choices
    ] == [
        ("high", 2, "high-bot"),
        ("low", 1, "low-bot"),
    ]


def test_population_plans_two_distinct_ranked_and_casual_lobbies_deterministically() -> (
    None
):
    planner = PopulationPlanner()
    first = planner.seed_specs(now=1800, seed_sequence=4)
    assert first == planner.seed_specs(now=1800, seed_sequence=4)
    assert [spec.ranked for spec in first] == [True, False]
    assert len({spec.open_human_seats for spec in first}) == 2
    assert all(spec.open_human_seats in {1, 2, 3} for spec in first)


def test_population_profile_rotation_prefers_least_used_then_stable_hash() -> None:
    profiles = [
        BotProfile("a", "heuristicAI"),
        BotProfile("b", "heuristicAI"),
        BotProfile("c", "heuristicAI"),
    ]
    planner = PopulationPlanner()
    selected = planner.choose_profiles(
        profiles,
        count=2,
        now=60,
        use_counts={"a": 2, "b": 0, "c": 0},
        exclude_user_ids={"c"},
    )
    assert selected == [BotProfile("b", "heuristicAI"), BotProfile("a", "heuristicAI")]
