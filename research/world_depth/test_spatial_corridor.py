import unittest

from research.world_depth.spatial_corridor import (
    END_Z,
    HEIGHT,
    START_Z,
    WIDTH,
    camera_path,
    project_card_rect,
    project_ground,
)


class CameraPathTest(unittest.TestCase):
    def test_straight_path_changes_only_z(self):
        for z in (3.0, 3.5, 4.0, 4.5, 5.0):
            camera = camera_path("straight", z)
            self.assertEqual(camera["x"], 0)
            self.assertEqual(camera["y"], 0)
            self.assertEqual(camera["pitchDegrees"], 0)
            self.assertEqual(camera["yawDegrees"], 0)

    def test_dynamic_path_preserves_endpoints_and_bounds(self):
        for z in (START_Z, END_Z):
            camera = camera_path("dynamic", z)
            self.assertAlmostEqual(camera["x"], 0)
            self.assertAlmostEqual(camera["y"], 0)
        samples = [camera_path("dynamic", START_Z + index * 0.02) for index in range(101)]
        self.assertLessEqual(max(abs(sample["x"]) for sample in samples), 0.0220001)
        self.assertLessEqual(max(abs(sample["y"]) for sample in samples), 0.0080001)


class ProjectionTest(unittest.TestCase):
    def test_near_object_moves_outward_as_camera_approaches(self):
        world_x, world_z = 0.8, 5.4
        start = project_ground(world_x, world_z, camera_path("straight", 3.0))
        later = project_ground(world_x, world_z, camera_path("straight", 4.0))
        self.assertIsNotNone(start)
        self.assertIsNotNone(later)
        self.assertGreater(abs(later[0] - WIDTH * 0.5), abs(start[0] - WIDTH * 0.5))
        self.assertGreater(later[1], start[1])

    def test_passed_object_is_not_projected(self):
        self.assertIsNone(project_ground(0.5, 4.5, camera_path("straight", 5.0)))

    def test_card_anchor_scales_from_world_position(self):
        card = {"x": 0.5, "z": 5.5, "width": 0.3, "height": 0.6, "anchor": [0.5, 1.0]}
        start = project_card_rect(card, camera_path("straight", 3.0))
        later = project_card_rect(card, camera_path("straight", 4.0))
        self.assertGreater(later[2], start[2])
        self.assertGreater(later[3], start[3])
        self.assertLess(start[0], WIDTH)
        self.assertLess(start[1], HEIGHT)


if __name__ == "__main__":
    unittest.main()
