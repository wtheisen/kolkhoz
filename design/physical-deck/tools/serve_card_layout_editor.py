#!/usr/bin/env python3
"""Serve the card editor and atomically sync its layouts into Flutter assets."""

from __future__ import annotations

import argparse
import json
import os
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from tempfile import NamedTemporaryFile


REPO_ROOT = Path(__file__).resolve().parents[3]
FLUTTER_LAYOUT_PATH = (
    REPO_ROOT
    / "app/assets/art/field_plan/cards/physical-deck-layout-v16.json"
)
SYNC_PATH = "/api/card-layout"
MAX_REQUEST_BYTES = 4 * 1024 * 1024


def validate_layout(payload: object) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("layout payload must be a JSON object")
    if payload.get("version") != 16:
        raise ValueError("layout payload must use version 16")
    canvas = payload.get("canvas")
    if canvas != {"width": 1644, "height": 2244}:
        raise ValueError("layout payload has the wrong canvas dimensions")
    layouts = payload.get("layouts")
    if not isinstance(layouts, dict) or not layouts:
        raise ValueError("layout payload must contain card layouts")
    return payload


def write_layout(payload: dict) -> None:
    FLUTTER_LAYOUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=FLUTTER_LAYOUT_PATH.parent,
        prefix=f".{FLUTTER_LAYOUT_PATH.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        json.dump(payload, temporary, ensure_ascii=False, indent=2)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, FLUTTER_LAYOUT_PATH)


class CardLayoutEditorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPO_ROOT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_POST(self) -> None:
        if self.path != SYNC_PATH:
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > MAX_REQUEST_BYTES:
                raise ValueError("invalid request size")
            payload = validate_layout(json.loads(self.rfile.read(length)))
            write_layout(payload)
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(error)})
            return

        self.send_json(
            HTTPStatus.OK,
            {"ok": True, "path": str(FLUTTER_LAYOUT_PATH.relative_to(REPO_ROOT))},
        )

    def send_json(self, status: HTTPStatus, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), CardLayoutEditorHandler)
    editor_url = (
        f"http://{args.host}:{args.port}"
        "/design/physical-deck/tools/card-layout-editor.html"
    )
    print(f"Card layout editor: {editor_url}", flush=True)
    print(
        f"Auto-sync target: {FLUTTER_LAYOUT_PATH.relative_to(REPO_ROOT)}",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
