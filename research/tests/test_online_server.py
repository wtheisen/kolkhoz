from __future__ import annotations

import json
import ctypes
import threading
import unittest
import urllib.request
import uuid
from http import HTTPStatus

from research.kolkhoz_research.c_engine import CEngine, build_shared_library
from research.kolkhoz_research.online_server import (
    HostedSession,
    KCEngineSnapshot,
    KolkhozOnlineHTTPServer,
    KolkhozOnlineSessionService,
    OnlineServerError,
    PHASE_GAME_OVER,
)
from research.kolkhoz_research.model import PolicyArtifact
from research.kolkhoz_research.online_store import seat_token_hash


def kolkhoz_variants() -> dict[str, object]:
    return {
        "deckType": 52,
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


class OnlineServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = CEngine(build_shared_library())

    def setUp(self) -> None:
        self.service = KolkhozOnlineSessionService(self.engine)

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

    def test_service_preserves_neural_seats_for_server_policy_ai(self) -> None:
        request = create_request()
        request["controllers"] = ["human", "human", "neuralAI", "neuralAI"]

        created = self.service.create_session(request)

        self.assertEqual(
            created["update"]["controllers"],
            ["human", "human", "neuralAI", "neuralAI"],
        )

    def test_service_lists_open_sessions(self) -> None:
        created = self.service.create_session(create_request())
        sessions = self.service.list_sessions()

        self.assertEqual(len(sessions), 1)
        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(sessions[0]["openSeats"], [1])
        self.assertEqual(sessions[0]["occupiedSeats"], [0])

        self.service.join_session(created["sessionID"], {"preferredPlayerID": 1})
        self.assertEqual(self.service.list_sessions(), [])
        listing = self.service.session_listing(created["sessionID"])
        self.assertEqual(listing["sessionID"], created["sessionID"])
        self.assertEqual(listing["openSeats"], [])
        self.assertEqual(listing["occupiedSeats"], [0, 1])
        self.assertGreater(listing["expiresAt"], listing["createdAt"])

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
        service = KolkhozOnlineSessionService(self.engine, store=store)
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

    def test_service_times_out_human_turn_with_autopilot_action(self) -> None:
        store = FakeOnlineStore()
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            created = service.create_session(create_request())
            hosted = service._sessions[created["sessionID"]]
            hosted.turn_player_id = 0
            hosted.turn_deadline_at = 0.0

            service.list_sessions()
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
            hosted = service._sessions[created["sessionID"]]
            hosted.turn_player_id = 0
            hosted.turn_deadline_at = 0.0
            hosted.seat_timeouts[0] = 1

            service.list_sessions()
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

    def test_service_records_explicit_leave_and_autopilots_seat(self) -> None:
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
            hosted = service._sessions[created["sessionID"]]
        finally:
            service.close()

        self.assertEqual(response["penalty"]["strikes"], 1)
        self.assertIn(0, hosted.abandoned_seats)
        self.assertIn(0, hosted.autopilot_seats)
        self.assertEqual(len(store.abandoned), 1)
        self.assertEqual(
            store.abandoned[0]["user_id"],
            "11111111-1111-1111-1111-111111111111",
        )

    def test_service_rejects_online_play_when_user_is_sent_north(self) -> None:
        store = FakeOnlineStore()
        store.banned_users["11111111-1111-1111-1111-111111111111"] = {
            "strikes": 3,
            "banned_until": 1893456000.0,
        }
        service = KolkhozOnlineSessionService(self.engine, store=store)
        try:
            with self.assertRaises(OnlineServerError) as denied:
                service.create_session(
                    create_request(),
                    user_id="11111111-1111-1111-1111-111111111111",
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
            store.created["seat_user_ids"],
            {0: "11111111-1111-1111-1111-111111111111"},
        )
        self.assertEqual(store.joined["player_id"], joined["playerID"])
        self.assertEqual(
            store.joined["user_id"],
            "22222222-2222-2222-2222-222222222222",
        )
        self.assertEqual(store.abandoned_startups, 1)

    def test_service_records_online_results_once_when_game_finishes(self) -> None:
        class FakeEngine:
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
            engine_pointer=ctypes.cast(ctypes.pointer(state), ctypes.c_void_p),
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "heuristicAI", "heuristicAI"],
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_user_ids={
                0: "11111111-1111-1111-1111-111111111111",
                1: "22222222-2222-2222-2222-222222222222",
            },
            created_by_user_id="11111111-1111-1111-1111-111111111111",
            action_log=[],
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
            engine_pointer=object(),  # type: ignore[arg-type]
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["human", "human", "heuristicAI", "heuristicAI"],
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_user_ids={},
            created_by_user_id=None,
            action_log=[],
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
            engine_pointer=object(),  # type: ignore[arg-type]
            seed=123,
            variants=kolkhoz_variants(),
            controllers=["mediumAI", "human", "neuralAI", "heuristicAI"],
            occupied_seats={0, 1},
            seat_tokens={0: "seat-0", 1: "seat-1"},
            seat_user_ids={},
            created_by_user_id=None,
            action_log=[],
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
            service._advance_automatic_turns(hosted)
        finally:
            service.close()

        self.assertEqual(engine.policy_steps, 2)
        self.assertEqual(engine.heuristic_steps, 1)
        self.assertEqual(engine.waiting, [1])

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
        self.assertEqual(sessions[0]["sessionID"], created["sessionID"])
        self.assertEqual(session["sessionID"], created["sessionID"])
        self.assertEqual(state["sessionID"], created["sessionID"])
        self.assertEqual(state["viewerID"], 0)
        self.assertIsInstance(state["legalActions"], list)


class FakeOnlineStore:
    def __init__(self) -> None:
        self.created: dict[str, object] = {}
        self.joined: dict[str, object] = {}
        self.actions: list[dict[str, object]] = []
        self.turn_states: list[dict[str, object]] = []
        self.seat_touches: list[dict[str, object]] = []
        self.timeouts: list[dict[str, object]] = []
        self.abandoned: list[dict[str, object]] = []
        self.finished: list[dict[str, object]] = []
        self.profiles: dict[str, dict[str, object]] = {}
        self.banned_users: dict[str, dict[str, object]] = {}
        self.abandoned_startups = 0
        self.closed = False

    def close(self) -> None:
        self.closed = True

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
        self.created = {
            "session_id": session_id,
            "seed": seed,
            "variants": variants,
            "controllers": controllers,
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

    def abandon_active_sessions(self, *, updated_at: float) -> None:
        self.abandoned_startups += 1

    def finish_session(
        self,
        *,
        session_id: str,
        results: list[dict[str, object]],
        updated_at: float,
        expires_at: float,
    ) -> None:
        self.finished.append(
            {
                "session_id": session_id,
                "results": results,
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


def make_action(kind: int, player_id: int):
    from research.kolkhoz_research.c_engine import KCAction, KCCard

    no_card = KCCard(-1, 0)
    return KCAction(kind, player_id, -1, no_card, no_card, no_card, -1, -1)


if __name__ == "__main__":
    unittest.main()
