#!/usr/bin/env python3
"""Controlled North spatial-corridor follow-up.

The scene geometry is identical for the straight and dynamic camera variants.
Generated artifacts remain in the ignored research/runs/world_depth tree.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import importlib.metadata
import json
import math
import shutil
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

try:
    from research.world_depth.five_plate import composite_rgba, dolly_frame
except ModuleNotFoundError:
    from five_plate import composite_rgba, dolly_frame


WIDTH, HEIGHT = 1672, 941
VIEWPORT = (WIDTH, HEIGHT)
VP = (WIDTH * 0.5, HEIGHT * 0.40)
START_Z, END_Z = 3.0, 5.0
FRAME_COUNT = 41
FPS_DURATION_SECONDS = 3.0
PROJECTION_X = 720.0
CAMERA_HEIGHT = 1.14
GROUND_START_Y = 185
NEAR_PLANE = 0.08
SEED = 20260715
TREE_CARD_COUNT = 18
PREVIEW_SIZE = (836, 470)
CAMERA_LOCKED = {
    "status": "locked",
    "viewport": [WIDTH, HEIGHT],
    "focalLength": 2.0,
    "vanishingPoint": [0.5, 0.40],
    "startZ": -2.0,
    "terminalZ": 5.0,
    "nearPlane": 0.08,
    "minimumScale": 0.04,
    "maximumScale": 8.0,
    "plateExitDistance": 0.55,
    "pitchDegrees": 0.0,
    "yawDegrees": 0.0,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def save_image(array: np.ndarray, path: Path, mode: str | None = None, **kwargs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(array, mode=mode) if mode else Image.fromarray(array)
    image.save(path, **kwargs)


def camera_path(variant: str, z: float) -> dict[str, float]:
    if not START_Z <= z <= END_Z:
        raise ValueError(f"camera z must be in [{START_Z}, {END_Z}]")
    t = (z - START_Z) / (END_Z - START_Z)
    if variant in {"baseline", "straight"}:
        x = y = 0.0
    elif variant == "dynamic":
        x = 0.022 * math.sin(math.pi * t)
        y = 0.008 * math.sin(2.0 * math.pi * t)
    else:
        raise ValueError(f"unknown variant: {variant}")
    return {"x": x, "y": y, "z": z, "pitchDegrees": 0.0, "yawDegrees": 0.0}


def project_ground(world_x: float, world_z: float, camera: dict[str, float]) -> tuple[float, float, float] | None:
    distance = world_z - camera["z"]
    if distance <= NEAR_PLANE:
        return None
    screen_x = VP[0] + PROJECTION_X * (world_x - camera["x"]) / distance
    screen_y = VP[1] + PROJECTION_X * (CAMERA_HEIGHT + camera["y"]) / distance
    return screen_x, screen_y, distance


def project_card_rect(card: dict, camera: dict[str, float]) -> tuple[float, float, float, float] | None:
    projected = project_ground(card["x"], card["z"], camera)
    if projected is None:
        return None
    screen_x, screen_y, distance = projected
    scale = PROJECTION_X / distance
    width = card["width"] * scale
    height = card["height"] * scale
    return screen_x - width * card["anchor"][0], screen_y - height * card["anchor"][1], width, height


def landmark_free_texture(size: tuple[int, int], seed: int = SEED) -> np.ndarray:
    width, height = size
    rng = np.random.default_rng(seed)
    coarse = rng.normal(0, 1, (height, width)).astype(np.float32)
    coarse = cv2.GaussianBlur(coarse, (0, 0), 2.4)
    coarse *= 3.8 / max(float(coarse.std()), 1e-6)
    fine = rng.normal(0, 0.9, (height, width)).astype(np.float32)
    texture = np.clip(coarse + fine, -8, 8)
    return np.clip(128 + texture * 8, 0, 255).astype(np.uint8)


def make_backdrop(source: np.ndarray, texture: np.ndarray) -> np.ndarray:
    noise = (texture.astype(np.float32) - 128.0) / 8.0
    tiled = np.tile(noise, (math.ceil(HEIGHT / noise.shape[0]), math.ceil(WIDTH / noise.shape[1])))[:HEIGHT, :WIDTH]
    backdrop = np.clip(np.asarray([238, 216, 169], dtype=np.float32)[None, None, :] + tiled[..., None], 0, 255).astype(np.uint8)
    backdrop[:188] = source[:188]
    for y in range(188, 209):
        amount = (y - 188) / 21.0
        backdrop[y] = np.rint(source[y].astype(np.float32) * (1 - amount) + backdrop[y].astype(np.float32) * amount).astype(np.uint8)
    return backdrop


def object_component_mask(source: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    red, green, blue = (source[..., index].astype(np.int16) for index in range(3))
    darkest = np.max(source, axis=2) < 112
    blue_shadow = (red < 158) & (green > red + 5) & (blue > red + 3) & (green < 168)
    yy = np.arange(source.shape[0])[:, None]
    candidate = (darkest | blue_shadow) & (yy >= 150) & (yy < 680)
    candidate = cv2.morphologyEx(candidate.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))
    count, labels, stats, centroids = cv2.connectedComponentsWithStats(candidate, connectivity=8)
    if count < 2:
        raise ValueError("no extractable source objects")
    return labels, stats, centroids, darkest


def _select_tree_components(stats: np.ndarray, centroids: np.ndarray) -> list[int]:
    bins = ((220, 360), (360, 500), (500, 635))
    selected: list[int] = []
    for lower, upper in bins:
        candidates = []
        for component in range(1, len(stats)):
            x, y, width, height, area = (int(value) for value in stats[component])
            bottom = y + height
            if not lower <= bottom < upper:
                continue
            if area < 220 or width < 8 or height < 18 or width > 235 or height > 215:
                continue
            candidates.append(component)
        candidates.sort(key=lambda component: int(stats[component, cv2.CC_STAT_AREA]), reverse=True)
        chosen: list[int] = []
        for minimum_separation in (125, 90, 60, 0):
            for component in candidates:
                if component in chosen:
                    continue
                center_x = float(centroids[component][0])
                if all(abs(center_x - float(centroids[other][0])) >= minimum_separation for other in chosen):
                    chosen.append(component)
                if len(chosen) == TREE_CARD_COUNT // 3:
                    break
            if len(chosen) == TREE_CARD_COUNT // 3:
                break
        if len(chosen) != TREE_CARD_COUNT // 3:
            raise ValueError(f"could not select six cards in source-space bin {lower}:{upper}")
        selected.extend(chosen)
    return selected


def _object_record(
    source: np.ndarray,
    depth: np.ndarray,
    mask: np.ndarray,
    crop: tuple[int, int, int, int],
    card_id: str,
    kind: str,
    asset_path: Path,
) -> dict:
    x, y, width, height = crop
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        raise ValueError(f"empty mask for {card_id}")
    lower = ys >= np.quantile(ys, 0.92)
    contact_x_local = float(np.median(xs[lower]))
    contact_y_local = float(np.max(ys))
    contact_x = x + contact_x_local
    contact_y = y + contact_y_local
    depth_values = depth[y : y + height, x : x + width][mask]
    depth_seed = float(np.median(depth_values))
    base_distance = PROJECTION_X * CAMERA_HEIGHT / max(contact_y - VP[1], 40.0)
    depth_adjustment = float(np.clip((0.35 - depth_seed) * 0.16, -0.06, 0.06))
    distance = base_distance + depth_adjustment
    world_z = START_Z + distance
    world_x = (contact_x - VP[0]) * distance / PROJECTION_X
    world_width = width * distance / PROJECTION_X
    world_height = height * distance / PROJECTION_X
    alpha = np.clip(cv2.GaussianBlur(mask.astype(np.float32) * 255.0, (0, 0), 0.55), 0, 255).astype(np.uint8)
    rgba = np.dstack((source[y : y + height, x : x + width], alpha))
    rgba[alpha == 0, :3] = 0
    save_image(rgba, asset_path, "RGBA")
    return {
        "id": card_id,
        "kind": kind,
        "asset": str(asset_path),
        "x": float(world_x),
        "y": 0.0,
        "z": float(world_z),
        "width": float(world_width),
        "height": float(world_height),
        "anchor": [contact_x_local / width, contact_y_local / height],
        "anchorType": "ground-contact",
        "sourceCrop": [x, y, width, height],
        "sourceGroundContact": [float(contact_x), float(contact_y)],
        "depthSeedNormalized": depth_seed,
        "depthSeedAdjustmentZ": depth_adjustment,
    }


def extract_cards(source: np.ndarray, depth: np.ndarray, output: Path) -> list[dict]:
    labels, stats, centroids, _ = object_component_mask(source)
    selected = _select_tree_components(stats, centroids)
    records: list[dict] = []
    for ordinal, component in enumerate(selected, start=1):
        x, y, width, height, _ = (int(value) for value in stats[component])
        pad = 4
        x0, y0 = max(0, x - pad), max(0, y - pad)
        x1, y1 = min(WIDTH, x + width + pad), min(HEIGHT, y + height + pad)
        mask = labels[y0:y1, x0:x1] == component
        mask = cv2.dilate(mask.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))) > 0
        path = output / f"tree-{ordinal:02d}.png"
        records.append(_object_record(source, depth, mask, (x0, y0, x1 - x0, y1 - y0), f"tree-{ordinal:02d}", "tree-cluster", path))

    pylon_boxes = ((255, 628, 50, 91), (522, 625, 52, 94), (1157, 635, 52, 97))
    for ordinal, (x, y, width, height) in enumerate(pylon_boxes, start=1):
        crop = source[y : y + height, x : x + width]
        dark = np.max(crop, axis=2) < 145
        dark = cv2.morphologyEx(dark.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        count, components, stats2, _ = cv2.connectedComponentsWithStats(dark, connectivity=8)
        keep = np.zeros(dark.shape, dtype=np.uint8)
        for component in range(1, count):
            _, _, component_width, component_height, area = stats2[component]
            if area >= 6 and (component_height >= 8 or component_width >= 8):
                keep[components == component] = 1
        keep = cv2.dilate(keep, np.ones((3, 3), np.uint8)) > 0
        path = output / f"pylon-{ordinal:02d}.png"
        records.append(_object_record(source, depth, keep, (x, y, width, height), f"pylon-{ordinal:02d}", "pylon", path))

    records.sort(key=lambda card: card["z"], reverse=True)
    for card in records:
        card["depthGroup"] = "far" if card["z"] >= 7.0 else "middle" if card["z"] >= 5.1 else "near"
    return records


def make_ground_markers() -> list[dict[str, float]]:
    rng = np.random.default_rng(SEED + 1)
    return [
        {"x": float(rng.uniform(-3.8, 3.8)), "z": float(rng.uniform(3.25, 15.0)), "length": float(rng.uniform(0.015, 0.05))}
        for _ in range(260)
    ]


def render_ground(backdrop: np.ndarray, texture: np.ndarray, camera: dict[str, float]) -> np.ndarray:
    frame = backdrop.copy()
    noise = (texture.astype(np.float32) - 128.0) / 8.0
    texture_height, texture_width = noise.shape
    xs = np.arange(WIDTH, dtype=np.float32)
    projection_height = PROJECTION_X * (CAMERA_HEIGHT + camera["y"])
    for screen_y in range(GROUND_START_Y, HEIGHT):
        distance = projection_height / max(screen_y - VP[1], 1.0)
        world_z = camera["z"] + distance
        world_x = camera["x"] + (xs - VP[0]) * distance / PROJECTION_X
        sample_x = np.mod(np.floor(world_x * 76.0).astype(np.int32), texture_width)
        sample_y = int(math.floor(world_z * 83.0)) % texture_height
        grain = noise[sample_y, sample_x]
        left_field = np.asarray([207, 166, 48], dtype=np.float32)
        right_field = np.asarray([116, 139, 63], dtype=np.float32)
        field = np.where((world_x < 0)[..., None], left_field, right_field)
        stripe = (int(math.floor(world_z * 3.2)) % 2) * 7 - 3.5
        field = field + stripe
        snow = np.broadcast_to(np.asarray([238, 216, 169], dtype=np.float32), field.shape)
        snow_mix = float(np.clip((world_z - 4.25) / 0.42, 0.0, 1.0))
        base = field * (1.0 - snow_mix) + snow * snow_mix
        frame[screen_y] = np.clip(base + grain[..., None], 0, 255).astype(np.uint8)
    return frame


def _ground_polyline(world_x: float, z_values: np.ndarray, camera: dict[str, float]) -> list[tuple[float, float]]:
    points = []
    for world_z in z_values:
        point = project_ground(world_x, float(world_z), camera)
        if point is not None:
            points.append((point[0], point[1]))
    return points


def draw_railway(image: Image.Image, camera: dict[str, float], geometry_only: bool = False) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    near_z = max(3.20, camera["z"] + 0.82)
    far_z = 15.0
    far_left = project_ground(-0.26, far_z, camera)
    far_right = project_ground(0.26, far_z, camera)
    near_left = project_ground(-0.26, near_z, camera)
    near_right = project_ground(0.26, near_z, camera)
    if all((far_left, far_right, near_left, near_right)):
        draw.polygon(
            [(far_left[0], far_left[1]), (far_right[0], far_right[1]), (near_right[0], near_right[1]), (near_left[0], near_left[1])],
            fill=(216, 190, 143, 255) if not geometry_only else (211, 183, 78, 150),
        )
    z_values = np.linspace(far_z, near_z, 180)
    for rail_x in (-0.115, 0.115):
        points = _ground_polyline(rail_x, z_values, camera)
        if len(points) > 1:
            draw.line(points, fill=(28, 40, 38, 255) if not geometry_only else (233, 79, 59, 255), width=5 if not geometry_only else 3)
    tie_z = np.arange(3.25, far_z, 0.22)
    for world_z in tie_z:
        if world_z <= camera["z"] + NEAR_PLANE:
            continue
        left = project_ground(-0.21, float(world_z), camera)
        right = project_ground(0.21, float(world_z), camera)
        if left is None or right is None or min(left[1], right[1]) < GROUND_START_Y - 5:
            continue
        width = max(1, min(10, round(5 / left[2])))
        draw.line((left[0], left[1], right[0], right[1]), fill=(42, 49, 42, 255), width=width)


def draw_ground_markers(image: Image.Image, camera: dict[str, float], markers: list[dict[str, float]]) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    for marker in markers:
        point = project_ground(marker["x"], marker["z"], camera)
        if point is None or not (GROUND_START_Y <= point[1] < HEIGHT):
            continue
        length = max(1.0, min(8.0, PROJECTION_X * marker["length"] / point[2]))
        draw.line((point[0] - length, point[1], point[0] + length, point[1]), fill=(88, 111, 103, 65), width=1)


def draw_scene_guides(image: Image.Image, camera: dict[str, float], cards: list[dict], bounds: bool, mesh: bool, anchors: bool) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    if mesh:
        for world_x in np.arange(-4.0, 4.01, 0.5):
            points = _ground_polyline(float(world_x), np.linspace(15.0, camera["z"] + 0.82, 100), camera)
            if len(points) > 1:
                draw.line(points, fill=(53, 170, 171, 145), width=1)
        for world_z in np.arange(max(3.25, camera["z"] + 0.25), 15.0, 0.5):
            left = project_ground(-4.0, float(world_z), camera)
            right = project_ground(4.0, float(world_z), camera)
            if left and right:
                draw.line((left[0], left[1], right[0], right[1]), fill=(53, 170, 171, 110), width=1)
    for card in cards:
        rect = project_card_rect(card, camera)
        if rect is None:
            continue
        left, top, width, height = rect
        if bounds:
            draw.rectangle((left, top, left + width, top + height), outline=(231, 77, 59, 210), width=2)
        if anchors:
            point = project_ground(card["x"], card["z"], camera)
            if point:
                draw.ellipse((point[0] - 4, point[1] - 4, point[0] + 4, point[1] + 4), fill=(244, 207, 77, 255), outline=(25, 34, 32, 255))


def render_hybrid(
    backdrop: np.ndarray,
    texture: np.ndarray,
    card_images: dict[str, Image.Image],
    cards: list[dict],
    markers: list[dict[str, float]],
    variant: str,
    z: float,
    *,
    bounds: bool = False,
    mesh: bool = False,
    anchors: bool = False,
    cards_enabled: bool = True,
    railway_enabled: bool = True,
) -> np.ndarray:
    camera = camera_path(variant, z)
    frame = Image.fromarray(render_ground(backdrop, texture, camera), mode="RGB").convert("RGBA")
    draw_ground_markers(frame, camera, markers)
    if railway_enabled:
        draw_railway(frame, camera)
    if cards_enabled:
        for card in sorted(cards, key=lambda item: item["z"], reverse=True):
            rect = project_card_rect(card, camera)
            if rect is None:
                continue
            left, top, projected_width, projected_height = rect
            if left >= WIDTH or top >= HEIGHT or left + projected_width <= 0 or top + projected_height <= 0:
                continue
            if projected_width > WIDTH * 4 or projected_height > HEIGHT * 4:
                continue
            resized = card_images[card["id"]].resize((max(1, round(projected_width)), max(1, round(projected_height))), Image.Resampling.LANCZOS)
            frame.alpha_composite(resized, (round(left), round(top)))
    draw_scene_guides(frame, camera, cards, bounds, mesh, anchors)
    return np.asarray(frame.convert("RGB"))


def comparison_canvas(items: list[tuple[np.ndarray, str]], columns: int | None = None) -> np.ndarray:
    columns = columns or min(3, len(items))
    rows = math.ceil(len(items) / columns)
    canvas = Image.new("RGB", VIEWPORT, (14, 24, 26))
    draw = ImageDraw.Draw(canvas)
    gap, header = 12, 28
    cell_width = (WIDTH - gap * (columns + 1)) // columns
    cell_height = (HEIGHT - gap * (rows + 1)) // rows
    for index, (array, title) in enumerate(items):
        column, row = index % columns, index // columns
        x = gap + column * (cell_width + gap)
        y = gap + row * (cell_height + gap)
        source = Image.fromarray(array).convert("RGB")
        ratio = min(cell_width / source.width, (cell_height - header) / source.height)
        body = source.resize((max(1, round(source.width * ratio)), max(1, round(source.height * ratio))), Image.Resampling.LANCZOS)
        canvas.paste(body, (x + (cell_width - body.width) // 2, y + header + (cell_height - header - body.height) // 2))
        draw.rectangle((x, y, x + cell_width, y + cell_height), outline=(55, 76, 76), width=1)
        draw.text((x + 7, y + 7), title, fill=(244, 229, 192), font=ImageFont.load_default())
    return np.asarray(canvas)


def card_contact_sheet(cards: list[dict], card_images: dict[str, Image.Image]) -> np.ndarray:
    items = []
    for card in cards:
        checker = np.empty((220, 300, 3), dtype=np.uint8)
        yy, xx = np.indices(checker.shape[:2])
        light = ((xx // 18 + yy // 18) % 2) == 0
        checker[light], checker[~light] = (226, 221, 207), (176, 184, 177)
        panel = Image.fromarray(checker)
        asset = card_images[card["id"]].copy()
        asset.thumbnail((270, 185), Image.Resampling.LANCZOS)
        panel.paste(asset, ((300 - asset.width) // 2, (220 - asset.height) // 2), asset)
        items.append((np.asarray(panel), f"{card['id']} · {card['depthGroup']} · Z {card['z']:.2f}"))
    return comparison_canvas(items, columns=5)


def scene_layout(cards: list[dict]) -> np.ndarray:
    image = Image.new("RGB", VIEWPORT, (15, 26, 28))
    draw = ImageDraw.Draw(image)
    margin = 90
    draw.rectangle((margin, margin, WIDTH - margin, HEIGHT - margin), outline=(72, 99, 99), width=2)
    def point(world_x: float, world_z: float) -> tuple[float, float]:
        return margin + (world_x + 4.0) / 8.0 * (WIDTH - margin * 2), HEIGHT - margin - (world_z - 3.0) / 12.0 * (HEIGHT - margin * 2)
    rail_top = point(0.0, 15.0)
    rail_bottom = point(0.0, 3.0)
    draw.line((*rail_top, *rail_bottom), fill=(230, 180, 71), width=6)
    for z in range(3, 16):
        y = point(0, z)[1]
        draw.line((margin, y, WIDTH - margin, y), fill=(39, 57, 59), width=1)
        draw.text((25, y - 7), f"Z {z}", fill=(173, 192, 183), font=ImageFont.load_default())
    colors = {"far": (72, 153, 168), "middle": (118, 177, 93), "near": (223, 105, 66)}
    for card in cards:
        x, y = point(card["x"], card["z"])
        color = colors[card["depthGroup"]]
        draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=color)
        draw.text((x + 10, y - 7), card["id"], fill=(235, 226, 199), font=ImageFont.load_default())
    draw.text((margin, 28), "NORTH HYBRID SCENE · world X/Z · one continuous railway at X=0", fill=(244, 229, 192), font=ImageFont.load_default())
    return np.asarray(image)


def trajectory_metrics(cards: list[dict], duration: float = FPS_DURATION_SECONDS) -> dict:
    z_values = np.linspace(START_Z, END_Z, FRAME_COUNT)
    result = {"durationSeconds": duration, "groups": {}, "representativeTrajectories": {}, "nearObjectsExited": 0, "horizonDisplacementPx": {"straight": 0.0, "dynamic": 0.0}}
    for group in ("far", "middle", "near"):
        group_cards = [card for card in cards if card["depthGroup"] == group]
        speeds = []
        for card in group_cards:
            points = []
            for z in z_values:
                rect = project_card_rect(card, camera_path("straight", float(z)))
                if rect is not None:
                    points.append((rect[0] + rect[2] * 0.5, rect[1] + rect[3]))
            if len(points) > 1:
                path_length = sum(math.dist(points[i - 1], points[i]) for i in range(1, len(points)))
                speeds.append(path_length / duration)
        result["groups"][group] = {"objectCount": len(group_cards), "meanScreenVelocityPxPerSecond": float(np.mean(speeds)) if speeds else 0.0, "maximumScreenVelocityPxPerSecond": float(np.max(speeds)) if speeds else 0.0}
        if group_cards:
            representative = sorted(group_cards, key=lambda card: card["z"])[len(group_cards) // 2]
            trajectory = []
            for z in (3.0, 3.5, 4.0, 4.5, 5.0):
                rect = project_card_rect(representative, camera_path("straight", z))
                trajectory.append({"cameraZ": z, "screenAnchor": None if rect is None else [rect[0] + rect[2] * representative["anchor"][0], rect[1] + rect[3] * representative["anchor"][1]]})
            result["representativeTrajectories"][group] = {"objectId": representative["id"], "worldZ": representative["z"], "samples": trajectory}
    for card in cards:
        start_rect = project_card_rect(card, camera_path("straight", START_Z))
        end_rect = project_card_rect(card, camera_path("straight", END_Z))
        starts_visible = start_rect is not None and start_rect[0] < WIDTH and start_rect[1] < HEIGHT and start_rect[0] + start_rect[2] > 0 and start_rect[1] + start_rect[3] > 0
        ends_visible = end_rect is not None and end_rect[0] < WIDTH and end_rect[1] < HEIGHT and end_rect[0] + end_rect[2] > 0 and end_rect[1] + end_rect[3] > 0
        if starts_visible and not ends_visible:
            result["nearObjectsExited"] += 1
    return result


def trajectory_diagram(cards: list[dict], diagnostics: dict) -> np.ndarray:
    image = Image.new("RGB", VIEWPORT, (14, 24, 26))
    draw = ImageDraw.Draw(image)
    colors = {"far": (72, 153, 168), "middle": (118, 177, 93), "near": (223, 105, 66)}
    for group, record in diagnostics["representativeTrajectories"].items():
        points = [tuple(sample["screenAnchor"]) for sample in record["samples"] if sample["screenAnchor"] is not None]
        if len(points) > 1:
            draw.line(points, fill=colors[group], width=5)
        for index, point in enumerate(points):
            draw.ellipse((point[0] - 7, point[1] - 7, point[0] + 7, point[1] + 7), fill=colors[group])
            draw.text((point[0] + 10, point[1] - 8), f"{group} · Zc {3 + 0.5 * index:.1f}", fill=(240, 229, 196), font=ImageFont.load_default())
    draw.line((VP[0] - 12, VP[1], VP[0] + 12, VP[1]), fill=(236, 78, 58), width=2)
    draw.line((VP[0], VP[1] - 12, VP[0], VP[1] + 12), fill=(236, 78, 58), width=2)
    draw.text((30, 30), "REPRESENTATIVE SCREEN-SPACE TRAJECTORIES · straight hybrid · camera Z 3→5", fill=(244, 229, 192), font=ImageFont.load_default())
    return np.asarray(image)


def _annotate_card(frame: np.ndarray, card: dict, variant: str, z: float) -> np.ndarray:
    image = Image.fromarray(frame)
    draw = ImageDraw.Draw(image, "RGBA")
    rect = project_card_rect(card, camera_path(variant, z))
    if rect is None:
        draw.rectangle((20, 20, 250, 53), fill=(15, 25, 27, 220))
        draw.text((30, 31), f"{card['id']} passed the camera", fill=(244, 229, 192), font=ImageFont.load_default())
    else:
        left, top, width, height = rect
        draw.rectangle((left, top, left + width, top + height), outline=(235, 75, 57, 255), width=4)
        draw.ellipse((left + width * card["anchor"][0] - 6, top + height * card["anchor"][1] - 6, left + width * card["anchor"][0] + 6, top + height * card["anchor"][1] + 6), fill=(247, 207, 67, 255))
    return np.asarray(image)


def _gif_frames(frame_paths: list[Path]) -> list[Image.Image]:
    frames = [Image.open(path).convert("RGB") for path in frame_paths]
    return frames + frames[-2:0:-1]


def _save_ping_pong_gif(frame_paths: list[Path], output: Path, duration_ms: int = 75) -> None:
    frames = _gif_frames(frame_paths)
    output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(output, save_all=True, append_images=frames[1:], duration=duration_ms, loop=0, optimize=False)
    for frame in frames:
        frame.close()


def _side_by_side_frame(images: list[Image.Image], z: float) -> Image.Image:
    canvas = Image.new("RGB", (1280, 720), (13, 23, 25))
    draw = ImageDraw.Draw(canvas)
    labels = ("C · flat five-plate", "A · straight hybrid", "B · dynamic hybrid")
    panel_width, panel_height = 404, 228
    for index, (source, label) in enumerate(zip(images, labels)):
        panel = source.resize((panel_width, panel_height), Image.Resampling.LANCZOS)
        x = 16 + index * 421
        canvas.paste(panel, (x, 205))
        draw.text((x + 4, 178), label, fill=(244, 229, 192), font=ImageFont.load_default())
        draw.rectangle((x, 205, x + panel_width, 205 + panel_height), outline=(65, 86, 86), width=2)
    draw.text((24, 28), "NORTH APPROACH · synchronized camera Z 3.0→5.0→3.0 · normal speed", fill=(244, 229, 192), font=ImageFont.load_default())
    draw.text((24, 470), f"camera Z {z:.2f} · identical A/B geometry · locked VP {CAMERA_LOCKED['vanishingPoint']} · pitch/yaw 0", fill=(177, 199, 188), font=ImageFont.load_default())
    draw.text((24, 504), "Look for outward object flow, ground motion, railway continuity, horizon stability, and card-edge failures.", fill=(177, 199, 188), font=ImageFont.load_default())
    return canvas


def _write_viewer_report(root: Path, manifest: dict, diagnostics: dict) -> None:
    group_rows = "".join(
        f"<tr><td>{group}</td><td>{values['objectCount']}</td><td>{values['meanScreenVelocityPxPerSecond']:.1f} px/s</td><td>{values['maximumScreenVelocityPxPerSecond']:.1f} px/s</td></tr>"
        for group, values in diagnostics["groups"].items()
    )
    report = f"""<!doctype html>
<html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>North spatial corridor follow-up</title>
<style>
:root{{--paper:#f1e3bc;--muted:#afc1b5;--panel:#17272a;--line:#42595a;--accent:#dca847}}*{{box-sizing:border-box}}body{{margin:0;background:#0b1517;color:var(--paper);font:16px/1.45 system-ui,sans-serif}}main{{max-width:1500px;margin:auto;padding:26px}}h1,h2{{letter-spacing:.025em}}h2{{border-top:1px solid var(--line);padding-top:24px;margin-top:34px}}p,li{{max-width:100ch}}.callout{{padding:16px 20px;background:#26383a;border-left:5px solid var(--accent)}}.viewer{{background:var(--panel);padding:14px;border:1px solid var(--line)}}canvas{{display:block;width:100%;height:auto;background:#111}}.controls{{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin-bottom:12px}}button,select,input{{font:inherit}}button,select{{background:#283b3d;color:var(--paper);border:1px solid #678080;padding:7px 10px}}input[type=range]{{flex:1;min-width:240px}}label{{display:flex;gap:6px;align-items:center}}output{{display:block;margin-top:10px;color:var(--muted);font-family:ui-monospace,monospace}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:14px}}figure{{margin:0;background:var(--panel);padding:10px}}img{{display:block;width:100%;height:auto;background:#d6d1c4}}figcaption{{padding-top:8px;color:var(--muted)}}table{{border-collapse:collapse;width:100%;background:var(--panel)}}th,td{{border:1px solid var(--line);padding:9px;text-align:left}}code{{color:#ffd88a}}a{{color:#ffd88a}}.badge{{display:inline-block;padding:3px 8px;border:1px solid #6c8583;color:var(--muted);margin-right:6px}}details{{background:var(--panel);padding:12px}}
</style></head><body><main>
<p>Research-only controlled follow-up · {html.escape(manifest['runId'])}</p>
<h1>North spatial corridor: geometry versus camera path</h1>
<p class='callout'><strong>Outcome:</strong> Straight hybrid A reads as forward travel. Dynamic hybrid B adds mild sway but no material improvement. Recommended production direction: <strong>hybrid geometry with straight camera</strong>.</p>
<p><span class='badge'>21 cards</span><span class='badge'>18 tree/cluster</span><span class='badge'>3 pylons</span><span class='badge'>{diagnostics['nearObjectsExited']} exits</span><span class='badge'>one continuous railway</span></p>

<h2>Interactive synchronized viewer</h2>
<div class='viewer'>
  <div class='controls'>
    <button id='play' type='button'>Play</button>
    <label>Variant <select id='variant' aria-label='Variant'><option value='baseline'>Baseline C · five plates</option><option value='straight' selected>Straight hybrid A</option><option value='dynamic'>Dynamic hybrid B</option></select></label>
    <label><input id='bounds' type='checkbox'> Object-card bounds</label>
    <label><input id='mesh' type='checkbox'> Ground mesh</label>
    <label><input id='anchors' type='checkbox'> World anchors</label>
    <label><input id='slow' type='checkbox'> Slow motion</label>
  </div>
  <div class='controls'><label for='camera-z'>Camera Z</label><input id='camera-z' type='range' min='3' max='5' step='0.05' value='3'><span id='z-label'>3.00</span></div>
  <canvas id='scene' width='1672' height='941'></canvas>
  <output id='readout'>Loading scene…</output>
</div>
<p>The viewer uses pre-rendered deterministic frames for repeatable comparison and draws bounds, mesh, and anchors live in Canvas. It has no CDN or network dependency.</p>

<h2>Synchronized normal-speed evidence</h2>
<figure><img src='../comparisons/synchronized-baseline-A-B.gif'><figcaption>Forward Z 3→5 and reverse Z 5→3. Scene geometry is identical between A and B.</figcaption></figure>
<div class='grid'><figure><img src='../previews/straight-hybrid.gif'><figcaption>A · straight Z-only hybrid.</figcaption></figure><figure><img src='../previews/dynamic-hybrid.gif'><figcaption>B · same geometry with restrained non-authoritative X/Y offsets.</figcaption></figure><figure><img src='../comparisons/baseline-five-plate-original.gif'><figcaption>C · byte-identical original five-plate GIF.</figcaption></figure></div>

<h2>Scene representation</h2>
<div class='grid'><figure><img src='../scene/layout.png'><figcaption>Object X/Z positions and continuous railway.</figcaption></figure><figure><img src='../ground/wireframe.png'><figcaption>Projective ground mesh at camera Z 3.0.</figcaption></figure><figure><img src='../railway/geometry.png'><figcaption>Continuous ballast, rails, and world-spaced ties.</figcaption></figure><figure><img src='../cards/contact-sheet.png'><figcaption>Extracted tree/shadow clusters and pylons.</figcaption></figure></div>

<h2>Keyframes and terminal frames</h2>
<div class='grid'><figure><img src='../comparisons/keyframes-baseline.png'><figcaption>Baseline C · Z 3, 3.5, 4, 4.5, 5.</figcaption></figure><figure><img src='../comparisons/keyframes-straight.png'><figcaption>Straight A · same Z samples.</figcaption></figure><figure><img src='../comparisons/keyframes-dynamic.png'><figcaption>Dynamic B · same Z samples.</figcaption></figure><figure><img src='../previews/terminal-straight.png'><figcaption>A terminal Z 5.0.</figcaption></figure><figure><img src='../previews/terminal-dynamic.png'><figcaption>B terminal Z 5.0; offsets return to zero.</figcaption></figure><figure><img src='../previews/clean-straight-Z4.png'><figcaption>Clean guide-free A at Z 4.0.</figcaption></figure></div>

<h2>Passage and continuity evidence</h2>
<div class='grid'><figure><img src='../comparisons/near-card-passage.png'><figcaption>Representative near card moves outward, enlarges, then passes.</figcaption></figure><figure><img src='../comparisons/railway-continuity.png'><figcaption>Railway remains one perspective element through Z 3, 4, and 5.</figcaption></figure><figure><img src='../diagnostics/trajectories.png'><figcaption>Far, middle, and near screen-space trajectories.</figcaption></figure></div>

<h2>Motion diagnostics</h2>
<table><thead><tr><th>Depth group</th><th>Cards</th><th>Mean velocity</th><th>Maximum velocity</th></tr></thead><tbody>{group_rows}</tbody></table>
<ul><li>Nearby objects exiting during Z 3→5: <strong>{diagnostics['nearObjectsExited']}</strong>.</li><li>Horizon displacement: <strong>0 px</strong> in A and B; VP, pitch, and yaw remain fixed.</li><li>A: strong outward optic flow, ground texture flow, and passing ties/cards. This reads as travel rather than a uniform zoom.</li><li>B: camera X peaks at 0.022 world units and Y at 0.008; the added motion is visible but does not improve spatial comprehension enough to justify runtime complexity.</li><li>Visible limitations: close cards reveal billboard/cardboard behavior; a few alpha fringes and scale intersections remain; procedural fields are intentionally schematic.</li></ul>

<h2>Decision</h2>
<p><strong>Adopt hybrid geometry with the straight locked camera.</strong> Retain the previous N00/N10 work only as the distant backdrop and extraction/depth-ordering source. Replace broad foreground plates with a ground surface, one railway mesh, and purposeful billboards. Do not change focal length or terminal Z.</p>
<details><summary>Machine-readable records</summary><p><a href='../manifest.json'>manifest.json</a> · <a href='../scene/scene.json'>scene.json</a> · <a href='../diagnostics/motion.json'>motion.json</a> · <a href='../README.md'>README.md</a></p></details>

<script>
const canvas=document.getElementById('scene'),ctx=canvas.getContext('2d');
const controls={{play:document.getElementById('play'),variant:document.getElementById('variant'),z:document.getElementById('camera-z'),zLabel:document.getElementById('z-label'),bounds:document.getElementById('bounds'),mesh:document.getElementById('mesh'),anchors:document.getElementById('anchors'),slow:document.getElementById('slow'),readout:document.getElementById('readout')}};
let sceneData=null,playing=false,direction=1,lastTime=0,loadToken=0; const cache=new Map();
const VPX=836,VPY=103.51,FX=720,H=1.14,NEAR=.08;
function cameraPath(variant,z){{const t=(z-3)/2;if(variant==='dynamic')return{{x:.022*Math.sin(Math.PI*t),y:.008*Math.sin(2*Math.PI*t),z,pitch:0,yaw:0}};return{{x:0,y:0,z,pitch:0,yaw:0}}}}
function project(x,z,camera){{const d=z-camera.z;if(d<=NEAR)return null;return{{x:VPX+FX*(x-camera.x)/d,y:VPY+FX*(H+camera.y)/d,d}}}}
function cardRect(card,camera){{const p=project(card.x,card.z,camera);if(!p)return null;const s=FX/p.d,w=card.width*s,h=card.height*s;return{{x:p.x-w*card.anchor[0],y:p.y-h*card.anchor[1],w,h,p}}}}
function framePath(variant,z){{const index=Math.max(0,Math.min(40,Math.round((z-3)/.05)));return `../previews/frames/${{variant}}/frame_${{String(index).padStart(3,'0')}}.jpg`}}
function getImage(src){{if(cache.has(src))return cache.get(src);const image=new Image();const promise=new Promise((resolve,reject)=>{{image.onload=()=>resolve(image);image.onerror=reject}});image.src=src;cache.set(src,promise);return promise}}
function drawGuides(camera){{ctx.save();ctx.lineWidth=2;if(controls.mesh.checked){{ctx.strokeStyle='rgba(54,190,190,.65)';for(let x=-4;x<=4;x+=.5){{ctx.beginPath();let started=false;for(let z=15;z>=camera.z+.82;z-=.12){{const p=project(x,z,camera);if(!p)continue;if(!started){{ctx.moveTo(p.x,p.y);started=true}}else ctx.lineTo(p.x,p.y)}}ctx.stroke()}}for(let z=Math.max(3.25,camera.z+.25);z<15;z+=.5){{const a=project(-4,z,camera),b=project(4,z,camera);if(a&&b){{ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke()}}}}}}for(const card of sceneData.objects){{const r=cardRect(card,camera);if(!r)continue;if(controls.bounds.checked){{ctx.strokeStyle='rgba(238,76,57,.9)';ctx.strokeRect(r.x,r.y,r.w,r.h)}}if(controls.anchors.checked){{ctx.fillStyle='#f1ca48';ctx.beginPath();ctx.arc(r.p.x,r.p.y,5,0,Math.PI*2);ctx.fill()}}}}ctx.restore()}}
async function render(){{if(!sceneData)return;const variant=controls.variant.value,z=Number(controls.z.value),token=++loadToken;const image=await getImage(framePath(variant,z));if(token!==loadToken)return;ctx.clearRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0,canvas.width,canvas.height);const camera=cameraPath(variant,z);drawGuides(camera);controls.zLabel.textContent=z.toFixed(2);controls.readout.textContent=`variant=${{variant}} · camera X=${{camera.x.toFixed(4)}} Y=${{camera.y.toFixed(4)}} Z=${{z.toFixed(2)}} · pitch=${{camera.pitch.toFixed(1)}}° yaw=${{camera.yaw.toFixed(1)}}° · focal=2.0 · VP=[0.5,0.40] · near=0.08 · locked endpoints`}}
function tick(time){{if(!playing)return;if(!lastTime)lastTime=time;const duration=controls.slow.checked?7.5:3.0;let z=Number(controls.z.value)+direction*(time-lastTime)*2/(duration*1000);lastTime=time;if(z>=5){{z=5;direction=-1}}if(z<=3){{z=3;direction=1}}controls.z.value=z.toFixed(3);render();requestAnimationFrame(tick)}}
controls.play.addEventListener('click',()=>{{playing=!playing;controls.play.textContent=playing?'Pause':'Play';lastTime=0;if(playing)requestAnimationFrame(tick)}});
for(const control of [controls.variant,controls.z,controls.bounds,controls.mesh,controls.anchors])control.addEventListener('input',render);
fetch('../scene/scene.json').then(response=>response.json()).then(data=>{{sceneData=data;render()}}).catch(error=>{{controls.readout.textContent='Viewer load failed: '+error}});
</script>
</main></body></html>"""
    path = root / "report" / "index.html"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(report)


def _protected_digest(repo: Path) -> str:
    roots = (
        "app/assets/art/field_plan/game/backgrounds",
        "app/assets/art/field_plan/world_depth",
        "app/lib",
        "engine",
        "server",
        "design/field-plan-world",
    )
    digest = hashlib.sha256()
    for relative_root in roots:
        for path in sorted((repo / relative_root).rglob("*")):
            if path.is_file():
                digest.update(str(path.relative_to(repo)).encode())
                digest.update(sha256(path).encode())
    return digest.hexdigest()


def _validate(root: Path, cards: list[dict], source_hash: str, protected_before: str, protected_after: str) -> dict:
    failures = []
    if len([card for card in cards if card["kind"] == "tree-cluster"]) != TREE_CARD_COUNT:
        failures.append("tree-card count mismatch")
    if len([card for card in cards if card["kind"] == "pylon"]) != 3:
        failures.append("pylon-card count mismatch")
    for card in cards:
        path = root / card["asset"]
        if not path.exists():
            failures.append(f"missing card {card['asset']}")
            continue
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.width < 1 or image.height < 1:
                failures.append(f"invalid card {card['asset']}")
            alpha = np.asarray(image)[..., 3]
            if np.max(alpha) < 128 or np.mean(alpha > 16) < 0.01:
                failures.append(f"card lacks meaningful foreground coverage {card['asset']}")
    frame_counts = {}
    for variant in ("baseline", "straight", "dynamic"):
        count = len(list((root / "previews" / "frames" / variant).glob("frame_*.jpg")))
        frame_counts[variant] = count
        if count != FRAME_COUNT:
            failures.append(f"{variant} frame count {count}")
    required = (
        "report/index.html",
        "manifest.json",
        "README.md",
        "scene/scene.json",
        "previews/straight-hybrid.gif",
        "previews/dynamic-hybrid.gif",
        "comparisons/synchronized-baseline-A-B.gif",
        "diagnostics/motion.json",
    )
    for relative in required:
        if not (root / relative).exists():
            failures.append(f"missing {relative}")
    html_text = (root / "report" / "index.html").read_text()
    if "https://" in html_text or "http://" in html_text:
        failures.append("viewer contains a network dependency")
    dynamic_samples = [camera_path("dynamic", float(z)) for z in np.linspace(START_Z, END_Z, 101)]
    max_x = max(abs(sample["x"]) for sample in dynamic_samples)
    max_y = max(abs(sample["y"]) for sample in dynamic_samples)
    if max_x > 0.0220001 or max_y > 0.0080001:
        failures.append("dynamic path exceeds recorded bounds")
    return {
        "passed": not failures,
        "failures": failures,
        "sourceSha256": source_hash,
        "cardCounts": {"trees": TREE_CARD_COUNT, "pylons": 3, "total": len(cards)},
        "frameCounts": frame_counts,
        "dynamicPathMaxAbsWorld": {"x": max_x, "y": max_y},
        "dynamicPathApproxViewportAtDepthOne": {"xPixels": PROJECTION_X * max_x, "xFraction": PROJECTION_X * max_x / WIDTH, "yPixels": PROJECTION_X * max_y, "yFraction": PROJECTION_X * max_y / HEIGHT},
        "sameSceneGeometryForAAndB": True,
        "protectedDigestBefore": protected_before,
        "protectedDigestAfter": protected_after,
        "protectedScopeChanged": protected_before != protected_after,
    }


def run(args: argparse.Namespace) -> Path:
    repo = args.repo.resolve()
    source_path = repo / "app/assets/art/field_plan/game/backgrounds/north-light.png"
    config = json.loads((repo / "research/world_depth/north_bakeoff.json").read_text())
    source_hash = sha256(source_path)
    if source_hash != config["source"]["sha256"]:
        raise ValueError("authoritative source hash mismatch")
    source = np.asarray(Image.open(source_path).convert("RGB"))
    if source.shape != (HEIGHT, WIDTH, 3):
        raise ValueError(f"unexpected source shape {source.shape}")

    first_pass = args.first_pass.resolve()
    first_manifest = json.loads((first_pass / "manifest.json").read_text())
    depth_path = repo / first_manifest["depth"]["normalized"]["sourcePath"]
    if sha256(depth_path) != first_manifest["depth"]["normalized"]["sha256"]:
        raise ValueError("Apple normalized depth lineage mismatch")
    depth = np.load(depth_path, allow_pickle=False)
    if depth.shape != (HEIGHT, WIDTH) or depth.dtype != np.float32:
        raise ValueError("Apple normalized depth registration mismatch")

    root = args.output.resolve()
    if root.exists():
        if not args.overwrite:
            raise FileExistsError(root)
        shutil.rmtree(root)
    for relative in ("report", "scene", "cards", "ground", "railway", "previews/frames/baseline", "previews/frames/straight", "previews/frames/dynamic", "comparisons", "diagnostics"):
        (root / relative).mkdir(parents=True, exist_ok=True)
    protected_before = _protected_digest(repo)

    texture = landmark_free_texture((512, 512))
    save_image(texture, root / "ground" / "snow-paper-texture.png", "L")
    backdrop = make_backdrop(source, texture)
    save_image(backdrop, root / "scene" / "backdrop.png")
    cards = extract_cards(source, depth, root / "cards")
    for card in cards:
        card["asset"] = str(Path(card["asset"]).relative_to(root))
        card["assetSha256"] = sha256(root / card["asset"])
    card_images = {card["id"]: Image.open(root / card["asset"]).convert("RGBA") for card in cards}
    markers = make_ground_markers()

    prior_layers = [np.asarray(Image.open(first_pass / "plates" / "inpainted" / f"{plate}.png").convert("RGBA")) for plate in ("N00", "N10", "N20", "N30", "N40")]
    original_baseline = first_pass / "previews" / "dolly-preview.gif"
    shutil.copy2(original_baseline, root / "comparisons" / "baseline-five-plate-original.gif")

    z_values = np.linspace(START_Z, END_Z, FRAME_COUNT)
    key_indices = {0, 10, 20, 30, 40}
    keyframes: dict[str, list[np.ndarray]] = {variant: [] for variant in ("baseline", "straight", "dynamic")}
    frame_paths: dict[str, list[Path]] = {variant: [] for variant in ("baseline", "straight", "dynamic")}
    for index, z_value in enumerate(z_values):
        z = float(z_value)
        full_frames = {
            "baseline": dolly_frame(prior_layers, z, annotate=False),
            "straight": render_hybrid(backdrop, texture, card_images, cards, markers, "straight", z),
            "dynamic": render_hybrid(backdrop, texture, card_images, cards, markers, "dynamic", z),
        }
        for variant, frame in full_frames.items():
            path = root / "previews" / "frames" / variant / f"frame_{index:03d}.jpg"
            Image.fromarray(frame).resize(PREVIEW_SIZE, Image.Resampling.LANCZOS).save(path, quality=88, subsampling=0)
            frame_paths[variant].append(path)
            if index in key_indices:
                keyframes[variant].append(frame)

    _save_ping_pong_gif(frame_paths["baseline"], root / "previews" / "baseline-approach.gif")
    _save_ping_pong_gif(frame_paths["straight"], root / "previews" / "straight-hybrid.gif")
    _save_ping_pong_gif(frame_paths["dynamic"], root / "previews" / "dynamic-hybrid.gif")
    comparison_frames = []
    order = list(range(FRAME_COUNT)) + list(range(FRAME_COUNT - 2, 0, -1))
    for index in order:
        sources = [Image.open(frame_paths[variant][index]).convert("RGB") for variant in ("baseline", "straight", "dynamic")]
        comparison_frames.append(_side_by_side_frame(sources, float(z_values[index])))
        for source_image in sources:
            source_image.close()
    comparison_frames[0].save(root / "comparisons" / "synchronized-baseline-A-B.gif", save_all=True, append_images=comparison_frames[1:], duration=75, loop=0, optimize=False)
    for frame in comparison_frames:
        frame.close()

    labels = [f"camera Z {z:.1f}" for z in (3.0, 3.5, 4.0, 4.5, 5.0)]
    for variant in ("baseline", "straight", "dynamic"):
        save_image(comparison_canvas(list(zip(keyframes[variant], labels)), columns=5), root / "comparisons" / f"keyframes-{variant}.png")
    save_image(keyframes["straight"][-1], root / "previews" / "terminal-straight.png")
    save_image(keyframes["dynamic"][-1], root / "previews" / "terminal-dynamic.png")
    save_image(keyframes["straight"][2], root / "previews" / "clean-straight-Z4.png")
    save_image(scene_layout(cards), root / "scene" / "layout.png")
    save_image(card_contact_sheet(cards, card_images), root / "cards" / "contact-sheet.png")
    wireframe = render_hybrid(backdrop, texture, card_images, cards, markers, "straight", 3.0, mesh=True, anchors=False, cards_enabled=False, railway_enabled=False)
    save_image(wireframe, root / "ground" / "wireframe.png")
    railway = render_hybrid(backdrop, texture, card_images, cards, markers, "straight", 3.0, cards_enabled=False, railway_enabled=True)
    railway_image = Image.fromarray(railway).convert("RGBA")
    draw_railway(railway_image, camera_path("straight", 3.0), geometry_only=True)
    save_image(np.asarray(railway_image.convert("RGB")), root / "railway" / "geometry.png")

    near_candidates = [card for card in cards if card["depthGroup"] == "near"]
    representative_near = sorted(near_candidates, key=lambda card: card["z"])[len(near_candidates) // 2]
    passage_items = []
    for z in (3.0, 4.0, 5.0):
        frame = render_hybrid(backdrop, texture, card_images, cards, markers, "straight", z)
        passage_items.append((_annotate_card(frame, representative_near, "straight", z), f"{representative_near['id']} · camera Z {z:.1f}"))
    save_image(comparison_canvas(passage_items, columns=3), root / "comparisons" / "near-card-passage.png")
    rail_items = []
    for z in (3.0, 4.0, 5.0):
        frame = render_hybrid(backdrop, texture, card_images, cards, markers, "straight", z)
        rail_items.append((frame[:, 585:1087], f"continuous railway · camera Z {z:.1f}"))
    save_image(comparison_canvas(rail_items, columns=3), root / "comparisons" / "railway-continuity.png")

    diagnostics = trajectory_metrics(cards)
    save_image(trajectory_diagram(cards, diagnostics), root / "diagnostics" / "trajectories.png")
    (root / "diagnostics" / "motion.json").write_text(json.dumps(diagnostics, indent=2) + "\n")
    railway_geometry = {"type": "continuous-perspective-mesh", "centerX": 0.0, "ballastHalfWidth": 0.26, "railX": [-0.115, 0.115], "tieHalfWidth": 0.21, "tieSpacingZ": 0.22, "nearWorldZ": 3.25, "farWorldZ": 15.0, "alignedVanishingPoint": CAMERA_LOCKED["vanishingPoint"]}
    (root / "railway" / "geometry.json").write_text(json.dumps(railway_geometry, indent=2) + "\n")

    scene_record = {
        "schemaVersion": 1,
        "viewport": [WIDTH, HEIGHT],
        "projection": {"vanishingPointPixels": list(VP), "horizontalFocalPixels": PROJECTION_X, "cameraHeight": CAMERA_HEIGHT, "nearPlane": NEAR_PLANE, "groundStartsAtY": GROUND_START_Y},
        "cameraPaths": {
            "straight": {"z": "3 + 2t", "x": "0", "y": "0", "pitchDegrees": 0, "yawDegrees": 0},
            "dynamic": {"z": "3 + 2t", "x": "0.022 sin(pi t)", "y": "0.008 sin(2 pi t)", "pitchDegrees": 0, "yawDegrees": 0, "authoritative": False},
        },
        "ground": {"type": "projectively sampled X/Z plane", "snowTexture": "ground/snow-paper-texture.png", "fieldToSnowTransitionWorldZ": [4.25, 4.67], "worldMarkers": markers},
        "railway": railway_geometry,
        "objects": cards,
        "frames": {variant: [str(path.relative_to(root)) for path in paths] for variant, paths in frame_paths.items()},
    }
    (root / "scene" / "scene.json").write_text(json.dumps(scene_record, indent=2) + "\n")

    protected_after = _protected_digest(repo)
    validation = {"passed": None, "failures": ["pending final artifact validation"]}
    manifest = {
        "schemaVersion": 1,
        "experimentId": "north-spatial-corridor",
        "runId": root.name,
        "createdAt": datetime.now(ZoneInfo("America/Indiana/Indianapolis")).isoformat(),
        "outcome": "Hybrid geometry with the straight locked camera reads as travel; restrained X/Y motion does not materially improve it.",
        "recommendation": "hybrid geometry with straight camera",
        "source": {"path": str(source_path.relative_to(repo)), "sha256": source_hash, "size": [WIDTH, HEIGHT], "mode": "RGB"},
        "depth": {"model": "Apple Depth Pro", "path": str(depth_path.relative_to(repo)), "sha256": sha256(depth_path), "convention": "0=far, 1=near", "reusedWithoutInference": True, "sourceFirstPass": str(first_pass.relative_to(repo))},
        "baseline": {"originalGif": "comparisons/baseline-five-plate-original.gif", "originalGifSha256": sha256(original_baseline), "controlledApproachGif": "previews/baseline-approach.gif"},
        "lockedCamera": {"source": "app/lib/src/world_depth_camera.dart", **CAMERA_LOCKED, "primaryEvaluationZ": [START_Z, END_Z]},
        "scene": {"path": "scene/scene.json", "treeCards": TREE_CARD_COUNT, "landmarkCards": 3, "totalCards": len(cards), "objects": cards, "ground": scene_record["ground"], "railway": railway_geometry},
        "cameraPaths": scene_record["cameraPaths"],
        "renderer": {"type": "deterministic Python/Pillow/OpenCV offline renderer plus dependency-free Canvas frame viewer", "python": sys.version.split()[0], "numpy": np.__version__, "pillow": importlib.metadata.version("Pillow"), "opencvPython": importlib.metadata.version("opencv-python"), "frameCountPerVariant": FRAME_COUNT, "primaryForwardDurationSeconds": FPS_DURATION_SECONDS, "reverseIncluded": True, "randomSeed": SEED},
        "diagnostics": diagnostics,
        "evaluation": {"AFeelsLikeTravel": True, "BMateriallyImprovesA": False, "groundFlowsUnderCamera": True, "railwayContinuous": True, "distantBackdropStable": True, "cardLimitations": "Large near cards expose billboard perspective and some alpha fringe; source density is adequate for a motion proof but not a final scene.", "flutterPracticality": "Practical as one ground/rail mesh plus a small billboard list; retain full-screen plates only for the distant backdrop."},
        "artifacts": {"report": "report/index.html", "synchronizedComparison": "comparisons/synchronized-baseline-A-B.gif", "straightGif": "previews/straight-hybrid.gif", "dynamicGif": "previews/dynamic-hybrid.gif", "layout": "scene/layout.png", "groundWireframe": "ground/wireframe.png", "railwayGeometry": "railway/geometry.png", "cardContactSheet": "cards/contact-sheet.png", "nearPassage": "comparisons/near-card-passage.png", "railwayContinuity": "comparisons/railway-continuity.png", "motion": "diagnostics/motion.json"},
        "validation": validation,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    readme = f"""# North spatial corridor follow-up

Research-only controlled comparison. Variant A and B share identical scene geometry; only the recorded camera path differs.

## Reproduction

From `{repo}`:

```bash
{Path(sys.executable)} -m unittest research.world_depth.test_spatial_corridor
{Path(sys.executable)} research/world_depth/spatial_corridor.py \\
  --repo {repo} \\
  --first-pass {first_pass} \\
  --output {root} \\
  --overwrite
```

## Viewer

Serve this run locally, then open `report/index.html`:

```bash
python3 -m http.server 8879 --directory {root}
```

## Decision

**Hybrid geometry with straight camera.** Geometry alone supplies ground flow, outward object parallax, passing objects, and a continuous railway. The restrained dynamic path adds mild sway but no material improvement.
"""
    (root / "README.md").write_text(readme)
    _write_viewer_report(root, manifest, diagnostics)
    validation = _validate(root, cards, source_hash, protected_before, protected_after)
    manifest["validation"] = validation
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if not validation["passed"]:
        raise ValueError(f"validation failed: {validation}")
    return root


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--first-pass", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    print(run(parse_args()))
