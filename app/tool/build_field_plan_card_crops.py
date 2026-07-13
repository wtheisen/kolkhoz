#!/usr/bin/env python3

from pathlib import Path

from PIL import Image

from field_plan_calibration_overlay import (
    BACKGROUND,
    BOARD_RECT,
    CARD_SLOT_RECTS,
    NORMALIZED_QUADS,
    SEAT_IDS,
)


OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "assets/art/field_plan/cards/planted"
)
CARD_SIZE = (700, 980)


def source_point(point: tuple[float, float], image: Image.Image) -> tuple[float, float]:
    left, top, width, height = BOARD_RECT
    scale = max(width / image.width, height / image.height)
    offset_x = left + (width - image.width * scale) / 2
    offset_y = top + (height - image.height * scale) / 2
    return ((point[0] - offset_x) / scale, (point[1] - offset_y) / scale)


def main() -> None:
    background = Image.open(BACKGROUND).convert("RGB")
    OUTPUT.mkdir(parents=True, exist_ok=True)

    for seat_id, slot, normalized in zip(
        SEAT_IDS, CARD_SLOT_RECTS, NORMALIZED_QUADS
    ):
        rendered = [
            (slot["x"] + x * slot["width"], slot["y"] + y * slot["height"])
            for x, y in normalized
        ]
        source = [source_point(point, background) for point in rendered]
        # Pillow QUAD order is top-left, bottom-left, bottom-right, top-right.
        quad = (*source[0], *source[3], *source[2], *source[1])
        face = background.transform(
            CARD_SIZE,
            Image.Transform.QUAD,
            quad,
            Image.Resampling.BICUBIC,
        )
        face.save(OUTPUT / f"seat-{seat_id}.png", optimize=True)


if __name__ == "__main__":
    main()
