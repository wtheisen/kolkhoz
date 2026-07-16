#!/usr/bin/env python3

"""Bake the calibrated field parcels and generated paper frame into card faces."""

from pathlib import Path

from PIL import Image, ImageFilter

from field_plan_calibration_overlay import BACKGROUND, BOARD_RECT, CARD_QUADS, SEAT_IDS


ROOT = Path(__file__).resolve().parents[1]
FRAME_SOURCE = ROOT / "tmp/imagegen/planted-frame-keyed.png"
FRAME_ASSET = (
    ROOT / "assets/art/field_plan/cards/planted/frame-paper-overlay.png"
)
OUTPUT_DIR = ROOT / "assets/art/field_plan/cards/planted"
OUTPUT_SIZE = (700, 980)
RENDER_SCALE = 2


def source_point(point: tuple[float, float], background_size: tuple[int, int]):
    left, top, width, height = BOARD_RECT
    source_width, source_height = background_size
    scale = max(width / source_width, height / source_height)
    offset_x = left + (width - source_width * scale) / 2
    offset_y = top + (height - source_height * scale) / 2
    return ((point[0] - offset_x) / scale, (point[1] - offset_y) / scale)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    frame = Image.open(FRAME_SOURCE).convert("RGBA")
    alpha_bounds = frame.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError(f"Generated frame has no visible pixels: {FRAME_SOURCE}")
    frame = frame.crop(alpha_bounds)
    frame = frame.resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)
    # Let the field show through gradually beneath the handmade paper edge. At
    # the final warped card size this becomes a visible, soft interior fade
    # instead of a one-pixel antialiased boundary.
    original_alpha = frame.getchannel("A")
    paper_fill = Image.new("RGB", frame.size, (244, 232, 195))
    paper_rgb = Image.composite(frame.convert("RGB"), paper_fill, original_alpha)
    frame = paper_rgb.convert("RGBA")
    frame.putalpha(original_alpha.filter(ImageFilter.GaussianBlur(6.0)))
    frame.save(FRAME_ASSET, optimize=True)

    background = Image.open(BACKGROUND).convert("RGB")
    render_size = tuple(value * RENDER_SCALE for value in OUTPUT_SIZE)
    render_frame = frame.resize(render_size, Image.Resampling.LANCZOS)

    for seat_id, rendered_quad in zip(SEAT_IDS, CARD_QUADS, strict=True):
        top_left, top_right, bottom_right, bottom_left = [
            source_point(point, background.size) for point in rendered_quad
        ]
        # Pillow's QUAD order is top-left, bottom-left, bottom-right, top-right.
        quad = (*top_left, *bottom_left, *bottom_right, *top_right)
        crop = background.transform(
            render_size,
            Image.Transform.QUAD,
            quad,
            resample=Image.Resampling.BICUBIC,
        ).convert("RGBA")
        crop.alpha_composite(render_frame)
        crop = crop.resize(OUTPUT_SIZE, Image.Resampling.LANCZOS).convert("RGB")
        output = OUTPUT_DIR / f"seat-{seat_id}.png"
        crop.save(output, optimize=True)
        print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
