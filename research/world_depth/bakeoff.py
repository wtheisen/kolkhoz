#!/usr/bin/env python3
"""North-only monocular-depth bake-off runner.

Model repositories, environments, and weights are supplied explicitly so this file
does not download or vendor third-party code. Generated artifacts belong in the
ignored research/runs/world_depth tree.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import shutil
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


EXPECTED_SIZE = (1672, 941)
PALETTE = np.asarray(
    [
        (45, 64, 89),
        (53, 96, 112),
        (59, 128, 120),
        (92, 155, 111),
        (145, 178, 99),
        (197, 190, 92),
        (226, 179, 85),
        (232, 144, 75),
        (220, 105, 67),
        (190, 73, 69),
        (147, 55, 79),
        (104, 48, 85),
    ],
    dtype=np.uint8,
)


@dataclass(frozen=True)
class Normalization:
    convention: str
    signal: str
    lowPercentile: float
    highPercentile: float
    lowValue: float
    highValue: float
    clippedLowFraction: float
    clippedHighFraction: float


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_source(source: Path, config: dict) -> dict:
    expected = config["source"]
    actual_hash = sha256(source)
    with Image.open(source) as image:
        size = image.size
        mode = image.mode
    if actual_hash != expected["sha256"]:
        raise ValueError(f"source SHA-256 mismatch: {actual_hash} != {expected['sha256']}")
    if size != (expected["width"], expected["height"]):
        raise ValueError(f"source dimensions mismatch: {size}")
    if mode != "RGB":
        raise ValueError(f"source mode mismatch: {mode} != RGB")
    return {"path": str(source), "sha256": actual_hash, "size": list(size), "mode": mode}


def normalize_depth(
    raw: np.ndarray,
    convention: str,
    percentiles: tuple[float, float] = (1.0, 99.0),
) -> tuple[np.ndarray, Normalization]:
    raw = np.asarray(raw, dtype=np.float32)
    while raw.ndim > 2 and 1 in raw.shape:
        raw = np.squeeze(raw, axis=raw.shape.index(1))
    if raw.ndim != 2:
        raise ValueError(f"depth must be HxW, got {raw.shape}")
    if not np.isfinite(raw).all():
        raise ValueError("depth contains NaN or infinity")

    if convention == "near-high":
        signal = raw
        signal_name = "raw (higher is nearer)"
    elif convention == "metric-depth":
        if np.any(raw <= 0):
            raise ValueError("metric depth must be positive")
        signal = np.reciprocal(raw)
        signal_name = "reciprocal metres (inverse depth; higher is nearer)"
    elif convention == "marigold-depth":
        signal = 1.0 - raw
        signal_name = "1 - native relative depth (native 0=near, 1=far)"
    else:
        raise ValueError(f"unknown convention: {convention}")

    low_pct, high_pct = percentiles
    low, high = np.percentile(signal, [low_pct, high_pct])
    if not high > low:
        raise ValueError("depth has no usable range")
    normalized = np.clip((signal - low) / (high - low), 0.0, 1.0).astype(np.float32)
    details = Normalization(
        convention=convention,
        signal=signal_name,
        lowPercentile=low_pct,
        highPercentile=high_pct,
        lowValue=float(low),
        highValue=float(high),
        clippedLowFraction=float(np.mean(signal <= low)),
        clippedHighFraction=float(np.mean(signal >= high)),
    )
    return normalized, details


def quantize_equal_range(depth: np.ndarray, bands: int) -> tuple[np.ndarray, list[float]]:
    if bands < 2:
        raise ValueError("bands must be at least 2")
    labels = np.minimum((np.clip(depth, 0, 1) * bands).astype(np.uint8), bands - 1)
    return labels, np.linspace(0.0, 1.0, bands + 1).tolist()


def quantize_quantile(depth: np.ndarray, bands: int) -> tuple[np.ndarray, list[float]]:
    if bands < 2:
        raise ValueError("bands must be at least 2")
    edges = np.quantile(depth, np.linspace(0.0, 1.0, bands + 1))
    # Put values equal to a repeated minimum threshold in the farthest band.
    labels = np.digitize(depth, edges[1:-1], right=True).astype(np.uint8)
    return labels, edges.tolist()


def boundaries(labels: np.ndarray) -> np.ndarray:
    result = np.zeros(labels.shape, dtype=bool)
    result[:, 1:] |= labels[:, 1:] != labels[:, :-1]
    result[1:, :] |= labels[1:, :] != labels[:-1, :]
    return result


def colorize_continuous(depth: np.ndarray) -> np.ndarray:
    try:
        from matplotlib import colormaps

        return (colormaps["turbo"](depth)[..., :3] * 255).astype(np.uint8)
    except ImportError:
        indices = np.minimum((depth * (len(PALETTE) - 1)).astype(np.uint8), len(PALETTE) - 1)
        return PALETTE[indices]


def colorize_labels(labels: np.ndarray, bands: int) -> np.ndarray:
    indices = np.rint(labels.astype(np.float32) * (len(PALETTE) - 1) / (bands - 1)).astype(np.uint8)
    return PALETTE[indices]


def save_png(array: np.ndarray, path: Path, mode: str | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(array, mode=mode) if mode else Image.fromarray(array)
    image.save(path)


def crop_box(rect: list[float], width: int, height: int) -> tuple[int, int, int, int]:
    x, y, w, h = rect
    return (
        int(round(x * width)),
        int(round(y * height)),
        int(round((x + w) * width)),
        int(round((y + h) * height)),
    )


def title_panel(image: Image.Image, title: str, width: int = 418) -> Image.Image:
    ratio = width / image.width
    body = image.resize((width, max(1, round(image.height * ratio))), Image.Resampling.LANCZOS)
    panel = Image.new("RGB", (width, body.height + 27), (20, 35, 38))
    panel.paste(body, (0, 27))
    ImageDraw.Draw(panel).text((8, 7), title, fill=(245, 231, 193), font=ImageFont.load_default())
    return panel


def grid_image(rows: list[list[tuple[Image.Image, str]]], gap: int = 8) -> Image.Image:
    panels = [[title_panel(image.convert("RGB"), title) for image, title in row] for row in rows]
    row_images: list[Image.Image] = []
    for row in panels:
        height = max(panel.height for panel in row)
        canvas = Image.new("RGB", (sum(p.width for p in row) + gap * (len(row) - 1), height), (11, 21, 23))
        x = 0
        for panel in row:
            canvas.paste(panel, (x, 0))
            x += panel.width + gap
        row_images.append(canvas)
    result = Image.new(
        "RGB",
        (max(row.width for row in row_images), sum(row.height for row in row_images) + gap * (len(row_images) - 1)),
        (11, 21, 23),
    )
    y = 0
    for row in row_images:
        result.paste(row, (0, y))
        y += row.height + gap
    return result


def edge_metrics(source: np.ndarray, depth: np.ndarray, labels: np.ndarray) -> dict:
    gray = source.astype(np.float32).mean(axis=2) / 255.0
    source_gradient = np.hypot(np.diff(gray, axis=1, append=gray[:, -1:]), np.diff(gray, axis=0, append=gray[-1:, :]))
    depth_gradient = np.hypot(
        np.diff(depth, axis=1, append=depth[:, -1:]),
        np.diff(depth, axis=0, append=depth[-1:, :]),
    )
    source_edges = source_gradient >= np.percentile(source_gradient, 85)
    dilated = np.asarray(Image.fromarray(source_edges).filter(ImageFilter.MaxFilter(5)), dtype=bool)
    band_edges = boundaries(labels)
    aligned = float(np.mean(dilated[band_edges])) if np.any(band_edges) else 0.0
    correlation = float(np.corrcoef(source_gradient.ravel(), depth_gradient.ravel())[0, 1])
    return {
        "bandBoundaryFraction": float(np.mean(band_edges)),
        "bandBoundaryAlignedToStrongSourceEdgeFraction": aligned,
        "sourceDepthGradientCorrelation": correlation,
        "normalizedDepthMean": float(np.mean(depth)),
        "normalizedDepthStdDev": float(np.std(depth)),
    }


def make_parallax(
    source: Image.Image,
    labels: np.ndarray,
    output: Path,
    vanishing_point: list[float],
) -> None:
    preview_size = (836, 470)
    source = source.resize(preview_size, Image.Resampling.LANCZOS).convert("RGBA")
    labels_img = Image.fromarray(labels).resize(preview_size, Image.Resampling.NEAREST)
    labels_small = np.asarray(labels_img)
    cx, cy = vanishing_point[0] * preview_size[0], vanishing_point[1] * preview_size[1]
    frames: list[Image.Image] = []
    travel = [0.0, 0.18, 0.36, 0.54, 0.72, 0.9, 0.72, 0.54, 0.36, 0.18]
    for amount in travel:
        canvas = Image.new("RGBA", preview_size, (11, 21, 23, 255))
        for band in range(5):
            alpha = Image.fromarray(np.where(labels_small == band, 255, 0).astype(np.uint8), mode="L")
            layer = source.copy()
            layer.putalpha(alpha)
            scale = 1.0 + amount * 0.035 * band
            inverse = 1.0 / scale
            transform = (inverse, 0.0, cx - cx * inverse, 0.0, inverse, cy - cy * inverse)
            warped = layer.transform(preview_size, Image.Transform.AFFINE, transform, Image.Resampling.BILINEAR)
            canvas.alpha_composite(warped)
        frame = canvas.convert("RGB")
        draw = ImageDraw.Draw(frame)
        draw.rectangle((0, 0, 390, 24), fill=(11, 21, 23))
        draw.text((7, 7), "DIAGNOSTIC ONLY - candidate camera; no inpainting", fill=(225, 184, 77))
        frames.append(frame)
    output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(output, save_all=True, append_images=frames[1:], duration=180, loop=0, optimize=True)


def postprocess(args: argparse.Namespace) -> None:
    config = json.loads(args.config.read_text())
    camera = json.loads(args.camera.read_text())
    source_info = verify_source(args.source, config)
    source_image = Image.open(args.source).convert("RGB")
    source = np.asarray(source_image)
    raw = np.load(args.raw, allow_pickle=False)
    if raw.shape != source.shape[:2]:
        raise ValueError(f"raw depth shape {raw.shape} != source {source.shape[:2]}")

    percentiles = (0.0, 100.0) if args.convention == "marigold-depth" else (1.0, 99.0)
    depth, normalization = normalize_depth(raw, args.convention, percentiles)
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    raw_target = out / "raw_depth.npy"
    if args.raw.resolve() != raw_target.resolve():
        shutil.copy2(args.raw, raw_target)
    np.save(out / "normalized_depth.npy", depth, allow_pickle=False)
    save_png(np.rint(depth * 65535).astype(np.uint16), out / "normalized_depth_u16.png", mode="I;16")
    save_png(colorize_continuous(depth), out / "normalized_depth_color.png")

    comparison = grid_image(
        [[(source_image, "Authoritative source"), (Image.fromarray(colorize_continuous(depth)), f"{args.model_name}: 0 far / 1 near")]]
    )
    comparison.save(out / "source_depth_comparison.png")

    metrics: dict = {"model": args.model_id, "crops": {}}
    quantization_manifest: dict = {}
    equal_five = None
    for method in config["quantization"]["methods"]:
        for bands in config["quantization"]["bandCounts"]:
            labels, edges = (
                quantize_equal_range(depth, bands)
                if method == "equal-range"
                else quantize_quantile(depth, bands)
            )
            stem = f"{method}_{bands:02d}"
            (out / "quantization").mkdir(parents=True, exist_ok=True)
            np.save(out / "quantization" / f"{stem}_labels.npy", labels, allow_pickle=False)
            save_png(colorize_labels(labels, bands), out / "quantization" / f"{stem}_color.png")
            matte_dir = out / "mattes" / stem
            for band in range(bands):
                save_png(
                    np.where(labels == band, 255, 0).astype(np.uint8),
                    matte_dir / f"band_{band:02d}_{'far' if band == 0 else 'near' if band == bands - 1 else 'mid'}.png",
                    mode="L",
                )
            edge = boundaries(labels)
            thick_edge = np.asarray(Image.fromarray(edge).filter(ImageFilter.MaxFilter(3)), dtype=bool)
            overlay = source.copy()
            overlay[thick_edge] = (232, 76, 61)
            save_png(overlay, out / "boundaries" / f"{stem}_overlay.png")
            quantization_manifest[stem] = {"edges": edges, "pixelFractions": [float(np.mean(labels == i)) for i in range(bands)]}
            if method == "equal-range" and bands == 5:
                equal_five = labels
                metrics.update(edge_metrics(source, depth, labels))

    if equal_five is None:
        raise RuntimeError("configuration did not produce equal-range 5 bands")
    make_parallax(source_image, equal_five, out / "parallax" / "diagnostic_equal-range_05.gif", camera["projection"]["vanishingPoint"])

    for crop in config["evaluationCrops"]:
        box = crop_box(crop["rect"], *source_image.size)
        crop_dir = out / "crops" / crop["id"]
        crop_dir.mkdir(parents=True, exist_ok=True)
        artifacts = [
            (source_image.crop(box), "source"),
            (Image.open(out / "normalized_depth_color.png").crop(box), "depth"),
            (Image.open(out / "quantization" / "equal-range_05_color.png").crop(box), "equal 5"),
            (Image.open(out / "quantization" / "quantile_05_color.png").crop(box), "quantile 5"),
            (Image.open(out / "boundaries" / "quantile_08_overlay.png").crop(box), "quantile 8 boundaries"),
        ]
        for image, label in artifacts:
            image.save(crop_dir / f"{label.replace(' ', '_')}.png")
        grid_image([artifacts], gap=5).save(crop_dir / "contact_sheet.png")
        x0, y0, x1, y1 = box
        crop_labels = equal_five[y0:y1, x0:x1]
        crop_source = source[y0:y1, x0:x1]
        crop_depth = depth[y0:y1, x0:x1]
        metrics["crops"][crop["id"]] = {
            "label": crop["label"],
            "pixelRect": list(box),
            **edge_metrics(crop_source, crop_depth, crop_labels),
        }

    metadata = {
        "modelId": args.model_id,
        "modelName": args.model_name,
        "source": source_info,
        "raw": {"path": "raw_depth.npy", "dtype": str(raw.dtype), "shape": list(raw.shape), "minimum": float(raw.min()), "maximum": float(raw.max())},
        "normalized": {"path": "normalized_depth.npy", "dtype": str(depth.dtype), "shape": list(depth.shape), "far": 0.0, "near": 1.0, "transform": asdict(normalization)},
        "quantizations": quantization_manifest,
        "cameraPreview": {"status": camera["status"], "authoritative": False, "vanishingPoint": camera["projection"]["vanishingPoint"]},
        "metrics": metrics,
    }
    (out / "artifact_manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")


def infer_depth_anything(args: argparse.Namespace) -> None:
    import cv2
    import torch

    sys.path.insert(0, str(args.repo))
    from depth_anything_v2.dpt import DepthAnythingV2

    device = torch.device(args.device)
    model = DepthAnythingV2(encoder="vits", features=64, out_channels=[48, 96, 192, 384])
    model.load_state_dict(torch.load(args.checkpoint, map_location="cpu", weights_only=True))
    model = model.to(device).eval()
    image = cv2.imread(str(args.source), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"unable to load {args.source}")
    started = time.perf_counter()
    with torch.inference_mode():
        raw = model.infer_image(image, args.input_size)
    elapsed = time.perf_counter() - started
    args.output.parent.mkdir(parents=True, exist_ok=True)
    np.save(args.output, raw.astype(np.float32), allow_pickle=False)
    print(json.dumps({"device": str(device), "seconds": elapsed, "shape": list(raw.shape), "torch": torch.__version__}))


def infer_depth_pro(args: argparse.Namespace) -> None:
    import torch

    sys.path.insert(0, str(args.repo / "src"))
    import depth_pro
    from depth_pro.depth_pro import DEFAULT_MONODEPTH_CONFIG_DICT, DepthProConfig

    base = DEFAULT_MONODEPTH_CONFIG_DICT
    config = DepthProConfig(
        patch_encoder_preset=base.patch_encoder_preset,
        image_encoder_preset=base.image_encoder_preset,
        decoder_features=base.decoder_features,
        checkpoint_uri=str(args.checkpoint),
        fov_encoder_preset=base.fov_encoder_preset,
        use_fov_head=base.use_fov_head,
    )
    device = torch.device(args.device)
    precision = torch.float16 if device.type == "mps" else torch.float32
    model, transform = depth_pro.create_model_and_transforms(config=config, device=device, precision=precision)
    model.eval()
    image, _, focal = depth_pro.load_rgb(args.source)
    started = time.perf_counter()
    with torch.inference_mode():
        prediction = model.infer(transform(image), f_px=focal)
    elapsed = time.perf_counter() - started
    raw = prediction["depth"].detach().float().cpu().numpy().squeeze()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    np.save(args.output, raw.astype(np.float32), allow_pickle=False)
    focal_out = float(prediction["focallength_px"].detach().float().cpu())
    print(json.dumps({"device": str(device), "precision": str(precision), "seconds": elapsed, "shape": list(raw.shape), "estimatedFocalLengthPx": focal_out, "torch": torch.__version__}))


def infer_marigold(args: argparse.Namespace) -> None:
    import torch

    sys.path.insert(0, str(args.repo))
    from marigold import MarigoldDepthPipeline

    device = torch.device(args.device)
    dtype = torch.float16 if args.half else torch.float32
    pipeline = MarigoldDepthPipeline.from_pretrained(args.checkpoint, torch_dtype=dtype, variant="fp16" if args.half else None)
    pipeline = pipeline.to(device)
    generator = torch.Generator(device=device).manual_seed(args.seed)
    image = Image.open(args.source).convert("RGB")
    started = time.perf_counter()
    with torch.inference_mode():
        prediction = pipeline(
            image,
            ensemble_size=1,
            batch_size=1,
            generator=generator,
            show_progress_bar=True,
            color_map=None,
        )
    elapsed = time.perf_counter() - started
    raw = prediction.depth_np.astype(np.float32)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    np.save(args.output, raw, allow_pickle=False)
    print(json.dumps({"device": str(device), "precision": str(dtype), "seconds": elapsed, "shape": list(raw.shape), "seed": args.seed, "torch": torch.__version__}))


def build_comparison(args: argparse.Namespace) -> None:
    run = args.run_dir
    config = json.loads(args.config.read_text())
    source_path = run / "source.png"
    if not source_path.exists():
        shutil.copy2(Path(config["source"]["path"]), source_path)
    source = Image.open(source_path).convert("RGB")
    model_dirs = [run / "models" / model for model in args.models]
    display_names = [json.loads((path / "artifact_manifest.json").read_text())["modelName"] for path in model_dirs]
    rows = []
    for rel, label in [
        ("normalized_depth_color.png", "normalized depth"),
        ("quantization/equal-range_05_color.png", "equal-range 5"),
        ("quantization/quantile_05_color.png", "quantile 5"),
        ("boundaries/quantile_08_overlay.png", "quantile 8 boundaries"),
    ]:
        rows.append([(source, f"Source - {label}")] + [(Image.open(path / rel), name) for path, name in zip(model_dirs, display_names)])
    comparison_dir = run / "comparison"
    comparison_dir.mkdir(parents=True, exist_ok=True)
    grid_image(rows).save(comparison_dir / "contact_sheet.png")

    for crop in config["evaluationCrops"]:
        rows = [[(Image.open(path / "crops" / crop["id"] / "contact_sheet.png"), name) for path, name in zip(model_dirs, display_names)]]
        grid_image(rows, gap=7).save(comparison_dir / f"crop_{crop['id']}.png")


def validate(args: argparse.Namespace) -> None:
    run = args.run_dir
    failures: list[str] = []
    validated: dict = {"models": {}, "failures": failures}
    with Image.open(run / "source.png") as source:
        if source.size != EXPECTED_SIZE or source.mode != "RGB":
            failures.append(f"run source is {source.size} {source.mode}")
    run_source_hash = sha256(run / "source.png")
    for model in args.models:
        directory = run / "models" / model
        manifest = json.loads((directory / "artifact_manifest.json").read_text())
        raw = np.load(directory / "raw_depth.npy", allow_pickle=False)
        normalized = np.load(directory / "normalized_depth.npy", allow_pickle=False)
        if raw.shape != (EXPECTED_SIZE[1], EXPECTED_SIZE[0]):
            failures.append(f"{model}: raw shape {raw.shape}")
        if normalized.shape != raw.shape or normalized.dtype != np.float32:
            failures.append(f"{model}: normalized {normalized.shape} {normalized.dtype}")
        if not np.isfinite(normalized).all() or normalized.min() < 0 or normalized.max() > 1:
            failures.append(f"{model}: normalized range/finite invalid")
        top_mean = float(np.mean(normalized[: normalized.shape[0] // 10]))
        bottom_mean = float(np.mean(normalized[-normalized.shape[0] // 10 :]))
        if not top_mean < bottom_mean:
            failures.append(f"{model}: expected North top strip to be farther than bottom strip")
        if manifest["source"]["sha256"] != run_source_hash:
            failures.append(f"{model}: run source hash differs from inference source")
        required_modes = {
            "normalized_depth_u16.png": {"I;16", "I"},
            "normalized_depth_color.png": {"RGB"},
            "boundaries/quantile_08_overlay.png": {"RGB"},
            "mattes/equal-range_05/band_00_far.png": {"L"},
        }
        for relative, modes in required_modes.items():
            with Image.open(directory / relative) as image:
                if image.size != EXPECTED_SIZE or image.mode not in modes:
                    failures.append(f"{model}: {relative} is {image.size} {image.mode}")
        matte_partitions = 0
        for method in ("equal-range", "quantile"):
            for bands in (5, 8, 12):
                labels = np.load(directory / "quantization" / f"{method}_{bands:02d}_labels.npy", allow_pickle=False)
                if labels.shape != raw.shape or labels.min() < 0 or labels.max() >= bands:
                    failures.append(f"{model}: invalid {method} {bands}-band labels")
                matte_sum = np.zeros(raw.shape, dtype=np.uint16)
                for matte_path in sorted((directory / "mattes" / f"{method}_{bands:02d}").glob("*.png")):
                    matte = np.asarray(Image.open(matte_path))
                    if matte.shape != raw.shape or not np.isin(matte, (0, 255)).all():
                        failures.append(f"{model}: invalid matte {matte_path.name}")
                    matte_sum += matte
                if not np.all(matte_sum == 255):
                    failures.append(f"{model}: {method} {bands}-band mattes do not partition every pixel")
                matte_partitions += 1
        png_count = 0
        for path in directory.rglob("*.png"):
            with Image.open(path) as image:
                png_count += 1
                if "crops" not in path.parts and image.size != EXPECTED_SIZE and path.name != "source_depth_comparison.png":
                    failures.append(f"{model}: unexpected dimensions {path.relative_to(directory)} {image.size}")
        validated["models"][model] = {
            "raw": {"shape": list(raw.shape), "dtype": str(raw.dtype)},
            "normalized": {"shape": list(normalized.shape), "dtype": str(normalized.dtype), "minimum": float(normalized.min()), "maximum": float(normalized.max())},
            "pngCount": png_count,
            "depthConvention": manifest["normalized"]["far"] == 0.0 and manifest["normalized"]["near"] == 1.0,
            "orientation": {"sourceCoordinates": "top-left, unchanged", "topStripMean": top_mean, "bottomStripMean": bottom_mean, "topFartherThanBottom": top_mean < bottom_mean},
            "channelChecks": {"normalized16": "single-channel 16-bit", "visualizations": "RGB", "mattes": "single-channel binary alpha"},
            "mattePartitionsChecked": matte_partitions,
        }
    validated["passed"] = not failures
    (run / "validation.json").write_text(json.dumps(validated, indent=2) + "\n")
    print(json.dumps(validated, indent=2))
    if failures:
        raise SystemExit(1)


def build_report(args: argparse.Namespace) -> None:
    run = args.run_dir
    summary = json.loads(args.summary.read_text())
    template = args.template.read_text()
    shutil.copy2(args.source, run / "source.png")
    rows = []
    for model in summary["models"]:
        model_id = model["id"]
        rows.append(
            "<tr>"
            f"<td>{html.escape(model['name'])}</td><td>{html.escape(model['status'])}</td>"
            f"<td>{html.escape(model.get('device', ''))}</td><td>{html.escape(model.get('assessment', ''))}</td>"
            f"<td><code>{html.escape(model.get('repositoryRevision', ''))}</code></td>"
            f"<td>{html.escape(model.get('codeLicense', ''))}<br>{html.escape(model.get('weightLicense', ''))}</td>"
            "</tr>"
        )
    evidence = "".join(
        f"<article class='report-card'><h3>{html.escape(item['title'])}</h3><img loading='lazy' src='{html.escape(item['path'])}' alt='{html.escape(item['title'])}'><p>{html.escape(item['caption'])}</p></article>"
        for item in summary["evidence"]
    )
    report = f"""
    <section class="panel report-section">
      <h2>Decision</h2>
      <p><code>{html.escape(summary['decision'])}</code> — {html.escape(summary['outcome'])}</p>
      <p><strong>Best model:</strong> {html.escape(summary['bestModel'])}. {html.escape(summary['bestModelWhy'])}</p>
    </section>
    <section class="panel report-section">
      <h2>Model comparison</h2>
      <div class="table-scroll"><table><thead><tr><th>Model</th><th>Status</th><th>Device</th><th>Manual cleanup</th><th>Repository revision</th><th>Licenses: code / weights</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>
    </section>
    <section class="panel report-section">
      <h2>Representative evidence</h2>
      <div class="report-grid">{evidence}</div>
    </section>
    <section class="panel report-section">
      <h2>Reproduction and verification</h2>
      <p><a href="reproduce.sh">Exact reproduction script</a> · <a href="run_manifest.json">run manifest</a> · <a href="validation.json">validation results</a> · <a href="summary.json">assessment JSON</a></p>
      <p>Source SHA-256: <code>{html.escape(summary['sourceSha256'])}</code>. The camera preview is diagnostic and non-authoritative because the camera contract is <code>candidate</code>.</p>
    </section>
    """
    extra_css = """
    <style>
      .report-section { margin-top: 18px; }
      .report-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(310px,1fr)); gap:14px; }
      .report-card { background:var(--panel-2); border-radius:9px; padding:12px; }
      .report-card img { width:100%; height:auto; border:1px solid var(--line); }
      .table-scroll { overflow-x:auto; }
      table { width:100%; border-collapse:collapse; }
      th, td { text-align:left; vertical-align:top; padding:9px; border-bottom:1px solid var(--line); }
    </style>
    """
    auto_script = f"""
    <script>
      const availableRunModels = {json.dumps([model['id'] for model in summary['models'] if model['status'] == 'success'])};
      function loadRunArtifact() {{
        if (!availableRunModels.includes(state.model)) state.model = availableRunModels[0];
        const stem = `${{state.method}}_${{String(state.bands).padStart(2, '0')}}`;
        let path = `models/${{state.model}}/quantization/${{stem}}_color.png`;
        if (state.preset === 'depth') path = `models/${{state.model}}/normalized_depth_color.png`;
        if (state.preset === 'edges' || state.view === 'overlay') path = `models/${{state.model}}/boundaries/${{stem}}_overlay.png`;
        if (state.preset === 'parallax') path = `models/${{state.model}}/parallax/diagnostic_equal-range_05.gif`;
        elements.resultImage.src = path;
        state.resultName = path;
        elements.empty.hidden = true;
        render();
      }}
      ['model','bands','method','view'].forEach(id => elements[id].addEventListener('change', loadRunArtifact));
      elements.presets.addEventListener('click', () => setTimeout(loadRunArtifact, 0));
      elements.sourceImage.src = 'source.png';
      loadRunArtifact();
    </script>
    """
    populated = template.replace(
        'src="../../../app/assets/art/field_plan/game/backgrounds/north-light.png"',
        'src="source.png"',
    )
    populated = populated.replace("</head>", extra_css + "</head>")
    populated = populated.replace("</main>", report + "</main>")
    populated = populated.replace("</body>", auto_script + "</body>")
    (run / "index.html").write_text(populated)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)

    verify = sub.add_parser("verify-source")
    verify.add_argument("--source", type=Path, required=True)
    verify.add_argument("--config", type=Path, required=True)
    verify.set_defaults(func=lambda args: print(json.dumps(verify_source(args.source, json.loads(args.config.read_text())), indent=2)))

    da = sub.add_parser("infer-depth-anything")
    da.add_argument("--repo", type=Path, required=True)
    da.add_argument("--checkpoint", type=Path, required=True)
    da.add_argument("--source", type=Path, required=True)
    da.add_argument("--output", type=Path, required=True)
    da.add_argument("--device", choices=("mps", "cpu"), default="mps")
    da.add_argument("--input-size", type=int, default=518)
    da.set_defaults(func=infer_depth_anything)

    depth_pro = sub.add_parser("infer-depth-pro")
    depth_pro.add_argument("--repo", type=Path, required=True)
    depth_pro.add_argument("--checkpoint", type=Path, required=True)
    depth_pro.add_argument("--source", type=Path, required=True)
    depth_pro.add_argument("--output", type=Path, required=True)
    depth_pro.add_argument("--device", choices=("mps", "cpu"), default="mps")
    depth_pro.set_defaults(func=infer_depth_pro)

    marigold = sub.add_parser("infer-marigold")
    marigold.add_argument("--repo", type=Path, required=True)
    marigold.add_argument("--checkpoint", type=Path, required=True)
    marigold.add_argument("--source", type=Path, required=True)
    marigold.add_argument("--output", type=Path, required=True)
    marigold.add_argument("--device", choices=("mps", "cpu"), default="mps")
    marigold.add_argument("--seed", type=int, default=20260715)
    marigold.add_argument("--half", action="store_true")
    marigold.set_defaults(func=infer_marigold)

    process = sub.add_parser("postprocess")
    process.add_argument("--model-id", required=True)
    process.add_argument("--model-name", required=True)
    process.add_argument("--convention", choices=("near-high", "metric-depth", "marigold-depth"), required=True)
    process.add_argument("--raw", type=Path, required=True)
    process.add_argument("--source", type=Path, required=True)
    process.add_argument("--config", type=Path, required=True)
    process.add_argument("--camera", type=Path, required=True)
    process.add_argument("--output", type=Path, required=True)
    process.set_defaults(func=postprocess)

    compare = sub.add_parser("compare")
    compare.add_argument("--run-dir", type=Path, required=True)
    compare.add_argument("--config", type=Path, required=True)
    compare.add_argument("--models", nargs="+", required=True)
    compare.set_defaults(func=build_comparison)

    check = sub.add_parser("validate")
    check.add_argument("--run-dir", type=Path, required=True)
    check.add_argument("--models", nargs="+", required=True)
    check.set_defaults(func=validate)

    report = sub.add_parser("report")
    report.add_argument("--run-dir", type=Path, required=True)
    report.add_argument("--template", type=Path, required=True)
    report.add_argument("--summary", type=Path, required=True)
    report.add_argument("--source", type=Path, required=True)
    report.set_defaults(func=build_report)
    return result


if __name__ == "__main__":
    arguments = parser().parse_args()
    arguments.func(arguments)
