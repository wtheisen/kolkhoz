import unittest

import numpy as np

from research.world_depth.bakeoff import (
    normalize_depth,
    quantize_equal_range,
    quantize_quantile,
)


class NormalizationTest(unittest.TestCase):
    def test_near_high_preserves_order(self):
        depth, details = normalize_depth(np.array([[1, 2], [3, 4]], dtype=np.float32), "near-high", (0, 100))
        np.testing.assert_allclose(depth, [[0, 1 / 3], [2 / 3, 1]])
        self.assertEqual(details.signal, "raw (higher is nearer)")

    def test_metric_depth_is_inverted(self):
        depth, _ = normalize_depth(np.array([[1, 2, 4]], dtype=np.float32), "metric-depth", (0, 100))
        self.assertEqual(float(depth[0, 0]), 1.0)
        self.assertEqual(float(depth[0, 2]), 0.0)

    def test_marigold_native_convention_is_inverted(self):
        depth, _ = normalize_depth(np.array([[0.0, 0.25, 1.0]], dtype=np.float32), "marigold-depth", (0, 100))
        np.testing.assert_allclose(depth, [[1.0, 0.75, 0.0]])

    def test_rejects_non_finite_values(self):
        with self.assertRaisesRegex(ValueError, "NaN or infinity"):
            normalize_depth(np.array([[0, np.nan]], dtype=np.float32), "near-high")


class QuantizationTest(unittest.TestCase):
    def test_equal_range_assigns_endpoints(self):
        labels, edges = quantize_equal_range(np.array([[0.0, 0.2, 0.999, 1.0]]), 5)
        np.testing.assert_array_equal(labels, [[0, 1, 4, 4]])
        self.assertEqual(edges, [0.0, 0.2, 0.4, 0.6000000000000001, 0.8, 1.0])

    def test_quantile_balances_distinct_values(self):
        labels, edges = quantize_quantile(np.arange(12, dtype=np.float32).reshape(3, 4), 3)
        np.testing.assert_array_equal(np.bincount(labels.ravel()), [4, 4, 4])
        self.assertEqual(len(edges), 4)


if __name__ == "__main__":
    unittest.main()
