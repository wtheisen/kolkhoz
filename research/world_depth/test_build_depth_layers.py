from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

import numpy as np
from PIL import Image

from research.world_depth.apply_depth_infills import apply_infills
from research.world_depth.build_depth_layers import build


class BuildDepthLayersTests(unittest.TestCase):
    def test_emits_distinct_registered_rgba_cutouts(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = np.zeros((8, 12, 3), dtype=np.uint8)
            source[..., 0] = 180
            depth = np.tile(np.linspace(0, 1, 12, dtype=np.float32), (8, 1))
            Image.fromarray(source, mode="RGB").save(root / "source.png")
            np.save(root / "depth.npy", depth, allow_pickle=False)

            build(root / "source.png", root / "depth.npy", root / "out", 4, "equal-range", 0, 1)

            cutouts = sorted((root / "out" / "cutouts").glob("*.png"))
            self.assertEqual(len(cutouts), 4)
            alphas = [np.asarray(Image.open(path).convert("RGBA"))[..., 3] for path in cutouts]
            self.assertTrue(all(alpha.shape == (8, 12) for alpha in alphas))
            self.assertTrue(all(np.any(alpha) for alpha in alphas))
            self.assertTrue(np.all(np.sum(np.stack(alphas) > 0, axis=0) == 1))

    def test_infills_hide_behind_nearer_bands_and_reconstruct_source(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = np.zeros((8, 12, 3), dtype=np.uint8)
            source[..., 0] = np.arange(12, dtype=np.uint8) * 10
            depth = np.tile(np.linspace(0, 1, 12, dtype=np.float32), (8, 1))
            Image.fromarray(source, mode="RGB").save(root / "source.png")
            np.save(root / "depth.npy", depth, allow_pickle=False)
            build(root / "source.png", root / "depth.npy", root / "layers", 4, "equal-range", 0, 2)

            generated = root / "generated"
            generated.mkdir()
            for target in (root / "layers" / "infill-targets").glob("*.png"):
                Image.new("RGB", (12, 8), (255, 0, 255)).save(generated / target.name)
            outputs = apply_infills(root / "layers", generated, root / "infilled")

            composite = np.zeros((8, 12, 4), dtype=np.uint8)
            for output in outputs:
                layer = np.asarray(Image.open(output).convert("RGBA"))
                visible = layer[..., 3] > 0
                composite[visible] = layer[visible]
            self.assertTrue(np.array_equal(composite[..., :3], source))
            self.assertTrue(np.all(composite[..., 3] == 255))


if __name__ == "__main__":
    unittest.main()
