from __future__ import annotations

import unittest

from research.kolkhoz_research.c_engine import CEngine
from research.kolkhoz_research.online_trajectories import (
    OnlineReplayEvent,
    OnlineReplayGame,
    OnlineReplayResult,
    ReplayCompatibilityError,
    trajectory_records_for_game,
)
from server.kolkhoz_server.contracts import (
    action_to_json,
    controllers_native,
    normalize_controllers,
    normalize_variants,
    variants_native,
)
from server.kolkhoz_server.model import ENGINE_REPLAY_CONTRACT_VERSION


class OnlineTrajectoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = CEngine()

    def _completed_game(self, seed: int = 20260724) -> OnlineReplayGame:
        variants = normalize_variants(None)
        controllers = normalize_controllers(None)
        pointer = self.engine.new_engine(
            seed,
            variants=variants_native(variants),
            controllers=controllers_native(controllers),
        )
        events: list[OnlineReplayEvent] = []
        try:
            revision = 0
            while self.engine.phase(pointer) != 5:
                action = self.engine.heuristic_action(pointer)
                revision += 1
                if int(action.kind) in (10, 11):
                    source = "automatic"
                    self.engine.apply_ai_action(pointer, action)
                else:
                    source = None
                    self.engine.apply_action(pointer, action)
                events.append(
                    OnlineReplayEvent(
                        revision,
                        action_to_json(action, source=source),
                    )
                )
            scores = self.engine.final_scores(pointer)
            winner = self.engine.winner_id(pointer)
        finally:
            self.engine.free_engine(pointer)

        ordered_scores = sorted(set(scores), reverse=True)
        return OnlineReplayGame(
            session_id="00000000-0000-0000-0000-000000000001",
            seed=seed,
            variants={"variants": variants, "controllers": controllers},
            engine_build_sha=self.engine.provenance().git_sha,
            engine_sha256=self.engine.provenance().c_sha256,
            engine_contract_version=ENGINE_REPLAY_CONTRACT_VERSION,
            completed_at="2026-07-24T12:00:00+00:00",
            results=tuple(
                OnlineReplayResult(
                    player_id=player_id,
                    score=score,
                    rank=ordered_scores.index(score) + 1,
                    won=player_id == winner,
                    rating_before=1600 + player_id,
                )
                for player_id, score in enumerate(scores)
            ),
            events=tuple(events),
        )

    def test_replays_complete_human_game_into_masked_training_records(self) -> None:
        game = self._completed_game()

        records = trajectory_records_for_game(
            self.engine,
            game,
            input_size=200,
        )

        self.assertGreater(len(records), 0)
        self.assertTrue(all(record["source"] == "online-human-expert" for record in records))
        self.assertTrue(all(record["source_game"] == game.session_id for record in records))
        self.assertTrue(all("user_id" not in record for record in records))
        self.assertTrue(
            all(record["features"]["candidate_count"] > 1 for record in records)
        )
        self.assertTrue(
            all(
                len(record["features"]["features"])
                == record["features"]["candidate_count"] * 200
                for record in records
            )
        )
        self.assertIn("target_value", records[0])
        assignment_revisions = {
            event.revision
            for event in game.events
            if int(event.payload["kind"]) == 5
            and event.payload.get("source") != "automatic"
        }
        exported_assignment_revisions = {
            int(record["action_index"])
            for record in records
            if record["phase"] == "assignment"
        }
        self.assertGreater(len(assignment_revisions), 0)
        self.assertEqual(exported_assignment_revisions, assignment_revisions)

    def test_rejects_game_from_different_engine_digest(self) -> None:
        game = self._completed_game()
        incompatible = OnlineReplayGame(
            **{**game.__dict__, "engine_sha256": "different-engine"}
        )

        with self.assertRaises(ReplayCompatibilityError):
            trajectory_records_for_game(
                self.engine,
                incompatible,
                input_size=200,
            )


if __name__ == "__main__":
    unittest.main()
