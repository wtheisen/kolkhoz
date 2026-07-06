from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
HISTORY_PATH = REPO_ROOT / "research/history/experiments.jsonl"
CURRENT_EXPERIMENT_PATH = REPO_ROOT / "research/history/current_experiment.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def append_history(record: dict[str, Any], path: Path = HISTORY_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    enriched = {"recorded_at": now_iso(), **record}
    with path.open("a", encoding="utf-8") as handle:
        json.dump(enriched, handle, sort_keys=True)
        handle.write("\n")


def write_current_experiment(
    record: dict[str, Any], path: Path = CURRENT_EXPERIMENT_PATH
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    timestamp = now_iso()
    enriched = {
        "updated_at": timestamp,
        "heartbeat_at": timestamp,
        "pid": os.getpid(),
        **record,
    }
    with path.open("w", encoding="utf-8") as handle:
        json.dump(enriched, handle, indent=2, sort_keys=True)
        handle.write("\n")
