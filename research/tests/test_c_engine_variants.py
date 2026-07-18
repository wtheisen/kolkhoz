from __future__ import annotations

import unittest

from research.kolkhoz_research.c_engine import CEngine, KCAction, KCCard, KCControllers


NO_CARD = KCCard(-1, 0)


def action(kind: int, player_id: int, card: KCCard = NO_CARD) -> KCAction:
    return KCAction(kind, player_id, -1, card, NO_CARD, NO_CARD, -1, -1)


class VariantEngineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.engine = CEngine()
        self.controllers = KCControllers()
        for player_id in range(4):
            self.controllers.seats[player_id] = 0

    def test_kolkhoz_defaults_enable_new_variants(self) -> None:
        variants = self.engine.kolkhoz_variants()
        self.assertTrue(variants.final_year_trump)
        self.assertTrue(variants.pass_cards)
        self.assertTrue(variants.highest_cards_requisition)
        self.assertTrue(variants.lotto_rewards)

    def test_lotto_builds_seeded_reward_piles_and_removes_rewards_from_hands(self) -> None:
        first = self.engine.new_engine(20260718, controllers=self.controllers)
        second = self.engine.new_engine(20260718, controllers=self.controllers)
        try:
            first_state = self.engine.snapshot(first)
            second_state = self.engine.snapshot(second)
            for suit in range(4):
                first_rewards = [
                    int(first_state.revealed_jobs[suit].value),
                    *[
                        int(first_state.job_piles[suit].cards[index].value)
                        for index in range(int(first_state.job_piles[suit].count))
                    ],
                ]
                second_rewards = [
                    int(second_state.revealed_jobs[suit].value),
                    *[
                        int(second_state.job_piles[suit].cards[index].value)
                        for index in range(int(second_state.job_piles[suit].count))
                    ],
                ]
                self.assertEqual(sorted(first_rewards[:]), sorted([1, 2, 3, 4, max(first_rewards)]))
                self.assertEqual(sum(value >= 5 for value in first_rewards), 1)
                self.assertEqual(first_rewards, second_rewards)
                lotto = next(value for value in first_rewards if value >= 5)
                self.assertFalse(
                    any(
                        int(first_state.players[player].hand.cards[index].suit) == suit
                        and int(first_state.players[player].hand.cards[index].value) == lotto
                        for player in range(4)
                        for index in range(int(first_state.players[player].hand.count))
                    )
                )
        finally:
            self.engine.free_engine(first)
            self.engine.free_engine(second)

    def test_pass_waits_for_every_player_then_moves_left_in_year_two(self) -> None:
        pointer = self.engine.new_engine(44, controllers=self.controllers)
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 6
            state.year = 2
            chosen = [
                KCCard(
                    int(state.players[player].hand.cards[0].suit),
                    int(state.players[player].hand.cards[0].value),
                )
                for player in range(4)
            ]
            before = [int(state.players[player].hand.count) for player in range(4)]
            for player in range(3):
                self.assertEqual(
                    self.engine.lib.kc_engine_apply_manual(pointer, action(9, player, chosen[player])),
                    0,
                )
                current = self.engine.snapshot(pointer)
                self.assertEqual(int(current.phase), 6)
                self.assertEqual([int(current.players[p].hand.count) for p in range(4)], before)
            self.assertEqual(
                self.engine.lib.kc_engine_apply_manual(pointer, action(9, 3, chosen[3])),
                0,
            )
            resolved = self.engine.snapshot(pointer)
            self.assertEqual(int(resolved.phase), 1)
            for sender, card in enumerate(chosen):
                recipient = (sender + 1) % 4
                self.assertTrue(
                    any(
                        resolved.players[recipient].hand.cards[index].suit == card.suit
                        and resolved.players[recipient].hand.cards[index].value == card.value
                        for index in range(int(resolved.players[recipient].hand.count))
                    )
                )
        finally:
            self.engine.free_engine(pointer)

    def test_pass_moves_right_in_years_three_and_five(self) -> None:
        for year in (3, 5):
            with self.subTest(year=year):
                pointer = self.engine.new_engine(44 + year, controllers=self.controllers)
                try:
                    state = self.engine.snapshot(pointer)
                    state.phase = 6
                    state.year = year
                    chosen = [
                        KCCard(
                            int(state.players[player].hand.cards[0].suit),
                            int(state.players[player].hand.cards[0].value),
                        )
                        for player in range(4)
                    ]
                    for player, card in enumerate(chosen):
                        self.assertEqual(
                            self.engine.lib.kc_engine_apply_manual(
                                pointer, action(9, player, card)
                            ),
                            0,
                        )
                    resolved = self.engine.snapshot(pointer)
                    for sender, card in enumerate(chosen):
                        recipient = (sender - 1) % 4
                        self.assertTrue(
                            any(
                                resolved.players[recipient].hand.cards[index].suit
                                == card.suit
                                and resolved.players[recipient]
                                .hand.cards[index]
                                .value
                                == card.value
                                for index in range(
                                    int(resolved.players[recipient].hand.count)
                                )
                            )
                        )
                finally:
                    self.engine.free_engine(pointer)

    def test_passing_does_not_run_in_year_one(self) -> None:
        pointer = self.engine.new_engine(52, controllers=self.controllers)
        try:
            state = self.engine.snapshot(pointer)
            selector = int(state.trump_selector)
            self.assertEqual(
                self.engine.lib.kc_engine_apply_manual(
                    pointer, KCAction(1, selector, 0, NO_CARD, NO_CARD, NO_CARD, -1, -1)
                ),
                0,
            )
            self.assertEqual(int(self.engine.snapshot(pointer).phase), 2)
        finally:
            self.engine.free_engine(pointer)

    def test_final_year_leftover_card_is_public_north_trump(self) -> None:
        pointer = self.engine.new_engine(20260719, controllers=self.controllers)
        try:
            for _ in range(1000):
                state = self.engine.snapshot(pointer)
                if int(state.year) == 5 and int(state.phase) == 6:
                    break
                actions = self.engine.legal_actions(pointer)
                if actions:
                    chosen = min(
                        actions,
                        key=lambda candidate: (
                            int(candidate.kind),
                            int(candidate.player_id),
                            int(candidate.suit),
                            int(candidate.card.value),
                        ),
                    )
                    self.assertEqual(
                        self.engine.lib.kc_engine_apply_manual(pointer, chosen), 0
                    )
                else:
                    self.assertGreater(self.engine.step_automatic(pointer), 0)
            final_year = self.engine.snapshot(pointer)
            self.assertEqual((int(final_year.year), int(final_year.phase)), (5, 6))
            revealed = final_year.final_year_trump_card
            self.assertTrue(
                (0 <= int(revealed.suit) < 4 and int(revealed.value) > 0)
                or (int(revealed.suit), int(revealed.value)) == (4, 14)
            )
            north = final_year.exiled[5]
            self.assertTrue(
                any(
                    north.cards[index].suit == revealed.suit
                    and north.cards[index].value == revealed.value
                    for index in range(int(north.count))
                )
            )
            expected_trump = -1 if int(revealed.suit) == 4 else int(revealed.suit)
            self.assertEqual(int(final_year.trump), expected_trump)
        finally:
            self.engine.free_engine(pointer)

    def _planned_requisition_cards(
        self,
        *,
        drunkard: bool = False,
        party_official: bool = False,
    ) -> list[tuple[int, int]]:
        pointer = self.engine.new_engine(91, controllers=self.controllers)
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.year = 1
            state.last_winner = 0
            state.last_trick_count = 0
            state.trick_count = 4
            state.variants.highest_cards_requisition = True
            state.variants.northern_style = True
            state.variants.hero_of_soviet_union = False
            state.variants.nomenclature = drunkard or party_official
            state.trump = 0
            for suit in range(4):
                state.work_hours[suit] = 40
            for player in range(4):
                state.players[player].hand.count = 0
                state.players[player].plot_hidden.count = 0
                state.players[player].plot_revealed.count = 0
            state.work_hours[0] = 0
            state.work_hours[1] = 0
            cards = [KCCard(0, 10), KCCard(1, 9), KCCard(0, 8), KCCard(1, 7)]
            for index, card in enumerate(cards):
                state.players[0].plot_hidden.cards[index] = card
            state.players[0].plot_hidden.count = len(cards)
            if drunkard:
                state.job_buckets[0].cards[0] = KCCard(0, 11)
                state.job_buckets[0].count = 1
            if party_official:
                state.job_buckets[0].cards[0] = KCCard(0, 13)
                state.job_buckets[0].count = 1
            self.assertEqual(
                self.engine.lib.kc_engine_apply_manual(pointer, action(6, 0)),
                0,
            )
            planned = self.engine.snapshot(pointer)
            return [
                (int(planned.requisition_plan[index].card.suit), int(planned.requisition_plan[index].card.value))
                for index in range(int(planned.requisition_plan_count))
                if int(planned.requisition_plan[index].player_id) == 0
            ]
        finally:
            self.engine.free_engine(pointer)

    def test_highest_cards_requisition_uses_one_combined_quota(self) -> None:
        self.assertEqual(self._planned_requisition_cards(), [(0, 10), (1, 9)])

    def test_drunkard_removes_its_suit_and_reduces_quota(self) -> None:
        self.assertEqual(self._planned_requisition_cards(drunkard=True), [(1, 9)])

    def test_party_official_adds_one_to_the_combined_quota(self) -> None:
        self.assertEqual(
            self._planned_requisition_cards(party_official=True),
            [(0, 10), (1, 9), (0, 8)],
        )


if __name__ == "__main__":
    unittest.main()
