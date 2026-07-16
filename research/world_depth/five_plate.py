#!/usr/bin/env python3
"""Build the first five semantic North plates from a completed Depth Pro run.

This is intentionally a research-only, single-composition runner.  It reuses the
preserved Apple output, creates a strict visible-pixel partition, and extends only
hidden pixels with deterministic inpainting for diagnostic camera motion.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import importlib.metadata
import json
import shutil
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

try:
    from research.world_depth.bakeoff import colorize_continuous
except ModuleNotFoundError:  # Support direct `python research/world_depth/five_plate.py` use.
    from bakeoff import colorize_continuous


SIZE = (1672, 941)
PLATE_IDS = ("N00", "N10", "N20", "N30", "N40")
PALETTE = np.asarray(
    [(43, 61, 83), (50, 102, 113), (89, 147, 108), (202, 170, 77), (193, 80, 61)],
    dtype=np.uint8,
)
MANUAL_THRESHOLDS = (0.06, 0.18, 0.44, 0.70)
SEMANTICS = (
    "sky, mountains, horizon, and foundational distant snow",
    "far treeline and upper snowfield",
    "middle snowfield and scattered trees",
    "farms, fences, roads, and lower landscape",
    "foreground crops, flowers, and railway entrance",
)
WORLD_Z = (6.60, 6.35, 6.10, 5.85, 5.60)
BLEED_RADII = (None, 96, 112, 128, 0)
FOUNDATION_SEED = 20260715
CAMERA = {
    "status": "locked",
    "viewportWidth": 1672,
    "viewportHeight": 941,
    "focalLength": 2.0,
    "vanishingPoint": [0.5, 0.40],
    "pitchDegrees": 0.0,
    "yawDegrees": 0.0,
    "startZ": -2.0,
    "terminalZ": 5.0,
    "nearPlane": 0.08,
    "minimumScale": 0.04,
    "maximumScale": 8.0,
    "plateExitDistance": 0.55,
    "stops": [
        {"id": "menu", "label": "MENU", "z": -2.0},
        {"id": "brigade", "label": "BRIGADE", "z": 0.0},
        {"id": "fields", "label": "FIELDS", "z": 3.0},
        {"id": "north", "label": "NORTH", "z": 5.0},
    ],
}
CROPS = {
    "horizon": (0, 78, 1672, 154),
    "forest": (0, 115, 1672, 235),
    "isolated-trees": (120, 220, 1432, 430),
    "farms": (0, 620, 1672, 190),
    "foreground": (0, 775, 1672, 166),
    "railway": (690, 615, 500, 326),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def save_image(array: np.ndarray, path: Path, mode: str | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(array, mode=mode) if mode else Image.fromarray(array)
    image.save(path)


def manual_depth_bands(depth: np.ndarray) -> np.ndarray:
    """Return the manager-selected geographic seed ranges, far to near."""
    if depth.ndim != 2 or not np.isfinite(depth).all():
        raise ValueError("normalized depth must be a finite HxW array")
    if float(depth.min()) < 0 or float(depth.max()) > 1:
        raise ValueError("normalized depth must lie in [0, 1]")
    return np.digitize(depth, MANUAL_THRESHOLDS, right=False).astype(np.uint8)


def _curve(width: int, points: list[tuple[int, int]]) -> np.ndarray:
    points = sorted(points)
    return np.rint(
        np.interp(np.arange(width), [p[0] for p in points], [p[1] for p in points])
    ).astype(np.int32)


def geographic_base_labels(height: int, width: int) -> tuple[np.ndarray, dict[str, list[int]]]:
    """Create broad hand-authored surface ownership curves in source coordinates."""
    if (width, height) != SIZE:
        raise ValueError(f"expected {SIZE}, got {(width, height)}")
    curves = {
        "N00_N10": _curve(width, [(0, 130), (240, 129), (470, 132), (710, 129), (930, 132), (1190, 128), (1430, 132), (1671, 130)]),
        "N10_N20": _curve(width, [(0, 276), (250, 284), (510, 293), (760, 301), (930, 302), (1190, 293), (1450, 283), (1671, 276)]),
        "N20_N30": _curve(width, [(0, 657), (60, 641), (125, 648), (190, 638), (285, 652), (390, 645), (500, 657), (610, 650), (720, 666), (820, 652), (930, 669), (1040, 652), (1150, 665), (1260, 651), (1380, 665), (1490, 657), (1580, 651), (1671, 660)]),
        "N30_N40": _curve(width, [(0, 791), (260, 792), (520, 796), (760, 799), (930, 800), (1120, 798), (1380, 794), (1671, 793)]),
    }
    yy = np.arange(height)[:, None]
    labels = np.zeros((height, width), dtype=np.uint8)
    labels[yy >= curves["N00_N10"][None, :]] = 1
    labels[yy >= curves["N10_N20"][None, :]] = 2
    labels[yy >= curves["N20_N30"][None, :]] = 3
    labels[yy >= curves["N30_N40"][None, :]] = 4
    control_points = {
        key: [int(values[x]) for x in (0, 418, 836, 1254, 1671)]
        for key, values in curves.items()
    }
    return labels, control_points


def semantic_labels(source: np.ndarray) -> tuple[np.ndarray, dict]:
    """Clean broad geography while preserving connected tree/shadow objects."""
    height, width = source.shape[:2]
    labels, curve_samples = geographic_base_labels(height, width)
    base = labels.copy()
    r, g, b = (source[..., i].astype(np.int16) for i in range(3))
    darkest = np.max(source, axis=2) < 112
    blue_shadow = (r < 158) & (g > r + 5) & (b > r + 3) & (g < 168)
    yy = np.arange(height)[:, None]
    snow_objects = (darkest | blue_shadow) & (yy >= 118) & (yy < 690)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    connected = cv2.morphologyEx(snow_objects.astype(np.uint8), cv2.MORPH_CLOSE, kernel)
    count, components, stats, _ = cv2.connectedComponentsWithStats(connected, connectivity=8)
    retained = 0
    moved_pixels = 0
    owner_counts = [0] * 5
    for component in range(1, count):
        x, y, w, h, area = stats[component]
        if area < 18 or h < 4:
            continue
        region = components[y : y + h, x : x + w] == component
        dark_region = region & darkest[y : y + h, x : x + w]
        object_y, object_x = np.nonzero(dark_region if np.any(dark_region) else region)
        foot_y = y + int(np.quantile(object_y, 0.94))
        foot_x = x + int(np.median(object_x))
        owner = int(base[min(foot_y, height - 1), min(foot_x, width - 1)])
        owner = max(1, owner)  # trees in front of the horizon never belong to N00
        target = labels[y : y + h, x : x + w]
        before = target[region].copy()
        target[region] = owner
        moved_pixels += int(np.count_nonzero(before != owner))
        retained += 1
        owner_counts[owner] += 1

    # Keep the continuous fence with the farm/lower-landscape plate.  The central
    # railway corridor is explicitly excluded so it can remain split by geography.
    xx = np.arange(width)[None, :]
    center = 875 + np.clip((yy - 650) / (height - 650), 0, 1) * 35
    half_width = 14 + np.clip((yy - 650) / (height - 650), 0, 1) * 155
    railway_corridor = np.abs(xx - center) <= half_width
    fence_ink = darkest & (yy >= 776) & (yy <= 814) & ~railway_corridor
    fence_ink = cv2.dilate(fence_ink.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    labels[fence_ink] = 3

    return labels, {
        "surfaceCurveSamplesAtX": {"x": [0, 418, 836, 1254, 1671], **curve_samples},
        "connectedTreeShadowObjectsRetained": retained,
        "treeShadowObjectsByOwner": dict(zip(PLATE_IDS, owner_counts)),
        "pixelsMovedForWholeObjects": moved_pixels,
        "fencePixelsForcedToN30": int(np.count_nonzero(fence_ink)),
        "railwayTreatment": "Rail pixels remain partitioned by the N20/N30/N40 geographic surfaces; future production should use a continuous mesh or dedicated railway treatment.",
    }


def label_color(labels: np.ndarray) -> np.ndarray:
    return PALETTE[labels]


def boundaries(labels: np.ndarray) -> np.ndarray:
    edge = np.zeros(labels.shape, dtype=bool)
    edge[:, 1:] |= labels[:, 1:] != labels[:, :-1]
    edge[1:, :] |= labels[1:, :] != labels[:-1, :]
    return cv2.dilate(edge.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0


def checkerboard(height: int, width: int, cell: int = 24) -> np.ndarray:
    yy, xx = np.indices((height, width))
    light = ((xx // cell + yy // cell) % 2) == 0
    result = np.empty((height, width, 3), dtype=np.uint8)
    result[light] = (229, 224, 211)
    result[~light] = (184, 190, 184)
    return result


def composite_rgba(layers: list[np.ndarray], background: np.ndarray | None = None) -> np.ndarray:
    height, width = layers[0].shape[:2]
    canvas = (
        np.zeros((height, width, 4), dtype=np.uint8)
        if background is None
        else np.dstack((background, np.full((height, width), 255, dtype=np.uint8)))
    )
    canvas_image = Image.fromarray(canvas, mode="RGBA")
    for layer in layers:
        canvas_image = Image.alpha_composite(canvas_image, Image.fromarray(layer, mode="RGBA"))
    return np.asarray(canvas_image)


def nearest_visible_fill(source: np.ndarray, visible: np.ndarray) -> np.ndarray:
    if not np.any(visible):
        raise ValueError("cannot fill from an empty visible mask")
    binary = (~visible).astype(np.uint8)
    _, nearest = cv2.distanceTransformWithLabels(
        binary, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    lookup = np.zeros((int(nearest.max()) + 1, 3), dtype=np.uint8)
    lookup[nearest[visible]] = source[visible]
    result = lookup[nearest]
    result[visible] = source[visible]
    return result


def _landmark_free_snow(shape: tuple[int, int]) -> np.ndarray:
    """Synthesize seeded low-contrast paper texture without copying scene marks."""
    height, width = shape
    rng = np.random.default_rng(FOUNDATION_SEED)
    coarse = rng.normal(0, 1, (height, width)).astype(np.float32)
    coarse = cv2.GaussianBlur(coarse, (0, 0), 2.2)
    coarse *= 3.2 / max(float(coarse.std()), 1e-6)
    fine = rng.normal(0, 0.8, (height, width)).astype(np.float32)
    texture = np.clip(coarse + fine, -7, 7)[..., None]
    snow = np.asarray([238, 216, 169], dtype=np.float32)[None, None, :] + texture
    return np.clip(snow, 0, 255).astype(np.uint8)


def _foundation_fill(source: np.ndarray, visible: np.ndarray) -> np.ndarray:
    """Make landmark-free snow beneath all nearer North content."""
    result = _landmark_free_snow(visible.shape)
    result[visible] = source[visible]
    boundary_bleed = cv2.distanceTransform((~visible).astype(np.uint8), cv2.DIST_L2, 5) <= 18
    boundary_bleed &= ~visible
    if np.any(boundary_bleed):
        result = cv2.inpaint(result, (boundary_bleed * 255).astype(np.uint8), 4.0, cv2.INPAINT_TELEA)
    result[visible] = source[visible]
    return result


def make_plates(source: np.ndarray, labels: np.ndarray) -> tuple[list[np.ndarray], list[np.ndarray], list[dict]]:
    raw: list[np.ndarray] = []
    inpainted: list[np.ndarray] = []
    records: list[dict] = []
    for index, plate_id in enumerate(PLATE_IDS):
        visible = labels == index
        alpha = np.where(visible, 255, 0).astype(np.uint8)
        raw_rgba = np.dstack((source, alpha))
        raw.append(raw_rgba)

        if index == 0:
            hidden = ~visible
            inpaint_rgb = _foundation_fill(source, visible)
            extended_alpha = np.full(labels.shape, 255, dtype=np.uint8)
        elif index < 4:
            distance = cv2.distanceTransform((~visible).astype(np.uint8), cv2.DIST_L2, 5)
            hidden = (distance <= int(BLEED_RADII[index])) & (labels > index)
            extended_alpha = np.where(visible | hidden, 255, 0).astype(np.uint8)
            if index in (1, 2):
                # Both hidden interfaces continue an open snow surface. Copying
                # boundary pixels here duplicates trees and field colors in motion.
                inpaint_rgb = _landmark_free_snow(visible.shape)
            else:
                nearest = nearest_visible_fill(source, visible)
                inpaint_rgb = cv2.inpaint(nearest, (hidden * 255).astype(np.uint8), 4.0, cv2.INPAINT_TELEA)
            inpaint_rgb[visible] = source[visible]
        else:
            hidden = np.zeros(labels.shape, dtype=bool)
            inpaint_rgb = source.copy()
            extended_alpha = alpha
        inpaint_rgba = np.dstack((inpaint_rgb, extended_alpha))
        inpaint_rgba[extended_alpha == 0, :3] = 0
        inpainted.append(inpaint_rgba)
        records.append(
            {
                "id": plate_id,
                "orderFarToNear": index,
                "worldZ": WORLD_Z[index],
                "owns": SEMANTICS[index],
                "visiblePixelCount": int(np.count_nonzero(visible)),
                "visiblePixelFraction": float(np.mean(visible)),
                "bleedRadiusPx": BLEED_RADII[index],
                "hiddenInpaintedPixelCount": int(np.count_nonzero(hidden)),
            }
        )
    return raw, inpainted, records


def project_scale(world_z: float, camera_z: float) -> float:
    distance = world_z - camera_z
    denominator = max(CAMERA["nearPlane"], CAMERA["focalLength"] + distance)
    scale = (CAMERA["focalLength"] + world_z) / denominator
    return float(np.clip(scale, CAMERA["minimumScale"], CAMERA["maximumScale"]))


def project_layer(layer: np.ndarray, world_z: float, camera_z: float) -> np.ndarray:
    height, width = layer.shape[:2]
    scale = project_scale(world_z, camera_z)
    inverse = 1.0 / scale
    cx = CAMERA["vanishingPoint"][0] * width
    cy = CAMERA["vanishingPoint"][1] * height
    transform = (inverse, 0, cx - cx * inverse, 0, inverse, cy - cy * inverse)
    warped = Image.fromarray(layer, mode="RGBA").transform(
        (width, height), Image.Transform.AFFINE, transform, Image.Resampling.BILINEAR
    )
    return np.asarray(warped)


def dolly_frame(layers: list[np.ndarray], camera_z: float, annotate: bool = True) -> np.ndarray:
    height, width = layers[0].shape[:2]
    background = np.full((height, width, 3), (18, 27, 29), dtype=np.uint8)
    projected = [project_layer(layer, z, camera_z) for layer, z in zip(layers, WORLD_Z)]
    frame = composite_rgba(projected, background)[..., :3].copy()
    if annotate:
        image = Image.fromarray(frame)
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 510, 38), fill=(18, 27, 29))
        scales = " / ".join(f"{project_scale(z, camera_z):.2f}" for z in WORLD_Z)
        draw.text((12, 8), f"LOCKED CAMERA  Z {camera_z:.2f}   plate scales {scales}", fill=(244, 226, 183), font=ImageFont.load_default())
        vx, vy = int(width * 0.5), int(height * 0.40)
        draw.line((vx - 8, vy, vx + 8, vy), fill=(230, 78, 61), width=2)
        draw.line((vx, vy - 8, vx, vy + 8), fill=(230, 78, 61), width=2)
        frame = np.asarray(image)
    return frame


def comparison_canvas(items: list[tuple[np.ndarray, str]]) -> np.ndarray:
    width, height = SIZE
    canvas = Image.new("RGB", SIZE, (15, 25, 27))
    draw = ImageDraw.Draw(canvas)
    columns = 3 if len(items) > 2 else len(items)
    rows = (len(items) + columns - 1) // columns
    gap = 12
    header = 30
    cell_w = (width - gap * (columns + 1)) // columns
    cell_h = (height - gap * (rows + 1)) // rows
    for index, (array, title) in enumerate(items):
        col, row = index % columns, index // columns
        x = gap + col * (cell_w + gap)
        y = gap + row * (cell_h + gap)
        source = Image.fromarray(array).convert("RGB")
        body_h = cell_h - header
        ratio = min(cell_w / source.width, body_h / source.height)
        resized = source.resize((max(1, round(source.width * ratio)), max(1, round(source.height * ratio))), Image.Resampling.LANCZOS)
        px = x + (cell_w - resized.width) // 2
        py = y + header + (body_h - resized.height) // 2
        draw.rectangle((x, y, x + cell_w, y + cell_h), fill=(29, 43, 45))
        canvas.paste(resized, (px, py))
        draw.text((x + 8, y + 8), title, fill=(244, 226, 183), font=ImageFont.load_default())
    return np.asarray(canvas)


def crop_review(source: np.ndarray, overlay: np.ndarray, owning_plate: np.ndarray, rect: tuple[int, int, int, int]) -> np.ndarray:
    x, y, w, h = rect
    slices = [image[y : y + h, x : x + w] for image in (source, overlay, owning_plate)]
    return comparison_canvas(list(zip(slices, ("source", "cleaned semantic boundary", "owning plate + hidden coverage"))))


def _artifact(path: Path, root: Path) -> dict:
    with Image.open(path) as image:
        return {"path": str(path.relative_to(root)), "sha256": sha256(path), "size": list(image.size), "mode": image.mode}


def validate_run(root: Path, source: np.ndarray, depth: np.ndarray, labels: np.ndarray, raw_layers: list[np.ndarray], inpainted_layers: list[np.ndarray], reconstruction: np.ndarray) -> dict:
    masks = np.stack([labels == i for i in range(5)], axis=0)
    coverage = masks.sum(axis=0)
    visible_changes = []
    for index, layer in enumerate(inpainted_layers):
        visible = labels == index
        visible_changes.append(int(np.count_nonzero(layer[visible, :3] != source[visible])))
    image_checks = []
    failures = []
    for path in sorted(root.rglob("*.png")):
        with Image.open(path) as image:
            if image.size != SIZE:
                failures.append(f"unexpected PNG size {image.size}: {path.relative_to(root)}")
            image_checks.append({"path": str(path.relative_to(root)), "size": list(image.size), "mode": image.mode})
    for path in sorted(root.rglob("*.gif")):
        with Image.open(path) as image:
            if image.size != SIZE:
                failures.append(f"unexpected GIF size {image.size}: {path.relative_to(root)}")
    exact_error = np.abs(reconstruction.astype(np.int16) - source.astype(np.int16))
    with Image.open(root / "depth" / "normalized_depth_u16.png") as normalized_u16:
        normalized_u16_mode = normalized_u16.mode
    mask_checks = {}
    for plate_id in PLATE_IDS:
        matte = np.asarray(Image.open(root / "masks" / f"{plate_id}-matte.png"))
        mask_checks[plate_id] = {"mode": "L", "binaryValues": sorted(int(value) for value in np.unique(matte))}
    checks = {
        "expectedSize": list(SIZE),
        "registeredPngCount": len(image_checks),
        "matteHolePixels": int(np.count_nonzero(coverage == 0)),
        "matteOverlapPixels": int(np.count_nonzero(coverage > 1)),
        "visiblePixelsChangedByInpaintingByPlate": dict(zip(PLATE_IDS, visible_changes)),
        "reconstructionMaximumAbsoluteChannelError": int(exact_error.max()),
        "reconstructionChangedChannelCount": int(np.count_nonzero(exact_error)),
        "normalizedDepth": {"shape": list(depth.shape), "dtype": str(depth.dtype), "minimum": float(depth.min()), "maximum": float(depth.max()), "u16Mode": normalized_u16_mode, "topStripMean": float(depth[:100].mean()), "bottomStripMean": float(depth[-100:].mean()), "topFartherThanBottom": bool(depth[:100].mean() < depth[-100:].mean())},
        "matteChannels": mask_checks,
        "rawPlateModes": [Image.fromarray(layer, mode="RGBA").mode for layer in raw_layers],
        "inpaintedPlateModes": [Image.fromarray(layer, mode="RGBA").mode for layer in inpainted_layers],
        "orientation": "top-left source coordinates; no crop, flip, or rotation",
        "depthConvention": "0=far, 1=near",
        "failures": failures,
    }
    checks["passed"] = not failures and checks["matteHolePixels"] == 0 and checks["matteOverlapPixels"] == 0 and not any(visible_changes) and checks["reconstructionMaximumAbsoluteChannelError"] == 0 and normalized_u16_mode == "I;16" and checks["normalizedDepth"]["topFartherThanBottom"] and all(item["binaryValues"] == [0, 255] for item in mask_checks.values())
    return checks


def write_report(root: Path, manifest: dict) -> None:
    plates = manifest["plates"]
    rows = "".join(
        f"<tr><td>{p['id']}</td><td>{p['orderFarToNear']}</td><td>{p['worldZ']:.2f}</td><td>{html.escape(p['owns'])}</td><td>{p['visiblePixelFraction']:.1%}</td><td>{p['hiddenInpaintedPixelCount']:,}</td></tr>"
        for p in plates
    )
    matte_cards = "".join(
        f"<figure><img src='../masks/{pid}-matte.png'><figcaption>{pid} cleaned matte</figcaption></figure>"
        for pid in PLATE_IDS
    )
    raw_cards = "".join(
        f"<figure><img src='../comparisons/{pid}-raw-transparency.png'><figcaption>{pid} raw cutout</figcaption></figure>"
        for pid in PLATE_IDS
    )
    inpaint_cards = "".join(
        f"<figure><img src='../comparisons/{pid}-inpainted-transparency.png'><figcaption>{pid} with hidden bleed</figcaption></figure>"
        for pid in PLATE_IDS
    )
    crop_cards = "".join(
        f"<figure><img src='../comparisons/crops/{name}.png'><figcaption>{name.replace('-', ' ')}</figcaption></figure>"
        for name in CROPS
    )
    report = f"""<!doctype html>
<html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>North five-plate first pass</title>
<style>
:root{{--ink:#f3e5bf;--muted:#b9c6b9;--panel:#18272a;--line:#435758;--accent:#e0ad4e}}*{{box-sizing:border-box}}body{{margin:0;background:#0d1719;color:var(--ink);font:16px/1.45 system-ui,sans-serif}}main{{max-width:1500px;margin:auto;padding:28px}}h1,h2{{letter-spacing:.03em}}h2{{border-top:1px solid var(--line);padding-top:24px;margin-top:36px}}p,li{{max-width:95ch}}.lede{{font-size:1.15rem}}.callout{{background:#26383a;border-left:5px solid var(--accent);padding:16px 20px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px}}figure{{margin:0;background:var(--panel);padding:10px}}img{{display:block;width:100%;height:auto;background:#d8d2c3}}figcaption{{color:var(--muted);padding-top:8px}}table{{border-collapse:collapse;width:100%;background:var(--panel)}}th,td{{border:1px solid var(--line);padding:9px;text-align:left;vertical-align:top}}code{{color:#ffd98c}}.wide{{grid-column:1/-1}}details{{background:var(--panel);padding:12px;margin:8px 0}}a{{color:#ffd98c}}
</style></head><body><main>
<p>Research-only manager viewer · {html.escape(manifest['runId'])}</p>
<h1>North: first semantic five-plate extraction + inpainting pass</h1>
<p class='lede'>{html.escape(manifest['outcome'])}</p>
<div class='callout'><strong>Recommendation: continue after specific corrections.</strong> Keep five plates for the next art pass, but hand-correct the forest/snow ownership, redraw long hidden farm/fence spans, and give the railway a dedicated continuous mesh or treatment before production.</div>
<h2>1. Source and Apple depth</h2><div class='grid'>
<figure><img src='../source/north-light.png'><figcaption>Authoritative 1672×941 source; SHA-256 <code>{manifest['source']['sha256']}</code>.</figcaption></figure>
<figure><img src='../depth/normalized_depth_color.png'><figcaption>Apple Depth Pro, normalized to 0 far / 1 near from reciprocal metric depth.</figcaption></figure></div>
<p>Apple inputs were reused from <code>{html.escape(manifest['depth']['sourceBakeoffRun'])}</code>; no model inference was repeated.</p>
<h2>2. Automatic geographic seed versus cleaned ownership</h2>
<figure><img src='../comparisons/semantic-contact-sheet.png'><figcaption>Manual depth ranges (0–.06, .06–.18, .18–.44, .44–.70, .70–1) are evidence only. Finished ownership follows geography and connected objects.</figcaption></figure>
<figure><img src='../comparisons/cleaned-boundary-overlay.png'><figcaption>Cleaned semantic boundaries. Tree/shadow components stay together; the fence belongs to N30; the railway is split geographically.</figcaption></figure>
<table><thead><tr><th>Plate</th><th>Order</th><th>Provisional Z</th><th>Semantic ownership</th><th>Visible area</th><th>Hidden pixels</th></tr></thead><tbody>{rows}</tbody></table>
<h2>3. Cleaned mattes</h2><p>The five visible mattes form a strict one-pixel-complete partition: no holes and no overlaps.</p><div class='grid'>{matte_cards}</div>
<h2>4. Raw registered plates</h2><div class='grid'>{raw_cards}</div>
<h2>5. Inpainted hidden coverage</h2><p>Visible RGB is byte-preserved. N00 uses landmark-free seeded snow/paper texture as a full foundation; N10 and N20 use the same clean snow only in hidden bleed. N30 uses deterministic nearest-visible extension plus OpenCV Telea; N40 has no nearer occluder.</p><div class='grid'>{inpaint_cards}</div>
<h2>6. Exact rest reconstruction</h2><div class='grid'>
<figure><img src='../comparisons/reconstruction.png'><figcaption>Far-to-near inpainted composite at original registration.</figcaption></figure>
<figure><img src='../comparisons/reconstruction-diff-amplified.png'><figcaption>Absolute difference ×16. Maximum original-registration error: {manifest['validation']['reconstructionMaximumAbsoluteChannelError']}.</figcaption></figure></div>
<h2>7. Locked-camera continuous dolly</h2>
<p>Projection mirrors the Flutter formula and uses the locked values: focal 2.0, VP (0.5, 0.40), Z −2→5, near 0.08, scale clamp 0.04–8, exit distance 0.55. Plate Z values are provisional and all remain beyond terminal Z=5.0.</p>
<figure><img src='../previews/dolly-preview.gif'><figcaption>Full locked track, then reverse. The early dark perimeter is expected because North alone is smaller before the Fields→North approach; terminal-frame seams and revealed hidden pixels are the evaluation target.</figcaption></figure>
<figure><img src='../previews/dolly-keyframes.png'><figcaption>Keyframes at camera Z −2, 1.5, 3.0, and 5.0.</figcaption></figure>
<h2>8. Evidence crops</h2><div class='grid'>{crop_cards}</div>
<h2>9. Findings and failure annotations</h2>
<ul><li><strong>Works:</strong> five geographic speeds read clearly, the source reconstructs exactly, silhouettes do not duplicate at rest, and the generic N00 snow foundation prevents transparent holes.</li><li><strong>Needs correction:</strong> automatic depth cannot decide the invisible N10/N20 snow split; connected-component cleanup still groups some touching forest shapes coarsely.</li><li><strong>Inpainting limit:</strong> Telea bleed is acceptable for narrow tree/fence reveals but smears long structured road, field, and rail spans. It is draft coverage, not final art.</li><li><strong>Railway:</strong> geographic splitting proves the problem but creates discontinuous scale along a single continuous object. A mesh or dedicated railway plate is required later.</li></ul>
<h2>10. Reproduction and validation</h2>
<p>Focused tests and exact commands are in <a href='../README.md'>README.md</a>. Machine-readable lineage and settings are in <a href='../manifest.json'>manifest.json</a>; validation passed: <strong>{str(manifest['validation']['passed']).lower()}</strong>.</p>
<details><summary>Inpainting record</summary><pre>{html.escape(json.dumps(manifest['inpainting'], indent=2))}</pre></details>
</main></body></html>"""
    report_path = root / "report" / "index.html"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report)


def run(args: argparse.Namespace) -> Path:
    repo = args.repo.resolve()
    config = json.loads((repo / "research/world_depth/north_bakeoff.json").read_text())
    source_path = repo / config["source"]["path"]
    if sha256(source_path) != config["source"]["sha256"]:
        raise ValueError("authoritative source SHA-256 does not match north_bakeoff.json")
    with Image.open(source_path) as opened:
        if opened.size != SIZE or opened.mode != "RGB":
            raise ValueError(f"unexpected source registration {opened.size} {opened.mode}")
        source = np.asarray(opened).copy()

    bakeoff = args.bakeoff_run.resolve()
    model_dir = bakeoff / "models" / "depth-pro"
    raw_path = model_dir / "raw_depth.npy"
    normalized_path = model_dir / "normalized_depth.npy"
    u16_path = model_dir / "normalized_depth_u16.png"
    color_path = model_dir / "normalized_depth_color.png"
    prior_manifest_path = bakeoff / "run_manifest.json"
    prior = json.loads(prior_manifest_path.read_text())
    depth_model = next(model for model in prior["models"] if model["id"] == "depth-pro")
    if sha256(raw_path) != depth_model["rawDepth"]["sha256"]:
        raise ValueError("Apple raw depth does not match completed bake-off manifest")
    depth = np.load(normalized_path, allow_pickle=False)
    raw_depth = np.load(raw_path, mmap_mode="r", allow_pickle=False)
    if depth.shape != source.shape[:2] or raw_depth.shape != source.shape[:2]:
        raise ValueError("Apple depth registration does not match source")
    if depth.dtype != np.float32 or not np.isfinite(depth).all() or depth.min() < 0 or depth.max() > 1:
        raise ValueError("Apple normalized depth is not finite float32 in [0,1]")

    root = args.output.resolve()
    if root.exists():
        if not args.overwrite:
            raise FileExistsError(f"output already exists: {root}")
        shutil.rmtree(root)
    for directory in ("source", "depth", "masks", "plates/raw", "plates/inpainted", "previews", "comparisons/crops", "licenses", "report"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, root / "source" / "north-light.png")
    shutil.copy2(raw_path, root / "depth" / "raw_depth.npy")
    shutil.copy2(normalized_path, root / "depth" / "normalized_depth.npy")
    shutil.copy2(u16_path, root / "depth" / "normalized_depth_u16.png")
    shutil.copy2(color_path, root / "depth" / "normalized_depth_color.png")
    for license_name in ("depth-pro-code-and-weight-license.txt", "depth-pro-upstream-README.md"):
        shutil.copy2(bakeoff / "licenses" / license_name, root / "licenses" / license_name)
    cv_package = Path(cv2.__file__).parent
    shutil.copy2(cv_package / "LICENSE.txt", root / "licenses" / "opencv-python-wrapper-MIT.txt")
    shutil.copy2(cv_package / "LICENSE-3RD-PARTY.txt", root / "licenses" / "opencv-binary-Apache-2.0-and-third-party.txt")

    auto = manual_depth_bands(depth)
    labels, cleanup = semantic_labels(source)
    raw_layers, inpainted_layers, plate_records = make_plates(source, labels)
    boundary = boundaries(labels)
    cleaned_overlay = source.copy()
    cleaned_overlay[boundary] = (230, 70, 55)
    cleaned_tint = np.rint(source.astype(np.float32) * 0.56 + label_color(labels).astype(np.float32) * 0.44).astype(np.uint8)
    auto_tint = np.rint(source.astype(np.float32) * 0.56 + label_color(auto).astype(np.float32) * 0.44).astype(np.uint8)

    inpaint_previews: list[np.ndarray] = []
    for index, plate_id in enumerate(PLATE_IDS):
        save_image(np.where(labels == index, 255, 0).astype(np.uint8), root / "masks" / f"{plate_id}-matte.png", "L")
        save_image(raw_layers[index], root / "plates" / "raw" / f"{plate_id}.png", "RGBA")
        save_image(inpainted_layers[index], root / "plates" / "inpainted" / f"{plate_id}.png", "RGBA")
        raw_preview = composite_rgba([raw_layers[index]], checkerboard(SIZE[1], SIZE[0]))[..., :3]
        inpaint_preview = composite_rgba([inpainted_layers[index]], checkerboard(SIZE[1], SIZE[0]))[..., :3]
        inpaint_previews.append(inpaint_preview)
        save_image(raw_preview, root / "comparisons" / f"{plate_id}-raw-transparency.png")
        save_image(inpaint_preview, root / "comparisons" / f"{plate_id}-inpainted-transparency.png")

    save_image(label_color(auto), root / "depth" / "manual-geographic-bands.png")
    save_image(label_color(labels), root / "masks" / "cleaned-labels.png")
    save_image(cleaned_overlay, root / "comparisons" / "cleaned-boundary-overlay.png")
    contact = comparison_canvas(
        [
            (source, "authoritative source"),
            (colorize_continuous(depth), "Apple continuous depth"),
            (auto_tint, "manual depth-range seed"),
            (cleaned_tint, "cleaned semantic ownership"),
            (cleaned_overlay, "cleaned boundaries"),
        ]
    )
    save_image(contact, root / "comparisons" / "semantic-contact-sheet.png")

    raw_reconstruction = composite_rgba(raw_layers)[..., :3]
    reconstruction = composite_rgba(inpainted_layers)[..., :3]
    difference = np.abs(reconstruction.astype(np.int16) - source.astype(np.int16)).astype(np.uint8)
    save_image(raw_reconstruction, root / "comparisons" / "raw-reconstruction.png")
    save_image(reconstruction, root / "comparisons" / "reconstruction.png")
    save_image(np.clip(difference.astype(np.uint16) * 16, 0, 255).astype(np.uint8), root / "comparisons" / "reconstruction-diff-amplified.png")

    camera_positions = np.linspace(CAMERA["startZ"], CAMERA["terminalZ"], 15)
    frames = [Image.fromarray(dolly_frame(inpainted_layers, float(z))) for z in camera_positions]
    frames += frames[-2:0:-1]
    frames[0].save(root / "previews" / "dolly-preview.gif", save_all=True, append_images=frames[1:], duration=190, loop=0, optimize=False)
    key_positions = (-2.0, 1.5, 3.0, 5.0)
    keyframes = [dolly_frame(inpainted_layers, z) for z in key_positions]
    save_image(comparison_canvas(list(zip(keyframes, [f"camera Z {z:.1f}" for z in key_positions]))), root / "previews" / "dolly-keyframes.png")
    terminal = dolly_frame(inpainted_layers, CAMERA["terminalZ"])
    save_image(terminal, root / "previews" / "terminal-frame.png")
    crop_owner = {"horizon": 0, "forest": 1, "isolated-trees": 2, "farms": 3, "foreground": 4, "railway": 3}
    for name, rect in CROPS.items():
        save_image(crop_review(source, cleaned_overlay, inpaint_previews[crop_owner[name]], rect), root / "comparisons" / "crops" / f"{name}.png")

    source_hash_after = sha256(source_path)
    if source_hash_after != config["source"]["sha256"]:
        raise ValueError("authoritative source changed during processing")
    validation = validate_run(root, source, depth, labels, raw_layers, inpainted_layers, reconstruction)
    if not validation["passed"]:
        raise ValueError(f"run validation failed: {validation}")

    camera_path = repo / "app/lib/src/world_depth_camera.dart"
    manifest = {
        "schemaVersion": 1,
        "experimentId": "north-five-plate-first-pass",
        "runId": root.name,
        "createdAt": datetime.now(ZoneInfo("America/Indiana/Indianapolis")).isoformat(),
        "outcome": "Five semantic plates reconstruct the still exactly and create a readable first dolly, but deterministic hidden bleed is not art-ready around long structured farms, fences, and the railway.",
        "recommendation": "continue after specific corrections",
        "source": {
            "authoritativePath": str(source_path.relative_to(repo)),
            "copiedPath": "source/north-light.png",
            "sha256": source_hash_after,
            "width": SIZE[0],
            "height": SIZE[1],
            "mode": "RGB",
        },
        "depth": {
            "model": "Apple Depth Pro",
            "sourceBakeoffRun": str(bakeoff.relative_to(repo)),
            "raw": {"sourcePath": str(raw_path.relative_to(repo)), "copiedPath": "depth/raw_depth.npy", "sha256": sha256(raw_path), "shape": list(raw_depth.shape), "dtype": str(raw_depth.dtype), "nativeConvention": "metric metres; lower is nearer"},
            "normalized": {"sourcePath": str(normalized_path.relative_to(repo)), "copiedPath": "depth/normalized_depth.npy", "sha256": sha256(normalized_path), "shape": list(depth.shape), "dtype": str(depth.dtype), "convention": "0=far, 1=near", "transform": "reciprocal metric depth, clipped to inverse-depth 1st/99th percentiles, linearly mapped to [0,1]"},
            "repository": depth_model["repository"],
            "repositoryRevision": depth_model["repositoryRevision"],
            "checkpoint": depth_model["checkpoint"],
            "repositoryLicense": depth_model["repositoryLicense"],
            "weightLicense": depth_model["weightLicense"],
        },
        "thresholds": {
            "kind": "manually selected normalized-depth geography seeds; not equal-range or quantile",
            "edges": [0.0, *MANUAL_THRESHOLDS, 1.0],
            "rangesFarToNear": ["[0.00,0.06)", "[0.06,0.18)", "[0.18,0.44)", "[0.44,0.70)", "[0.70,1.00]"],
            "finishedBoundaryPolicy": "semantic curves and whole connected objects supersede numeric bands",
        },
        "cleanup": cleanup,
        "plates": plate_records,
        "camera": {"sourcePath": str(camera_path.relative_to(repo)), "sourceSha256": sha256(camera_path), **CAMERA, "projection": "Flutter projectWorldDepthLayer perspective scale: (focalLength + worldZ) / max(nearPlane, focalLength + worldZ - cameraZ), clamped; scaled about vanishing point"},
        "inpainting": {
            "model": "OpenCV Telea fast-marching inpainting, deterministic nearest-visible extension, and seeded landmark-free snow synthesis",
            "implementation": f"opencv-python {importlib.metadata.version('opencv-python')} (cv2 {cv2.__version__})",
            "repository": "https://github.com/opencv/opencv",
            "repositoryLicense": {"id": "Apache-2.0", "scope": "bundled OpenCV binary", "evidence": "licenses/opencv-binary-Apache-2.0-and-third-party.txt"},
            "wrapperLicense": {"id": "MIT", "scope": "opencv-python wrapper", "evidence": "licenses/opencv-python-wrapper-MIT.txt"},
            "checkpoint": None,
            "weightLicense": {"id": "not applicable", "reason": "OpenCV Telea and the procedural texture stage have no learned weights."},
            "parameters": {"teleaRadiusPx": 4.0, "nearestDistance": "cv2 DIST_L2 mask size 5", "bleedRadiiPx": dict(zip(PLATE_IDS, BLEED_RADII)), "snowFoundation": "RGB [238,216,169] plus seeded Gaussian paper noise clipped to +/-7; no source landmark pixels", "strategyByPlate": {"N00": "full procedural snow foundation with Telea seam", "N10": "procedural snow hidden bleed", "N20": "procedural snow hidden bleed", "N30": "nearest-visible extension plus Telea", "N40": "no hidden extension"}},
            "prompt": None,
            "negativePrompt": None,
            "seed": FOUNDATION_SEED,
            "determinism": "NumPy PCG64 is reset to the recorded seed for every procedural snow field; OpenCV stages are deterministic.",
            "visiblePixelPolicy": "Original source RGB is restored byte-for-byte wherever the cleaned visible matte is 255.",
        },
        "artifacts": {
            "report": "report/index.html",
            "dollyPreview": "previews/dolly-preview.gif",
            "terminalFrame": "previews/terminal-frame.png",
            "reconstruction": "comparisons/reconstruction.png",
            "amplifiedDifference": "comparisons/reconstruction-diff-amplified.png",
        },
        "validation": validation,
        "failures": [
            "N10/N20 snow ownership is not visible in the flattened source and remains an art-directed boundary.",
            "Telea smears long structured field, road, fence, and railway spans when exposed by terminal parallax.",
            "The railway cannot remain one coherent rigid object when split among geographic planes; future mesh or dedicated treatment is required.",
        ],
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    readme = f"""# North five-plate first pass

Research-only output. No production asset was modified.

## Reproduction

From `{repo}`:

```bash
{Path(__import__('sys').executable)} -m unittest research.world_depth.test_bakeoff research.world_depth.test_five_plate
{Path(__import__('sys').executable)} research/world_depth/five_plate.py \\
  --repo {repo} \\
  --bakeoff-run {bakeoff} \\
  --output {root} \\
  --overwrite
```

The command reuses the recorded Apple Depth Pro arrays; it does not download weights or repeat inference.

## Decision

**Continue after specific corrections.** Keep five semantic plates, then hand-correct forest/snow ownership, redraw structured hidden farm/fence spans, and treat the railway as a continuous mesh or dedicated element before production.
"""
    (root / "README.md").write_text(readme)
    write_report(root, manifest)
    # Report/manifest were written after the first validation pass; confirm their
    # raster references were not accompanied by a misregistered image.
    final_validation = validate_run(root, source, depth, labels, raw_layers, inpainted_layers, reconstruction)
    manifest["validation"] = final_validation
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    write_report(root, manifest)
    return root


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--bakeoff-run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    output = run(parse_args())
    print(output)
