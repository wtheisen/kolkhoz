from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Any

import torch
from torch import nn

from .benchmark import _metrics, run_policy_game
from .c_engine import CEngine, KCAction
from .model import HEAD_COUNT, INPUT_SIZE, PolicyArtifact


def best_device(prefer_mps: bool = True) -> torch.device:
    if prefer_mps and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


class TorchPolicy(nn.Module):
    def __init__(self, layer_sizes: list[int], input_size: int = INPUT_SIZE, head_count: int = HEAD_COUNT) -> None:
        super().__init__()
        self.input_size = input_size
        self.head_count = head_count
        self.layers = nn.ModuleList()
        previous = input_size
        for size in layer_sizes:
            self.layers.append(nn.Linear(previous, size))
            previous = size
        self.output = nn.Linear(previous, head_count)

    @classmethod
    def from_artifact(cls, artifact: PolicyArtifact, device: torch.device) -> "TorchPolicy":
        if artifact.layer_sizes:
            layer_sizes = artifact.layer_sizes
        else:
            layer_sizes = [artifact.hidden_size]
        model = cls(layer_sizes=layer_sizes, input_size=artifact.input_size, head_count=artifact.head_count)
        with torch.no_grad():
            if artifact.layer_sizes:
                hidden_weights = artifact.data["hidden_weights"]
                hidden_biases = artifact.data["hidden_biases"]
                for index, layer in enumerate(model.layers):
                    layer.weight.copy_(torch.tensor(hidden_weights[index], dtype=torch.float32).reshape(layer.out_features, layer.in_features))
                    layer.bias.copy_(torch.tensor(hidden_biases[index], dtype=torch.float32))
                model.output.weight.copy_(
                    torch.tensor(artifact.data["output_weights"], dtype=torch.float32).reshape(model.head_count, model.layers[-1].out_features)
                )
            else:
                model.layers[0].weight.copy_(torch.tensor(artifact.data["w1"], dtype=torch.float32).reshape(model.layers[0].out_features, model.input_size))
                model.layers[0].bias.copy_(torch.tensor(artifact.data["b1"], dtype=torch.float32))
                model.output.weight.copy_(torch.tensor(artifact.data["w2"], dtype=torch.float32).reshape(model.head_count, model.layers[-1].out_features))
            b2s = artifact.data.get("b2s") or [float(artifact.data.get("b2", 0.0))] * model.head_count
            model.output.bias.copy_(torch.tensor(b2s, dtype=torch.float32))
        return model.to(device)

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        value = features
        for layer in self.layers:
            value = torch.relu(layer(value))
        return self.output(value)

    def export_artifact(self, source: PolicyArtifact, path: Path, *, training_record: dict[str, Any] | None = None) -> None:
        data = dict(source.data)
        data["backend"] = "c-mlp"
        data["training_backend"] = "torch-mps" if next(self.parameters()).device.type == "mps" else "torch"
        if training_record is not None:
            data["training_record"] = training_record
        layers = [layer.out_features for layer in self.layers]
        data["hidden_layers"] = layers
        data["hidden_size"] = layers[0]
        data["input_size"] = self.input_size
        data["hidden_weights"] = [layer.weight.detach().cpu().reshape(-1).tolist() for layer in self.layers]
        data["hidden_biases"] = [layer.bias.detach().cpu().reshape(-1).tolist() for layer in self.layers]
        data["output_weights"] = self.output.weight.detach().cpu().reshape(-1).tolist()
        data["b2s"] = self.output.bias.detach().cpu().reshape(-1).tolist()
        data["b2"] = float(data["b2s"][0]) if data["b2s"] else 0.0
        PolicyArtifact(data=data).save(path)


def _candidate_tensor(candidates: list[Any], input_size: int, device: torch.device) -> torch.Tensor:
    features = torch.zeros((len(candidates), input_size), dtype=torch.float32, device=device)
    for row, candidate in enumerate(candidates):
        for index in range(candidate.feature_count):
            column = int(candidate.feature_indices[index])
            if 0 <= column < input_size:
                features[row, column] = float(candidate.feature_values[index])
    return features


def _candidate_scores(model: TorchPolicy, candidates: list[Any], player_id: int) -> torch.Tensor:
    features = _candidate_tensor(candidates, model.input_size, next(model.parameters()).device)
    outputs = model(features)
    heads = []
    for candidate in candidates:
        action_head = int(candidate.action_head)
        if model.head_count == 16:
            heads.append(player_id * 4 + (action_head % 4))
        else:
            heads.append(min(max(action_head, 0), model.head_count - 1))
    head_tensor = torch.tensor(heads, dtype=torch.long, device=outputs.device)
    return outputs.gather(1, head_tensor[:, None]).squeeze(1)


def _choose_torch_action(
    model: TorchPolicy,
    candidates: list[Any],
    player_id: int,
    *,
    sample: bool,
    temperature: float,
) -> tuple[KCAction, torch.Tensor | None]:
    scores = _candidate_scores(model, candidates, player_id)
    if sample:
        distribution = torch.distributions.Categorical(logits=scores / max(temperature, 0.05))
        selected = distribution.sample()
        return candidates[int(selected.item())].action, distribution.log_prob(selected)
    selected = int(torch.argmax(scores).item())
    return candidates[selected].action, None


def _winner(scores: list[int], medals: list[int]) -> int:
    best = 0
    for player_id in range(1, 4):
        if (scores[player_id], medals[player_id], player_id) > (scores[best], medals[best], best):
            best = player_id
    return best


def run_torch_game(
    engine: CEngine,
    model: TorchPolicy,
    *,
    seed: int,
    model_seat: int,
    sample: bool = False,
    temperature: float = 1.0,
) -> dict[str, Any]:
    pointer = engine.new_engine(seed)
    log_probs: list[torch.Tensor] = []
    actions = 0
    try:
        for _ in range(2000):
            player_id = engine.waiting_player(pointer)
            if player_id < 0:
                scores = engine.final_scores(pointer)
                medals = engine.total_medals(pointer)
                winner = _winner(scores, medals)
                return {
                    "seed": seed,
                    "seat": model_seat,
                    "actions": actions,
                    "scores": scores,
                    "medals": medals,
                    "winner_id": winner,
                    "metrics": asdict(_metrics(scores, medals, winner, model_seat)),
                    "log_probs": log_probs,
                }
            if player_id == model_seat:
                candidates = engine.policy_action_features(pointer, player_id=player_id, input_size=model.input_size)
                if candidates:
                    action, log_prob = _choose_torch_action(model, candidates, player_id, sample=sample, temperature=temperature)
                    if log_prob is not None:
                        log_probs.append(log_prob)
                else:
                    action = engine.heuristic_action(pointer)
            else:
                action = engine.heuristic_action(pointer)
            engine.apply_policy_action(pointer, action)
            actions += 1
    finally:
        engine.free_engine(pointer)
    raise RuntimeError("Torch policy game exceeded guard limit")


def torch_parity(
    engine: CEngine,
    *,
    model_path: Path,
    games_per_seat: int,
    seed: int,
    prefer_mps: bool,
) -> dict[str, Any]:
    artifact = PolicyArtifact.load(model_path)
    device = best_device(prefer_mps)
    model = TorchPolicy.from_artifact(artifact, device).eval()
    records = []
    same_winner = 0
    same_scores = 0
    for seat in range(4):
        for offset in range(games_per_seat):
            game_seed = seed + seat * games_per_seat + offset
            torch_game = run_torch_game(engine, model, seed=game_seed, model_seat=seat)
            c_game = run_policy_game(
                engine,
                seed=game_seed,
                model=artifact,
                model_is_heuristic=False,
                opponent=None,
                opponent_is_heuristic=True,
                seat=seat,
            )
            winner_match = torch_game["winner_id"] == c_game["winner_id"]
            score_match = torch_game["scores"] == c_game["scores"]
            same_winner += 1 if winner_match else 0
            same_scores += 1 if score_match else 0
            records.append(
                {
                    "seed": game_seed,
                    "seat": seat,
                    "winner_match": winner_match,
                    "score_match": score_match,
                    "torch": {key: torch_game[key] for key in ("winner_id", "scores", "metrics")},
                    "c": {key: c_game[key] for key in ("winner_id", "scores", "metrics")},
                }
            )
    total = len(records)
    return {
        "kind": "torch_policy_parity",
        "model": str(model_path),
        "device": str(device),
        "games": total,
        "same_winner_rate": same_winner / total if total else 0.0,
        "same_score_rate": same_scores / total if total else 0.0,
        "records": records,
        "status": "passed_gate" if same_winner == total and same_scores == total else "inconclusive",
    }


def train_torch_policy(
    engine: CEngine,
    *,
    start_model_path: Path,
    output_path: Path,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
) -> dict[str, Any]:
    artifact = PolicyArtifact.load(start_model_path)
    device = best_device(prefer_mps)
    model = TorchPolicy.from_artifact(artifact, device).train()
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    episode_records = []
    pending_losses: list[torch.Tensor] = []
    for episode in range(episodes):
        seat = episode % 4
        game = run_torch_game(engine, model, seed=seed + episode, model_seat=seat, sample=True, temperature=temperature)
        metrics = game["metrics"]
        reward = metrics["win"] - 0.25 * (metrics["rank"] - 1.0) + 0.02 * metrics["margin"]
        if game["log_probs"]:
            loss = -torch.stack(game["log_probs"]).sum() * float(reward)
            pending_losses.append(loss)
        episode_records.append(
            {
                "episode": episode + 1,
                "seed": seed + episode,
                "seat": seat,
                "reward": float(reward),
                "win": metrics["win"],
                "rank": metrics["rank"],
                "margin": metrics["margin"],
            }
        )
        if pending_losses and ((episode + 1) % batch_size == 0 or episode + 1 == episodes):
            optimizer.zero_grad(set_to_none=True)
            torch.stack(pending_losses).mean().backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            pending_losses.clear()

    summary = {
        "episodes": episodes,
        "average_reward": sum(item["reward"] for item in episode_records) / len(episode_records),
        "top_rate": sum(item["win"] for item in episode_records) / len(episode_records),
        "average_rank": sum(item["rank"] for item in episode_records) / len(episode_records),
        "average_margin": sum(item["margin"] for item in episode_records) / len(episode_records),
    }
    record = {
        "kind": "torch_policy_training",
        "backend": "torch-mps" if device.type == "mps" else "torch",
        "start_model": str(start_model_path),
        "output_model": str(output_path),
        "device": str(device),
        "training": {
            "episodes": episodes,
            "batch_size": batch_size,
            "seed": seed,
            "learning_rate": learning_rate,
            "temperature": temperature,
        },
        "summary": summary,
        "status": "trained",
    }
    model.export_artifact(artifact, output_path, training_record=record)
    return record
