from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore


class RealCEngineRecoveryTests(unittest.TestCase):
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
