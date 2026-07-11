from __future__ import annotations

import unittest

from server.tools.scale_harness import (
    CapacityScenario,
    Thresholds,
    exercise_overload,
    run_local,
)


class ScaleHarnessTests(unittest.TestCase):
    def test_capacity_scenario_is_explicitly_modeled_with_headroom(self) -> None:
        value = CapacityScenario(1_000_000, 25_000, 10_000).projection()
        self.assertEqual(value["evidence"], "modeled-not-measured")
        self.assertEqual(value["activeGames"], 250_000)
        self.assertGreater(value["gatewayInstances"], 40)
        self.assertGreater(value["gameWorkerInstances"], 25)

    def test_overload_is_bounded_and_rejected(self) -> None:
        value = exercise_overload(queue_size=4, submissions=10)
        self.assertEqual(value["maximumObservedDepth"], 4)
        self.assertEqual(value["accepted"], 4)
        self.assertEqual(value["rejected"], 6)

    def test_smoke_emits_latency_recovery_and_pass_fail_evidence(self) -> None:
        result = run_local(
            players=10_000,
            operations=12,
            concurrency=4,
            shards=2,
            thresholds=Thresholds(),
        )
        self.assertEqual(result["evidence"], "executable-local-runtime")
        self.assertEqual(result["scope"]["playersModeled"], 10_000)
        self.assertEqual(result["workerRecovery"]["revision"], 1)
        self.assertTrue(result["checks"]["overloadBounded"])
        self.assertIn("p95Ms", result["latency"]["action"])
        self.assertTrue(result["passed"])


if __name__ == "__main__":
    unittest.main()
