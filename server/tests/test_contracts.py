from __future__ import annotations

import unittest
from http import HTTPStatus

from research.kolkhoz_research.c_engine import (
    CEngine,
    KCAction,
    KCCard,
    build_shared_library,
)
from server.kolkhoz_server.contracts import (
    DEFAULT_VARIANTS,
    action_from_json,
    action_in,
    action_to_json,
    controllers_native,
    listing_json,
    normalize_controllers,
    normalize_variants,
    optional_bool,
    optional_int,
    privacy_safe_action_log,
    snapshot_json,
    update_json,
    variants_native,
)
from server.kolkhoz_server.errors import ServerError


class ContractNormalizationTests(unittest.TestCase):
    def test_normalizes_variants_without_accepting_unknown_fields(self) -> None:
        self.assertEqual(normalize_variants(None), DEFAULT_VARIANTS)
        normalized = normalize_variants({"allowSwap": False, "futureRule": True})
        self.assertFalse(normalized["allowSwap"])
        self.assertNotIn("futureRule", normalized)
        native = variants_native(normalized)
        self.assertFalse(native.allow_swap)
        self.assertTrue(native.wrecker)

    def test_normalizes_four_supported_controllers_and_keeps_a_human(self) -> None:
        self.assertEqual(
            normalize_controllers(["neuralAI", "mediumAI"]),
            ["neuralAI", "mediumAI", "human", "human"],
        )
        all_ai = normalize_controllers(["heuristicAI"] * 4)
        self.assertEqual(all_ai[0], "human")
        native = controllers_native(all_ai)
        self.assertEqual(list(native.seats), [0, 1, 1, 1])

    def test_rejects_invalid_contract_scalars(self) -> None:
        for value in (True, "not-an-int"):
            with self.subTest(value=value), self.assertRaises(ServerError) as raised:
                optional_int(value)
            self.assertEqual(raised.exception.status, HTTPStatus.BAD_REQUEST)
        self.assertTrue(optional_bool("yes"))
        self.assertFalse(optional_bool("0"))
        with self.assertRaises(ServerError):
            normalize_controllers(["impossibleAI"])


class ActionContractTests(unittest.TestCase):
    def test_portable_action_round_trip_and_membership(self) -> None:
        action = KCAction(8, 2, -1, KCCard(-1, 0), KCCard(1, 7), KCCard(3, 9), 1, -1)
        encoded = action_to_json(action, source="automatic")
        self.assertEqual(encoded["source"], "automatic")
        decoded = action_from_json(encoded)
        self.assertTrue(action_in(decoded, [action]))
        self.assertEqual(
            action_to_json(decoded), {k: v for k, v in encoded.items() if k != "source"}
        )

    def test_missing_optional_cards_use_engine_sentinels(self) -> None:
        action = action_from_json({"kind": 0, "playerID": 1})
        self.assertEqual((action.card.suit, action.card.value), (-1, 0))
        self.assertEqual(action.plot_zone, -1)
        with self.assertRaises(ServerError) as raised:
            action_from_json({"kind": 0})
        self.assertEqual(str(raised.exception), "missing playerID")

    def test_swap_secrets_are_redacted_only_from_other_viewers_before_game_over(
        self,
    ) -> None:
        action = action_to_json(
            KCAction(8, 1, -1, KCCard(-1, 0), KCCard(0, 6), KCCard(2, 9), 0, -1)
        )
        other = privacy_safe_action_log([action], 0, game_over=False)[0]
        owner = privacy_safe_action_log([action], 1, game_over=False)[0]
        finished = privacy_safe_action_log([action], 0, game_over=True)[0]
        self.assertEqual(other["handCard"], {"suit": -1, "value": -1})
        self.assertEqual(owner["handCard"], {"suit": 0, "value": 6})
        self.assertEqual(finished["plotCard"], {"suit": 2, "value": 9})


class ProjectionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = CEngine(build_shared_library())

    def test_snapshot_exposes_only_the_viewers_private_cards(self) -> None:
        controllers = controllers_native(["human"] * 4)
        pointer = self.engine.new_engine(
            321,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers,
        )
        try:
            viewed = snapshot_json(self.engine, pointer, 0)
            spectator = snapshot_json(self.engine, pointer, None)
        finally:
            self.engine.free_engine(pointer)
        self.assertGreater(len(viewed["players"][0]["hand"]), 0)
        self.assertEqual(viewed["players"][1]["hand"], [])
        self.assertTrue(all(player["hand"] == [] for player in spectator["players"]))
        self.assertTrue(all(pile["cards"] == [] for pile in viewed["jobPiles"]))
        self.assertEqual(
            set(viewed),
            {
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
            },
        )

    def test_update_and_listing_keep_flutter_envelope_names(self) -> None:
        snapshot = {"phase": 2, "waitingPlayer": 0}
        action = KCAction(0, 0, 1, KCCard(-1, 0), KCCard(-1, 0), KCCard(-1, 0), -1, -1)
        update = update_json(
            session_id="s",
            seed=4,
            invite_code="invite",
            viewer_id=0,
            actions=[],
            started=True,
            lobby_countdown_ends_at=None,
            reactions=[],
            variants=DEFAULT_VARIANTS,
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            player_profiles=[],
            seat_presence=[],
            turn_player_id=0,
            turn_deadline_at=12.0,
            snapshot=snapshot,
            legal_actions=[action],
        )
        self.assertTrue(update["isViewerTurn"])
        self.assertEqual(update["legalActions"], [action_to_json(action)])
        self.assertEqual(update["actionLogCount"], 0)

        listing = listing_json(
            session_id="s",
            invite_code="invite",
            open_seats=[3, 1],
            occupied_seats={2, 0},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            player_profiles=[],
            seat_presence=[],
            turn_player_id=None,
            turn_deadline_at=None,
            action_log_count=0,
            started=False,
            lobby_countdown_ends_at=None,
            created_at=1.0,
            expires_at=2.0,
        )
        self.assertEqual(listing["occupiedSeats"], [0, 2])
        self.assertEqual(listing["openSeats"], [3, 1])
        self.assertEqual(
            set(listing),
            {
                "sessionID",
                "inviteCode",
                "openSeats",
                "occupiedSeats",
                "controllers",
                "ranked",
                "browserJoinable",
                "playerProfiles",
                "seatPresence",
                "turnPlayerID",
                "turnDeadlineAt",
                "actionLogCount",
                "started",
                "lobbyCountdownEndsAt",
                "createdAt",
                "expiresAt",
            },
        )


if __name__ == "__main__":
    unittest.main()
