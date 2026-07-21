#!/usr/bin/env python3

"""Composite exact production pip layouts into the Steam capsule draft."""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "design/steam/drafts/header-capsule-composition-v1.png"
WHEAT = ROOT / "app/assets/art/field_plan/cards/suits/suit-wheat.png"
SUNFLOWER = ROOT / "app/assets/art/field_plan/cards/suits/suit-sunflower.png"
MASTER_OUTPUT = ROOT / "design/steam/drafts/header-capsule-precise-cards-v3.png"
CAPSULE_OUTPUT = ROOT / "design/steam/exports/header-capsule-920x430-v3.png"
FONT = ROOT / "app/assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf"

# Clockwise from top-left, measured against the 1802 x 873 composition draft.
CARD_QUADS = (
    (WHEAT, 10, ((660, 492), (887, 451), (1034, 779), (775, 815))),
    (SUNFLOWER, 9, ((939, 402), (1168, 391), (1288, 698), (1028, 735))),
)

PATCH_SIZE = (600, 900)
PIP_POSITIONS = {
    9: (
        (0.25, 0.13),
        (0.75, 0.13),
        (0.25, 0.37),
        (0.75, 0.37),
        (0.50, 0.50),
        (0.25, 0.63),
        (0.75, 0.63),
        (0.25, 0.87),
        (0.75, 0.87),
    ),
    10: (
        (0.25, 0.11),
        (0.75, 0.11),
        (0.50, 0.27),
        (0.25, 0.39),
        (0.75, 0.39),
        (0.25, 0.61),
        (0.75, 0.61),
        (0.50, 0.73),
        (0.25, 0.89),
        (0.75, 0.89),
    ),
}


def card_face(suit_path: Path, value: int) -> np.ndarray:
    width, height = PATCH_SIZE
    patch = Image.new("RGBA", PATCH_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch)
    corner = 34
    outline = (31, 42, 42, 255)
    red = (198, 48, 30, 255)
    cream = (244, 226, 184, 255)
    outer = (
        (corner, 0),
        (width - corner, 0),
        (width, corner),
        (width, height - corner),
        (width - corner, height),
        (corner, height),
        (0, height - corner),
        (0, corner),
    )
    draw.polygon(outer, fill=cream)
    draw.line((*outer, outer[0]), fill=outline, width=12, joint="curve")
    inset = 25
    inner = (
        (corner + inset, inset),
        (width - corner - inset, inset),
        (width - inset, corner + inset),
        (width - inset, height - corner - inset),
        (width - corner - inset, height - inset),
        (corner + inset, height - inset),
        (inset, height - corner - inset),
        (inset, corner + inset),
    )
    draw.line((*inner, inner[0]), fill=red, width=5, joint="curve")

    suit = Image.open(suit_path).convert("RGBA")
    bounds = suit.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"Suit asset has no visible pixels: {suit_path}")
    suit = suit.crop(bounds)
    pip_size = (62, 90) if value == 10 else (78, 78)
    suit.thumbnail(pip_size, Image.Resampling.LANCZOS)

    rank_color = red if value == 10 else outline
    font = ImageFont.truetype(str(FONT), 88)
    rank = str(value)
    draw.text((48, 34), rank, font=font, fill=rank_color, anchor="la")
    index_suit = suit.copy()
    index_suit.thumbnail((44, 54), Image.Resampling.LANCZOS)
    patch.alpha_composite(index_suit, (58, 119))

    bottom_index = Image.new("RGBA", (150, 190), (0, 0, 0, 0))
    bottom_draw = ImageDraw.Draw(bottom_index)
    bottom_draw.text((18, 4), rank, font=font, fill=rank_color, anchor="la")
    bottom_index.alpha_composite(index_suit, (28, 90))
    bottom_index = bottom_index.rotate(180, expand=False)
    patch.alpha_composite(bottom_index, (width - 174, height - 200))

    field_left, field_top, field_width, field_height = (118, 142, 364, 616)
    for x, y in PIP_POSITIONS[value]:
        pip = suit if y <= 0.5 else suit.rotate(180, expand=True)
        left = round(field_left + field_width * x - pip.width / 2)
        top = round(field_top + field_height * y - pip.height / 2)
        patch.alpha_composite(pip, (left, top))

    return cv2.cvtColor(np.array(patch), cv2.COLOR_RGBA2BGRA)


def composite_card(
    canvas: np.ndarray,
    suit_path: Path,
    value: int,
    destination: tuple[tuple[int, int], ...],
) -> np.ndarray:
    card = card_face(suit_path, value)

    height, width = card.shape[:2]
    source = np.float32(
        ((0, 0), (width - 1, 0), (width - 1, height - 1), (0, height - 1))
    )
    target = np.float32(destination)
    transform = cv2.getPerspectiveTransform(source, target)
    warped = cv2.warpPerspective(
        card,
        transform,
        (canvas.shape[1], canvas.shape[0]),
        flags=cv2.INTER_LANCZOS4,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )

    alpha = warped[:, :, 3:4].astype(np.float32) / 255.0
    foreground = warped[:, :, :3].astype(np.float32)
    background = canvas.astype(np.float32)
    return np.clip(foreground * alpha + background * (1.0 - alpha), 0, 255).astype(
        np.uint8
    )


def main() -> None:
    canvas = cv2.imread(str(SOURCE), cv2.IMREAD_COLOR)
    if canvas is None:
        raise RuntimeError(f"Could not read capsule draft: {SOURCE}")

    for suit_path, value, destination in CARD_QUADS:
        canvas = composite_card(canvas, suit_path, value, destination)

    MASTER_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(MASTER_OUTPUT), canvas)

    rgb = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB)
    image = Image.fromarray(rgb)
    target_ratio = 920 / 430
    crop_height = round(image.width / target_ratio)
    crop_top = (image.height - crop_height) // 2
    image = image.crop((0, crop_top, image.width, crop_top + crop_height))
    image = image.resize((920, 430), Image.Resampling.LANCZOS)
    CAPSULE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(CAPSULE_OUTPUT, optimize=True)

    print(MASTER_OUTPUT.relative_to(ROOT))
    print(CAPSULE_OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
