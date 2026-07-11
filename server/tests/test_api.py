from __future__ import annotations

import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

from server.kolkhoz_server.api import OnlineApplication
from server.kolkhoz_server.auth import StaticAuthVerifier
from server.kolkhoz_server.gateway import Gateway
from server.kolkhoz_server.lobby import SQLiteLobbyRepository
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore
from server.tests.test_runtime import FakeEngineFactory


class FakeResults:
    def __init__(self) -> None:
        self.abandoned: list[tuple[str, int]] = []

    def abandon_seat(self, **values: object) -> dict[str, object]:
        self.abandoned.append((str(values["session_id"]), int(values["player_id"])))
        return {"strikes": 1, "banned_until": None}

    def finish_session(self, **values: object) -> bool:
        return True

    def online_ban_for_user(self, **values: object) -> None:
        return None


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
            SQLiteLobbyRepository(database),
            auth=StaticAuthVerifier({"host-token": "host", "guest-token": "guest"}),
            lobby_countdown_seconds=0,
            results=FakeResults(),
        )
        self.server = Gateway(
            ("127.0.0.1", 0), self.runtime, application=self.application
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.runtime.close()
        self.thread.join(timeout=2)
        self.temporary.cleanup()

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
        request = urllib.request.Request(
            self.base_url + path,
            data=None if body is None else json.dumps(body).encode(),
            method=method,
            headers=headers,
        )
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                payload = response.read()
                return response.status, json.loads(payload) if payload else {}
        except urllib.error.HTTPError as error:
            try:
                return error.code, json.loads(error.read())
            finally:
                error.close()

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
