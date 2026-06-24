from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Resources"
OUT = ROOT / "ios/KolkhozSwiftUI/Mockups"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(RES / "Fonts/Handjet.ttf"), size=size)


F_SMALL = font(15)
F_TAG = font(13)


def load(path: Path, size: tuple[int, int] | None = None) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if size:
        image = image.resize(size, Image.Resampling.NEAREST)
    return image


def icon(name: str, size: int) -> Image.Image:
    return load(RES / "Icons" / f"icon-{name}.png", (size, size))


def art(name: str, size: tuple[int, int]) -> Image.Image:
    return load(RES / "Embellishments" / name, size)


def paste(base: Image.Image, image: Image.Image, xy: tuple[int, int], alpha: int = 255):
    image = image.copy()
    if alpha < 255:
        image.putalpha(image.getchannel("A").point(lambda p: p * alpha // 255))
    base.alpha_composite(image, xy)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def label(draw: ImageDraw.ImageDraw, box, text: str):
    rounded(draw, box, 3, (120, 72, 30, 210), (90, 58, 22, 255), 1)
    draw.text(((box[0] + box[2]) // 2, (box[1] + box[3]) // 2 - 1), text, fill=(245, 224, 185), font=F_TAG, anchor="mm")


def soft_panel(base: Image.Image, box, tint=(180, 120, 40), alpha=44):
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    rounded(d, box, 6, tint + (alpha,), tint + (150,), 1)
    base.alpha_composite(overlay)


def crop_lines(draw: ImageDraw.ImageDraw, box, color=(135, 95, 38, 130)):
    l, t, r, b = box
    for n in range(7):
        y = t + 8 + n * max(6, (b - t - 16) // 6)
        draw.line((l + 4, y, r - 4, y + 5), fill=color, width=1)


def make_assignment():
    base = Image.open(OUT / "actual-assignment-base.jpg").convert("RGBA")
    d = ImageDraw.Draw(base)
    # Four current job tiles in the real assignment screen.
    tile_boxes = [
        (260, 92, 362, 197, "sunflower"),
        (370, 92, 473, 197, "potato"),
        (480, 92, 584, 197, "beet"),
    ]
    for box in tile_boxes:
        l, t, r, b, suit = box
        art_box = (l + 8, t + 52, r - 9, b - 8)
        soft_panel(base, art_box, (156, 112, 42), 36)
        crop_lines(d, art_box)
        paste(base, icon(suit, 28), (r - 42, b - 44), 72)
        label(d, (l + 12, t + 58, l + 48, t + 73), "ART")
    paste(base, art("panel-divider-pixel.png", (86, 18)), (586, 76), 120)
    base.convert("RGB").save(OUT / "actual-assignment-art-mockup.jpg", quality=95)


def make_swap():
    base = Image.open(OUT / "actual-swap-base.jpg").convert("RGBA")
    d = ImageDraw.Draw(base)
    # Current cellar and plot bands.
    for box, name, icon_name in [
        ((112, 152, 338, 248), "CELLAR BACK", "cellar"),
        ((370, 152, 702, 248), "FIELD BACK", "plot"),
    ]:
        soft_panel(base, box, (148, 108, 48), 34)
        crop_lines(d, (box[0] + 12, box[1] + 14, box[2] - 12, box[1] + 54), (130, 90, 36, 105))
        paste(base, icon(icon_name, 34), (box[2] - 46, box[1] + 10), 72)
        paste(base, art("plot-empty-pixel.png", (70, 50)), (box[0] + 18, box[1] + 26), 86)
        label(d, (box[0] + 14, box[1] + 10, box[0] + 76, box[1] + 25), name)
    base.convert("RGB").save(OUT / "actual-swap-art-mockup.jpg", quality=95)


def make_requisition():
    base = Image.open(OUT / "actual-requisition-base.jpg").convert("RGBA")
    d = ImageDraw.Draw(base)
    # Add current-style requisition art around plot cards and the summary panel without changing layout.
    for x in [121, 231, 340, 450]:
        soft_panel(base, (x - 6, 106, x + 44, 151), (185, 30, 48), 54)
        paste(base, icon("warning", 18), (x + 19, 112), 150)
    soft_panel(base, (456, 86, 728, 128), (185, 30, 48), 38)
    paste(base, art("badge-seal-pixel.png", (46, 44)), (678, 88), 78)
    paste(base, art("panel-divider-pixel.png", (118, 24)), (482, 99), 80)
    label(d, (610, 100, 674, 116), "NOTICE ART")
    base.convert("RGB").save(OUT / "actual-requisition-art-mockup.jpg", quality=95)


def make_north():
    base = Image.open(OUT / "actual-north-base.jpg").convert("RGBA")
    d = ImageDraw.Draw(base)
    # Five year columns in the actual north history screen.
    columns = [(151, 87, 249, 320), (257, 87, 355, 320), (363, 87, 461, 320), (469, 87, 566, 320), (574, 87, 672, 320)]
    for i, box in enumerate(columns):
        l, t, r, b = box
        soft_panel(base, (l + 7, t + 70, r - 7, t + 142), (118, 138, 138), 30)
        for n in range(3):
            x = l + 16 + n * 28
            d.line((x, t + 76, x + 12, t + 132), fill=(120, 145, 145, 72), width=1)
        paste(base, icon("north", 32), (r - 48, t + 86), 78)
        if i > 0:
            paste(base, art("badge-seal-pixel.png", (42, 40)), (l + 31, t + 84), 65)
        label(d, (l + 12, t + 74, l + 67, t + 89), "FROST ART")
    base.convert("RGB").save(OUT / "actual-north-art-mockup.jpg", quality=95)


def main():
    make_assignment()
    make_swap()
    make_requisition()
    make_north()
    for name in [
        "actual-assignment-art-mockup.jpg",
        "actual-swap-art-mockup.jpg",
        "actual-requisition-art-mockup.jpg",
        "actual-north-art-mockup.jpg",
    ]:
        print(OUT / name)


if __name__ == "__main__":
    main()
