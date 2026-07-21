from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from server.kolkhoz_server.ai import AutomaticAdvancer, ModelCache
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore


class RealCEngineRecoveryTests(unittest.TestCase):
    def test_server_advances_central_planner_reveals_before_human_trump(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "central-planner.sqlite3"
            runtime = GameRuntime(
                SQLiteEventStore(database),
                shard_count=1,
                automatic_advancer=AutomaticAdvancer(
                    ModelCache({}, lambda path: object())
                ),
            )
            try:
                runtime.create_game(
                    seed=42042,
                    variants={"variants": {}, "controllers": ["human"] * 4},
                    session_id="central-planner",
                )

                applied = runtime.advance_automatic("central-planner", now=0)
                update = runtime.state("central-planner")
                events = runtime.events("central-planner")
            finally:
                runtime.close()

            self.assertEqual(applied, 4)
            self.assertEqual(update.revision, 4)
            self.assertTrue(update.state["legalActions"])
            self.assertTrue(
                all(action["kind"] == 1 for action in update.state["legalActions"])
            )
            self.assertEqual([event.payload["kind"] for event in events], [10] * 4)
            self.assertTrue(
                all(event.payload["source"] == "automatic" for event in events)
            )

    def test_replacement_worker_replays_identical_authoritative_c_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "real-engine.sqlite3"
            settings = {
                "variants": {},
                "controllers": ["human"] * 4,
            }
            first = GameRuntime(SQLiteEventStore(database), shard_count=2)
            first.create_game(seed=42042, variants=settings, session_id="real-replay")
            before = first.state("real-replay").state
            legal = before["legalActions"]
            self.assertTrue(legal)
            first.submit_action("real-replay", expected_revision=0, action=legal[0])
            committed = first.state("real-replay").state
            first.close()

            replacement = GameRuntime(SQLiteEventStore(database), shard_count=3)
            try:
                recovered = replacement.state("real-replay").state
            finally:
                replacement.close()

            self.assertEqual(recovered, committed)


if __name__ == "__main__":
    unittest.main()
