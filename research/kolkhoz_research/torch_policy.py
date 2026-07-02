from __future__ import annotations

import random
from dataclasses import asdict
from pathlib import Path
from typing import Any, Callable

import torch
from torch import nn

from .benchmark import _ci, _mean, _metrics, run_policy_game
from .c_engine import CEngine, KCAction, KCObjectToken, OBJECT_SCALAR_COUNT
from .model import HEAD_COUNT, INPUT_SIZE, PolicyArtifact

OBJECT_TYPE_EMBEDDINGS = 8
OBJECT_OWNER_EMBEDDINGS = 6
OBJECT_ZONE_EMBEDDINGS = 32
OBJECT_SUIT_EMBEDDINGS = 6
OBJECT_VALUE_EMBEDDINGS = 16
OBJECT_INDEX_EMBEDDINGS = 64

ObjectBatch = tuple[
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
]


def best_device(prefer_mps: bool = True) -> torch.device:
    if prefer_mps and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


class ResidualBlock(nn.Module):
    def __init__(self, width: int) -> None:
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(width, width),
            nn.ReLU(),
            nn.Linear(width, width),
        )

    def forward(self, value: torch.Tensor) -> torch.Tensor:
        return torch.relu(value + self.layers(value))


class ActionTransformer(nn.Module):
    def __init__(self, input_size: int, head_count: int, layer_sizes: list[int]) -> None:
        super().__init__()
        if not layer_sizes:
            raise ValueError("action-transformer requires at least a model width")
        width = int(layer_sizes[0])
        depth = int(layer_sizes[1]) if len(layer_sizes) > 1 else 4
        heads = int(layer_sizes[2]) if len(layer_sizes) > 2 else 4
        feedforward = int(layer_sizes[3]) if len(layer_sizes) > 3 else width * 4
        if width <= 0 or depth <= 0 or heads <= 0 or feedforward <= 0:
            raise ValueError("action-transformer width, depth, heads, and feedforward must be positive")
        if width % heads != 0:
            raise ValueError("action-transformer width must be divisible by attention heads")
        self.width = width
        self.depth = depth
        self.heads = heads
        self.feedforward = feedforward
        self.head_count = head_count
        self.feature_projection = nn.Sequential(
            nn.Linear(input_size, width),
            nn.LayerNorm(width),
            nn.GELU(),
            nn.Linear(width, width),
        )
        self.player_embedding = nn.Embedding(4, width)
        self.action_embedding = nn.Embedding(max(head_count, 16), width)
        self.object_type_embedding = nn.Embedding(OBJECT_TYPE_EMBEDDINGS, width)
        self.object_owner_embedding = nn.Embedding(OBJECT_OWNER_EMBEDDINGS, width)
        self.object_zone_embedding = nn.Embedding(OBJECT_ZONE_EMBEDDINGS, width)
        self.object_suit_embedding = nn.Embedding(OBJECT_SUIT_EMBEDDINGS, width)
        self.object_value_embedding = nn.Embedding(OBJECT_VALUE_EMBEDDINGS, width)
        self.object_index_embedding = nn.Embedding(OBJECT_INDEX_EMBEDDINGS, width)
        self.object_scalar_projection = nn.Sequential(
            nn.Linear(OBJECT_SCALAR_COUNT, width),
            nn.LayerNorm(width),
            nn.GELU(),
            nn.Linear(width, width),
        )
        self.cls_token = nn.Parameter(torch.zeros(1, 1, width))
        layer = nn.TransformerEncoderLayer(
            d_model=width,
            nhead=heads,
            dim_feedforward=feedforward,
            dropout=0.05,
            activation="gelu",
            batch_first=True,
            norm_first=True,
        )
        self.encoder = nn.TransformerEncoder(layer, num_layers=depth, enable_nested_tensor=False)
        self.scorer = nn.Sequential(
            nn.LayerNorm(width * 2),
            nn.Linear(width * 2, width),
            nn.GELU(),
            nn.Linear(width, 1),
        )

    def _object_embeddings(self, object_batch: ObjectBatch) -> torch.Tensor:
        type_ids, owner_ids, zone_ids, suit_ids, value_ids, index_ids, scalars, _ = object_batch
        return (
            self.object_type_embedding(type_ids.clamp(0, self.object_type_embedding.num_embeddings - 1))
            + self.object_owner_embedding(owner_ids.clamp(0, self.object_owner_embedding.num_embeddings - 1))
            + self.object_zone_embedding(zone_ids.clamp(0, self.object_zone_embedding.num_embeddings - 1))
            + self.object_suit_embedding(suit_ids.clamp(0, self.object_suit_embedding.num_embeddings - 1))
            + self.object_value_embedding(value_ids.clamp(0, self.object_value_embedding.num_embeddings - 1))
            + self.object_index_embedding(index_ids.clamp(0, self.object_index_embedding.num_embeddings - 1))
            + self.object_scalar_projection(scalars)
        )

    def forward(
        self,
        features: torch.Tensor,
        player_ids: torch.Tensor,
        action_heads: torch.Tensor,
        group_ids: torch.Tensor | None,
        object_batch: ObjectBatch | None = None,
    ) -> torch.Tensor:
        if features.numel() == 0:
            return torch.empty((0,), dtype=features.dtype, device=features.device)
        player_ids = player_ids.to(features.device).clamp(0, 3)
        head_indices = _head_indices(action_heads.to(features.device), player_ids, self.head_count)
        tokens = (
            self.feature_projection(features)
            + self.player_embedding(player_ids)
            + self.action_embedding(head_indices.clamp(0, self.action_embedding.num_embeddings - 1))
        )
        if group_ids is None:
            group_ids = torch.zeros((features.shape[0],), dtype=torch.long, device=features.device)
        else:
            group_ids = group_ids.to(features.device)
        group_count = int(group_ids.max().item()) + 1
        lengths = torch.bincount(group_ids, minlength=group_count)
        max_length = int(lengths.max().item())
        object_embeddings = None
        object_mask = None
        object_count = 0
        if object_batch is not None:
            object_batch = tuple(item.to(tokens.device) for item in object_batch)  # type: ignore[assignment]
            object_embeddings = self._object_embeddings(object_batch)
            object_mask = object_batch[-1].bool()
            object_count = int(object_embeddings.shape[1])
        sequence = torch.zeros((group_count, max_length + object_count + 1, self.width), dtype=tokens.dtype, device=tokens.device)
        mask = torch.ones((group_count, max_length + object_count + 1), dtype=torch.bool, device=tokens.device)
        sequence[:, 0:1, :] = self.cls_token.expand(group_count, -1, -1)
        mask[:, 0] = False
        if object_embeddings is not None and object_mask is not None and object_count > 0:
            sequence[:, 1:object_count + 1, :] = object_embeddings
            mask[:, 1:object_count + 1] = object_mask
        action_start = object_count + 1
        positions: list[torch.Tensor] = []
        for group_index in range(group_count):
            indices = torch.nonzero(group_ids == group_index, as_tuple=False).flatten()
            positions.append(indices)
            length = int(indices.numel())
            sequence[group_index, action_start:action_start + length, :] = tokens[indices]
            mask[group_index, action_start:action_start + length] = False
        encoded = self.encoder(sequence, src_key_padding_mask=mask)
        scores = torch.empty((features.shape[0],), dtype=tokens.dtype, device=tokens.device)
        for group_index, indices in enumerate(positions):
            length = int(indices.numel())
            global_token = encoded[group_index, 0].expand(length, -1)
            action_tokens = encoded[group_index, action_start:action_start + length, :]
            scores[indices] = self.scorer(torch.cat([action_tokens, global_token], dim=1)).squeeze(1)
        return scores


class TorchPolicy(nn.Module):
    def __init__(
        self,
        layer_sizes: list[int],
        input_size: int = INPUT_SIZE,
        head_count: int = HEAD_COUNT,
        architecture: str = "mlp",
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.head_count = head_count
        self.architecture = architecture
        self.layer_sizes = layer_sizes
        self.layers = nn.ModuleList()
        if architecture == "mlp":
            previous = input_size
            for size in layer_sizes:
                self.layers.append(nn.Linear(previous, size))
                previous = size
            self.output = nn.Linear(previous, head_count)
        elif architecture == "residual-mlp":
            if not layer_sizes:
                raise ValueError("residual-mlp requires at least one layer size")
            width = layer_sizes[0]
            if any(size != width for size in layer_sizes):
                raise ValueError("residual-mlp requires equal layer sizes; depth is the number of sizes")
            self.input_projection = nn.Linear(input_size, width)
            self.blocks = nn.ModuleList([ResidualBlock(width) for _ in layer_sizes])
            self.output = nn.Linear(width, head_count)
        elif architecture == "action-transformer":
            self.action_transformer = ActionTransformer(input_size=input_size, head_count=head_count, layer_sizes=layer_sizes)
        else:
            raise ValueError(f"unknown Torch policy architecture {architecture!r}")

    @classmethod
    def from_artifact(cls, artifact: PolicyArtifact, device: torch.device) -> "TorchPolicy":
        if artifact.layer_sizes:
            layer_sizes = artifact.layer_sizes
        else:
            layer_sizes = [artifact.hidden_size]
        model = cls(layer_sizes=layer_sizes, input_size=artifact.input_size, head_count=artifact.head_count, architecture="mlp")
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

    @classmethod
    def scratch(
        cls,
        *,
        architecture: str,
        layer_sizes: list[int],
        input_size: int,
        head_count: int,
        seed: int,
        scale: float,
        device: torch.device,
    ) -> "TorchPolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(layer_sizes=layer_sizes, input_size=input_size, head_count=head_count, architecture=architecture)
        with torch.no_grad():
            for name, parameter in model.named_parameters():
                if parameter.ndim >= 2:
                    nn.init.normal_(parameter, mean=0.0, std=scale)
                elif "norm" in name and name.endswith("weight"):
                    parameter.fill_(1.0)
                else:
                    parameter.zero_()
        return model.to(device)

    @classmethod
    def from_checkpoint(cls, path: Path, device: torch.device) -> "TorchPolicy":
        checkpoint = torch.load(path, map_location="cpu")
        model = cls(
            layer_sizes=list(checkpoint["layer_sizes"]),
            input_size=int(checkpoint.get("input_size", INPUT_SIZE)),
            head_count=int(checkpoint.get("head_count", HEAD_COUNT)),
            architecture=str(checkpoint["architecture"]),
        )
        model.load_state_dict(checkpoint["state_dict"])
        return model.to(device)

    @property
    def uses_object_tokens(self) -> bool:
        return self.architecture == "action-transformer"

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        if self.architecture == "mlp":
            value = features
            for layer in self.layers:
                value = torch.relu(layer(value))
            return self.output(value)
        value = torch.relu(self.input_projection(features))
        for block in self.blocks:
            value = block(value)
        return self.output(value)

    def candidate_scores(
        self,
        features: torch.Tensor,
        player_ids: torch.Tensor,
        action_heads: torch.Tensor,
        group_ids: torch.Tensor | None = None,
        object_batch: ObjectBatch | None = None,
    ) -> torch.Tensor:
        if self.architecture == "action-transformer":
            return self.action_transformer(features, player_ids, action_heads, group_ids, object_batch)
        outputs = self(features)
        head_tensor = _head_indices(action_heads.to(outputs.device), player_ids.to(outputs.device), self.head_count)
        return outputs.gather(1, head_tensor[:, None]).squeeze(1)

    def export_artifact(self, source: PolicyArtifact, path: Path, *, training_record: dict[str, Any] | None = None) -> None:
        if self.architecture != "mlp":
            raise ValueError("only mlp Torch policies can be exported to the C-compatible JSON artifact")
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

    def save_checkpoint(self, path: Path, *, training_record: dict[str, Any] | None = None) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-torch-policy-v1",
                "architecture": self.architecture,
                "layer_sizes": self.layer_sizes,
                "input_size": self.input_size,
                "head_count": self.head_count,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


def load_torch_policy(path: Path, device: torch.device) -> tuple[TorchPolicy, PolicyArtifact | None]:
    if path.suffix == ".pt":
        return TorchPolicy.from_checkpoint(path, device), None
    artifact = PolicyArtifact.load(path)
    return TorchPolicy.from_artifact(artifact, device), artifact


def _head_indices(action_heads: torch.Tensor, player_ids: torch.Tensor, head_count: int) -> torch.Tensor:
    if head_count == 16:
        return (player_ids * 4 + (action_heads % 4)).long()
    return action_heads.clamp(0, head_count - 1).long()


def _candidate_tensor(candidates: list[Any], input_size: int, device: torch.device) -> torch.Tensor:
    features = torch.zeros((len(candidates), input_size), dtype=torch.float32)
    for row, candidate in enumerate(candidates):
        for index in range(candidate.feature_count):
            column = int(candidate.feature_indices[index])
            if 0 <= column < input_size:
                features[row, column] = float(candidate.feature_values[index])
    return features.to(device)


def _object_id(value: int, offset: int, count: int) -> int:
    return max(0, min(count - 1, int(value) + offset))


def _object_token_batch(token_groups: list[list[KCObjectToken] | None], device: torch.device) -> ObjectBatch:
    group_count = len(token_groups)
    max_tokens = max(1, max((len(tokens) if tokens is not None else 0) for tokens in token_groups))
    type_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    owner_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    zone_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    suit_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    value_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    index_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    scalars = torch.zeros((group_count, max_tokens, OBJECT_SCALAR_COUNT), dtype=torch.float32)
    padding_mask = torch.ones((group_count, max_tokens), dtype=torch.bool)
    for group_index, tokens in enumerate(token_groups):
        if not tokens:
            continue
        for token_index, token in enumerate(tokens[:max_tokens]):
            type_ids[group_index, token_index] = _object_id(token.type, 0, OBJECT_TYPE_EMBEDDINGS)
            owner_ids[group_index, token_index] = _object_id(token.owner, 1, OBJECT_OWNER_EMBEDDINGS)
            zone_ids[group_index, token_index] = _object_id(token.zone, 0, OBJECT_ZONE_EMBEDDINGS)
            suit_ids[group_index, token_index] = _object_id(token.suit, 1, OBJECT_SUIT_EMBEDDINGS)
            value_ids[group_index, token_index] = _object_id(token.value, 0, OBJECT_VALUE_EMBEDDINGS)
            index_ids[group_index, token_index] = _object_id(token.index, 0, OBJECT_INDEX_EMBEDDINGS)
            for scalar_index in range(OBJECT_SCALAR_COUNT):
                scalars[group_index, token_index, scalar_index] = float(token.scalars[scalar_index])
            padding_mask[group_index, token_index] = False
    return (
        type_ids.to(device),
        owner_ids.to(device),
        zone_ids.to(device),
        suit_ids.to(device),
        value_ids.to(device),
        index_ids.to(device),
        scalars.to(device),
        padding_mask.to(device),
    )


def _candidate_scores(model: TorchPolicy, candidates: list[Any], player_id: int, object_tokens: list[KCObjectToken] | None = None) -> torch.Tensor:
    features = _candidate_tensor(candidates, model.input_size, next(model.parameters()).device)
    player_ids = torch.full((len(candidates),), int(player_id), dtype=torch.long, device=features.device)
    action_heads = torch.tensor([int(candidate.action_head) for candidate in candidates], dtype=torch.long, device=features.device)
    object_batch = _object_token_batch([object_tokens], features.device) if model.uses_object_tokens else None
    return model.candidate_scores(features, player_ids, action_heads, object_batch=object_batch)


def _choose_torch_action(
    model: TorchPolicy,
    candidates: list[Any],
    player_id: int,
    *,
    sample: bool,
    temperature: float,
    object_tokens: list[KCObjectToken] | None = None,
) -> tuple[KCAction, torch.Tensor | None]:
    scores = _candidate_scores(model, candidates, player_id, object_tokens)
    if sample:
        distribution = torch.distributions.Categorical(logits=scores / max(temperature, 0.05))
        selected = distribution.sample()
        return candidates[int(selected.item())].action, distribution.log_prob(selected)
    selected = int(torch.argmax(scores).item())
    return candidates[selected].action, None


def _batched_candidate_scores(
    model: TorchPolicy,
    groups: list[tuple[int, list[Any], int, list[KCObjectToken] | None]],
) -> tuple[torch.Tensor, list[tuple[int, int, int, list[Any]]]]:
    device = next(model.parameters()).device
    total_candidates = sum(len(candidates) for _, candidates, _, _ in groups)
    features = torch.zeros((total_candidates, model.input_size), dtype=torch.float32)
    player_ids = torch.empty((total_candidates,), dtype=torch.long)
    action_heads = torch.empty((total_candidates,), dtype=torch.long)
    group_ids = torch.empty((total_candidates,), dtype=torch.long)
    spans: list[tuple[int, int, int, list[Any]]] = []
    object_groups: list[list[KCObjectToken] | None] = []
    row = 0
    for group_index, (env_index, candidates, player_id, object_tokens) in enumerate(groups):
        start = row
        for candidate in candidates:
            for feature_index in range(candidate.feature_count):
                column = int(candidate.feature_indices[feature_index])
                if 0 <= column < model.input_size:
                    features[row, column] = float(candidate.feature_values[feature_index])
            player_ids[row] = int(player_id)
            action_heads[row] = int(candidate.action_head)
            group_ids[row] = group_index
            row += 1
        spans.append((env_index, start, row, candidates))
        object_groups.append(object_tokens)
    object_batch = _object_token_batch(object_groups, device) if model.uses_object_tokens else None
    return model.candidate_scores(
        features.to(device),
        player_ids.to(device),
        action_heads.to(device),
        group_ids.to(device),
        object_batch=object_batch,
    ), spans


def _winner(scores: list[int], medals: list[int]) -> int:
    best = 0
    for player_id in range(1, 4):
        if (scores[player_id], medals[player_id], player_id) > (scores[best], medals[best], best):
            best = player_id
    return best


def _curriculum_complete(engine: CEngine, pointer: Any, *, start_year: int, round_curriculum: bool) -> bool:
    return round_curriculum and engine.year(pointer) >= start_year + 2


def _game_result(
    engine: CEngine,
    pointer: Any,
    *,
    seed: int,
    seat: int,
    actions: int,
    log_probs: list[torch.Tensor],
) -> dict[str, Any]:
    scores = engine.final_scores(pointer)
    medals = engine.total_medals(pointer)
    winner = _winner(scores, medals)
    return {
        "seed": seed,
        "seat": seat,
        "actions": actions,
        "scores": scores,
        "medals": medals,
        "winner_id": winner,
        "metrics": asdict(_metrics(scores, medals, winner, seat)),
        "log_probs": log_probs,
    }


def run_torch_game(
    engine: CEngine,
    model: TorchPolicy,
    *,
    seed: int,
    model_seat: int,
    sample: bool = False,
    temperature: float = 1.0,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
) -> dict[str, Any]:
    pointer = engine.new_engine(
        seed,
        round_curriculum=round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
    )
    start_year = engine.year(pointer)
    log_probs: list[torch.Tensor] = []
    actions = 0
    try:
        for _ in range(2000):
            if _curriculum_complete(engine, pointer, start_year=start_year, round_curriculum=round_curriculum):
                return _game_result(
                    engine,
                    pointer,
                    seed=seed,
                    seat=model_seat,
                    actions=actions,
                    log_probs=log_probs,
                )
            player_id = engine.waiting_player(pointer)
            if player_id < 0:
                return _game_result(
                    engine,
                    pointer,
                    seed=seed,
                    seat=model_seat,
                    actions=actions,
                    log_probs=log_probs,
                )
            if player_id == model_seat:
                candidates = engine.policy_action_features(pointer, player_id=player_id, input_size=model.input_size)
                if candidates:
                    object_tokens = engine.object_tokens(pointer, perspective_player=player_id) if model.uses_object_tokens else None
                    action, log_prob = _choose_torch_action(
                        model,
                        candidates,
                        player_id,
                        sample=sample,
                        temperature=temperature,
                        object_tokens=object_tokens,
                    )
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


def run_torch_games_batched(
    engine: CEngine,
    model: TorchPolicy,
    *,
    seeds: list[int],
    seats: list[int],
    opponent_model: TorchPolicy | None = None,
    sample: bool = False,
    temperature: float = 1.0,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
) -> list[dict[str, Any]]:
    envs = []
    for seed, seat in zip(seeds, seats, strict=True):
        pointer = engine.new_engine(
            seed,
            round_curriculum=round_curriculum,
            round_plot_cards=round_plot_cards,
            round_famine_rate=round_famine_rate,
        )
        envs.append(
            {
                "pointer": pointer,
                "start_year": engine.year(pointer),
                "seed": seed,
                "seat": seat,
                "actions": 0,
                "log_probs": [],
                "done": False,
            }
        )
    complete: list[dict[str, Any] | None] = [None] * len(envs)
    try:
        for _ in range(2000):
            if all(env["done"] for env in envs):
                return [item for item in complete if item is not None]

            model_groups: list[tuple[int, list[Any], int, list[KCObjectToken] | None]] = []
            opponent_groups: list[tuple[int, list[Any], int, list[KCObjectToken] | None]] = []
            progressed = False
            for env_index, env in enumerate(envs):
                if env["done"]:
                    continue
                pointer = env["pointer"]
                if _curriculum_complete(engine, pointer, start_year=int(env["start_year"]), round_curriculum=round_curriculum):
                    complete[env_index] = _game_result(
                        engine,
                        pointer,
                        seed=int(env["seed"]),
                        seat=int(env["seat"]),
                        actions=int(env["actions"]),
                        log_probs=env["log_probs"],
                    )
                    env["done"] = True
                    engine.free_engine(pointer)
                    progressed = True
                    continue
                player_id = engine.waiting_player(pointer)
                if player_id < 0:
                    complete[env_index] = _game_result(
                        engine,
                        pointer,
                        seed=int(env["seed"]),
                        seat=int(env["seat"]),
                        actions=int(env["actions"]),
                        log_probs=env["log_probs"],
                    )
                    env["done"] = True
                    engine.free_engine(pointer)
                    progressed = True
                    continue
                if player_id == env["seat"]:
                    candidates = engine.policy_action_features(pointer, player_id=player_id, input_size=model.input_size)
                    if candidates:
                        object_tokens = engine.object_tokens(pointer, perspective_player=player_id) if model.uses_object_tokens else None
                        model_groups.append((env_index, candidates, player_id, object_tokens))
                        continue
                elif opponent_model is not None:
                    candidates = engine.policy_action_features(pointer, player_id=player_id, input_size=opponent_model.input_size)
                    if candidates:
                        object_tokens = engine.object_tokens(pointer, perspective_player=player_id) if opponent_model.uses_object_tokens else None
                        opponent_groups.append((env_index, candidates, player_id, object_tokens))
                        continue
                action = engine.heuristic_action(pointer)
                engine.apply_policy_action(pointer, action)
                env["actions"] = int(env["actions"]) + 1
                progressed = True

            def apply_scored_groups(policy: TorchPolicy, groups: list[tuple[int, list[Any], int, list[KCObjectToken] | None]], trainable: bool) -> None:
                nonlocal progressed
                if not groups:
                    return
                scores, spans = _batched_candidate_scores(policy, groups)
                for env_index, start, end, candidates in spans:
                    logits = scores[start:end]
                    if sample and trainable:
                        distribution = torch.distributions.Categorical(logits=logits / max(temperature, 0.05))
                        selected_tensor = distribution.sample()
                        selected = int(selected_tensor.item())
                        envs[env_index]["log_probs"].append(distribution.log_prob(selected_tensor))
                    else:
                        selected = int(torch.argmax(logits).item())
                    engine.apply_policy_action(envs[env_index]["pointer"], candidates[selected].action)
                    envs[env_index]["actions"] = int(envs[env_index]["actions"]) + 1
                progressed = True

            if sample:
                apply_scored_groups(model, model_groups, True)
            else:
                with torch.no_grad():
                    apply_scored_groups(model, model_groups, True)
            if opponent_model is not None:
                with torch.no_grad():
                    apply_scored_groups(opponent_model, opponent_groups, False)

            if not progressed:
                raise RuntimeError("batched Torch rollout made no progress")
    finally:
        for env in envs:
            if not env["done"]:
                engine.free_engine(env["pointer"])
                env["done"] = True
    raise RuntimeError("batched Torch policy games exceeded guard limit")


def torch_parity(
    engine: CEngine,
    *,
    model_path: Path,
    games_per_seat: int,
    seed: int,
    prefer_mps: bool,
    rollout_envs: int = 64,
) -> dict[str, Any]:
    artifact = PolicyArtifact.load(model_path)
    device = best_device(prefer_mps)
    model = TorchPolicy.from_artifact(artifact, device).eval()
    records = []
    same_winner = 0
    same_scores = 0
    scheduled = [
        (seed + seat * games_per_seat + offset, seat)
        for seat in range(4)
        for offset in range(games_per_seat)
    ]
    for start in range(0, len(scheduled), max(1, rollout_envs)):
        chunk = scheduled[start:start + max(1, rollout_envs)]
        torch_games = run_torch_games_batched(
            engine,
            model,
            seeds=[item[0] for item in chunk],
            seats=[item[1] for item in chunk],
        )
        for torch_game in torch_games:
            game_seed = int(torch_game["seed"])
            seat = int(torch_game["seat"])
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


def torch_benchmark_candidate(
    engine: CEngine,
    *,
    candidate_path: Path,
    baseline_path: Path | None,
    games_per_seat: int,
    seed: int,
    bootstrap_samples: int,
    min_win_delta: float = 0.0,
    min_rank_delta: float = 0.0,
    min_margin_delta: float = 0.0,
    prefer_mps: bool,
    rollout_envs: int = 64,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    include_games: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    candidate, _ = load_torch_policy(candidate_path, device)
    candidate.eval()
    baseline = None
    if baseline_path is not None:
        baseline, _ = load_torch_policy(baseline_path, device)
        baseline.eval()

    scheduled = [
        (seed + seat * games_per_seat + offset, seat)
        for seat in range(4)
        for offset in range(games_per_seat)
    ]
    candidate_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    baseline_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    games: list[dict[str, Any]] = []

    chunk_size = max(1, rollout_envs)
    for start in range(0, len(scheduled), chunk_size):
        chunk = scheduled[start:start + chunk_size]
        candidate_games = run_torch_games_batched(
            engine,
            candidate,
            seeds=[item[0] for item in chunk],
            seats=[item[1] for item in chunk],
            opponent_model=baseline,
            round_curriculum=round_curriculum,
            round_plot_cards=round_plot_cards,
            round_famine_rate=round_famine_rate,
        )
        for game in candidate_games:
            candidate_games_by_key[(int(game["seed"]), int(game["seat"]))] = game

        if baseline is None:
            for game_seed, seat in chunk:
                baseline_games_by_key[(game_seed, seat)] = run_policy_game(
                    engine,
                    seed=game_seed,
                    model=None,
                    model_is_heuristic=True,
                    opponent=None,
                    opponent_is_heuristic=True,
                    seat=seat,
                    round_curriculum=round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                )
        else:
            baseline_games = run_torch_games_batched(
                engine,
                baseline,
                seeds=[item[0] for item in chunk],
                seats=[item[1] for item in chunk],
                opponent_model=baseline,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
            for game in baseline_games:
                baseline_games_by_key[(int(game["seed"]), int(game["seat"]))] = game
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "torch_policy_benchmark",
                    "status": "running",
                    "phase": "benchmark",
                    "candidate_model": str(candidate_path),
                    "baseline_model": str(baseline_path) if baseline_path else "heuristic",
                    "candidate_architecture": candidate.architecture,
                    "baseline_architecture": baseline.architecture if baseline is not None else "heuristic",
                    "device": str(device),
                    "round_curriculum": round_curriculum,
                    "curriculum_rounds": 2 if round_curriculum else None,
                    "round_plot_cards": round_plot_cards,
                    "round_famine_rate": round_famine_rate,
                    "progress": {
                        "completed_games": min(start + chunk_size, len(scheduled)),
                        "total_games": len(scheduled),
                        "percent": min(1.0, (start + chunk_size) / len(scheduled)) if scheduled else 1.0,
                    },
                }
            )

    records = []
    for game_seed, seat in scheduled:
        candidate_game = candidate_games_by_key[(game_seed, seat)]
        baseline_game = baseline_games_by_key[(game_seed, seat)]
        candidate_metrics = candidate_game["metrics"]
        baseline_metrics = baseline_game["metrics"]
        records.append(
            {
                "seed": game_seed,
                "seat": seat,
                "win_delta": candidate_metrics["win"] - baseline_metrics["win"],
                "rank_delta": baseline_metrics["rank"] - candidate_metrics["rank"],
                "margin_delta": candidate_metrics["margin"] - baseline_metrics["margin"],
                "candidate": candidate_metrics,
                "baseline": baseline_metrics,
            }
        )
        if include_games:
            games.append({"candidate": candidate_game, "baseline": baseline_game})

    win_values = [record["win_delta"] for record in records]
    rank_values = [record["rank_delta"] for record in records]
    margin_values = [record["margin_delta"] for record in records]
    intervals = {
        "win_delta": _ci(win_values, bootstrap_samples, seed ^ 0xC00A),
        "rank_delta": _ci(rank_values, bootstrap_samples, seed ^ 0xC00B),
        "margin_delta": _ci(margin_values, bootstrap_samples, seed ^ 0xC00C),
    }
    pass_gate = (
        intervals["win_delta"]["low"] >= min_win_delta
        and intervals["rank_delta"]["low"] >= min_rank_delta
        and intervals["margin_delta"]["low"] >= min_margin_delta
    )
    record: dict[str, Any] = {
        "kind": "torch_policy_benchmark",
        "candidate_model": str(candidate_path),
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "candidate_architecture": candidate.architecture,
        "baseline_architecture": baseline.architecture if baseline is not None else "heuristic",
        "device": str(device),
        "rollout_envs": chunk_size,
        "round_curriculum": round_curriculum,
        "curriculum_rounds": 2 if round_curriculum else None,
        "round_plot_cards": round_plot_cards,
        "round_famine_rate": round_famine_rate,
        "games_per_seat": games_per_seat,
        "total_games": len(records),
        "seed": seed,
        "thresholds": {
            "min_win_delta": min_win_delta,
            "min_rank_delta": min_rank_delta,
            "min_margin_delta": min_margin_delta,
        },
        "intervals": intervals,
        "summary": {
            "candidate_win_rate": _mean([record["candidate"]["win"] for record in records]),
            "baseline_win_rate": _mean([record["baseline"]["win"] for record in records]),
            "candidate_average_rank": _mean([record["candidate"]["rank"] for record in records]),
            "baseline_average_rank": _mean([record["baseline"]["rank"] for record in records]),
            "candidate_average_margin": _mean([record["candidate"]["margin"] for record in records]),
            "baseline_average_margin": _mean([record["baseline"]["margin"] for record in records]),
        },
        "status": "passed_gate" if pass_gate else "rejected",
    }
    if include_games:
        record["games"] = games
    return record


def _torch_training_progress(
    *,
    model: TorchPolicy,
    device: torch.device,
    start_model_path: Path | None,
    output_path: Path,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    rollout_envs: int,
    unbatched: bool,
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
    completed: int,
    episode_records: list[dict[str, Any]],
    status: str,
) -> dict[str, Any]:
    recent = episode_records[-min(32, len(episode_records)):]
    summary = {
        "average_reward": _mean([item["reward"] for item in recent]),
        "top_rate": _mean([item["win"] for item in recent]),
        "average_rank": _mean([item["rank"] for item in recent]),
        "average_margin": _mean([item["margin"] for item in recent]),
    } if recent else {}
    return {
        "kind": "torch_policy_training",
        "status": status,
        "phase": "training",
        "backend": "torch-mps" if device.type == "mps" else "torch",
        "start_model": str(start_model_path) if start_model_path else "scratch",
        "output_model": str(output_path),
        "device": str(device),
        "model": {
            "architecture": model.architecture,
            "layers": model.layer_sizes,
            "input_size": model.input_size,
            "head_count": model.head_count,
        },
        "training": {
            "episodes": episodes,
            "batch_size": batch_size,
            "seed": seed,
            "learning_rate": learning_rate,
            "temperature": temperature,
            "rollout_envs": 1 if unbatched else rollout_envs,
            "batched_rollouts": not unbatched,
            "round_curriculum": round_curriculum,
            "curriculum_rounds": 2 if round_curriculum else None,
            "round_plot_cards": round_plot_cards,
            "round_famine_rate": round_famine_rate,
        },
        "progress": {
            "completed_episodes": completed,
            "total_episodes": episodes,
            "percent": min(1.0, completed / episodes) if episodes else 1.0,
        },
        "curve": _training_curve(episode_records),
        "summary": summary,
    }


def _training_curve(episode_records: list[dict[str, Any]], max_points: int = 800) -> dict[str, Any]:
    if not episode_records:
        return {"points": [], "sampled": False, "source_episodes": 0}
    stride = max(1, (len(episode_records) + max_points - 1) // max_points)
    points = []
    for index, item in enumerate(episode_records):
        if index % stride != 0 and index != len(episode_records) - 1:
            continue
        points.append(
            {
                "episode": int(item["episode"]),
                "reward": float(item["reward"]),
                "win": float(item["win"]),
                "rank": float(item["rank"]),
                "margin": float(item["margin"]),
            }
        )
    return {
        "points": points,
        "sampled": stride > 1,
        "source_episodes": len(episode_records),
    }


def train_torch_policy(
    engine: CEngine,
    *,
    start_model_path: Path | None,
    output_path: Path,
    architecture: str,
    layer_sizes: list[int],
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
    rollout_envs: int,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    unbatched: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    artifact: PolicyArtifact | None = None
    if start_model_path is None:
        model = TorchPolicy.scratch(
            architecture=architecture,
            layer_sizes=layer_sizes,
            input_size=INPUT_SIZE,
            head_count=HEAD_COUNT,
            seed=scratch_seed,
            scale=scratch_scale,
            device=device,
        )
    else:
        model, artifact = load_torch_policy(start_model_path, device)
    model.train()
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    episode_records = []
    pending_losses: list[torch.Tensor] = []
    completed = 0
    if progress_callback is not None:
        progress_callback(
            _torch_training_progress(
                model=model,
                device=device,
                start_model_path=start_model_path,
                output_path=output_path,
                episodes=episodes,
                batch_size=batch_size,
                seed=seed,
                learning_rate=learning_rate,
                temperature=temperature,
                rollout_envs=rollout_envs,
                unbatched=unbatched,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
                completed=completed,
                episode_records=episode_records,
                status="running",
            )
        )
    while completed < episodes:
        count = 1 if unbatched else min(max(1, rollout_envs), episodes - completed)
        seeds = [seed + completed + offset for offset in range(count)]
        seats = [(completed + offset) % 4 for offset in range(count)]
        games = [
            run_torch_game(
                engine,
                model,
                seed=seeds[0],
                model_seat=seats[0],
                sample=True,
                temperature=temperature,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
        ] if unbatched else run_torch_games_batched(
            engine,
            model,
            seeds=seeds,
            seats=seats,
            sample=True,
            temperature=temperature,
            round_curriculum=round_curriculum,
            round_plot_cards=round_plot_cards,
            round_famine_rate=round_famine_rate,
        )
        for game in games:
            metrics = game["metrics"]
            reward = metrics["win"] - 0.25 * (metrics["rank"] - 1.0) + 0.02 * metrics["margin"]
            if game["log_probs"]:
                loss = -torch.stack(game["log_probs"]).sum() * float(reward)
                pending_losses.append(loss)
            episode_records.append(
                {
                    "episode": len(episode_records) + 1,
                    "seed": game["seed"],
                    "seat": game["seat"],
                    "reward": float(reward),
                    "win": metrics["win"],
                    "rank": metrics["rank"],
                    "margin": metrics["margin"],
                }
            )
        completed += len(games)
        if progress_callback is not None:
            progress_callback(
                _torch_training_progress(
                    model=model,
                    device=device,
                    start_model_path=start_model_path,
                    output_path=output_path,
                    episodes=episodes,
                    batch_size=batch_size,
                    seed=seed,
                    learning_rate=learning_rate,
                    temperature=temperature,
                    rollout_envs=rollout_envs,
                    unbatched=unbatched,
                    round_curriculum=round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    completed=completed,
                    episode_records=episode_records,
                    status="running",
                )
            )
        if pending_losses and (len(pending_losses) >= batch_size or completed >= episodes):
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
        "start_model": str(start_model_path) if start_model_path else "scratch",
        "output_model": str(output_path),
        "device": str(device),
        "model": {
            "architecture": model.architecture,
            "layers": model.layer_sizes,
            "input_size": model.input_size,
            "head_count": model.head_count,
            "scratch_seed": scratch_seed if start_model_path is None else None,
            "scratch_scale": scratch_scale if start_model_path is None else None,
        },
        "training": {
            "episodes": episodes,
            "batch_size": batch_size,
            "seed": seed,
            "learning_rate": learning_rate,
            "temperature": temperature,
            "rollout_envs": 1 if unbatched else rollout_envs,
            "batched_rollouts": not unbatched,
            "round_curriculum": round_curriculum,
            "curriculum_rounds": 2 if round_curriculum else None,
            "round_plot_cards": round_plot_cards,
            "round_famine_rate": round_famine_rate,
        },
        "summary": summary,
        "curve": _training_curve(episode_records),
        "status": "trained",
    }
    if output_path.suffix == ".pt":
        model.save_checkpoint(output_path, training_record=record)
    elif artifact is not None:
        model.export_artifact(artifact, output_path, training_record=record)
    else:
        raise ValueError("scratch Torch policies must be saved as .pt checkpoints")
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "training",
                "progress": {
                    "completed_episodes": episodes,
                    "total_episodes": episodes,
                    "percent": 1.0,
                },
            }
        )
    return record
