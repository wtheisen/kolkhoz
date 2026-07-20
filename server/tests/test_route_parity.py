from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server.kolkhoz_server.api import OnlineApplication, Request
from server.kolkhoz_server.auth import StaticAuthVerifier
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.lobby import SQLiteLobbyRepository
from server.kolkhoz_server.routes import ROUTES, resolve_route
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.social import SocialService
from server.kolkhoz_server.store import SQLiteEventStore


class ParityEngine:
    """Small deterministic engine double with the fields used by API projection."""

    def __init__(self, seed: int) -> None:
        self.value = seed

    def apply(self, action: dict[str, object]) -> None:
        delta = action.get("delta")
        if not isinstance(delta, int):
            raise ValueError("delta must be an integer")
        self.value += delta

    def view(self, viewer_id: int | None = None) -> dict[str, object]:
        return {
            "value": self.value,
            "viewerID": viewer_id,
            "year": 1,
            "phase": 0,
            "waitingPlayer": 0,
            "legalActions": [{"type": "add", "delta": 1, "playerID": 0}],
        }

    def close(self) -> None:
        pass


class ParityEngineFactory:
    def create(self, seed: int, variants: dict[str, object]) -> ParityEngine:
        return ParityEngine(seed)


class FakeSocialRepository:
    def ensure_comrade_code(self, **values: object) -> str:
        return "HOST0001"

    def leaderboard(self, *, limit: int = 100) -> list[dict[str, object]]:
        return [self._profile("host", "Host", 1200)]

    def public_profile(self, *, user_id: str) -> dict[str, object]:
        return self._profile(user_id, user_id.title(), 1100)

    def profiles_for_user_ids(
        self, user_ids: list[str]
    ) -> dict[str, dict[str, object]]:
        return {
            user_id: self._profile(user_id, user_id.title(), 1100)
            for user_id in user_ids
        }

    def profiles_for_ai_controllers(
        self, controllers: list[str]
    ) -> dict[str, dict[str, object]]:
        return {
            controller: self._profile(controller, controller, 1000)
            for controller in controllers
            if controller != "human"
        }

    def comrades_for_user(self, *, user_id: str) -> dict[str, object]:
        return {
            "user_id": user_id,
            "comrade_code": "HOST0001",
            "comrades": [self._profile("guest", "Guest", 1000)],
            "incoming_requests": [],
            "outgoing_requests": [],
        }

    def send_comrade_request_by_code(self, **values: object) -> dict[str, object]:
        return {**self._profile("guest", "Guest", 1000), "accepted": False}

    def send_comrade_request_to_user(self, **values: object) -> dict[str, object]:
        return {**self._profile("guest", "Guest", 1000), "accepted": False}

    def respond_to_comrade_request(self, **values: object) -> dict[str, object] | None:
        return self._profile("guest", "Guest", 1000)

    def remove_comrade(self, **values: object) -> None:
        pass

    @staticmethod
    def _profile(user_id: str, name: str, rating: int) -> dict[str, object]:
        return {
            "userID": user_id,
            "displayName": name,
            "avatarURL": None,
            "stats": {"rating": rating, "online_games": 1},
        }


class FakeAccountDeletionService:
    def __init__(self) -> None:
        self.deleted: list[str] = []

    def delete(self, user_id: str) -> None:
        self.deleted.append(user_id)


class CanonicalRouteParityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        database = Path(self.temporary.name) / "route-parity.sqlite3"
        self.runtime = GameRuntime(
            SQLiteEventStore(database),
            engine_factory=ParityEngineFactory(),
            shard_count=2,
        )
        self.application = OnlineApplication(
            self.runtime,
            SQLiteLobbyRepository(database),
            auth=StaticAuthVerifier(
                {
                    "host-token": "host",
                    "guest-token": "guest",
                    "third-token": "third",
                    "fourth-token": "fourth",
                }
            ),
            social=SocialService(FakeSocialRepository()),
            accounts=FakeAccountDeletionService(),  # type: ignore[arg-type]
            lobby_countdown_seconds=0,
        )
        self.exercised: set[tuple[str, str]] = set()

    def tearDown(self) -> None:
        self.runtime.close()
        self.temporary.cleanup()

    def request(
        self,
        method: str,
        path: str,
        body: dict[str, object] | None = None,
        *,
        bearer: str | None = None,
        seat_token: str | None = None,
    ) -> tuple[int, object]:
        route = resolve_route(method, path.split("?", 1)[0])
        self.assertIsNotNone(route, f"canonical route did not resolve: {method} {path}")
        self.exercised.add((route.method, route.path))
        headers = {
            "content-type": "application/json",
            "x-kolkhoz-device-id": "device-1",
        }
        if bearer:
            headers["authorization"] = f"Bearer {bearer}"
        if seat_token:
            headers["x-kolkhoz-seat-token"] = seat_token
        try:
            response = self.application.dispatch(
                Request(method, path, headers, body or {})
            )
            return int(response.status), response.body
        except ServerError as error:
            return int(error.status), {"error": error.message}

    def assert_ok(self, response: tuple[int, object]) -> object:
        status, body = response
        self.assertEqual(status, 200, body)
        return body

    def test_every_canonical_route_dispatches_with_a_realistic_contract(self) -> None:
        self.assert_ok(self.request("GET", "/health"))
        self.assert_ok(self.request("GET", "/metrics"))
        self.assert_ok(self.request("GET", "/canary"))
        self.request("GET", "/admin/operations", bearer="host-token")
        self.request("POST", "/identity/platform/game_center")
        self.request("POST", "/identity/guest")
        self.request("POST", "/identity/legacy", bearer="host-token")
        self.request(
            "POST",
            "/identity/email/code",
            {"email": "host@example.com"},
            bearer="host-token",
        )
        self.request(
            "POST",
            "/identity/email/verify",
            {"email": "host@example.com", "code": "123456"},
            bearer="host-token",
        )
        self.request("POST", "/identity/device-links", bearer="host-token")
        self.request("GET", "/identity/device-links/request-1", bearer="host-token")
        self.request(
            "DELETE", "/identity/device-links/request-1", bearer="host-token"
        )
        self.request("POST", "/identity/device-links/redeem", bearer="host-token")
        self.request(
            "POST",
            "/identity/device-links/request-1/approve",
            bearer="host-token",
        )
        self.assert_ok(self.request("DELETE", "/account", bearer="host-token"))
        self.request("GET", "/commerce/entitlements", bearer="host-token")
        self.request(
            "POST",
            "/commerce/purchases/claim",
            {"provider": "apple", "verificationData": "test"},
            bearer="host-token",
        )
        self.request(
            "POST",
            "/commerce/providers/apple/notifications",
            {"signedPayload": "test"},
        )
        self.request(
            "PUT",
            "/installations/device-12345678",
            {"platform": "ios", "token": "valid-token-value"},
            bearer="host-token",
        )
        self.request("DELETE", "/installations/device-12345678", bearer="host-token")
        self.assert_ok(
            self.request("POST", "/presence", {"sessionID": None}, bearer="host-token")
        )
        leaderboard = self.assert_ok(self.request("GET", "/leaderboard"))
        self.assertEqual(leaderboard["players"][0]["userID"], "host")
        self.assert_ok(self.request("GET", "/profile", bearer="host-token"))
        self.request("PATCH", "/profile", {"displayName": "Host"})
        self.assert_ok(self.request("GET", "/profiles/guest"))
        self.assert_ok(self.request("GET", "/results/recent", bearer="host-token"))
        self.request("GET", "/results/missing/replay", bearer="host-token")
        self.request("POST", "/results/missing/rematch", bearer="host-token")
        self.request("GET", "/challenges/daily", bearer="host-token")
        self.request("POST", "/challenges/daily/start", bearer="host-token")
        self.request("GET", "/tournaments/weekly", bearer="host-token")
        self.request("POST", "/tournaments/weekly/join", bearer="host-token")
        self.request("POST", "/tournaments/weekly/leave", bearer="host-token")
        self.assert_ok(self.request("GET", "/comrades", bearer="host-token"))
        self.assert_ok(
            self.request(
                "POST", "/comrades", {"comradeCode": "GUEST001"}, bearer="host-token"
            )
        )
        self.assert_ok(
            self.request(
                "POST",
                "/comrades/respond",
                {"userID": "guest", "accept": True},
                bearer="host-token",
            )
        )
        self.assert_ok(
            self.request(
                "POST", "/comrades/remove", {"userID": "guest"}, bearer="host-token"
            )
        )

        created = self.assert_ok(
            self.request(
                "POST",
                "/sessions",
                {
                    "seed": 42,
                    "controllers": ["human", "human", "human", "human"],
                    "browserJoinable": True,
                },
                bearer="host-token",
            )
        )
        session_id = created["sessionID"]
        host_seat_token = created["seatToken"]
        self.assert_ok(self.request("GET", "/sessions"))
        self.assert_ok(self.request("GET", "/sessions/watchable"))
        self.request("GET", f"/sessions/{session_id}/spectate")
        self.assert_ok(self.request("GET", f"/sessions/{session_id}"))
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{session_id}/invites",
                {"userIDs": ["guest"]},
                bearer="host-token",
            )
        )
        pending = self.assert_ok(
            self.request("GET", "/sessions/invites", bearer="guest-token")
        )
        self.assertEqual(pending[0]["invitedUserID"], "guest")
        self.assertEqual(pending[0]["hostProfile"]["userID"], "host")
        self.assertEqual(pending[0]["hostProfile"]["displayName"], "Host")
        self.assertNotIn("inviteCode", pending[0])
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{session_id}/invites/decline",
                {},
                bearer="guest-token",
            )
        )
        joined = self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{created['inviteCode'].lower()}/join",
                {"preferredPlayerID": 1},
                bearer="guest-token",
            )
        )
        guest_seat_token = joined["seatToken"]
        matched = self.assert_ok(
            self.request(
                "POST",
                "/sessions/matchmake",
                {"rankedOnly": False},
                bearer="third-token",
            )
        )
        self.assertEqual(matched["sessionID"], session_id)
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{session_id}/players/2/kick",
                {"hostPlayerID": 0},
                bearer="host-token",
                seat_token=host_seat_token,
            )
        )
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{created['inviteCode']}/join",
                {"preferredPlayerID": 2},
                bearer="third-token",
            )
        )
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{created['inviteCode']}/join",
                {"preferredPlayerID": 3},
                bearer="fourth-token",
            )
        )

        synced = self.assert_ok(
            self.request("POST", "/active-session/sync", {}, bearer="host-token")
        )
        host_seat_token = synced["seatToken"]
        self.assert_ok(
            self.request(
                "GET",
                f"/sessions/{session_id}/state?viewerID=0",
                bearer="host-token",
                seat_token=host_seat_token,
            )
        )
        legal = self.assert_ok(
            self.request(
                "GET",
                f"/sessions/{session_id}/players/0/actions",
                bearer="host-token",
                seat_token=host_seat_token,
            )
        )
        self.assertEqual(legal[0]["playerID"], 0)
        with (
            patch.object(
                self.runtime,
                "advance_and_state",
                wraps=self.runtime.advance_and_state,
            ) as advance_and_state,
            patch.object(
                self.application.lobby,
                "touch_seat",
                wraps=self.application.lobby.touch_seat,
            ) as touch_seat,
        ):
            updated = self.assert_ok(
                self.request(
                    "POST",
                    f"/sessions/{session_id}/actions",
                    {
                        "playerID": 0,
                        "actionLogCount": 0,
                        "action": {"type": "add", "delta": 2, "playerID": 0},
                    },
                    bearer="host-token",
                    seat_token=host_seat_token,
                )
            )
        advance_and_state.assert_not_called()
        touch_seat.assert_called_once()
        self.assertEqual(updated["actionLogCount"], 1)
        incremental = self.assert_ok(
            self.request(
                "GET",
                f"/sessions/{session_id}/actions?viewerID=0&afterRevision=0",
                bearer="host-token",
                seat_token=host_seat_token,
            )
        )
        self.assertEqual(incremental["updates"], [])
        self.assertEqual(incremental["resyncUpdate"]["actionLogCount"], 1)
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{session_id}/reactions",
                {"playerID": 0, "reactionID": "comrade"},
                bearer="host-token",
                seat_token=host_seat_token,
            )
        )
        self.assert_ok(
            self.request(
                "POST",
                f"/sessions/{session_id}/players/1/leave",
                {},
                bearer="guest-token",
                seat_token=guest_seat_token,
            )
        )

        expected = {(route.method, route.path) for route in ROUTES}
        self.assertEqual(expected, self.exercised)


if __name__ == "__main__":
    unittest.main()
