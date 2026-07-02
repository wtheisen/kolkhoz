from __future__ import annotations

import json
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from .history import CURRENT_EXPERIMENT_PATH, HISTORY_PATH, REPO_ROOT, now_iso


DASHBOARD_DIR = REPO_ROOT / "research/dashboard"


def _read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _read_history(limit: int = 200) -> list[dict[str, Any]]:
    if not HISTORY_PATH.exists():
        return []
    records = []
    try:
        lines = HISTORY_PATH.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    for line in lines[-limit:]:
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def _category(kind: str) -> str:
    if "training" in kind:
        return "training"
    if "benchmark" in kind:
        return "benchmark"
    if kind in {"torch_policy_parity", "policy_tournament", "seed_mining", "engine_smoke"}:
        return "evaluation"
    return "other"


def _model_spec(record: dict[str, Any]) -> dict[str, Any]:
    model = record.get("model") if isinstance(record.get("model"), dict) else {}
    artifact = _artifact_spec(record.get("output_model") or record.get("candidate_model") or record.get("model"))
    architecture = (
        model.get("architecture")
        or record.get("candidate_architecture")
        or artifact.get("architecture")
        or ("mlp" if record.get("backend") == "c-mlp" else None)
        or record.get("backend")
        or "unknown"
    )
    layers = model.get("layers") or record.get("layers") or artifact.get("layers")
    return {
        "architecture": architecture,
        "layers": layers if isinstance(layers, list) else [],
        "backend": record.get("backend") or artifact.get("backend"),
        "device": record.get("device"),
        "output_model": record.get("output_model") or record.get("candidate_model") or record.get("model"),
        "start_model": record.get("start_model"),
        "baseline_model": record.get("baseline_model"),
    }


def _artifact_spec(path_value: Any) -> dict[str, Any]:
    if not path_value or not isinstance(path_value, str) or not path_value.endswith(".json"):
        return {}
    path = (REPO_ROOT / path_value).resolve()
    try:
        path.relative_to(REPO_ROOT)
    except ValueError:
        return {}
    data = _read_json(path)
    if not data:
        return {}
    layers = data.get("hidden_layers") or data.get("layerSizes")
    if not isinstance(layers, list):
        hidden = data.get("hidden_size") or data.get("hiddenSize")
        layers = [hidden] if hidden else []
    return {
        "architecture": "mlp" if data.get("backend", "c-mlp") == "c-mlp" else data.get("backend"),
        "backend": data.get("backend", "c-mlp"),
        "layers": [int(item) for item in layers if item],
    }


def _compact(record: dict[str, Any]) -> dict[str, Any]:
    kind = str(record.get("kind", "unknown"))
    return {
        "timestamp": record.get("recorded_at") or record.get("updated_at"),
        "kind": kind,
        "category": _category(kind),
        "status": record.get("status", "unknown"),
        "phase": record.get("phase"),
        "model": _model_spec(record),
        "training": record.get("training"),
        "progress": record.get("progress"),
        "summary": record.get("summary"),
        "result": record.get("result"),
        "intervals": record.get("intervals"),
        "thresholds": record.get("thresholds"),
        "games_per_seat": record.get("games_per_seat"),
        "total_games": record.get("total_games") or record.get("games"),
        "seed": record.get("seed") or (record.get("training") or {}).get("seed"),
        "engine": record.get("engine"),
    }


def dashboard_payload() -> dict[str, Any]:
    history = [_compact(record) for record in _read_history()]
    current_raw = _read_json(CURRENT_EXPERIMENT_PATH)
    current = _compact(current_raw) if current_raw else (history[-1] if history else None)
    trainings = [record for record in history if record["category"] == "training"]
    benchmarks = [record for record in history if record["category"] == "benchmark"]
    evaluations = [record for record in history if record["category"] == "evaluation"]
    return {
        "generated_at": now_iso(),
        "current": current,
        "history": list(reversed(history[-80:])),
        "trainings": list(reversed(trainings[-30:])),
        "benchmarks": list(reversed(benchmarks[-30:])),
        "evaluations": list(reversed(evaluations[-30:])),
        "counts": {
            "history": len(history),
            "trainings": len(trainings),
            "benchmarks": len(benchmarks),
            "evaluations": len(evaluations),
        },
        "paths": {
            "history": str(HISTORY_PATH.relative_to(REPO_ROOT)),
            "current": str(CURRENT_EXPERIMENT_PATH.relative_to(REPO_ROOT)),
        },
    }


class DashboardHandler(BaseHTTPRequestHandler):
    server_version = "KolkhozResearchDashboard/1.0"

    def do_GET(self) -> None:
        self._handle_request(include_body=True)

    def do_HEAD(self) -> None:
        self._handle_request(include_body=False)

    def _handle_request(self, *, include_body: bool) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/status":
            self._send_json(dashboard_payload(), include_body=include_body)
            return
        if parsed.path == "/":
            self._send_file(DASHBOARD_DIR / "index.html", include_body=include_body)
            return
        requested = (DASHBOARD_DIR / parsed.path.lstrip("/")).resolve()
        try:
            requested.relative_to(DASHBOARD_DIR.resolve())
        except ValueError:
            self.send_error(404)
            return
        self._send_file(requested, include_body=include_body)

    def log_message(self, format: str, *args: Any) -> None:
        print(f"[dashboard] {self.address_string()} - {format % args}")

    def _send_json(self, payload: dict[str, Any], *, include_body: bool) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if include_body:
            self.wfile.write(data)

    def _send_file(self, path: Path, *, include_body: bool) -> None:
        if not path.exists() or not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if include_body:
            self.wfile.write(data)


def serve_dashboard(host: str = "127.0.0.1", port: int = 8765) -> None:
    server = ThreadingHTTPServer((host, port), DashboardHandler)
    print(f"Kolkhoz research dashboard: http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
