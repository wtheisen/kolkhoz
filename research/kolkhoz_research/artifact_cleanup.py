from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from .history import CURRENT_EXPERIMENT_PATH, HISTORY_PATH, REPO_ROOT


JSON_CHECKPOINT_RE = re.compile(r"^candidate_e(\d+)\.json$")
TORCH_CHECKPOINT_RE = re.compile(r"^(.+)_ep(\d+)\.pt$")


@dataclass(frozen=True)
class CleanupCandidate:
    path: Path
    bytes: int
    reason: str


@dataclass(frozen=True)
class ScoredCheckpoint:
    path: Path
    score: tuple[float, float, float, int]


def cleanup_artifacts(
    *,
    roots: Iterable[Path],
    keep_json_checkpoints: int,
    keep_torch_checkpoints: int,
    keep_latest_runs_per_experiment: int,
    protected_paths: Iterable[Path],
    delete: bool,
    include_files: bool,
) -> dict[str, Any]:
    latest_run_dirs = _latest_run_dirs(roots, keep_latest_runs_per_experiment)
    protected = _protected_artifacts(set(protected_paths), keep_torch_checkpoints)
    candidates = _cleanup_candidates(
        roots=roots,
        keep_json_checkpoints=keep_json_checkpoints,
        keep_torch_checkpoints=keep_torch_checkpoints,
        keep_run_dirs=latest_run_dirs,
        protected=protected,
    )
    deleted: list[CleanupCandidate] = []
    if delete:
        for candidate in candidates:
            try:
                candidate.path.unlink()
                deleted.append(candidate)
            except FileNotFoundError:
                continue
        _remove_empty_dirs(roots)

    record = {
        "kind": "artifact_cleanup",
        "mode": "delete" if delete else "dry_run",
        "roots": [str(_display_path(path)) for path in roots],
        "protected_count": len(protected),
        "kept_latest_run_count": len(latest_run_dirs),
        "candidate_count": len(candidates),
        "candidate_bytes": sum(item.bytes for item in candidates),
        "deleted_count": len(deleted),
        "deleted_bytes": sum(item.bytes for item in deleted),
    }
    if include_files:
        record["candidates"] = [_candidate_record(item) for item in candidates]
    else:
        record["sample_candidates"] = [_candidate_record(item) for item in candidates[:20]]
    return record


def _cleanup_candidates(
    *,
    roots: Iterable[Path],
    keep_json_checkpoints: int,
    keep_torch_checkpoints: int,
    keep_run_dirs: set[Path],
    protected: set[Path],
) -> list[CleanupCandidate]:
    candidates: list[CleanupCandidate] = []
    for root in roots:
        if not root.exists():
            continue
        candidates.extend(_stale_json_checkpoints(root, keep_json_checkpoints, keep_run_dirs, protected))
        candidates.extend(_stale_torch_checkpoints(root, keep_torch_checkpoints, keep_run_dirs, protected))
    return sorted(candidates, key=lambda item: str(item.path))


def _stale_json_checkpoints(
    root: Path,
    keep_count: int,
    keep_run_dirs: set[Path],
    protected: set[Path],
) -> list[CleanupCandidate]:
    by_run: dict[Path, list[Path]] = {}
    for path in root.rglob("candidate_e*.json"):
        if not path.is_file() or JSON_CHECKPOINT_RE.match(path.name) is None:
            continue
        by_run.setdefault(path.parent, []).append(path)

    candidates: list[CleanupCandidate] = []
    for run_dir, paths in by_run.items():
        if run_dir.resolve() in keep_run_dirs:
            continue
        ordered = sorted(paths, key=lambda item: _json_checkpoint_epoch(item))
        keep = set(ordered[-max(0, keep_count):])
        for path in ordered:
            resolved = path.resolve()
            if path in keep or resolved in protected:
                continue
            candidates.append(CleanupCandidate(path=path, bytes=_file_size(path), reason="old_json_checkpoint"))
    return candidates


def _stale_torch_checkpoints(
    root: Path,
    keep_count: int,
    keep_run_dirs: set[Path],
    protected: set[Path],
) -> list[CleanupCandidate]:
    by_run: dict[Path, list[Path]] = {}
    for checkpoints_dir in root.rglob("checkpoints"):
        if not checkpoints_dir.is_dir():
            continue
        for path in checkpoints_dir.iterdir():
            if path.is_file() and path.suffix == ".pt":
                by_run.setdefault(checkpoints_dir.parent, []).append(path)

    candidates: list[CleanupCandidate] = []
    for run_dir, paths in by_run.items():
        if run_dir.resolve() in keep_run_dirs:
            continue
        ordered = sorted(paths, key=lambda item: _torch_checkpoint_episode(item))
        keep = set(ordered[-max(0, keep_count):])
        for path in ordered:
            resolved = path.resolve()
            if path in keep or resolved in protected:
                continue
            candidates.append(CleanupCandidate(path=path, bytes=_file_size(path), reason="old_torch_checkpoint"))
    return candidates


def _latest_run_dirs(roots: Iterable[Path], keep_count: int) -> set[Path]:
    if keep_count <= 0:
        return set()
    by_experiment: dict[Path, set[Path]] = {}
    for root in roots:
        if not root.exists():
            continue
        for run_dir in _run_dirs_with_checkpoints(root):
            by_experiment.setdefault(run_dir.parent.resolve(), set()).add(run_dir.resolve())

    keep: set[Path] = set()
    for run_dirs in by_experiment.values():
        ordered = sorted(run_dirs, key=_run_sort_key)
        keep.update(ordered[-keep_count:])
    return keep


def _run_dirs_with_checkpoints(root: Path) -> set[Path]:
    run_dirs: set[Path] = set()
    for path in root.rglob("candidate_e*.json"):
        if path.is_file() and JSON_CHECKPOINT_RE.match(path.name):
            run_dirs.add(path.parent)
    for checkpoints_dir in root.rglob("checkpoints"):
        if not checkpoints_dir.is_dir():
            continue
        if any(path.is_file() and path.suffix == ".pt" for path in checkpoints_dir.iterdir()):
            run_dirs.add(checkpoints_dir.parent)
    return run_dirs


def _run_sort_key(path: Path) -> tuple[int, float, str]:
    return (_timestamp_key(path.name), _latest_file_mtime(path), path.name)


def _timestamp_key(name: str) -> int:
    match = re.match(r"^(\d{8})T(\d{6})Z$", name)
    if not match:
        return 0
    return int(match.group(1) + match.group(2))


def _latest_file_mtime(path: Path) -> float:
    try:
        latest = path.stat().st_mtime
    except FileNotFoundError:
        return 0.0
    for child in path.rglob("*"):
        if not child.is_file():
            continue
        try:
            latest = max(latest, child.stat().st_mtime)
        except FileNotFoundError:
            continue
    return latest


def _protected_artifacts(extra_paths: set[Path], keep_torch_checkpoints: int) -> set[Path]:
    protected: set[Path] = set()
    protected.update(_resolve_existing(path) for path in extra_paths)
    checkpoint_refs: list[ScoredCheckpoint] = []
    for record in _history_records():
        protected.update(_record_artifacts(record))
        checkpoint_refs.extend(_record_checkpoint_refs(record))

    by_run: dict[Path, list[ScoredCheckpoint]] = {}
    for item in checkpoint_refs:
        by_run.setdefault(item.path.parent.parent, []).append(item)
    for refs in by_run.values():
        ordered = sorted(refs, key=lambda item: item.score)
        for item in ordered[-max(0, keep_torch_checkpoints):]:
            protected.add(item.path)
    return {path.resolve() for path in protected if path.exists()}


def _history_records() -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if HISTORY_PATH.exists():
        with HISTORY_PATH.open("r", encoding="utf-8") as handle:
            for line in handle:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(record, dict):
                    records.append(record)
    if CURRENT_EXPERIMENT_PATH.exists():
        try:
            record = json.loads(CURRENT_EXPERIMENT_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            record = None
        if isinstance(record, dict):
            records.append(record)
    return records


def _record_artifacts(record: dict[str, Any]) -> set[Path]:
    protected: set[Path] = set()
    artifact_keys = {
        "baseline_model",
        "candidate_model",
        "eval_baseline_model",
        "model",
        "output_model",
        "start_model",
        "teacher_model",
    }
    for key, value in _walk_items(record):
        if key in artifact_keys:
            protected.update(_paths_from_value(value))
        elif key in {"opponent_model", "opponent_models"}:
            protected.update(_paths_from_value(value))
    return {_resolve_existing(path) for path in protected if path.exists()}


def _record_checkpoint_refs(record: dict[str, Any]) -> list[ScoredCheckpoint]:
    refs: list[ScoredCheckpoint] = []
    for value in _walk_dicts(record):
        checkpoint = value.get("checkpoint_model")
        if not isinstance(checkpoint, str):
            continue
        path = _path_from_record_value(checkpoint)
        if path is None or not path.exists():
            continue
        refs.append(ScoredCheckpoint(path=_resolve_existing(path), score=_checkpoint_score(value)))
    return refs


def _checkpoint_score(record: dict[str, Any]) -> tuple[float, float, float, int]:
    intervals = record.get("intervals") if isinstance(record.get("intervals"), dict) else {}
    summary = record.get("summary") if isinstance(record.get("summary"), dict) else {}
    win_delta = _interval_low(intervals.get("win_delta"))
    rank_delta = _interval_low(intervals.get("rank_delta"))
    margin_delta = _interval_low(intervals.get("margin_delta"))
    if win_delta == 0.0:
        win_delta = _float(summary.get("candidate_win_rate")) - _float(summary.get("baseline_win_rate"))
    episode = int(record.get("completed_episodes", 0) or 0)
    return (win_delta, rank_delta, margin_delta, episode)


def _walk_items(value: Any) -> Iterable[tuple[str, Any]]:
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key), child
            yield from _walk_items(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_items(child)


def _walk_dicts(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _paths_from_value(value: Any) -> set[Path]:
    paths: set[Path] = set()
    if isinstance(value, str):
        path = _path_from_record_value(value)
        if path is not None:
            paths.add(path)
    elif isinstance(value, list):
        for item in value:
            paths.update(_paths_from_value(item))
    return paths


def _path_from_record_value(value: str) -> Path | None:
    if value in {"", "heuristic", "scratch", "current best"}:
        return None
    if not any(value.endswith(suffix) for suffix in (".json", ".pt")):
        return None
    path = Path(value)
    return path if path.is_absolute() else REPO_ROOT / path


def _resolve_existing(path: Path) -> Path:
    return path.resolve() if path.exists() else path


def _json_checkpoint_epoch(path: Path) -> int:
    match = JSON_CHECKPOINT_RE.match(path.name)
    return int(match.group(1)) if match else 0


def _torch_checkpoint_episode(path: Path) -> int:
    match = TORCH_CHECKPOINT_RE.match(path.name)
    return int(match.group(2)) if match else 0


def _interval_low(value: Any) -> float:
    if isinstance(value, list) and value:
        return _float(value[0])
    if isinstance(value, dict):
        return _float(value.get("low"))
    return 0.0


def _float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _file_size(path: Path) -> int:
    try:
        return path.stat().st_size
    except FileNotFoundError:
        return 0


def _remove_empty_dirs(roots: Iterable[Path]) -> None:
    for root in roots:
        if not root.exists():
            continue
        for path in sorted((item for item in root.rglob("*") if item.is_dir()), reverse=True):
            try:
                path.rmdir()
            except OSError:
                pass


def _candidate_record(candidate: CleanupCandidate) -> dict[str, Any]:
    return {
        "path": str(_display_path(candidate.path)),
        "bytes": candidate.bytes,
        "reason": candidate.reason,
    }


def _display_path(path: Path) -> Path:
    try:
        return path.relative_to(REPO_ROOT)
    except ValueError:
        return path
