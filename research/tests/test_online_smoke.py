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
            with mock.patch.dict(os.environ, {"KOLKHOZ_SMOKE_RESULT_LOG": str(path)}):
                online_smoke._append_result({"status": "passed", "actions": 12})

            self.assertEqual(
                json.loads(path.read_text(encoding="utf-8")),
                {"status": "passed", "actions": 12},
            )

    def test_games_played_handles_missing_row(self) -> None:
        with mock.patch.object(online_smoke, "request_json", return_value=[]):
            self.assertEqual(
                online_smoke._games_played("url", "key", "token", "user"),
                0,
            )

    def test_games_played_reads_uncapped_stats_counter(self) -> None:
        payload = [{"games_played": 7}]
        with mock.patch.object(
            online_smoke, "request_json", return_value=payload
        ) as request_json:
            self.assertEqual(
                online_smoke._games_played("url", "key", "token", "user"),
                7,
            )
        self.assertIn("/rest/v1/profile_stats?", request_json.call_args.args[0])
        self.assertIn("select=games_played", request_json.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
