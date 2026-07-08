from __future__ import annotations

import base64
import hashlib
import hmac
import html
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, quote, urlparse
from datetime import datetime, timezone

from .history import CURRENT_EXPERIMENT_PATH, HISTORY_PATH, REPO_ROOT, STATE_ROOT, now_iso


DASHBOARD_DIR = REPO_ROOT / "research/dashboard"
RUNNING_STALE_SECONDS = 180


def _allowed_data_roots() -> list[Path]:
    roots = [REPO_ROOT, STATE_ROOT]
    run_root = os.environ.get("KOLKHOZ_RESEARCH_RUN_ROOT")
    if run_root:
        roots.append(Path(run_root).expanduser())
    resolved: list[Path] = []
    for root in roots:
        try:
            path = root.resolve()
        except OSError:
            continue
        if path not in resolved:
            resolved.append(path)
    return resolved


def _resolve_data_path(path_value: Any) -> Path | None:
    if not path_value or not isinstance(path_value, str):
        return None
    path = Path(path_value).expanduser()
    if not path.is_absolute():
        path = REPO_ROOT / path
    try:
        resolved = path.resolve()
    except OSError:
        return None
    for root in _allowed_data_roots():
        try:
            resolved.relative_to(root)
            return resolved
        except ValueError:
            continue
    return None


def _read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _read_linked_json(path_value: Any) -> dict[str, Any] | None:
    path = _resolve_data_path(path_value)
    if path is None:
        return None
    return _read_json(path)


def _repo_path(path_value: Any) -> Path | None:
    return _resolve_data_path(path_value)


def _repo_relative(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(REPO_ROOT))
    except ValueError:
        return str(resolved)


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


def _parse_iso(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _pid_alive(pid: Any) -> bool | None:
    try:
        value = int(pid)
    except (TypeError, ValueError):
        return None
    if value <= 0:
        return False
    try:
        os.kill(value, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _with_liveness(record: dict[str, Any] | None) -> dict[str, Any] | None:
    if not record:
        return record
    status = str(record.get("status", "unknown"))
    heartbeat = _parse_iso(record.get("heartbeat_at") or record.get("updated_at"))
    age_seconds = None
    if heartbeat is not None:
        age_seconds = max(0.0, (datetime.now(timezone.utc) - heartbeat).total_seconds())
    alive = _pid_alive(record.get("pid"))
    liveness = {
        "pid": record.get("pid"),
        "heartbeat_at": record.get("heartbeat_at"),
        "heartbeat_age_seconds": age_seconds,
        "process_alive": alive,
        "stale_after_seconds": RUNNING_STALE_SECONDS,
    }
    if status == "running" and (
        alive is False
        or (age_seconds is not None and age_seconds > RUNNING_STALE_SECONDS)
    ):
        reason = "process_exited" if alive is False else "heartbeat_stale"
        return {
            **record,
            "status": "stale",
            "previous_status": status,
            "liveness": {**liveness, "stale_reason": reason},
        }
    return {**record, "liveness": liveness}


def _category(kind: str) -> str:
    if kind in {"self_play_improvement_loop", "self_play_seed_pool"}:
        return "training"
    if kind == "self_play_improvement_generation":
        return "benchmark"
    if "training" in kind:
        return "training"
    if "benchmark" in kind:
        return "benchmark"
    if kind in {
        "torch_policy_parity",
        "policy_tournament",
        "seed_mining",
        "engine_smoke",
    }:
        return "evaluation"
    return "other"


def _model_spec(record: dict[str, Any]) -> dict[str, Any]:
    model = record.get("model") if isinstance(record.get("model"), dict) else {}
    artifact = _artifact_spec(
        record.get("output_model")
        or record.get("candidate_model")
        or record.get("best_model")
        or record.get("current_best_model")
        or record.get("model")
    )
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
        "hidden_size": model.get("hidden_size") or record.get("hidden_size"),
        "layer_count": model.get("layer_count") or record.get("layer_count"),
        "head_count": model.get("head_count") or record.get("head_count"),
        "context_length": model.get("context_length") or record.get("context_length"),
        "action_encoding": model.get("action_encoding") or record.get("action_encoding"),
        "backend": record.get("backend") or artifact.get("backend"),
        "device": record.get("device"),
        "output_model": record.get("output_model")
        or record.get("candidate_model")
        or record.get("best_model")
        or record.get("current_best_model")
        or record.get("model"),
        "start_model": record.get("start_model"),
        "baseline_model": record.get("baseline_model")
        or record.get("current_best_model"),
    }


def _artifact_spec(path_value: Any) -> dict[str, Any]:
    if (
        not path_value
        or not isinstance(path_value, str)
        or not path_value.endswith(".json")
    ):
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
        "architecture": "mlp"
        if data.get("backend", "c-mlp") == "c-mlp"
        else data.get("backend"),
        "backend": data.get("backend", "c-mlp"),
        "layers": [int(item) for item in layers if item],
    }


def _read_launch_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return values
    for line in lines:
        key, separator, value = line.partition("=")
        if separator and key:
            values[key] = value
    return values


def _interval_mean(record: dict[str, Any] | None, key: str) -> float | None:
    if not record:
        return None
    interval = (record.get("intervals") or {}).get(key)
    if not isinstance(interval, dict):
        return None
    value = interval.get("mean")
    return float(value) if isinstance(value, (int, float)) else None


def _compact_pool_benchmark(record: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(record, dict):
        return None
    return {
        "path": record.get("path") or record.get("benchmark_record"),
        "status": record.get("status") or record.get("benchmark_status"),
        "baseline_model": record.get("baseline_model"),
        "games_per_seat": record.get("games_per_seat"),
        "total_games": record.get("total_games"),
        "summary": record.get("summary"),
        "intervals": record.get("intervals"),
        "win_delta": record.get("win_delta")
        if isinstance(record.get("win_delta"), (int, float))
        else _interval_mean(record, "win_delta"),
        "rank_delta": record.get("rank_delta")
        if isinstance(record.get("rank_delta"), (int, float))
        else _interval_mean(record, "rank_delta"),
        "margin_delta": record.get("margin_delta")
        if isinstance(record.get("margin_delta"), (int, float))
        else _interval_mean(record, "margin_delta"),
        "utility_delta": record.get("utility_delta")
        if isinstance(record.get("utility_delta"), (int, float))
        else _interval_mean(record, "utility_delta"),
        "promotion_eligible": record.get("promotion_eligible"),
    }


def _compact_model_pool(record: dict[str, Any]) -> list[dict[str, Any]]:
    if record.get("kind") != "self_play_seed_pool":
        return []
    generations = record.get("generations")
    if not isinstance(generations, list):
        return []
    promotion_by_generation = {
        int(item.get("generation")): item
        for item in record.get("promotion_records", []) or []
        if isinstance(item, dict) and isinstance(item.get("generation"), (int, float))
    }
    pool = []
    for item in generations:
        if not isinstance(item, dict):
            continue
        generation = item.get("generation")
        promotion = (
            promotion_by_generation.get(int(generation))
            if isinstance(generation, (int, float))
            else None
        )
        selection = _compact_pool_benchmark(
            _read_linked_json(item.get("selection_record") or item.get("benchmark_record"))
        ) or _compact_pool_benchmark(item)
        if selection and not selection.get("path"):
            selection["path"] = item.get("selection_record") or item.get("benchmark_record")
        current_best = _compact_pool_benchmark((promotion or {}).get("promotion_current_best"))
        arena_records = [
            compact
            for compact in (
                _compact_pool_benchmark(arena)
                for arena in ((promotion or {}).get("arena_records") or [])
                if isinstance(arena, dict)
            )
            if compact
        ]
        pool.append(
            {
                "generation": generation,
                "seed": item.get("seed"),
                "eval_seed": item.get("eval_seed"),
                "candidate_model": item.get("candidate_model"),
                "benchmark_status": item.get("benchmark_status"),
                "selection_record": item.get("selection_record") or item.get("benchmark_record"),
                "selection_score": item.get("selection_score"),
                "selection": selection,
                "finalist": bool(promotion),
                "promotion_eligible": (promotion or {}).get("promotion_eligible"),
                "promoted": (promotion or item).get("promoted"),
                "arena_score": (promotion or {}).get("arena_score"),
                "arena_mean_win_delta": (promotion or {}).get("arena_mean_win_delta"),
                "worst_arena_win_delta": (promotion or {}).get("worst_arena_win_delta"),
                "complete_arena": (promotion or {}).get("complete_arena"),
                "promotion_current_best": current_best,
                "arena_records": arena_records,
            }
        )
    return pool


def _pool_record_for_child(record: dict[str, Any]) -> dict[str, Any] | None:
    run_dir = _repo_path(record.get("run_dir"))
    if not run_dir or not run_dir.name.startswith("seed_"):
        return None
    parent = run_dir.parent
    if not parent.name or not parent.parent.name.startswith("torch_mlp_self_play_seed_pool"):
        return None
    launch = _read_launch_values(parent / "launch.txt")
    seed_dirs = sorted(
        path
        for path in parent.glob("seed_[0-9][0-9][0-9]")
        if path.is_dir()
    )
    pool_size = int(launch.get("POOL_SIZE") or len(seed_dirs) or 0)
    if pool_size <= 0:
        return None

    generations = []
    for index in range(1, pool_size + 1):
        seed_dir = parent / f"seed_{index:03d}"
        summary = _read_json(seed_dir / "self_play_improvement.json") or {}
        child_generations = summary.get("generations")
        child = (
            child_generations[0]
            if isinstance(child_generations, list)
            and child_generations
            and isinstance(child_generations[0], dict)
            else {}
        )
        selection_path = seed_dir / "generation_001" / "benchmark.json"
        selection = _read_json(selection_path)
        eval_seed = None
        if launch.get("EVAL_SEED") and launch.get("SEED_STRIDE"):
            eval_seed = int(launch["EVAL_SEED"]) + (index - 1) * int(launch["SEED_STRIDE"])
        generations.append(
            {
                "generation": index,
                "seed_run_dir": _repo_relative(seed_dir),
                "seed": child.get("seed"),
                "eval_seed": eval_seed,
                "candidate_model": child.get("candidate_model")
                or (selection or {}).get("candidate_model"),
                "training_record": child.get("training_record"),
                "selection_record": _repo_relative(selection_path)
                if selection_path.exists()
                else None,
                "benchmark_record": _repo_relative(selection_path)
                if selection_path.exists()
                else None,
                "benchmark_status": (selection or {}).get("status")
                or child.get("benchmark_status"),
                "summary": (selection or {}).get("summary") or child.get("summary"),
                "intervals": (selection or {}).get("intervals") or child.get("intervals"),
                "promoted": False,
            }
        )

    promotion_records = []
    for finalist_dir in sorted(parent.glob("finalist_[0-9][0-9][0-9]")):
        if not finalist_dir.is_dir():
            continue
        try:
            generation = int(finalist_dir.name.split("_", 1)[1])
        except (IndexError, ValueError):
            continue
        source = next(
            (item for item in generations if item.get("generation") == generation),
            {},
        )
        current_best = _compact_pool_benchmark(
            _read_json(finalist_dir / "promotion_current_best.json")
        )
        arena_records = [
            compact
            for compact in (
                _compact_pool_benchmark(_read_json(path))
                for path in sorted(finalist_dir.glob("arena_*.json"))
            )
            if compact
        ]
        promotion_records.append(
            {
                **source,
                "promotion_current_best": current_best,
                "arena_records": arena_records,
                "promotion_eligible": bool(
                    current_best and current_best.get("promotion_eligible")
                ),
                "promoted": False,
            }
        )

    completed = sum(1 for item in generations if item.get("selection_record"))
    return {
        "kind": "self_play_seed_pool",
        "status": record.get("status"),
        "phase": record.get("phase"),
        "run_dir": _repo_relative(parent),
        "requested_generations": pool_size,
        "completed_generations": completed,
        "promoted_count": 0,
        "generations": generations,
        "promotion_records": promotion_records,
    }


def _compact(record: dict[str, Any]) -> dict[str, Any]:
    kind = str(record.get("kind", "unknown"))
    generations = record.get("generations") if isinstance(record.get("generations"), list) else []
    latest_generation = record.get("latest_generation")
    if not isinstance(latest_generation, dict) and generations:
        latest_generation = generations[-1] if isinstance(generations[-1], dict) else None
    summary = record.get("summary")
    if summary is None and isinstance(latest_generation, dict):
        summary = latest_generation.get("summary")
    if summary is None and isinstance(record.get("latest_point"), dict):
        latest_point = record["latest_point"]
        summary = {
            **latest_point,
            "average_action_count": latest_point.get("actions"),
        }
    latest_generation_training = None
    latest_generation_benchmark = None
    if kind in {"self_play_improvement_loop", "self_play_seed_pool"} and isinstance(latest_generation, dict):
        training_record = _read_linked_json(latest_generation.get("training_record"))
        benchmark_record = _read_linked_json(latest_generation.get("benchmark_record"))
        if training_record:
            latest_generation_training = _compact(training_record)
        if benchmark_record:
            latest_generation_benchmark = _compact(benchmark_record)
    status = record.get("status") or record.get("benchmark_status") or "unknown"
    training = record.get("training")
    if isinstance(training, dict) and not training.get("eval_interval"):
        eval_episodes = sorted(
            {
                int(item.get("completed_episodes", 0))
                for item in record.get("evaluations", []) or []
                if isinstance(item, dict)
                and int(item.get("completed_episodes", 0) or 0) > 0
            }
        )
        if len(eval_episodes) > 1:
            deltas = [
                right - left
                for left, right in zip(eval_episodes, eval_episodes[1:])
                if right > left
            ]
            if deltas:
                training = {
                    **training,
                    "eval_interval": min(deltas),
                    "eval_interval_source": "inferred",
                }
        elif eval_episodes:
            training = {
                **training,
                "eval_interval": eval_episodes[0],
                "eval_interval_source": "inferred",
            }
    selected_evaluation = record.get("selected_evaluation")
    generation_latest_evaluation = None
    if latest_generation_training:
        selected_evaluation = selected_evaluation or latest_generation_training.get(
            "selected_evaluation"
        )
        generation_latest_evaluation = latest_generation_training.get("latest_evaluation")
    return {
        "timestamp": record.get("recorded_at") or record.get("updated_at"),
        "kind": kind,
        "category": _category(kind),
        "status": status,
        "phase": record.get("phase"),
        "model": _model_spec(record),
        "training": training,
        "progress": record.get("progress"),
        "curve": record.get("curve"),
        "points": record.get("points"),
        "latest_point": record.get("latest_point"),
        "updates": record.get("updates"),
        "evaluations": record.get("evaluations"),
        "latest_evaluation": record.get("latest_evaluation"),
        "selected_evaluation": selected_evaluation,
        "generation_latest_evaluation": generation_latest_evaluation,
        "summary": summary,
        "result": record.get("result"),
        "intervals": record.get("intervals"),
        "distribution": record.get("distribution"),
        "thresholds": record.get("thresholds"),
        "evidence": record.get("evidence"),
        "generations": generations[-12:],
        "latest_generation": latest_generation,
        "latest_generation_training": latest_generation_training,
        "latest_generation_benchmark": latest_generation_benchmark,
        "completed_generations": record.get("completed_generations"),
        "requested_generations": record.get("requested_generations"),
        "promoted_count": record.get("promoted_count"),
        "finalists": record.get("finalists"),
        "promotion_records": record.get("promotion_records"),
        "model_pool": _compact_model_pool(record),
        "best_candidate": record.get("best_candidate"),
        "stopped_reason": record.get("stopped_reason"),
        "run_dir": record.get("run_dir"),
        "best_model": record.get("best_model"),
        "current_best_model": record.get("current_best_model"),
        "candidate_model": record.get("candidate_model"),
        "benchmark_status": record.get("benchmark_status"),
        "promoted": record.get("promoted"),
        "games_per_seat": record.get("games_per_seat"),
        "total_games": record.get("total_games") or record.get("games"),
        "seed": record.get("seed") or (record.get("training") or {}).get("seed"),
        "engine": record.get("engine"),
    }


def dashboard_payload() -> dict[str, Any]:
    history = [_compact(record) for record in _read_history()]
    current_raw = _with_liveness(_read_json(CURRENT_EXPERIMENT_PATH))
    current = (
        _compact(current_raw) if current_raw else (history[-1] if history else None)
    )
    if current_raw and current and not current.get("model_pool"):
        parent_pool = _pool_record_for_child(current_raw)
        if parent_pool:
            current["model_pool"] = _compact_model_pool(parent_pool)
            current["pool_parent"] = {
                "run_dir": parent_pool.get("run_dir"),
                "completed_generations": parent_pool.get("completed_generations"),
                "requested_generations": parent_pool.get("requested_generations"),
            }
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
            "history": _repo_relative(HISTORY_PATH),
            "current": _repo_relative(CURRENT_EXPERIMENT_PATH),
        },
    }


class DashboardHandler(BaseHTTPRequestHandler):
    server_version = "KolkhozResearchDashboard/1.0"
    session_cookie_name = "kolkhoz_dashboard_session"

    def do_GET(self) -> None:
        self._handle_request(include_body=True)

    def do_HEAD(self) -> None:
        self._handle_request(include_body=False)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/login":
            self._handle_login()
            return
        self.send_error(404)

    def _handle_request(self, *, include_body: bool) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/login":
            if self._is_authorized():
                self._send_redirect("/", include_body=include_body)
                return
            self._send_login_page(
                include_body=include_body, failed="error=1" in parsed.query
            )
            return

        if not self._is_authorized():
            if parsed.path == "/api/status":
                self._send_auth_required(include_body=include_body)
            else:
                self._send_redirect(
                    f"/login?next={quote(self.path)}", include_body=include_body
                )
            return

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

    def _is_authorized(self) -> bool:
        password = getattr(self.server, "dashboard_password", None)
        if not password:
            return True
        cookie_token = self._session_cookie_value()
        expected_token = self._session_token()
        if cookie_token and hmac.compare_digest(cookie_token, expected_token):
            return True
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(header[6:].strip()).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return False
        username, separator, candidate_password = decoded.partition(":")
        if not separator:
            return False
        expected_username = getattr(self.server, "dashboard_username", "kolkhoz")
        return hmac.compare_digest(username, expected_username) and hmac.compare_digest(
            candidate_password, password
        )

    def _handle_login(self) -> None:
        password = getattr(self.server, "dashboard_password", None)
        if not password:
            self._send_redirect("/", include_body=True)
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
        except ValueError:
            length = 0
        raw_body = self.rfile.read(length).decode("utf-8", errors="replace")
        fields = parse_qs(raw_body)
        username = fields.get("username", [""])[0]
        candidate_password = fields.get("password", [""])[0]
        expected_username = getattr(self.server, "dashboard_username", "kolkhoz")
        if hmac.compare_digest(username, expected_username) and hmac.compare_digest(
            candidate_password, password
        ):
            self.send_response(303)
            self.send_header("Location", "/")
            self.send_header("Set-Cookie", self._session_cookie_header())
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        self._send_redirect("/login?error=1", include_body=True)

    def _session_token(self) -> str:
        password = getattr(self.server, "dashboard_password", "") or ""
        username = getattr(self.server, "dashboard_username", "kolkhoz")
        return hmac.new(
            password.encode("utf-8"),
            f"{username}:kolkhoz-dashboard".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    def _session_cookie_header(self) -> str:
        return f"{self.session_cookie_name}={self._session_token()}; Path=/; HttpOnly; SameSite=Lax; Secure"

    def _session_cookie_value(self) -> str | None:
        cookie_header = self.headers.get("Cookie", "")
        for item in cookie_header.split(";"):
            name, separator, value = item.strip().partition("=")
            if separator and name == self.session_cookie_name:
                return value
        return None

    def _send_login_page(self, *, include_body: bool, failed: bool) -> None:
        title = "Kolkhoz Research"
        error = '<p class="error">That password did not match.</p>' if failed else ""
        username = html.escape(
            str(getattr(self.server, "dashboard_username", "kolkhoz"))
        )
        body = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} Login</title>
  <style>
    :root {{
      color-scheme: light;
      --paper: #f8f4ea;
      --ink: #24231f;
      --muted: #6d7168;
      --line: #d7d0c0;
      --accent: #2f6688;
      --danger: #a9493d;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      min-height: 100vh;
      margin: 0;
      display: grid;
      place-items: center;
      background: var(--paper);
      color: var(--ink);
      font: 16px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{
      width: min(420px, calc(100vw - 32px));
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fffcf5;
      padding: 28px;
      box-shadow: 0 20px 48px rgba(36, 35, 31, 0.12);
    }}
    .label {{
      margin: 0 0 8px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }}
    h1 {{
      margin: 0 0 24px;
      font-size: 30px;
      line-height: 1.05;
      letter-spacing: 0;
    }}
    label {{
      display: block;
      margin: 0 0 14px;
      color: var(--muted);
      font-size: 13px;
      font-weight: 700;
    }}
    input {{
      display: block;
      width: 100%;
      height: 44px;
      margin-top: 6px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #fff;
      color: var(--ink);
      font: inherit;
      padding: 0 12px;
    }}
    input:focus {{
      border-color: var(--accent);
      outline: 2px solid rgba(47, 102, 136, 0.18);
      outline-offset: 1px;
    }}
    button {{
      width: 100%;
      height: 44px;
      border: 0;
      border-radius: 6px;
      background: var(--accent);
      color: #fff;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
    }}
    .error {{
      margin: -8px 0 14px;
      color: var(--danger);
      font-size: 14px;
      font-weight: 700;
    }}
  </style>
</head>
<body>
  <main>
    <p class="label">Kolkhoz research</p>
    <h1>Model Lab</h1>
    {error}
    <form method="post" action="/login">
      <label>Username
        <input name="username" value="{username}" autocomplete="username">
      </label>
      <label>Password
        <input name="password" type="password" autocomplete="current-password" autofocus>
      </label>
      <button type="submit">Sign in</button>
    </form>
  </main>
</body>
</html>
""".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if include_body:
            self.wfile.write(body)

    def _send_redirect(self, location: str, *, include_body: bool) -> None:
        body = b""
        self.send_response(303)
        self.send_header("Location", location)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if include_body:
            self.wfile.write(body)

    def _send_auth_required(self, *, include_body: bool) -> None:
        body = b"Authentication required\n"
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Kolkhoz Research Dashboard"')
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if include_body:
            self.wfile.write(body)

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
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if include_body:
            self.wfile.write(data)


def serve_dashboard(
    host: str = "127.0.0.1",
    port: int = 8765,
    *,
    username: str = "kolkhoz",
    password: str | None = None,
) -> None:
    server = ThreadingHTTPServer((host, port), DashboardHandler)
    server.dashboard_username = username
    server.dashboard_password = password
    auth_note = " with basic auth" if password else ""
    print(f"Kolkhoz research dashboard: http://{host}:{port}{auth_note}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
