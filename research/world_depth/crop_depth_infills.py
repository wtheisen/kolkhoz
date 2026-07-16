#!/usr/bin/env python3
"""Crop registered infilled depth plates to their opaque support bounds."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def crop_plates(source_dir: Path, output_dir: Path, canvas_width: int, canvas_height: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    records = []
    for source_path in sorted(source_dir.glob("*.png")):
        image = Image.open(source_path).convert("RGBA")
        if image.size != (canvas_width, canvas_height):
            raise ValueError(f"{source_path} is {image.size}, expected {(canvas_width, canvas_height)}")
        bounds = image.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"{source_path} has no opaque pixels")
        output_path = output_dir / source_path.name
        image.crop(bounds).save(output_path)
        left, top, right, bottom = bounds
        records.append(
            {
                "id": source_path.stem,
                "path": output_path.name,
                "pixelBounds": [left, top, right, bottom],
                "initialRect": [
                    left / canvas_width,
                    top / canvas_height,
                    (right - left) / canvas_width,
                    (bottom - top) / canvas_height,
                ],
            }
        )
    (output_dir / "manifest.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "canvas": [canvas_width, canvas_height],
                "plates": records,
            },
            indent=2,
        )
        + "\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--width", type=int, default=1672)
    parser.add_argument("--height", type=int, default=941)
    args = parser.parse_args()
    crop_plates(args.source, args.output, args.width, args.height)


if __name__ == "__main__":
    main()
