from __future__ import annotations

import json
import ctypes
import threading
import time
import unittest
import urllib.request
import uuid
from http import HTTPStatus

from research.kolkhoz_research.c_engine import (
    CEngine,
    KCAction,
    KCCard,
    build_shared_library,
)
from research.kolkhoz_research.online_load_test import run_online_load_test
from research.kolkhoz_research.online_server import (
    BOT_HUMAN_GAME_ACTION_DELAY_MAX_SECONDS,
    BOT_HUMAN_GAME_ACTION_DELAY_MIN_SECONDS,
    DEFAULT_SESSION_TTL_SECONDS,
    HostedSession,
    KCEngineSnapshot,
    KolkhozOnlineHTTPServer,
    KolkhozOnlineSessionService,
    OnlineServerError,
    PHASE_GAME_OVER,
    POSTGRES_BIGINT_MAX,
    _requisition_message,
)
from research.kolkhoz_research.model import PolicyArtifact
from research.kolkhoz_research.online_store import (
    SERVER_BOT_PROFILES,
    SERVER_BOT_PROFILES_BY_ID,
    seat_token_hash,
)


def kolkhoz_variants() -> dict[str, object]:
    return {
        "deckType": 52,
        "maxYears": 5,
        "nomenclature": False,
        "allowSwap": True,
        "northernStyle": False,
        "miceVariant": False,
        "ordenNachalniku": False,
        "medalsCount": False,
        "accumulateJobs": False,
        "heroOfSovietUnion": True,
        "wrecker": True,
    }


def create_request() -> dict[str, object]:
    return {
        "seed": 123,
        "variants": kolkhoz_variants(),
        "controllers": ["human", "human", "heuristicAI", "heuristicAI"],
    }


def start_hosted_through_lobby(
    service: KolkhozOnlineSessionService,
    hosted: HostedSession,
    *,
    now: float,
) -> None:
    service._sync_lobby_state(hosted, now)
    deadline = hosted.lobby_countdown_ends_at
    if deadline is None:
        raise AssertionError("full lobby did not start a countdown")
    service._sync_lobby_state(hosted, deadline)
    if not hosted.started:
        raise AssertionError("lobby did not start at its deadline")


class OnlineServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = CEngine(build_shared_library())

    def setUp(self) -> None:
        self.service = KolkhozOnlineSessionService(
            self.engine,
            lobby_countdown_seconds=0,
        )

    def tearDown(self) -> None:
        self.service.close()

    def test_service_uses_current_engine_and_flutter_json_contract(self) -> None:
        created = self.service.create_session(create_request())

        uuid.UUID(created["sessionID"])
        self.assertEqual(created["playerID"], 0)
        self.assertIsInstance(created["seatToken"], str)
        update = created["update"]
        self.assertEqual(update["variants"], kolkhoz_variants())
        self.assertEqual(
            update["controllers"], ["human", "human", "heuristicAI", "heuristicAI"]
        )
        self.assertIn("legalActions", update)
        self.assertIn("isViewerTurn", update)
        self.assertIn("seatPresence", update)
        self.assertIn("turnPlayerID", update)
        self.assertIn("turnDeadlineAt", update)
        self.assertFalse(update["ranked"])

        snapshot = update["snapshot"]
        for key in [
            "year",
            "phase",
            "currentPlayer",
            "waitingPlayer",
            "waitingForExternalAction",
            "lead",
            "trumpSelector",
            "trump",
            "trickCount",
            "isFamine",
            "players",
            "jobPiles",
            "revealedJobs",
            "claimedJobs",
            "workHours",
            "jobBuckets",
            "accumulatedJobCards",
            "currentTrick",
            "lastTrick",
            "lastWinner",
            "exiled",
            "pendingAssignments",
            "requisitionEvents",
            "scores",
            "winnerID",
            "swapConfirmed",
            "swapCount",
        ]:
            self.assertIn(key, snapshot)

        self.assertGreater(len(snapshot["players"][0]["hand"]), 0)
        self.assertEqual(snapshot["players"][1]["hand"], [])
        self.assertEqual(snapshot["jobPiles"], [{"suit": i, "cards": []} for i in range(4)])
        self.assertEqual(
            snapshot["accumulatedJobCards"],
            [{"suit": i, "cards": []} for i in range(4)],
        )

        joined = self.service.join_session(created["sessionID"], {"preferredPlayerID": 1})
        self.assertEqual(joined["playerID"], 1)
        self.assertIsInstance(joined["seatToken"], str)
        joined_players = joined["update"]["snapshot"]["players"]
        self.assertEqual(joined_players[0]["hand"], [])
        self.assertGreater(len(joined_players[1]["hand"]), 0)

        with self.assertRaises(OnlineServerError) as unauthorized:
            self.service.legal_actions(created["sessionID"], 0, "wrong-token")
        self.assertEqual(unauthorized.exception.status, HTTPStatus.UNAUTHORIZED)
        with self.assertRaises(OnlineServerError) as unauthorized_state:
            self.service.update(created["sessionID"], 0, "wrong-token")
        self.assertEqual(unauthorized_state.exception.status, HTTPStatus.UNAUTHORIZED)

        actions = self.service.legal_actions(
            created["sessionID"],
            0,
            created["seatToken"],
        )
        self.assertGreater(len(actions), 0)
        submitted = self.service.submit_action(
            created["sessionID"],
            {
                "playerID": 0,
                "actionLogCount": created["update"]["actionLogCount"],
                "action": actions[0],
            },
            created["seatToken"],
        )
        self.assertEqual(submitted["actionLogCount"], 1)

        with self.assertRaises(OnlineServerError) as stale:
            self.service.submit_action(
                created["sessionID"],
                {"playerID": 0, "actionLogCount": 0, "action": actions[0]},
                created["seatToken"],
            )
        self.assertEqual(stale.exception.status, HTTPStatus.CONFLICT)

    def test_requisition_event_messages_match_engine_kinds(self) -> None:
        self.assertEqual(_requisition_message(1), "Card sent north.")
        self.assertEqual(_requisition_message(2), "No matching card found.")
        self.assertEqual(_requisition_message(3), "Drunkard exiled.")
        self.assertEqual(_requisition_message(4), "Protected from requisition.")

    def test_reactions_are_shared_and_permanent_after_game_start(self) -> None:
        created = self.service.create_session(create_request())
        joined = self.service.join_session(
            created["sessionID"],
            {"preferredPlayerID": 1},
        )

        guest_update = self.service.submit_reaction(
            created["sessionID"],
            {"playerID": 1, "reactionID": "medal"},
            joined["seatToken"],
        )
        host_update = self.service.update(
            created["sessionID"],
            0,
            created["seatToken"],
        )

        self.assertEqual(guest_update["reactions"], host_update["reactions"])
        self.assertEqual(
            host_update["reactions"][0],
            {
                "revision": 1,
                "playerID": 1,
                "reactionID": "medal",
                "year": host_update["snapshot"]["year"],
                "phase": host_update["snapshot"]["phase"],
                "createdAt": host_update["reactions"][0]["createdAt"],
            },
        )

        with self.assertRaises(OnlineServerError) as invalid:
            self.service.submit_reaction(
                created["sessionID"],
                {"playerID": 1, "reactionID": "not-curated"},
                joined["seatToken"],
            )
        self.assertEqual(invalid.exception.status, HTTPStatus.BAD_REQUEST)

    def test_reactions_are_rejected_while_session_is_in_lobby(self) -> None:
        service = KolkhozOnlineSessionService(
            self.engine,
            lobby_countdown_seconds=30,
        )
        try:
            created = service.create_session(create_request())
            with self.assertRaises(OnlineServerError) as not_started:
                service.submit_reaction(
                    created["sessionID"],
                    {"playerID": 0, "reactionID": "comrade"},
                    created["seatToken"],
                )
            self.assertEqual(not_started.exception.status, HTTPStatus.CONFLICT)
        finally:
            service.close()

    def test_other_players_plot_swaps_are_redacted_until_game_over(self) -> None:
        created = self.service.create_session(create_request())
        hosted = self.service._session(created["sessionID"])
        hosted.action_log.append(
            {
                "kind": 2,
                "playerID": 1,
                "handCard": {"suit": 0, "value": 7},
                "plotCard": {"suit": 1, "value": 8},
            }
        )

        hidden = self.service._game_log_actions(hosted, 0)[0]
        visible_to_owner = self.service._game_log_actions(hosted, 1)[0]

        self.assertEqual(hidden["handCard"], {"suit": -1, "value": -1})
        self.assertEqual(hidden["plotCard"], {"suit": -1, "value": -1})
        self.assertEqual(visible_to_owner["handCard"], {"suit": 0, "value": 7})

    def test_joined_players_wait_for_shared_lobby_countdown(self) -> None:
        service = KolkhozOnlineSessionService(
            self.engine,
            lobby_countdown_seconds=30,
        )
        try:
            created = service.create_session(create_request())
            self.assertFalse(created["update"]["started"])
            self.assertIsNone(created["update"]["lobbyCountdownEndsAt"])
            self.assertEqual(created["update"]["legalActions"], [])

            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
            )
            countdown_ends_at = joined["update"]["lobbyCountdownEndsAt"]
            self.assertFalse(joined["update"]["started"])
            self.assertIsInstance(countdown_ends_at, float)
            self.assertEqual(joined["update"]["legalActions"], [])

            host_update = service.update(
                created["sessionID"],
                0,
                created["seatToken"],
            )
            self.assertFalse(host_update["started"])
            self.assertEqual(host_update["lobbyCountdownEndsAt"], countdown_ends_at)

            hosted = service._session(created["sessionID"])
            hosted.lobby_countdown_ends_at = time.time() - 1
            guest_update = service.update(
                created["sessionID"],
                1,
                joined["seatToken"],
            )
            self.assertTrue(guest_update["started"])
            self.assertIsNone(guest_update["lobbyCountdownEndsAt"])
            self.assertTrue(
                service.update(
                    created["sessionID"],
                    0,
                    created["seatToken"],
                )["started"]
            )
        finally:
            service.close()

    def test_lobby_countdown_cancels_when_a_player_leaves(self) -> None:
        service = KolkhozOnlineSessionService(
            self.engine,
            lobby_countdown_seconds=30,
        )
        try:
            created = service.create_session(create_request())
            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
            )
            self.assertIsNotNone(joined["update"]["lobbyCountdownEndsAt"])

            service.leave_session(
                created["sessionID"],
                1,
                joined["seatToken"],
            )
            host_update = service.update(
                created["sessionID"],
                0,
                created["seatToken"],
            )
            self.assertFalse(host_update["started"])
            self.assertIsNone(host_update["lobbyCountdownEndsAt"])
        finally:
            service.close()

    def test_hero_makes_every_other_player_vulnerable(self) -> None:
        for is_famine, required_tricks in ((False, 4), (True, 3)):
            with self.subTest(is_famine=is_famine):
                pointer = self.engine.new_engine(seed=1)
                try:
                    state = ctypes.cast(
                        pointer, ctypes.POINTER(KCEngineSnapshot)
                    ).contents
                    state.year = 5 if is_famine else 1
                    state.is_famine = is_famine
                    state.phase = 3
                    state.last_winner = 0
                    state.last_trick_count = 0
                    state.trick_count = required_tricks
                    state.variants.nomenclature = False
                    state.variants.northern_style = False
                    state.variants.mice_variant = False
                    state.variants.hero_of_soviet_union = True
                    state.variants.wrecker = False
                    for suit in range(4):
                        state.work_hours[suit] = 0 if suit == 0 else 40
                        state.claimed_jobs[suit] = suit != 0
                    for player_id in range(4):
                        player = state.players[player_id]
                        player.hand.count = 0
                        player.plot_revealed.count = 1
                        player.plot_revealed.cards[0] = KCCard(0, 6 + player_id)
                        player.plot_hidden.count = 0
                        player.has_won_trick_this_year = player_id == 0
                        player.medals = required_tricks if player_id == 0 else 0

                    self.engine.apply_action(
                        pointer,
                        KCAction(kind=6, player_id=0),
                    )

                    self.assertEqual(state.phase, 4)
                    self.assertEqual(state.exiled[state.year].count, 3)
                    self.assertEqual(
                        {
                            state.requisition_events[index].player_id
                            for index in range(state.requisition_event_count)
                            if state.requisition_events[index].message_kind == 1
                        },
                        {1, 2, 3},
                    )
                    self.assertEqual(state.players[0].plot_revealed.count, 1)
                finally:
                    self.engine.free_engine(pointer)

    def test_service_preserves_neural_seats_for_server_policy_ai(self) -> None:
        request = create_request()
        request["controllers"] = ["human", "human", "neuralAI", "neuralAI"]

        created = self.service.create_session(request)

        self.assertEqual(
            created["update"]["controllers"],
            ["human", "human", "neuralAI", "neuralAI"],
        )

    def test_service_forces_player_created_ranked_request_to_casual(self) -> None:
        request = create_request()
        request["ranked"] = True

        created = self.service.create_session(request, user_id="host-a")
        listing = self.service.session_listing(created["sessionID"])

        self.assertFalse(created["update"]["ranked"])
        self.assertFalse(listing["ranked"])

    def test_service_assigns_seeded_profiles_to_server_ai_seats(self) -> None:
        created = self.service.create_session(create_request())
        listing = self.service.session_listing(created["sessionID"])
        profiles_by_player = {
            profile["playerID"]: profile
            for profile in created["update"]["playerProfiles"]
        }

        self.assertEqual(listing["openSeats"], [1])
        self.assertEqual(listing["occupiedSeats"], [0, 2, 3])
        self.assertEqual(set(profiles_by_player), {2, 3})
        for player_id in (2, 3):
            profile = profiles_by_player[player_id]
            self.assertIn(profile["userID"], SERVER_BOT_PROFILES_BY_ID)
            self.assertNotIn("AI", profile["displayName"])
            self.assertIsInstance(profile["displayName"], str)
            self.assertIsInstance(profile["avatarURL"], str)

    def test_service_matchmakes_into_fullest_visible_game(self) -> None:
        casual_request = create_request()
        casual_request["ranked"] = False
        casual_request["controllers"] = ["human", "human", "human", "heuristicAI"]
        casual = self.service.create_session(casual_request, user_id="host-a")

        fuller = self.service.create_session(create_request(), user_id="host-b")

        locked_request = create_request()
        locked_request["browserJoinable"] = False
        locked = self.service.create_session(locked_request, user_id="host-c")

        matched = self.service.matchmake_session({}, user_id="matched-user")

        self.assertEqual(matched["sessionID"], fuller["sessionID"])
        self.assertEqual(matched["playerID"], 1)
        self.assertEqual(
            self.service.session_listing(fuller["sessionID"])["openSeats"],
            [],
        )
        self.assertEqual(
            self.service.session_listing(casual["sessionID"])["openSeats"],
            [1, 2],
        )
        self.assertEqual(
            self.service.session_listing(locked["sessionID"])["openSeats"],
            [1],
        )

    def test_service_matchmaking_ranked_filter_skips_casual_games(self) -> None:
        casual_request = create_request()
        casual_request["ranked"] = False
        casual = self.service.create_session(casual_request, user_id="host-a")

        ranked_session_id = self.service.create_population_session(
            bot_profiles=list(SERVER_BOT_PROFILES),
            open_human_seats=3,
            ranked=True,
            now=time.time(),
            population_kind="rating_seed",
        )

        matched = self.service.matchmake_session(
            {"rankedOnly": True},
            user_id="matched-user",
        )

        self.assertEqual(matched["sessionID"], ranked_session_id)
        self.assertEqual(
            self.service.session_listing(casual["sessionID"])["openSeats"],
            [1],
        )

    def test_population_session_seed_fits_postgres_bigint(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            service.create_population_session(
                bot_profiles=[SERVER_BOT_PROFILES[0]],
                open_human_seats=3,
                ranked=True,
                now=1_700_000_000.125,
                population_kind="rating_seed",
            )
        finally:
            service.close()

        self.assertLessEqual(store.created["seed"], POSTGRES_BIGINT_MAX)

    def test_service_matchmaking_ranked_filter_seeds_lobby_when_none_available(
        self,
    ) -> None:
        service = KolkhozOnlineSessionService(self.engine)
        try:
            matched = service.matchmake_session(
                {"rankedOnly": True},
                user_id="matched-user",
            )

            listing = service.session_listing(matched["sessionID"])
        finally:
            service.close()

        self.assertTrue(matched["update"]["ranked"])
        self.assertTrue(listing["ranked"])
        self.assertEqual(matched["playerID"], 0)
        self.assertEqual(listing["occupiedSeats"], [0])
        self.assertEqual(listing["openSeats"], [1, 2, 3])
        self.assertEqual(listing["playerProfiles"][0]["userID"], "matched-user")

    def test_service_matchmaking_ranked_comrades_filter_does_not_seed_stranger_lobby(
        self,
    ) -> None:
        store = FakeOnlineStore()
        store.profiles["missing-comrade"] = {
            "display_name": "Missing Comrade",
            "avatar_url": "worker2",
            "comrade_code": "MISNG",
            "stats": {},
        }
        store.comrade_links["matched-user"] = {"missing-comrade"}
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            with self.assertRaises(OnlineServerError) as missing:
                service.matchmake_session(
                    {"rankedOnly": True, "comradesOnly": True},
                    user_id="matched-user",
                )
        finally:
            service.close()

        self.assertEqual(missing.exception.status, HTTPStatus.NOT_FOUND)

    def test_service_matchmaking_comrades_filter_skips_strangers(self) -> None:
        store = FakeOnlineStore()
        store.profiles["host-b"] = {
            "display_name": "Comrade Host",
            "avatar_url": "worker2",
            "comrade_code": "HOSTB",
            "stats": {},
        }
        store.comrade_links["matched-user"] = {"host-b"}
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            stranger_request = create_request()
            stranger_request["controllers"] = [
                "human",
                "human",
                "heuristicAI",
                "heuristicAI",
            ]
            service.create_session(stranger_request, user_id="host-a")

            comrade_request = create_request()
            comrade_request["controllers"] = [
                "human",
                "human",
                "human",
                "heuristicAI",
            ]
            comrade = service.create_session(comrade_request, user_id="host-b")

            matched = service.matchmake_session(
                {"comradesOnly": True},
                user_id="matched-user",
            )
        finally:
            service.close()

        self.assertEqual(matched["sessionID"], comrade["sessionID"])

    def test_service_matchmaking_prefers_closer_ratings_over_fuller_tables(self) -> None:
        store = FakeOnlineStore()
        store.profiles["matched-user"] = {
            "display_name": "New Player",
            "avatar_url": "worker1",
            "comrade_code": "MATCH",
            "stats": {"rating": 500},
        }
        store.profiles["host-high"] = {
            "display_name": "High Host",
            "avatar_url": "worker2",
            "comrade_code": "HIGH1",
            "stats": {"rating": 1600},
        }
        store.profiles["host-close"] = {
            "display_name": "Close Host",
            "avatar_url": "worker3",
            "comrade_code": "CLOSE",
            "stats": {"rating": 550},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            high_request = create_request()
            high_request["controllers"] = [
                "human",
                "human",
                "heuristicAI",
                "heuristicAI",
            ]
            high = service.create_session(high_request, user_id="host-high")

            close_request = create_request()
            close_request["controllers"] = [
                "human",
                "human",
                "human",
                "heuristicAI",
            ]
            close = service.create_session(close_request, user_id="host-close")

            matched = service.matchmake_session({}, user_id="matched-user")
            high_open_seats = service.session_listing(high["sessionID"])["openSeats"]
        finally:
            service.close()

        self.assertEqual(matched["sessionID"], close["sessionID"])
        self.assertEqual(high_open_seats, [1])

    def test_population_handler_seeds_ranked_and_casual_lobbies_per_tick(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            population_enabled=True,
        )
        try:
            service.tick()
            assert service.population_handler is not None
            service.population_handler.next_open_seat_fill_at = time.time() + 3600
            first_tick_sessions = service.list_sessions()
            service.population_handler.next_lobby_seed_at = 0.0
            service.tick()
            second_tick_sessions = service.list_sessions()
            service.population_handler.next_lobby_seed_at = 0.0
            service.tick()
            third_tick_sessions = service.list_sessions()
        finally:
            service.close()

        first_tick_open_counts = [
            len(session["openSeats"]) for session in first_tick_sessions
        ]
        self.assertEqual(len(first_tick_sessions), 2)
        self.assertEqual(len(set(first_tick_open_counts)), 2)
        self.assertTrue(set(first_tick_open_counts).issubset({1, 2, 3}))
        self.assertEqual(
            sorted(session["ranked"] for session in first_tick_sessions),
            [False, True],
        )
        self.assertEqual(len(second_tick_sessions), 4)
        self.assertEqual(len(third_tick_sessions), 6)
        self.assertTrue(
            all(
                len(session["openSeats"]) in {1, 2, 3}
                for session in third_tick_sessions
            )
        )
        for session in third_tick_sessions:
            self.assertTrue(session["browserJoinable"])
            self.assertEqual(
                len(session["playerProfiles"]),
                4 - len(session["openSeats"]),
            )
            self.assertTrue(
                all(
                    profile["userID"] in SERVER_BOT_PROFILES_BY_ID
                    for profile in session["playerProfiles"]
                )
            )
        self.assertEqual(store.finished, [])

    def test_population_handler_fills_one_open_seat_per_game_per_fill_tick(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            population_enabled=True,
        )
        try:
            service.tick()
            original_open_seats = sum(
                len(session["openSeats"]) for session in service.list_sessions()
            )
            assert service.population_handler is not None
            service.population_handler.next_open_seat_fill_at = 0.0
            service.population_handler.next_lobby_seed_at = time.time() + 3600

            service.tick()
            filled_open_seats = sum(
                len(session["openSeats"]) for session in service.list_sessions()
            )
        finally:
            service.close()

        self.assertEqual(filled_open_seats, original_open_seats - 2)
        self.assertIn(store.joined["user_id"], SERVER_BOT_PROFILES_BY_ID)

    def test_service_matches_profile_bot_by_rating_when_filling_ranked_seat(
        self,
    ) -> None:
        store = FakeOnlineStore()
        initial_bot = SERVER_BOT_PROFILES[0]
        far_bot = SERVER_BOT_PROFILES[-1]
        close_bot = SERVER_BOT_PROFILES[1]
        store.profiles[str(initial_bot["user_id"])] = {
            "display_name": initial_bot["display_name"],
            "avatar_url": initial_bot["avatar_url"],
            "stats": {"rating": 1000},
        }
        store.profiles[str(far_bot["user_id"])] = {
            "display_name": far_bot["display_name"],
            "avatar_url": far_bot["avatar_url"],
            "stats": {"rating": 1500},
        }
        store.profiles[str(close_bot["user_id"])] = {
            "display_name": close_bot["display_name"],
            "avatar_url": close_bot["avatar_url"],
            "stats": {"rating": 950},
        }
        store.profiles["human-low"] = {
            "display_name": "Human Low",
            "avatar_url": "worker3",
            "stats": {"rating": 920},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            session_id = service.create_population_session(
                bot_profiles=[initial_bot],
                open_human_seats=3,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )
            service.join_session(
                session_id,
                {"preferredPlayerID": 1},
                user_id="human-low",
            )

            filled = service.fill_open_seat_with_server_bot(
                now=time.time(),
                profiles=[far_bot, close_bot],
            )
            listing = service.session_listing(session_id)
        finally:
            service.close()

        self.assertEqual(filled["user_id"], close_bot["user_id"])
        self.assertEqual(listing["occupiedSeats"], [0, 1, 2])

    def test_service_fills_at_most_one_profile_bot_per_game_per_tick(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            session_id = service.create_population_session(
                bot_profiles=[SERVER_BOT_PROFILES[0]],
                open_human_seats=3,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )

            filled = service.fill_open_seats_with_server_bots(
                now=time.time(),
                profiles=[
                    SERVER_BOT_PROFILES[1],
                    SERVER_BOT_PROFILES[2],
                    SERVER_BOT_PROFILES[3],
                ],
            )
            listing = service.session_listing(session_id)
        finally:
            service.close()

        self.assertEqual(len(filled), 1)
        self.assertEqual(listing["occupiedSeats"], [0, 1])
        self.assertEqual(listing["openSeats"], [2, 3])

    def test_service_can_seed_ranked_population_game_without_profile_bots(
        self,
    ) -> None:
        service = KolkhozOnlineSessionService(self.engine)
        try:
            session_id = service.create_population_session(
                bot_profiles=[],
                open_human_seats=4,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )
            listing = service.session_listing(session_id)
        finally:
            service.close()

        self.assertTrue(listing["ranked"])
        self.assertEqual(listing["occupiedSeats"], [])
        self.assertEqual(listing["openSeats"], [0, 1, 2, 3])
        self.assertEqual(listing["playerProfiles"], [])

    def test_service_does_not_reuse_active_profile_bot_when_filling_seats(self) -> None:
        store = FakeOnlineStore()
        active_bot = SERVER_BOT_PROFILES[0]
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            service.create_population_session(
                bot_profiles=[active_bot],
                open_human_seats=3,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )

            filled = service.fill_open_seats_with_server_bots(
                now=time.time(),
                profiles=[active_bot],
            )
        finally:
            service.close()

        self.assertEqual(len(filled), 1)
        self.assertNotEqual(filled[0]["user_id"], active_bot["user_id"])
        self.assertEqual(filled[0]["user_id"], "factory-bot-1")

    def test_service_skips_active_profile_bot_when_seeding_population_game(self) -> None:
        store = FakeOnlineStore()
        active_bot = SERVER_BOT_PROFILES[0]
        available_bot = SERVER_BOT_PROFILES[1]
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            service.create_population_session(
                bot_profiles=[active_bot],
                open_human_seats=3,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )

            second_session_id = service.create_population_session(
                bot_profiles=[active_bot, available_bot],
                open_human_seats=3,
                ranked=True,
                now=time.time() + 1,
                population_kind="rating_seed",
            )
            listing = service.session_listing(second_session_id)
        finally:
            service.close()

        self.assertEqual(listing["playerProfiles"][0]["userID"], available_bot["user_id"])

    def test_service_creates_profile_bot_when_seeding_pool_is_short(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            session_id = service.create_population_session(
                bot_profiles=[],
                open_human_seats=3,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )
            listing = service.session_listing(session_id)
        finally:
            service.close()

        self.assertEqual(len(store.generated_profile_bots), 1)
        self.assertEqual(listing["playerProfiles"][0]["userID"], "factory-bot-1")
        self.assertEqual(listing["playerProfiles"][0]["stats"]["rating"], 1000)

    def test_service_creates_profile_bot_when_fill_pool_is_short(self) -> None:
        store = FakeOnlineStore()
        store.profiles["human-low"] = {
            "display_name": "Human Low",
            "avatar_url": "worker3",
            "stats": {"rating": 930},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            session_id = service.create_population_session(
                bot_profiles=[],
                open_human_seats=4,
                ranked=True,
                now=time.time(),
                population_kind="rating_seed",
            )
            service.join_session(
                session_id,
                {"preferredPlayerID": 0},
                user_id="human-low",
            )

            filled = service.fill_open_seats_with_server_bots(
                now=time.time(),
                profiles=[],
            )
            listing = service.session_listing(session_id)
        finally:
            service.close()

        self.assertEqual(len(filled), 1)
        self.assertEqual(filled[0]["user_id"], "factory-bot-1")
        self.assertEqual(filled[0]["stats"]["rating"], 930)
        self.assertEqual(listing["occupiedSeats"], [0, 1])

    def test_service_exposes_ordered_action_updates_for_animation_queue(self) -> None:
        created = self.service.create_session(create_request())
        joined = self.service.join_session(
            created["sessionID"],
            {"preferredPlayerID": 1},
        )
        start_revision = created["update"]["actionLogCount"]
        player_zero_actions = self.service.legal_actions(
            created["sessionID"],
            0,
            created["seatToken"],
        )
        first = self.service.submit_action(
            created["sessionID"],
            {
                "playerID": 0,
                "actionLogCount": start_revision,
                "action": player_zero_actions[0],
            },
            created["seatToken"],
        )
        player_one_actions = self.service.legal_actions(
            created["sessionID"],
            1,
            joined["seatToken"],
        )
        submitted = self.service.submit_action(
            created["sessionID"],
            {
                "playerID": 1,
                "actionLogCount": first["actionLogCount"],
                "action": player_one_actions[0],
            },
            joined["seatToken"],
        )
        queued = self.service.action_updates(
            created["sessionID"],
            0,
            start_revision,
            created["seatToken"],
        )

        self.assertGreaterEqual(submitted["actionLogCount"], start_revision + 2)
        revisions = [entry["revision"] for entry in queued["updates"]]
        self.assertEqual(
            revisions,
            list(range(start_revision + 1, submitted["actionLogCount"] + 1)),
        )
        self.assertEqual(
            queued["updates"][-1]["update"]["actionLogCount"],
            submitted["actionLogCount"],
        )

    def test_service_lists_open_sessions(self) -> None:
        created = self.service.create_session(create_request())
        sessions = self.service.list_sessions()

        self.assertEqual(len(sessions), 1)
        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(sessions[0]["openSeats"], [1])
        self.assertEqual(sessions[0]["occupiedSeats"], [0, 2, 3])

        self.service.join_session(created["sessionID"], {"preferredPlayerID": 1})
        self.assertEqual(self.service.list_sessions(), [])
        listing = self.service.session_listing(created["sessionID"])
        self.assertEqual(listing["sessionID"], created["sessionID"])
        self.assertEqual(listing["openSeats"], [])
        self.assertEqual(listing["occupiedSeats"], [0, 1, 2, 3])
        self.assertGreater(listing["expiresAt"], listing["createdAt"])
        self.assertEqual(DEFAULT_SESSION_TTL_SECONDS, 30 * 60)
        self.assertAlmostEqual(
            listing["expiresAt"] - listing["createdAt"],
            DEFAULT_SESSION_TTL_SECONDS,
            delta=1.0,
        )

    def test_service_hides_locked_sessions_from_browser_and_forces_casual(self) -> None:
        request = create_request()
        request["ranked"] = True
        request["browserJoinable"] = False

        created = self.service.create_session(request)

        self.assertFalse(created["update"]["ranked"])
        self.assertFalse(created["update"]["browserJoinable"])
        self.assertEqual(self.service.list_sessions(), [])

        listing = self.service.session_listing(created["sessionID"])
        self.assertEqual(listing["openSeats"], [1])
        self.assertFalse(listing["ranked"])
        self.assertFalse(listing["browserJoinable"])

        joined = self.service.join_session(
            created["sessionID"],
            {"preferredPlayerID": 1},
        )
        self.assertEqual(joined["playerID"], 1)
        self.assertFalse(joined["update"]["ranked"])
        self.assertFalse(joined["update"]["browserJoinable"])

    def test_service_invites_comrade_to_private_session(self) -> None:
        store = FakeOnlineStore()
        store.profiles["host-user"] = {
            "display_name": "Host",
            "avatar_url": None,
            "stats": {},
        }
        store.profiles["comrade-user"] = {
            "display_name": "Comrade",
            "avatar_url": None,
            "stats": {},
        }
        store.comrade_links["host-user"] = {"comrade-user"}
        store.comrade_links["comrade-user"] = {"host-user"}
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,  # type: ignore[arg-type]
            lobby_countdown_seconds=0,
        )
        try:
            request = create_request()
            request["browserJoinable"] = False
            created = service.create_session(request, user_id="host-user")

            with self.assertRaises(OnlineServerError) as forbidden_invite:
                service.invite_session_comrades(
                    created["sessionID"],
                    {"userIDs": ["stranger-user"]},
                    user_id="host-user",
                )
            self.assertEqual(forbidden_invite.exception.status, HTTPStatus.FORBIDDEN)

            invited = service.invite_session_comrades(
                created["sessionID"],
                {"userIDs": ["comrade-user"]},
                user_id="host-user",
            )
            self.assertEqual(invited["invitedUserIDs"], ["comrade-user"])

            self.assertEqual(service.pending_session_invites(user_id="stranger-user"), [])
            pending = service.pending_session_invites(user_id="comrade-user")
            self.assertEqual(len(pending), 1)
            self.assertEqual(pending[0]["sessionID"], created["sessionID"])
            self.assertNotIn("inviteCode", pending[0])

            with self.assertRaises(OnlineServerError) as forbidden_join:
                service.join_session(
                    created["sessionID"],
                    {"preferredPlayerID": 1},
                    user_id="stranger-user",
                )
            self.assertEqual(forbidden_join.exception.status, HTTPStatus.FORBIDDEN)

            declined = service.decline_session_invite(
                created["sessionID"],
                user_id="comrade-user",
            )
            self.assertEqual(declined["declined"], True)
            self.assertEqual(service.pending_session_invites(user_id="comrade-user"), [])

            with self.assertRaises(OnlineServerError) as declined_join:
                service.join_session(
                    created["sessionID"],
                    {"preferredPlayerID": 1},
                    user_id="comrade-user",
                )
            self.assertEqual(declined_join.exception.status, HTTPStatus.FORBIDDEN)

            service.invite_session_comrades(
                created["sessionID"],
                {"userIDs": ["comrade-user"]},
                user_id="host-user",
            )
            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
                user_id="comrade-user",
            )
            self.assertEqual(joined["playerID"], 1)
            self.assertEqual(service.pending_session_invites(user_id="comrade-user"), [])
        finally:
            service.close()

    def test_expired_sessions_are_pruned(self) -> None:
        service = KolkhozOnlineSessionService(self.engine, session_ttl_seconds=0.001)
        try:
            created = service.create_session(create_request())
            service._sessions[created["sessionID"]].last_seen_at = 0
            self.assertEqual(service.list_sessions(), [])
            with self.assertRaises(OnlineServerError) as missing:
                service.session_listing(created["sessionID"])
            self.assertEqual(missing.exception.status, HTTPStatus.NOT_FOUND)
        finally:
            service.close()

    def test_service_persists_sessions_seats_and_actions_when_store_configured(
        self,
    ) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            lobby_countdown_seconds=0,
        )
        try:
            created = service.create_session(create_request())
            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
            )
            actions = service.legal_actions(
                created["sessionID"],
                0,
                created["seatToken"],
            )
            service.submit_action(
                created["sessionID"],
                {
                    "playerID": 0,
                    "actionLogCount": created["update"]["actionLogCount"],
                    "action": actions[0],
                },
                created["seatToken"],
            )
        finally:
            service.close()

        self.assertEqual(store.created["session_id"], created["sessionID"])
        self.assertEqual(store.created["seed"], 123)
        self.assertEqual(store.created["seat_token_hashes"][0], seat_token_hash(created["seatToken"]))
        self.assertEqual(store.joined["session_id"], created["sessionID"])
        self.assertEqual(store.joined["player_id"], joined["playerID"])
        self.assertEqual(store.actions[0]["revision"], 1)
        self.assertEqual(store.actions[0]["player_id"], 0)
        self.assertEqual(store.closed, True)

    def test_service_recovers_persisted_session_after_restart(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            lobby_countdown_seconds=0,
        )
        try:
            request = create_request()
            request["controllers"] = [
                "human",
                "heuristicAI",
                "heuristicAI",
                "heuristicAI",
            ]
            created = service.create_session(request)
            actions = service.legal_actions(
                created["sessionID"],
                0,
                created["seatToken"],
            )
            submitted = service.submit_action(
                created["sessionID"],
                {
                    "playerID": 0,
                    "actionLogCount": created["update"]["actionLogCount"],
                    "action": actions[0],
                },
                created["seatToken"],
            )
        finally:
            service.close()

        recovered = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            self.assertEqual(recovered._sessions, {})
            state = recovered.update(
                created["sessionID"],
                0,
                created["seatToken"],
            )
            updates = recovered.action_updates(
                created["sessionID"],
                0,
                0,
                created["seatToken"],
            )
        finally:
            recovered.close()

        self.assertEqual(state["sessionID"], created["sessionID"])
        self.assertEqual(state["actionLogCount"], submitted["actionLogCount"])
        self.assertEqual(updates["actionLogCount"], submitted["actionLogCount"])
        self.assertEqual(
            [entry["revision"] for entry in updates["updates"]],
            list(range(1, submitted["actionLogCount"] + 1)),
        )

    def test_service_rolls_back_join_when_persistence_fails(self) -> None:
        store = FailingJoinStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            with self.assertRaises(OnlineServerError) as failed_join:
                service.join_session(
                    created["sessionID"],
                    {"preferredPlayerID": 1},
                    user_id="22222222-2222-2222-2222-222222222222",
                )
            self.assertEqual(
                failed_join.exception.status,
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )

            hosted = service._sessions[created["sessionID"]]
            self.assertEqual(hosted.occupied_seats, {0, 2, 3})
            self.assertNotIn(1, hosted.seat_tokens)
            self.assertNotIn(1, hosted.seat_user_ids)
            self.assertEqual(service.list_sessions()[0]["openSeats"], [1])

            store.fail_join = False
            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
                user_id="22222222-2222-2222-2222-222222222222",
            )
        finally:
            service.close()

        self.assertEqual(joined["playerID"], 1)
        self.assertEqual(store.joined["player_id"], 1)

    def test_service_host_can_kick_joined_player_before_game_starts(self) -> None:
        created = self.service.create_session(
            create_request(),
            user_id="11111111-1111-1111-1111-111111111111",
        )
        joined = self.service.join_session(
            created["sessionID"],
            {"preferredPlayerID": 1},
            user_id="22222222-2222-2222-2222-222222222222",
        )

        kicked = self.service.kick_session_player(
            created["sessionID"],
            joined["playerID"],
            {"hostPlayerID": created["playerID"]},
            created["seatToken"],
            user_id="11111111-1111-1111-1111-111111111111",
        )

        listing = self.service.session_listing(created["sessionID"])
        self.assertEqual(kicked["playerID"], 0)
        self.assertIn(1, listing["openSeats"])
        self.assertNotIn(1, listing["occupiedSeats"])
        self.assertFalse(
            any(profile["playerID"] == 1 for profile in listing["playerProfiles"])
        )

    def test_service_rejects_kick_from_non_host(self) -> None:
        created = self.service.create_session(
            create_request(),
            user_id="11111111-1111-1111-1111-111111111111",
        )
        joined = self.service.join_session(
            created["sessionID"],
            {"preferredPlayerID": 1},
            user_id="22222222-2222-2222-2222-222222222222",
        )

        with self.assertRaises(OnlineServerError) as denied:
            self.service.kick_session_player(
                created["sessionID"],
                created["playerID"],
                {"hostPlayerID": joined["playerID"]},
                joined["seatToken"],
                user_id="22222222-2222-2222-2222-222222222222",
            )

        self.assertEqual(denied.exception.status, HTTPStatus.FORBIDDEN)

    def test_service_times_out_human_turn_with_autopilot_action(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
            )
            hosted = service._sessions[created["sessionID"]]
            hosted.lobby_countdown_ends_at = 0.0
            service._sync_lobby_state(hosted, time.time())
            hosted.turn_player_id = 0
            hosted.turn_deadline_at = 0.0

            service.tick()
        finally:
            service.close()

        self.assertEqual(len(store.actions), 1)
        self.assertEqual(store.actions[0]["player_id"], 0)
        self.assertEqual(len(store.timeouts), 1)
        self.assertEqual(store.timeouts[0]["player_id"], 0)
        self.assertEqual(store.timeouts[0]["timeouts"], 1)
        self.assertEqual(store.timeouts[0]["autopilot"], False)

    def test_service_abandons_seat_after_repeated_timeouts(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
            service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
                user_id="22222222-2222-2222-2222-222222222222",
            )
            hosted = service._sessions[created["sessionID"]]
            hosted.lobby_countdown_ends_at = 0.0
            service._sync_lobby_state(hosted, time.time())
            hosted.turn_player_id = 0
            hosted.turn_deadline_at = 0.0
            hosted.seat_timeouts[0] = 1

            service.tick()
        finally:
            service.close()

        self.assertEqual(len(store.timeouts), 1)
        self.assertEqual(store.timeouts[0]["player_id"], 0)
        self.assertEqual(store.timeouts[0]["timeouts"], 2)
        self.assertEqual(store.timeouts[0]["autopilot"], True)
        self.assertEqual(len(store.abandoned), 1)
        self.assertEqual(store.abandoned[0]["player_id"], 0)
        self.assertEqual(
            store.abandoned[0]["user_id"],
            "11111111-1111-1111-1111-111111111111",
        )

    def test_service_list_sessions_does_not_resolve_timeouts(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            hosted = service._sessions[created["sessionID"]]
            hosted.turn_player_id = 0
            hosted.turn_deadline_at = 0.0

            sessions = service.list_sessions()
        finally:
            service.close()

        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(store.actions, [])
        self.assertEqual(store.timeouts, [])
        self.assertEqual(store.abandoned, [])

    def test_service_stops_timeout_loop_when_autopilot_has_no_action(self) -> None:
        class FakeEngine:
            def waiting_player(self, pointer: object) -> int:
                return 0

            def heuristic_action(self, pointer: object):
                return make_action(4, 1)

            def legal_actions(self, pointer: object) -> list[object]:
                return []

            def free_engine(self, pointer: object) -> None:
                pass

        engine = FakeEngine()
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            engine,
            session_ttl_seconds=0,
        )
        hosted = HostedSession(
            session_id="11111111-1111-1111-1111-111111111111",
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(
                ctypes.pointer(KCEngineSnapshot()),
                ctypes.c_void_p,
            ),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "heuristicAI", "heuristicAI"],
            ranked=False,
            browser_joinable=True,
            population_kind=None,
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0"},
            seat_token_hashes={0: seat_token_hash("seat-0")},
            seat_user_ids={},
            server_bot_controllers={},
            bot_action_ready_at={},
            created_by_user_id=None,
            action_log=[],
            action_update_cache=[],
            created_at=0.0,
            last_seen_at=0.0,
            last_persisted_touch_at=0.0,
            seat_last_seen_at={0: 0.0},
            seat_timeouts={0: 2},
            autopilot_seats={0},
            abandoned_seats={0},
            turn_player_id=None,
            turn_deadline_at=None,
        )
        try:
            start_hosted_through_lobby(service, hosted, now=70.0)
            service._resolve_turn_timeouts(hosted, now=100.0)
        finally:
            service.close()

        self.assertEqual(hosted.action_log, [])
        self.assertIsNone(hosted.turn_deadline_at)

    def test_service_leave_before_first_action_vacates_seat_without_penalty(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
            response = service.leave_session(
                created["sessionID"],
                created["playerID"],
                created["seatToken"],
                user_id="11111111-1111-1111-1111-111111111111",
            )
        finally:
            service.close()

        self.assertEqual(response["penalty"], {})
        self.assertNotIn(created["sessionID"], service._sessions)
        self.assertEqual(len(store.expired), 1)
        self.assertEqual(store.expired[0]["session_id"], created["sessionID"])
        self.assertEqual(len(store.lobby_left), 0)
        self.assertEqual(len(store.abandoned), 0)

    def test_service_records_explicit_leave_and_autopilots_started_game_seat(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            lobby_countdown_seconds=0,
        )
        try:
            request = create_request()
            request["controllers"] = [
                "human",
                "heuristicAI",
                "heuristicAI",
                "heuristicAI",
            ]
            created = service.create_session(
                request,
                user_id="11111111-1111-1111-1111-111111111111",
            )
            actions = service.legal_actions(
                created["sessionID"],
                created["playerID"],
                created["seatToken"],
            )
            service.submit_action(
                created["sessionID"],
                {
                    "playerID": created["playerID"],
                    "actionLogCount": created["update"]["actionLogCount"],
                    "action": actions[0],
                },
                created["seatToken"],
                user_id="11111111-1111-1111-1111-111111111111",
            )
            response = service.leave_session(
                created["sessionID"],
                created["playerID"],
                created["seatToken"],
                user_id="11111111-1111-1111-1111-111111111111",
            )
            hosted = service._sessions[created["sessionID"]]
        finally:
            service.close()

        self.assertEqual(response["penalty"]["strikes"], 1)
        self.assertIn(0, hosted.abandoned_seats)
        self.assertIn(0, hosted.autopilot_seats)
        self.assertEqual(len(store.lobby_left), 0)
        self.assertEqual(len(store.abandoned), 1)
        self.assertEqual(
            store.abandoned[0]["user_id"],
            "11111111-1111-1111-1111-111111111111",
        )

    def test_service_allows_private_create_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["11111111-1111-1111-1111-111111111111"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
        finally:
            service.close()

        self.assertEqual(created["playerID"], 0)
        self.assertEqual(
            store.created["created_by_user_id"],
            "11111111-1111-1111-1111-111111111111",
        )

    def test_service_rejects_matchmaking_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["22222222-2222-2222-2222-222222222222"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            with self.assertRaises(OnlineServerError) as denied:
                service.matchmake_session(
                    {},
                    user_id="22222222-2222-2222-2222-222222222222",
                )
        finally:
            service.close()

        self.assertEqual(denied.exception.status, HTTPStatus.FORBIDDEN)
        self.assertIn("sent north", denied.exception.message)

    def test_service_rejects_public_browser_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["22222222-2222-2222-2222-222222222222"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            with self.assertRaises(OnlineServerError) as denied:
                service.list_sessions(
                    user_id="22222222-2222-2222-2222-222222222222",
                )
        finally:
            service.close()

        self.assertEqual(denied.exception.status, HTTPStatus.FORBIDDEN)
        self.assertIn("sent north", denied.exception.message)

    def test_service_rejects_join_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["22222222-2222-2222-2222-222222222222"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            with self.assertRaises(OnlineServerError) as denied:
                service.join_session(
                    created["sessionID"],
                    {"preferredPlayerID": 1},
                    user_id="22222222-2222-2222-2222-222222222222",
                )
        finally:
            service.close()

        self.assertEqual(denied.exception.status, HTTPStatus.FORBIDDEN)
        self.assertIn("sent north", denied.exception.message)

    def test_service_allows_invite_code_join_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["22222222-2222-2222-2222-222222222222"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            joined = service.join_session(
                created["inviteCode"],
                {"preferredPlayerID": 1},
                user_id="22222222-2222-2222-2222-222222222222",
            )
        finally:
            service.close()

        self.assertEqual(joined["playerID"], 1)
        self.assertEqual(
            store.joined["user_id"],
            "22222222-2222-2222-2222-222222222222",
        )

    def test_auth_enabled_server_rejects_anonymous_online_create_and_join(self) -> None:
        class FakeAuthVerifier:
            def user_id_from_authorization(self, authorization: str | None) -> str | None:
                return None

        service = KolkhozOnlineSessionService(
            self.engine,
            auth_verifier=FakeAuthVerifier(),  # type: ignore[arg-type]
        )
        try:
            with self.assertRaises(OnlineServerError) as create_denied:
                service.create_session(create_request())
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
            with self.assertRaises(OnlineServerError) as join_denied:
                service.join_session(
                    created["sessionID"],
                    {"preferredPlayerID": 1},
                )
        finally:
            service.close()

        self.assertEqual(create_denied.exception.status, HTTPStatus.UNAUTHORIZED)
        self.assertEqual(join_denied.exception.status, HTTPStatus.UNAUTHORIZED)

    def test_service_persists_supabase_user_ids_when_authenticated(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
            joined = service.join_session(
                created["sessionID"],
                {"preferredPlayerID": 1},
                user_id="22222222-2222-2222-2222-222222222222",
            )
        finally:
            service.close()

        self.assertEqual(
            store.created["created_by_user_id"],
            "11111111-1111-1111-1111-111111111111",
        )
        self.assertEqual(
            store.created["seat_user_ids"][0],
            "11111111-1111-1111-1111-111111111111",
        )
        self.assertEqual(set(store.created["seat_user_ids"]), {0, 2, 3})
        for player_id in (2, 3):
            bot_profile = SERVER_BOT_PROFILES_BY_ID[
                store.created["seat_user_ids"][player_id]
            ]
            self.assertEqual(bot_profile["controller"], "heuristicAI")
        self.assertEqual(store.joined["player_id"], joined["playerID"])
        self.assertEqual(
            store.joined["user_id"],
            "22222222-2222-2222-2222-222222222222",
        )

    def test_service_manages_comrade_requests_by_short_code(self) -> None:
        store = FakeOnlineStore()
        user_id = "11111111-1111-1111-1111-111111111111"
        comrade_id = "22222222-2222-2222-2222-222222222222"
        store.profiles[comrade_id] = {
            "display_name": "Comrade Vera",
            "avatar_url": "worker2",
            "comrade_code": "VERA2",
            "stats": {"rating": 1234},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            initial = service.comrades(user_id=user_id)
            sent = service.send_comrade_request(
                {"comradeCode": "vera2"},
                user_id=user_id,
            )
            requester_listed = service.comrades(user_id=user_id)
            addressee_listed = service.comrades(user_id=comrade_id)
            accepted = service.respond_to_comrade_request(
                {"userID": user_id, "accept": True},
                user_id=comrade_id,
            )
            listed = service.comrades(user_id=user_id)
            removed = service.remove_comrade(
                {"userID": comrade_id},
                user_id=user_id,
            )
            after_remove = service.comrades(user_id=user_id)
        finally:
            service.close()

        self.assertEqual(initial["comradeCode"], "11111")
        self.assertEqual(sent["request"]["userID"], comrade_id)
        self.assertEqual(sent["request"]["displayName"], "Comrade Vera")
        self.assertEqual(requester_listed["outgoingRequests"][0]["userID"], comrade_id)
        self.assertEqual(addressee_listed["incomingRequests"][0]["userID"], user_id)
        self.assertEqual(accepted["accepted"], True)
        self.assertEqual(accepted["comrade"]["userID"], user_id)
        self.assertEqual(listed["comrades"][0]["userID"], comrade_id)
        self.assertEqual(removed, {"removed": True})
        self.assertEqual(after_remove["comrades"], [])
        self.assertEqual(store.abandoned_startups, 0)

    def test_service_reports_comrade_presence_and_game_status(self) -> None:
        store = FakeOnlineStore()
        user_id = "11111111-1111-1111-1111-111111111111"
        comrade_id = "22222222-2222-2222-2222-222222222222"
        store.profiles[user_id] = {
            "display_name": "Comrade Misha",
            "avatar_url": "worker1",
            "comrade_code": "MISHA",
            "stats": {},
        }
        store.profiles[comrade_id] = {
            "display_name": "Comrade Vera",
            "avatar_url": "worker2",
            "comrade_code": "VERA2",
            "stats": {},
        }
        store.comrade_links[user_id] = {comrade_id}
        store.comrade_links[comrade_id] = {user_id}
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            service.mark_online_presence(user_id=comrade_id)
            created = service.create_session(
                create_request(),
                user_id=comrade_id,
            )
            listed = service.comrades(user_id=user_id)["comrades"][0]
            hosted = service._sessions[created["sessionID"]]
            hosted.started = True
            playing = service.comrades(user_id=user_id)["comrades"][0]
        finally:
            service.close()

        self.assertEqual(listed["userID"], comrade_id)
        self.assertEqual(listed["isOnline"], True)
        self.assertEqual(listed["inLobby"], True)
        self.assertEqual(listed["inGame"], False)
        self.assertEqual(playing["isOnline"], True)
        self.assertEqual(playing["inLobby"], False)
        self.assertEqual(playing["inGame"], True)

    def test_service_declines_comrade_request(self) -> None:
        store = FakeOnlineStore()
        user_id = "11111111-1111-1111-1111-111111111111"
        target_id = "22222222-2222-2222-2222-222222222222"
        store.profiles[user_id] = {
            "display_name": "Comrade Misha",
            "avatar_url": "worker1",
            "comrade_code": "MISHA",
            "stats": {"rating": 1011},
        }
        store.profiles[target_id] = {
            "display_name": "Comrade Vera",
            "avatar_url": "worker2",
            "comrade_code": "VERA2",
            "stats": {"rating": 1234},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            service.send_comrade_request({"comradeCode": "VERA2"}, user_id=user_id)
            declined = service.respond_to_comrade_request(
                {"userID": user_id, "accept": False},
                user_id=target_id,
            )
            listed = service.comrades(user_id=target_id)
        finally:
            service.close()

        self.assertEqual(declined, {"accepted": False})
        self.assertEqual(listed["incomingRequests"], [])
        self.assertEqual(store.comrade_links.get(user_id), None)

    def test_service_manages_comrade_requests_by_user_id(self) -> None:
        store = FakeOnlineStore()
        user_id = "11111111-1111-1111-1111-111111111111"
        target_id = "22222222-2222-2222-2222-222222222222"
        store.profiles[user_id] = {
            "display_name": "Comrade Misha",
            "avatar_url": "worker1",
            "comrade_code": "MISHA",
            "stats": {"rating": 1011},
        }
        store.profiles[target_id] = {
            "display_name": "Comrade Vera",
            "avatar_url": "worker2",
            "comrade_code": "VERA2",
            "stats": {"rating": 1234},
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            sent = service.send_comrade_request(
                {"userID": target_id},
                user_id=user_id,
            )
            accepted = service.send_comrade_request(
                {"userID": user_id},
                user_id=target_id,
            )
            listed = service.comrades(user_id=user_id)
        finally:
            service.close()

        self.assertEqual(sent["request"]["userID"], target_id)
        self.assertEqual(accepted["comrade"]["userID"], user_id)
        self.assertEqual(listed["comrades"][0]["userID"], target_id)

    def test_service_records_online_results_once_when_game_finishes(self) -> None:
        class FakeEngine:
            def waiting_player(self, pointer: object) -> int:
                return -1

            def free_engine(self, pointer: object) -> None:
                pass

        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            FakeEngine(),
            store=store,
            session_ttl_seconds=0,
        )
        state = KCEngineSnapshot()
        state.phase = PHASE_GAME_OVER
        state.winner_id = 1
        state.game_scores[0] = 12
        state.game_scores[1] = 30
        state.game_scores[2] = 20
        state.game_scores[3] = 5
        hosted = HostedSession(
            session_id="11111111-1111-1111-1111-111111111111",
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(ctypes.pointer(state), ctypes.c_void_p),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "heuristicAI", "heuristicAI"],
            ranked=True,
            browser_joinable=True,
            population_kind=None,
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_token_hashes={
                0: seat_token_hash("seat-0"),
                1: seat_token_hash("seat-1"),
            },
            seat_user_ids={
                0: "11111111-1111-1111-1111-111111111111",
                1: "22222222-2222-2222-2222-222222222222",
            },
            server_bot_controllers={},
            bot_action_ready_at={},
            created_by_user_id="11111111-1111-1111-1111-111111111111",
            action_log=[],
            action_update_cache=[],
            created_at=1.0,
            last_seen_at=2.0,
            last_persisted_touch_at=1.0,
            seat_last_seen_at={0: 2.0, 1: 2.0},
            seat_timeouts={},
            autopilot_seats=set(),
            abandoned_seats=set(),
            turn_player_id=None,
            turn_deadline_at=None,
        )
        try:
            start_hosted_through_lobby(service, hosted, now=0.0)
            service._persist_finished_if_needed(hosted)
            service._persist_finished_if_needed(hosted)
        finally:
            service.close()

        self.assertEqual(len(store.finished), 1)
        self.assertEqual(store.finished[0]["session_id"], hosted.session_id)
        self.assertEqual(
            store.finished[0]["results"],
            [
                {
                    "player_id": 0,
                    "user_id": "11111111-1111-1111-1111-111111111111",
                    "controller": "human",
                    "score": 12,
                    "rank": 3,
                    "won": False,
                },
                {
                    "player_id": 1,
                    "user_id": "22222222-2222-2222-2222-222222222222",
                    "controller": "human",
                    "score": 30,
                    "rank": 1,
                    "won": True,
                },
                {
                    "player_id": 2,
                    "user_id": None,
                    "controller": "heuristicAI",
                    "score": 20,
                    "rank": 2,
                    "won": False,
                },
                {
                    "player_id": 3,
                    "user_id": None,
                    "controller": "heuristicAI",
                    "score": 5,
                    "rank": 4,
                    "won": False,
                },
            ],
        )

    def test_service_exposes_player_profiles_when_store_has_profiles(self) -> None:
        store = FakeOnlineStore()
        store.profiles = {
            "11111111-1111-1111-1111-111111111111": {
                "display_name": "Mira",
                "avatar_url": "worker3",
                "stats": {
                    "games_played": 3,
                    "wins_total": 2,
                    "offline_games": 1,
                    "offline_wins": 1,
                    "online_games": 2,
                    "online_wins": 1,
                    "rating": 1016,
                },
            }
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(
                create_request(),
                user_id="11111111-1111-1111-1111-111111111111",
            )
            listing = service.session_listing(created["sessionID"])
        finally:
            service.close()

        self.assertEqual(
            created["update"]["playerProfiles"][0]["displayName"],
            "Mira",
        )
        self.assertEqual(listing["playerProfiles"][0]["avatarURL"], "worker3")
        self.assertEqual(
            listing["playerProfiles"][0]["stats"]["online_wins"],
            1,
        )

    def test_authenticated_seats_reject_mismatched_supabase_user_id(self) -> None:
        class FakeAuthVerifier:
            def user_id_from_authorization(self, authorization: str | None) -> str:
                return "wrong-user"

        service = KolkhozOnlineSessionService(
            self.engine,
            auth_verifier=FakeAuthVerifier(),  # type: ignore[arg-type]
        )
        try:
            created = service.create_session(
                create_request(),
                user_id="right-user",
            )
            with self.assertRaises(OnlineServerError) as unauthorized:
                service.update(
                    created["sessionID"],
                    0,
                    created["seatToken"],
                    user_id="wrong-user",
                )
        finally:
            service.close()

        self.assertEqual(unauthorized.exception.status, HTTPStatus.UNAUTHORIZED)

    def test_requisition_continue_stays_with_engine_owner(self) -> None:
        class FakeEngine:
            def __init__(self) -> None:
                self.action = make_action(kind=7, player_id=0)

            def legal_actions(self, pointer: object) -> list[object]:
                return [self.action]

            def waiting_player(self, pointer: object) -> int:
                return 0

            def free_engine(self, pointer: object) -> None:
                pass

        session_id = "11111111-1111-1111-1111-111111111111"
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            FakeEngine(),
            session_ttl_seconds=0,
        )
        service._sessions[session_id] = HostedSession(
            session_id=session_id,
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(
                ctypes.pointer(KCEngineSnapshot()),
                ctypes.c_void_p,
            ),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "heuristicAI", "heuristicAI"],
            ranked=True,
            browser_joinable=True,
            population_kind=None,
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_token_hashes={
                0: seat_token_hash("seat-0"),
                1: seat_token_hash("seat-1"),
            },
            seat_user_ids={},
            server_bot_controllers={},
            bot_action_ready_at={},
            created_by_user_id=None,
            action_log=[],
            action_update_cache=[],
            created_at=0.0,
            last_seen_at=0.0,
            last_persisted_touch_at=0.0,
            seat_last_seen_at={0: 0.0, 1: 0.0},
            seat_timeouts={},
            autopilot_seats=set(),
            abandoned_seats=set(),
            turn_player_id=None,
            turn_deadline_at=None,
        )
        start_hosted_through_lobby(
            service,
            service._sessions[session_id],
            now=time.time(),
        )

        try:
            self.assertEqual(
                service.legal_actions(session_id, 0, "seat-0")[0]["playerID"],
                0,
            )
            self.assertEqual(service.legal_actions(session_id, 1, "seat-1"), [])
        finally:
            service.close()

    def test_service_advances_neural_and_heuristic_ai_to_next_human(self) -> None:
        class FakeEngine:
            def __init__(self) -> None:
                self.waiting = [2, 3, 0, 1]
                self.policy_steps = 0
                self.heuristic_steps = 0

            def waiting_player(self, pointer: object) -> int:
                return self.waiting[0]

            def step_policy_automatic(self, pointer: object, model: object) -> int:
                self.policy_steps += 1
                self.waiting.pop(0)
                return 1

            def step_automatic(self, pointer: object) -> int:
                self.heuristic_steps += 1
                self.waiting.pop(0)
                return 1

            def free_engine(self, pointer: object) -> None:
                pass

        engine = FakeEngine()
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            engine,
            session_ttl_seconds=0,
            policy_artifact=PolicyArtifact.scratch(
                hidden_layers=[1],
                seed=1,
                scale=0.01,
            ),
        )
        hosted = HostedSession(
            session_id="11111111-1111-1111-1111-111111111111",
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(
                ctypes.pointer(KCEngineSnapshot()),
                ctypes.c_void_p,
            ),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["mediumAI", "human", "neuralAI", "heuristicAI"],
            ranked=True,
            browser_joinable=True,
            population_kind="rating_seed",
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_token_hashes={
                0: seat_token_hash("seat-0"),
                1: seat_token_hash("seat-1"),
            },
            seat_user_ids={},
            server_bot_controllers={},
            bot_action_ready_at={},
            created_by_user_id=None,
            action_log=[],
            action_update_cache=[],
            created_at=0.0,
            last_seen_at=0.0,
            last_persisted_touch_at=0.0,
            seat_last_seen_at={0: 0.0, 1: 0.0},
            seat_timeouts={},
            autopilot_seats=set(),
            abandoned_seats=set(),
            turn_player_id=None,
            turn_deadline_at=None,
        )
        try:
            start_hosted_through_lobby(service, hosted, now=0.0)
        finally:
            service.close()

        self.assertEqual(engine.policy_steps, 2)
        self.assertEqual(engine.heuristic_steps, 1)
        self.assertEqual(engine.waiting, [1])

    def test_service_delays_bot_actions_in_human_visible_games(self) -> None:
        class FakeEngine:
            def __init__(self) -> None:
                self.waiting = 0
                self.action = make_action(4, 0)
                self.applied = 0

            def waiting_player(self, pointer: object) -> int:
                return self.waiting

            def heuristic_action(self, pointer: object):
                return self.action

            def legal_actions(self, pointer: object) -> list[object]:
                return [self.action]

            def apply_ai_action(self, pointer: object, action: object) -> None:
                self.applied += 1
                self.waiting = 1

            def free_engine(self, pointer: object) -> None:
                pass

        engine = FakeEngine()
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            engine,
            session_ttl_seconds=0,
        )
        service._cache_action_update = lambda *args, **kwargs: None  # type: ignore[method-assign]
        hosted = HostedSession(
            session_id="11111111-1111-1111-1111-111111111111",
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(
                ctypes.pointer(KCEngineSnapshot()),
                ctypes.c_void_p,
            ),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["heuristicAI", "human", "human", "human"],
            ranked=True,
            browser_joinable=True,
            population_kind="open_lobby_seed",
            occupied_seats={0, 1, 2, 3},
            seat_tokens={0: "seat-0"},
            seat_token_hashes={0: seat_token_hash("seat-0")},
            seat_user_ids={
                0: "00000000-0000-4000-8000-000000000101",
            },
            server_bot_controllers={},
            bot_action_ready_at={},
            created_by_user_id=None,
            action_log=[],
            action_update_cache=[],
            created_at=0.0,
            last_seen_at=0.0,
            last_persisted_touch_at=0.0,
            seat_last_seen_at={0: 0.0},
            seat_timeouts={},
            autopilot_seats=set(),
            abandoned_seats=set(),
            turn_player_id=None,
            turn_deadline_at=None,
        )
        try:
            start_hosted_through_lobby(service, hosted, now=70.0)
            ready_at = hosted.bot_action_ready_at[0]
            service._advance_automatic_turns(hosted, now=ready_at - 0.01)
            self.assertEqual(engine.applied, 0)
            self.assertEqual(len(hosted.action_log), 0)
            self.assertGreaterEqual(
                ready_at - 100.0,
                BOT_HUMAN_GAME_ACTION_DELAY_MIN_SECONDS,
            )
            self.assertLessEqual(
                ready_at - 100.0,
                BOT_HUMAN_GAME_ACTION_DELAY_MAX_SECONDS,
            )

            service._advance_automatic_turns(hosted, now=ready_at)
        finally:
            service.close()

        self.assertEqual(engine.applied, 1)
        self.assertEqual(len(hosted.action_log), 1)
        self.assertNotIn(0, hosted.bot_action_ready_at)

    def test_profile_bot_policy_uses_effective_controller_for_human_seat(self) -> None:
        class FakeEngine:
            def __init__(self) -> None:
                self.waiting = 1
                self.policy_action_value = make_action(4, 1)
                self.fallback_action = make_action(9, 1)
                self.applied: list[object] = []
                self.policy_calls = 0

            def waiting_player(self, pointer: object) -> int:
                return self.waiting

            def policy_action(self, pointer: object, model: object):
                self.policy_calls += 1
                state = ctypes.cast(
                    pointer,
                    ctypes.POINTER(KCEngineSnapshot),
                ).contents
                if state.controllers.seats[1] != 2:
                    return None
                return self.policy_action_value

            def legal_actions(self, pointer: object) -> list[object]:
                return [self.fallback_action]

            def apply_ai_action(self, pointer: object, action: object) -> None:
                self.applied.append(action)
                self.waiting = 0

            def free_engine(self, pointer: object) -> None:
                pass

        state = KCEngineSnapshot()
        state.controllers.seats[1] = 0
        engine = FakeEngine()
        service = KolkhozOnlineSessionService(  # type: ignore[arg-type]
            engine,
            session_ttl_seconds=0,
            policy_artifact=PolicyArtifact.scratch(
                hidden_layers=[1],
                seed=1,
                scale=0.01,
            ),
        )
        service._cache_action_update = lambda *args, **kwargs: None  # type: ignore[method-assign]
        hosted = HostedSession(
            session_id="11111111-1111-1111-1111-111111111111",
            invite_code="ABCDE",
            engine_pointer=ctypes.cast(ctypes.pointer(state), ctypes.c_void_p),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "human", "human"],
            ranked=True,
            browser_joinable=True,
            population_kind="open_lobby_seed",
            occupied_seats={0, 1, 2, 3},
            seat_tokens={1: "seat-1"},
            seat_token_hashes={1: seat_token_hash("seat-1")},
            seat_user_ids={1: "00000000-0000-4000-8000-000000000301"},
            server_bot_controllers={1: "neuralAI"},
            bot_action_ready_at={1: 0.0},
            created_by_user_id=None,
            action_log=[],
            action_update_cache=[],
            created_at=0.0,
            last_seen_at=0.0,
            last_persisted_touch_at=0.0,
            seat_last_seen_at={1: 0.0},
            seat_timeouts={},
            autopilot_seats=set(),
            abandoned_seats=set(),
            turn_player_id=None,
            turn_deadline_at=None,
        )
        try:
            start_hosted_through_lobby(service, hosted, now=1.0)
        finally:
            service.close()

        self.assertEqual(engine.policy_calls, 1)
        self.assertEqual(engine.applied, [engine.policy_action_value])
        self.assertEqual(state.controllers.seats[1], 0)

    def test_http_routes_match_flutter_client_paths(self) -> None:
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), self.service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://127.0.0.1:{server.server_port}"
            created = request_json("POST", f"{base_url}/sessions", create_request())
            headers = {"X-Kolkhoz-Seat-Token": created["seatToken"]}
            sessions = request_json("GET", f"{base_url}/sessions")
            session = request_json("GET", f"{base_url}/sessions/{created['sessionID']}")
            matched = request_json(
                "POST",
                f"{base_url}/sessions/matchmake",
                {"rankedOnly": False},
            )
            kicked = request_json(
                "POST",
                f"{base_url}/sessions/{created['sessionID']}/players/"
                f"{matched['playerID']}/kick",
                {"hostPlayerID": created["playerID"]},
                headers=headers,
            )
            rejoined = request_json(
                "POST",
                f"{base_url}/sessions/{created['sessionID']}/join",
                {"preferredPlayerID": matched["playerID"]},
            )
            actions = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/players/0/actions",
                headers=headers,
            )
            submitted = request_json(
                "POST",
                f"{base_url}/sessions/{created['sessionID']}/actions",
                {
                    "sessionID": created["sessionID"],
                    "playerID": 0,
                    "actionLogCount": created["update"]["actionLogCount"],
                    "action": actions[0],
                },
                headers=headers,
            )
            state = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/state?viewerID=0",
                headers=headers,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.assertEqual(submitted["sessionID"], created["sessionID"])
        self.assertEqual(matched["sessionID"], created["sessionID"])
        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(session["sessionID"], created["sessionID"])
        self.assertEqual(matched["playerID"], 1)
        self.assertEqual(kicked["playerID"], 0)
        self.assertEqual(rejoined["playerID"], 1)
        self.assertEqual(state["sessionID"], created["sessionID"])
        self.assertEqual(state["viewerID"], 0)
        self.assertIsInstance(state["legalActions"], list)

    def test_http_metrics_reports_route_and_lock_timings(self) -> None:
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), self.service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://127.0.0.1:{server.server_port}"
            request_json("GET", f"{base_url}/health")
            created = request_json("POST", f"{base_url}/sessions", create_request())
            request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/state?viewerID=0",
                headers={"X-Kolkhoz-Seat-Token": created["seatToken"]},
            )
            metrics = request_json("GET", f"{base_url}/metrics")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.assertEqual(metrics["service"]["activeSessions"], 1)
        self.assertGreaterEqual(metrics["service"]["activeSeats"], 3)
        self.assertEqual(metrics["service"]["profiledBotSeats"], 15)
        self.assertEqual(metrics["service"]["connectedHumanSeats"], 0)
        self.assertEqual(metrics["service"]["citizensOnline"], 15)
        self.assertGreaterEqual(metrics["process"]["activeThreads"], 1)
        self.assertIn("GET /health", metrics["routes"])
        self.assertIn("POST /sessions", metrics["routes"])
        self.assertIn("GET /sessions/{session}/state", metrics["routes"])
        self.assertEqual(metrics["routeStatuses"]["GET /health 200"], 1)
        self.assertGreaterEqual(metrics["sessionLockWaits"]["request"]["count"], 1)

    def test_http_presence_counts_only_authenticated_heartbeats(self) -> None:
        user_id = "11111111-1111-1111-1111-111111111111"

        class FakeAuthVerifier:
            def user_id_from_authorization(self, authorization: str | None) -> str | None:
                return user_id if authorization == "Bearer user-token" else None

        service = KolkhozOnlineSessionService(
            self.engine,
            auth_verifier=FakeAuthVerifier(),  # type: ignore[arg-type]
        )
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://127.0.0.1:{server.server_port}"
            anonymous = request_json("POST", f"{base_url}/presence")
            first = request_json(
                "POST",
                f"{base_url}/presence",
                headers={"Authorization": "Bearer user-token"},
            )
            second = request_json(
                "POST",
                f"{base_url}/presence",
                headers={"Authorization": "Bearer user-token"},
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
            service.close()

        self.assertEqual(anonymous["service"]["connectedHumanSeats"], 0)
        self.assertEqual(anonymous["service"]["citizensOnline"], 15)
        self.assertEqual(first["service"]["connectedHumanSeats"], 1)
        self.assertEqual(first["service"]["citizensOnline"], 16)
        self.assertEqual(second["service"]["connectedHumanSeats"], 1)
        self.assertEqual(second["service"]["citizensOnline"], 16)

    def test_online_load_test_runs_synthetic_players(self) -> None:
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), self.service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            result = run_online_load_test(
                base_url=f"http://127.0.0.1:{server.server_port}",
                players=2,
                duration_seconds=0.25,
                poll_interval_seconds=0.03,
                setup_concurrency=1,
                request_timeout_seconds=5.0,
                seed=7,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.assertEqual(result["players"], 2)
        self.assertEqual(result["sessions"], 1)
        self.assertGreater(result["client"]["requests"], 0)
        self.assertGreaterEqual(result["client"]["actionsSubmitted"], 1)
        self.assertEqual(result["client"]["errors"], [])
        self.assertIsInstance(result["serverMetrics"], dict)

    def test_http_create_list_and_join_accept_dummy_json_payloads(self) -> None:
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), self.service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://127.0.0.1:{server.server_port}"
            created = request_json(
                "POST",
                f"{base_url}/sessions",
                {
                    "seed": 456,
                    "variants": kolkhoz_variants(),
                    "controllers": [
                        "human",
                        "human",
                        "heuristicAI",
                        "heuristicAI",
                    ],
                    "ranked": False,
                },
            )
            sessions = request_json("GET", f"{base_url}/sessions")
            joined = request_json(
                "POST",
                f"{base_url}/sessions/{created['inviteCode'].lower()}/join",
                {"preferredPlayerID": 1},
            )
            state = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/state?viewerID=1",
                headers={"X-Kolkhoz-Seat-Token": joined["seatToken"]},
            )
            sessions_after_join = request_json("GET", f"{base_url}/sessions")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

        self.assertEqual(created["playerID"], 0)
        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(sessions[0]["inviteCode"], created["inviteCode"])
        self.assertEqual(sessions[0]["openSeats"], [1])
        self.assertEqual(sessions[0]["ranked"], False)
        self.assertEqual(joined["sessionID"], created["sessionID"])
        self.assertEqual(joined["inviteCode"], created["inviteCode"])
        self.assertEqual(joined["playerID"], 1)
        self.assertEqual(state["sessionID"], created["sessionID"])
        self.assertEqual(state["viewerID"], 1)
        self.assertEqual(sessions_after_join, [])

    def test_http_routes_accept_dummy_payloads_for_every_endpoint(self) -> None:
        host_user_id = "11111111-1111-1111-1111-111111111111"
        guest_user_id = "22222222-2222-2222-2222-222222222222"

        class FakeAuthVerifier:
            def user_id_from_authorization(self, authorization: str | None) -> str | None:
                if authorization == "Bearer host-token":
                    return host_user_id
                if authorization == "Bearer guest-token":
                    return guest_user_id
                return None

        store = FakeOnlineStore()
        store.profiles[host_user_id] = {
            "display_name": "Host",
            "avatar_url": "worker1",
            "comrade_code": "HOST1",
            "stats": {"online_games": 2, "online_wins": 1},
        }
        store.profiles[guest_user_id] = {
            "display_name": "Guest",
            "avatar_url": "worker2",
            "comrade_code": "GUEST",
            "stats": {"online_games": 3, "online_wins": 1},
        }
        service = KolkhozOnlineSessionService(
            self.engine,
            store=store,
            auth_verifier=FakeAuthVerifier(),  # type: ignore[arg-type]
            lobby_countdown_seconds=0,
        )
        server = KolkhozOnlineHTTPServer(("127.0.0.1", 0), service)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://127.0.0.1:{server.server_port}"
            host_headers = {"Authorization": "Bearer host-token"}
            guest_headers = {"Authorization": "Bearer guest-token"}

            options_status = request_status("OPTIONS", f"{base_url}/sessions")
            health = request_json("GET", f"{base_url}/health")
            comrades = request_json(
                "GET",
                f"{base_url}/comrades",
                headers=host_headers,
            )
            sent_request = request_json(
                "POST",
                f"{base_url}/comrades",
                {"userID": guest_user_id},
                headers=host_headers,
            )
            accepted_request = request_json(
                "POST",
                f"{base_url}/comrades/respond",
                {"userID": host_user_id, "accept": True},
                headers=guest_headers,
            )
            removed_comrade = request_json(
                "POST",
                f"{base_url}/comrades/remove",
                {"userID": guest_user_id},
                headers=host_headers,
            )
            created = request_json(
                "POST",
                f"{base_url}/sessions",
                {
                    "seed": 789,
                    "variants": kolkhoz_variants(),
                    "controllers": [
                        "human",
                        "human",
                        "heuristicAI",
                        "heuristicAI",
                    ],
                },
                headers=host_headers,
            )
            listed = request_json("GET", f"{base_url}/sessions")
            session = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}",
            )
            joined = request_json(
                "POST",
                f"{base_url}/sessions/{created['inviteCode']}/join",
                {"preferredPlayerID": 1},
                headers=guest_headers,
            )
            host_seat_headers = {
                **host_headers,
                "X-Kolkhoz-Seat-Token": created["seatToken"],
            }
            guest_seat_headers = {
                **guest_headers,
                "X-Kolkhoz-Seat-Token": joined["seatToken"],
            }
            state = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/state?viewerID=0",
                headers=host_seat_headers,
            )
            actions = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/players/0/actions",
                headers=host_seat_headers,
            )
            submitted = request_json(
                "POST",
                f"{base_url}/sessions/{created['sessionID']}/actions",
                {
                    "sessionID": created["sessionID"],
                    "playerID": 0,
                    "actionLogCount": created["update"]["actionLogCount"],
                    "action": actions[0],
                },
                headers=host_seat_headers,
            )
            updates = request_json(
                "GET",
                f"{base_url}/sessions/{created['sessionID']}/actions"
                "?viewerID=1&afterRevision=0",
                headers=guest_seat_headers,
            )
            left = request_json(
                "POST",
                f"{base_url}/sessions/{created['sessionID']}/players/1/leave",
                {"sessionID": created["sessionID"], "playerID": 1},
                headers=guest_seat_headers,
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
            service.close()

        self.assertEqual(options_status, HTTPStatus.NO_CONTENT)
        self.assertEqual(health, {"status": "ok"})
        self.assertEqual(comrades["userID"], host_user_id)
        self.assertEqual(sent_request["request"]["userID"], guest_user_id)
        self.assertEqual(accepted_request["accepted"], True)
        self.assertEqual(removed_comrade, {"removed": True})
        self.assertEqual(created["playerID"], 0)
        self.assertEqual(listed[0]["sessionID"], created["sessionID"])
        self.assertEqual(session["sessionID"], created["sessionID"])
        self.assertEqual(joined["playerID"], 1)
        self.assertEqual(state["viewerID"], 0)
        self.assertGreater(len(actions), 0)
        self.assertEqual(submitted["sessionID"], created["sessionID"])
        self.assertGreaterEqual(updates["actionLogCount"], 1)
        self.assertGreaterEqual(len(updates["updates"]), 1)
        self.assertEqual(left["playerID"], 1)
        self.assertEqual(left["penalty"]["strikes"], 1)


class FakeOnlineStore:
    def __init__(self) -> None:
        self.created: dict[str, object] = {}
        self.joined: dict[str, object] = {}
        self.actions: list[dict[str, object]] = []
        self.reactions: list[dict[str, object]] = []
        self.turn_states: list[dict[str, object]] = []
        self.lobby_states: list[dict[str, object]] = []
        self.seat_touches: list[dict[str, object]] = []
        self.timeouts: list[dict[str, object]] = []
        self.abandoned: list[dict[str, object]] = []
        self.lobby_left: list[dict[str, object]] = []
        self.kicked: list[dict[str, object]] = []
        self.expired: list[dict[str, object]] = []
        self.finished: list[dict[str, object]] = []
        self.profiles: dict[str, dict[str, object]] = {}
        self.comrade_links: dict[str, set[str]] = {}
        self.comrade_requests: set[tuple[str, str]] = set()
        self.banned_users: dict[str, dict[str, object]] = {}
        self.generated_profile_bots: list[dict[str, object]] = []
        self.abandoned_startups = 0
        self.closed = False

    def close(self) -> None:
        self.closed = True

    def create_session(
        self,
        *,
        session_id: str,
        invite_code: str,
        seed: int,
        variants: dict[str, object],
        controllers: list[str],
        ranked: bool,
        browser_joinable: bool,
        occupied_seats: set[int],
        seat_tokens: dict[int, str],
        seat_user_ids: dict[int, str],
        action_log_count: int,
        created_at: float,
        expires_at: float,
        policy_model_sha: str | None,
        created_by_user_id: str | None,
    ) -> None:
        self.created = {
            "session_id": session_id,
            "invite_code": invite_code,
            "seed": seed,
            "variants": variants,
            "controllers": controllers,
            "ranked": ranked,
            "browser_joinable": browser_joinable,
            "occupied_seats": set(occupied_seats),
            "seat_user_ids": dict(seat_user_ids),
            "seat_token_hashes": {
                player_id: seat_token_hash(token)
                for player_id, token in seat_tokens.items()
            },
            "action_log_count": action_log_count,
            "created_at": created_at,
            "expires_at": expires_at,
            "policy_model_sha": policy_model_sha,
            "created_by_user_id": created_by_user_id,
            "status": "open",
            "lobby_countdown_ends_at": None,
        }

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
        self.joined = {
            "session_id": session_id,
            "player_id": player_id,
            "seat_token_hash": seat_token_hash(seat_token),
            "user_id": user_id,
            "updated_at": updated_at,
            "expires_at": expires_at,
        }

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
        self.actions.append(
            {
                "session_id": session_id,
                "revision": revision,
                "player_id": player_id,
                "action": action,
                "updated_at": updated_at,
                "expires_at": expires_at,
            }
        )

    def append_reaction(
        self,
        *,
        session_id: str,
        revision: int,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        created_at: float,
        expires_at: float,
    ) -> None:
        self.reactions.append(
            {
                "session_id": session_id,
                "revision": revision,
                "player_id": player_id,
                "reaction_id": reaction_id,
                "year": year,
                "phase": phase,
                "created_at": created_at,
                "expires_at": expires_at,
            }
        )

    def load_session(self, session_id_or_invite: str) -> dict[str, object] | None:
        if not self.created:
            return None
        if session_id_or_invite not in {
            self.created["session_id"],
            str(self.created["invite_code"]).upper(),
        }:
            return None
        created = self.created
        return {
            "session_id": created["session_id"],
            "invite_code": created["invite_code"],
            "seed": created["seed"],
            "variants": created["variants"],
            "controllers": created["controllers"],
            "ranked": created["ranked"],
            "browser_joinable": created["browser_joinable"],
            "status": created["status"],
            "created_by_user_id": created["created_by_user_id"],
            "created_at": created["created_at"],
            "last_seen_at": created["created_at"],
            "expires_at": created["expires_at"],
            "turn_player_id": None,
            "turn_deadline_at": None,
            "lobby_countdown_ends_at": created["lobby_countdown_ends_at"],
            "seats": [
                {
                    "player_id": player_id,
                    "controller": created["controllers"][player_id],
                    "occupied": player_id in created["occupied_seats"],
                    "user_id": created["seat_user_ids"].get(player_id),
                    "seat_token_hash": created["seat_token_hashes"].get(player_id),
                    "last_seen_at": created["created_at"],
                    "timeouts": 0,
                    "abandoned": False,
                    "autopilot": False,
                }
                for player_id in range(4)
            ],
            "actions": list(self.actions),
            "reactions": [
                {
                    "revision": entry["revision"],
                    "playerID": entry["player_id"],
                    "reactionID": entry["reaction_id"],
                    "year": entry["year"],
                    "phase": entry["phase"],
                    "createdAt": entry["created_at"],
                }
                for entry in self.reactions
            ],
        }

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
        self.turn_states.append(
            {
                "session_id": session_id,
                "turn_player_id": turn_player_id,
                "turn_deadline_at": turn_deadline_at,
                "updated_at": updated_at,
                "expires_at": expires_at,
            }
        )

    def update_lobby_state(
        self,
        *,
        session_id: str,
        started: bool,
        lobby_countdown_ends_at: float | None,
        updated_at: float,
        expires_at: float,
    ) -> None:
        state = {
            "session_id": session_id,
            "started": started,
            "lobby_countdown_ends_at": lobby_countdown_ends_at,
            "updated_at": updated_at,
            "expires_at": expires_at,
        }
        self.lobby_states.append(state)
        if self.created.get("session_id") == session_id:
            self.created["status"] = "active" if started else "open"
            self.created["lobby_countdown_ends_at"] = lobby_countdown_ends_at

    def touch_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        updated_at: float,
        expires_at: float,
    ) -> None:
        self.seat_touches.append(
            {
                "session_id": session_id,
                "player_id": player_id,
                "updated_at": updated_at,
                "expires_at": expires_at,
            }
        )

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
        self.timeouts.append(
            {
                "session_id": session_id,
                "player_id": player_id,
                "timeouts": timeouts,
                "autopilot": autopilot,
                "updated_at": updated_at,
                "expires_at": expires_at,
                "revision": revision,
            }
        )

    def online_ban_for_user(
        self,
        *,
        user_id: str,
        checked_at: float,
    ) -> dict[str, object] | None:
        return self.banned_users.get(user_id)

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
        penalty = {"strikes": 1, "banned_until": None}
        self.abandoned.append(
            {
                "session_id": session_id,
                "player_id": player_id,
                "user_id": user_id,
                "updated_at": updated_at,
                "expires_at": expires_at,
                "revision": revision,
                "penalty": penalty,
            }
        )
        return penalty

    def kick_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        updated_at: float,
        expires_at: float,
        revision: int,
    ) -> None:
        self.kicked.append(
            {
                "session_id": session_id,
                "player_id": player_id,
                "updated_at": updated_at,
                "expires_at": expires_at,
                "revision": revision,
            }
        )

    def leave_lobby_seat(
        self,
        *,
        session_id: str,
        player_id: int,
        updated_at: float,
        expires_at: float,
        revision: int,
    ) -> None:
        self.lobby_left.append(
            {
                "session_id": session_id,
                "player_id": player_id,
                "updated_at": updated_at,
                "expires_at": expires_at,
                "revision": revision,
            }
        )

    def expire_session(
        self,
        *,
        session_id: str,
        updated_at: float,
        expires_at: float,
    ) -> None:
        self.expired.append(
            {
                "session_id": session_id,
                "updated_at": updated_at,
                "expires_at": expires_at,
            }
        )

    def abandon_active_sessions(self, *, updated_at: float) -> None:
        self.abandoned_startups += 1

    def finish_session(
        self,
        *,
        session_id: str,
        results: list[dict[str, object]],
        ranked: bool,
        updated_at: float,
        expires_at: float,
    ) -> None:
        self.finished.append(
            {
                "session_id": session_id,
                "results": results,
                "ranked": ranked,
                "updated_at": updated_at,
                "expires_at": expires_at,
            }
        )

    def profiles_for_user_ids(
        self,
        user_ids: list[str],
    ) -> dict[str, dict[str, object]]:
        return {
            user_id: self.profiles[user_id]
            for user_id in user_ids
            if user_id in self.profiles
        }

    def profiles_for_ai_controllers(
        self,
        controllers: list[str],
    ) -> dict[str, dict[str, object]]:
        return {}

    def create_profile_bot_profiles(
        self,
        *,
        count: int,
        exclude_user_ids: set[str],
        target_rating: int,
        updated_at: float,
    ) -> list[dict[str, object]]:
        created: list[dict[str, object]] = []
        for _ in range(count):
            index = len(self.generated_profile_bots) + 1
            user_id = f"factory-bot-{index}"
            while user_id in exclude_user_ids:
                index += 1
                user_id = f"factory-bot-{index}"
            profile = {
                "user_id": user_id,
                "controller": "mediumAI",
                "slot": index,
                "display_name": f"Factory Bot {index}",
                "avatar_url": "worker1",
                "stats": {
                    "rating": target_rating,
                    "peak_rating": target_rating,
                    "rating_games": 0,
                },
            }
            self.generated_profile_bots.append(profile)
            self.profiles[user_id] = {
                "display_name": profile["display_name"],
                "avatar_url": profile["avatar_url"],
                "stats": profile["stats"],
            }
            exclude_user_ids.add(user_id)
            created.append(profile)
        return created

    def ensure_comrade_code(
        self,
        *,
        user_id: str,
        display_name: str,
        updated_at: float,
    ) -> str:
        profile = self.profiles.setdefault(
            user_id,
            {
                "display_name": display_name,
                "avatar_url": None,
                "stats": {},
            },
        )
        profile.setdefault("comrade_code", user_id.replace("-", "").upper()[:5])
        return str(profile["comrade_code"])

    def comrades_for_user(self, *, user_id: str) -> dict[str, object]:
        code = self.ensure_comrade_code(
            user_id=user_id,
            display_name="Player",
            updated_at=0,
        )
        return {
            "user_id": user_id,
            "comrade_code": code,
            "comrades": [
                self._comrade_profile(comrade_user_id)
                for comrade_user_id in sorted(self.comrade_links.get(user_id, set()))
            ],
            "incoming_requests": [
                self._comrade_profile(requester_user_id)
                for requester_user_id, addressee_user_id in sorted(
                    self.comrade_requests,
                )
                if addressee_user_id == user_id
            ],
            "outgoing_requests": [
                self._comrade_profile(addressee_user_id)
                for requester_user_id, addressee_user_id in sorted(
                    self.comrade_requests,
                )
                if requester_user_id == user_id
            ],
        }

    def send_comrade_request_by_code(
        self,
        *,
        user_id: str,
        comrade_code: str,
        updated_at: float,
    ) -> dict[str, object]:
        normalized = comrade_code.strip().upper()
        for candidate_user_id, profile in self.profiles.items():
            if str(profile.get("comrade_code", "")).upper() != normalized:
                continue
            return self._send_comrade_request_to_user(user_id, candidate_user_id)
        raise ValueError("comrade code not found")

    def send_comrade_request_to_user(
        self,
        *,
        user_id: str,
        comrade_user_id: str,
        updated_at: float,
    ) -> dict[str, object]:
        return self._send_comrade_request_to_user(user_id, comrade_user_id)

    def _send_comrade_request_to_user(
        self,
        user_id: str,
        comrade_user_id: str,
    ) -> dict[str, object]:
        if comrade_user_id not in self.profiles:
            raise ValueError("comrade profile not found")
        if comrade_user_id == user_id:
            raise ValueError("cannot add yourself as a comrade")
        if comrade_user_id in self.comrade_links.get(user_id, set()):
            raise ValueError("already comrades")
        reverse = (comrade_user_id, user_id)
        if reverse in self.comrade_requests:
            self.comrade_requests.remove(reverse)
            self.comrade_links.setdefault(user_id, set()).add(comrade_user_id)
            self.comrade_links.setdefault(comrade_user_id, set()).add(user_id)
            profile = self._comrade_profile(comrade_user_id)
            profile["accepted"] = True
            return profile
        self.comrade_requests.add((user_id, comrade_user_id))
        profile = self._comrade_profile(comrade_user_id)
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
        request = (requester_user_id, user_id)
        if request not in self.comrade_requests:
            raise ValueError("comrade request not found")
        self.comrade_requests.remove(request)
        if not accept:
            return None
        self.comrade_links.setdefault(user_id, set()).add(requester_user_id)
        self.comrade_links.setdefault(requester_user_id, set()).add(user_id)
        return self._comrade_profile(requester_user_id)

    def remove_comrade(self, *, user_id: str, comrade_user_id: str) -> None:
        self.comrade_links.setdefault(user_id, set()).discard(comrade_user_id)
        self.comrade_links.setdefault(comrade_user_id, set()).discard(user_id)
        self.comrade_requests.discard((user_id, comrade_user_id))
        self.comrade_requests.discard((comrade_user_id, user_id))

    def _comrade_profile(self, user_id: str) -> dict[str, object]:
        profile = self.profiles[user_id]
        return {
            "userID": user_id,
            "displayName": profile.get("display_name"),
            "avatarURL": profile.get("avatar_url"),
            "comradeCode": profile.get("comrade_code"),
            "stats": profile.get("stats", {}),
        }


class FailingJoinStore(FakeOnlineStore):
    def __init__(self) -> None:
        super().__init__()
        self.fail_join = True

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
        if self.fail_join:
            raise RuntimeError("join persistence failed")
        super().join_seat(
            session_id=session_id,
            player_id=player_id,
            seat_token=seat_token,
            user_id=user_id,
            updated_at=updated_at,
            expires_at=expires_at,
        )


def request_json(
    method: str,
    url: str,
    body: object | None = None,
    *,
    headers: dict[str, str] | None = None,
) -> object:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            **(headers or {}),
        },
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def request_status(
    method: str,
    url: str,
    body: object | None = None,
    *,
    headers: dict[str, str] | None = None,
) -> int:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            **(headers or {}),
        },
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        response.read()
        return response.status


def make_action(kind: int, player_id: int):
    from research.kolkhoz_research.c_engine import KCAction, KCCard

    no_card = KCCard(-1, 0)
    return KCAction(kind, player_id, -1, no_card, no_card, no_card, -1, -1)


if __name__ == "__main__":
    unittest.main()
