from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server.kolkhoz_server.api import OnlineApplication, Request
from server.kolkhoz_server.auth import StaticAuthVerifier
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.lobby import SeatRecord
from server.tests.in_memory_lobby import InMemoryLobbyRepository
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore
from server.kolkhoz_server.commerce import (
    CommerceService,
    InMemoryEntitlementRepository,
    PurchaseVerificationError,
    VerifiedPurchase,
)
from server.tests.test_runtime import FakeEngineFactory


class FakeResults:
    def __init__(self) -> None:
        self.abandoned: list[tuple[str, int]] = []
        self.recorded: list[str] = []
        self.series_by_session: dict[str, dict[str, object]] = {}

    def record_abandonment(self, **values: object) -> dict[str, object]:
        self.abandoned.append((str(values["session_id"]), int(values["player_id"])))
        return {"strikes": 1, "banned_until": None}

    def record_session_results(self, **values: object) -> bool:
        self.recorded.append(str(values["session_id"]))
        return True

    def online_ban_for_user(self, **values: object) -> None:
        return None

    def recent_games(self, **values: object) -> list[dict[str, object]]:
        return [
            {
                "sessionID": "recent-game",
                "playerID": 1,
                "score": 123,
                "rank": 2,
                "won": False,
                "ranked": True,
                "completedAt": 1000.0,
            }
        ]

    def session_results(self, **values: object) -> list[dict[str, object]]:
        return [
            {
                "playerID": 0,
                "userID": "host",
                "score": 100,
                "rank": 1,
                "won": True,
                "ranked": False,
                "completedAt": 1000.0,
                "displayName": "Host",
            }
        ]

    def daily_challenge(self, **values: object) -> dict[str, object]:
        return {
            "attempt": {"sessionID": "old", "score": 140},
            "leaders": [{"displayName": "Host", "score": 140}],
        }

    def claim_daily_attempt(self, **values: object) -> bool:
        return True

    def create_series(self, *, session_id: str, best_of: int) -> dict[str, object]:
        value = {
            "seriesID": "series-1",
            "bestOf": best_of,
            "roundNumber": 1,
            "completed": False,
            "winnerPlayerID": None,
            "wins": {},
        }
        self.series_by_session[session_id] = value
        return value

    def series_status(self, *, session_id: str) -> dict[str, object] | None:
        return self.series_by_session.get(session_id)

    def continue_series(
        self, *, source_session_id: str, session_id: str
    ) -> dict[str, object] | None:
        source = self.series_by_session.get(source_session_id)
        if source is None:
            return None
        value = {**source, "roundNumber": int(source["roundNumber"]) + 1}
        self.series_by_session[session_id] = value
        return value


class CompatibilityApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        database = Path(self.temporary.name) / "api.sqlite3"
        self.runtime = GameRuntime(
            SQLiteEventStore(database),
            engine_factory=FakeEngineFactory(),
            shard_count=2,
        )
        self.application = OnlineApplication(
            self.runtime,
            InMemoryLobbyRepository(),
            auth=StaticAuthVerifier({"host-token": "host", "guest-token": "guest"}),
            lobby_countdown_seconds=0,
            results=FakeResults(),
        )

    def tearDown(self) -> None:
        self.runtime.close()
        self.temporary.cleanup()

    def test_recent_results_require_auth_and_return_last_games(self) -> None:
        status, _ = self.request("GET", "/results/recent")
        self.assertEqual(status, 401)
        status, body = self.request("GET", "/results/recent", bearer="host-token")
        self.assertEqual(status, 200)
        self.assertEqual(body["games"][0]["sessionID"], "recent-game")

    def test_committed_update_fast_path_requires_a_live_human_wait(self) -> None:
        human = SeatRecord(1, "human", True, "guest", "token", 1.0, 0, False, False)
        automatic = SeatRecord(1, "heuristicAI", True, None, None, 1.0, 0, False, False)
        autopilot = SeatRecord(1, "human", True, "guest", "token", 1.0, 2, True, True)

        self.assertTrue(
            self.application._update_waits_for_human(
                {"phase": 2, "waitingPlayer": 1}, [human]
            )
        )
        self.assertFalse(
            self.application._update_waits_for_human(
                {"phase": 2, "waitingPlayer": 1}, [automatic]
            )
        )
        self.assertFalse(
            self.application._update_waits_for_human(
                {"phase": 2, "waitingPlayer": 1}, [autopilot]
            )
        )
        self.assertFalse(
            self.application._update_waits_for_human(
                {"phase": 5, "waitingPlayer": 1}, [human]
            )
        )
        self.assertFalse(
            self.application._update_waits_for_human(
                {
                    "phase": 0,
                    "waitingPlayer": 1,
                    "legalActions": [{"kind": 10, "playerID": 1}],
                },
                [human],
            )
        )

    def test_cached_action_update_reuses_matching_full_session_context(self) -> None:
        status, created = self.request(
            "POST", "/sessions", {"seed": 3}, bearer="host-token"
        )
        self.assertEqual(status, 200)
        session_id = created["sessionID"]
        record = self.application.lobby.session(session_id)
        seats = self.application.lobby.seats(session_id)
        state = {
            "phase": 2,
            "waitingPlayer": 0,
            "legalActions": [{"kind": 0, "playerID": 0}],
        }

        with patch.object(
            self.application.lobby,
            "reactions",
            wraps=self.application.lobby.reactions,
        ) as reactions:
            update = self.application._cached_action_update(
                record,
                seats,
                0,
                state,
                1,
                expected_revision=0,
                action={"kind": 0, "playerID": 0},
                turn_player_id=0,
                turn_deadline_at=100.0,
            )

        self.assertIsNotNone(update)
        self.assertEqual(update["actionLogCount"], 1)
        self.assertEqual(update["turnDeadlineAt"], 100.0)
        self.assertEqual(update["gameLogActions"][-1]["playerID"], 0)
        reactions.assert_called_once_with(session_id)
        self.assertIsNone(
            self.application._cached_action_update(
                record,
                seats,
                0,
                state,
                3,
                expected_revision=2,
                action={"kind": 0, "playerID": 0},
                turn_player_id=0,
                turn_deadline_at=100.0,
            )
        )

    def test_account_deletion_requires_auth_and_targets_current_user(self) -> None:
        class Accounts:
            def __init__(self) -> None:
                self.deleted: list[str] = []

            def delete(self, user_id: str) -> None:
                self.deleted.append(user_id)

        accounts = Accounts()
        self.application.accounts = accounts  # type: ignore[assignment]
        missing, _ = self.request("DELETE", "/account")
        self.assertEqual(missing, 401)
        status, body = self.request("DELETE", "/account", bearer="host-token")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"deleted": True})
        self.assertEqual(accounts.deleted, ["host"])

    def test_commerce_claim_is_authenticated_and_returns_entitlement(self) -> None:
        class Verifier:
            provider = "apple"

            def verify_purchase(self, value: str) -> VerifiedPurchase:
                if value != "signed-transaction":
                    raise PurchaseVerificationError("invalid")
                return VerifiedPurchase(
                    provider="apple",
                    original_transaction_id="transaction-1",
                    product_id="full-game",
                    account_reference="host",
                    active=True,
                )

            def verify_notification(self, value: str) -> VerifiedPurchase | None:
                return None

        self.application.commerce = CommerceService(
            InMemoryEntitlementRepository(), {"apple": Verifier()}
        )
        missing, _ = self.request("GET", "/commerce/entitlements")
        self.assertEqual(missing, 401)
        status, initial = self.request(
            "GET", "/commerce/entitlements", bearer="host-token"
        )
        self.assertEqual(status, 200)
        self.assertFalse(initial["fullGame"])
        claimed_status, claimed = self.request(
            "POST",
            "/commerce/purchases/claim",
            {"provider": "apple", "verificationData": "signed-transaction"},
            bearer="host-token",
        )
        self.assertEqual(claimed_status, 200)
        self.assertTrue(claimed["fullGame"])
        self.application.require_full_game = True
        guest_status, _ = self.request("GET", "/sessions", bearer="guest-token")
        self.assertEqual(guest_status, 403)
        owner_status, _ = self.request("GET", "/sessions", bearer="host-token")
        self.assertEqual(owner_status, 200)

    def test_installation_registration_is_authenticated_and_owned(self) -> None:
        class Installations:
            def __init__(self) -> None:
                self.registered: list[dict[str, object]] = []
                self.deleted: list[dict[str, object]] = []

            def register_installation(self, **values: object) -> None:
                self.registered.append(values)

            def delete_installation(self, **values: object) -> bool:
                self.deleted.append(values)
                return True

        installations = Installations()
        self.application.notification_repository = installations  # type: ignore[assignment]
        path = "/installations/device-12345678"
        missing, _ = self.request(
            "PUT", path, {"platform": "ios", "token": "valid-token-value"}
        )
        self.assertEqual(missing, 401)
        status, body = self.request(
            "PUT",
            path,
            {"platform": "ios", "token": "valid-token-value"},
            bearer="host-token",
        )
        self.assertEqual(status, 200)
        self.assertTrue(body["registered"])
        self.assertEqual(installations.registered[0]["user_id"], "host")
        deleted, _ = self.request("DELETE", path, bearer="guest-token")
        self.assertEqual(deleted, 200)
        self.assertEqual(installations.deleted[0]["user_id"], "guest")

    def test_daily_challenge_returns_shared_seed_and_personal_best(self) -> None:
        status, body = self.request("GET", "/challenges/daily", bearer="host-token")
        self.assertEqual(status, 200)
        self.assertIsInstance(body["seed"], int)
        self.assertEqual(body["attempt"]["score"], 140)

    def test_best_of_format_is_persisted_in_session_update(self) -> None:
        status, created = self.request(
            "POST",
            "/sessions",
            {
                "controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"],
                "bestOf": 3,
            },
            bearer="host-token",
        )
        self.assertEqual(status, 200)
        self.assertEqual(created["series"]["bestOf"], 3)
        self.assertEqual(created["update"]["series"]["roundNumber"], 1)

    def test_ranked_games_reject_rematch(self) -> None:
        _, created = self.request(
            "POST",
            "/sessions",
            {"controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"]},
            bearer="host-token",
        )
        self.application.lobby.set_ranked(created["sessionID"], True, now=1.0)
        status, body = self.request(
            "POST", f"/results/{created['sessionID']}/rematch", bearer="host-token"
        )
        self.assertEqual(status, 409)
        self.assertIn("ranked games cannot be rematched", body["error"])

    def test_public_casual_game_can_be_spectated_without_actions(self) -> None:
        _, created = self.request(
            "POST",
            "/sessions",
            {
                "controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"],
                "browserJoinable": True,
            },
            bearer="host-token",
        )
        session_id = created["sessionID"]
        status, update = self.request("GET", f"/sessions/{session_id}/spectate")
        self.assertEqual(status, 200)
        self.assertTrue(update["spectator"])
        self.assertEqual(update["legalActions"], [])
        self.assertIsNone(update["viewerID"])

        self.application.lobby.set_ranked(session_id, True, now=2.0)
        status, _ = self.request("GET", f"/sessions/{session_id}/spectate")
        self.assertEqual(status, 403)

    def test_gameplay_gets_do_not_mutate_session_state(self) -> None:
        status, created = self.request(
            "POST",
            "/sessions",
            {
                "seed": 10,
                "controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"],
            },
            bearer="host-token",
        )
        self.assertEqual(status, 200)
        session_id = created["sessionID"]
        before_game = self.runtime.store.game(session_id)
        before_session = self.application.lobby.session(session_id)
        before_turn = self.application.lobby.turn_state(session_id)
        before_results = list(self.application.results.recorded)

        for _ in range(3):
            read_status, _ = self.request(
                "GET",
                f"/sessions/{session_id}/state?viewerID=0",
                bearer="host-token",
                seat_token=created["seatToken"],
            )
            self.assertEqual(read_status, 200)

        after_game = self.runtime.store.game(session_id)
        after_session = self.application.lobby.session(session_id)
        self.assertEqual(after_game.revision, before_game.revision)
        self.assertEqual(after_session.status, before_session.status)
        self.assertEqual(self.application.lobby.turn_state(session_id), before_turn)
        self.assertEqual(self.application.results.recorded, before_results)

    def request(
        self,
        method: str,
        path: str,
        body: dict[str, object] | None = None,
        *,
        bearer: str | None = None,
        seat_token: str | None = None,
        device_id: str | None = None,
    ) -> tuple[int, object]:
        headers = {"content-type": "application/json"}
        if bearer:
            headers["authorization"] = f"Bearer {bearer}"
        if seat_token:
            headers["x-kolkhoz-seat-token"] = seat_token
        if device_id:
            headers["x-kolkhoz-device-id"] = device_id
        try:
            response = self.application.dispatch(
                Request(method, path, headers, body or {})
            )
            return int(response.status), response.body
        except ServerError as error:
            return int(error.status), {"error": error.message}

    def test_create_list_join_state_action_and_presence_route_contracts(self) -> None:
        status, created = self.request(
            "POST",
            "/sessions",
            {
                "seed": 10,
                "controllers": ["human", "human", "heuristicAI", "heuristicAI"],
            },
            bearer="host-token",
        )
        self.assertEqual(status, 200)
        session_id = created["sessionID"]
        host_seat = created["seatToken"]

        listed_status, listings = self.request("GET", "/sessions")
        self.assertEqual(listed_status, 200)
        self.assertEqual(listings[0]["sessionID"], session_id)

        joined_status, joined = self.request(
            "POST",
            f"/sessions/{created['inviteCode'].lower()}/join",
            {"preferredPlayerID": 1},
            bearer="guest-token",
        )
        self.assertEqual(joined_status, 200)
        self.assertEqual(joined["playerID"], 1)

        state_status, state = self.request(
            "GET",
            f"/sessions/{session_id}/state?viewerID=0",
            bearer="host-token",
            seat_token=host_seat,
        )
        self.assertEqual(state_status, 200)
        self.assertEqual(state["actionLogCount"], 0)

        with patch.object(
            self.runtime,
            "advance_and_state",
            wraps=self.runtime.advance_and_state,
        ) as advance_and_state:
            action_status, update = self.request(
                "POST",
                f"/sessions/{session_id}/actions",
                {
                    "playerID": 0,
                    "actionLogCount": 0,
                    "action": {"delta": 2, "playerID": 0},
                },
                bearer="host-token",
                seat_token=host_seat,
            )
        self.assertEqual(action_status, 200)
        self.assertEqual(update["actionLogCount"], 1)
        advance_and_state.assert_called_once()

        _, anonymous_presence = self.request("POST", "/presence", {})
        _, signed_in_presence = self.request(
            "POST", "/presence", {}, bearer="host-token"
        )
        self.assertEqual(anonymous_presence["service"]["citizensOnline"], 0)
        self.assertEqual(signed_in_presence["service"]["citizensOnline"], 1)

        leave_status, left = self.request(
            "POST",
            f"/sessions/{session_id}/players/1/leave",
            {},
            bearer="guest-token",
            seat_token=joined["seatToken"],
        )
        self.assertEqual(leave_status, 200)
        self.assertEqual(left["penalty"]["strikes"], 1)
        guest_presence = next(
            value for value in left["update"]["seatPresence"] if value["playerID"] == 1
        )
        self.assertTrue(guest_presence["abandoned"])
        self.assertTrue(guest_presence["autopilot"])

    def test_auth_and_seat_conflicts_preserve_legacy_statuses(self) -> None:
        missing_auth, error = self.request("POST", "/sessions", {"seed": 1})
        self.assertEqual(missing_auth, 401)
        self.assertEqual(error["error"], "missing auth token")

        _, created = self.request("POST", "/sessions", {"seed": 1}, bearer="host-token")
        invalid_seat, error = self.request(
            "GET",
            f"/sessions/{created['sessionID']}/state?viewerID=0",
            bearer="host-token",
            seat_token="wrong",
        )
        self.assertEqual(invalid_seat, 401)
        self.assertEqual(error["error"], "invalid seat token")

    def test_population_lobby_starts_when_profile_bots_fill_every_seat(self) -> None:
        _, created = self.request(
            "POST",
            "/sessions",
            {"seed": 17, "controllers": ["human"] * 4},
            bearer="host-token",
        )
        session_id = created["sessionID"]
        lobby = self.application.lobby
        self.application.population_seat_filled(session_id)
        self.assertEqual(lobby.session(session_id).status, "open")

        for seat in lobby.seats(session_id):
            lobby._replace_seat(
                session_id,
                SeatRecord(
                    seat.player_id,
                    "heuristicAI",
                    True,
                    seat.user_id or f"bot-{seat.player_id}",
                    seat.token_hash,
                    seat.last_seen_at,
                    seat.timeouts,
                    seat.abandoned,
                    seat.autopilot,
                ),
            )

        with patch.object(
            self.runtime,
            "events",
            side_effect=AssertionError("population advancement read event history"),
        ):
            self.application.population_seat_filled(session_id)

        self.assertEqual(lobby.session(session_id).status, "active")

    def test_active_sync_rejects_second_device_without_rotating_token(self) -> None:
        _, created = self.request("POST", "/sessions", {"seed": 1}, bearer="host-token")
        session_id = created["sessionID"]
        status, synced = self.request(
            "POST",
            "/active-session/sync",
            {},
            bearer="host-token",
            device_id="phone",
        )
        self.assertEqual(status, 200)

        conflict, error = self.request(
            "POST",
            "/active-session/sync",
            {},
            bearer="host-token",
            device_id="tablet",
        )
        self.assertEqual(conflict, 409)
        self.assertIn("another device", error["error"])

        still_valid, _ = self.request(
            "GET",
            f"/sessions/{session_id}/state?viewerID=0",
            bearer="host-token",
            seat_token=synced["seatToken"],
        )
        self.assertEqual(still_valid, 200)

    def test_create_and_join_immediately_register_device_leases(self) -> None:
        _, created = self.request(
            "POST",
            "/sessions",
            {"seed": 1},
            bearer="host-token",
            device_id="host-phone",
        )
        host_conflict, host_error = self.request(
            "POST",
            "/active-session/sync",
            {},
            bearer="host-token",
            device_id="host-tablet",
        )
        self.assertEqual(host_conflict, 409)
        self.assertIn("another device", host_error["error"])

        joined_status, _ = self.request(
            "POST",
            f"/sessions/{created['inviteCode']}/join",
            {},
            bearer="guest-token",
            device_id="guest-phone",
        )
        self.assertEqual(joined_status, 200)
        guest_conflict, guest_error = self.request(
            "POST",
            "/active-session/sync",
            {},
            bearer="guest-token",
            device_id="guest-tablet",
        )
        self.assertEqual(guest_conflict, 409)
        self.assertIn("another device", guest_error["error"])
