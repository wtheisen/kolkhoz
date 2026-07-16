import unittest

from research.world_depth.looming_threat import (
    END_Z,
    HEIGHT,
    OBJECTS,
    SELECTED_VIEWPOINT,
    START_Z,
    VIEWPOINTS,
    YEAR_STATES,
    north_polygon,
    object_rect,
    project_ground,
    threat_state,
)


class ThreatTransformTest(unittest.TestCase):
    def test_year_lookup_endpoints_are_exact(self):
        self.assertEqual(threat_state(0), YEAR_STATES[1])
        self.assertEqual(threat_state(1), YEAR_STATES[5])

    def test_threat_grows_upward_from_fixed_base(self):
        for viewpoint, vp_y in VIEWPOINTS.items():
            bases = []
            tops = []
            for level in (0, .25, .5, .75, 1):
                polygon = north_polygon(vp_y, threat_state(level))
                bases.append(max(point[1] for point in polygon))
                tops.append(min(point[1] for point in polygon))
            self.assertEqual(len(set(bases)), 1, viewpoint)
            self.assertTrue(all(tops[index] > tops[index + 1] for index in range(4)))


class PhysicalProjectionTest(unittest.TestCase):
    def test_horizon_is_stable_during_straight_dolly(self):
        vp_y = VIEWPOINTS[SELECTED_VIEWPOINT]
        far_start = project_ground(0, 1_000_000, START_Z, vp_y)
        far_end = project_ground(0, 1_000_000, END_Z, vp_y)
        self.assertAlmostEqual(far_start[1], far_end[1], places=3)
        self.assertAlmostEqual(far_start[1], HEIGHT * vp_y, places=2)

    def test_foreground_object_passes_camera(self):
        obj = next(item for item in OBJECTS if item["id"] == "tree-near-left")
        self.assertIsNotNone(object_rect(obj, START_Z, VIEWPOINTS[SELECTED_VIEWPOINT]))
        self.assertIsNone(object_rect(obj, END_Z, VIEWPOINTS[SELECTED_VIEWPOINT]))

    def test_viewpoint_only_changes_vertical_projection(self):
        points = [project_ground(.8, 8, 3, vp_y) for vp_y in VIEWPOINTS.values()]
        self.assertEqual(len({round(point[0], 6) for point in points}), 1)
        self.assertEqual(len({round(point[2], 6) for point in points}), 1)
        self.assertEqual(len({round(point[1], 6) for point in points}), 3)


if __name__ == "__main__":
    unittest.main()
