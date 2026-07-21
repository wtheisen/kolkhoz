from __future__ import annotations

import unittest

from research.kolkhoz_research.c_engine import (
    CEngine,
    KCControllers,
    KCCard,
    KCRequisitionEvent,
)


_ACTION_PRIORITY = {6: 0, 7: 0, 3: 0, 1: 1, 4: 1, 5: 1, 2: 2, 8: 3}


class StepwiseRequisitionTests(unittest.TestCase):
    def test_party_official_exiles_do_not_pre_reveal_hidden_cards(self) -> None:
        engine = CEngine()
        pointer = engine.new_engine(7)

        try:
            state = engine.snapshot(pointer)
            state.phase = 4
            state.year = 1
            state.trump = 2
            state.variants.nomenclature = True
            state.players[0].plot_hidden.cards[0] = KCCard(0, 10)
            state.players[0].plot_hidden.cards[1] = KCCard(0, 9)
            state.players[0].plot_hidden.count = 2
            state.requisition_event_count = 0
            state.requisition_plan[0] = KCRequisitionEvent(0, 0, KCCard(0, 8), 1)
            state.requisition_plan[1] = KCRequisitionEvent(0, 0, KCCard(0, 7), 1)
            state.requisition_plan_count = 2
            state.requisition_plan_index = 0

            self.assertEqual(engine.step_automatic(pointer), 1)
            after_first = engine.snapshot(pointer)
            self.assertEqual(int(after_first.players[0].plot_hidden.count), 2)
            self.assertEqual(int(after_first.players[0].plot_revealed.count), 0)

            self.assertEqual(engine.step_automatic(pointer), 1)
            after_second = engine.snapshot(pointer)
            self.assertEqual(int(after_second.players[0].plot_hidden.count), 2)
            self.assertEqual(int(after_second.players[0].plot_revealed.count), 0)
            self.assertEqual(int(after_second.exiled[1].count), 2)
        finally:
            engine.free_engine(pointer)

    def test_requisition_advances_one_event_per_automatic_step(self) -> None:
        engine = CEngine()
        controllers = KCControllers()
        for player_id in range(4):
            controllers.seats[player_id] = 0
        pointer = engine.new_engine(3, controllers=controllers)

        try:
            event_steps = 0
            for _ in range(500):
                state = engine.snapshot(pointer)
                if int(state.phase) == 5:
                    break
                if int(state.phase) == 4:
                    previous_events = int(state.requisition_event_count)
                    previous_exiled = int(state.exiled[state.year].count)
                    status = engine.step_automatic(pointer)
                    next_state = engine.snapshot(pointer)
                    if status > 0:
                        self.assertEqual(
                            int(next_state.requisition_event_count),
                            previous_events + 1,
                        )
                        self.assertIn(
                            int(next_state.exiled[next_state.year].count)
                            - previous_exiled,
                            (0, 1),
                        )
                        next_actions = engine.legal_actions(pointer)
                        if engine.waiting_player(pointer) < 0:
                            self.assertEqual(next_actions, [])
                        else:
                            self.assertEqual(
                                [int(action.kind) for action in next_actions],
                                [7],
                            )
                        event_steps += 1
                        continue

                actions = engine.legal_actions(pointer)
                if not actions:
                    self.assertGreater(engine.step_automatic(pointer), 0)
                    continue
                action = min(
                    actions,
                    key=lambda candidate: (
                        _ACTION_PRIORITY.get(int(candidate.kind), 9),
                        int(candidate.kind),
                        int(candidate.player_id),
                        int(candidate.suit),
                        int(candidate.card.suit),
                        int(candidate.card.value),
                    ),
                )
                self.assertEqual(engine.lib.kc_engine_apply_manual(pointer, action), 0)

            self.assertGreater(event_steps, 1)
            self.assertEqual(int(engine.snapshot(pointer).phase), 5)
        finally:
            engine.free_engine(pointer)


if __name__ == "__main__":
    unittest.main()
