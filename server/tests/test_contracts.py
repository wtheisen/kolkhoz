from __future__ import annotations

import ctypes
import unittest
from http import HTTPStatus

from research.kolkhoz_research.c_engine import (
    CEngine,
    KCAction,
    KCCard,
    KCEngineSnapshot,
    build_shared_library,
)
from server.kolkhoz_server.contracts import (
    DEFAULT_VARIANTS,
    action_from_json,
    action_in,
    action_to_json,
    card_from_json,
    card_to_json,
    controllers_native,
    listing_json,
    normalize_controllers,
    normalize_variants,
    optional_bool,
    optional_int,
    privacy_safe_action_log,
    snapshot_json,
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
        self.assertFalse(native.pass_cards)
        self.assertTrue(native.wrecker)

    def test_passing_remains_available_as_an_explicit_custom_variant(self) -> None:
        normalized = normalize_variants({"passCards": True})

        self.assertTrue(normalized["passCards"])
        self.assertTrue(variants_native(normalized).pass_cards)

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
    def test_legacy_wrecker_wire_value_maps_to_zero_value_engine_card(self) -> None:
        decoded = card_from_json({"suit": 4, "value": 14})
        self.assertEqual((decoded.suit, decoded.value), (4, 0))
        self.assertEqual(card_to_json(decoded), {"suit": 4, "value": 14})

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

    def test_pass_card_is_never_exposed_to_other_viewers(self) -> None:
        action = action_to_json(
            KCAction(9, 2, -1, KCCard(3, 12), KCCard(-1, 0), KCCard(-1, 0), -1, -1)
        )
        other = privacy_safe_action_log([action], 0, game_over=False)[0]
        owner = privacy_safe_action_log([action], 2, game_over=False)[0]
        finished = privacy_safe_action_log([action], 0, game_over=True)[0]
        self.assertEqual(other["card"], {"suit": -1, "value": -1})
        self.assertEqual(owner["card"], {"suit": 3, "value": 12})
        self.assertEqual(finished["card"], {"suit": -1, "value": -1})


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
            viewed["exiledPlayers"],
            [{"suit": year, "values": []} for year in range(6)],
        )
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
                "exiledPlayers",
                "pendingAssignments",
                "requisitionEvents",
                "scores",
                "winnerID",
                "swapConfirmed",
                "swapCount",
                "passConfirmed",
                "finalYearTrumpCard",
            },
        )

    def test_snapshot_pairs_each_exiled_card_with_its_player(self) -> None:
        pointer = self.engine.new_engine(
            654,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = ctypes.cast(pointer, ctypes.POINTER(KCEngineSnapshot)).contents
            state.exiled[2].cards[0] = KCCard(1, 10)
            state.exiled[2].cards[1] = KCCard(3, 7)
            state.exiled[2].count = 2
            state.exiled_player_ids[2][0] = 1
            state.exiled_player_ids[2][1] = 3
            viewed = snapshot_json(self.engine, pointer, 0)
        finally:
            self.engine.free_engine(pointer)
        self.assertEqual(viewed["exiledPlayers"][2], {"suit": 2, "values": [1, 3]})

    def test_listing_keeps_flutter_envelope_names(self) -> None:
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
