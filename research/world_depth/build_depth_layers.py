#!/usr/bin/env python3
"""Build registered plate cutouts and inpaint requests from estimated depth."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def quantize(depth: np.ndarray, bands: int, method: str) -> tuple[np.ndarray, list[float]]:
    if method == "quantile":
        edges = np.quantile(depth, np.linspace(0.0, 1.0, bands + 1))
    else:
        edges = np.linspace(float(depth.min()), float(depth.max()), bands + 1)
    edges = np.asarray(edges, dtype=np.float32)
    edges[0] = -np.inf
    edges[-1] = np.inf
    labels = np.digitize(depth, edges[1:-1], right=False).astype(np.uint8)
    return labels, [float(value) for value in edges[1:-1]]


def rgba_cutout(source: np.ndarray, mask: np.ndarray) -> np.ndarray:
    cutout = np.zeros((*source.shape[:2], 4), dtype=np.uint8)
    cutout[mask, :3] = source[mask, :3]
    cutout[mask, 3] = 255
    return cutout


def build(
    source_path: Path,
    depth_path: Path,
    output: Path,
    bands: int,
    method: str,
    smooth_radius: float,
    support_pixels: int,
) -> None:
    source = np.asarray(Image.open(source_path).convert("RGB"))
    depth = np.load(depth_path, allow_pickle=False).astype(np.float32)
    if depth.shape != source.shape[:2]:
        raise ValueError(f"depth {depth.shape} does not match source {source.shape[:2]}")
    if smooth_radius > 0:
        depth = ndimage.gaussian_filter(depth, sigma=smooth_radius)

    labels, edges = quantize(depth, bands, method)
    masks_dir = output / "masks"
    cutouts_dir = output / "cutouts"
    targets_dir = output / "infill-targets"
    holes_dir = output / "infill-masks"
    for directory in (masks_dir, cutouts_dir, targets_dir, holes_dir):
        directory.mkdir(parents=True, exist_ok=True)

    plate_records = []
    structure = ndimage.generate_binary_structure(2, 1)
    for band in range(bands):
        name = f"band-{band:02d}-{'far' if band == 0 else 'near' if band == bands - 1 else 'mid'}"
        mask = labels == band
        Image.fromarray(mask.astype(np.uint8) * 255, mode="L").save(masks_dir / f"{name}.png")
        Image.fromarray(rgba_cutout(source, mask), mode="RGBA").save(cutouts_dir / f"{name}.png")

        support = ndimage.binary_dilation(mask, structure=structure, iterations=support_pixels)
        # Plates composite far-to-near. Extend a plate only beneath pixels owned
        # by a nearer band, so generated support is fully occluded in the
        # calibrated reference frame and appears only when parallax opens a gap.
        hole = support & (labels > band)
        target = source.copy()
        target[hole] = (255, 0, 255)
        Image.fromarray(target, mode="RGB").save(targets_dir / f"{name}.png")
        Image.fromarray(hole.astype(np.uint8) * 255, mode="L").save(holes_dir / f"{name}.png")
        ys, xs = np.where(mask)
        plate_records.append(
            {
                "id": name,
                "depthBand": band,
                "pixelCount": int(mask.sum()),
                "bounds": [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)],
                "mask": f"masks/{name}.png",
                "cutout": f"cutouts/{name}.png",
                "infillTarget": f"infill-targets/{name}.png",
                "infillMask": f"infill-masks/{name}.png",
            }
        )

    Image.fromarray(labels, mode="L").save(output / "labels.png")
    (output / "manifest.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "source": str(source_path),
                "normalizedDepth": str(depth_path),
                "depthConvention": "0=far, 1=near",
                "bandCount": bands,
                "quantization": method,
                "smoothingSigma": smooth_radius,
                "infillSupportPixels": support_pixels,
                "edges": edges,
                "plates": plate_records,
            },
            indent=2,
        )
        + "\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--depth", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bands", type=int, default=8)
    parser.add_argument("--method", choices=("equal-range", "quantile"), default="equal-range")
    parser.add_argument("--smooth-radius", type=float, default=1.25)
    parser.add_argument("--support-pixels", type=int, default=48)
    args = parser.parse_args()
    build(
        source_path=args.source,
        depth_path=args.depth,
        output=args.output,
        bands=args.bands,
        method=args.method,
        smooth_radius=args.smooth_radius,
        support_pixels=args.support_pixels,
    )


if __name__ == "__main__":
    main()
