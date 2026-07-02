from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Any

from .c_engine import CEngine, KCPolicyGradientConfig
from .model import PolicyArtifact


def _result_dict(result: Any) -> dict[str, Any]:
    return {
        "episodes": int(result.episodes),
        "actions": int(result.actions),
        "batches": int(result.batches),
        "checksum": int(result.checksum),
        "top_rate": float(result.top_rate),
        "average_rank": float(result.average_rank),
        "average_margin": float(result.average_margin),
        "average_reward": float(result.average_reward),
        "average_advantage": float(result.average_advantage),
        "last_gradient_norm": float(result.last_gradient_norm),
        "last_clip_scale": float(result.last_clip_scale),
        "average_ppo_kl": float(result.average_ppo_kl),
        "average_ppo_abs_kl": float(result.average_ppo_abs_kl),
        "average_ppo_entropy": float(result.average_ppo_entropy),
        "average_ppo_clip_fraction": float(result.average_ppo_clip_fraction),
        "weight_checksum": float(result.weight_checksum),
    }


def train_c_mlp(
    engine: CEngine,
    *,
    output_path: Path,
    start_model_path: Path | None,
    opponent_model_path: Path | None,
    opponent_mode: str,
    hidden_layers: list[int],
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    max_gradient_norm: float,
    l2: float,
    thread_count: int,
    optimizer: str,
    use_ppo: bool,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
    entropy_weight: float,
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
    paired_baseline: bool,
    training_seats: list[int],
) -> dict[str, Any]:
    model = (
        PolicyArtifact.load(start_model_path)
        if start_model_path
        else PolicyArtifact.scratch(hidden_layers=hidden_layers, seed=scratch_seed, scale=scratch_scale)
    )
    if model.backend != "c-mlp":
        raise ValueError(f"train-c-mlp cannot update backend {model.backend!r}")
    model_buffer = model.c_buffer()

    if opponent_mode == "model" and opponent_model_path is None:
        raise ValueError("--opponent-mode model requires --opponent-model")
    opponent = PolicyArtifact.load(opponent_model_path) if opponent_model_path and opponent_mode == "model" else None
    config = KCPolicyGradientConfig()
    config.episodes = episodes
    config.batch_size = batch_size
    config.seed = seed
    config.learning_rate = learning_rate
    config.temperature = temperature
    config.max_gradient_norm = max_gradient_norm
    config.l2 = l2
    config.win_weight = 1.0
    config.strict_weight = 0.0
    config.rank_weight = 0.25
    config.margin_weight = 0.02
    config.thread_count = thread_count
    config.greedy_sample_rate = 0.05
    config.advantage_baseline_beta = 0.02
    config.advantage_clip = 4.0
    config.value_learning_rate = 0.0
    config.value_weights = model.value_weights_pointer()
    config.training_seat_count = min(len(training_seats), 4)
    for index, seat in enumerate(training_seats[:4]):
        config.training_seats[index] = int(seat)
    config.round_curriculum = round_curriculum
    config.round_plot_cards = round_plot_cards
    config.round_famine_rate = round_famine_rate
    config.has_opponent_model = opponent_mode != "self-play"
    config.opponent_is_heuristic = opponent_mode == "heuristic"
    config.paired_baseline = paired_baseline
    config.use_adam = optimizer == "adam"
    config.use_ppo = use_ppo
    config.ppo_epochs = ppo_epochs
    config.ppo_minibatch_size = ppo_minibatch_size
    config.ppo_clip = ppo_clip
    config.entropy_weight = entropy_weight
    config.adam_beta1 = 0.9
    config.adam_beta2 = 0.999
    config.adam_epsilon = 1e-8
    if opponent is not None:
        config.opponent_model = opponent.c_buffer()

    status, result = engine.train_policy_gradient(model_buffer, config)
    if status != 0:
        raise RuntimeError(f"C policy-gradient training failed with status {status}")
    model.sync_from_c()
    model.data["training_backend"] = "c-policy-gradient"
    model.data["training_config"] = {
        "episodes": episodes,
        "batch_size": batch_size,
        "seed": seed,
        "learning_rate": learning_rate,
        "optimizer": optimizer,
        "use_ppo": use_ppo,
        "thread_count": thread_count,
        "round_curriculum": round_curriculum,
        "round_plot_cards": round_plot_cards,
        "round_famine_rate": round_famine_rate,
        "opponent_mode": opponent_mode,
        "opponent_model": str(opponent_model_path) if opponent_model_path else None,
    }
    model.save(output_path)
    return {
        "kind": "policy_training",
        "backend": "c-mlp",
        "output_model": str(output_path),
        "start_model": str(start_model_path) if start_model_path else "scratch",
        "opponent_model": str(opponent_model_path) if opponent_model_path else opponent_mode,
        "engine": asdict(engine.provenance()),
        "result": _result_dict(result),
        "status": "trained",
    }
