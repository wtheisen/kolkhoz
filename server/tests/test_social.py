from __future__ import annotations

import unittest

from server.kolkhoz_server.social import SocialService, _profile


ALICE = {
    "userID": "alice",
    "displayName": "Alice",
    "avatarURL": "worker1",
    "comradeCode": "ALICE001",
    "stats": {"rating": 1200, "online_games": 4},
}
BOB = {
    "userID": "bob",
    "displayName": "Bob",
    "avatarURL": None,
    "comradeCode": "BOB00001",
    "stats": {"rating": 1100},
}


class FakeRepository:
    def __init__(self) -> None:
        self.incoming = True
        self.calls: list[tuple[object, ...]] = []

    def ensure_comrade_code(self, **values):
        self.calls.append(("ensure", values))
        return "ALICE001"

    def leaderboard(self, *, limit=100):
        return [dict(ALICE), dict(BOB)]

    def public_profile(self, *, user_id):
        if user_id == "missing":
            raise ValueError("comrade profile not found")
        return dict(ALICE)

    def comrades_for_user(self, *, user_id):
        return {
            "user_id": user_id,
            "comrade_code": "ALICE001",
            "comrades": [dict(BOB)],
            "incoming_requests": [{**ALICE, "userID": "carol", "requestedAt": 12.5}],
            "outgoing_requests": [],
        }

    def send_comrade_request_by_code(self, **values):
        self.calls.append(("code", values))
        return {**BOB, "accepted": False}

    def send_comrade_request_to_user(self, **values):
        self.calls.append(("user", values))
        return {**BOB, "accepted": self.incoming}

    def respond_to_comrade_request(self, **values):
        self.calls.append(("respond", values))
        return dict(BOB) if values["accept"] else None

    def remove_comrade(self, **values):
        self.calls.append(("remove", values))


class FakePresence:
    def statuses(self, user_ids):
        return {
            user_id: {
                "isOnline": user_id == "bob",
                "inGame": False,
                "inLobby": user_id == "bob",
            }
            for user_id in user_ids
        }


class SocialServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = FakeRepository()
        self.service = SocialService(
            self.repository, presence=FakePresence(), clock=lambda: 100.0
        )

    def test_leaderboard_preserves_public_shape_and_assigns_rank(self) -> None:
        self.assertEqual(
            self.service.leaderboard(),
            {
                "players": [
                    {
                        "userID": "alice",
                        "displayName": "Alice",
                        "avatarURL": "worker1",
                        "stats": ALICE["stats"],
                        "rank": 1,
                    },
                    {
                        "userID": "bob",
                        "displayName": "Bob",
                        "avatarURL": None,
                        "stats": BOB["stats"],
                        "rank": 2,
                    },
                ]
            },
        )

    def test_public_profile_excludes_private_comrade_code(self) -> None:
        self.assertEqual(
            self.service.public_profile("alice"),
            {
                "userID": "alice",
                "displayName": "Alice",
                "avatarURL": "worker1",
                "stats": ALICE["stats"],
            },
        )

    def test_comrades_preserves_shape_and_decorates_presence(self) -> None:
        result = self.service.comrades(user_id="alice")
        self.assertEqual(result["userID"], "alice")
        self.assertEqual(result["comradeCode"], "ALICE001")
        self.assertEqual(result["comrades"][0]["userID"], "bob")
        self.assertTrue(result["comrades"][0]["isOnline"])
        self.assertTrue(result["comrades"][0]["inLobby"])
        self.assertEqual(result["incomingRequests"][0]["requestedAt"], 12.5)
        self.assertEqual(self.repository.calls[0][0], "ensure")

    def test_send_by_code_returns_pending_request(self) -> None:
        result = self.service.send_request(
            {"comradeCode": " bob-0001 "}, user_id="alice"
        )
        self.assertEqual(set(result), {"request"})
        self.assertEqual(self.repository.calls[-1][0], "code")
        self.assertEqual(self.repository.calls[-1][1]["updated_at"], 100.0)

    def test_crossed_request_returns_accepted_comrade(self) -> None:
        result = self.service.send_request({"userID": "bob"}, user_id="alice")
        self.assertEqual(set(result), {"comrade"})
        self.assertEqual(result["comrade"]["userID"], "bob")

    def test_respond_accept_and_decline_shapes(self) -> None:
        accepted = self.service.respond(
            {"userID": "bob", "accept": True}, user_id="alice"
        )
        declined = self.service.respond(
            {"userID": "bob", "accept": False}, user_id="alice"
        )
        self.assertTrue(accepted["accepted"])
        self.assertEqual(accepted["comrade"]["userID"], "bob")
        self.assertEqual(declined, {"accepted": False})

    def test_remove_and_validation(self) -> None:
        self.assertEqual(
            self.service.remove({"userID": "bob"}, user_id="alice"), {"removed": True}
        )
        with self.assertRaisesRegex(ValueError, "missing userID"):
            self.service.remove({}, user_id="alice")

    def test_database_row_defaults_match_legacy_contract(self) -> None:
        row = ["alice", "Alice", None, "ALICE001"] + [None] * 16
        result = _profile(row)
        self.assertEqual(result["stats"]["rating"], 1000)
        self.assertEqual(result["stats"]["casual_rating"], 1000)
        self.assertEqual(result["stats"]["online_games"], 0)


if __name__ == "__main__":
    unittest.main()
