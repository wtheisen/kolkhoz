from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "scripts/run_authenticated_online_smoke.py"
SPEC = importlib.util.spec_from_file_location("online_smoke", SCRIPT)
assert SPEC and SPEC.loader
online_smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(online_smoke)


class OnlineSmokeTests(unittest.TestCase):
    def test_append_result_creates_jsonl_record(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "smoke.jsonl"
            with mock.patch.dict(
                os.environ, {"KOLKHOZ_SMOKE_RESULT_LOG": str(path)}
            ):
                online_smoke._append_result({"status": "passed", "actions": 12})

            self.assertEqual(
                json.loads(path.read_text(encoding="utf-8")),
                {"status": "passed", "actions": 12},
            )

    def test_progression_games_handles_missing_row(self) -> None:
        with mock.patch.object(online_smoke, "request_json", return_value=[]):
            self.assertEqual(
                online_smoke._progression_games("url", "key", "token", "user"),
                0,
            )

    def test_progression_games_reads_game_counter(self) -> None:
        payload = [{"progress": {"challenge.games_5": 7}}]
        with mock.patch.object(online_smoke, "request_json", return_value=payload):
            self.assertEqual(
                online_smoke._progression_games("url", "key", "token", "user"),
                7,
            )


if __name__ == "__main__":
    unittest.main()
