from __future__ import annotations

import tempfile
import threading
import unittest
from pathlib import Path

from server.kolkhoz_server.ai import (
    AUTOMATIC_BATCH_LIMIT,
    AutomaticAdvancer,
    AutomaticState,
    ModelCache,
    bot_action_delay,
    deterministic_profile,
)


class FakeEngine:
    def __init__(self, waiting: list[int], controllers: list[str]) -> None:
        self.waiting = waiting
        self.controllers = controllers
        self.applied: list[dict[str, object]] = []
        self.policy_observed_controller: str | None = None
        self.rejected_kinds: set[int] = set()

    def waiting_player(self) -> int:
        return self.waiting[0] if self.waiting else -1

    def legal_actions(self):
        player = self.waiting_player()
        return [
            {"playerID": player, "kind": 1},
            {"playerID": player, "kind": 2, "model": "medium-model"},
        ]

    def heuristic_action(self):
        return {"playerID": self.waiting_player(), "kind": 1}

    def policy_action(self, model: object):
        player = self.waiting_player()
        self.policy_observed_controller = self.controllers[player]
        return {"playerID": player, "kind": 2, "model": str(model)}

    def apply_ai_action(self, action):
        if action.get("kind") in self.rejected_kinds:
            raise ValueError("illegal action")
        self.applied.append(action)
        self.waiting.pop(0)

    def controller(self, player_id: int) -> str:
        return self.controllers[player_id]

    def set_controller(self, player_id: int, controller: str) -> None:
        self.controllers[player_id] = controller


class AITests(unittest.TestCase):
    def test_long_automatic_sequence_is_split_into_bounded_batches(self) -> None:
        engine = FakeEngine([0] * (AUTOMATIC_BATCH_LIMIT + 2), ["heuristicAI"] * 4)
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )

        count = AutomaticAdvancer(ModelCache({}, lambda path: object())).advance(
            engine, state, now=0, record=lambda *_: None
        )

        self.assertEqual(count, AUTOMATIC_BATCH_LIMIT)
        self.assertEqual(len(engine.waiting), 2)
        self.assertEqual(state.action_count, AUTOMATIC_BATCH_LIMIT)

    def test_advances_multiple_automatic_players_until_human(self) -> None:
        engine = FakeEngine([0, 1, 2], ["heuristicAI", "mediumAI", "human", "human"])
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        recorded: list[tuple[dict[str, object], str]] = []
        models = ModelCache({"mediumAI": "unused"}, lambda path: "medium-model")

        count = AutomaticAdvancer(models).advance(
            engine,
            state,
            now=10,
            record=lambda action, source: recorded.append((action, source)),
        )

        self.assertEqual(count, 2)
        self.assertEqual([action["kind"] for action in engine.applied], [1, 2])
        self.assertEqual([source for _, source in recorded], ["automatic", "automatic"])
        self.assertEqual(state.action_count, 2)

    def test_profile_bot_policy_temporarily_flips_and_restores_controller(self) -> None:
        engine = FakeEngine([0, 1], ["human"] * 4)
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        state.assign_profile_bot(0, {"user_id": "bot", "controller": "neuralAI"})
        models = ModelCache({"neuralAI": "unused"}, lambda path: object())

        AutomaticAdvancer(models).advance(engine, state, now=0, record=lambda *_: None)

        self.assertEqual(engine.policy_observed_controller, "neuralAI")
        self.assertEqual(engine.controllers[0], "human")

    def test_policy_controller_restored_when_selection_fails(self) -> None:
        engine = FakeEngine([0], ["human"] * 4)
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        state.controller_overrides[0] = "neuralAI"
        models = ModelCache({"neuralAI": "unused"}, lambda path: object())
        engine.policy_action = lambda model: (_ for _ in ()).throw(RuntimeError("bad"))

        with self.assertRaisesRegex(RuntimeError, "bad"):
            AutomaticAdvancer(models).advance(
                engine, state, now=0, record=lambda *_: None
            )
        self.assertEqual(engine.controllers[0], "human")

    def test_illegal_policy_action_falls_back_to_first_legal_action(self) -> None:
        engine = FakeEngine([0], ["neuralAI"] * 4)
        engine.policy_action = lambda model: {"playerID": 0, "kind": 99}
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        models = ModelCache({"neuralAI": "unused"}, lambda path: object())

        AutomaticAdvancer(models).advance(engine, state, now=0, record=lambda *_: None)

        self.assertEqual(engine.applied, [{"playerID": 0, "kind": 1}])

    def test_rejected_policy_action_retries_first_legal_action(self) -> None:
        engine = FakeEngine([0], ["mediumAI"] * 4)
        engine.rejected_kinds.add(2)
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        models = ModelCache({"mediumAI": "unused"}, lambda path: "medium-model")

        AutomaticAdvancer(models).advance(engine, state, now=0, record=lambda *_: None)

        self.assertEqual(engine.applied, [{"playerID": 0, "kind": 1}])

    def test_policy_selection_illegal_action_falls_back(self) -> None:
        engine = FakeEngine([0], ["neuralAI"] * 4)
        engine.policy_action = lambda model: (_ for _ in ()).throw(
            ValueError("illegal action")
        )
        state = AutomaticState(
            "game", tuple(engine.controllers), browser_joinable=False
        )
        models = ModelCache({"neuralAI": "unused"}, lambda path: object())

        AutomaticAdvancer(models).advance(engine, state, now=0, record=lambda *_: None)

        self.assertEqual(engine.applied, [{"playerID": 0, "kind": 1}])

    def test_human_game_delay_is_deterministic_and_only_scheduled_once(self) -> None:
        engine = FakeEngine([1], ["human", "heuristicAI", "human", "human"])
        state = AutomaticState("game", tuple(engine.controllers))
        advancer = AutomaticAdvancer(ModelCache({}, lambda path: object()))

        self.assertEqual(
            advancer.advance(engine, state, now=5, record=lambda *_: None), 0
        )
        ready = state.ready_at[1]
        self.assertEqual(ready, 5 + bot_action_delay(state, 1))
        self.assertEqual(
            advancer.advance(engine, state, now=ready - 0.01, record=lambda *_: None), 0
        )
        self.assertEqual(
            advancer.advance(engine, state, now=ready, record=lambda *_: None), 1
        )

    def test_model_cache_loads_once_across_threads_and_hashes_available_models(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "model.json"
            path.write_text("model")
            calls: list[Path] = []
            cache = ModelCache(
                {"neuralAI": path}, lambda value: calls.append(value) or object()
            )
            results: list[object] = []
            threads = [
                threading.Thread(target=lambda: results.append(cache.get("neuralAI")))
                for _ in range(8)
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self.assertEqual(len(calls), 1)
            self.assertTrue(all(value is results[0] for value in results))
            self.assertEqual(len(cache.sha256() or ""), 64)

    def test_profile_restore_and_selection_are_stable(self) -> None:
        profiles = [
            {"user_id": "a", "controller": "mediumAI"},
            {"user_id": "b", "controller": "mediumAI"},
        ]
        self.assertEqual(
            deterministic_profile("game", "mediumAI", 0, profiles),
            deterministic_profile("game", "mediumAI", 0, profiles),
        )
        state = AutomaticState("game", ("human",) * 4, seat_user_ids={2: "a"})
        state.restore_profile_bots({"a": profiles[0]})
        self.assertEqual(state.effective_controller(2), "mediumAI")


if __name__ == "__main__":
    unittest.main()
