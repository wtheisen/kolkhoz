#!/usr/bin/env python3
"""Update the Flutter neural policy asset from the current deployable model."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ASSET_PATH = Path("clients/flutter_app/assets/policies/current_best_policy.json")
CURRENT_EXPERIMENT_PATH = Path("research/history/current_experiment.json")
FALLBACK_POLICY_PATH = Path(
    "training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json"
)


class PolicyAssetError(ValueError):
    pass


@dataclass
class DeployablePolicy:
    path: Path
    label: str
    cleanup_path: Path | None = None

    def cleanup(self) -> None:
        if self.cleanup_path is not None:
            self.cleanup_path.unlink(missing_ok=True)


def main() -> int:
    root = Path(__file__).resolve().parents[3]
    destination = root / ASSET_PATH
    policy: DeployablePolicy | None = None
    try:
        policy = _resolve_current_policy(root)
        _update_asset(policy.path, destination, policy.label)
    except PolicyAssetError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    finally:
        if policy is not None:
            policy.cleanup()
    return 0


def _resolve_current_policy(root: Path) -> DeployablePolicy:
    candidates = list(_candidate_paths(root))
    errors: list[str] = []
    for label, candidate in candidates:
        try:
            resolved = _resolve_path(root, candidate)
            return _prepare_deployable_policy(root, label, resolved)
        except PolicyAssetError as error:
            errors.append(f"{label}: {error}")

    detail = "\n  ".join(errors) if errors else "no candidates were found"
    raise PolicyAssetError(f"no deployable C MLP policy found:\n  {detail}")


def _prepare_deployable_policy(root: Path, label: str, path: Path) -> DeployablePolicy:
    if path.suffix.lower() == ".json":
        _validate_deployable_policy(path)
        return DeployablePolicy(path=path, label=label)
    if path.suffix.lower() == ".pt":
        exported = _export_torch_mlp_checkpoint(root, path)
        _validate_deployable_policy(exported)
        return DeployablePolicy(
            path=exported,
            label=f"{label} exported from Torch MLP",
            cleanup_path=exported,
        )
    raise PolicyAssetError(f"{path} is not a JSON C MLP model or Torch MLP checkpoint")


def _candidate_paths(root: Path) -> list[tuple[str, Path]]:
    override = os.environ.get("KOLKHOZ_APP_POLICY_MODEL")
    if override:
        return [("KOLKHOZ_APP_POLICY_MODEL", Path(override))]

    candidates: list[tuple[str, Path]] = []
    current_experiment = root / CURRENT_EXPERIMENT_PATH
    if current_experiment.exists():
        record = _read_json_object(current_experiment)
        _append_path(
            candidates,
            "current_experiment.current_best_model",
            record.get("current_best_model"),
        )
        _append_path(
            candidates,
            "current_experiment.best_model",
            record.get("best_model"),
        )

        latest_evaluation = _dict_value(record, "latest_evaluation")
        if latest_evaluation.get("comparison") == "current_best":
            _append_path(
                candidates,
                "latest_evaluation.baseline_model",
                latest_evaluation.get("baseline_model"),
            )

        training = _dict_value(record, "training")
        _append_path(
            candidates,
            "training.reward_baseline_model",
            training.get("reward_baseline_model"),
        )
        opponent_models = training.get("opponent_models")
        if isinstance(opponent_models, list):
            for index, model_path in enumerate(opponent_models):
                _append_path(
                    candidates,
                    f"training.opponent_models[{index}]",
                    model_path,
                )

    _append_path(candidates, "fallback promoted C MLP", FALLBACK_POLICY_PATH)
    return _dedupe_candidates(candidates)


def _append_path(
    candidates: list[tuple[str, Path]],
    label: str,
    value: object,
) -> None:
    if isinstance(value, str) and value:
        candidates.append((label, Path(value)))


def _dedupe_candidates(candidates: list[tuple[str, Path]]) -> list[tuple[str, Path]]:
    seen: set[str] = set()
    deduped: list[tuple[str, Path]] = []
    for label, path in candidates:
        key = str(path)
        if key in seen:
            continue
        seen.add(key)
        deduped.append((label, path))
    return deduped


def _resolve_path(root: Path, path: Path) -> Path:
    expanded = Path(os.path.expanduser(str(path)))
    if expanded.is_absolute():
        return expanded
    return root / expanded


def _validate_deployable_policy(path: Path) -> None:
    if not path.exists():
        raise PolicyAssetError(f"{path} does not exist")
    if path.suffix.lower() != ".json":
        raise PolicyAssetError(f"{path} is not a JSON C MLP model")

    model = _read_json_object(path)
    backend = model.get("backend", "c-mlp")
    if backend != "c-mlp":
        raise PolicyAssetError(f"{path} uses unsupported backend {backend!r}")

    input_size = _int_value(model.get("input_size", model.get("inputSize")), 200)
    hidden_layers = _int_list(model.get("hidden_layers", model.get("layerSizes")))
    hidden_weights = _nested_float_list(
        model.get("hidden_weights", model.get("layerWeights"))
    )
    hidden_biases = _nested_float_list(
        model.get("hidden_biases", model.get("layerBiases"))
    )
    output_weights = _float_list(model.get("output_weights", model.get("outputWeights")))
    b2s = _float_list(model.get("b2s"))
    head_count = _int_value(
        model.get("head_count", model.get("headCount")),
        len(b2s) if b2s else 1,
    )

    if input_size <= 0:
        raise PolicyAssetError(f"{path} has invalid input_size {input_size}")
    if not hidden_layers:
        raise PolicyAssetError(f"{path} is missing hidden_layers")
    if len(hidden_weights) < len(hidden_layers) or len(hidden_biases) < len(
        hidden_layers
    ):
        raise PolicyAssetError(f"{path} has incomplete hidden layer parameters")
    if head_count <= 0:
        raise PolicyAssetError(f"{path} has invalid head_count {head_count}")

    previous_size = input_size
    for index, layer_size in enumerate(hidden_layers):
        if layer_size <= 0:
            raise PolicyAssetError(f"{path} has invalid hidden layer size {layer_size}")
        expected_weights = previous_size * layer_size
        actual_weights = len(hidden_weights[index])
        if actual_weights != expected_weights:
            raise PolicyAssetError(
                f"{path} hidden layer {index} has {actual_weights} weights, "
                f"expected {expected_weights}"
            )
        actual_biases = len(hidden_biases[index])
        if actual_biases != layer_size:
            raise PolicyAssetError(
                f"{path} hidden layer {index} has {actual_biases} biases, "
                f"expected {layer_size}"
            )
        previous_size = layer_size

    expected_output_weights = previous_size * head_count
    if len(output_weights) != expected_output_weights:
        raise PolicyAssetError(
            f"{path} has {len(output_weights)} output weights, "
            f"expected {expected_output_weights}"
        )
    if b2s and len(b2s) != head_count:
        raise PolicyAssetError(
            f"{path} has {len(b2s)} output biases, expected {head_count}"
        )


def _export_torch_mlp_checkpoint(root: Path, checkpoint_path: Path) -> Path:
    if not checkpoint_path.exists():
        raise PolicyAssetError(f"{checkpoint_path} does not exist")

    root_string = str(root)
    if root_string not in sys.path:
        sys.path.insert(0, root_string)

    try:
        import torch
        from research.kolkhoz_research.model import PolicyArtifact
        from research.kolkhoz_research.torch_policy import TorchPolicy
    except ModuleNotFoundError as error:
        raise PolicyAssetError(
            f"{checkpoint_path} is a Torch checkpoint, but Torch is not importable"
        ) from error

    try:
        model = TorchPolicy.from_checkpoint(checkpoint_path, torch.device("cpu"))
    except Exception as error:
        raise PolicyAssetError(
            f"could not load Torch checkpoint {checkpoint_path}: {error}"
        ) from error
    if model.architecture != "mlp":
        raise PolicyAssetError(
            f"{checkpoint_path} is architecture {model.architecture!r}, not exportable mlp"
        )

    template_path = root / ASSET_PATH
    if not template_path.exists():
        template_path = root / FALLBACK_POLICY_PATH
    _validate_deployable_policy(template_path)
    template = PolicyArtifact.load(template_path)

    with tempfile.NamedTemporaryFile(
        prefix="kolkhoz_policy_",
        suffix=".json",
        delete=False,
    ) as handle:
        export_path = Path(handle.name)
    try:
        model.export_artifact(
            template,
            export_path,
            training_record={
                "kind": "app_policy_export",
                "source_checkpoint": str(checkpoint_path),
            },
        )
    except Exception as error:
        export_path.unlink(missing_ok=True)
        raise PolicyAssetError(
            f"could not export Torch MLP {checkpoint_path}: {error}"
        ) from error
    return export_path


def _update_asset(source: Path, destination: Path, source_label: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    source_hash = _sha256(source)
    if destination.exists() and _sha256(destination) == source_hash:
        print(f"Neural policy asset already current: {source_label} -> {source}")
        return

    shutil.copyfile(source, destination)
    print(f"Updated neural policy asset: {source_label} -> {destination}")


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except json.JSONDecodeError as error:
        raise PolicyAssetError(f"{path} is not valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise PolicyAssetError(f"{path} must contain a JSON object")
    return value


def _dict_value(value: dict[str, Any], key: str) -> dict[str, Any]:
    child = value.get(key)
    if isinstance(child, dict):
        return child
    return {}


def _int_value(value: object, fallback: int) -> int:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return fallback


def _int_list(value: object) -> list[int]:
    if not isinstance(value, list):
        return []
    return [_int_value(item, 0) for item in value]


def _float_list(value: object) -> list[float]:
    if not isinstance(value, list):
        return []
    result: list[float] = []
    for item in value:
        if isinstance(item, (int, float)) and not isinstance(item, bool):
            result.append(float(item))
        else:
            result.append(0.0)
    return result


def _nested_float_list(value: object) -> list[list[float]]:
    if not isinstance(value, list):
        return []
    return [_float_list(row) for row in value if isinstance(row, list)]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if __name__ == "__main__":
    raise SystemExit(main())
