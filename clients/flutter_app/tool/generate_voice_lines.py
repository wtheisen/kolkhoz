#!/usr/bin/env python3
"""Generate the complete Russian face-card voice pack for Kolkhoz."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
AUDITION_SCRIPT = Path(__file__).with_name("generate_voice_auditions.py")
KING_FILTER = (
    "asetrate=20160,aresample=24000,atempo=1.190476,"
    "asoftclip=type=tanh:threshold=0.72,"
    "acompressor=threshold=0.12:ratio=3:attack=5:release=60"
)

GROUPS = (
    {
        "id": "worker-jack",
        "voice": "alloy",
        "direction": "An unmistakably male native Russian farm worker about eighteen years old. Boyish, bright, youthful, energetic, proud, and sincere. Each sentence is a separate very short card cue: brisk, natural, and roughly one second long. Keep exactly the same voice and microphone distance throughout. No caricature.",
        "lines": (
            ("jack-wheat", "Хлеб будет!"),
            ("jack-sunflower", "Тянемся к солнцу!"),
            ("jack-potato", "Картошка — второй хлеб!"),
            ("jack-beet", "Свёкла — в амба́р!"),
        ),
    },
    {
        "id": "worker-queen",
        "voice": "coral",
        "direction": "A native Russian woman working on a collective farm. Calm, capable, resolute, practical, and warm, with a grounded contralto feeling. Each sentence is a separate brisk card cue under two seconds. Keep exactly the same voice and microphone distance throughout. Never glamorous or theatrical.",
        "lines": (
            ("queen-wheat", "Каждое зерно пойдёт в дело."),
            ("queen-sunflower", "Солнце даст богатый урожай."),
            ("queen-potato", "Картошку сохраним до весны."),
            ("queen-beet", "Свёкла уродилась на славу."),
        ),
    },
    {
        "id": "worker-king",
        "voice": "ballad",
        "direction": "An ancient native Russian male brigade foreman with an exceptionally deep, harsh, cracked throat-growl: extreme gravel, heavy rasp, and strong vocal fry on every word. Weather-beaten, stern, dependable, and never polished or narrator-like. Bark each sentence as a separate brisk card cue under two seconds. Keep exactly the same voice throughout.",
        "post_filter": KING_FILTER,
        "lines": (
            ("king-wheat", "За хлеб отвечаю лично."),
            ("king-sunflower", "Подсолнух выполнил план."),
            ("king-potato", "Без картошки не останемся."),
            ("king-beet", "Свёкла даст стране сахар."),
        ),
    },
    {
        "id": "nomenklatura-drunkard",
        "voice": "echo",
        "independent": True,
        "direction": "A tired adult Russian man who has had too much vodka. His speech is lazy, thick-tongued, and noticeably slurred, but the words remain intelligible. He sounds sleepy, slack, evasive, and pleased with his excuse. Keep each cue near two seconds, with no long pauses, hiccups, added words, or cartoon voice.",
        "lines": (
            ("nomenklatura-jack-wheat", "За хлеб выпьем. Работать — завтра."),
            ("nomenklatura-jack-sunflower", "Подсолнух сам вырастет. Наливай."),
            ("nomenklatura-jack-potato", "Картошка подождёт. Наливай."),
            ("nomenklatura-jack-beet", "Свёкла подождёт. Вы́пьем."),
        ),
    },
    {
        "id": "nomenklatura-informant",
        "voice": "coral",
        "direction": "One native Russian female bureaucratic informant. Quiet, precise, controlled, crisp, and subtly threatening, with the unnerving implication that she knows everything. Each sentence is a separate brisk card cue under two seconds. Keep exactly the same voice throughout; no theatrical pauses.",
        "lines": (
            ("nomenklatura-queen-wheat", "Доклад о хлебе отправлен."),
            ("nomenklatura-queen-sunflower", "О подсолнухе уже доложено."),
            ("nomenklatura-queen-potato", "Я знаю, кто спрятал картошку."),
            ("nomenklatura-queen-beet", "По свёкле всё записано."),
        ),
    },
    {
        "id": "nomenklatura-party-official",
        "voice": "ballad",
        "independent": True,
        "direction": "One ancient native Russian male Party official with an exceptionally deep, harsh, cracked throat-growl: extreme gravel, heavy rasp, and strong vocal fry. Cold, decorated, menacing, and absolutely certain of his authority; never polished or narrator-like. Bark each sentence as a separate brisk card cue under two seconds. Keep exactly the same voice throughout.",
        "post_filter": KING_FILTER,
        "lines": (
            ("nomenklatura-king-wheat", "Хлеб сдать. Возражения?"),
            ("nomenklatura-king-sunflower", "План подсолнуха утверждён."),
            ("nomenklatura-king-potato", "Картошку изъять. По необходимости."),
            ("nomenklatura-king-beet", "Свёклу сдать. Виновных тоже."),
        ),
    },
)


def load_generator():
    spec = importlib.util.spec_from_file_location("voice_auditions", AUDITION_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load audition generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def api_key_from_file(path: Path) -> str:
    text = path.read_text()
    marker = 'os.environ["OPENAI_API_KEY"] = "'
    return text.split(marker, 1)[1].split('"', 1)[0]


def silence_boundaries(path: Path, count: int) -> list[float]:
    result = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-i", str(path), "-af",
            "silencedetect=noise=-42dB:d=0.38", "-f", "null", "-",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    starts = [float(value) for value in re.findall(r"silence_start: ([0-9.]+)", result.stderr)]
    ends = [float(value) for value in re.findall(r"silence_end: ([0-9.]+)", result.stderr)]
    gaps = sorted(
        ((end - start, (start + end) / 2) for start, end in zip(starts, ends) if start > 0.1),
        reverse=True,
    )
    if len(gaps) < count - 1:
        raise RuntimeError(f"Found only {len(gaps)} usable pauses in {path.name}")
    return sorted(midpoint for _, midpoint in gaps[: count - 1])


def split_group(source: Path, group: dict, output: Path) -> list[dict[str, str]]:
    lines = group["lines"]
    boundaries = silence_boundaries(source, len(lines))
    duration_result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(source)],
        capture_output=True,
        text=True,
        check=True,
    )
    points = [0.0, *boundaries, float(duration_result.stdout.strip())]
    manifest = []
    for index, (clip_id, line) in enumerate(lines):
        target = output / f"{clip_id}.wav"
        filters = []
        if group.get("post_filter"):
            filters.append(group["post_filter"])
        filters.append(
            "silenceremove=start_periods=1:start_duration=0.04:start_threshold=-45dB,"
            "areverse,silenceremove=start_periods=1:start_duration=0.04:"
            "start_threshold=-45dB,areverse"
        )
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error", "-i", str(source),
                "-ss", str(points[index]), "-to", str(points[index + 1]),
                "-af", ",".join(filters), str(target),
            ],
            check=True,
        )
        trim_detected_edge_silence(target)
        manifest.append(
            {"id": clip_id, "file": target.name, "line": line, "character": group["id"]}
        )
    return manifest


def trim_detected_edge_silence(path: Path) -> None:
    duration_result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True,
        text=True,
        check=True,
    )
    duration = float(duration_result.stdout.strip())
    detection = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-i", str(path), "-af",
            "silencedetect=noise=-42dB:d=0.12", "-f", "null", "-",
        ],
        capture_output=True,
        text=True,
        check=False,
    ).stderr
    starts = [float(value) for value in re.findall(r"silence_start: ([0-9.]+)", detection)]
    ends = [float(value) for value in re.findall(r"silence_end: ([0-9.]+)", detection)]
    crop_start = 0.0
    crop_end = duration
    for start, end in zip(starts, ends):
        if start <= 0.05:
            crop_start = max(crop_start, end - 0.03)
        if end >= duration - 0.05:
            crop_end = min(crop_end, start + 0.03)
    if crop_start <= 0.0 and crop_end >= duration:
        return
    trimmed = path.with_suffix(".edge-trimmed.wav")
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(path),
            "-ss", str(crop_start), "-to", str(crop_end), str(trimmed),
        ],
        check=True,
    )
    trimmed.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--key-file", type=Path)
    parser.add_argument("--group", action="append", dest="groups")
    parser.add_argument("--clip", action="append", dest="clips")
    args = parser.parse_args()
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and args.key_file:
        api_key = api_key_from_file(args.key_file)
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not configured")

    args.output.mkdir(parents=True, exist_ok=True)
    generate = load_generator().generate
    unknown = set(args.groups or ()) - {group["id"] for group in GROUPS}
    if unknown:
        raise SystemExit(f"Unknown groups: {', '.join(sorted(unknown))}")
    all_clip_ids = {clip_id for group in GROUPS for clip_id, _ in group["lines"]}
    unknown_clips = set(args.clips or ()) - all_clip_ids
    if unknown_clips:
        raise SystemExit(f"Unknown clips: {', '.join(sorted(unknown_clips))}")
    selected_groups = [group for group in GROUPS if (
        (not args.groups or group["id"] in args.groups)
        and (not args.clips or any(clip_id in args.clips for clip_id, _ in group["lines"]))
    )]
    for group in selected_groups:
        print(f"Generating {group['id']}...")
        if group.get("independent") or args.clips:
            generator = load_generator()
            for clip_id, line in group["lines"]:
                if args.clips and clip_id not in args.clips:
                    continue
                target = args.output / f"{clip_id}.wav"
                item = {
                    "voice": group["voice"],
                    "line": line,
                    "direction": (
                        group["direction"]
                        + " Say only this one Russian line exactly once."
                    ),
                }
                target.write_bytes(generate(api_key, item))
                generator.finish_audio(target, group.get("post_filter"))
                trim_detected_edge_silence(target)
            continue
        combined = args.output / f".{group['id']}-combined.wav"
        spoken_lines = "\n\n".join(line for _, line in group["lines"])
        item = {
            "voice": group["voice"],
            "line": spoken_lines,
            "direction": (
                group["direction"]
                + " Say only the four Russian lines below, in order. Leave about "
                + str(group.get("pause_seconds", 1))
                + " full seconds "
                "of complete silence between lines without announcing or describing the pause."
            ),
        }
        combined.write_bytes(generate(api_key, item))
        split_group(combined, group, args.output)
        combined.unlink()

    auditions = ROOT / "clients/flutter_app/tool/voice_line_auditions"
    for name in ("saboteur-wrench.wav", "saboteur-any-crop.wav"):
        target = args.output / name
        target.write_bytes((auditions / name).read_bytes())
    manifest = [
        {"id": clip_id, "file": f"{clip_id}.wav", "line": line, "character": group["id"]}
        for group in GROUPS
        for clip_id, line in group["lines"]
    ]
    manifest.extend(
        [
            {
                "id": "saboteur-wrench", "file": "saboteur-wrench.wav",
                "line": "Один оборот — и план сорван.", "character": "saboteur",
            },
            {
                "id": "saboteur-any-crop", "file": "saboteur-any-crop.wav",
                "line": "Я подхожу к любой культуре.", "character": "saboteur",
            },
        ]
    )
    (args.output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
