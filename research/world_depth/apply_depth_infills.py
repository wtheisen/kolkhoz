#!/usr/bin/env python3
"""Merge generated hidden coverage into depth cutouts without changing visible pixels."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def apply_infills(layer_dir: Path, generated_dir: Path, output_dir: Path) -> list[Path]:
    manifest = json.loads((layer_dir / "manifest.json").read_text())
    source = np.asarray(Image.open(manifest["source"]).convert("RGB"))
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    for plate in manifest["plates"]:
        generated_path = generated_dir / f'{plate["id"]}.png'
        if not generated_path.exists():
            raise FileNotFoundError(f"missing generated infill: {generated_path}")
        generated = np.asarray(Image.open(generated_path).convert("RGB").resize(
            (source.shape[1], source.shape[0]), Image.Resampling.LANCZOS
        ))
        visible = np.asarray(Image.open(layer_dir / plate["mask"]).convert("L")) > 0
        infill = np.asarray(Image.open(layer_dir / plate["infillMask"]).convert("L")) > 0
        final = np.zeros((*source.shape[:2], 4), dtype=np.uint8)
        final[infill, :3] = generated[infill]
        final[visible, :3] = source[visible]
        final[visible | infill, 3] = 255
        output_path = output_dir / f'{plate["id"]}.png'
        Image.fromarray(final, mode="RGBA").save(output_path)
        outputs.append(output_path)
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--layers", type=Path, required=True)
    parser.add_argument("--generated", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    for path in apply_infills(args.layers, args.generated, args.output):
        print(path)


if __name__ == "__main__":
    main()
