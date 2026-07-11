#!/usr/bin/env python3
"""Generate Russian character-voice auditions for Kolkhoz."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen


AUDITIONS = (
    {
        "id": "worker-jack",
        "voice": "alloy",
        "line": "Хлеб будет!",
        "direction": "A boyish native Russian male farm worker, about eighteen. Bright, youthful, energetic, proud, and sincere. A very quick natural exclamation, completed in about one second. No dramatic pause and no caricature.",
    },
    {
        "id": "worker-queen",
        "voice": "coral",
        "line": "Каждое зерно пойдёт в дело.",
        "direction": "A native Russian woman working on a collective farm. Calm, capable, resolute, and practical. Warm contralto feeling, never glamorous or theatrical. Deliver briskly in under two seconds with no dramatic pauses.",
    },
    {
        "id": "worker-king",
        "voice": "ballad",
        "line": "За хлеб отвечаю лично.",
        "direction": "An ancient native Russian male brigade foreman. Speak in an exceptionally deep, harsh, cracked throat-growl: extreme gravel, heavy rasp, strong vocal fry on every word, almost an animal growl but still intelligible. His lungs and voice are ruined by a lifetime of smoke, cold, and field work. Absolutely no smooth narrator tone. Bark the statement quickly in under two seconds.",
        "post_filter": "asetrate=20160,aresample=24000,atempo=1.190476,asoftclip=type=tanh:threshold=0.72,acompressor=threshold=0.12:ratio=3:attack=5:release=60",
    },
    {
        "id": "nomenklatura-drunkard",
        "voice": "echo",
        "line": "За хлеб выпьем. Работать — завтра.",
        "direction": "A thoroughly drunk native Russian man who contributes no work. Heavy but intelligible slurring: soften consonants, run neighboring words together, and sound thick-tongued, sleepy, slack, evasive, and complacently pleased with the excuse. Compress the entire line into one quick drunken mumble lasting about two seconds, with no lingering pauses. Darkly comic but realistic; no shouting, hiccups, added words, or cartoon voice.",
    },
    {
        "id": "nomenklatura-informant",
        "voice": "coral",
        "line": "Доклад о хлебе отправлен.",
        "direction": "A native Russian female bureaucratic informant. Quiet, precise, controlled, and subtly threatening. Crisp Russian diction. Deliver the whole report briskly in under two seconds, with no dramatic pause. Speak every written word exactly once.",
    },
    {
        "id": "nomenklatura-party-official",
        "voice": "ballad",
        "line": "Хлеб сдать. Возражения?",
        "direction": "An ancient native Russian male Party official with an exceptionally deep, harsh, cracked throat-growl: extreme gravel, heavy rasp, and strong vocal fry on every word. Cold, decorated, and absolutely certain of his authority; stern and menacing, never polished or narrator-like. Bark the order quickly, then make the final question clipped and plainly rhetorical. Speak every written word exactly once.",
        "post_filter": "asetrate=20160,aresample=24000,atempo=1.190476,asoftclip=type=tanh:threshold=0.72,acompressor=threshold=0.12:ratio=3:attack=5:release=60",
    },
    {
        "id": "saboteur-wrench",
        "voice": "echo",
        "line": "Один оборот — и план сорван.",
        "direction": "An unmistakably adult Russian man, but reedy and nasal rather than deep. A gaunt, slimy saboteur with the ingratiating whine of a petty thief and the suppressed sneer of an evil court adviser. Oily, conniving, cowardly, and pleased with his own cleverness. Close-mic and conspiratorial, clearly voiced, never feminine or heroic. Deliver quickly.",
    },
    {
        "id": "saboteur-any-crop",
        "voice": "echo",
        "line": "Я подхожу к любой культуре.",
        "direction": "The same adult Russian male schemer: reedy, nasal, slimy, whining, ingratiating, and conniving, like a petty thief or evil court adviser. Let a smug little sneer leak through the final words. Never feminine or heroic. Stress любой культуре slightly because he can infiltrate every crop suit. Deliver quickly.",
    },
)


def generate(api_key: str, item: dict[str, str]) -> bytes:
    prompt = (
        "Perform exactly the Russian line below. Output speech only: no introduction, "
        "translation, commentary, music, or sound effects. "
        f"Performance direction: {item['direction']}\n"
        f"Line: {item['line']}"
    )
    payload = json.dumps(
        {
            "model": "gpt-audio-1.5",
            "modalities": ["text", "audio"],
            "audio": {"voice": item["voice"], "format": "wav"},
            "messages": [{"role": "user", "content": prompt}],
        }
    ).encode()
    request = Request(
        "https://api.openai.com/v1/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )
    with urlopen(request, timeout=120) as response:
        result = json.load(response)
    return base64.b64decode(result["choices"][0]["message"]["audio"]["data"])


def finish_audio(path: Path, post_filter: str | None = None) -> None:
    trimmed = path.with_suffix(".trimmed.wav")
    filters = []
    if post_filter:
        filters.append(post_filter)
    filters.append(
        "silenceremove=start_periods=1:start_duration=0.04:start_threshold=-45dB,"
        "areverse,silenceremove=start_periods=1:start_duration=0.04:"
        "start_threshold=-45dB,areverse"
    )
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-af",
            ",".join(filters),
            str(trimmed),
        ],
        check=True,
    )
    trimmed.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--key-file", type=Path)
    parser.add_argument("--id", action="append", dest="ids")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and args.key_file:
        text = args.key_file.read_text()
        marker = 'os.environ["OPENAI_API_KEY"] = "'
        api_key = text.split(marker, 1)[1].split('"', 1)[0]
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not configured")

    args.output.mkdir(parents=True, exist_ok=True)
    manifest = []
    selected = [item for item in AUDITIONS if not args.ids or item["id"] in args.ids]
    unknown = set(args.ids or ()) - {item["id"] for item in AUDITIONS}
    if unknown:
        raise SystemExit(f"Unknown audition ids: {', '.join(sorted(unknown))}")
    for item in selected:
        path = args.output / f"{item['id']}.wav"
        print(f"Generating {path.name}...")
        path.write_bytes(generate(api_key, item))
        finish_audio(path, item.get("post_filter"))
        manifest.append({**item, "file": path.name})
    if args.ids:
        manifest = [{**item, "file": f"{item['id']}.wav"} for item in AUDITIONS]
    (args.output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
