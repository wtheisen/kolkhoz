import unittest

import numpy as np

from research.world_depth.five_plate import (
    CAMERA,
    PLATE_IDS,
    _landmark_free_snow,
    composite_rgba,
    manual_depth_bands,
    nearest_visible_fill,
    project_scale,
)


class ManualBandsTest(unittest.TestCase):
    def test_manual_threshold_endpoints(self):
        values = np.array([[0.0, 0.059, 0.06, 0.179, 0.18, 0.439, 0.44, 0.699, 0.70, 1.0]])
        np.testing.assert_array_equal(manual_depth_bands(values), [[0, 0, 1, 1, 2, 2, 3, 3, 4, 4]])

    def test_rejects_out_of_range_depth(self):
        with self.assertRaisesRegex(ValueError, "\[0, 1\]"):
            manual_depth_bands(np.array([[-0.01, 0.5]]))


class PlateTest(unittest.TestCase):
    def test_partition_reconstructs_source_exactly(self):
        source = np.arange(3 * 4 * 3, dtype=np.uint8).reshape(3, 4, 3)
        labels = np.array([[0, 0, 1, 1], [2, 2, 3, 3], [4, 4, 4, 4]], dtype=np.uint8)
        layers = [np.dstack((source, np.where(labels == i, 255, 0).astype(np.uint8))) for i in range(5)]
        reconstruction = composite_rgba(layers)[..., :3]
        np.testing.assert_array_equal(reconstruction, source)

    def test_nearest_fill_preserves_visible_pixels(self):
        source = np.zeros((4, 5, 3), dtype=np.uint8)
        source[1, 1] = (30, 40, 50)
        source[2, 4] = (90, 100, 110)
        visible = np.zeros((4, 5), dtype=bool)
        visible[1, 1] = True
        visible[2, 4] = True
        result = nearest_visible_fill(source, visible)
        np.testing.assert_array_equal(result[visible], source[visible])
        self.assertTrue(np.all(result.sum(axis=2) > 0))

    def test_landmark_free_snow_is_seeded_and_registered(self):
        first = _landmark_free_snow((12, 18))
        second = _landmark_free_snow((12, 18))
        np.testing.assert_array_equal(first, second)
        self.assertEqual(first.shape, (12, 18, 3))


class CameraTest(unittest.TestCase):
    def test_locked_terminal_and_scale_order(self):
        self.assertEqual(CAMERA["terminalZ"], 5.0)
        scales = [project_scale(6.6, z) for z in (-2.0, 0.0, 3.0, 5.0)]
        self.assertEqual(scales, sorted(scales))
        self.assertGreater(scales[-1], scales[0])
        self.assertEqual(len(PLATE_IDS), 5)


if __name__ == "__main__":
    unittest.main()
