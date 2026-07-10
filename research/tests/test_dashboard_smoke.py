from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from research.kolkhoz_research import dashboard


class DashboardSmokeTests(unittest.TestCase):
    def test_online_smoke_runs_ignores_invalid_records(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "online_smoke.jsonl"
            path.write_text(
                '{"status":"passed","sessionID":"first"}\ninvalid\n'
                '{"status":"failed","error":"boom"}\n',
                encoding="utf-8",
            )
            with mock.patch.object(dashboard, "ONLINE_SMOKE_LOG", path):
                runs = dashboard._online_smoke_runs()

        self.assertEqual([run["status"] for run in runs], ["failed", "passed"])

    def test_start_online_smoke_prevents_overlapping_runs(self) -> None:
        running = mock.Mock()
        running.poll.return_value = None
        with dashboard._online_smoke_lock:
            previous = dashboard._online_smoke_process
            dashboard._online_smoke_process = running
        try:
            with mock.patch.object(dashboard.subprocess, "Popen") as popen:
                self.assertFalse(dashboard._start_online_smoke())
                popen.assert_not_called()
        finally:
            with dashboard._online_smoke_lock:
                dashboard._online_smoke_process = previous


if __name__ == "__main__":
    unittest.main()
