from __future__ import annotations

import json
import hashlib
import itertools
import math
import random
from dataclasses import asdict
from pathlib import Path
from typing import Any, Callable

import torch
from torch import nn
from torch.nn import functional as F

from .benchmark import (
    _ci,
    _margin_shape,
    _mean,
    _metrics,
    _promotion_decision,
    run_policy_game,
)
from .c_engine import (
    ACTION_SCALAR_COUNT,
    CEngine,
    DenseObjectTokens,
    DensePolicyActionFeatures,
    KCAction,
    KCCard,
    KCObjectToken,
    OBJECT_SCALAR_COUNT,
)
from .history import append_history
from .model import FEATURE_VERSION, HEAD_COUNT, INPUT_SIZE, PolicyArtifact

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
    torch.Tensor,
]

ActionBatch = tuple[
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
]

ACTION_KIND_EMBEDDINGS = 10
ACTION_PLAYER_EMBEDDINGS = 6
ACTION_SUIT_EMBEDDINGS = 6
ACTION_VALUE_EMBEDDINGS = 16
ACTION_ZONE_EMBEDDINGS = 16

KC_PHASE_TRICK = 2
KC_PHASE_ASSIGNMENT = 3
KC_PHASE_REQUISITION = 4
KC_PHASE_GAME_OVER = 5

KC_PHASE_NAMES = {
    0: "planning",
    1: "swap",
    2: "trick",
    3: "assignment",
    4: "requisition",
    5: "game_over",
}


def _phase_name(phase_id: int | None) -> str:
    if phase_id is None:
        return "unknown"
    return KC_PHASE_NAMES.get(int(phase_id), f"phase_{int(phase_id)}")


def _zip_strict(*iterables: Any):
    sentinel = object()
    for items in itertools.zip_longest(*iterables, fillvalue=sentinel):
        if any(item is sentinel for item in items):
            raise ValueError("zip arguments have different lengths")
        yield items


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


class ResidualLayerNormBlock(nn.Module):
    def __init__(self, width: int) -> None:
        super().__init__()
        self.norm = nn.LayerNorm(width)
        self.layers = nn.Sequential(
            nn.Linear(width, width),
            nn.GELU(),
            nn.Linear(width, width),
        )

    def forward(self, value: torch.Tensor) -> torch.Tensor:
        return torch.relu(value + self.layers(self.norm(value)))


class ActionTransformer(nn.Module):
    def __init__(
        self,
        input_size: int,
        head_count: int,
        layer_sizes: list[int],
        transformer_dropout: float = 0.05,
    ) -> None:
        super().__init__()
        if not layer_sizes:
            raise ValueError("action-transformer requires at least a model width")
        if transformer_dropout < 0.0 or transformer_dropout > 1.0:
            raise ValueError("action-transformer dropout must be between 0.0 and 1.0")
        width = int(layer_sizes[0])
        depth = int(layer_sizes[1]) if len(layer_sizes) > 1 else 4
        heads = int(layer_sizes[2]) if len(layer_sizes) > 2 else 4
        feedforward = int(layer_sizes[3]) if len(layer_sizes) > 3 else width * 4
        if width <= 0 or depth <= 0 or heads <= 0 or feedforward <= 0:
            raise ValueError(
                "action-transformer width, depth, heads, and feedforward must be positive"
            )
        if width % heads != 0:
            raise ValueError(
                "action-transformer width must be divisible by attention heads"
            )
        self.width = width
        self.depth = depth
        self.heads = heads
        self.feedforward = feedforward
        self.transformer_dropout = transformer_dropout
        self.head_count = head_count
        self.feature_projection = nn.Sequential(
            nn.Linear(input_size, width),
            nn.LayerNorm(width),
            nn.GELU(),
            nn.Linear(width, width),
        )
        self.player_embedding = nn.Embedding(4, width)
        self.action_embedding = nn.Embedding(max(head_count, 16), width)
        self.action_kind_embedding = nn.Embedding(ACTION_KIND_EMBEDDINGS, width)
        self.action_player_embedding = nn.Embedding(ACTION_PLAYER_EMBEDDINGS, width)
        self.action_suit_embedding = nn.Embedding(ACTION_SUIT_EMBEDDINGS, width)
        self.action_value_embedding = nn.Embedding(ACTION_VALUE_EMBEDDINGS, width)
        self.action_zone_embedding = nn.Embedding(ACTION_ZONE_EMBEDDINGS, width)
        self.action_scalar_projection = nn.Sequential(
            nn.Linear(ACTION_SCALAR_COUNT, width),
            nn.LayerNorm(width),
            nn.GELU(),
            nn.Linear(width, width),
        )
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
            dropout=transformer_dropout,
            activation="gelu",
            batch_first=True,
            norm_first=True,
        )
        self.encoder = nn.TransformerEncoder(
            layer, num_layers=depth, enable_nested_tensor=False
        )
        self.scorer = nn.Sequential(
            nn.LayerNorm(width * 2),
            nn.Linear(width * 2, width),
            nn.GELU(),
            nn.Linear(width, 1),
        )
        self.phase_scorers = nn.ModuleList(
            [
                nn.Sequential(
                    nn.LayerNorm(width * 2),
                    nn.Linear(width * 2, width),
                    nn.GELU(),
                    nn.Linear(width, 1),
                )
                for _ in range(max(4, head_count))
            ]
        )
        self.value_head = nn.Sequential(
            nn.LayerNorm(width),
            nn.Linear(width, width),
            nn.GELU(),
            nn.Linear(width, 1),
        )

    def _object_embeddings(self, object_batch: ObjectBatch) -> torch.Tensor:
        type_ids, owner_ids, zone_ids, suit_ids, value_ids, index_ids, scalars, _ = (
            object_batch
        )
        return (
            self.object_type_embedding(
                type_ids.clamp(0, self.object_type_embedding.num_embeddings - 1)
            )
            + self.object_owner_embedding(
                owner_ids.clamp(0, self.object_owner_embedding.num_embeddings - 1)
            )
            + self.object_zone_embedding(
                zone_ids.clamp(0, self.object_zone_embedding.num_embeddings - 1)
            )
            + self.object_suit_embedding(
                suit_ids.clamp(0, self.object_suit_embedding.num_embeddings - 1)
            )
            + self.object_value_embedding(
                value_ids.clamp(0, self.object_value_embedding.num_embeddings - 1)
            )
            + self.object_index_embedding(
                index_ids.clamp(0, self.object_index_embedding.num_embeddings - 1)
            )
            + self.object_scalar_projection(scalars)
        )

    def _action_embeddings(self, action_batch: ActionBatch) -> torch.Tensor:
        (
            kind_ids,
            player_ids,
            suit_ids,
            target_suit_ids,
            card_suit_ids,
            card_value_ids,
            hand_suit_ids,
            hand_value_ids,
            plot_suit_ids,
            plot_value_ids,
            plot_zone_ids,
            action_scalars,
        ) = action_batch
        suit_limit = self.action_suit_embedding.num_embeddings - 1
        value_limit = self.action_value_embedding.num_embeddings - 1
        return (
            self.action_kind_embedding(
                kind_ids.clamp(0, self.action_kind_embedding.num_embeddings - 1)
            )
            + self.action_player_embedding(
                player_ids.clamp(0, self.action_player_embedding.num_embeddings - 1)
            )
            + self.action_suit_embedding(suit_ids.clamp(0, suit_limit))
            + self.action_suit_embedding(target_suit_ids.clamp(0, suit_limit))
            + self.action_suit_embedding(card_suit_ids.clamp(0, suit_limit))
            + self.action_value_embedding(card_value_ids.clamp(0, value_limit))
            + self.action_suit_embedding(hand_suit_ids.clamp(0, suit_limit))
            + self.action_value_embedding(hand_value_ids.clamp(0, value_limit))
            + self.action_suit_embedding(plot_suit_ids.clamp(0, suit_limit))
            + self.action_value_embedding(plot_value_ids.clamp(0, value_limit))
            + self.action_zone_embedding(
                plot_zone_ids.clamp(0, self.action_zone_embedding.num_embeddings - 1)
            )
            + self.action_scalar_projection(action_scalars.float())
        )

    def forward(
        self,
        features: torch.Tensor,
        player_ids: torch.Tensor,
        action_heads: torch.Tensor,
        group_ids: torch.Tensor | None,
        object_batch: ObjectBatch | None = None,
        action_batch: ActionBatch | None = None,
        return_values: bool = False,
        group_count: int | None = None,
        action_slot_count: int | None = None,
    ) -> torch.Tensor | tuple[torch.Tensor, torch.Tensor]:
        if features.numel() == 0:
            scores = torch.empty((0,), dtype=features.dtype, device=features.device)
            values = torch.empty((0,), dtype=features.dtype, device=features.device)
            return (scores, values) if return_values else scores
        player_ids = player_ids.to(features.device).clamp(0, 3)
        head_indices = _head_indices(
            action_heads.to(features.device), player_ids, self.head_count
        )
        tokens = (
            self.feature_projection(features)
            + self.player_embedding(player_ids)
            + self.action_embedding(
                head_indices.clamp(0, self.action_embedding.num_embeddings - 1)
            )
        )
        if action_batch is not None:
            action_batch = tuple(item.to(tokens.device) for item in action_batch)  # type: ignore[assignment]
            tokens = tokens + self._action_embeddings(action_batch)
        if group_ids is None:
            group_ids = torch.zeros(
                (features.shape[0],), dtype=torch.long, device=features.device
            )
        else:
            group_ids = group_ids.to(features.device)
        if group_count is None:
            group_count = int(group_ids.max().item()) + 1
        lengths = torch.bincount(group_ids, minlength=group_count)
        if action_slot_count is None:
            action_slot_count = int(lengths.max().item())
        object_embeddings = None
        object_mask = None
        object_count = 0
        if object_batch is not None:
            object_batch = tuple(item.to(tokens.device) for item in object_batch)  # type: ignore[assignment]
            object_embeddings = self._object_embeddings(object_batch)
            object_mask = object_batch[-1].bool()
            object_count = int(object_embeddings.shape[1])
        sequence = torch.zeros(
            (group_count, action_slot_count + object_count + 1, self.width),
            dtype=tokens.dtype,
            device=tokens.device,
        )
        mask = torch.ones(
            (group_count, action_slot_count + object_count + 1),
            dtype=torch.bool,
            device=tokens.device,
        )
        sequence[:, 0:1, :] = self.cls_token.expand(group_count, -1, -1)
        mask[:, 0] = False
        if (
            object_embeddings is not None
            and object_mask is not None
            and object_count > 0
        ):
            sequence[:, 1 : object_count + 1, :] = object_embeddings
            mask[:, 1 : object_count + 1] = object_mask
        action_start = object_count + 1
        starts = torch.cumsum(lengths, dim=0) - lengths
        action_positions = (
            torch.arange(tokens.shape[0], dtype=torch.long, device=tokens.device)
            - starts[group_ids]
        )
        sequence[group_ids, action_start + action_positions, :] = tokens
        mask[group_ids, action_start + action_positions] = False
        encoded = self.encoder(sequence, src_key_padding_mask=mask)
        values = self.value_head(encoded[:, 0]).squeeze(1)
        action_tokens = encoded[group_ids, action_start + action_positions, :]
        global_tokens = encoded[group_ids, 0, :]
        score_features = torch.cat([action_tokens, global_tokens], dim=1)
        scores = self.scorer(score_features).squeeze(1)
        phase_scores = torch.cat(
            [scorer(score_features) for scorer in self.phase_scorers], dim=1
        )
        phase_indices = action_heads.to(phase_scores.device).clamp(
            0, len(self.phase_scorers) - 1
        )
        scores = scores + phase_scores.gather(1, phase_indices[:, None]).squeeze(1)
        return (scores, values) if return_values else scores


def _zero_final_linear(module: nn.Module) -> None:
    for child in reversed(list(module.modules())):
        if isinstance(child, nn.Linear):
            with torch.no_grad():
                child.weight.zero_()
                if child.bias is not None:
                    child.bias.zero_()
            return


class TorchPolicy(nn.Module):
    def __init__(
        self,
        layer_sizes: list[int],
        input_size: int = INPUT_SIZE,
        head_count: int = HEAD_COUNT,
        architecture: str = "mlp",
        transformer_dropout: float = 0.05,
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.head_count = head_count
        self.architecture = architecture
        self.transformer_dropout = (
            transformer_dropout if architecture == "action-transformer" else None
        )
        self.layer_sizes = layer_sizes
        self.layers = nn.ModuleList()
        if architecture == "mlp":
            previous = input_size
            for size in layer_sizes:
                self.layers.append(nn.Linear(previous, size))
                previous = size
            self.output = nn.Linear(previous, head_count)
            self.value_output = nn.Linear(previous, 1)
        elif architecture == "residual-mlp":
            if not layer_sizes:
                raise ValueError("residual-mlp requires at least one layer size")
            width = layer_sizes[0]
            if any(size != width for size in layer_sizes):
                raise ValueError(
                    "residual-mlp requires equal layer sizes; depth is the number of sizes"
                )
            self.input_projection = nn.Linear(input_size, width)
            self.blocks = nn.ModuleList([ResidualBlock(width) for _ in layer_sizes])
            self.output = nn.Linear(width, head_count)
            self.value_output = nn.Linear(width, 1)
        elif architecture == "residual-layernorm-mlp":
            if not layer_sizes:
                raise ValueError(
                    "residual-layernorm-mlp requires at least one layer size"
                )
            width = layer_sizes[-1]
            if any(size != width for size in layer_sizes):
                raise ValueError(
                    "residual-layernorm-mlp requires equal layer sizes; depth is the number of sizes"
                )
            previous = input_size
            for size in layer_sizes:
                self.layers.append(nn.Linear(previous, size))
                previous = size
            self.blocks = nn.ModuleList(
                [ResidualLayerNormBlock(width) for _ in layer_sizes]
            )
            self.output = nn.Linear(width, head_count)
            self.value_output = nn.Linear(width, 1)
        elif architecture == "action-transformer":
            self.action_transformer = ActionTransformer(
                input_size=input_size,
                head_count=head_count,
                layer_sizes=layer_sizes,
                transformer_dropout=transformer_dropout,
            )
        else:
            raise ValueError(f"unknown Torch policy architecture {architecture!r}")

    @classmethod
    def from_artifact(
        cls, artifact: PolicyArtifact, device: torch.device
    ) -> "TorchPolicy":
        if artifact.layer_sizes:
            layer_sizes = artifact.layer_sizes
        else:
            layer_sizes = [artifact.hidden_size]
        model = cls(
            layer_sizes=layer_sizes,
            input_size=artifact.input_size,
            head_count=artifact.head_count,
            architecture="mlp",
        )
        with torch.no_grad():
            if artifact.layer_sizes:
                hidden_weights = artifact.data["hidden_weights"]
                hidden_biases = artifact.data["hidden_biases"]
                for index, layer in enumerate(model.layers):
                    layer.weight.copy_(
                        torch.tensor(
                            hidden_weights[index], dtype=torch.float32
                        ).reshape(layer.out_features, layer.in_features)
                    )
                    layer.bias.copy_(
                        torch.tensor(hidden_biases[index], dtype=torch.float32)
                    )
                model.output.weight.copy_(
                    torch.tensor(
                        artifact.data["output_weights"], dtype=torch.float32
                    ).reshape(model.head_count, model.layers[-1].out_features)
                )
            else:
                model.layers[0].weight.copy_(
                    torch.tensor(artifact.data["w1"], dtype=torch.float32).reshape(
                        model.layers[0].out_features, model.input_size
                    )
                )
                model.layers[0].bias.copy_(
                    torch.tensor(artifact.data["b1"], dtype=torch.float32)
                )
                model.output.weight.copy_(
                    torch.tensor(artifact.data["w2"], dtype=torch.float32).reshape(
                        model.head_count, model.layers[-1].out_features
                    )
                )
            b2s = (
                artifact.data.get("b2s")
                or [float(artifact.data.get("b2", 0.0))] * model.head_count
            )
            model.output.bias.copy_(torch.tensor(b2s, dtype=torch.float32))
            model.value_output.weight.zero_()
            model.value_output.bias.zero_()
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
        transformer_dropout: float = 0.05,
    ) -> "TorchPolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(
            layer_sizes=layer_sizes,
            input_size=input_size,
            head_count=head_count,
            architecture=architecture,
            transformer_dropout=transformer_dropout,
        )
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
        transformer_dropout = checkpoint.get("transformer_dropout", 0.05)
        if transformer_dropout is None:
            transformer_dropout = 0.05
        model = cls(
            layer_sizes=list(checkpoint["layer_sizes"]),
            input_size=int(checkpoint.get("input_size", INPUT_SIZE)),
            head_count=int(checkpoint.get("head_count", HEAD_COUNT)),
            architecture=str(checkpoint["architecture"]),
            transformer_dropout=float(transformer_dropout),
        )
        incompatible = model.load_state_dict(checkpoint["state_dict"], strict=False)
        if incompatible.unexpected_keys:
            raise RuntimeError(
                f"unexpected checkpoint keys in {path}: {incompatible.unexpected_keys}"
            )
        missing_keys = list(incompatible.missing_keys)
        if any(
            key.startswith("action_transformer.action_scalar_projection.")
            for key in missing_keys
        ):
            _zero_final_linear(model.action_transformer.action_scalar_projection)
        if any(
            key.startswith("action_transformer.phase_scorers.")
            for key in missing_keys
        ):
            for scorer in model.action_transformer.phase_scorers:
                _zero_final_linear(scorer)
        return model.to(device)

    def set_transformer_dropout(self, dropout: float) -> None:
        if self.architecture != "action-transformer":
            return
        if dropout < 0.0 or dropout > 1.0:
            raise ValueError("action-transformer dropout must be between 0.0 and 1.0")
        self.transformer_dropout = dropout
        self.action_transformer.transformer_dropout = dropout
        for module in self.action_transformer.modules():
            if isinstance(module, nn.Dropout):
                module.p = dropout

    @property
    def uses_object_tokens(self) -> bool:
        return self.architecture == "action-transformer"

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        return self.policy_logits(features)

    def _hidden_features(self, features: torch.Tensor) -> torch.Tensor:
        if self.architecture == "mlp":
            value = features
            for layer in self.layers:
                value = torch.relu(layer(value))
            return value
        if self.architecture == "residual-layernorm-mlp":
            value = features
            for layer in self.layers:
                value = torch.relu(layer(value))
            for block in self.blocks:
                value = block(value)
            return value
        value = torch.relu(self.input_projection(features))
        for block in self.blocks:
            value = block(value)
        return value

    def policy_logits(self, features: torch.Tensor) -> torch.Tensor:
        return self.output(self._hidden_features(features))

    def value_estimates(
        self, features: torch.Tensor, group_ids: torch.Tensor | None = None
    ) -> torch.Tensor:
        values = self.value_output(self._hidden_features(features)).squeeze(1)
        if group_ids is None:
            return values.mean().reshape(1)
        group_ids = group_ids.to(values.device)
        group_count = int(group_ids.max().item()) + 1 if group_ids.numel() else 0
        grouped = torch.zeros((group_count,), dtype=values.dtype, device=values.device)
        counts = torch.zeros((group_count,), dtype=values.dtype, device=values.device)
        grouped.scatter_add_(0, group_ids, values)
        counts.scatter_add_(0, group_ids, torch.ones_like(values))
        return grouped / counts.clamp_min(1.0)

    def candidate_scores(
        self,
        features: torch.Tensor,
        player_ids: torch.Tensor,
        action_heads: torch.Tensor,
        group_ids: torch.Tensor | None = None,
        object_batch: ObjectBatch | None = None,
        action_batch: ActionBatch | None = None,
        group_count: int | None = None,
        action_slot_count: int | None = None,
    ) -> torch.Tensor:
        if self.architecture == "action-transformer":
            return self.action_transformer(
                features,
                player_ids,
                action_heads,
                group_ids,
                object_batch,
                action_batch,
                group_count=group_count,
                action_slot_count=action_slot_count,
            )
        outputs = self(features)
        head_tensor = _head_indices(
            action_heads.to(outputs.device),
            player_ids.to(outputs.device),
            self.head_count,
        )
        return outputs.gather(1, head_tensor[:, None]).squeeze(1)

    def candidate_scores_and_values(
        self,
        features: torch.Tensor,
        player_ids: torch.Tensor,
        action_heads: torch.Tensor,
        group_ids: torch.Tensor | None = None,
        object_batch: ObjectBatch | None = None,
        action_batch: ActionBatch | None = None,
        group_count: int | None = None,
        action_slot_count: int | None = None,
    ) -> tuple[torch.Tensor, torch.Tensor]:
        if self.architecture == "action-transformer":
            return self.action_transformer(
                features,
                player_ids,
                action_heads,
                group_ids,
                object_batch,
                action_batch,
                return_values=True,
                group_count=group_count,
                action_slot_count=action_slot_count,
            )
        scores = self.candidate_scores(
            features, player_ids, action_heads, group_ids, object_batch, action_batch
        )
        return scores, self.value_estimates(features, group_ids)

    def export_artifact(
        self,
        source: PolicyArtifact,
        path: Path,
        *,
        training_record: dict[str, Any] | None = None,
    ) -> None:
        if self.architecture != "mlp":
            raise ValueError(
                "only mlp Torch policies can be exported to the C-compatible JSON artifact"
            )
        data = dict(source.data)
        data["backend"] = "c-mlp"
        data["training_backend"] = (
            "torch-mps" if next(self.parameters()).device.type == "mps" else "torch"
        )
        if training_record is not None:
            data["training_record"] = training_record
        layers = [layer.out_features for layer in self.layers]
        data["hidden_layers"] = layers
        data["hidden_size"] = layers[0]
        data["input_size"] = self.input_size
        data["hidden_weights"] = [
            layer.weight.detach().cpu().reshape(-1).tolist() for layer in self.layers
        ]
        data["hidden_biases"] = [
            layer.bias.detach().cpu().reshape(-1).tolist() for layer in self.layers
        ]
        data["output_weights"] = self.output.weight.detach().cpu().reshape(-1).tolist()
        data["b2s"] = self.output.bias.detach().cpu().reshape(-1).tolist()
        data["b2"] = float(data["b2s"][0]) if data["b2s"] else 0.0
        PolicyArtifact(data=data).save(path)

    def save_checkpoint(
        self, path: Path, *, training_record: dict[str, Any] | None = None
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-torch-policy-v1",
                "architecture": self.architecture,
                "feature_version": FEATURE_VERSION,
                "layer_sizes": self.layer_sizes,
                "input_size": self.input_size,
                "head_count": self.head_count,
                "transformer_dropout": self.transformer_dropout,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


def initialize_policy_from_source(target: TorchPolicy, source: TorchPolicy) -> None:
    if target.input_size != source.input_size or target.head_count != source.head_count:
        raise ValueError("cannot initialize from a source policy with different IO shape")
    if target.architecture == source.architecture:
        target.load_state_dict(source.state_dict())
        return
    if target.architecture == "residual-layernorm-mlp" and source.architecture == "mlp":
        if len(target.layers) != len(source.layers):
            raise ValueError(
                "residual-layernorm-mlp layer count must match the source mlp layer count"
            )
        with torch.no_grad():
            for target_layer, source_layer in _zip_strict(
                target.layers, source.layers
            ):
                if (
                    target_layer.weight.shape != source_layer.weight.shape
                    or target_layer.bias.shape != source_layer.bias.shape
                ):
                    raise ValueError(
                        "residual-layernorm-mlp layers must match source mlp shapes"
                    )
                target_layer.weight.copy_(source_layer.weight)
                target_layer.bias.copy_(source_layer.bias)
            target.output.weight.copy_(source.output.weight)
            target.output.bias.copy_(source.output.bias)
            target.value_output.weight.copy_(source.value_output.weight)
            target.value_output.bias.copy_(source.value_output.bias)
            for block in target.blocks:
                final = block.layers[-1]
                if isinstance(final, nn.Linear):
                    final.weight.zero_()
                    final.bias.zero_()
        return
    raise ValueError(
        f"cannot initialize {target.architecture!r} from {source.architecture!r}"
    )


def load_torch_policy(
    path: Path, device: torch.device
) -> tuple[TorchPolicy, PolicyArtifact | None]:
    if path.suffix == ".pt":
        return TorchPolicy.from_checkpoint(path, device), None
    artifact = PolicyArtifact.load(path)
    return TorchPolicy.from_artifact(artifact, device), artifact


def _head_indices(
    action_heads: torch.Tensor, player_ids: torch.Tensor, head_count: int
) -> torch.Tensor:
    if head_count == 16:
        return (player_ids * 4 + (action_heads % 4)).long()
    return action_heads.clamp(0, head_count - 1).long()


def _candidate_tensor(
    candidates: list[Any], input_size: int, device: torch.device
) -> torch.Tensor:
    features = torch.zeros((len(candidates), input_size), dtype=torch.float32)
    for row, candidate in enumerate(candidates):
        for index in range(candidate.feature_count):
            column = int(candidate.feature_indices[index])
            if 0 <= column < input_size:
                features[row, column] = float(candidate.feature_values[index])
    return features.to(device)


def _object_id(value: int, offset: int, count: int) -> int:
    return max(0, min(count - 1, int(value) + offset))


def _object_token_batch(
    token_groups: list[list[KCObjectToken] | None], device: torch.device
) -> ObjectBatch:
    group_count = len(token_groups)
    max_tokens = max(
        1, max((len(tokens) if tokens is not None else 0) for tokens in token_groups)
    )
    type_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    owner_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    zone_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    suit_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    value_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    index_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    scalars = torch.zeros(
        (group_count, max_tokens, OBJECT_SCALAR_COUNT), dtype=torch.float32
    )
    padding_mask = torch.ones((group_count, max_tokens), dtype=torch.bool)
    for group_index, tokens in enumerate(token_groups):
        if not tokens:
            continue
        for token_index, token in enumerate(tokens[:max_tokens]):
            type_ids[group_index, token_index] = _object_id(
                token.type, 0, OBJECT_TYPE_EMBEDDINGS
            )
            owner_ids[group_index, token_index] = _object_id(
                token.owner, 1, OBJECT_OWNER_EMBEDDINGS
            )
            zone_ids[group_index, token_index] = _object_id(
                token.zone, 0, OBJECT_ZONE_EMBEDDINGS
            )
            suit_ids[group_index, token_index] = _object_id(
                token.suit, 1, OBJECT_SUIT_EMBEDDINGS
            )
            value_ids[group_index, token_index] = _object_id(
                token.value, 0, OBJECT_VALUE_EMBEDDINGS
            )
            index_ids[group_index, token_index] = _object_id(
                token.index, 0, OBJECT_INDEX_EMBEDDINGS
            )
            for scalar_index in range(OBJECT_SCALAR_COUNT):
                scalars[group_index, token_index, scalar_index] = float(
                    token.scalars[scalar_index]
                )
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


def _action_id(value: int, offset: int, count: int) -> int:
    return max(0, min(count - 1, int(value) + offset))


def _action_token_batch(candidates: list[Any], device: torch.device) -> ActionBatch:
    count = len(candidates)
    kind_ids = torch.zeros((count,), dtype=torch.long)
    player_ids = torch.zeros((count,), dtype=torch.long)
    suit_ids = torch.zeros((count,), dtype=torch.long)
    target_suit_ids = torch.zeros((count,), dtype=torch.long)
    card_suit_ids = torch.zeros((count,), dtype=torch.long)
    card_value_ids = torch.zeros((count,), dtype=torch.long)
    hand_suit_ids = torch.zeros((count,), dtype=torch.long)
    hand_value_ids = torch.zeros((count,), dtype=torch.long)
    plot_suit_ids = torch.zeros((count,), dtype=torch.long)
    plot_value_ids = torch.zeros((count,), dtype=torch.long)
    plot_zone_ids = torch.zeros((count,), dtype=torch.long)
    action_scalars = torch.zeros((count, ACTION_SCALAR_COUNT), dtype=torch.float32)
    for row, candidate in enumerate(candidates):
        action = candidate.action
        kind_ids[row] = _action_id(action.kind, 0, ACTION_KIND_EMBEDDINGS)
        player_ids[row] = _action_id(action.player_id, 1, ACTION_PLAYER_EMBEDDINGS)
        suit_ids[row] = _action_id(action.suit, 1, ACTION_SUIT_EMBEDDINGS)
        target_suit_ids[row] = _action_id(action.target_suit, 1, ACTION_SUIT_EMBEDDINGS)
        card_suit_ids[row] = _action_id(action.card.suit, 1, ACTION_SUIT_EMBEDDINGS)
        card_value_ids[row] = _action_id(action.card.value, 0, ACTION_VALUE_EMBEDDINGS)
        hand_suit_ids[row] = _action_id(
            action.hand_card.suit, 1, ACTION_SUIT_EMBEDDINGS
        )
        hand_value_ids[row] = _action_id(
            action.hand_card.value, 0, ACTION_VALUE_EMBEDDINGS
        )
        plot_suit_ids[row] = _action_id(
            action.plot_card.suit, 1, ACTION_SUIT_EMBEDDINGS
        )
        plot_value_ids[row] = _action_id(
            action.plot_card.value, 0, ACTION_VALUE_EMBEDDINGS
        )
        plot_zone_ids[row] = _action_id(action.plot_zone, 1, ACTION_ZONE_EMBEDDINGS)
    return (
        kind_ids.to(device),
        player_ids.to(device),
        suit_ids.to(device),
        target_suit_ids.to(device),
        card_suit_ids.to(device),
        card_value_ids.to(device),
        hand_suit_ids.to(device),
        hand_value_ids.to(device),
        plot_suit_ids.to(device),
        plot_value_ids.to(device),
        plot_zone_ids.to(device),
        action_scalars.to(device),
    )


def _int_buffer_tensor(buffer: Any, count: int) -> torch.Tensor:
    return torch.frombuffer(buffer, dtype=torch.int32, count=count).to(torch.long)


def _float_buffer_tensor(buffer: Any, count: int) -> torch.Tensor:
    return torch.frombuffer(buffer, dtype=torch.float32, count=count)


def _dense_object_token_batch(
    token_groups: list[DenseObjectTokens | None], device: torch.device
) -> ObjectBatch:
    group_count = len(token_groups)
    max_tokens = max(
        1, max((len(tokens) if tokens is not None else 0) for tokens in token_groups)
    )
    type_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    owner_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    zone_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    suit_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    value_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    index_ids = torch.zeros((group_count, max_tokens), dtype=torch.long)
    scalars = torch.zeros(
        (group_count, max_tokens, OBJECT_SCALAR_COUNT), dtype=torch.float32
    )
    padding_mask = torch.ones((group_count, max_tokens), dtype=torch.bool)
    for group_index, tokens in enumerate(token_groups):
        if tokens is None or not tokens.count:
            continue
        count = min(tokens.count, max_tokens)
        type_ids[group_index, :count].copy_(_int_buffer_tensor(tokens.type_ids, count))
        owner_ids[group_index, :count].copy_(
            _int_buffer_tensor(tokens.owner_ids, count)
        )
        zone_ids[group_index, :count].copy_(_int_buffer_tensor(tokens.zone_ids, count))
        suit_ids[group_index, :count].copy_(_int_buffer_tensor(tokens.suit_ids, count))
        value_ids[group_index, :count].copy_(
            _int_buffer_tensor(tokens.value_ids, count)
        )
        index_ids[group_index, :count].copy_(
            _int_buffer_tensor(tokens.index_ids, count)
        )
        scalars[group_index, :count].copy_(
            _float_buffer_tensor(tokens.scalars, count * OBJECT_SCALAR_COUNT).view(
                count, OBJECT_SCALAR_COUNT
            )
        )
        padding_mask[group_index, :count] = False
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


def _dense_action_token_batch(
    candidate_batches: list[DensePolicyActionFeatures], device: torch.device
) -> ActionBatch:
    total = sum(len(batch) for batch in candidate_batches)
    kind_ids = torch.empty((total,), dtype=torch.long)
    player_ids = torch.empty((total,), dtype=torch.long)
    suit_ids = torch.empty((total,), dtype=torch.long)
    target_suit_ids = torch.empty((total,), dtype=torch.long)
    card_suit_ids = torch.empty((total,), dtype=torch.long)
    card_value_ids = torch.empty((total,), dtype=torch.long)
    hand_suit_ids = torch.empty((total,), dtype=torch.long)
    hand_value_ids = torch.empty((total,), dtype=torch.long)
    plot_suit_ids = torch.empty((total,), dtype=torch.long)
    plot_value_ids = torch.empty((total,), dtype=torch.long)
    plot_zone_ids = torch.empty((total,), dtype=torch.long)
    action_scalars = torch.zeros((total, ACTION_SCALAR_COUNT), dtype=torch.float32)
    row = 0
    for batch in candidate_batches:
        count = len(batch)
        if count <= 0:
            continue
        target = slice(row, row + count)
        kind_ids[target].copy_(_int_buffer_tensor(batch.kind_ids, count))
        player_ids[target].copy_(_int_buffer_tensor(batch.player_ids, count))
        suit_ids[target].copy_(_int_buffer_tensor(batch.suit_ids, count))
        target_suit_ids[target].copy_(_int_buffer_tensor(batch.target_suit_ids, count))
        card_suit_ids[target].copy_(_int_buffer_tensor(batch.card_suit_ids, count))
        card_value_ids[target].copy_(_int_buffer_tensor(batch.card_value_ids, count))
        hand_suit_ids[target].copy_(_int_buffer_tensor(batch.hand_suit_ids, count))
        hand_value_ids[target].copy_(_int_buffer_tensor(batch.hand_value_ids, count))
        plot_suit_ids[target].copy_(_int_buffer_tensor(batch.plot_suit_ids, count))
        plot_value_ids[target].copy_(_int_buffer_tensor(batch.plot_value_ids, count))
        plot_zone_ids[target].copy_(_int_buffer_tensor(batch.plot_zone_ids, count))
        scalar_count = max(0, min(int(batch.action_scalar_count), ACTION_SCALAR_COUNT))
        if scalar_count:
            action_scalars[target, :scalar_count].copy_(
                _float_buffer_tensor(
                    batch.action_scalars, count * int(batch.action_scalar_count)
                )
                .view(count, int(batch.action_scalar_count))[:, :scalar_count]
            )
        row += count
    return (
        kind_ids.to(device),
        player_ids.to(device),
        suit_ids.to(device),
        target_suit_ids.to(device),
        card_suit_ids.to(device),
        card_value_ids.to(device),
        hand_suit_ids.to(device),
        hand_value_ids.to(device),
        plot_suit_ids.to(device),
        plot_value_ids.to(device),
        plot_zone_ids.to(device),
        action_scalars.to(device),
    )


def _clone_ppo_sample(
    model: TorchPolicy,
    candidates: DensePolicyActionFeatures,
    object_tokens: DenseObjectTokens | None,
    *,
    player_id: int,
    selected: int,
    old_log_prob: torch.Tensor,
    temperature: float,
) -> dict[str, Any]:
    count = len(candidates)
    cpu = torch.device("cpu")
    return {
        "features": _float_buffer_tensor(candidates.features, count * model.input_size)
        .view(count, model.input_size)
        .clone(),
        "player_ids": torch.full((count,), int(player_id), dtype=torch.long),
        "action_heads": _int_buffer_tensor(candidates.action_heads, count).clone(),
        "object_batch": tuple(
            item.clone() for item in _dense_object_token_batch([object_tokens], cpu)
        )
        if model.uses_object_tokens
        else None,
        "action_batch": tuple(
            item.clone() for item in _dense_action_token_batch([candidates], cpu)
        )
        if model.uses_object_tokens
        else None,
        "selected": int(selected),
        "old_log_prob": old_log_prob.detach().cpu(),
        "temperature": float(temperature),
        "candidate_count": count,
    }


def _ppo_sample_outputs(
    model: TorchPolicy,
    sample: dict[str, Any],
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.distributions.Categorical]:
    device = next(model.parameters()).device
    count = int(sample["candidate_count"])
    object_batch = sample.get("object_batch")
    action_batch = sample.get("action_batch")
    if object_batch is not None:
        object_batch = tuple(item.to(device) for item in object_batch)
    if action_batch is not None:
        action_batch = tuple(item.to(device) for item in action_batch)
    scores, values = model.candidate_scores_and_values(
        sample["features"].to(device),
        sample["player_ids"].to(device),
        sample["action_heads"].to(device),
        torch.zeros((count,), dtype=torch.long, device=device),
        object_batch=object_batch,
        action_batch=action_batch,
        group_count=1,
        action_slot_count=count,
    )
    distribution = torch.distributions.Categorical(
        logits=scores / max(float(sample["temperature"]), 0.05)
    )
    selected = torch.tensor(int(sample["selected"]), dtype=torch.long, device=device)
    return (
        distribution.log_prob(selected),
        values[0],
        distribution.entropy(),
        distribution,
    )


def _ppo_samples_outputs_batch(
    model: TorchPolicy,
    samples: list[dict[str, Any]],
) -> tuple[
    torch.Tensor,
    torch.Tensor,
    torch.Tensor,
    torch.distributions.Categorical,
    torch.Tensor,
]:
    device = next(model.parameters()).device
    if not samples:
        raise ValueError("cannot score an empty PPO sample batch")
    counts = [int(sample["candidate_count"]) for sample in samples]
    features = torch.cat([sample["features"] for sample in samples], dim=0).to(device)
    player_ids = torch.cat([sample["player_ids"] for sample in samples], dim=0).to(
        device
    )
    action_heads = torch.cat([sample["action_heads"] for sample in samples], dim=0).to(
        device
    )
    group_ids = torch.cat(
        [
            torch.full((count,), index, dtype=torch.long)
            for index, count in enumerate(counts)
        ],
        dim=0,
    ).to(device)
    object_batch = (
        _collate_ppo_object_batches(samples, device)
        if model.uses_object_tokens
        else None
    )
    action_batch = (
        _collate_ppo_action_batches(samples, device)
        if model.uses_object_tokens
        else None
    )
    scores, values = model.candidate_scores_and_values(
        features,
        player_ids,
        action_heads,
        group_ids,
        object_batch=object_batch,
        action_batch=action_batch,
        group_count=len(samples),
        action_slot_count=max(counts),
    )
    logits = torch.full(
        (len(samples), max(counts)), -1.0e9, dtype=scores.dtype, device=device
    )
    cursor = 0
    for index, count in enumerate(counts):
        logits[index, :count] = scores[cursor : cursor + count]
        cursor += count
    temperatures = torch.tensor(
        [max(float(sample["temperature"]), 0.05) for sample in samples],
        dtype=logits.dtype,
        device=device,
    )
    distribution = torch.distributions.Categorical(
        logits=logits / temperatures[:, None]
    )
    selected = torch.tensor(
        [int(sample["selected"]) for sample in samples], dtype=torch.long, device=device
    )
    old_log_probs = torch.stack(
        [sample["old_log_prob"].float() for sample in samples]
    ).to(device)
    return (
        distribution.log_prob(selected),
        values,
        distribution.entropy(),
        distribution,
        old_log_probs,
    )


def _collate_ppo_object_batches(
    samples: list[dict[str, Any]], device: torch.device
) -> ObjectBatch | None:
    batches = [sample.get("object_batch") for sample in samples]
    if not batches or batches[0] is None:
        return None
    max_tokens = max(int(batch[0].shape[1]) for batch in batches if batch is not None)
    collated = []
    for component_index in range(len(batches[0])):
        first = batches[0][component_index]
        shape = (len(samples), max_tokens, *first.shape[2:])
        if component_index == len(batches[0]) - 1:
            target = torch.ones(shape, dtype=first.dtype)
        else:
            target = torch.zeros(shape, dtype=first.dtype)
        for sample_index, batch in enumerate(batches):
            item = batch[component_index]
            count = int(item.shape[1])
            target[sample_index, :count, ...] = item[0, :count, ...]
        collated.append(target.to(device))
    return tuple(collated)  # type: ignore[return-value]


def _collate_ppo_action_batches(
    samples: list[dict[str, Any]], device: torch.device
) -> ActionBatch | None:
    batches = [sample.get("action_batch") for sample in samples]
    if not batches or batches[0] is None:
        return None
    return tuple(
        torch.cat([batch[index] for batch in batches], dim=0).to(device)
        for index in range(len(batches[0]))
    )  # type: ignore[return-value]


def _candidate_scores(
    model: TorchPolicy,
    candidates: list[Any],
    player_id: int,
    object_tokens: list[KCObjectToken] | None = None,
) -> torch.Tensor:
    features = _candidate_tensor(
        candidates, model.input_size, next(model.parameters()).device
    )
    player_ids = torch.full(
        (len(candidates),), int(player_id), dtype=torch.long, device=features.device
    )
    action_heads = torch.tensor(
        [int(candidate.action_head) for candidate in candidates],
        dtype=torch.long,
        device=features.device,
    )
    object_batch = (
        _object_token_batch([object_tokens], features.device)
        if model.uses_object_tokens
        else None
    )
    action_batch = (
        _action_token_batch(candidates, features.device)
        if model.uses_object_tokens
        else None
    )
    return model.candidate_scores(
        features,
        player_ids,
        action_heads,
        object_batch=object_batch,
        action_batch=action_batch,
    )


def _candidate_scores_and_values(
    model: TorchPolicy,
    candidates: list[Any],
    player_id: int,
    object_tokens: list[KCObjectToken] | None = None,
) -> tuple[torch.Tensor, torch.Tensor]:
    features = _candidate_tensor(
        candidates, model.input_size, next(model.parameters()).device
    )
    player_ids = torch.full(
        (len(candidates),), int(player_id), dtype=torch.long, device=features.device
    )
    action_heads = torch.tensor(
        [int(candidate.action_head) for candidate in candidates],
        dtype=torch.long,
        device=features.device,
    )
    object_batch = (
        _object_token_batch([object_tokens], features.device)
        if model.uses_object_tokens
        else None
    )
    action_batch = (
        _action_token_batch(candidates, features.device)
        if model.uses_object_tokens
        else None
    )
    return model.candidate_scores_and_values(
        features,
        player_ids,
        action_heads,
        object_batch=object_batch,
        action_batch=action_batch,
    )


def _choose_torch_action(
    model: TorchPolicy,
    candidates: list[Any],
    player_id: int,
    *,
    sample: bool,
    temperature: float,
    object_tokens: list[KCObjectToken] | None = None,
) -> tuple[KCAction, torch.Tensor | None, torch.Tensor | None, torch.Tensor | None]:
    scores, values = _candidate_scores_and_values(
        model, candidates, player_id, object_tokens
    )
    if sample:
        distribution = torch.distributions.Categorical(
            logits=scores / max(temperature, 0.05)
        )
        selected = distribution.sample()
        return (
            candidates[int(selected.item())].action,
            distribution.log_prob(selected),
            values[0],
            distribution.entropy(),
        )
    selected = int(torch.argmax(scores).item())
    return candidates[selected].action, None, values[0], None


def _batched_candidate_scores(
    model: TorchPolicy,
    groups: list[tuple[int, DensePolicyActionFeatures, int, DenseObjectTokens | None]],
) -> tuple[
    torch.Tensor,
    torch.Tensor,
    list[tuple[int, int, int, DensePolicyActionFeatures, int]],
]:
    device = next(model.parameters()).device
    group_count = len(groups)
    action_slot_count = max(1, max(len(candidates) for _, candidates, _, _ in groups))
    total_candidates = sum(len(candidates) for _, candidates, _, _ in groups)
    features = torch.empty((total_candidates, model.input_size), dtype=torch.float32)
    player_ids = torch.empty((total_candidates,), dtype=torch.long)
    action_heads = torch.empty((total_candidates,), dtype=torch.long)
    group_ids = torch.empty((total_candidates,), dtype=torch.long)
    spans: list[tuple[int, int, int, DensePolicyActionFeatures, int]] = []
    object_groups: list[DenseObjectTokens | None] = []
    action_batches: list[DensePolicyActionFeatures] = []
    row = 0
    for group_index, (env_index, candidates, player_id, object_tokens) in enumerate(
        groups
    ):
        count = len(candidates)
        start = row
        end = row + count
        features[start:end].copy_(
            _float_buffer_tensor(candidates.features, count * model.input_size).view(
                count, model.input_size
            )
        )
        player_ids[start:end] = int(player_id)
        action_heads[start:end].copy_(
            _int_buffer_tensor(candidates.action_heads, count)
        )
        group_ids[start:end] = group_index
        row = end
        spans.append((env_index, start, row, candidates, group_index))
        object_groups.append(object_tokens)
        action_batches.append(candidates)
    object_batch = (
        _dense_object_token_batch(object_groups, device)
        if model.uses_object_tokens
        else None
    )
    action_batch = (
        _dense_action_token_batch(action_batches, device)
        if model.uses_object_tokens
        else None
    )
    scores, values = model.candidate_scores_and_values(
        features.to(device),
        player_ids.to(device),
        action_heads.to(device),
        group_ids.to(device),
        object_batch=object_batch,
        action_batch=action_batch,
        group_count=group_count,
        action_slot_count=action_slot_count,
    )
    return scores, values, spans


def _card_dict(card: KCCard) -> dict[str, int]:
    return {"suit": int(card.suit), "value": int(card.value)}


def _action_dict(action: KCAction) -> dict[str, Any]:
    return {
        "kind": int(action.kind),
        "player_id": int(action.player_id),
        "suit": int(action.suit),
        "card": _card_dict(action.card),
        "hand_card": _card_dict(action.hand_card),
        "plot_card": _card_dict(action.plot_card),
        "plot_zone": int(action.plot_zone),
        "target_suit": int(action.target_suit),
    }


def _action_from_dict(data: dict[str, Any]) -> KCAction:
    return KCAction(
        int(data.get("kind", 0)),
        int(data.get("player_id", -1)),
        int(data.get("suit", -1)),
        KCCard(
            int((data.get("card") or {}).get("suit", -1)),
            int((data.get("card") or {}).get("value", 0)),
        ),
        KCCard(
            int((data.get("hand_card") or {}).get("suit", -1)),
            int((data.get("hand_card") or {}).get("value", 0)),
        ),
        KCCard(
            int((data.get("plot_card") or {}).get("suit", -1)),
            int((data.get("plot_card") or {}).get("value", 0)),
        ),
        int(data.get("plot_zone", 0)),
        int(data.get("target_suit", -1)),
    )


def _action_signature(action: KCAction) -> tuple[int, ...]:
    return (
        int(action.kind),
        int(action.player_id),
        int(action.suit),
        int(action.card.suit),
        int(action.card.value),
        int(action.hand_card.suit),
        int(action.hand_card.value),
        int(action.plot_card.suit),
        int(action.plot_card.value),
        int(action.plot_zone),
        int(action.target_suit),
    )


def _dense_features_record(
    candidates: DensePolicyActionFeatures, object_tokens: DenseObjectTokens | None
) -> dict[str, Any]:
    count = len(candidates)
    return {
        "candidate_count": count,
        "input_size": int(candidates.input_size),
        "action_heads": [int(candidates.action_heads[index]) for index in range(count)],
        "kind_ids": [int(candidates.kind_ids[index]) for index in range(count)],
        "player_ids": [int(candidates.player_ids[index]) for index in range(count)],
        "suit_ids": [int(candidates.suit_ids[index]) for index in range(count)],
        "target_suit_ids": [
            int(candidates.target_suit_ids[index]) for index in range(count)
        ],
        "card_suit_ids": [
            int(candidates.card_suit_ids[index]) for index in range(count)
        ],
        "card_value_ids": [
            int(candidates.card_value_ids[index]) for index in range(count)
        ],
        "hand_suit_ids": [
            int(candidates.hand_suit_ids[index]) for index in range(count)
        ],
        "hand_value_ids": [
            int(candidates.hand_value_ids[index]) for index in range(count)
        ],
        "plot_suit_ids": [
            int(candidates.plot_suit_ids[index]) for index in range(count)
        ],
        "plot_value_ids": [
            int(candidates.plot_value_ids[index]) for index in range(count)
        ],
        "plot_zone_ids": [
            int(candidates.plot_zone_ids[index]) for index in range(count)
        ],
        "action_scalar_count": int(candidates.action_scalar_count),
        "action_scalars": [
            float(candidates.action_scalars[index])
            for index in range(count * int(candidates.action_scalar_count))
        ],
        "features": [
            float(candidates.features[index])
            for index in range(count * int(candidates.input_size))
        ],
        "object_tokens": _dense_object_record(object_tokens),
    }


def _dense_object_record(tokens: DenseObjectTokens | None) -> dict[str, Any] | None:
    if tokens is None:
        return None
    count = len(tokens)
    return {
        "count": count,
        "type_ids": [int(tokens.type_ids[index]) for index in range(count)],
        "owner_ids": [int(tokens.owner_ids[index]) for index in range(count)],
        "zone_ids": [int(tokens.zone_ids[index]) for index in range(count)],
        "suit_ids": [int(tokens.suit_ids[index]) for index in range(count)],
        "value_ids": [int(tokens.value_ids[index]) for index in range(count)],
        "index_ids": [int(tokens.index_ids[index]) for index in range(count)],
        "scalars": [
            float(tokens.scalars[index]) for index in range(count * OBJECT_SCALAR_COUNT)
        ],
    }


def _terminal_metrics(engine: CEngine, pointer: Any, seat: int) -> dict[str, float]:
    scores = engine.final_scores(pointer)
    medals = engine.total_medals(pointer)
    winner = max(range(4), key=lambda player: (scores[player], medals[player], player))
    return asdict(_metrics(scores, medals, winner, seat))


def _replay_engine(
    engine: CEngine,
    *,
    seed: int,
    actions: list[dict[str, Any]],
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
    curriculum_rounds: int,
) -> Any:
    pointer = engine.new_engine(
        seed,
        round_curriculum=round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
        curriculum_rounds=curriculum_rounds,
    )
    for action in actions:
        engine.apply_policy_action(pointer, _action_from_dict(action))
    return pointer


def _candidate_index_for_action(
    candidates: DensePolicyActionFeatures, action: KCAction
) -> int | None:
    signature = _action_signature(action)
    for index in range(len(candidates)):
        if _action_signature(candidates.action_at(index)) == signature:
            return index
    return None


def _rollout_policy_action(
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    rollout_model: TorchPolicy | None,
    sample: bool,
    temperature: float,
) -> KCAction:
    if rollout_model is None:
        return engine.heuristic_action(pointer)
    candidates = engine.dense_policy_action_features(
        pointer, player_id=player_id, input_size=rollout_model.input_size
    )
    if not candidates:
        return engine.heuristic_action(pointer)
    object_tokens = (
        engine.dense_object_tokens(pointer, perspective_player=player_id)
        if rollout_model.uses_object_tokens
        else None
    )
    with torch.no_grad():
        scores, _, spans = _batched_candidate_scores(
            rollout_model, [(0, candidates, player_id, object_tokens)]
        )
    _, start, end, _, _ = spans[0]
    logits = scores[start:end]
    if sample:
        distribution = torch.distributions.Categorical(
            logits=logits / max(temperature, 0.05)
        )
        selected = int(distribution.sample().item())
    else:
        selected = int(torch.argmax(logits).item())
    return candidates.action_at(selected)


def _rollout_policy_index(
    engine: CEngine,
    pointer: Any,
    *,
    candidates: DensePolicyActionFeatures,
    player_id: int,
    rollout_model: TorchPolicy | None,
) -> int:
    try:
        action = _rollout_policy_action(
            engine,
            pointer,
            player_id=player_id,
            rollout_model=rollout_model,
            sample=False,
            temperature=1.0,
        )
    except RuntimeError:
        action = engine.heuristic_action(pointer)
    return _candidate_index_for_action(candidates, action) or 0


def _search_score(
    metrics: dict[str, float],
    *,
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
) -> float:
    return (
        win_weight * float(metrics["win"])
        - rank_weight * (float(metrics["rank"]) - 1.0)
        + margin_weight * float(metrics["margin"])
    )


def _search_horizon_complete(
    engine: CEngine,
    pointer: Any,
    *,
    horizon: str,
    start_year: int,
    start_phase: int,
    actions_after_candidate: int,
) -> str | None:
    player_id = engine.waiting_player(pointer)
    if player_id < 0:
        return "terminal"
    phase = engine.phase(pointer)
    if phase == KC_PHASE_GAME_OVER:
        return "terminal"
    if horizon == "full-game":
        return None
    if engine.year(pointer) > start_year:
        return "year"
    if horizon == "end-year":
        return None
    if horizon != "end-trick":
        raise ValueError(f"unknown search horizon {horizon!r}")
    if phase == KC_PHASE_REQUISITION:
        return "requisition"
    if (
        start_phase in {KC_PHASE_TRICK, KC_PHASE_ASSIGNMENT}
        and actions_after_candidate > 0
        and phase == KC_PHASE_TRICK
    ):
        return "trick"
    return None


def _finish_with_rollout_policy(
    engine: CEngine,
    pointer: Any,
    *,
    seat: int,
    max_actions: int,
    horizon: str,
    start_year: int,
    start_phase: int,
    round_curriculum: bool,
    curriculum_rounds: int,
    rollout_model: TorchPolicy | None,
    rollout_sample: bool,
    rollout_temperature: float,
    actions_after_candidate: int,
) -> dict[str, Any]:
    actions = 0
    while actions < max_actions:
        if _curriculum_complete(
            engine,
            pointer,
            start_year=start_year,
            round_curriculum=round_curriculum,
            curriculum_rounds=curriculum_rounds,
        ):
            return {
                "metrics": _terminal_metrics(engine, pointer, seat),
                "actions": actions,
                "stop_reason": "curriculum",
            }
        stop_reason = _search_horizon_complete(
            engine,
            pointer,
            horizon=horizon,
            start_year=start_year,
            start_phase=start_phase,
            actions_after_candidate=actions_after_candidate + actions,
        )
        if stop_reason is not None:
            return {
                "metrics": _terminal_metrics(engine, pointer, seat),
                "actions": actions,
                "stop_reason": stop_reason,
            }
        player_id = engine.waiting_player(pointer)
        try:
            action = _rollout_policy_action(
                engine,
                pointer,
                player_id=player_id,
                rollout_model=rollout_model,
                sample=rollout_sample,
                temperature=rollout_temperature,
            )
        except RuntimeError:
            return {
                "metrics": _terminal_metrics(engine, pointer, seat),
                "actions": actions,
                "stop_reason": "no_action",
            }
        engine.apply_policy_action(pointer, action)
        actions += 1
    return {
        "metrics": _terminal_metrics(engine, pointer, seat),
        "actions": actions,
        "stop_reason": "action_limit",
    }


def _softmax_probabilities(values: list[float], *, temperature: float) -> list[float]:
    if not values:
        return []
    tensor = torch.tensor(values, dtype=torch.float32)
    probs = torch.softmax(tensor / max(float(temperature), 1e-6), dim=0)
    return [float(item) for item in probs.tolist()]


def _q_target_stats(
    q_values: list[float], target_policy: list[float] | None = None
) -> dict[str, float]:
    if not q_values:
        return {
            "q_margin": 0.0,
            "q_range": 0.0,
            "q_std": 0.0,
            "target_entropy": 0.0,
        }
    sorted_q = sorted(float(value) for value in q_values)
    q_margin = sorted_q[-1] - sorted_q[-2] if len(sorted_q) >= 2 else 0.0
    mean = _mean(sorted_q)
    q_std = math.sqrt(_mean([(value - mean) * (value - mean) for value in sorted_q]))
    entropy = 0.0
    if target_policy is not None:
        entropy = -sum(
            float(prob) * math.log(max(float(prob), 1e-8)) for prob in target_policy
        )
    return {
        "q_margin": q_margin,
        "q_range": sorted_q[-1] - sorted_q[0],
        "q_std": q_std,
        "target_entropy": entropy,
    }


def _policy_confidence_weight(
    record: dict[str, Any],
    q_values: list[float],
    *,
    min_policy_q_margin: float,
    policy_confidence_scale: float,
    min_policy_weight: float,
) -> float:
    if not q_values:
        return 1.0
    margin = record.get("q_margin")
    if margin is None and isinstance(record.get("search"), dict):
        margin = record["search"].get("q_margin")
    if margin is None:
        margin = _q_target_stats(q_values).get("q_margin", 0.0)
    q_margin = float(margin)
    if q_margin < float(min_policy_q_margin):
        return 0.0
    scale = float(policy_confidence_scale)
    if scale <= 0.0:
        return 1.0
    weight = min(1.0, max(0.0, (q_margin - float(min_policy_q_margin)) / scale))
    if q_margin > 0.0:
        weight = max(float(min_policy_weight), weight)
    return min(1.0, max(0.0, weight))


def _search_target_values(
    engine: CEngine,
    *,
    seed: int,
    action_history: list[dict[str, Any]],
    candidates: DensePolicyActionFeatures,
    seat: int,
    baseline_index: int,
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
    curriculum_rounds: int,
    max_search_actions: int,
    rollout_action_limit: int,
    rollout_model: TorchPolicy | None,
    rollout_model_path: Path | None,
    rollout_sample: bool,
    rollout_temperature: float,
    rollouts_per_action: int,
    determinize_search: bool,
    search_horizon: str,
    search_target: str,
    target_temperature: float,
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
) -> tuple[int, dict[str, Any]]:
    if len(candidates) <= 1 or len(candidates) > max_search_actions:
        q_values = [0.0] * len(candidates)
        target_policy = [1.0] if len(candidates) == 1 else None
        target_stats = _q_target_stats(q_values, target_policy)
        return baseline_index, {
            "searched": False,
            "reason": "candidate_count",
            "candidate_count": len(candidates),
            "baseline_index": baseline_index,
            "q_values": q_values if len(candidates) == 1 else None,
            "target_policy": target_policy,
            "target_value": 0.0 if len(candidates) == 1 else None,
            **target_stats,
        }
    if search_target not in {"absolute", "paired-baseline"}:
        raise ValueError(f"unknown search target {search_target!r}")
    raw_scores: list[float] = []
    rollout_scores_by_action: list[list[float]] = [[] for _ in range(len(candidates))]
    rollout_results_by_action: list[list[dict[str, Any]]] = [
        [] for _ in range(len(candidates))
    ]
    rollout_count = max(1, int(rollouts_per_action))
    determinization_seeds: list[int | None] = []
    for rollout_index in range(rollout_count):
        replay_pointer = _replay_engine(
            engine,
            seed=seed,
            actions=action_history,
            round_curriculum=round_curriculum,
            round_plot_cards=round_plot_cards,
            round_famine_rate=round_famine_rate,
            curriculum_rounds=curriculum_rounds,
        )
        sample_seed = (
            seed * 0x9E3779B97F4A7C15 + rollout_index * 0x94D049BB133111EB
        ) & 0xFFFFFFFFFFFFFFFF
        determinization_seeds.append(sample_seed if determinize_search else None)
        root_pointer = replay_pointer
        try:
            if determinize_search:
                root_pointer = engine.sample_determinization(
                    replay_pointer,
                    perspective_player=seat,
                    sample_seed=sample_seed,
                )
                engine.free_engine(replay_pointer)
                replay_pointer = None
            start_year = engine.year(root_pointer)
            start_phase = engine.phase(root_pointer)
            for index in range(len(candidates)):
                pointer = engine.clone_engine(root_pointer)
                try:
                    engine.apply_policy_action(pointer, candidates.action_at(index))
                    if rollout_sample:
                        torch.manual_seed(
                            (seed * 1315423911 + index * 2654435761 + rollout_index)
                            & 0x7FFFFFFF
                        )
                    rollout = _finish_with_rollout_policy(
                        engine,
                        pointer,
                        seat=seat,
                        max_actions=rollout_action_limit,
                        horizon=search_horizon,
                        start_year=start_year,
                        start_phase=start_phase,
                        round_curriculum=round_curriculum,
                        curriculum_rounds=curriculum_rounds,
                        rollout_model=rollout_model,
                        rollout_sample=rollout_sample,
                        rollout_temperature=rollout_temperature,
                        actions_after_candidate=1,
                    )
                    metrics = rollout["metrics"]
                    score = _search_score(
                        metrics,
                        win_weight=win_weight,
                        rank_weight=rank_weight,
                        margin_weight=margin_weight,
                    )
                    rollout_scores_by_action[index].append(score)
                    rollout_results_by_action[index].append(
                        {
                            "rollout": rollout_index,
                            "score": score,
                            "metrics": metrics,
                            "rollout_actions": rollout["actions"],
                            "stop_reason": rollout["stop_reason"],
                            "determinization_seed": sample_seed
                            if determinize_search
                            else None,
                        }
                    )
                finally:
                    engine.free_engine(pointer)
        finally:
            engine.free_engine(root_pointer)
            if replay_pointer is not None and replay_pointer is not root_pointer:
                engine.free_engine(replay_pointer)
    results: list[dict[str, Any]] = []
    for index, scores in enumerate(rollout_scores_by_action):
        average_score = _mean(scores)
        raw_scores.append(average_score)
        results.append(
            {
                "index": index,
                "score": average_score,
                "rollouts": rollout_results_by_action[index],
            }
        )
    baseline_score = raw_scores[baseline_index] if raw_scores else 0.0
    q_values = (
        [score - baseline_score for score in raw_scores]
        if search_target == "paired-baseline"
        else raw_scores
    )
    best_index = max(
        range(len(q_values)), key=lambda candidate_index: q_values[candidate_index]
    )
    target_policy = _softmax_probabilities(q_values, temperature=target_temperature)
    target_stats = _q_target_stats(q_values, target_policy)
    target_value = max(q_values) if q_values else 0.0
    return best_index, {
        "searched": True,
        "candidate_count": len(candidates),
        "baseline_index": baseline_index,
        "rollout_policy": str(rollout_model_path)
        if rollout_model_path
        else "heuristic",
        "rollout_sample": rollout_sample,
        "rollout_temperature": rollout_temperature,
        "rollouts_per_action": rollout_count,
        "comparison_determinization": "shared-root",
        "determinization_seeds": determinization_seeds,
        "determinize_search": determinize_search,
        "horizon": search_horizon,
        "target": search_target,
        "target_temperature": target_temperature,
        "score_weights": {
            "win": win_weight,
            "rank": rank_weight,
            "margin": margin_weight,
        },
        "raw_scores": raw_scores,
        "q_values": q_values,
        "target_policy": target_policy,
        "target_value": target_value,
        **target_stats,
        "best_index": best_index,
        "results": results,
    }


def generate_supervised_trajectories(
    engine: CEngine,
    *,
    output_path: Path,
    games: int,
    seed: int,
    input_size: int = INPUT_SIZE,
    seats: list[int] | None = None,
    max_search_actions: int = 8,
    rollout_action_limit: int = 512,
    rollout_model_path: Path | None = None,
    rollout_sample: bool = False,
    rollout_temperature: float = 1.0,
    rollouts_per_action: int = 1,
    determinize_search: bool = True,
    search_horizon: str = "full-game",
    search_target: str = "paired-baseline",
    target_temperature: float = 0.25,
    min_search_q_margin: float = 0.0,
    min_search_q_std: float = 0.0,
    skip_forced_targets: bool = False,
    win_weight: float = 1.0,
    rank_weight: float = 0.05,
    margin_weight: float = 0.001,
    prefer_mps: bool = True,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    curriculum_rounds: int = 5,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    seats = seats or [0, 1, 2, 3]
    rollout_model: TorchPolicy | None = None
    if rollout_model_path is not None:
        rollout_model, _ = load_torch_policy(
            rollout_model_path, best_device(prefer_mps)
        )
        rollout_model.eval()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    state_count = 0
    record_count = 0
    searched_count = 0
    forced_count = 0
    soft_target_count = 0
    skipped_low_signal_count = 0
    phase_record_counts: dict[str, int] = {}
    phase_skipped_counts: dict[str, int] = {}
    with output_path.open("w", encoding="utf-8") as handle:
        for game_index in range(games):
            game_seed = seed + game_index
            pointer = engine.new_engine(
                game_seed,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
                curriculum_rounds=curriculum_rounds,
            )
            action_history: list[dict[str, Any]] = []
            action_index = 0
            try:
                while action_index < 2000:
                    player_id = engine.waiting_player(pointer)
                    if player_id < 0:
                        break
                    phase_id = engine.phase(pointer)
                    phase = _phase_name(phase_id)
                    candidates = engine.dense_policy_action_features(
                        pointer, player_id=player_id, input_size=input_size
                    )
                    if len(candidates) <= 0:
                        break
                    heuristic = engine.heuristic_action(pointer)
                    heuristic_signature = _action_signature(heuristic)
                    heuristic_index = next(
                        (
                            index
                            for index in range(len(candidates))
                            if _action_signature(candidates.action_at(index))
                            == heuristic_signature
                        ),
                        0,
                    )
                    baseline_index = _rollout_policy_index(
                        engine,
                        pointer,
                        candidates=candidates,
                        player_id=player_id,
                        rollout_model=rollout_model,
                    )
                    object_tokens = engine.dense_object_tokens(
                        pointer, perspective_player=player_id
                    )
                    target_index = baseline_index
                    search: dict[str, Any] = {
                        "searched": False,
                        "reason": "non_training_seat",
                        "baseline_index": baseline_index,
                    }
                    if player_id in seats:
                        target_index, search = _search_target_values(
                            engine,
                            seed=game_seed,
                            action_history=action_history,
                            candidates=candidates,
                            seat=player_id,
                            baseline_index=baseline_index,
                            round_curriculum=round_curriculum,
                            round_plot_cards=round_plot_cards,
                            round_famine_rate=round_famine_rate,
                            curriculum_rounds=curriculum_rounds,
                            max_search_actions=max_search_actions,
                            rollout_action_limit=rollout_action_limit,
                            rollout_model=rollout_model,
                            rollout_model_path=rollout_model_path,
                            rollout_sample=rollout_sample,
                            rollout_temperature=rollout_temperature,
                            rollouts_per_action=rollouts_per_action,
                            determinize_search=determinize_search,
                            search_horizon=search_horizon,
                            search_target=search_target,
                            target_temperature=target_temperature,
                            win_weight=win_weight,
                            rank_weight=rank_weight,
                            margin_weight=margin_weight,
                        )
                        state_count += 1
                        searched_count += 1 if search.get("searched") else 0
                        forced_count += 1 if len(candidates) == 1 else 0
                        q_values = search.get("q_values")
                        target_policy = search.get("target_policy")
                        target_value = search.get("target_value")
                        q_margin = search.get("q_margin")
                        q_range = search.get("q_range")
                        q_std = search.get("q_std")
                        target_entropy = search.get("target_entropy")
                        if q_values is not None and target_policy is not None:
                            soft_target_count += 1
                        skip_record = False
                        q_margin_value = float(q_margin) if q_margin is not None else 0.0
                        q_std_value = float(q_std) if q_std is not None else 0.0
                        if len(candidates) == 1 and skip_forced_targets:
                            skip_record = True
                        if (
                            min_search_q_margin > 0.0
                            and q_margin_value < min_search_q_margin
                        ):
                            skip_record = True
                        if min_search_q_std > 0.0 and q_std_value < min_search_q_std:
                            skip_record = True
                        if skip_record:
                            skipped_low_signal_count += 1
                            phase_skipped_counts[phase] = (
                                phase_skipped_counts.get(phase, 0) + 1
                            )
                        else:
                            record = {
                                "format": "kolkhoz-supervised-trajectory-v3",
                                "seed": game_seed,
                                "game_index": game_index,
                                "action_index": action_index,
                                "phase_id": phase_id,
                                "phase": phase,
                                "player_id": player_id,
                                "target_index": target_index,
                                "heuristic_index": heuristic_index,
                                "baseline_index": baseline_index,
                                "q_values": q_values,
                                "target_policy": target_policy,
                                "target_value": target_value,
                                "q_margin": q_margin,
                                "q_range": q_range,
                                "q_std": q_std,
                                "target_entropy": target_entropy,
                                "target_action": _action_dict(
                                    candidates.action_at(target_index)
                                ),
                                "heuristic_action": _action_dict(heuristic),
                                "baseline_action": _action_dict(
                                    candidates.action_at(baseline_index)
                                ),
                                "search": search,
                                "features": _dense_features_record(
                                    candidates, object_tokens
                                ),
                            }
                            handle.write(json.dumps(record, sort_keys=True))
                            handle.write("\n")
                            record_count += 1
                            phase_record_counts[phase] = (
                                phase_record_counts.get(phase, 0) + 1
                            )
                    action = (
                        candidates.action_at(target_index)
                        if player_id in seats
                        else _rollout_policy_action(
                            engine,
                            pointer,
                            player_id=player_id,
                            rollout_model=rollout_model,
                            sample=False,
                            temperature=rollout_temperature,
                        )
                    )
                    engine.apply_policy_action(pointer, action)
                    action_history.append(_action_dict(action))
                    action_index += 1
            finally:
                engine.free_engine(pointer)
            if progress_callback is not None:
                progress_callback(
                    {
                        "kind": "supervised_trajectory_generation",
                        "status": "running",
                        "phase": "trajectory_generation",
                        "output_model": str(output_path),
                        "training": {
                            "games": games,
                            "seed": seed,
                            "input_size": input_size,
                            "seats": seats,
                            "rollout_model": str(rollout_model_path)
                            if rollout_model_path
                            else "heuristic",
                            "search_horizon": search_horizon,
                            "search_target": search_target,
                            "determinize_search": determinize_search,
                        },
                        "progress": {
                            "completed_games": game_index + 1,
                            "total_games": games,
                            "percent": (game_index + 1) / max(1, games),
                        },
                        "summary": {
                            "states": state_count,
                            "records": record_count,
                            "searched_states": searched_count,
                            "forced_states": forced_count,
                            "soft_target_states": soft_target_count,
                            "skipped_low_signal_states": skipped_low_signal_count,
                            "phase_record_counts": dict(
                                sorted(phase_record_counts.items())
                            ),
                            "phase_skipped_counts": dict(
                                sorted(phase_skipped_counts.items())
                            ),
                        },
                    }
                )
    return {
        "kind": "supervised_trajectory_generation",
        "status": "generated",
        "output_model": str(output_path),
        "training": {
            "games": games,
            "seed": seed,
            "input_size": input_size,
            "seats": seats,
            "max_search_actions": max_search_actions,
            "rollout_action_limit": rollout_action_limit,
            "rollout_model": str(rollout_model_path)
            if rollout_model_path
            else "heuristic",
            "rollout_sample": rollout_sample,
            "rollout_temperature": rollout_temperature,
            "rollouts_per_action": rollouts_per_action,
            "determinize_search": determinize_search,
            "search_horizon": search_horizon,
            "search_target": search_target,
            "target_temperature": target_temperature,
            "min_search_q_margin": min_search_q_margin,
            "min_search_q_std": min_search_q_std,
            "skip_forced_targets": skip_forced_targets,
            "score_weights": {
                "win": win_weight,
                "rank": rank_weight,
                "margin": margin_weight,
            },
            "round_curriculum": round_curriculum,
            "curriculum_rounds": curriculum_rounds if round_curriculum else None,
            "round_plot_cards": round_plot_cards,
            "round_famine_rate": round_famine_rate,
        },
        "summary": {
            "states": state_count,
            "records": record_count,
            "searched_states": searched_count,
            "forced_states": forced_count,
            "soft_target_states": soft_target_count,
            "skipped_low_signal_states": skipped_low_signal_count,
            "phase_record_counts": dict(sorted(phase_record_counts.items())),
            "phase_skipped_counts": dict(sorted(phase_skipped_counts.items())),
        },
    }


def _record_object_batch(
    record: dict[str, Any], device: torch.device
) -> ObjectBatch | None:
    tokens = (record.get("features") or {}).get("object_tokens") or None
    if tokens is None:
        return None
    count = int(tokens.get("count", 0))
    max_tokens = max(1, count)

    def long_row(key: str) -> torch.Tensor:
        values = list(tokens.get(key, []))[:count] + [0] * max(0, max_tokens - count)
        return torch.tensor([values], dtype=torch.long, device=device)

    scalars = list(tokens.get("scalars", []))[: count * OBJECT_SCALAR_COUNT]
    scalars += [0.0] * max(0, max_tokens * OBJECT_SCALAR_COUNT - len(scalars))
    padding = torch.ones((1, max_tokens), dtype=torch.bool, device=device)
    if count:
        padding[0, :count] = False
    return (
        long_row("type_ids"),
        long_row("owner_ids"),
        long_row("zone_ids"),
        long_row("suit_ids"),
        long_row("value_ids"),
        long_row("index_ids"),
        torch.tensor(scalars, dtype=torch.float32, device=device).view(
            1, max_tokens, OBJECT_SCALAR_COUNT
        ),
        padding,
    )


def _record_action_batch(
    features_record: dict[str, Any], device: torch.device
) -> ActionBatch:
    count = int(features_record["candidate_count"])
    keys = [
        "kind_ids",
        "player_ids",
        "suit_ids",
        "target_suit_ids",
        "card_suit_ids",
        "card_value_ids",
        "hand_suit_ids",
        "hand_value_ids",
        "plot_suit_ids",
        "plot_value_ids",
        "plot_zone_ids",
    ]
    action_scalars = list(features_record.get("action_scalars", []))
    stored_scalar_count = int(features_record.get("action_scalar_count", 0))
    scalar_tensor = torch.zeros((count, ACTION_SCALAR_COUNT), dtype=torch.float32)
    if stored_scalar_count > 0 and action_scalars:
        scalar_count = min(stored_scalar_count, ACTION_SCALAR_COUNT)
        expected = count * stored_scalar_count
        values = action_scalars[:expected] + [0.0] * max(0, expected - len(action_scalars))
        scalar_tensor[:, :scalar_count].copy_(
            torch.tensor(values, dtype=torch.float32)
            .view(count, stored_scalar_count)[:, :scalar_count]
        )
    return (
        *(
        torch.tensor(features_record[key], dtype=torch.long, device=device)
        for key in keys
        ),
        scalar_tensor.to(device),
    )  # type: ignore[return-value]


def _load_supervised_records(
    paths: list[Path], limit: int | None = None
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for path in paths:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                records.append(json.loads(line))
                if limit is not None and len(records) >= limit:
                    return records
    return records


def _supervised_record_phase(record: dict[str, Any]) -> str:
    phase = record.get("phase")
    if isinstance(phase, str) and phase:
        return phase
    phase_id = record.get("phase_id")
    if phase_id is not None:
        try:
            return _phase_name(int(phase_id))
        except (TypeError, ValueError):
            pass
    features = record.get("features")
    if isinstance(features, dict):
        action_heads = features.get("action_heads")
        if isinstance(action_heads, list) and action_heads:
            try:
                target_index = int(record.get("target_index", 0))
            except (TypeError, ValueError):
                target_index = 0
            if 0 <= target_index < len(action_heads):
                try:
                    return _phase_name(int(action_heads[target_index]))
                except (TypeError, ValueError):
                    pass
            try:
                return _phase_name(int(action_heads[0]))
            except (TypeError, ValueError):
                pass
    return "unknown"


def _supervised_phase_counts(records: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in records:
        phase = _supervised_record_phase(record)
        counts[phase] = counts.get(phase, 0) + 1
    return dict(sorted(counts.items()))


def _weighted_supervised_epoch_records(
    records: list[dict[str, Any]],
    phase_sample_weights: dict[str, float] | None,
    rng: random.Random,
) -> list[dict[str, Any]]:
    if not phase_sample_weights:
        epoch_records = list(records)
        rng.shuffle(epoch_records)
        return epoch_records
    weights = [
        max(0.0, float(phase_sample_weights.get(_supervised_record_phase(record), 1.0)))
        for record in records
    ]
    if not records or sum(weights) <= 0.0:
        return []
    epoch_records = rng.choices(records, weights=weights, k=len(records))
    rng.shuffle(epoch_records)
    return epoch_records


def pretrain_torch_policy_from_trajectories(
    *,
    trajectory_paths: list[Path],
    output_path: Path,
    start_model_path: Path | None,
    architecture: str,
    layer_sizes: list[int],
    scratch_seed: int,
    scratch_scale: float,
    epochs: int,
    batch_size: int,
    learning_rate: float,
    value_loss_weight: float,
    target_temperature: float,
    min_policy_q_margin: float,
    policy_confidence_scale: float,
    min_policy_weight: float,
    q_value_loss_weight: float,
    phase_sample_weights: dict[str, float] | None,
    limit_states: int | None,
    prefer_mps: bool,
    transformer_dropout: float | None = None,
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
            transformer_dropout=0.05
            if transformer_dropout is None
            else transformer_dropout,
        )
    else:
        model, artifact = load_torch_policy(start_model_path, device)
        if transformer_dropout is not None:
            model.set_transformer_dropout(transformer_dropout)
    records = _load_supervised_records(trajectory_paths, limit_states)
    if not records:
        raise ValueError("no supervised trajectory records found")
    phase_counts = _supervised_phase_counts(records)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    updates: list[dict[str, float]] = []
    model.train()
    rng = random.Random(0x51A7E)
    for epoch in range(1, epochs + 1):
        epoch_records = _weighted_supervised_epoch_records(
            records, phase_sample_weights, rng
        )
        if not epoch_records:
            raise ValueError("phase sampling produced no supervised records")
        total_loss = 0.0
        total_policy_loss = 0.0
        total_value_loss = 0.0
        total_q_value_loss = 0.0
        total_correct = 0
        total_soft_targets = 0
        total_target_entropy = 0.0
        total_q_margin = 0.0
        total_policy_weight = 0.0
        total_skipped_policy_targets = 0
        total_states = 0
        for start in range(0, len(epoch_records), batch_size):
            batch = epoch_records[start : start + batch_size]
            losses = []
            policy_losses = []
            value_losses = []
            q_value_losses = []
            correct = 0
            for record in batch:
                feature_record = record["features"]
                count = int(feature_record["candidate_count"])
                features = torch.tensor(
                    feature_record["features"], dtype=torch.float32, device=device
                ).view(count, int(feature_record["input_size"]))
                player_ids = torch.full(
                    (count,), int(record["player_id"]), dtype=torch.long, device=device
                )
                action_heads = torch.tensor(
                    feature_record["action_heads"], dtype=torch.long, device=device
                )
                group_ids = torch.zeros((count,), dtype=torch.long, device=device)
                object_batch = (
                    _record_object_batch(record, device)
                    if model.uses_object_tokens
                    else None
                )
                action_batch = (
                    _record_action_batch(feature_record, device)
                    if model.uses_object_tokens
                    else None
                )
                scores, values = model.candidate_scores_and_values(
                    features,
                    player_ids,
                    action_heads,
                    group_ids,
                    object_batch=object_batch,
                    action_batch=action_batch,
                    group_count=1,
                    action_slot_count=count,
                )
                q_values = record.get("q_values")
                if isinstance(q_values, list) and len(q_values) == count:
                    q_list = [float(value) for value in q_values]
                    q_tensor = torch.tensor(
                        q_list,
                        dtype=torch.float32,
                        device=device,
                    )
                    serialized_policy = record.get("target_policy")
                    if (
                        isinstance(serialized_policy, list)
                        and len(serialized_policy) == count
                    ):
                        target_probs = torch.tensor(
                            [float(value) for value in serialized_policy],
                            dtype=torch.float32,
                            device=device,
                        ).clamp_min(0.0)
                        target_probs = target_probs / target_probs.sum().clamp_min(
                            1e-8
                        )
                    else:
                        target_probs = torch.softmax(
                            q_tensor / max(float(target_temperature), 1e-6), dim=0
                        )
                    policy_loss = -(
                        target_probs.detach() * torch.log_softmax(scores, dim=0)
                    ).sum()
                    target_index = int(torch.argmax(q_tensor).item())
                    value_scalar = float(record.get("target_value", max(q_values)))
                    entropy = float(
                        -(
                            target_probs.detach()
                            * torch.log(target_probs.detach().clamp_min(1e-8))
                        )
                        .sum()
                        .cpu()
                    )
                    q_margin = _q_target_stats(q_list).get("q_margin", 0.0)
                    policy_weight = _policy_confidence_weight(
                        record,
                        q_list,
                        min_policy_q_margin=min_policy_q_margin,
                        policy_confidence_scale=policy_confidence_scale,
                        min_policy_weight=min_policy_weight,
                    )
                    q_logits = q_tensor / max(float(target_temperature), 1e-6)
                    q_value_loss = (
                        (
                            (scores - scores.mean())
                            - (q_logits.detach() - q_logits.detach().mean())
                        )
                        .pow(2)
                        .mean()
                    )
                    total_soft_targets += 1
                    total_target_entropy += entropy
                    total_q_margin += q_margin
                else:
                    target_index = int(record["target_index"])
                    target = torch.tensor(
                        [target_index], dtype=torch.long, device=device
                    )
                    policy_loss = F.cross_entropy(scores.unsqueeze(0), target)
                    value_scalar = (
                        1.0
                        if target_index != int(record.get("heuristic_index", -1))
                        else 0.5
                    )
                    policy_weight = 1.0
                    q_value_loss = torch.zeros((), dtype=torch.float32, device=device)
                value_target = torch.tensor(
                    [value_scalar], dtype=torch.float32, device=device
                )
                value_loss = (values.float() - value_target).pow(2).mean()
                loss = (
                    policy_weight * policy_loss
                    + policy_weight * q_value_loss_weight * q_value_loss
                    + value_loss_weight * value_loss
                )
                losses.append(loss)
                policy_losses.append((policy_weight * policy_loss).detach())
                value_losses.append(value_loss.detach())
                q_value_losses.append((policy_weight * q_value_loss).detach())
                total_policy_weight += policy_weight
                if policy_weight <= 0.0:
                    total_skipped_policy_targets += 1
                correct += (
                    1 if int(torch.argmax(scores).detach().cpu()) == target_index else 0
                )
            if not losses:
                continue
            optimizer.zero_grad(set_to_none=True)
            batch_loss = torch.stack(losses).mean()
            batch_loss.backward()
            grad_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            total_loss += float(batch_loss.detach().cpu()) * len(batch)
            total_policy_loss += float(torch.stack(policy_losses).mean().cpu()) * len(
                batch
            )
            total_value_loss += float(torch.stack(value_losses).mean().cpu()) * len(
                batch
            )
            total_q_value_loss += float(torch.stack(q_value_losses).mean().cpu()) * len(
                batch
            )
            total_correct += correct
            total_states += len(batch)
        update = {
            "epoch": float(epoch),
            "loss": total_loss / max(1, total_states),
            "policy_loss": total_policy_loss / max(1, total_states),
            "value_loss": total_value_loss / max(1, total_states),
            "q_value_loss": total_q_value_loss / max(1, total_states),
            "target_match_rate": total_correct / max(1, total_states),
            "soft_target_rate": total_soft_targets / max(1, total_states),
            "target_entropy": total_target_entropy / max(1, total_soft_targets),
            "q_margin": total_q_margin / max(1, total_soft_targets),
            "policy_weight": total_policy_weight / max(1, total_states),
            "skipped_policy_rate": total_skipped_policy_targets / max(1, total_states),
            "states": float(total_states),
            "grad_norm": float(grad_norm.detach().cpu())
            if isinstance(grad_norm, torch.Tensor)
            else float(grad_norm),
        }
        updates.append(update)
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "torch_policy_supervised_pretrain",
                    "status": "running",
                    "phase": "supervised_pretrain",
                    "output_model": str(output_path),
                    "start_model": str(start_model_path)
                    if start_model_path
                    else "scratch",
                    "model": {
                        "architecture": model.architecture,
                        "layers": model.layer_sizes,
                        "input_size": model.input_size,
                        "head_count": model.head_count,
                    },
                    "training": {
                        "epochs": epochs,
                        "batch_size": batch_size,
                        "learning_rate": learning_rate,
                        "target_temperature": target_temperature,
                        "min_policy_q_margin": min_policy_q_margin,
                        "policy_confidence_scale": policy_confidence_scale,
                        "min_policy_weight": min_policy_weight,
                        "q_value_loss_weight": q_value_loss_weight,
                        "phase_sample_weights": phase_sample_weights or {},
                        "phase_record_counts": phase_counts,
                        "states": len(records),
                        "epoch_states": len(epoch_records),
                    },
                    "progress": {
                        "completed_epochs": epoch,
                        "total_epochs": epochs,
                        "percent": epoch / max(1, epochs),
                    },
                    "summary": update,
                    "updates": list(updates),
                }
            )
    record = {
        "kind": "torch_policy_supervised_pretrain",
        "status": "pretrained",
        "backend": "torch-mps" if device.type == "mps" else "torch",
        "device": str(device),
        "start_model": str(start_model_path) if start_model_path else "scratch",
        "output_model": str(output_path),
        "trajectory_paths": [str(path) for path in trajectory_paths],
        "model": {
            "architecture": model.architecture,
            "layers": model.layer_sizes,
            "input_size": model.input_size,
            "head_count": model.head_count,
            "scratch_seed": scratch_seed if start_model_path is None else None,
            "scratch_scale": scratch_scale if start_model_path is None else None,
        },
        "training": {
            "epochs": epochs,
            "batch_size": batch_size,
            "learning_rate": learning_rate,
            "value_loss_weight": value_loss_weight,
            "target_temperature": target_temperature,
            "min_policy_q_margin": min_policy_q_margin,
            "policy_confidence_scale": policy_confidence_scale,
            "min_policy_weight": min_policy_weight,
            "q_value_loss_weight": q_value_loss_weight,
            "phase_sample_weights": phase_sample_weights or {},
            "phase_record_counts": phase_counts,
            "states": len(records),
            "epoch_states": len(records),
        },
        "updates": updates,
        "summary": updates[-1],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.suffix == ".pt":
        model.save_checkpoint(output_path, training_record=record)
    elif artifact is not None:
        model.export_artifact(artifact, output_path, training_record=record)
    else:
        raise ValueError("scratch Torch policies must be saved as .pt checkpoints")
    return record


def _spawn_distill_env(engine: CEngine, seed: int) -> dict[str, Any]:
    return {
        "pointer": engine.new_engine(seed),
        "seed": seed,
        "actions": 0,
    }


def _add_distill_bucket(
    buckets: dict[str, dict[str, float]], key: str, matched: bool
) -> None:
    bucket = buckets.setdefault(key, {"states": 0.0, "matches": 0.0})
    bucket["states"] += 1.0
    bucket["matches"] += 1.0 if matched else 0.0


def _distill_bucket_rates(
    buckets: dict[str, dict[str, float]],
) -> dict[str, dict[str, float]]:
    return {
        key: {
            "states": values["states"],
            "teacher_match_rate": values["matches"] / values["states"]
            if values["states"]
            else 0.0,
        }
        for key, values in sorted(buckets.items())
    }


def _merge_distill_buckets(
    records: list[dict[str, Any]], field: str
) -> dict[str, dict[str, float]]:
    merged: dict[str, dict[str, float]] = {}
    for record in records:
        for key, values in record.get(field, {}).items():
            states = float(values.get("states", 0.0))
            rate = float(values.get("teacher_match_rate", 0.0))
            bucket = merged.setdefault(key, {"states": 0.0, "matches": 0.0})
            bucket["states"] += states
            bucket["matches"] += rate * states
    return _distill_bucket_rates(merged)


def _distillation_progress(
    *,
    teacher_path: Path,
    output_path: Path,
    model: TorchPolicy,
    device: torch.device,
    states: int,
    completed_states: int,
    batch_size: int,
    rollout_envs: int,
    seed: int,
    learning_rate: float,
    distill_temperature: float,
    summary: dict[str, Any],
    status: str,
) -> dict[str, Any]:
    return {
        "kind": "torch_policy_distillation",
        "status": status,
        "phase": "distillation",
        "backend": "torch-mps" if device.type == "mps" else "torch",
        "teacher_model": str(teacher_path),
        "output_model": str(output_path),
        "device": str(device),
        "model": {
            "architecture": model.architecture,
            "layers": model.layer_sizes,
            "input_size": model.input_size,
            "head_count": model.head_count,
        },
        "training": {
            "states": states,
            "batch_size": batch_size,
            "rollout_envs": rollout_envs,
            "seed": seed,
            "learning_rate": learning_rate,
            "distill_temperature": distill_temperature,
        },
        "progress": {
            "completed_states": completed_states,
            "total_states": states,
            "percent": min(1.0, completed_states / states) if states else 1.0,
        },
        "summary": summary,
    }


def distill_action_transformer_policy(
    engine: CEngine,
    *,
    teacher_model_path: Path,
    output_path: Path,
    layer_sizes: list[int],
    scratch_seed: int,
    scratch_scale: float,
    states: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    distill_temperature: float,
    forced_action_weight: float,
    swap_weight: float,
    play_weight: float,
    assignment_weight: float,
    high_candidate_weight: float,
    high_candidate_threshold: int,
    prefer_mps: bool,
    rollout_envs: int,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    teacher, _ = load_torch_policy(teacher_model_path, device)
    teacher.eval()
    model = TorchPolicy.scratch(
        architecture="action-transformer",
        layer_sizes=layer_sizes,
        input_size=teacher.input_size,
        head_count=teacher.head_count,
        seed=scratch_seed,
        scale=scratch_scale,
        device=device,
    )
    model.train()
    optimizer = torch.optim.AdamW(model.parameters(), lr=learning_rate)
    envs = [
        _spawn_distill_env(engine, seed + offset)
        for offset in range(max(1, rollout_envs))
    ]
    next_seed = seed + len(envs)
    completed_states = 0
    update_records: list[dict[str, Any]] = []
    summary: dict[str, Any] = {}
    temperature = max(0.05, distill_temperature)

    def replace_env(env_index: int) -> None:
        nonlocal next_seed
        try:
            engine.free_engine(envs[env_index]["pointer"])
        except Exception:
            pass
        envs[env_index] = _spawn_distill_env(engine, next_seed)
        next_seed += 1

    if progress_callback is not None:
        progress_callback(
            _distillation_progress(
                teacher_path=teacher_model_path,
                output_path=output_path,
                model=model,
                device=device,
                states=states,
                completed_states=completed_states,
                batch_size=batch_size,
                rollout_envs=rollout_envs,
                seed=seed,
                learning_rate=learning_rate,
                distill_temperature=distill_temperature,
                summary=summary,
                status="running",
            )
        )

    try:
        while completed_states < states:
            groups: list[
                tuple[int, DensePolicyActionFeatures, int, DenseObjectTokens | None]
            ] = []
            guard = 0
            while len(groups) < batch_size and guard < max(64, batch_size * 8):
                guard += 1
                progressed = False
                for env_index, env in enumerate(envs):
                    if len(groups) >= batch_size:
                        break
                    pointer = env["pointer"]
                    player_id = engine.waiting_player(pointer)
                    if player_id < 0 or int(env["actions"]) >= 2000:
                        replace_env(env_index)
                        progressed = True
                        continue
                    candidates = engine.dense_policy_action_features(
                        pointer, player_id=player_id, input_size=model.input_size
                    )
                    if candidates:
                        object_tokens = engine.dense_object_tokens(
                            pointer, perspective_player=player_id
                        )
                        groups.append((env_index, candidates, player_id, object_tokens))
                        progressed = True
                        continue
                    try:
                        action = engine.heuristic_action(pointer)
                    except RuntimeError:
                        replace_env(env_index)
                        progressed = True
                        continue
                    engine.apply_policy_action(pointer, action)
                    env["actions"] = int(env["actions"]) + 1
                    progressed = True
                if not progressed:
                    raise RuntimeError("distillation rollout made no progress")

            if not groups:
                raise RuntimeError("distillation could not collect policy states")

            with torch.no_grad():
                teacher_scores, _, teacher_spans = _batched_candidate_scores(
                    teacher, groups
                )
            student_scores, _, student_spans = _batched_candidate_scores(model, groups)
            losses = []
            loss_weights = []
            matches = 0
            entropies = []
            candidate_counts = []
            action_kind_buckets: dict[str, dict[str, float]] = {}
            candidate_count_buckets: dict[str, dict[str, float]] = {}
            selected_actions: list[tuple[int, KCAction]] = []
            for teacher_span, student_span in _zip_strict(teacher_spans, student_spans):
                env_index, teacher_start, teacher_end, candidates, _ = teacher_span
                _, student_start, student_end, _, _ = student_span
                teacher_logits = teacher_scores[teacher_start:teacher_end] / temperature
                student_logits = student_scores[student_start:student_end] / temperature
                target = torch.softmax(teacher_logits, dim=0)
                losses.append(
                    F.kl_div(
                        torch.log_softmax(student_logits, dim=0),
                        target,
                        reduction="sum",
                    )
                    * (temperature * temperature)
                )
                teacher_choice = int(torch.argmax(teacher_logits).item())
                student_choice = int(torch.argmax(student_logits).item())
                matched = teacher_choice == student_choice
                matches += 1 if matched else 0
                candidate_count = len(candidates)
                candidate_counts.append(candidate_count)
                action_kind = int(candidates.action_at(teacher_choice).kind)
                loss_weight = 1.0
                if candidate_count <= 1:
                    loss_weight *= forced_action_weight
                if action_kind == 2:
                    loss_weight *= swap_weight
                elif action_kind == 4:
                    loss_weight *= play_weight
                elif action_kind == 5:
                    loss_weight *= assignment_weight
                if candidate_count >= high_candidate_threshold:
                    loss_weight *= high_candidate_weight
                loss_weights.append(loss_weight)
                _add_distill_bucket(action_kind_buckets, str(action_kind), matched)
                _add_distill_bucket(
                    candidate_count_buckets, str(candidate_count), matched
                )
                entropies.append(
                    float(
                        -(target * torch.log(target.clamp_min(1e-8)))
                        .sum()
                        .detach()
                        .cpu()
                    )
                )
                selected_actions.append(
                    (env_index, candidates.action_at(teacher_choice))
                )

            loss_tensor = torch.stack(losses)
            weight_tensor = torch.tensor(
                loss_weights, dtype=loss_tensor.dtype, device=loss_tensor.device
            )
            loss = (loss_tensor * weight_tensor).sum() / weight_tensor.sum().clamp_min(
                1e-6
            )
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()

            for env_index, action in selected_actions:
                try:
                    engine.apply_policy_action(envs[env_index]["pointer"], action)
                    envs[env_index]["actions"] = int(envs[env_index]["actions"]) + 1
                except RuntimeError:
                    replace_env(env_index)

            completed_states += len(groups)
            update = {
                "states": completed_states,
                "loss": float(loss.detach().cpu()),
                "teacher_match_rate": matches / len(groups),
                "teacher_entropy": _mean(entropies),
                "candidate_count_mean": _mean(candidate_counts),
                "candidate_count_max": max(candidate_counts) if candidate_counts else 0,
                "average_loss_weight": _mean(loss_weights),
                "teacher_match_by_action_kind": _distill_bucket_rates(
                    action_kind_buckets
                ),
                "teacher_match_by_candidate_count": _distill_bucket_rates(
                    candidate_count_buckets
                ),
            }
            update_records.append(update)
            recent_updates = update_records[-20:]
            summary = {
                "loss": _mean([item["loss"] for item in recent_updates]),
                "teacher_match_rate": _mean(
                    [item["teacher_match_rate"] for item in recent_updates]
                ),
                "teacher_entropy": _mean(
                    [item["teacher_entropy"] for item in recent_updates]
                ),
                "candidate_count_mean": _mean(
                    [item["candidate_count_mean"] for item in recent_updates]
                ),
                "candidate_count_max": max(
                    [item["candidate_count_max"] for item in recent_updates], default=0
                ),
                "average_loss_weight": _mean(
                    [item["average_loss_weight"] for item in recent_updates]
                ),
                "teacher_match_by_action_kind": _merge_distill_buckets(
                    recent_updates, "teacher_match_by_action_kind"
                ),
                "teacher_match_by_candidate_count": _merge_distill_buckets(
                    recent_updates, "teacher_match_by_candidate_count"
                ),
            }
            if progress_callback is not None and (
                len(update_records) == 1
                or completed_states >= states
                or len(update_records) % 10 == 0
            ):
                progress_callback(
                    _distillation_progress(
                        teacher_path=teacher_model_path,
                        output_path=output_path,
                        model=model,
                        device=device,
                        states=states,
                        completed_states=min(completed_states, states),
                        batch_size=batch_size,
                        rollout_envs=rollout_envs,
                        seed=seed,
                        learning_rate=learning_rate,
                        distill_temperature=distill_temperature,
                        summary=summary,
                        status="running",
                    )
                )
    finally:
        for env in envs:
            try:
                engine.free_engine(env["pointer"])
            except Exception:
                pass

    record = {
        "kind": "torch_policy_distillation",
        "backend": "torch-mps" if device.type == "mps" else "torch",
        "teacher_model": str(teacher_model_path),
        "output_model": str(output_path),
        "device": str(device),
        "model": {
            "architecture": model.architecture,
            "layers": model.layer_sizes,
            "input_size": model.input_size,
            "head_count": model.head_count,
            "scratch_seed": scratch_seed,
            "scratch_scale": scratch_scale,
        },
        "training": {
            "states": states,
            "batch_size": batch_size,
            "rollout_envs": rollout_envs,
            "seed": seed,
            "learning_rate": learning_rate,
            "distill_temperature": distill_temperature,
            "forced_action_weight": forced_action_weight,
            "swap_weight": swap_weight,
            "play_weight": play_weight,
            "assignment_weight": assignment_weight,
            "high_candidate_weight": high_candidate_weight,
            "high_candidate_threshold": high_candidate_threshold,
        },
        "updates": update_records[-50:],
        "summary": summary,
        "status": "distilled",
    }
    model.save_checkpoint(output_path, training_record=record)
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "distillation",
                "progress": {
                    "completed_states": states,
                    "total_states": states,
                    "percent": 1.0,
                },
            }
        )
    return record


def _winner(scores: list[int], medals: list[int]) -> int:
    best = 0
    for player_id in range(1, 4):
        if (scores[player_id], medals[player_id], player_id) > (
            scores[best],
            medals[best],
            best,
        ):
            best = player_id
    return best


def _curriculum_complete(
    engine: CEngine,
    pointer: Any,
    *,
    start_year: int,
    round_curriculum: bool,
    curriculum_rounds: int,
) -> bool:
    return round_curriculum and engine.year(pointer) >= start_year + max(
        1, curriculum_rounds
    )


def _score_snapshot(
    engine: CEngine, pointer: Any, *, seat: int, action_index: int
) -> dict[str, Any]:
    scores = engine.final_scores(pointer)
    medals = engine.total_medals(pointer)
    winner = _winner(scores, medals)
    return {
        "year": engine.year(pointer),
        "action_index": action_index,
        "scores": scores,
        "medals": medals,
        "winner_id": winner,
        "metrics": asdict(_metrics(scores, medals, winner, seat)),
    }


def _append_score_snapshot(
    snapshots: list[dict[str, Any]],
    engine: CEngine,
    pointer: Any,
    *,
    seat: int,
    action_index: int,
) -> None:
    snapshot = _score_snapshot(engine, pointer, seat=seat, action_index=action_index)
    if not snapshots or snapshots[-1]["year"] != snapshot["year"]:
        snapshots.append(snapshot)


def _scheduled_curriculum_rounds(
    *,
    episode: int,
    episodes: int,
    schedule: str,
    default_rounds: int,
    scaled_rounds: list[int],
    mixed_curriculum_profile: str = "default",
    rng_seed: int | None = None,
) -> int:
    if schedule == "constant":
        return default_rounds
    if schedule == "scaled":
        if not scaled_rounds:
            return default_rounds
        fraction = (episode - 1) / max(1, episodes - 1)
        index = min(len(scaled_rounds) - 1, int(fraction * len(scaled_rounds)))
        return scaled_rounds[index]
    if schedule == "mixed":
        return _sample_mixed_curriculum_rounds(
            episode=episode,
            episodes=episodes,
            profile=mixed_curriculum_profile,
            rng_seed=rng_seed,
        )
    raise ValueError(f"unknown curriculum schedule {schedule!r}")


def _episode_at_fraction(total: int, fraction: float) -> int:
    return min(total, max(1, int(total * fraction) + 1))


def _mixed_curriculum_phases(
    episodes: int, profile: str = "default"
) -> list[dict[str, Any]]:
    total = max(1, episodes)
    if profile == "full-game-heavy":
        boundaries = [
            (0.00, 0.10, [{"rounds": 2, "weight": 1.00}]),
            (
                0.10,
                0.20,
                [{"rounds": 2, "weight": 0.50}, {"rounds": 3, "weight": 0.50}],
            ),
            (0.20, 0.25, [{"rounds": 3, "weight": 1.00}]),
            (
                0.25,
                0.40,
                [{"rounds": 3, "weight": 0.50}, {"rounds": 4, "weight": 0.50}],
            ),
            (
                0.40,
                0.65,
                [{"rounds": 4, "weight": 0.50}, {"rounds": 5, "weight": 0.50}],
            ),
            (0.65, 1.00, [{"rounds": 5, "weight": 1.00}]),
        ]
        phases = []
        for index, (start_fraction, end_fraction, weights) in enumerate(boundaries):
            start_episode = _episode_at_fraction(total, start_fraction)
            end_episode = (
                total
                if end_fraction >= 1.0
                else max(start_episode, int(total * end_fraction))
            )
            phases.append(
                {
                    "name": f"full-game-heavy mix {index + 1}",
                    "start_episode": start_episode,
                    "end_episode": min(end_episode, total),
                    "weights": weights,
                }
            )
        return [
            phase
            for phase in phases
            if int(phase["start_episode"]) <= int(phase["end_episode"])
        ]
    if profile != "default":
        raise ValueError(f"unknown mixed curriculum profile {profile!r}")
    split_a = max(1, int(total * 0.33))
    split_b = max(split_a + 1, int(total * 0.66))
    split_c = max(split_b + 1, int(total * 0.90))
    phases = [
        {
            "name": "early mix",
            "start_episode": 1,
            "end_episode": min(split_a, total),
            "weights": [
                {"rounds": 1, "weight": 0.50},
                {"rounds": 2, "weight": 0.30},
                {"rounds": 5, "weight": 0.20},
            ],
        },
        {
            "name": "middle mix",
            "start_episode": min(split_a + 1, total),
            "end_episode": min(split_b, total),
            "weights": [
                {"rounds": 2, "weight": 0.20},
                {"rounds": 3, "weight": 0.40},
                {"rounds": 4, "weight": 0.20},
                {"rounds": 5, "weight": 0.20},
            ],
        },
        {
            "name": "late mix",
            "start_episode": min(split_b + 1, total),
            "end_episode": min(split_c, total),
            "weights": [
                {"rounds": 3, "weight": 0.10},
                {"rounds": 4, "weight": 0.20},
                {"rounds": 5, "weight": 0.70},
            ],
        },
        {
            "name": "full game",
            "start_episode": min(split_c + 1, total),
            "end_episode": total,
            "weights": [{"rounds": 5, "weight": 1.00}],
        },
    ]
    return [
        phase
        for phase in phases
        if int(phase["start_episode"]) <= int(phase["end_episode"])
    ]


def _sample_mixed_curriculum_rounds(
    *, episode: int, episodes: int, profile: str, rng_seed: int | None
) -> int:
    phase = next(
        (
            item
            for item in _mixed_curriculum_phases(episodes, profile)
            if item["start_episode"] <= episode <= item["end_episode"]
        ),
        _mixed_curriculum_phases(episodes, profile)[-1],
    )
    weights = phase["weights"]
    if rng_seed is None:
        return int(max(weights, key=lambda item: float(item["weight"]))["rounds"])
    draw = random.Random(rng_seed).random()
    cumulative = 0.0
    for item in weights:
        cumulative += float(item["weight"])
        if draw <= cumulative:
            return int(item["rounds"])
    return int(weights[-1]["rounds"])


def _game_result(
    engine: CEngine,
    pointer: Any,
    *,
    seed: int,
    seat: int,
    actions: int,
    log_probs: list[torch.Tensor],
    values: list[torch.Tensor],
    entropies: list[torch.Tensor],
    phase_ids: list[int] | None = None,
    kl_terms: list[torch.Tensor] | None = None,
    ppo_samples: list[dict[str, Any]] | None = None,
    score_snapshots: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    scores = engine.final_scores(pointer)
    medals = engine.total_medals(pointer)
    winner = _winner(scores, medals)
    snapshots = list(score_snapshots or [])
    final_snapshot = {
        "year": engine.year(pointer),
        "action_index": len(log_probs),
        "scores": scores,
        "medals": medals,
        "winner_id": winner,
        "metrics": asdict(_metrics(scores, medals, winner, seat)),
    }
    if snapshots and snapshots[-1]["year"] == final_snapshot["year"]:
        snapshots[-1] = final_snapshot
    else:
        snapshots.append(final_snapshot)
    return {
        "seed": seed,
        "seat": seat,
        "actions": actions,
        "scores": scores,
        "medals": medals,
        "winner_id": winner,
        "metrics": asdict(_metrics(scores, medals, winner, seat)),
        "log_probs": log_probs,
        "values": values,
        "entropies": entropies,
        "phase_ids": phase_ids or [],
        "kl_terms": kl_terms or [],
        "ppo_samples": ppo_samples or [],
        "score_snapshots": snapshots,
    }


def run_torch_game(
    engine: CEngine,
    model: TorchPolicy,
    *,
    seed: int,
    model_seat: int,
    opponent_model: TorchPolicy | None = None,
    sample: bool = False,
    temperature: float = 1.0,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    curriculum_rounds: int = 2,
) -> dict[str, Any]:
    use_round_curriculum = round_curriculum and curriculum_rounds < 5
    pointer = engine.new_engine(
        seed,
        round_curriculum=use_round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
        curriculum_rounds=curriculum_rounds,
    )
    start_year = engine.year(pointer)
    log_probs: list[torch.Tensor] = []
    values: list[torch.Tensor] = []
    entropies: list[torch.Tensor] = []
    phase_ids: list[int] = []
    actions = 0
    try:
        for _ in range(2000):
            if _curriculum_complete(
                engine,
                pointer,
                start_year=start_year,
                round_curriculum=use_round_curriculum,
                curriculum_rounds=curriculum_rounds,
            ):
                return _game_result(
                    engine,
                    pointer,
                    seed=seed,
                    seat=model_seat,
                    actions=actions,
                    log_probs=log_probs,
                    values=values,
                    entropies=entropies,
                    phase_ids=phase_ids,
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
                    values=values,
                    entropies=entropies,
                    phase_ids=phase_ids,
                )
            if player_id == model_seat:
                candidates = engine.policy_action_features(
                    pointer, player_id=player_id, input_size=model.input_size
                )
                if candidates:
                    object_tokens = (
                        engine.object_tokens(pointer, perspective_player=player_id)
                        if model.uses_object_tokens
                        else None
                    )
                    action, log_prob, value, entropy = _choose_torch_action(
                        model,
                        candidates,
                        player_id,
                        sample=sample,
                        temperature=temperature,
                        object_tokens=object_tokens,
                    )
                    if log_prob is not None:
                        log_probs.append(log_prob)
                        phase_ids.append(engine.phase(pointer))
                    if value is not None:
                        values.append(value)
                    if entropy is not None:
                        entropies.append(entropy)
                else:
                    try:
                        action = engine.heuristic_action(pointer)
                    except RuntimeError:
                        return _game_result(
                            engine,
                            pointer,
                            seed=seed,
                            seat=model_seat,
                            actions=actions,
                            log_probs=log_probs,
                            values=values,
                            entropies=entropies,
                            phase_ids=phase_ids,
                        )
            elif opponent_model is not None:
                candidates = engine.policy_action_features(
                    pointer, player_id=player_id, input_size=opponent_model.input_size
                )
                if candidates:
                    object_tokens = (
                        engine.object_tokens(pointer, perspective_player=player_id)
                        if opponent_model.uses_object_tokens
                        else None
                    )
                    with torch.no_grad():
                        action, _, _, _ = _choose_torch_action(
                            opponent_model,
                            candidates,
                            player_id,
                            sample=False,
                            temperature=temperature,
                            object_tokens=object_tokens,
                        )
                else:
                    try:
                        action = engine.heuristic_action(pointer)
                    except RuntimeError:
                        return _game_result(
                            engine,
                            pointer,
                            seed=seed,
                            seat=model_seat,
                            actions=actions,
                            log_probs=log_probs,
                            values=values,
                            entropies=entropies,
                            phase_ids=phase_ids,
                        )
            else:
                try:
                    action = engine.heuristic_action(pointer)
                except RuntimeError:
                    return _game_result(
                        engine,
                        pointer,
                        seed=seed,
                        seat=model_seat,
                        actions=actions,
                        log_probs=log_probs,
                        values=values,
                        entropies=entropies,
                        phase_ids=phase_ids,
                    )
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
    reference_model: TorchPolicy | None = None,
    sample: bool = False,
    collect_ppo_samples: bool = False,
    temperature: float = 1.0,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    curriculum_rounds: int = 2,
) -> list[dict[str, Any]]:
    envs = []
    use_round_curriculum = round_curriculum and curriculum_rounds < 5
    for seed, seat in _zip_strict(seeds, seats):
        pointer = engine.new_engine(
            seed,
            round_curriculum=use_round_curriculum,
            round_plot_cards=round_plot_cards,
            round_famine_rate=round_famine_rate,
            curriculum_rounds=curriculum_rounds,
        )
        envs.append(
            {
                "pointer": pointer,
                "start_year": engine.year(pointer),
                "seed": seed,
                "seat": seat,
                "actions": 0,
                "log_probs": [],
                "values": [],
                "entropies": [],
                "phase_ids": [],
                "kl_terms": [],
                "ppo_samples": [],
                "score_snapshots": [
                    _score_snapshot(engine, pointer, seat=seat, action_index=0)
                ],
                "done": False,
            }
        )
    complete: list[dict[str, Any] | None] = [None] * len(envs)
    try:
        for _ in range(2000):
            if all(env["done"] for env in envs):
                return [item for item in complete if item is not None]

            model_groups: list[
                tuple[int, DensePolicyActionFeatures, int, DenseObjectTokens | None]
            ] = []
            opponent_groups: list[
                tuple[int, DensePolicyActionFeatures, int, DenseObjectTokens | None]
            ] = []
            progressed = False
            for env_index, env in enumerate(envs):
                if env["done"]:
                    continue
                pointer = env["pointer"]
                if _curriculum_complete(
                    engine,
                    pointer,
                    start_year=int(env["start_year"]),
                    round_curriculum=use_round_curriculum,
                    curriculum_rounds=curriculum_rounds,
                ):
                    complete[env_index] = _game_result(
                        engine,
                        pointer,
                        seed=int(env["seed"]),
                        seat=int(env["seat"]),
                        actions=int(env["actions"]),
                        log_probs=env["log_probs"],
                        values=env["values"],
                        entropies=env["entropies"],
                        phase_ids=env["phase_ids"],
                        kl_terms=env["kl_terms"],
                        ppo_samples=env["ppo_samples"],
                        score_snapshots=env["score_snapshots"],
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
                        values=env["values"],
                        entropies=env["entropies"],
                        phase_ids=env["phase_ids"],
                        kl_terms=env["kl_terms"],
                        ppo_samples=env["ppo_samples"],
                        score_snapshots=env["score_snapshots"],
                    )
                    env["done"] = True
                    engine.free_engine(pointer)
                    progressed = True
                    continue
                if player_id == env["seat"]:
                    candidates = engine.dense_policy_action_features(
                        pointer, player_id=player_id, input_size=model.input_size
                    )
                    if candidates:
                        object_tokens = (
                            engine.dense_object_tokens(
                                pointer, perspective_player=player_id
                            )
                            if model.uses_object_tokens
                            else None
                        )
                        model_groups.append(
                            (env_index, candidates, player_id, object_tokens)
                        )
                        continue
                elif opponent_model is not None:
                    candidates = engine.dense_policy_action_features(
                        pointer,
                        player_id=player_id,
                        input_size=opponent_model.input_size,
                    )
                    if candidates:
                        object_tokens = (
                            engine.dense_object_tokens(
                                pointer, perspective_player=player_id
                            )
                            if opponent_model.uses_object_tokens
                            else None
                        )
                        opponent_groups.append(
                            (env_index, candidates, player_id, object_tokens)
                        )
                        continue
                try:
                    action = engine.heuristic_action(pointer)
                except RuntimeError:
                    complete[env_index] = _game_result(
                        engine,
                        pointer,
                        seed=int(env["seed"]),
                        seat=int(env["seat"]),
                        actions=int(env["actions"]),
                        log_probs=env["log_probs"],
                        values=env["values"],
                        entropies=env["entropies"],
                        phase_ids=env["phase_ids"],
                        kl_terms=env["kl_terms"],
                        ppo_samples=env["ppo_samples"],
                        score_snapshots=env["score_snapshots"],
                    )
                    env["done"] = True
                    engine.free_engine(pointer)
                    progressed = True
                    continue
                engine.apply_policy_action(pointer, action)
                env["actions"] = int(env["actions"]) + 1
                _append_score_snapshot(
                    env["score_snapshots"],
                    engine,
                    pointer,
                    seat=int(env["seat"]),
                    action_index=len(env["log_probs"]),
                )
                progressed = True

            def apply_scored_groups(
                policy: TorchPolicy,
                groups: list[
                    tuple[int, DensePolicyActionFeatures, int, DenseObjectTokens | None]
                ],
                trainable: bool,
            ) -> None:
                nonlocal progressed
                if not groups:
                    return
                scores, values, spans = _batched_candidate_scores(policy, groups)
                reference_scores = None
                reference_spans = None
                if sample and trainable and reference_model is not None:
                    with torch.no_grad():
                        reference_scores, _, reference_spans = (
                            _batched_candidate_scores(reference_model, groups)
                        )
                for env_index, start, end, candidates, group_index in spans:
                    logits = scores[start:end]
                    if sample and trainable:
                        distribution = torch.distributions.Categorical(
                            logits=logits / max(temperature, 0.05)
                        )
                        selected_tensor = distribution.sample()
                        selected = int(selected_tensor.item())
                        old_log_prob = distribution.log_prob(selected_tensor)
                        phase_id = engine.phase(envs[env_index]["pointer"])
                        envs[env_index]["log_probs"].append(old_log_prob)
                        envs[env_index]["values"].append(values[group_index])
                        envs[env_index]["entropies"].append(distribution.entropy())
                        envs[env_index]["phase_ids"].append(phase_id)
                        if collect_ppo_samples:
                            envs[env_index]["ppo_samples"].append(
                                _clone_ppo_sample(
                                    policy,
                                    candidates,
                                    groups[group_index][3],
                                    player_id=groups[group_index][2],
                                    selected=selected,
                                    old_log_prob=old_log_prob,
                                    temperature=temperature,
                                )
                            )
                        if reference_scores is not None and reference_spans is not None:
                            _, reference_start, reference_end, _, _ = reference_spans[
                                group_index
                            ]
                            reference_distribution = torch.distributions.Categorical(
                                logits=reference_scores[reference_start:reference_end]
                                / max(temperature, 0.05)
                            )
                            envs[env_index]["kl_terms"].append(
                                torch.distributions.kl_divergence(
                                    distribution, reference_distribution
                                )
                            )
                    else:
                        selected = int(torch.argmax(logits).item())
                    engine.apply_policy_action(
                        envs[env_index]["pointer"], candidates.action_at(selected)
                    )
                    envs[env_index]["actions"] = int(envs[env_index]["actions"]) + 1
                    _append_score_snapshot(
                        envs[env_index]["score_snapshots"],
                        engine,
                        envs[env_index]["pointer"],
                        seat=int(envs[env_index]["seat"]),
                        action_index=len(envs[env_index]["log_probs"]),
                    )
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
        chunk = scheduled[start : start + max(1, rollout_envs)]
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
                    "torch": {
                        key: torch_game[key]
                        for key in ("winner_id", "scores", "metrics")
                    },
                    "c": {
                        key: c_game[key] for key in ("winner_id", "scores", "metrics")
                    },
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
        "status": "passed_gate"
        if same_winner == total and same_scores == total
        else "inconclusive",
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
    promotion_min_games_per_seat: int = 64,
    promotion_min_bootstrap_samples: int = 1000,
    promotion_objective: str = "utility",
    promotion_utility_win_weight: float = 1.0,
    promotion_utility_rank_weight: float = 0.05,
    promotion_utility_margin_weight: float = 0.001,
    min_utility_delta: float = 0.0,
    candidate_pool_min_utility_delta: float = 0.0,
    risk_min_win_delta_mean: float | None = None,
    risk_min_rank_delta_mean: float | None = None,
    risk_min_margin_delta_mean: float | None = None,
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
        chunk = scheduled[start : start + chunk_size]
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
                    "baseline_model": str(baseline_path)
                    if baseline_path
                    else "heuristic",
                    "candidate_architecture": candidate.architecture,
                    "baseline_architecture": baseline.architecture
                    if baseline is not None
                    else "heuristic",
                    "device": str(device),
                    "round_curriculum": round_curriculum,
                    "curriculum_rounds": 2 if round_curriculum else None,
                    "round_plot_cards": round_plot_cards,
                    "round_famine_rate": round_famine_rate,
                    "progress": {
                        "completed_games": min(start + chunk_size, len(scheduled)),
                        "total_games": len(scheduled),
                        "percent": min(1.0, (start + chunk_size) / len(scheduled))
                        if scheduled
                        else 1.0,
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
                "margin_delta": candidate_metrics["margin"]
                - baseline_metrics["margin"],
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
    evidence_grade = (
        "promotion"
        if (
            games_per_seat >= promotion_min_games_per_seat
            and bootstrap_samples >= promotion_min_bootstrap_samples
            and len(records) >= promotion_min_games_per_seat * 4
        )
        else "selection"
    )
    decision = _promotion_decision(
        win_values=win_values,
        rank_values=rank_values,
        margin_values=margin_values,
        intervals=intervals,
        bootstrap_samples=bootstrap_samples,
        seed=seed,
        objective=promotion_objective,
        utility_win_weight=promotion_utility_win_weight,
        utility_rank_weight=promotion_utility_rank_weight,
        utility_margin_weight=promotion_utility_margin_weight,
        min_win_delta=min_win_delta,
        min_rank_delta=min_rank_delta,
        min_margin_delta=min_margin_delta,
        min_utility_delta=min_utility_delta,
        candidate_pool_min_utility_delta=candidate_pool_min_utility_delta,
        risk_min_win_delta_mean=risk_min_win_delta_mean,
        risk_min_rank_delta_mean=risk_min_rank_delta_mean,
        risk_min_margin_delta_mean=risk_min_margin_delta_mean,
        evidence_grade=evidence_grade,
    )
    record: dict[str, Any] = {
        "kind": "torch_policy_benchmark",
        "candidate_model": str(candidate_path),
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "candidate_architecture": candidate.architecture,
        "baseline_architecture": baseline.architecture
        if baseline is not None
        else "heuristic",
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
        "evidence": {
            "grade": evidence_grade,
            "promotion_eligible": decision["promotion_eligible"],
            "promotion_min_games_per_seat": promotion_min_games_per_seat,
            "promotion_min_bootstrap_samples": promotion_min_bootstrap_samples,
            "paired_same_seed": True,
            "rotated_seats": True,
            "primary_objective": decision["primary_objective"],
            "guardrails": ["rank_delta", "margin_delta"],
            "candidate_pool": decision["candidate_pool"],
            "pass_gate": decision["pass_gate"],
        },
        "promotion_objective": decision["objective"],
        "intervals": intervals,
        "distribution": _margin_shape(records, bootstrap_samples, seed ^ 0xD157),
        "summary": {
            "candidate_win_rate": _mean(
                [record["candidate"]["win"] for record in records]
            ),
            "baseline_win_rate": _mean(
                [record["baseline"]["win"] for record in records]
            ),
            "candidate_average_rank": _mean(
                [record["candidate"]["rank"] for record in records]
            ),
            "baseline_average_rank": _mean(
                [record["baseline"]["rank"] for record in records]
            ),
            "candidate_average_margin": _mean(
                [record["candidate"]["margin"] for record in records]
            ),
            "baseline_average_margin": _mean(
                [record["baseline"]["margin"] for record in records]
            ),
        },
        "status": decision["status"],
    }
    if include_games:
        record["games"] = games
    return record


def _rounded_float_payload(values: list[Any]) -> list[float]:
    return [round(float(value), 6) for value in values]


def _trajectory_oracle_state_key(
    *,
    player_id: int,
    phase_id: int,
    features_record: dict[str, Any],
) -> str:
    object_tokens = features_record.get("object_tokens") or {}
    payload = {
        "player_id": int(player_id),
        "phase_id": int(phase_id),
        "candidate_count": int(features_record.get("candidate_count", 0)),
        "input_size": int(features_record.get("input_size", INPUT_SIZE)),
        "action_heads": list(features_record.get("action_heads", [])),
        "kind_ids": list(features_record.get("kind_ids", [])),
        "player_ids": list(features_record.get("player_ids", [])),
        "suit_ids": list(features_record.get("suit_ids", [])),
        "target_suit_ids": list(features_record.get("target_suit_ids", [])),
        "card_suit_ids": list(features_record.get("card_suit_ids", [])),
        "card_value_ids": list(features_record.get("card_value_ids", [])),
        "hand_suit_ids": list(features_record.get("hand_suit_ids", [])),
        "hand_value_ids": list(features_record.get("hand_value_ids", [])),
        "plot_suit_ids": list(features_record.get("plot_suit_ids", [])),
        "plot_value_ids": list(features_record.get("plot_value_ids", [])),
        "plot_zone_ids": list(features_record.get("plot_zone_ids", [])),
        "action_scalar_count": int(features_record.get("action_scalar_count", 0)),
        "action_scalars": _rounded_float_payload(
            list(features_record.get("action_scalars", []))
        ),
        "features": _rounded_float_payload(list(features_record.get("features", []))),
        "object_tokens": {
            "count": int(object_tokens.get("count", 0)),
            "type_ids": list(object_tokens.get("type_ids", [])),
            "owner_ids": list(object_tokens.get("owner_ids", [])),
            "zone_ids": list(object_tokens.get("zone_ids", [])),
            "suit_ids": list(object_tokens.get("suit_ids", [])),
            "value_ids": list(object_tokens.get("value_ids", [])),
            "index_ids": list(object_tokens.get("index_ids", [])),
            "scalars": _rounded_float_payload(list(object_tokens.get("scalars", []))),
        },
    }
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def _build_trajectory_oracle_table(
    trajectory_paths: list[Path],
) -> tuple[dict[str, tuple[int, ...]], dict[str, Any]]:
    records = _load_supervised_records(trajectory_paths)
    table: dict[str, tuple[int, ...]] = {}
    margins: dict[str, float] = {}
    conflicts = 0
    malformed = 0
    phase_counts: dict[str, int] = {}
    for record in records:
        try:
            features_record = record["features"]
            player_id = int(record["player_id"])
            phase_id = int(record.get("phase_id", 0))
            key = _trajectory_oracle_state_key(
                player_id=player_id,
                phase_id=phase_id,
                features_record=features_record,
            )
            signature = _action_signature(_action_from_dict(record["target_action"]))
            q_margin = float(record.get("q_margin") or 0.0)
        except Exception:
            malformed += 1
            continue
        phase = _supervised_record_phase(record)
        phase_counts[phase] = phase_counts.get(phase, 0) + 1
        existing = table.get(key)
        if existing is not None and existing != signature:
            conflicts += 1
            if q_margin <= margins.get(key, -float("inf")):
                continue
        table[key] = signature
        margins[key] = q_margin
    return table, {
        "records": len(records),
        "unique_states": len(table),
        "conflicts": conflicts,
        "malformed": malformed,
        "phase_record_counts": dict(sorted(phase_counts.items())),
    }


def _baseline_policy_action_or_heuristic(
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    baseline_model: TorchPolicy | None,
) -> KCAction:
    try:
        return _rollout_policy_action(
            engine,
            pointer,
            player_id=player_id,
            rollout_model=baseline_model,
            sample=False,
            temperature=1.0,
        )
    except RuntimeError:
        return engine.heuristic_action(pointer)


def _run_trajectory_oracle_game(
    engine: CEngine,
    *,
    oracle_table: dict[str, tuple[int, ...]],
    baseline_model: TorchPolicy | None,
    seed: int,
    model_seat: int,
    oracle_seats: set[int],
    input_size: int,
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
) -> dict[str, Any]:
    pointer = engine.new_engine(
        seed,
        round_curriculum=round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
        curriculum_rounds=2 if round_curriculum else 5,
    )
    actions = 0
    model_turns = 0
    oracle_hits = 0
    oracle_misses = 0
    target_unmatched = 0
    phase_hits: dict[str, int] = {}
    phase_misses: dict[str, int] = {}
    try:
        for _ in range(2000):
            player_id = engine.waiting_player(pointer)
            if player_id < 0:
                break
            if player_id in oracle_seats:
                model_turns += 1
                phase_id = engine.phase(pointer)
                phase = _phase_name(phase_id)
                candidates = engine.dense_policy_action_features(
                    pointer, player_id=player_id, input_size=input_size
                )
                object_tokens = engine.dense_object_tokens(
                    pointer, perspective_player=player_id
                )
                key = _trajectory_oracle_state_key(
                    player_id=player_id,
                    phase_id=phase_id,
                    features_record=_dense_features_record(candidates, object_tokens),
                )
                target_signature = oracle_table.get(key)
                selected_action: KCAction | None = None
                if target_signature is not None:
                    for index in range(len(candidates)):
                        if _action_signature(candidates.action_at(index)) == target_signature:
                            selected_action = candidates.action_at(index)
                            break
                    if selected_action is not None:
                        oracle_hits += 1
                        phase_hits[phase] = phase_hits.get(phase, 0) + 1
                    else:
                        target_unmatched += 1
                        oracle_misses += 1
                        phase_misses[phase] = phase_misses.get(phase, 0) + 1
                else:
                    oracle_misses += 1
                    phase_misses[phase] = phase_misses.get(phase, 0) + 1
                action = selected_action or _baseline_policy_action_or_heuristic(
                    engine,
                    pointer,
                    player_id=player_id,
                    baseline_model=baseline_model,
                )
            else:
                action = _baseline_policy_action_or_heuristic(
                    engine,
                    pointer,
                    player_id=player_id,
                    baseline_model=baseline_model,
                )
            engine.apply_policy_action(pointer, action)
            actions += 1
        result = _game_result(
            engine,
            pointer,
            seed=seed,
            seat=model_seat,
            actions=actions,
            log_probs=[],
            values=[],
            entropies=[],
        )
        result["oracle"] = {
            "model_turns": model_turns,
            "hits": oracle_hits,
            "misses": oracle_misses,
            "target_unmatched": target_unmatched,
            "coverage": oracle_hits / max(1, model_turns),
            "phase_hits": dict(sorted(phase_hits.items())),
            "phase_misses": dict(sorted(phase_misses.items())),
        }
        return result
    finally:
        engine.free_engine(pointer)


def trajectory_oracle_benchmark(
    engine: CEngine,
    *,
    trajectory_paths: list[Path],
    baseline_path: Path | None,
    games_per_seat: int,
    seed: int,
    bootstrap_samples: int,
    prefer_mps: bool,
    rollout_envs: int = 64,
    input_size: int = INPUT_SIZE,
    oracle_all_seats: bool = False,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    include_games: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    oracle_table, oracle_table_summary = _build_trajectory_oracle_table(
        trajectory_paths
    )
    device = best_device(prefer_mps)
    baseline = None
    if baseline_path is not None:
        baseline, _ = load_torch_policy(baseline_path, device)
        baseline.eval()
    scheduled = [
        (seed + seat * games_per_seat + offset, seat)
        for seat in range(4)
        for offset in range(games_per_seat)
    ]
    chunk_size = max(1, rollout_envs)
    candidate_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    baseline_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    games: list[dict[str, Any]] = []
    for start in range(0, len(scheduled), chunk_size):
        chunk = scheduled[start : start + chunk_size]
        for game_seed, seat in chunk:
            candidate_games_by_key[(game_seed, seat)] = _run_trajectory_oracle_game(
                engine,
                oracle_table=oracle_table,
                baseline_model=baseline,
                seed=game_seed,
                model_seat=seat,
                oracle_seats=set(range(4)) if oracle_all_seats else {seat},
                input_size=input_size,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
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
            with torch.no_grad():
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
                    "kind": "trajectory_oracle_benchmark",
                    "status": "running",
                    "phase": "benchmark",
                    "trajectory_paths": [str(path) for path in trajectory_paths],
                    "baseline_model": str(baseline_path) if baseline_path else "heuristic",
                    "oracle_all_seats": oracle_all_seats,
                    "progress": {
                        "completed_games": min(start + chunk_size, len(scheduled)),
                        "total_games": len(scheduled),
                        "percent": min(1.0, (start + chunk_size) / max(1, len(scheduled))),
                    },
                    "oracle": oracle_table_summary,
                }
            )

    records = []
    oracle_turns = 0
    oracle_hits = 0
    oracle_misses = 0
    target_unmatched = 0
    phase_hits: dict[str, int] = {}
    phase_misses: dict[str, int] = {}
    for game_seed, seat in scheduled:
        candidate_game = candidate_games_by_key[(game_seed, seat)]
        baseline_game = baseline_games_by_key[(game_seed, seat)]
        oracle_stats = candidate_game.get("oracle", {})
        oracle_turns += int(oracle_stats.get("model_turns", 0))
        oracle_hits += int(oracle_stats.get("hits", 0))
        oracle_misses += int(oracle_stats.get("misses", 0))
        target_unmatched += int(oracle_stats.get("target_unmatched", 0))
        for phase, count in (oracle_stats.get("phase_hits") or {}).items():
            phase_hits[phase] = phase_hits.get(phase, 0) + int(count)
        for phase, count in (oracle_stats.get("phase_misses") or {}).items():
            phase_misses[phase] = phase_misses.get(phase, 0) + int(count)
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
                "oracle": oracle_stats,
            }
        )
        if include_games:
            games.append({"candidate": candidate_game, "baseline": baseline_game})

    win_values = [record["win_delta"] for record in records]
    rank_values = [record["rank_delta"] for record in records]
    margin_values = [record["margin_delta"] for record in records]
    intervals = {
        "win_delta": _ci(win_values, bootstrap_samples, seed ^ 0xA11CE),
        "rank_delta": _ci(rank_values, bootstrap_samples, seed ^ 0xA11CF),
        "margin_delta": _ci(margin_values, bootstrap_samples, seed ^ 0xA11D0),
    }
    pass_gate = (
        intervals["win_delta"]["low"] >= 0.0
        and intervals["rank_delta"]["low"] >= 0.0
        and intervals["margin_delta"]["low"] >= 0.0
    )
    record: dict[str, Any] = {
        "kind": "trajectory_oracle_benchmark",
        "trajectory_paths": [str(path) for path in trajectory_paths],
        "candidate_model": "trajectory-oracle",
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "candidate_architecture": "trajectory-oracle",
        "baseline_architecture": baseline.architecture if baseline is not None else "heuristic",
        "device": str(device),
        "rollout_envs": chunk_size,
        "games_per_seat": games_per_seat,
        "total_games": len(records),
        "seed": seed,
        "oracle_all_seats": oracle_all_seats,
        "intervals": intervals,
        "oracle": {
            **oracle_table_summary,
            "model_turns": oracle_turns,
            "hits": oracle_hits,
            "misses": oracle_misses,
            "target_unmatched": target_unmatched,
            "coverage": oracle_hits / max(1, oracle_turns),
            "phase_hits": dict(sorted(phase_hits.items())),
            "phase_misses": dict(sorted(phase_misses.items())),
        },
        "summary": {
            "candidate_win_rate": _mean([record["candidate"]["win"] for record in records]),
            "baseline_win_rate": _mean([record["baseline"]["win"] for record in records]),
            "candidate_average_rank": _mean([record["candidate"]["rank"] for record in records]),
            "baseline_average_rank": _mean([record["baseline"]["rank"] for record in records]),
            "candidate_average_margin": _mean([record["candidate"]["margin"] for record in records]),
            "baseline_average_margin": _mean([record["baseline"]["margin"] for record in records]),
        },
        "status": "passed_selection_gate" if pass_gate else "rejected",
    }
    if include_games:
        record["games"] = games
    return record


def _run_search_oracle_game(
    engine: CEngine,
    *,
    seed: int,
    metric_seat: int,
    oracle_seats: set[int],
    baseline_model: TorchPolicy | None,
    baseline_path: Path | None,
    input_size: int,
    max_search_actions: int,
    rollout_action_limit: int,
    rollouts_per_action: int,
    determinize_search: bool,
    search_horizon: str,
    search_target: str,
    target_temperature: float,
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
    round_curriculum: bool,
    round_plot_cards: int,
    round_famine_rate: float,
    curriculum_rounds: int,
) -> dict[str, Any]:
    pointer = engine.new_engine(
        seed,
        round_curriculum=round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
        curriculum_rounds=curriculum_rounds,
    )
    actions = 0
    oracle_turns = 0
    searched_turns = 0
    fallback_turns = 0
    forced_turns = 0
    rejected_turns = 0
    phase_turns: dict[str, int] = {}
    phase_searched: dict[str, int] = {}
    action_history: list[dict[str, Any]] = []
    try:
        for _ in range(2000):
            player_id = engine.waiting_player(pointer)
            if player_id < 0:
                break
            if player_id in oracle_seats:
                oracle_turns += 1
                phase_id = engine.phase(pointer)
                phase = _phase_name(phase_id)
                phase_turns[phase] = phase_turns.get(phase, 0) + 1
                candidates = engine.dense_policy_action_features(
                    pointer, player_id=player_id, input_size=input_size
                )
                baseline_index = _rollout_policy_index(
                    engine,
                    pointer,
                    candidates=candidates,
                    player_id=player_id,
                    rollout_model=baseline_model,
                )
                target_index, search = _search_target_values(
                    engine,
                    seed=seed,
                    action_history=action_history,
                    candidates=candidates,
                    seat=player_id,
                    baseline_index=baseline_index,
                    round_curriculum=round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    curriculum_rounds=curriculum_rounds,
                    max_search_actions=max_search_actions,
                    rollout_action_limit=rollout_action_limit,
                    rollout_model=baseline_model,
                    rollout_model_path=baseline_path,
                    rollout_sample=False,
                    rollout_temperature=1.0,
                    rollouts_per_action=rollouts_per_action,
                    determinize_search=determinize_search,
                    search_horizon=search_horizon,
                    search_target=search_target,
                    target_temperature=target_temperature,
                    win_weight=win_weight,
                    rank_weight=rank_weight,
                    margin_weight=margin_weight,
                )
                if search.get("searched"):
                    searched_turns += 1
                    phase_searched[phase] = phase_searched.get(phase, 0) + 1
                else:
                    fallback_turns += 1
                    if len(candidates) == 1:
                        forced_turns += 1
                action = candidates.action_at(target_index)
            else:
                action = _baseline_policy_action_or_heuristic(
                    engine,
                    pointer,
                    player_id=player_id,
                    baseline_model=baseline_model,
                )
            try:
                engine.apply_policy_action(pointer, action)
            except RuntimeError:
                if player_id not in oracle_seats:
                    raise
                rejected_turns += 1
                fallback_turns += 1
                action = _baseline_policy_action_or_heuristic(
                    engine,
                    pointer,
                    player_id=player_id,
                    baseline_model=baseline_model,
                )
                engine.apply_policy_action(pointer, action)
            action_history.append(_action_dict(action))
            actions += 1
        result = _game_result(
            engine,
            pointer,
            seed=seed,
            seat=metric_seat,
            actions=actions,
            log_probs=[],
            values=[],
            entropies=[],
        )
        result["oracle"] = {
            "model_turns": oracle_turns,
            "searched_turns": searched_turns,
            "fallback_turns": fallback_turns,
            "forced_turns": forced_turns,
            "rejected_turns": rejected_turns,
            "search_coverage": searched_turns / max(1, oracle_turns),
            "phase_turns": dict(sorted(phase_turns.items())),
            "phase_searched": dict(sorted(phase_searched.items())),
        }
        return result
    finally:
        engine.free_engine(pointer)


def search_oracle_benchmark(
    engine: CEngine,
    *,
    baseline_path: Path | None,
    games_per_seat: int,
    seed: int,
    bootstrap_samples: int,
    prefer_mps: bool,
    rollout_envs: int = 64,
    input_size: int = INPUT_SIZE,
    oracle_all_seats: bool = True,
    max_search_actions: int = 12,
    rollout_action_limit: int = 512,
    rollouts_per_action: int = 2,
    determinize_search: bool = True,
    search_horizon: str = "full-game",
    search_target: str = "paired-baseline",
    target_temperature: float = 0.2,
    win_weight: float = 1.0,
    rank_weight: float = 0.05,
    margin_weight: float = 0.001,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    curriculum_rounds: int = 5,
    include_games: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    baseline = None
    if baseline_path is not None:
        baseline, _ = load_torch_policy(baseline_path, device)
        baseline.eval()
    scheduled = [
        (seed + seat * games_per_seat + offset, seat)
        for seat in range(4)
        for offset in range(games_per_seat)
    ]
    chunk_size = max(1, rollout_envs)
    candidate_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    baseline_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    games: list[dict[str, Any]] = []
    for start in range(0, len(scheduled), chunk_size):
        chunk = scheduled[start : start + chunk_size]
        for game_seed, seat in chunk:
            candidate_games_by_key[(game_seed, seat)] = _run_search_oracle_game(
                engine,
                seed=game_seed,
                metric_seat=seat,
                oracle_seats=set(range(4)) if oracle_all_seats else {seat},
                baseline_model=baseline,
                baseline_path=baseline_path,
                input_size=input_size,
                max_search_actions=max_search_actions,
                rollout_action_limit=rollout_action_limit,
                rollouts_per_action=rollouts_per_action,
                determinize_search=determinize_search,
                search_horizon=search_horizon,
                search_target=search_target,
                target_temperature=target_temperature,
                win_weight=win_weight,
                rank_weight=rank_weight,
                margin_weight=margin_weight,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
                curriculum_rounds=curriculum_rounds if round_curriculum else 5,
            )
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
            with torch.no_grad():
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
                    "kind": "search_oracle_benchmark",
                    "status": "running",
                    "phase": "benchmark",
                    "baseline_model": str(baseline_path) if baseline_path else "heuristic",
                    "oracle_all_seats": oracle_all_seats,
                    "progress": {
                        "completed_games": min(start + chunk_size, len(scheduled)),
                        "total_games": len(scheduled),
                        "percent": min(1.0, (start + chunk_size) / max(1, len(scheduled))),
                    },
                }
            )

    records = []
    oracle_turns = 0
    searched_turns = 0
    fallback_turns = 0
    forced_turns = 0
    rejected_turns = 0
    phase_turns: dict[str, int] = {}
    phase_searched: dict[str, int] = {}
    for game_seed, seat in scheduled:
        candidate_game = candidate_games_by_key[(game_seed, seat)]
        baseline_game = baseline_games_by_key[(game_seed, seat)]
        oracle_stats = candidate_game.get("oracle", {})
        oracle_turns += int(oracle_stats.get("model_turns", 0))
        searched_turns += int(oracle_stats.get("searched_turns", 0))
        fallback_turns += int(oracle_stats.get("fallback_turns", 0))
        forced_turns += int(oracle_stats.get("forced_turns", 0))
        rejected_turns += int(oracle_stats.get("rejected_turns", 0))
        for phase, count in (oracle_stats.get("phase_turns") or {}).items():
            phase_turns[phase] = phase_turns.get(phase, 0) + int(count)
        for phase, count in (oracle_stats.get("phase_searched") or {}).items():
            phase_searched[phase] = phase_searched.get(phase, 0) + int(count)
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
                "oracle": oracle_stats,
            }
        )
        if include_games:
            games.append({"candidate": candidate_game, "baseline": baseline_game})
    intervals = {
        "win_delta": _ci([record["win_delta"] for record in records], bootstrap_samples, seed ^ 0x51A0),
        "rank_delta": _ci([record["rank_delta"] for record in records], bootstrap_samples, seed ^ 0x51A1),
        "margin_delta": _ci([record["margin_delta"] for record in records], bootstrap_samples, seed ^ 0x51A2),
    }
    pass_gate = (
        intervals["win_delta"]["low"] >= 0.0
        and intervals["rank_delta"]["low"] >= 0.0
        and intervals["margin_delta"]["low"] >= 0.0
    )
    record: dict[str, Any] = {
        "kind": "search_oracle_benchmark",
        "candidate_model": "live-search-oracle",
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "candidate_architecture": "live-search-oracle",
        "baseline_architecture": baseline.architecture if baseline is not None else "heuristic",
        "device": str(device),
        "rollout_envs": chunk_size,
        "games_per_seat": games_per_seat,
        "total_games": len(records),
        "seed": seed,
        "oracle_all_seats": oracle_all_seats,
        "search": {
            "max_search_actions": max_search_actions,
            "rollout_action_limit": rollout_action_limit,
            "rollouts_per_action": rollouts_per_action,
            "determinize_search": determinize_search,
            "search_horizon": search_horizon,
            "search_target": search_target,
            "target_temperature": target_temperature,
            "score_weights": {
                "win": win_weight,
                "rank": rank_weight,
                "margin": margin_weight,
            },
        },
        "oracle": {
            "model_turns": oracle_turns,
            "searched_turns": searched_turns,
            "fallback_turns": fallback_turns,
            "forced_turns": forced_turns,
            "rejected_turns": rejected_turns,
            "search_coverage": searched_turns / max(1, oracle_turns),
            "phase_turns": dict(sorted(phase_turns.items())),
            "phase_searched": dict(sorted(phase_searched.items())),
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
        "status": "passed_selection_gate" if pass_gate else "rejected",
    }
    if include_games:
        record["games"] = games
    return record


def _paired_eval_in_memory(
    engine: CEngine,
    *,
    candidate: TorchPolicy,
    baseline: TorchPolicy | None,
    baseline_path: Path | None,
    comparison: str,
    comparison_label: str,
    checkpoint_path: Path | None,
    completed_episodes: int,
    games_per_seat: int,
    seed: int,
    bootstrap_samples: int,
    rollout_envs: int,
    device: torch.device,
) -> dict[str, Any]:
    scheduled = [
        (seed + seat * games_per_seat + offset, seat)
        for seat in range(4)
        for offset in range(games_per_seat)
    ]
    candidate_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    baseline_games_by_key: dict[tuple[int, int], dict[str, Any]] = {}
    chunk_size = max(1, rollout_envs)
    was_training = candidate.training
    candidate.eval()
    if baseline is not None:
        baseline.eval()
    try:
        for start in range(0, len(scheduled), chunk_size):
            chunk = scheduled[start : start + chunk_size]
            with torch.no_grad():
                candidate_games = run_torch_games_batched(
                    engine,
                    candidate,
                    seeds=[item[0] for item in chunk],
                    seats=[item[1] for item in chunk],
                    opponent_model=baseline,
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
                    )
            else:
                with torch.no_grad():
                    baseline_games = run_torch_games_batched(
                        engine,
                        baseline,
                        seeds=[item[0] for item in chunk],
                        seats=[item[1] for item in chunk],
                        opponent_model=baseline,
                    )
                for game in baseline_games:
                    baseline_games_by_key[(int(game["seed"]), int(game["seat"]))] = game
    finally:
        if was_training:
            candidate.train()

    records = []
    for game_seed, seat in scheduled:
        candidate_metrics = candidate_games_by_key[(game_seed, seat)]["metrics"]
        baseline_metrics = baseline_games_by_key[(game_seed, seat)]["metrics"]
        records.append(
            {
                "seed": game_seed,
                "seat": seat,
                "win_delta": candidate_metrics["win"] - baseline_metrics["win"],
                "rank_delta": baseline_metrics["rank"] - candidate_metrics["rank"],
                "margin_delta": candidate_metrics["margin"]
                - baseline_metrics["margin"],
                "candidate": candidate_metrics,
                "baseline": baseline_metrics,
            }
        )
    intervals = {
        "win_delta": _ci(
            [record["win_delta"] for record in records],
            bootstrap_samples,
            seed ^ 0xE10A,
        ),
        "rank_delta": _ci(
            [record["rank_delta"] for record in records],
            bootstrap_samples,
            seed ^ 0xE10B,
        ),
        "margin_delta": _ci(
            [record["margin_delta"] for record in records],
            bootstrap_samples,
            seed ^ 0xE10C,
        ),
    }
    return {
        "kind": "torch_policy_training_eval",
        "status": "evaluated",
        "completed_episodes": completed_episodes,
        "checkpoint_model": str(checkpoint_path) if checkpoint_path else None,
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "comparison": comparison,
        "comparison_label": comparison_label,
        "candidate_architecture": candidate.architecture,
        "baseline_architecture": baseline.architecture
        if baseline is not None
        else "heuristic",
        "device": str(device),
        "seed": seed,
        "games_per_seat": games_per_seat,
        "total_games": len(records),
        "full_game": True,
        "intervals": intervals,
        "distribution": _margin_shape(records, bootstrap_samples, seed ^ 0xE1D7),
        "summary": {
            "candidate_win_rate": _mean(
                [record["candidate"]["win"] for record in records]
            ),
            "baseline_win_rate": _mean(
                [record["baseline"]["win"] for record in records]
            ),
            "candidate_average_rank": _mean(
                [record["candidate"]["rank"] for record in records]
            ),
            "baseline_average_rank": _mean(
                [record["baseline"]["rank"] for record in records]
            ),
            "candidate_average_margin": _mean(
                [record["candidate"]["margin"] for record in records]
            ),
            "baseline_average_margin": _mean(
                [record["baseline"]["margin"] for record in records]
            ),
        },
    }


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
    curriculum_schedule: str,
    curriculum_rounds: int,
    current_curriculum_rounds: int,
    scaled_curriculum_rounds: list[int],
    mixed_curriculum_profile: str,
    round_plot_cards: int,
    round_famine_rate: float,
    opponent_mode: str,
    opponent_schedule: str,
    opponent_model_paths: list[Path],
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
    reward_mode: str,
    reward_baseline_path: Path | None,
    round_rank_weight: float,
    round_margin_weight: float,
    two_round_rank_weight: float,
    two_round_margin_weight: float,
    reward_schedule: str,
    early_win_weight: float,
    early_rank_weight: float,
    early_margin_weight: float,
    late_win_weight: float,
    late_rank_weight: float,
    late_margin_weight: float,
    advantage_mode: str,
    policy_loss_reduction: str,
    use_ppo: bool = False,
    ppo_epochs: int = 4,
    ppo_minibatch_size: int = 256,
    ppo_clip: float = 0.2,
    value_loss_weight: float,
    entropy_weight: float,
    reference_model_path: Path | None,
    reference_kl_weight: float,
    completed: int,
    episode_records: list[dict[str, Any]],
    eval_records: list[dict[str, Any]],
    status: str,
    phase: str = "training",
) -> dict[str, Any]:
    recent = episode_records[-min(32, len(episode_records)) :]
    summary = (
        {
            "average_reward": _mean([item["reward"] for item in recent]),
            "top_rate": _mean([item["win"] for item in recent]),
            "average_rank": _mean([item["rank"] for item in recent]),
            "average_margin": _mean([item["margin"] for item in recent]),
            "average_win_delta": _mean(
                [
                    item["win_delta"]
                    for item in recent
                    if item.get("win_delta") is not None
                ]
            ),
            "average_rank_delta": _mean(
                [
                    item["rank_delta"]
                    for item in recent
                    if item.get("rank_delta") is not None
                ]
            ),
            "average_margin_delta": _mean(
                [
                    item["margin_delta"]
                    for item in recent
                    if item.get("margin_delta") is not None
                ]
            ),
            "average_action_count": _mean(
                [item.get("action_count", 0) for item in recent]
            ),
            "average_value": _mean(
                [
                    item["value_mean"]
                    for item in recent
                    if item.get("value_mean") is not None
                ]
            ),
            "average_entropy": _mean(
                [
                    item["entropy_mean"]
                    for item in recent
                    if item.get("entropy_mean") is not None
                ]
            ),
            "average_win_component": _mean(
                [item.get("win_component", 0.0) for item in recent]
            ),
            "average_rank_component": _mean(
                [item.get("rank_component", 0.0) for item in recent]
            ),
            "average_margin_component": _mean(
                [item.get("margin_component", 0.0) for item in recent]
            ),
            "average_round_component": _mean(
                [item.get("round_component", 0.0) for item in recent]
            ),
            "average_two_round_component": _mean(
                [item.get("two_round_component", 0.0) for item in recent]
            ),
            "average_final_component": _mean(
                [item.get("final_component", 0.0) for item in recent]
            ),
            "phase_action_buckets": _aggregate_episode_phase_buckets(recent),
        }
        if recent
        else {}
    )
    latest_update = next(
        (item for item in reversed(episode_records) if item.get("loss") is not None),
        None,
    )
    if latest_update is not None:
        summary.update(
            {
                "loss": latest_update.get("loss"),
                "policy_loss": latest_update.get("policy_loss"),
                "value_loss": latest_update.get("value_loss"),
                "entropy": latest_update.get("entropy"),
                "reference_kl": latest_update.get("reference_kl"),
                "ppo_approx_kl": latest_update.get("ppo_approx_kl"),
                "ppo_clip_fraction": latest_update.get("ppo_clip_fraction"),
                "advantage_mean": latest_update.get("advantage_mean"),
                "advantage_std": latest_update.get("advantage_std"),
                "phase_update_buckets": latest_update.get("phase_update_buckets"),
            }
        )
    current_weights = {
        "win": recent[-1].get("win_weight", win_weight) if recent else win_weight,
        "rank": recent[-1].get("rank_weight", rank_weight) if recent else rank_weight,
        "margin": recent[-1].get("margin_weight", margin_weight)
        if recent
        else margin_weight,
    }
    return {
        "kind": "torch_policy_training",
        "status": status,
        "phase": phase,
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
            "transformer_dropout": model.transformer_dropout,
            "rollout_envs": 1 if unbatched else rollout_envs,
            "batched_rollouts": not unbatched,
            "round_curriculum": round_curriculum,
            "curriculum_schedule": curriculum_schedule,
            "curriculum_rounds": current_curriculum_rounds
            if round_curriculum
            else None,
            "default_curriculum_rounds": curriculum_rounds
            if round_curriculum
            else None,
            "scaled_curriculum_rounds": scaled_curriculum_rounds,
            "mixed_curriculum_profile": mixed_curriculum_profile,
            "curriculum_mixture": _mixed_curriculum_phases(
                episodes, mixed_curriculum_profile
            )
            if curriculum_schedule == "mixed"
            else None,
            "full_game_currently": round_curriculum and current_curriculum_rounds >= 5,
            "round_plot_cards": round_plot_cards,
            "round_famine_rate": round_famine_rate,
            "opponent_mode": opponent_mode,
            "opponent_schedule": opponent_schedule,
            "opponent_models": [str(path) for path in opponent_model_paths],
            "reward_weights": {
                "win": win_weight,
                "rank": rank_weight,
                "margin": margin_weight,
                "round_rank": round_rank_weight,
                "round_margin": round_margin_weight,
                "two_round_rank": two_round_rank_weight,
                "two_round_margin": two_round_margin_weight,
            },
            "reward_mode": reward_mode,
            "reward_baseline_model": str(reward_baseline_path)
            if reward_baseline_path
            else None,
            "reward_schedule": {
                "mode": reward_schedule,
                "early": {
                    "win": early_win_weight,
                    "rank": early_rank_weight,
                    "margin": early_margin_weight,
                },
                "middle": {
                    "win": win_weight,
                    "rank": rank_weight,
                    "margin": margin_weight,
                },
                "late": {
                    "win": late_win_weight,
                    "rank": late_rank_weight,
                    "margin": late_margin_weight,
                },
            },
            "current_reward_weights": current_weights,
            "advantage_mode": advantage_mode,
            "policy_loss_reduction": policy_loss_reduction,
            "optimizer": "ppo" if use_ppo else "actor-critic",
            "ppo": use_ppo,
            "ppo_epochs": ppo_epochs,
            "ppo_minibatch_size": ppo_minibatch_size,
            "ppo_clip": ppo_clip,
            "value_loss_weight": value_loss_weight,
            "entropy_weight": entropy_weight,
            "reference_model": str(reference_model_path)
            if reference_model_path
            else None,
            "reference_kl_weight": reference_kl_weight,
        },
        "progress": {
            "completed_episodes": completed,
            "total_episodes": episodes,
            "percent": min(1.0, completed / episodes) if episodes else 1.0,
        },
        "curve": _training_curve(episode_records, batch_size=batch_size),
        "evaluations": eval_records[-20:],
        "latest_evaluation": _latest_primary_eval(eval_records),
        "summary": summary,
    }


def _shaped_reward(
    metrics: dict[str, Any],
    *,
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
) -> float:
    return (
        win_weight * float(metrics["win"])
        - rank_weight * (float(metrics["rank"]) - 1.0)
        + margin_weight * float(metrics["margin"])
    )


def _paired_snapshot_delta(
    candidate: dict[str, Any], baseline: dict[str, Any]
) -> dict[str, float]:
    candidate_metrics = candidate["metrics"]
    baseline_metrics = baseline["metrics"]
    return {
        "win": float(candidate_metrics["win"]) - float(baseline_metrics["win"]),
        "rank": float(baseline_metrics["rank"]) - float(candidate_metrics["rank"]),
        "margin": float(candidate_metrics["margin"])
        - float(baseline_metrics["margin"]),
    }


def _paired_round_delta_segments(
    game: dict[str, Any],
    baseline_game: dict[str, Any],
    *,
    final_weights: dict[str, float],
    round_rank_weight: float,
    round_margin_weight: float,
    two_round_rank_weight: float,
    two_round_margin_weight: float,
) -> list[dict[str, Any]]:
    candidate_snapshots = game.get("score_snapshots") or []
    baseline_snapshots = baseline_game.get("score_snapshots") or []
    boundary_count = min(len(candidate_snapshots), len(baseline_snapshots))
    if boundary_count < 2:
        return []

    segments: list[dict[str, Any]] = []
    for index in range(1, boundary_count):
        start = int(candidate_snapshots[index - 1]["action_index"])
        end = int(candidate_snapshots[index]["action_index"])
        if end <= start:
            continue
        previous_delta = _paired_snapshot_delta(
            candidate_snapshots[index - 1], baseline_snapshots[index - 1]
        )
        current_delta = _paired_snapshot_delta(
            candidate_snapshots[index], baseline_snapshots[index]
        )
        round_rank_delta = current_delta["rank"] - previous_delta["rank"]
        round_margin_delta = current_delta["margin"] - previous_delta["margin"]
        round_component = (
            round_rank_weight * round_rank_delta
            + round_margin_weight * round_margin_delta
        )
        two_round_component = 0.0
        two_round_rank_delta = 0.0
        two_round_margin_delta = 0.0
        if index >= 2 and index % 2 == 0:
            two_previous_delta = _paired_snapshot_delta(
                candidate_snapshots[index - 2], baseline_snapshots[index - 2]
            )
            two_round_rank_delta = current_delta["rank"] - two_previous_delta["rank"]
            two_round_margin_delta = (
                current_delta["margin"] - two_previous_delta["margin"]
            )
            two_round_component = (
                two_round_rank_weight * two_round_rank_delta
                + two_round_margin_weight * two_round_margin_delta
            )
        final_component = 0.0
        final_win_component = 0.0
        final_rank_component = 0.0
        final_margin_component = 0.0
        if index == boundary_count - 1:
            final_win_component = final_weights["win"] * current_delta["win"]
            final_rank_component = final_weights["rank"] * current_delta["rank"]
            final_margin_component = final_weights["margin"] * current_delta["margin"]
            final_component = (
                final_win_component + final_rank_component + final_margin_component
            )
        reward = round_component + two_round_component + final_component
        segments.append(
            {
                "start": start,
                "end": end,
                "reward": reward,
                "round_component": round_component,
                "two_round_component": two_round_component,
                "final_component": final_component,
                "round_rank_delta": round_rank_delta,
                "round_margin_delta": round_margin_delta,
                "two_round_rank_delta": two_round_rank_delta,
                "two_round_margin_delta": two_round_margin_delta,
                "final_win_component": final_win_component,
                "final_rank_component": final_rank_component,
                "final_margin_component": final_margin_component,
            }
        )
    return segments


def _scheduled_reward_weights(
    *,
    episode: int,
    episodes: int,
    schedule: str,
    win_weight: float,
    rank_weight: float,
    margin_weight: float,
    early_win_weight: float | None,
    early_rank_weight: float,
    early_margin_weight: float,
    late_win_weight: float | None,
    late_rank_weight: float,
    late_margin_weight: float,
) -> dict[str, float]:
    if schedule == "constant":
        return {"win": win_weight, "rank": rank_weight, "margin": margin_weight}
    if schedule != "staged":
        raise ValueError(f"unknown reward schedule {schedule!r}")
    fraction = (episode - 1) / max(1, episodes - 1)
    if fraction < 1.0 / 3.0:
        return {
            "win": win_weight if early_win_weight is None else early_win_weight,
            "rank": early_rank_weight,
            "margin": early_margin_weight,
        }
    if fraction < 2.0 / 3.0:
        return {"win": win_weight, "rank": rank_weight, "margin": margin_weight}
    return {
        "win": win_weight if late_win_weight is None else late_win_weight,
        "rank": late_rank_weight,
        "margin": late_margin_weight,
    }


def _scheduled_opponent_model(
    *,
    episode: int,
    episodes: int,
    batch_index: int,
    opponent_mode: str,
    opponent_schedule: str,
    model: TorchPolicy,
    opponent_pool: list[TorchPolicy],
) -> tuple[TorchPolicy | None, str]:
    if opponent_mode == "self-play":
        return model, "self-play"
    if opponent_mode == "heuristic" or not opponent_pool:
        return None, "heuristic"
    pool_model = opponent_pool[batch_index % len(opponent_pool)]
    if opponent_schedule == "constant":
        return pool_model, "model-pool"
    if opponent_schedule != "weak-to-baseline":
        raise ValueError(f"unknown opponent schedule {opponent_schedule!r}")
    progress = episode / max(1, episodes)
    if progress < 0.25:
        return None, "heuristic"
    if progress < 0.60 and batch_index % 2 == 0:
        return None, "heuristic"
    return pool_model, "model-pool"


def _latest_primary_eval(eval_records: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not eval_records:
        return None
    latest_episode = max(
        int(record.get("completed_episodes", 0)) for record in eval_records
    )
    latest_records = [
        record
        for record in eval_records
        if int(record.get("completed_episodes", 0)) == latest_episode
    ]
    return next(
        (
            record
            for record in latest_records
            if record.get("comparison") != "heuristic"
        ),
        latest_records[-1],
    )


def _best_primary_eval_checkpoint(
    eval_records: list[dict[str, Any]],
) -> dict[str, Any] | None:
    candidates = [
        record
        for record in eval_records
        if record.get("comparison") != "heuristic" and record.get("checkpoint_model")
    ]
    if not candidates:
        return None
    return max(candidates, key=_primary_eval_score)


def _primary_eval_score(record: dict[str, Any]) -> tuple[float, float, float, int]:
    intervals = (
        record.get("intervals") if isinstance(record.get("intervals"), dict) else {}
    )
    win = (
        intervals.get("win_delta")
        if isinstance(intervals.get("win_delta"), dict)
        else {}
    )
    rank = (
        intervals.get("rank_delta")
        if isinstance(intervals.get("rank_delta"), dict)
        else {}
    )
    margin = (
        intervals.get("margin_delta")
        if isinstance(intervals.get("margin_delta"), dict)
        else {}
    )
    return (
        float(win.get("mean", 0.0)),
        float(rank.get("mean", 0.0)),
        float(margin.get("mean", 0.0)),
        int(record.get("completed_episodes", 0) or 0),
    )


def _normalize_advantages(
    values: torch.Tensor, labels: list[Any], *, mode: str
) -> torch.Tensor:
    if mode == "none" or values.numel() <= 1:
        return values
    if mode == "batch":
        centered = values - values.mean()
        std = centered.std(unbiased=False)
        if float(std.detach().cpu()) < 1e-6:
            return values
        return centered / std
    if mode == "curriculum":
        normalized = torch.empty_like(values)
        for label in set(labels):
            indices = [index for index, item in enumerate(labels) if item == label]
            tensor_indices = torch.tensor(
                indices, dtype=torch.long, device=values.device
            )
            bucket = values[tensor_indices]
            if bucket.numel() <= 1:
                normalized[tensor_indices] = bucket
                continue
            centered = bucket - bucket.mean()
            std = centered.std(unbiased=False)
            normalized[tensor_indices] = (
                bucket if float(std.detach().cpu()) < 1e-6 else centered / std
            )
        return normalized
    raise ValueError(f"unknown advantage mode {mode!r}")


def _episode_policy_loss(losses: list[torch.Tensor], *, mode: str) -> torch.Tensor:
    if not losses:
        raise ValueError("cannot reduce empty policy loss")
    if mode == "episode-sum":
        return torch.stack([items.sum() for items in losses]).mean()
    if mode == "episode-mean":
        return torch.stack([items.mean() for items in losses]).mean()
    if mode == "episode-sqrt":
        return torch.stack(
            [
                items.sum()
                / torch.sqrt(
                    torch.tensor(
                        float(items.numel()), dtype=items.dtype, device=items.device
                    )
                )
                for items in losses
            ]
        ).mean()
    if mode == "action-mean":
        return torch.cat(losses).mean()
    raise ValueError(f"unknown policy loss reduction {mode!r}")


def _phase_update_buckets(
    episodes: list[dict[str, Any]],
    raw_advantages: torch.Tensor,
    *,
    action_key: str,
) -> dict[str, dict[str, Any]]:
    buckets: dict[str, dict[str, float]] = {}
    cursor = 0
    for episode in episodes:
        action_count = len(episode.get(action_key, []))
        phase_ids = list(episode.get("phase_ids") or [])
        entropies = list(episode.get("entropies") or [])
        for index in range(action_count):
            phase_id = phase_ids[index] if index < len(phase_ids) else None
            phase = _phase_name(phase_id)
            bucket = buckets.setdefault(
                phase,
                {
                    "actions": 0.0,
                    "reward_sum": 0.0,
                    "advantage_sum": 0.0,
                    "entropy_sum": 0.0,
                    "entropy_actions": 0.0,
                },
            )
            bucket["actions"] += 1.0
            bucket["reward_sum"] += float(episode["reward"])
            if cursor + index < raw_advantages.numel():
                bucket["advantage_sum"] += float(raw_advantages[cursor + index].cpu())
            if index < len(entropies):
                entropy = entropies[index]
                if isinstance(entropy, torch.Tensor):
                    entropy_value = float(entropy.detach().cpu())
                else:
                    entropy_value = float(entropy)
                bucket["entropy_sum"] += entropy_value
                bucket["entropy_actions"] += 1.0
        cursor += action_count
    return {
        key: {
            "actions": value["actions"],
            "average_reward": value["reward_sum"] / value["actions"]
            if value["actions"]
            else 0.0,
            "average_advantage": value["advantage_sum"] / value["actions"]
            if value["actions"]
            else 0.0,
            "average_entropy": value["entropy_sum"] / value["entropy_actions"]
            if value["entropy_actions"]
            else None,
        }
        for key, value in sorted(buckets.items())
    }


def _episode_phase_action_buckets(
    phase_ids: list[int],
    entropies: list[torch.Tensor],
) -> dict[str, dict[str, Any]]:
    buckets: dict[str, dict[str, float]] = {}
    action_count = max(len(phase_ids), len(entropies))
    for index in range(action_count):
        phase_id = phase_ids[index] if index < len(phase_ids) else None
        phase = _phase_name(phase_id)
        bucket = buckets.setdefault(
            phase,
            {"actions": 0.0, "entropy_sum": 0.0, "entropy_actions": 0.0},
        )
        bucket["actions"] += 1.0
        if index < len(entropies):
            entropy = entropies[index]
            if isinstance(entropy, torch.Tensor):
                entropy_value = float(entropy.detach().cpu())
            else:
                entropy_value = float(entropy)
            bucket["entropy_sum"] += entropy_value
            bucket["entropy_actions"] += 1.0
    return {
        key: {
            "actions": value["actions"],
            "average_entropy": value["entropy_sum"] / value["entropy_actions"]
            if value["entropy_actions"]
            else None,
        }
        for key, value in sorted(buckets.items())
    }


def _aggregate_episode_phase_buckets(
    episode_records: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    buckets: dict[str, dict[str, float]] = {}
    for record in episode_records:
        reward = float(record.get("reward", 0.0))
        phase_buckets = record.get("phase_action_buckets")
        if not isinstance(phase_buckets, dict):
            continue
        for phase, value in phase_buckets.items():
            if not isinstance(value, dict):
                continue
            actions = float(value.get("actions", 0.0))
            bucket = buckets.setdefault(
                str(phase),
                {
                    "actions": 0.0,
                    "reward_sum": 0.0,
                    "entropy_sum": 0.0,
                    "entropy_actions": 0.0,
                },
            )
            bucket["actions"] += actions
            bucket["reward_sum"] += reward * actions
            entropy = value.get("average_entropy")
            if entropy is not None and actions > 0.0:
                bucket["entropy_sum"] += float(entropy) * actions
                bucket["entropy_actions"] += actions
    return {
        phase: {
            "actions": value["actions"],
            "average_reward": value["reward_sum"] / value["actions"]
            if value["actions"]
            else 0.0,
            "average_entropy": value["entropy_sum"] / value["entropy_actions"]
            if value["entropy_actions"]
            else None,
        }
        for phase, value in sorted(buckets.items())
    }


def _optimize_actor_critic_batch(
    optimizer: torch.optim.Optimizer,
    model: TorchPolicy,
    episodes: list[dict[str, Any]],
    *,
    advantage_mode: str,
    policy_loss_reduction: str,
    value_loss_weight: float,
    entropy_weight: float,
    reference_kl_weight: float,
) -> dict[str, Any]:
    device = next(model.parameters()).device
    valid = [
        episode for episode in episodes if episode["log_probs"] and episode["values"]
    ]
    if not valid:
        return {}
    optimizer.zero_grad(set_to_none=True)
    episode_log_probs = [
        torch.stack(episode["log_probs"]).to(device) for episode in valid
    ]
    episode_values = [
        torch.stack(episode["values"]).to(device).float() for episode in valid
    ]
    episode_entropies = [
        torch.stack(episode["entropies"]).to(device).float()
        for episode in valid
        if episode["entropies"]
    ]
    episode_kl_terms = [
        torch.stack(episode["kl_terms"]).to(device).float()
        for episode in valid
        if episode.get("kl_terms")
    ]
    returns = [
        torch.full(
            (len(episode["log_probs"]),),
            float(episode["reward"]),
            dtype=torch.float32,
            device=device,
        )
        for episode in valid
    ]
    flat_values = torch.cat(episode_values)
    flat_returns = torch.cat(returns)
    labels = [
        episode["curriculum_rounds"] for episode in valid for _ in episode["log_probs"]
    ]
    raw_advantages = flat_returns - flat_values.detach()
    advantages = _normalize_advantages(raw_advantages, labels, mode=advantage_mode)
    cursor = 0
    policy_losses = []
    value_losses = []
    curriculum_buckets: dict[str, dict[str, float]] = {}
    for episode, log_probs, values, episode_returns in _zip_strict(
        valid, episode_log_probs, episode_values, returns
    ):
        length = log_probs.numel()
        episode_advantages = advantages[cursor : cursor + length]
        cursor += length
        episode_policy_loss = -log_probs * episode_advantages
        policy_losses.append(episode_policy_loss)
        value_losses.append((values - episode_returns).pow(2))
        bucket = curriculum_buckets.setdefault(
            str(episode["curriculum_rounds"]),
            {
                "episodes": 0.0,
                "actions": 0.0,
                "reward_sum": 0.0,
                "abs_policy_loss_sum": 0.0,
            },
        )
        bucket["episodes"] += 1.0
        bucket["actions"] += float(length)
        bucket["reward_sum"] += float(episode["reward"])
        bucket["abs_policy_loss_sum"] += float(
            episode_policy_loss.detach().abs().sum().cpu()
        )
    policy_loss = _episode_policy_loss(policy_losses, mode=policy_loss_reduction)
    value_loss = torch.cat(value_losses).mean()
    entropy = (
        torch.cat(episode_entropies).mean()
        if episode_entropies
        else torch.zeros((), dtype=torch.float32, device=device)
    )
    reference_kl = (
        torch.cat(episode_kl_terms).mean()
        if episode_kl_terms
        else torch.zeros((), dtype=torch.float32, device=device)
    )
    loss = (
        policy_loss
        + value_loss_weight * value_loss
        + reference_kl_weight * reference_kl
        - entropy_weight * entropy
    )
    loss.backward()
    grad_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
    optimizer.step()
    return {
        "loss": float(loss.detach().cpu()),
        "policy_loss": float(policy_loss.detach().cpu()),
        "value_loss": float(value_loss.detach().cpu()),
        "entropy": float(entropy.detach().cpu()),
        "reference_kl": float(reference_kl.detach().cpu()),
        "advantage_mean": float(raw_advantages.mean().detach().cpu()),
        "advantage_std": float(raw_advantages.std(unbiased=False).detach().cpu())
        if raw_advantages.numel() > 1
        else 0.0,
        "return_mean": float(flat_returns.mean().detach().cpu()),
        "value_mean": float(flat_values.mean().detach().cpu()),
        "grad_norm": float(grad_norm.detach().cpu())
        if isinstance(grad_norm, torch.Tensor)
        else float(grad_norm),
        "action_count": float(sum(len(episode["log_probs"]) for episode in valid)),
        "episode_count": float(len(valid)),
        "curriculum_update_buckets": {
            key: {
                "episodes": value["episodes"],
                "actions": value["actions"],
                "average_reward": value["reward_sum"] / value["episodes"]
                if value["episodes"]
                else 0.0,
                "abs_policy_loss_sum": value["abs_policy_loss_sum"],
            }
            for key, value in sorted(curriculum_buckets.items())
        },
        "phase_update_buckets": _phase_update_buckets(
            valid, raw_advantages, action_key="log_probs"
        ),
    }


def _optimize_ppo_batch(
    optimizer: torch.optim.Optimizer,
    model: TorchPolicy,
    episodes: list[dict[str, Any]],
    *,
    advantage_mode: str,
    value_loss_weight: float,
    entropy_weight: float,
    reference_kl_weight: float,
    reference_model: TorchPolicy | None,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
) -> dict[str, Any]:
    device = next(model.parameters()).device
    valid = [
        episode
        for episode in episodes
        if episode.get("ppo_samples")
        and episode["values"]
        and len(episode["ppo_samples"]) == len(episode["values"])
    ]
    if not valid:
        return {}
    episode_values = [
        torch.stack(episode["values"]).to(device).float() for episode in valid
    ]
    returns = [
        torch.full(
            (len(episode["ppo_samples"]),),
            float(episode["reward"]),
            dtype=torch.float32,
            device=device,
        )
        for episode in valid
    ]
    flat_values = torch.cat(episode_values)
    flat_returns = torch.cat(returns)
    labels = [
        episode["curriculum_rounds"]
        for episode in valid
        for _ in episode["ppo_samples"]
    ]
    raw_advantages = flat_returns - flat_values.detach()
    advantages = _normalize_advantages(
        raw_advantages, labels, mode=advantage_mode
    ).detach()
    flat_samples = [sample for episode in valid for sample in episode["ppo_samples"]]
    sample_count = len(flat_samples)
    minibatch_size = max(1, min(int(ppo_minibatch_size), sample_count))
    epochs = max(1, int(ppo_epochs))
    clip_epsilon = max(0.0, float(ppo_clip))
    stats: list[dict[str, float]] = []
    for _ in range(epochs):
        order = torch.randperm(sample_count)
        for start in range(0, sample_count, minibatch_size):
            index_tensor = order[start : start + minibatch_size].to(device)
            indices = index_tensor.tolist()
            sample_batch = [flat_samples[index] for index in indices]
            log_probs, values, entropies, distribution, old_log_probs = (
                _ppo_samples_outputs_batch(model, sample_batch)
            )
            batch_advantages = advantages[index_tensor]
            batch_returns = flat_returns[index_tensor]
            ratio = torch.exp(log_probs - old_log_probs)
            unclipped = ratio * batch_advantages
            clipped = (
                torch.clamp(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon)
                * batch_advantages
            )
            policy_loss = -torch.minimum(unclipped, clipped).mean()
            value_loss = (values - batch_returns).pow(2).mean()
            entropy = entropies.mean()
            approx_kl = (old_log_probs - log_probs.detach()).mean()
            clip_fraction = (
                (torch.abs(ratio.detach() - 1.0) > clip_epsilon).float().mean()
            )
            if reference_model is not None and reference_kl_weight > 0.0:
                with torch.no_grad():
                    _, _, _, reference_distribution, _ = _ppo_samples_outputs_batch(
                        reference_model, sample_batch
                    )
                reference_kl = torch.distributions.kl_divergence(
                    distribution, reference_distribution
                ).mean()
            else:
                reference_kl = torch.zeros((), dtype=torch.float32, device=device)
            loss = (
                policy_loss
                + value_loss_weight * value_loss
                + reference_kl_weight * reference_kl
                - entropy_weight * entropy
            )
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            grad_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            stats.append(
                {
                    "loss": float(loss.detach().cpu()),
                    "policy_loss": float(policy_loss.detach().cpu()),
                    "value_loss": float(value_loss.detach().cpu()),
                    "entropy": float(entropy.detach().cpu()),
                    "reference_kl": float(reference_kl.detach().cpu()),
                    "approx_kl": float(approx_kl.detach().cpu()),
                    "clip_fraction": float(clip_fraction.detach().cpu()),
                    "grad_norm": float(grad_norm.detach().cpu())
                    if isinstance(grad_norm, torch.Tensor)
                    else float(grad_norm),
                }
            )
    recent = stats[-max(1, min(len(stats), 20)) :]
    curriculum_buckets: dict[str, dict[str, float]] = {}
    for episode in valid:
        bucket = curriculum_buckets.setdefault(
            str(episode["curriculum_rounds"]),
            {
                "episodes": 0.0,
                "actions": 0.0,
                "reward_sum": 0.0,
            },
        )
        bucket["episodes"] += 1.0
        bucket["actions"] += float(len(episode["ppo_samples"]))
        bucket["reward_sum"] += float(episode["reward"])
    return {
        "loss": _mean([item["loss"] for item in recent]),
        "policy_loss": _mean([item["policy_loss"] for item in recent]),
        "value_loss": _mean([item["value_loss"] for item in recent]),
        "entropy": _mean([item["entropy"] for item in recent]),
        "reference_kl": _mean([item["reference_kl"] for item in recent]),
        "ppo_approx_kl": _mean([item["approx_kl"] for item in recent]),
        "ppo_clip_fraction": _mean([item["clip_fraction"] for item in recent]),
        "advantage_mean": float(raw_advantages.mean().detach().cpu()),
        "advantage_std": float(raw_advantages.std(unbiased=False).detach().cpu())
        if raw_advantages.numel() > 1
        else 0.0,
        "return_mean": float(flat_returns.mean().detach().cpu()),
        "value_mean": float(flat_values.mean().detach().cpu()),
        "grad_norm": _mean([item["grad_norm"] for item in recent]),
        "action_count": float(sample_count),
        "episode_count": float(len(valid)),
        "ppo_epochs": float(epochs),
        "ppo_minibatch_size": float(minibatch_size),
        "ppo_clip": float(clip_epsilon),
        "curriculum_update_buckets": {
            key: {
                "episodes": value["episodes"],
                "actions": value["actions"],
                "average_reward": value["reward_sum"] / value["episodes"]
                if value["episodes"]
                else 0.0,
            }
            for key, value in sorted(curriculum_buckets.items())
        },
        "phase_update_buckets": _phase_update_buckets(
            valid, raw_advantages, action_key="ppo_samples"
        ),
    }


def _training_curve(
    episode_records: list[dict[str, Any]], batch_size: int = 1, max_points: int = 800
) -> dict[str, Any]:
    if not episode_records:
        return {"points": [], "sampled": False, "source_episodes": 0}
    bucket_size = max(1, int(batch_size))
    buckets = [
        episode_records[start : start + bucket_size]
        for start in range(0, len(episode_records), bucket_size)
    ]
    stride = max(1, (len(buckets) + max_points - 1) // max_points)
    points = []

    def average(items: list[dict[str, Any]], key: str, default: float = 0.0) -> float:
        values = [
            float(item.get(key, default)) for item in items if item.get(key) is not None
        ]
        return _mean(values)

    def latest_average(items: list[dict[str, Any]], source_key: str) -> float | None:
        values = [
            float(item[source_key])
            for item in items
            if item.get(source_key) is not None
        ]
        return _mean(values) if values else None

    for start in range(0, len(buckets), stride):
        selected_buckets = buckets[start : start + stride]
        bucket = [item for selected in selected_buckets for item in selected]
        if not bucket:
            continue
        item = bucket[-1]
        value = latest_average(bucket, "value_mean")
        entropy = latest_average(bucket, "entropy_mean")
        loss = latest_average(bucket, "loss")
        policy_loss = latest_average(bucket, "policy_loss")
        value_loss = latest_average(bucket, "value_loss")
        points.append(
            {
                "episode": int(item["episode"]),
                "reward": average(bucket, "reward"),
                "win": average(bucket, "win"),
                "rank": average(bucket, "rank"),
                "margin": average(bucket, "margin"),
                "baseline_win": latest_average(bucket, "baseline_win"),
                "baseline_rank": latest_average(bucket, "baseline_rank"),
                "baseline_margin": latest_average(bucket, "baseline_margin"),
                "win_delta": latest_average(bucket, "win_delta"),
                "rank_delta": latest_average(bucket, "rank_delta"),
                "margin_delta": latest_average(bucket, "margin_delta"),
                "win_component": average(bucket, "win_component"),
                "rank_component": average(bucket, "rank_component"),
                "margin_component": average(bucket, "margin_component"),
                "curriculum_rounds": int(item.get("curriculum_rounds", 5)),
                "action_count": int(round(average(bucket, "action_count"))),
                "value": value,
                "entropy": entropy,
                "loss": loss,
                "policy_loss": policy_loss,
                "value_loss": value_loss,
            }
        )
    return {
        "points": points,
        "sampled": stride > 1 or bucket_size > 1,
        "source_episodes": len(episode_records),
        "bucket_size": bucket_size,
        "source_batches": len(buckets),
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
    transformer_dropout: float | None = None,
    opponent_model_paths: list[Path] | None = None,
    opponent_mode: str = "heuristic",
    opponent_schedule: str = "constant",
    win_weight: float = 1.0,
    rank_weight: float = 0.1,
    margin_weight: float = 0.005,
    reward_mode: str = "absolute",
    reward_baseline_path: Path | None = None,
    round_rank_weight: float = 0.10,
    round_margin_weight: float = 0.002,
    two_round_rank_weight: float = 0.15,
    two_round_margin_weight: float = 0.003,
    reward_schedule: str = "constant",
    early_win_weight: float | None = None,
    early_rank_weight: float = 0.2,
    early_margin_weight: float = 0.01,
    late_win_weight: float | None = None,
    late_rank_weight: float = 0.03,
    late_margin_weight: float = 0.001,
    advantage_mode: str = "curriculum",
    policy_loss_reduction: str = "episode-mean",
    use_ppo: bool = False,
    ppo_epochs: int = 4,
    ppo_minibatch_size: int = 256,
    ppo_clip: float = 0.2,
    value_loss_weight: float = 0.5,
    entropy_weight: float = 0.01,
    reference_model_path: Path | None = None,
    reference_kl_weight: float = 0.0,
    eval_interval: int = 0,
    eval_games_per_seat: int = 8,
    eval_seed: int = 52_000_000,
    eval_bootstrap_samples: int = 500,
    eval_baseline_path: Path | None = None,
    eval_include_heuristic: bool = False,
    select_best_eval_checkpoint: bool = False,
    eval_patience: int = 0,
    round_curriculum: bool = False,
    curriculum_schedule: str = "constant",
    curriculum_rounds: int = 2,
    scaled_curriculum_rounds: list[int] | None = None,
    mixed_curriculum_profile: str = "default",
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
    unbatched: bool = False,
    record_eval_history: bool = False,
    reinitialize_architecture: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    opponent_model_paths = opponent_model_paths or []
    scaled_curriculum_rounds = scaled_curriculum_rounds or [2, 3, 4, 5]
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
            transformer_dropout=0.05
            if transformer_dropout is None
            else transformer_dropout,
        )
    else:
        source_model, artifact = load_torch_policy(start_model_path, device)
        if reinitialize_architecture:
            model = TorchPolicy.scratch(
                architecture=architecture,
                layer_sizes=layer_sizes,
                input_size=source_model.input_size,
                head_count=source_model.head_count,
                seed=scratch_seed,
                scale=scratch_scale,
                device=device,
                transformer_dropout=0.05
                if transformer_dropout is None
                else transformer_dropout,
            )
            initialize_policy_from_source(model, source_model)
        else:
            model = source_model
        if transformer_dropout is not None:
            model.set_transformer_dropout(transformer_dropout)
    opponent_pool: list[TorchPolicy] = []
    if opponent_mode == "model-pool":
        if not opponent_model_paths:
            raise ValueError(
                "--opponent-mode model-pool requires at least one --opponent-model"
            )
        for path in opponent_model_paths:
            opponent, _ = load_torch_policy(path, device)
            opponent.eval()
            opponent_pool.append(opponent)
    elif opponent_mode not in {"heuristic", "self-play"}:
        raise ValueError(f"unknown opponent mode {opponent_mode!r}")
    eval_baseline: TorchPolicy | None = None
    if eval_baseline_path is None and opponent_model_paths:
        eval_baseline_path = opponent_model_paths[0]
    if eval_baseline_path is not None:
        eval_baseline, _ = load_torch_policy(eval_baseline_path, device)
        eval_baseline.eval()
    paired_reward_modes = {"paired-baseline-delta", "paired-baseline-round-delta"}
    if reward_mode not in {"absolute", *paired_reward_modes}:
        raise ValueError(f"unknown reward mode {reward_mode!r}")
    if reward_mode in paired_reward_modes and reward_baseline_path is None:
        reward_baseline_path = eval_baseline_path or (
            opponent_model_paths[0] if opponent_model_paths else None
        )
    reward_baseline: TorchPolicy | None = None
    if reward_baseline_path is not None:
        reward_baseline, _ = load_torch_policy(reward_baseline_path, device)
        reward_baseline.eval()
    if reward_mode in paired_reward_modes and reward_baseline is None:
        raise ValueError(
            f"--reward-mode {reward_mode} requires --reward-baseline, --eval-baseline, or --opponent-model"
        )
    if reference_kl_weight < 0.0:
        raise ValueError("--reference-kl-weight must be non-negative")
    if reference_model_path is None and reference_kl_weight > 0.0:
        reference_model_path = start_model_path
    reference_model: TorchPolicy | None = None
    if reference_model_path is not None and reference_kl_weight > 0.0:
        reference_model, _ = load_torch_policy(reference_model_path, device)
        reference_model.eval()
    if unbatched and reference_model is not None:
        raise ValueError("--reference-kl-weight is only supported by batched rollouts")
    if unbatched and use_ppo:
        raise ValueError("--ppo is only supported by batched rollouts")
    model.train()
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    episode_records = []
    pending_episodes: list[dict[str, Any]] = []
    update_records: list[dict[str, Any]] = []
    eval_records: list[dict[str, Any]] = []
    completed = 0
    next_eval_episode = eval_interval if eval_interval > 0 else None
    best_eval_score: tuple[float, float, float, int] | None = None
    evals_since_improvement = 0
    early_stop: dict[str, Any] | None = None
    initial_curriculum_rounds = _scheduled_curriculum_rounds(
        episode=1,
        episodes=episodes,
        schedule=curriculum_schedule,
        default_rounds=curriculum_rounds,
        scaled_rounds=scaled_curriculum_rounds,
        mixed_curriculum_profile=mixed_curriculum_profile,
        rng_seed=seed ^ 0xC11C01,
    )
    initial_round_curriculum = round_curriculum or curriculum_schedule in {
        "scaled",
        "mixed",
    }
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
                round_curriculum=initial_round_curriculum,
                curriculum_schedule=curriculum_schedule,
                curriculum_rounds=curriculum_rounds,
                current_curriculum_rounds=initial_curriculum_rounds,
                scaled_curriculum_rounds=scaled_curriculum_rounds,
                mixed_curriculum_profile=mixed_curriculum_profile,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
                opponent_mode=opponent_mode,
                opponent_schedule=opponent_schedule,
                opponent_model_paths=opponent_model_paths,
                win_weight=win_weight,
                rank_weight=rank_weight,
                margin_weight=margin_weight,
                reward_mode=reward_mode,
                reward_baseline_path=reward_baseline_path,
                round_rank_weight=round_rank_weight,
                round_margin_weight=round_margin_weight,
                two_round_rank_weight=two_round_rank_weight,
                two_round_margin_weight=two_round_margin_weight,
                reward_schedule=reward_schedule,
                early_win_weight=win_weight
                if early_win_weight is None
                else early_win_weight,
                early_rank_weight=early_rank_weight,
                early_margin_weight=early_margin_weight,
                late_win_weight=win_weight
                if late_win_weight is None
                else late_win_weight,
                late_rank_weight=late_rank_weight,
                late_margin_weight=late_margin_weight,
                advantage_mode=advantage_mode,
                policy_loss_reduction=policy_loss_reduction,
                use_ppo=use_ppo,
                ppo_epochs=ppo_epochs,
                ppo_minibatch_size=ppo_minibatch_size,
                ppo_clip=ppo_clip,
                value_loss_weight=value_loss_weight,
                entropy_weight=entropy_weight,
                reference_model_path=reference_model_path,
                reference_kl_weight=reference_kl_weight,
                completed=completed,
                episode_records=episode_records,
                eval_records=eval_records,
                status="running",
            )
        )
    while completed < episodes:
        count = 1 if unbatched else min(max(1, rollout_envs), episodes - completed)
        seeds = [seed + completed + offset for offset in range(count)]
        seats = [(completed + offset) % 4 for offset in range(count)]
        current_curriculum_rounds = _scheduled_curriculum_rounds(
            episode=completed + 1,
            episodes=episodes,
            schedule=curriculum_schedule,
            default_rounds=curriculum_rounds,
            scaled_rounds=scaled_curriculum_rounds,
            mixed_curriculum_profile=mixed_curriculum_profile,
            rng_seed=(seed + completed + 1) ^ 0xC11C01,
        )
        current_round_curriculum = round_curriculum or curriculum_schedule in {
            "scaled",
            "mixed",
        }
        opponent_model, opponent_label = _scheduled_opponent_model(
            episode=completed + 1,
            episodes=episodes,
            batch_index=completed // max(1, count),
            opponent_mode=opponent_mode,
            opponent_schedule=opponent_schedule,
            model=model,
            opponent_pool=opponent_pool,
        )
        if curriculum_schedule == "mixed":
            curriculum_by_episode = [
                _scheduled_curriculum_rounds(
                    episode=completed + offset + 1,
                    episodes=episodes,
                    schedule=curriculum_schedule,
                    default_rounds=curriculum_rounds,
                    scaled_rounds=scaled_curriculum_rounds,
                    mixed_curriculum_profile=mixed_curriculum_profile,
                    rng_seed=(seed + completed + offset + 1) ^ 0xC11C01,
                )
                for offset in range(count)
            ]
        else:
            curriculum_by_episode = [current_curriculum_rounds] * count
        if unbatched:
            games = [
                run_torch_game(
                    engine,
                    model,
                    seed=seeds[0],
                    model_seat=seats[0],
                    opponent_model=opponent_model,
                    sample=True,
                    temperature=temperature,
                    round_curriculum=current_round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    curriculum_rounds=curriculum_by_episode[0],
                )
            ]
        elif curriculum_schedule == "mixed":
            games_by_index: dict[int, dict[str, Any]] = {}
            for selected_rounds in sorted(set(curriculum_by_episode)):
                indices = [
                    index
                    for index, value in enumerate(curriculum_by_episode)
                    if value == selected_rounds
                ]
                grouped_games = run_torch_games_batched(
                    engine,
                    model,
                    seeds=[seeds[index] for index in indices],
                    seats=[seats[index] for index in indices],
                    opponent_model=opponent_model,
                    reference_model=reference_model,
                    sample=True,
                    collect_ppo_samples=use_ppo,
                    temperature=temperature,
                    round_curriculum=current_round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    curriculum_rounds=selected_rounds,
                )
                for index, game in zip(indices, grouped_games):
                    games_by_index[index] = game
            games = [games_by_index[index] for index in range(count)]
        else:
            games = run_torch_games_batched(
                engine,
                model,
                seeds=seeds,
                seats=seats,
                opponent_model=opponent_model,
                reference_model=reference_model,
                sample=True,
                collect_ppo_samples=use_ppo,
                temperature=temperature,
                round_curriculum=current_round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
                curriculum_rounds=current_curriculum_rounds,
            )
        baseline_games: list[dict[str, Any]] | None = None
        if reward_mode in {"paired-baseline-delta", "paired-baseline-round-delta"}:
            if reward_baseline is None:
                raise RuntimeError(f"{reward_mode} reward has no loaded baseline")
            if curriculum_schedule == "mixed":
                baseline_games_by_index: dict[int, dict[str, Any]] = {}
                for selected_rounds in sorted(set(curriculum_by_episode)):
                    indices = [
                        index
                        for index, value in enumerate(curriculum_by_episode)
                        if value == selected_rounds
                    ]
                    grouped_baseline_games = run_torch_games_batched(
                        engine,
                        reward_baseline,
                        seeds=[seeds[index] for index in indices],
                        seats=[seats[index] for index in indices],
                        opponent_model=reward_baseline,
                        sample=False,
                        temperature=temperature,
                        round_curriculum=current_round_curriculum,
                        round_plot_cards=round_plot_cards,
                        round_famine_rate=round_famine_rate,
                        curriculum_rounds=selected_rounds,
                    )
                    for index, baseline_game in zip(indices, grouped_baseline_games):
                        baseline_games_by_index[index] = baseline_game
                baseline_games = [
                    baseline_games_by_index[index] for index in range(count)
                ]
            else:
                baseline_games = run_torch_games_batched(
                    engine,
                    reward_baseline,
                    seeds=seeds,
                    seats=seats,
                    opponent_model=reward_baseline,
                    sample=False,
                    temperature=temperature,
                    round_curriculum=current_round_curriculum,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    curriculum_rounds=current_curriculum_rounds,
                )
        for game_index, game in enumerate(games):
            metrics = game["metrics"]
            baseline_metrics = (
                baseline_games[game_index]["metrics"]
                if baseline_games is not None
                else None
            )
            episode_number = len(episode_records) + 1
            scheduled_weights = _scheduled_reward_weights(
                episode=episode_number,
                episodes=episodes,
                schedule=reward_schedule,
                win_weight=win_weight,
                rank_weight=rank_weight,
                margin_weight=margin_weight,
                early_win_weight=early_win_weight,
                early_rank_weight=early_rank_weight,
                early_margin_weight=early_margin_weight,
                late_win_weight=late_win_weight,
                late_rank_weight=late_rank_weight,
                late_margin_weight=late_margin_weight,
            )
            if baseline_metrics is None:
                reward = _shaped_reward(
                    metrics,
                    win_weight=scheduled_weights["win"],
                    rank_weight=scheduled_weights["rank"],
                    margin_weight=scheduled_weights["margin"],
                )
                win_component = scheduled_weights["win"] * float(metrics["win"])
                rank_component = -scheduled_weights["rank"] * (
                    float(metrics["rank"]) - 1.0
                )
                margin_component = scheduled_weights["margin"] * float(
                    metrics["margin"]
                )
                win_delta = None
                rank_delta = None
                margin_delta = None
            else:
                win_delta = float(metrics["win"]) - float(baseline_metrics["win"])
                rank_delta = float(baseline_metrics["rank"]) - float(metrics["rank"])
                margin_delta = float(metrics["margin"]) - float(
                    baseline_metrics["margin"]
                )
                win_component = scheduled_weights["win"] * win_delta
                rank_component = scheduled_weights["rank"] * rank_delta
                margin_component = scheduled_weights["margin"] * margin_delta
                reward = win_component + rank_component + margin_component
            boundary_segments: list[dict[str, Any]] = []
            round_component = 0.0
            two_round_component = 0.0
            final_component = win_component + rank_component + margin_component
            if reward_mode == "paired-baseline-round-delta":
                if baseline_games is None:
                    raise RuntimeError(
                        "paired-baseline-round-delta reward has no baseline games"
                    )
                boundary_segments = _paired_round_delta_segments(
                    game,
                    baseline_games[game_index],
                    final_weights=scheduled_weights,
                    round_rank_weight=round_rank_weight,
                    round_margin_weight=round_margin_weight,
                    two_round_rank_weight=two_round_rank_weight,
                    two_round_margin_weight=two_round_margin_weight,
                )
                if boundary_segments:
                    round_component = sum(
                        float(segment["round_component"])
                        for segment in boundary_segments
                    )
                    two_round_component = sum(
                        float(segment["two_round_component"])
                        for segment in boundary_segments
                    )
                    final_component = sum(
                        float(segment["final_component"])
                        for segment in boundary_segments
                    )
                    reward = round_component + two_round_component + final_component
            curriculum_episode_rounds = (
                curriculum_by_episode[game_index] if current_round_curriculum else 5
            )
            action_count = len(game["log_probs"])
            if action_count and boundary_segments:
                for segment in boundary_segments:
                    start = int(segment["start"])
                    end = int(segment["end"])
                    if end <= start:
                        continue
                    pending_episodes.append(
                        {
                            "log_probs": game["log_probs"][start:end],
                            "values": game["values"][start:end],
                            "entropies": game["entropies"][start:end],
                            "phase_ids": game.get("phase_ids", [])[start:end],
                            "kl_terms": game.get("kl_terms", [])[start:end],
                            "ppo_samples": game.get("ppo_samples", [])[start:end],
                            "reward": float(segment["reward"]),
                            "curriculum_rounds": curriculum_episode_rounds,
                            "action_count": end - start,
                        }
                    )
            elif action_count:
                pending_episodes.append(
                    {
                        "log_probs": game["log_probs"],
                        "values": game["values"],
                        "entropies": game["entropies"],
                        "phase_ids": game.get("phase_ids", []),
                        "kl_terms": game.get("kl_terms", []),
                        "ppo_samples": game.get("ppo_samples", []),
                        "reward": float(reward),
                        "curriculum_rounds": curriculum_episode_rounds,
                        "action_count": action_count,
                    }
                )
            episode_records.append(
                {
                    "episode": episode_number,
                    "seed": game["seed"],
                    "seat": game["seat"],
                    "reward": float(reward),
                    "win": metrics["win"],
                    "rank": metrics["rank"],
                    "margin": metrics["margin"],
                    "baseline_win": baseline_metrics["win"]
                    if baseline_metrics is not None
                    else None,
                    "baseline_rank": baseline_metrics["rank"]
                    if baseline_metrics is not None
                    else None,
                    "baseline_margin": baseline_metrics["margin"]
                    if baseline_metrics is not None
                    else None,
                    "win_delta": win_delta,
                    "rank_delta": rank_delta,
                    "margin_delta": margin_delta,
                    "win_component": win_component,
                    "rank_component": rank_component,
                    "margin_component": margin_component,
                    "round_component": round_component,
                    "two_round_component": two_round_component,
                    "final_component": final_component,
                    "win_weight": scheduled_weights["win"],
                    "rank_weight": scheduled_weights["rank"],
                    "margin_weight": scheduled_weights["margin"],
                    "curriculum_rounds": curriculum_episode_rounds,
                    "action_count": action_count,
                    "value_mean": float(
                        torch.stack(game["values"]).detach().mean().cpu()
                    )
                    if game["values"]
                    else None,
                    "entropy_mean": float(
                        torch.stack(game["entropies"]).detach().mean().cpu()
                    )
                    if game["entropies"]
                    else None,
                    "phase_action_buckets": _episode_phase_action_buckets(
                        list(game.get("phase_ids", [])), list(game["entropies"])
                    ),
                    "opponent": opponent_label,
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
                    round_curriculum=current_round_curriculum,
                    curriculum_schedule=curriculum_schedule,
                    curriculum_rounds=curriculum_rounds,
                    current_curriculum_rounds=current_curriculum_rounds,
                    scaled_curriculum_rounds=scaled_curriculum_rounds,
                    mixed_curriculum_profile=mixed_curriculum_profile,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                    opponent_mode=opponent_mode,
                    opponent_schedule=opponent_schedule,
                    opponent_model_paths=opponent_model_paths,
                    win_weight=win_weight,
                    rank_weight=rank_weight,
                    margin_weight=margin_weight,
                    reward_mode=reward_mode,
                    reward_baseline_path=reward_baseline_path,
                    round_rank_weight=round_rank_weight,
                    round_margin_weight=round_margin_weight,
                    two_round_rank_weight=two_round_rank_weight,
                    two_round_margin_weight=two_round_margin_weight,
                    reward_schedule=reward_schedule,
                    early_win_weight=win_weight
                    if early_win_weight is None
                    else early_win_weight,
                    early_rank_weight=early_rank_weight,
                    early_margin_weight=early_margin_weight,
                    late_win_weight=win_weight
                    if late_win_weight is None
                    else late_win_weight,
                    late_rank_weight=late_rank_weight,
                    late_margin_weight=late_margin_weight,
                    advantage_mode=advantage_mode,
                    policy_loss_reduction=policy_loss_reduction,
                    use_ppo=use_ppo,
                    ppo_epochs=ppo_epochs,
                    ppo_minibatch_size=ppo_minibatch_size,
                    ppo_clip=ppo_clip,
                    value_loss_weight=value_loss_weight,
                    entropy_weight=entropy_weight,
                    reference_model_path=reference_model_path,
                    reference_kl_weight=reference_kl_weight,
                    completed=completed,
                    episode_records=episode_records,
                    eval_records=eval_records,
                    status="running",
                )
            )
        if pending_episodes and (
            len(pending_episodes) >= batch_size or completed >= episodes
        ):
            if use_ppo:
                update = _optimize_ppo_batch(
                    optimizer,
                    model,
                    pending_episodes,
                    advantage_mode=advantage_mode,
                    value_loss_weight=value_loss_weight,
                    entropy_weight=entropy_weight,
                    reference_kl_weight=reference_kl_weight,
                    reference_model=reference_model,
                    ppo_epochs=ppo_epochs,
                    ppo_minibatch_size=ppo_minibatch_size,
                    ppo_clip=ppo_clip,
                )
            else:
                update = _optimize_actor_critic_batch(
                    optimizer,
                    model,
                    pending_episodes,
                    advantage_mode=advantage_mode,
                    policy_loss_reduction=policy_loss_reduction,
                    value_loss_weight=value_loss_weight,
                    entropy_weight=entropy_weight,
                    reference_kl_weight=reference_kl_weight,
                )
            if update:
                update["episode"] = float(completed)
                update_records.append(update)
                episode_records[-1].update(
                    {key: value for key, value in update.items() if key != "episode"}
                )
            pending_episodes.clear()
        if next_eval_episode is not None and completed >= next_eval_episode:
            while next_eval_episode is not None and completed >= next_eval_episode:
                next_eval_episode += eval_interval
            checkpoint_path = None
            if output_path.suffix == ".pt":
                checkpoint_path = (
                    output_path.parent
                    / "checkpoints"
                    / f"{output_path.stem}_ep{completed}.pt"
                )
                model.save_checkpoint(checkpoint_path)
            eval_specs: list[tuple[TorchPolicy | None, Path | None, str, str]] = []
            if eval_baseline is not None or eval_baseline_path is not None:
                eval_specs.append(
                    (eval_baseline, eval_baseline_path, "current_best", "current best")
                )
            if eval_include_heuristic or not eval_specs:
                eval_specs.append((None, None, "heuristic", "heuristic"))
            new_primary_evals: list[dict[str, Any]] = []
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
                        round_curriculum=current_round_curriculum,
                        curriculum_schedule=curriculum_schedule,
                        curriculum_rounds=curriculum_rounds,
                        current_curriculum_rounds=current_curriculum_rounds,
                        scaled_curriculum_rounds=scaled_curriculum_rounds,
                        mixed_curriculum_profile=mixed_curriculum_profile,
                        round_plot_cards=round_plot_cards,
                        round_famine_rate=round_famine_rate,
                        opponent_mode=opponent_mode,
                        opponent_schedule=opponent_schedule,
                        opponent_model_paths=opponent_model_paths,
                        win_weight=win_weight,
                        rank_weight=rank_weight,
                        margin_weight=margin_weight,
                        reward_mode=reward_mode,
                        reward_baseline_path=reward_baseline_path,
                        round_rank_weight=round_rank_weight,
                        round_margin_weight=round_margin_weight,
                        two_round_rank_weight=two_round_rank_weight,
                        two_round_margin_weight=two_round_margin_weight,
                        reward_schedule=reward_schedule,
                        early_win_weight=win_weight
                        if early_win_weight is None
                        else early_win_weight,
                        early_rank_weight=early_rank_weight,
                        early_margin_weight=early_margin_weight,
                        late_win_weight=win_weight
                        if late_win_weight is None
                        else late_win_weight,
                        late_rank_weight=late_rank_weight,
                        late_margin_weight=late_margin_weight,
                        advantage_mode=advantage_mode,
                        policy_loss_reduction=policy_loss_reduction,
                        use_ppo=use_ppo,
                        ppo_epochs=ppo_epochs,
                        ppo_minibatch_size=ppo_minibatch_size,
                        ppo_clip=ppo_clip,
                        value_loss_weight=value_loss_weight,
                        entropy_weight=entropy_weight,
                        reference_model_path=reference_model_path,
                        reference_kl_weight=reference_kl_weight,
                        completed=completed,
                        episode_records=episode_records,
                        eval_records=eval_records,
                        status="running",
                        phase="evaluation",
                    )
                )
            for (
                baseline_model,
                baseline_path,
                comparison,
                comparison_label,
            ) in eval_specs:
                eval_record = _paired_eval_in_memory(
                    engine,
                    candidate=model,
                    baseline=baseline_model,
                    baseline_path=baseline_path,
                    comparison=comparison,
                    comparison_label=comparison_label,
                    checkpoint_path=checkpoint_path,
                    completed_episodes=completed,
                    games_per_seat=eval_games_per_seat,
                    seed=eval_seed + completed,
                    bootstrap_samples=eval_bootstrap_samples,
                    rollout_envs=rollout_envs,
                    device=device,
                )
                eval_records.append(eval_record)
                if eval_record.get("comparison") != "heuristic":
                    new_primary_evals.append(eval_record)
                if record_eval_history:
                    append_history(
                        {
                            **eval_record,
                            "training_output_model": str(output_path),
                            "training_start_model": str(start_model_path)
                            if start_model_path
                            else "scratch",
                            "training_seed": seed,
                            "engine": asdict(engine.provenance()),
                        }
                    )
            if eval_patience > 0:
                for eval_record in new_primary_evals:
                    score = _primary_eval_score(eval_record)
                    if best_eval_score is None or score > best_eval_score:
                        best_eval_score = score
                        evals_since_improvement = 0
                    else:
                        evals_since_improvement += 1
                    if evals_since_improvement >= eval_patience:
                        early_stop = {
                            "reason": "eval_patience",
                            "patience": eval_patience,
                            "completed_episodes": completed,
                            "best_score": list(best_eval_score)
                            if best_eval_score is not None
                            else None,
                            "latest_score": list(score),
                        }
                        break
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
                        round_curriculum=current_round_curriculum,
                        curriculum_schedule=curriculum_schedule,
                        curriculum_rounds=curriculum_rounds,
                        current_curriculum_rounds=current_curriculum_rounds,
                        scaled_curriculum_rounds=scaled_curriculum_rounds,
                        mixed_curriculum_profile=mixed_curriculum_profile,
                        round_plot_cards=round_plot_cards,
                        round_famine_rate=round_famine_rate,
                        opponent_mode=opponent_mode,
                        opponent_schedule=opponent_schedule,
                        opponent_model_paths=opponent_model_paths,
                        win_weight=win_weight,
                        rank_weight=rank_weight,
                        margin_weight=margin_weight,
                        reward_mode=reward_mode,
                        reward_baseline_path=reward_baseline_path,
                        round_rank_weight=round_rank_weight,
                        round_margin_weight=round_margin_weight,
                        two_round_rank_weight=two_round_rank_weight,
                        two_round_margin_weight=two_round_margin_weight,
                        reward_schedule=reward_schedule,
                        early_win_weight=win_weight
                        if early_win_weight is None
                        else early_win_weight,
                        early_rank_weight=early_rank_weight,
                        early_margin_weight=early_margin_weight,
                        late_win_weight=win_weight
                        if late_win_weight is None
                        else late_win_weight,
                        late_rank_weight=late_rank_weight,
                        late_margin_weight=late_margin_weight,
                        advantage_mode=advantage_mode,
                        policy_loss_reduction=policy_loss_reduction,
                        use_ppo=use_ppo,
                        ppo_epochs=ppo_epochs,
                        ppo_minibatch_size=ppo_minibatch_size,
                        ppo_clip=ppo_clip,
                        value_loss_weight=value_loss_weight,
                        entropy_weight=entropy_weight,
                        reference_model_path=reference_model_path,
                        reference_kl_weight=reference_kl_weight,
                        completed=completed,
                        episode_records=episode_records,
                        eval_records=eval_records,
                        status="running",
                    )
                )
            if early_stop is not None:
                break

    summary = {
        "episodes": episodes,
        "completed_episodes": completed,
        "average_reward": sum(item["reward"] for item in episode_records)
        / len(episode_records),
        "top_rate": sum(item["win"] for item in episode_records) / len(episode_records),
        "average_rank": sum(item["rank"] for item in episode_records)
        / len(episode_records),
        "average_margin": sum(item["margin"] for item in episode_records)
        / len(episode_records),
        "average_win_delta": _mean(
            [
                item["win_delta"]
                for item in episode_records
                if item.get("win_delta") is not None
            ]
        ),
        "average_rank_delta": _mean(
            [
                item["rank_delta"]
                for item in episode_records
                if item.get("rank_delta") is not None
            ]
        ),
        "average_margin_delta": _mean(
            [
                item["margin_delta"]
                for item in episode_records
                if item.get("margin_delta") is not None
            ]
        ),
        "average_action_count": _mean(
            [item.get("action_count", 0) for item in episode_records]
        ),
        "average_value": _mean(
            [
                item["value_mean"]
                for item in episode_records
                if item.get("value_mean") is not None
            ]
        ),
        "average_entropy": _mean(
            [
                item["entropy_mean"]
                for item in episode_records
                if item.get("entropy_mean") is not None
            ]
        ),
        "average_win_component": _mean(
            [item.get("win_component", 0.0) for item in episode_records]
        ),
        "average_rank_component": _mean(
            [item.get("rank_component", 0.0) for item in episode_records]
        ),
        "average_margin_component": _mean(
            [item.get("margin_component", 0.0) for item in episode_records]
        ),
        "average_round_component": _mean(
            [item.get("round_component", 0.0) for item in episode_records]
        ),
        "average_two_round_component": _mean(
            [item.get("two_round_component", 0.0) for item in episode_records]
        ),
        "average_final_component": _mean(
            [item.get("final_component", 0.0) for item in episode_records]
        ),
        "phase_action_buckets": _aggregate_episode_phase_buckets(episode_records),
    }
    if update_records:
        latest_update = update_records[-1]
        summary.update(
            {
                "loss": latest_update.get("loss"),
                "policy_loss": latest_update.get("policy_loss"),
                "value_loss": latest_update.get("value_loss"),
                "entropy": latest_update.get("entropy"),
                "reference_kl": latest_update.get("reference_kl"),
                "ppo_approx_kl": latest_update.get("ppo_approx_kl"),
                "ppo_clip_fraction": latest_update.get("ppo_clip_fraction"),
                "advantage_mean": latest_update.get("advantage_mean"),
                "advantage_std": latest_update.get("advantage_std"),
            }
        )
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
            "scratch_seed": scratch_seed
            if start_model_path is None or reinitialize_architecture
            else None,
            "scratch_scale": scratch_scale
            if start_model_path is None or reinitialize_architecture
            else None,
            "reinitialized_architecture": reinitialize_architecture,
        },
        "training": {
            "episodes": episodes,
            "batch_size": batch_size,
            "seed": seed,
            "learning_rate": learning_rate,
            "temperature": temperature,
            "transformer_dropout": model.transformer_dropout,
            "rollout_envs": 1 if unbatched else rollout_envs,
            "batched_rollouts": not unbatched,
            "round_curriculum": round_curriculum
            or curriculum_schedule in {"scaled", "mixed"},
            "curriculum_schedule": curriculum_schedule,
            "curriculum_rounds": curriculum_rounds
            if round_curriculum or curriculum_schedule in {"scaled", "mixed"}
            else None,
            "scaled_curriculum_rounds": scaled_curriculum_rounds,
            "mixed_curriculum_profile": mixed_curriculum_profile,
            "curriculum_mixture": _mixed_curriculum_phases(
                episodes, mixed_curriculum_profile
            )
            if curriculum_schedule == "mixed"
            else None,
            "round_plot_cards": round_plot_cards,
            "round_famine_rate": round_famine_rate,
            "opponent_mode": opponent_mode,
            "opponent_schedule": opponent_schedule,
            "opponent_models": [str(path) for path in opponent_model_paths],
            "reward_weights": {
                "win": win_weight,
                "rank": rank_weight,
                "margin": margin_weight,
                "round_rank": round_rank_weight,
                "round_margin": round_margin_weight,
                "two_round_rank": two_round_rank_weight,
                "two_round_margin": two_round_margin_weight,
            },
            "reward_mode": reward_mode,
            "reward_baseline_model": str(reward_baseline_path)
            if reward_baseline_path
            else None,
            "reward_schedule": {
                "mode": reward_schedule,
                "early": {
                    "win": win_weight if early_win_weight is None else early_win_weight,
                    "rank": early_rank_weight,
                    "margin": early_margin_weight,
                },
                "middle": {
                    "win": win_weight,
                    "rank": rank_weight,
                    "margin": margin_weight,
                },
                "late": {
                    "win": win_weight if late_win_weight is None else late_win_weight,
                    "rank": late_rank_weight,
                    "margin": late_margin_weight,
                },
            },
            "advantage_mode": advantage_mode,
            "policy_loss_reduction": policy_loss_reduction,
            "optimizer": "ppo" if use_ppo else "actor-critic",
            "ppo": use_ppo,
            "ppo_epochs": ppo_epochs,
            "ppo_minibatch_size": ppo_minibatch_size,
            "ppo_clip": ppo_clip,
            "value_loss_weight": value_loss_weight,
            "entropy_weight": entropy_weight,
            "reference_model": str(reference_model_path)
            if reference_model_path
            else None,
            "reference_kl_weight": reference_kl_weight,
            "eval_interval": eval_interval,
            "eval_games_per_seat": eval_games_per_seat,
            "eval_seed": eval_seed,
            "eval_bootstrap_samples": eval_bootstrap_samples,
            "eval_patience": eval_patience,
            "eval_baseline_model": str(eval_baseline_path)
            if eval_baseline_path
            else "heuristic",
            "eval_include_heuristic": eval_include_heuristic,
            "completed_episodes": completed,
        },
        "updates": update_records[-50:],
        "evaluations": eval_records,
        "latest_evaluation": _latest_primary_eval(eval_records),
        "selected_evaluation": None,
        "summary": summary,
        "curve": _training_curve(episode_records, batch_size=batch_size),
        "early_stop": early_stop,
        "status": "early_stopped" if early_stop is not None else "trained",
    }
    if select_best_eval_checkpoint:
        selected_eval = _best_primary_eval_checkpoint(eval_records)
        if selected_eval is not None:
            record["selected_evaluation"] = selected_eval
            record["selected_checkpoint_model"] = selected_eval.get("checkpoint_model")
            selected_checkpoint = Path(str(selected_eval["checkpoint_model"]))
            selected_model, _ = load_torch_policy(selected_checkpoint, device)
            model = selected_model
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
                    "completed_episodes": completed,
                    "total_episodes": episodes,
                    "percent": min(1.0, completed / max(1, episodes)),
                },
            }
        )
    return record
