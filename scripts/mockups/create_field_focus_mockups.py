from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Resources"
OUT = ROOT / "ios/KolkhozSwiftUI/Mockups"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(RES / "Fonts/Handjet.ttf"), size=size)


F_TAG = font(12)


def load(path: Path, size: tuple[int, int] | None = None) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if size:
        image = image.resize(size, Image.Resampling.NEAREST)
    return image


def icon(name: str, size: int) -> Image.Image:
    return load(RES / "Icons" / f"icon-{name}.png", (size, size))


def paste(base: Image.Image, image: Image.Image, xy: tuple[int, int], alpha: int = 255):
    image = image.copy()
    if alpha < 255:
        image.putalpha(image.getchannel("A").point(lambda p: p * alpha // 255))
    base.alpha_composite(image, xy)


def field_band(base: Image.Image, box, suit: str, label: str | None = None, alpha: int = 58):
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    l, t, r, b = box
    d.rounded_rectangle(box, radius=7, fill=(150, 108, 46, alpha), outline=(126, 84, 34, 130), width=1)

    height = max(1, b - t)
    for n in range(9):
        y = t + 7 + n * max(5, height // 10)
        d.line((l + 7, y, r - 8, y + 5), fill=(103, 74, 31, 120), width=1)
        d.line((l + 10, y + 2, r - 10, y + 7), fill=(226, 187, 101, 46), width=1)

    for n in range(4):
        x = l + 18 + n * max(18, (r - l - 44) // 4)
        d.line((x, t + 9, x + 9, b - 8), fill=(80, 62, 33, 62), width=1)

    base.alpha_composite(overlay)
    paste(base, icon(suit, min(54, max(28, (b - t) - 10))), (r - min(64, b - t + 8), t + 5), 76)
    if label:
        tag = Image.new("RGBA", base.size, (0, 0, 0, 0))
        td = ImageDraw.Draw(tag)
        td.rounded_rectangle((l + 7, t + 6, l + 55, t + 21), radius=3, fill=(110, 70, 28, 210), outline=(92, 56, 22, 255), width=1)
        td.text((l + 31, t + 13), label, fill=(245, 224, 185, 255), font=F_TAG, anchor="mm")
        base.alpha_composite(tag)


def assignment_field_focus():
    base = Image.open(OUT / "actual-assignment-base.jpg").convert("RGBA")
    # Real job columns; make the crop backgrounds feel more like part of the existing tile surface.
    for box in [
        (251, 95, 361, 198, "sunflower"),
        (363, 95, 473, 198, "potato"),
        (474, 95, 584, 198, "beet"),
    ]:
        l, t, r, b, suit = box
        field_band(base, (l + 3, t + 47, r - 3, b - 8), suit, "FIELD", 50)
    base.convert("RGB").save(OUT / "field-focus-assignment.jpg", quality=95)


def swap_field_focus():
    base = Image.open(OUT / "actual-swap-base.jpg").convert("RGBA")
    # The plot view benefits most from field art behind visible-card lanes.
    field_band(base, (371, 150, 704, 249), "wheat", "FIELD", 50)
    field_band(base, (112, 150, 338, 249), "potato", "CELLAR", 34)
    base.convert("RGB").save(OUT / "field-focus-swap.jpg", quality=95)


def north_field_focus():
    base = Image.open(OUT / "actual-north-base.jpg").convert("RGBA")
    # A harvested-field ghost keeps the north history connected to plot cards, instead of pure frost.
    for l, t, r, b, suit in [
        (151, 88, 249, 322, "beet"),
        (257, 88, 355, 322, "sunflower"),
        (363, 88, 461, 322, "potato"),
        (469, 88, 566, 322, "wheat"),
        (574, 88, 672, 322, "beet"),
    ]:
        field_band(base, (l + 8, t + 70, r - 8, t + 144), suit, None, 28)
    base.convert("RGB").save(OUT / "field-focus-north.jpg", quality=95)


def requisition_field_focus():
    base = Image.open(OUT / "actual-requisition-base.jpg").convert("RGBA")
    # Use failed-job field color as a quiet backing, then keep the existing red requisition UI.
    for l, t, r, b, suit in [
        (113, 92, 173, 318, "beet"),
        (179, 92, 272, 318, "beet"),
        (279, 92, 371, 318, "sunflower"),
        (376, 92, 452, 318, "potato"),
    ]:
        field_band(base, (l + 6, t + 70, r - 6, t + 142), suit, None, 30)
    base.convert("RGB").save(OUT / "field-focus-requisition.jpg", quality=95)


def main():
    assignment_field_focus()
    swap_field_focus()
    requisition_field_focus()
    north_field_focus()
    for name in [
        "field-focus-assignment.jpg",
        "field-focus-swap.jpg",
        "field-focus-requisition.jpg",
        "field-focus-north.jpg",
    ]:
        print(OUT / name)


if __name__ == "__main__":
    main()
