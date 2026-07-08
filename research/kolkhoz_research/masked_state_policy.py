from __future__ import annotations

import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import torch
from torch import nn
from torch.nn import functional as F

from .c_engine import CEngine, KCAction, KCCard, KCControllers
from .history import append_history
from .model import STATE_INPUT_SIZE
from .torch_policy import best_device

KC_PHASE_PLANNING = 0
KC_PHASE_REQUISITION = 4
KC_PHASE_GAME_OVER = 5

KC_ACTION_SET_TRUMP = 1
KC_ACTION_SWAP = 2
KC_ACTION_CONFIRM_SWAP = 3
KC_ACTION_PLAY_CARD = 4
KC_ACTION_ASSIGN = 5
KC_ACTION_SUBMIT_ASSIGNMENTS = 6
KC_ACTION_CONTINUE_AFTER_REQUISITION = 7
KC_ACTION_UNDO_SWAP = 8

CARD_SUIT_COUNT = 5
CARD_VALUE_COUNT = 15
CARD_COUNT = CARD_SUIT_COUNT * CARD_VALUE_COUNT
SPECIAL_ACTION_COUNT = 4
TRUMP_BASE = SPECIAL_ACTION_COUNT
PLAY_BASE = TRUMP_BASE + 4
ASSIGN_BASE = PLAY_BASE + CARD_COUNT
SWAP_BASE = ASSIGN_BASE + 4
SWAP_ZONE_COUNT = 2
ACTION_SPACE_SIZE = SWAP_BASE + CARD_COUNT * CARD_COUNT * SWAP_ZONE_COUNT

SPECIAL_ACTION_IDS = {
    KC_ACTION_CONFIRM_SWAP: 0,
    KC_ACTION_SUBMIT_ASSIGNMENTS: 1,
    KC_ACTION_CONTINUE_AFTER_REQUISITION: 2,
    KC_ACTION_UNDO_SWAP: 3,
}


def _card_id(card: KCCard) -> int | None:
    suit = int(card.suit)
    value = int(card.value)
    if suit < 0 or suit >= CARD_SUIT_COUNT or value < 0 or value >= CARD_VALUE_COUNT:
        return None
    return suit * CARD_VALUE_COUNT + value


def action_id(action: KCAction) -> int | None:
    kind = int(action.kind)
    if kind in SPECIAL_ACTION_IDS:
        return SPECIAL_ACTION_IDS[kind]
    if kind == KC_ACTION_SET_TRUMP:
        suit = int(action.suit)
        return TRUMP_BASE + suit if 0 <= suit < 4 else None
    if kind == KC_ACTION_PLAY_CARD:
        card = _card_id(action.card)
        return PLAY_BASE + card if card is not None else None
    if kind == KC_ACTION_ASSIGN:
        target = int(action.target_suit)
        return ASSIGN_BASE + target if 0 <= target < 4 else None
    if kind == KC_ACTION_SWAP:
        hand = _card_id(action.hand_card)
        plot = _card_id(action.plot_card)
        zone = 0 if int(action.plot_zone) == 0 else 1 if int(action.plot_zone) == 1 else None
        if hand is None or plot is None or zone is None:
            return None
        return SWAP_BASE + ((hand * CARD_COUNT + plot) * SWAP_ZONE_COUNT + zone)
    return None


@dataclass
class MaskedTransition:
    state: list[float]
    legal_ids: list[int]
    action_id: int
    log_probability: float
    value: float
    player_id: int
    reward: float = 0.0


@dataclass
class MaskedEpisode:
    transitions: list[MaskedTransition]
    scores: list[int]
    rewards: list[float]
    winner_id: int


@dataclass
class RecurrentMaskedTransition:
    state: list[float]
    hidden: list[float]
    legal_ids: list[int]
    action_id: int
    log_probability: float
    value: float
    player_id: int
    reward: float = 0.0


@dataclass
class RecurrentMaskedEpisode:
    transitions: list[RecurrentMaskedTransition]
    scores: list[int]
    rewards: list[float]
    winner_id: int


@dataclass
class TransformerMaskedTransition:
    context: list[list[float]]
    legal_ids: list[int]
    action_id: int
    log_probability: float
    value: float
    player_id: int
    reward: float = 0.0


@dataclass
class TransformerMaskedEpisode:
    transitions: list[TransformerMaskedTransition]
    scores: list[int]
    rewards: list[float]
    winner_id: int


class MaskedStatePolicy(nn.Module):
    def __init__(
        self,
        *,
        input_size: int = STATE_INPUT_SIZE,
        action_space_size: int = ACTION_SPACE_SIZE,
        layer_sizes: list[int] | None = None,
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.action_space_size = action_space_size
        self.layer_sizes = list(layer_sizes or [256, 256])
        layers: list[nn.Module] = []
        previous = input_size
        for size in self.layer_sizes:
            layers.append(nn.Linear(previous, size))
            layers.append(nn.ReLU())
            previous = size
        self.trunk = nn.Sequential(*layers)
        self.policy_head = nn.Linear(previous, action_space_size)
        self.value_head = nn.Linear(previous, 1)

    def forward(self, states: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        hidden = self.trunk(states)
        return self.policy_head(hidden), self.value_head(hidden).squeeze(1)

    @classmethod
    def scratch(
        cls,
        *,
        layer_sizes: list[int],
        seed: int,
        scale: float,
        device: torch.device,
    ) -> "MaskedStatePolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(layer_sizes=layer_sizes)
        with torch.no_grad():
            for parameter in model.parameters():
                if parameter.ndim >= 2:
                    nn.init.normal_(parameter, mean=0.0, std=scale)
                else:
                    parameter.zero_()
        return model.to(device)

    @classmethod
    def from_checkpoint(cls, path: Path, device: torch.device) -> "MaskedStatePolicy":
        checkpoint = torch.load(path, map_location="cpu")
        model = cls(
            input_size=int(checkpoint.get("input_size", STATE_INPUT_SIZE)),
            action_space_size=int(checkpoint.get("action_space_size", ACTION_SPACE_SIZE)),
            layer_sizes=[int(item) for item in checkpoint["layer_sizes"]],
        )
        model.load_state_dict(checkpoint["state_dict"])
        return model.to(device)

    def save_checkpoint(
        self, path: Path, *, training_record: dict[str, Any] | None = None
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-masked-state-policy-v1",
                "architecture": "masked-state-mlp",
                "input_size": self.input_size,
                "action_space_size": self.action_space_size,
                "layer_sizes": self.layer_sizes,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


class TransformerMaskedStatePolicy(nn.Module):
    def __init__(
        self,
        *,
        input_size: int = STATE_INPUT_SIZE,
        hidden_size: int = 128,
        layer_count: int = 2,
        head_count: int = 4,
        context_length: int = 8,
        dropout: float = 0.0,
        action_space_size: int = ACTION_SPACE_SIZE,
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.layer_count = layer_count
        self.head_count = head_count
        self.context_length = context_length
        self.action_space_size = action_space_size
        self.input = nn.Linear(input_size, hidden_size)
        self.position = nn.Parameter(torch.zeros(context_length, hidden_size))
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=hidden_size,
            nhead=head_count,
            dim_feedforward=hidden_size * 4,
            dropout=dropout,
            activation="gelu",
            batch_first=True,
            norm_first=False,
        )
        self.encoder = nn.TransformerEncoder(encoder_layer, num_layers=layer_count)
        self.norm = nn.LayerNorm(hidden_size)
        self.policy_head = nn.Linear(hidden_size, action_space_size)
        self.value_head = nn.Linear(hidden_size, 1)

    def initial_context(self, batch_size: int, device: torch.device) -> torch.Tensor:
        return torch.zeros(
            (batch_size, self.context_length, self.input_size),
            dtype=torch.float32,
            device=device,
        )

    def forward_context(self, contexts: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        hidden = self.input(contexts) + self.position.unsqueeze(0)
        encoded = self.encoder(hidden)
        pooled = self.norm(encoded[:, -1, :])
        return self.policy_head(pooled), self.value_head(pooled).squeeze(1)

    @classmethod
    def scratch(
        cls,
        *,
        hidden_size: int,
        layer_count: int,
        head_count: int,
        context_length: int,
        dropout: float,
        seed: int,
        scale: float,
        device: torch.device,
    ) -> "TransformerMaskedStatePolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(
            hidden_size=hidden_size,
            layer_count=layer_count,
            head_count=head_count,
            context_length=context_length,
            dropout=dropout,
        )
        with torch.no_grad():
            for parameter in model.parameters():
                if parameter.ndim >= 2:
                    nn.init.normal_(parameter, mean=0.0, std=scale)
                else:
                    parameter.zero_()
        return model.to(device)

    @classmethod
    def from_checkpoint(
        cls, path: Path, device: torch.device
    ) -> "TransformerMaskedStatePolicy":
        checkpoint = torch.load(path, map_location="cpu")
        model = cls(
            input_size=int(checkpoint.get("input_size", STATE_INPUT_SIZE)),
            hidden_size=int(checkpoint["hidden_size"]),
            layer_count=int(checkpoint["layer_count"]),
            head_count=int(checkpoint["head_count"]),
            context_length=int(checkpoint["context_length"]),
            action_space_size=int(checkpoint.get("action_space_size", ACTION_SPACE_SIZE)),
        )
        model.load_state_dict(checkpoint["state_dict"])
        return model.to(device)

    def save_checkpoint(
        self, path: Path, *, training_record: dict[str, Any] | None = None
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-masked-state-transformer-policy-v1",
                "architecture": "masked-state-transformer",
                "input_size": self.input_size,
                "hidden_size": self.hidden_size,
                "layer_count": self.layer_count,
                "head_count": self.head_count,
                "context_length": self.context_length,
                "action_space_size": self.action_space_size,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


class RecurrentMaskedStatePolicy(nn.Module):
    def __init__(
        self,
        *,
        input_size: int = STATE_INPUT_SIZE,
        hidden_size: int = 256,
        action_space_size: int = ACTION_SPACE_SIZE,
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.action_space_size = action_space_size
        self.input = nn.Linear(input_size, hidden_size)
        self.rnn = nn.GRUCell(hidden_size, hidden_size)
        self.policy_head = nn.Linear(hidden_size, action_space_size)
        self.value_head = nn.Linear(hidden_size, 1)

    def initial_hidden(self, batch_size: int, device: torch.device) -> torch.Tensor:
        return torch.zeros((batch_size, self.hidden_size), dtype=torch.float32, device=device)

    def forward_step(
        self, states: torch.Tensor, hidden: torch.Tensor
    ) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        embedded = F.relu(self.input(states))
        next_hidden = self.rnn(embedded, hidden)
        logits = self.policy_head(next_hidden)
        values = self.value_head(next_hidden).squeeze(1)
        return logits, values, next_hidden

    @classmethod
    def scratch(
        cls,
        *,
        hidden_size: int,
        seed: int,
        scale: float,
        device: torch.device,
    ) -> "RecurrentMaskedStatePolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(hidden_size=hidden_size)
        with torch.no_grad():
            for parameter in model.parameters():
                if parameter.ndim >= 2:
                    nn.init.normal_(parameter, mean=0.0, std=scale)
                else:
                    parameter.zero_()
        return model.to(device)

    @classmethod
    def from_checkpoint(
        cls, path: Path, device: torch.device
    ) -> "RecurrentMaskedStatePolicy":
        checkpoint = torch.load(path, map_location="cpu")
        model = cls(
            input_size=int(checkpoint.get("input_size", STATE_INPUT_SIZE)),
            hidden_size=int(checkpoint["hidden_size"]),
            action_space_size=int(checkpoint.get("action_space_size", ACTION_SPACE_SIZE)),
        )
        model.load_state_dict(checkpoint["state_dict"])
        return model.to(device)

    def save_checkpoint(
        self, path: Path, *, training_record: dict[str, Any] | None = None
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-masked-state-rnn-policy-v1",
                "architecture": "masked-state-rnn",
                "input_size": self.input_size,
                "hidden_size": self.hidden_size,
                "action_space_size": self.action_space_size,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


def _all_external_controllers() -> KCControllers:
    return KCControllers((0, 0, 0, 0))


def _legal_action_map(actions: list[KCAction]) -> tuple[list[int], dict[int, KCAction]]:
    legal_ids: list[int] = []
    by_id: dict[int, KCAction] = {}
    for action in actions:
        item = action_id(action)
        if item is None:
            continue
        if item not in by_id:
            legal_ids.append(item)
            by_id[item] = action
    return legal_ids, by_id


def _masked_logits(logits: torch.Tensor, legal_ids: list[int]) -> torch.Tensor:
    mask = torch.full_like(logits, -1.0e9)
    if legal_ids:
        mask[..., torch.tensor(legal_ids, dtype=torch.long, device=logits.device)] = 0.0
    return logits + mask


def _state_tensor(
    engine: CEngine, pointer: Any, player_id: int, device: torch.device
) -> torch.Tensor:
    features = engine.state_features(pointer, perspective_player=player_id)
    if not features:
        raise RuntimeError("C engine returned no masked-policy state features")
    return torch.tensor(features, dtype=torch.float32, device=device).unsqueeze(0)


def _choose_model_action(
    model: MaskedStatePolicy,
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    device: torch.device,
    sample: bool,
    temperature: float,
) -> tuple[KCAction, MaskedTransition | None]:
    actions = engine.legal_actions(pointer)
    legal_ids, by_id = _legal_action_map(actions)
    if not legal_ids:
        raise RuntimeError("masked policy was asked to move with no legal actions")
    state = _state_tensor(engine, pointer, player_id, device)
    logits, values = model(state)
    masked = _masked_logits(logits[0] / max(0.05, temperature), legal_ids)
    distribution = torch.distributions.Categorical(logits=masked)
    selected = distribution.sample() if sample else torch.argmax(masked)
    selected_id = int(selected.item())
    action = by_id[selected_id]
    transition = None
    if sample:
        transition = MaskedTransition(
            state=state.squeeze(0).detach().cpu().tolist(),
            legal_ids=legal_ids,
            action_id=selected_id,
            log_probability=float(distribution.log_prob(selected).detach().cpu().item()),
            value=float(values[0].detach().cpu().item()),
            player_id=player_id,
        )
    return action, transition


def _winner_id(scores: list[int]) -> int:
    best = max(scores)
    for index, score in enumerate(scores):
        if score == best:
            return index
    return 0


def _player_rewards(scores: list[int]) -> list[float]:
    rewards: list[float] = []
    for player_id, score in enumerate(scores):
        opponents = [scores[index] for index in range(4) if index != player_id]
        rewards.append((float(score) - (sum(opponents) / 3.0)) / 100.0)
    return rewards


def rollout_masked_episode(
    engine: CEngine,
    model: MaskedStatePolicy,
    *,
    seed: int,
    device: torch.device,
    temperature: float,
    round_curriculum: bool = False,
    curriculum_rounds: int = 2,
    round_plot_cards: int = 6,
    round_famine_rate: float = 0.2,
    max_actions: int = 512,
) -> MaskedEpisode:
    pointer = engine.new_engine(
        seed,
        controllers=_all_external_controllers(),
        round_curriculum=round_curriculum,
        curriculum_rounds=curriculum_rounds,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
    )
    transitions: list[MaskedTransition] = []
    try:
        for _ in range(max_actions):
            phase = engine.phase(pointer)
            if phase == KC_PHASE_GAME_OVER:
                scores = engine.final_scores(pointer)
                rewards = _player_rewards(scores)
                for transition in transitions:
                    transition.reward = rewards[transition.player_id]
                return MaskedEpisode(
                    transitions=transitions,
                    scores=scores,
                    rewards=rewards,
                    winner_id=_winner_id(scores),
                )
            actions = engine.legal_actions(pointer)
            if not actions:
                status = engine.step_automatic(pointer)
                if status < 0:
                    raise RuntimeError(f"automatic masked rollout step failed: {status}")
                continue
            player_id = int(actions[0].player_id)
            if phase == KC_PHASE_REQUISITION:
                engine.apply_action(pointer, actions[0])
                continue
            action, transition = _choose_model_action(
                model,
                engine,
                pointer,
                player_id=player_id,
                device=device,
                sample=True,
                temperature=temperature,
            )
            if transition is not None:
                transitions.append(transition)
            engine.apply_policy_action(pointer, action)
        raise RuntimeError("masked rollout exceeded action limit")
    finally:
        engine.free_engine(pointer)


def _batch_masked_logits(
    logits: torch.Tensor, legal_ids: list[list[int]]
) -> torch.Tensor:
    masked = torch.full_like(logits, -1.0e9)
    for row, ids in enumerate(legal_ids):
        if ids:
            masked[row, torch.tensor(ids, dtype=torch.long, device=logits.device)] = logits[
                row, torch.tensor(ids, dtype=torch.long, device=logits.device)
            ]
    return masked


def _eval_score(evaluation: dict[str, Any]) -> float:
    return float(evaluation.get("win_rate", 0.0)) + 0.001 * float(
        evaluation.get("average_margin", 0.0)
    )


def _best_eval_path(output_path: Path) -> Path:
    return output_path.with_name("best_eval.pt")


def _maybe_save_best_eval(
    model: nn.Module,
    output_path: Path,
    completed: int,
    evaluation: dict[str, Any] | None,
    best_eval: dict[str, Any] | None,
    best_eval_score: float | None,
    training_record: dict[str, Any],
) -> tuple[dict[str, Any] | None, float | None]:
    if evaluation is None:
        return best_eval, best_eval_score
    score = _eval_score(evaluation)
    if best_eval_score is not None and score <= best_eval_score:
        return best_eval, best_eval_score
    best_eval = {
        **evaluation,
        "completed_episodes": completed,
        "score": score,
    }
    best_eval_score = score
    best_path = _best_eval_path(output_path)
    model.save_checkpoint(
        best_path,
        training_record={
            **training_record,
            "best_evaluation": best_eval,
            "best_model": str(best_path),
        },
    )
    return best_eval, best_eval_score


def _ppo_update(
    model: MaskedStatePolicy,
    optimizer: torch.optim.Optimizer,
    transitions: list[MaskedTransition],
    *,
    device: torch.device,
    ppo_epochs: int,
    minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
) -> dict[str, float]:
    if not transitions:
        return {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    states = torch.tensor([item.state for item in transitions], dtype=torch.float32, device=device)
    actions = torch.tensor([item.action_id for item in transitions], dtype=torch.long, device=device)
    old_log_probs = torch.tensor(
        [item.log_probability for item in transitions], dtype=torch.float32, device=device
    )
    returns = torch.tensor(
        [item.reward for item in transitions], dtype=torch.float32, device=device
    )
    old_values = torch.tensor([item.value for item in transitions], dtype=torch.float32, device=device)
    advantages = returns - old_values
    if advantages.numel() > 1:
        advantages = (advantages - advantages.mean()) / advantages.std().clamp_min(1.0e-6)
    legal_ids = [item.legal_ids for item in transitions]
    indices = list(range(len(transitions)))
    metrics = {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    steps = 0
    for _ in range(ppo_epochs):
        random.shuffle(indices)
        for start in range(0, len(indices), minibatch_size):
            batch_indices = indices[start : start + minibatch_size]
            batch_states = states[batch_indices]
            batch_actions = actions[batch_indices]
            batch_old_log_probs = old_log_probs[batch_indices]
            batch_returns = returns[batch_indices]
            batch_advantages = advantages[batch_indices]
            batch_legal = [legal_ids[index] for index in batch_indices]
            logits, values = model(batch_states)
            masked = _batch_masked_logits(logits, batch_legal)
            distribution = torch.distributions.Categorical(logits=masked)
            log_probs = distribution.log_prob(batch_actions)
            ratio = torch.exp(log_probs - batch_old_log_probs)
            clipped = torch.clamp(ratio, 1.0 - ppo_clip, 1.0 + ppo_clip)
            policy_loss = -torch.minimum(
                ratio * batch_advantages, clipped * batch_advantages
            ).mean()
            value_loss = F.mse_loss(values, batch_returns)
            entropy = distribution.entropy().mean()
            loss = policy_loss + value_loss_weight * value_loss - entropy_weight * entropy
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            metrics["loss"] += float(loss.detach().cpu().item())
            metrics["policy_loss"] += float(policy_loss.detach().cpu().item())
            metrics["value_loss"] += float(value_loss.detach().cpu().item())
            metrics["entropy"] += float(entropy.detach().cpu().item())
            steps += 1
    if steps:
        for key in metrics:
            metrics[key] /= steps
    return metrics


def evaluate_masked_policy(
    engine: CEngine,
    model: MaskedStatePolicy,
    *,
    games_per_seat: int,
    seed: int,
    device: torch.device,
    round_curriculum: bool = False,
    curriculum_rounds: int = 5,
    round_plot_cards: int = 6,
    round_famine_rate: float = 0.2,
) -> dict[str, Any]:
    model.eval()
    wins = 0
    ties = 0
    total = 0
    margins: list[float] = []
    try:
        for model_seat in range(4):
            for offset in range(games_per_seat):
                pointer = engine.new_engine(
                    seed + model_seat * games_per_seat + offset,
                    controllers=_all_external_controllers(),
                    round_curriculum=round_curriculum,
                    curriculum_rounds=curriculum_rounds,
                    round_plot_cards=round_plot_cards,
                    round_famine_rate=round_famine_rate,
                )
                try:
                    for _ in range(512):
                        phase = engine.phase(pointer)
                        if phase == KC_PHASE_GAME_OVER:
                            break
                        actions = engine.legal_actions(pointer)
                        if not actions:
                            status = engine.step_automatic(pointer)
                            if status < 0:
                                raise RuntimeError(f"eval automatic step failed: {status}")
                            continue
                        player_id = int(actions[0].player_id)
                        if phase == KC_PHASE_REQUISITION:
                            engine.apply_action(pointer, actions[0])
                        elif player_id == model_seat:
                            action, _ = _choose_model_action(
                                model,
                                engine,
                                pointer,
                                player_id=player_id,
                                device=device,
                                sample=False,
                                temperature=1.0,
                            )
                            engine.apply_policy_action(pointer, action)
                        else:
                            engine.apply_policy_action(pointer, engine.heuristic_action(pointer))
                    scores = engine.final_scores(pointer)
                    best = max(scores)
                    if scores[model_seat] == best:
                        if scores.count(best) > 1:
                            ties += 1
                        else:
                            wins += 1
                    opponent_best = max(score for index, score in enumerate(scores) if index != model_seat)
                    margins.append(float(scores[model_seat] - opponent_best))
                    total += 1
                finally:
                    engine.free_engine(pointer)
    finally:
        model.train()
    return {
        "games": total,
        "games_per_seat": games_per_seat,
        "wins": wins,
        "ties": ties,
        "win_rate": wins / total if total else 0.0,
        "tie_rate": ties / total if total else 0.0,
        "average_margin": sum(margins) / len(margins) if margins else 0.0,
    }


def _choose_recurrent_model_action(
    model: RecurrentMaskedStatePolicy,
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    hidden: torch.Tensor,
    device: torch.device,
    sample: bool,
    temperature: float,
) -> tuple[KCAction, RecurrentMaskedTransition | None, torch.Tensor]:
    actions = engine.legal_actions(pointer)
    legal_ids, by_id = _legal_action_map(actions)
    if not legal_ids:
        raise RuntimeError("recurrent masked policy was asked to move with no legal actions")
    state = _state_tensor(engine, pointer, player_id, device)
    hidden_before = hidden.detach()
    logits, values, next_hidden = model.forward_step(state, hidden_before)
    masked = _masked_logits(logits[0] / max(0.05, temperature), legal_ids)
    distribution = torch.distributions.Categorical(logits=masked)
    selected = distribution.sample() if sample else torch.argmax(masked)
    selected_id = int(selected.item())
    action = by_id[selected_id]
    transition = None
    if sample:
        transition = RecurrentMaskedTransition(
            state=state.squeeze(0).detach().cpu().tolist(),
            hidden=hidden_before.squeeze(0).detach().cpu().tolist(),
            legal_ids=legal_ids,
            action_id=selected_id,
            log_probability=float(distribution.log_prob(selected).detach().cpu().item()),
            value=float(values[0].detach().cpu().item()),
            player_id=player_id,
        )
    return action, transition, next_hidden.detach()


def rollout_recurrent_masked_episode(
    engine: CEngine,
    model: RecurrentMaskedStatePolicy,
    *,
    seed: int,
    device: torch.device,
    temperature: float,
    max_actions: int = 512,
) -> RecurrentMaskedEpisode:
    pointer = engine.new_engine(seed, controllers=_all_external_controllers())
    hidden_states = model.initial_hidden(4, device)
    transitions: list[RecurrentMaskedTransition] = []
    try:
        for _ in range(max_actions):
            phase = engine.phase(pointer)
            if phase == KC_PHASE_GAME_OVER:
                scores = engine.final_scores(pointer)
                rewards = _player_rewards(scores)
                for transition in transitions:
                    transition.reward = rewards[transition.player_id]
                return RecurrentMaskedEpisode(
                    transitions=transitions,
                    scores=scores,
                    rewards=rewards,
                    winner_id=_winner_id(scores),
                )
            actions = engine.legal_actions(pointer)
            if not actions:
                status = engine.step_automatic(pointer)
                if status < 0:
                    raise RuntimeError(f"automatic recurrent rollout step failed: {status}")
                continue
            player_id = int(actions[0].player_id)
            if phase == KC_PHASE_REQUISITION:
                engine.apply_action(pointer, actions[0])
                continue
            action, transition, next_hidden = _choose_recurrent_model_action(
                model,
                engine,
                pointer,
                player_id=player_id,
                hidden=hidden_states[player_id : player_id + 1],
                device=device,
                sample=True,
                temperature=temperature,
            )
            hidden_states[player_id : player_id + 1] = next_hidden
            if transition is not None:
                transitions.append(transition)
            engine.apply_policy_action(pointer, action)
        raise RuntimeError("recurrent masked rollout exceeded action limit")
    finally:
        engine.free_engine(pointer)


def _recurrent_ppo_update(
    model: RecurrentMaskedStatePolicy,
    optimizer: torch.optim.Optimizer,
    transitions: list[RecurrentMaskedTransition],
    *,
    device: torch.device,
    ppo_epochs: int,
    minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
) -> dict[str, float]:
    if not transitions:
        return {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    states = torch.tensor([item.state for item in transitions], dtype=torch.float32, device=device)
    hiddens = torch.tensor([item.hidden for item in transitions], dtype=torch.float32, device=device)
    actions = torch.tensor([item.action_id for item in transitions], dtype=torch.long, device=device)
    old_log_probs = torch.tensor(
        [item.log_probability for item in transitions], dtype=torch.float32, device=device
    )
    returns = torch.tensor(
        [item.reward for item in transitions], dtype=torch.float32, device=device
    )
    old_values = torch.tensor([item.value for item in transitions], dtype=torch.float32, device=device)
    advantages = returns - old_values
    if advantages.numel() > 1:
        advantages = (advantages - advantages.mean()) / advantages.std().clamp_min(1.0e-6)
    legal_ids = [item.legal_ids for item in transitions]
    indices = list(range(len(transitions)))
    metrics = {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    steps = 0
    for _ in range(ppo_epochs):
        random.shuffle(indices)
        for start in range(0, len(indices), minibatch_size):
            batch_indices = indices[start : start + minibatch_size]
            batch_states = states[batch_indices]
            batch_hiddens = hiddens[batch_indices]
            batch_actions = actions[batch_indices]
            batch_old_log_probs = old_log_probs[batch_indices]
            batch_returns = returns[batch_indices]
            batch_advantages = advantages[batch_indices]
            batch_legal = [legal_ids[index] for index in batch_indices]
            logits, values, _ = model.forward_step(batch_states, batch_hiddens)
            masked = _batch_masked_logits(logits, batch_legal)
            distribution = torch.distributions.Categorical(logits=masked)
            log_probs = distribution.log_prob(batch_actions)
            ratio = torch.exp(log_probs - batch_old_log_probs)
            clipped = torch.clamp(ratio, 1.0 - ppo_clip, 1.0 + ppo_clip)
            policy_loss = -torch.minimum(
                ratio * batch_advantages, clipped * batch_advantages
            ).mean()
            value_loss = F.mse_loss(values, batch_returns)
            entropy = distribution.entropy().mean()
            loss = policy_loss + value_loss_weight * value_loss - entropy_weight * entropy
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            metrics["loss"] += float(loss.detach().cpu().item())
            metrics["policy_loss"] += float(policy_loss.detach().cpu().item())
            metrics["value_loss"] += float(value_loss.detach().cpu().item())
            metrics["entropy"] += float(entropy.detach().cpu().item())
            steps += 1
    if steps:
        for key in metrics:
            metrics[key] /= steps
    return metrics


def evaluate_recurrent_masked_policy(
    engine: CEngine,
    model: RecurrentMaskedStatePolicy,
    *,
    games_per_seat: int,
    seed: int,
    device: torch.device,
) -> dict[str, Any]:
    model.eval()
    wins = 0
    ties = 0
    total = 0
    margins: list[float] = []
    try:
        for model_seat in range(4):
            for offset in range(games_per_seat):
                pointer = engine.new_engine(
                    seed + model_seat * games_per_seat + offset,
                    controllers=_all_external_controllers(),
                )
                hidden_states = model.initial_hidden(4, device)
                try:
                    for _ in range(512):
                        phase = engine.phase(pointer)
                        if phase == KC_PHASE_GAME_OVER:
                            break
                        actions = engine.legal_actions(pointer)
                        if not actions:
                            status = engine.step_automatic(pointer)
                            if status < 0:
                                raise RuntimeError(f"recurrent eval automatic step failed: {status}")
                            continue
                        player_id = int(actions[0].player_id)
                        if phase == KC_PHASE_REQUISITION:
                            engine.apply_action(pointer, actions[0])
                        elif player_id == model_seat:
                            action, _, next_hidden = _choose_recurrent_model_action(
                                model,
                                engine,
                                pointer,
                                player_id=player_id,
                                hidden=hidden_states[player_id : player_id + 1],
                                device=device,
                                sample=False,
                                temperature=1.0,
                            )
                            hidden_states[player_id : player_id + 1] = next_hidden
                            engine.apply_policy_action(pointer, action)
                        else:
                            engine.apply_policy_action(pointer, engine.heuristic_action(pointer))
                    scores = engine.final_scores(pointer)
                    best = max(scores)
                    if scores[model_seat] == best:
                        if scores.count(best) > 1:
                            ties += 1
                        else:
                            wins += 1
                    opponent_best = max(score for index, score in enumerate(scores) if index != model_seat)
                    margins.append(float(scores[model_seat] - opponent_best))
                    total += 1
                finally:
                    engine.free_engine(pointer)
    finally:
        model.train()
    return {
        "games": total,
        "games_per_seat": games_per_seat,
        "wins": wins,
        "ties": ties,
        "win_rate": wins / total if total else 0.0,
        "tie_rate": ties / total if total else 0.0,
        "average_margin": sum(margins) / len(margins) if margins else 0.0,
    }


def train_recurrent_masked_state_policy(
    engine: CEngine,
    *,
    output_path: Path,
    start_model_path: Path | None,
    hidden_size: int,
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
    eval_interval: int = 0,
    eval_games_per_seat: int = 4,
    eval_seed: int = 91_000_000,
    record_history: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    if start_model_path is None:
        model = RecurrentMaskedStatePolicy.scratch(
            hidden_size=hidden_size,
            seed=scratch_seed,
            scale=scratch_scale,
            device=device,
        )
    else:
        model = RecurrentMaskedStatePolicy.from_checkpoint(start_model_path, device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    all_points: list[dict[str, Any]] = []
    completed = 0
    last_metrics: dict[str, float] = {}
    last_eval: dict[str, Any] | None = None
    best_eval: dict[str, Any] | None = None
    best_eval_score: float | None = None
    while completed < episodes:
        current_batch = min(batch_size, episodes - completed)
        batch_episodes = [
            rollout_recurrent_masked_episode(
                engine,
                model,
                seed=seed + completed + index,
                device=device,
                temperature=temperature,
            )
            for index in range(current_batch)
        ]
        transitions = [
            transition
            for episode in batch_episodes
            for transition in episode.transitions
        ]
        reward_by_player = [0.0, 0.0, 0.0, 0.0]
        reward_counts = [0, 0, 0, 0]
        for episode in batch_episodes:
            for player_id, reward in enumerate(episode.rewards):
                reward_by_player[player_id] += reward
                reward_counts[player_id] += 1
        mean_rewards = [
            reward_by_player[index] / max(1, reward_counts[index]) for index in range(4)
        ]
        last_metrics = _recurrent_ppo_update(
            model,
            optimizer,
            transitions,
            device=device,
            ppo_epochs=ppo_epochs,
            minibatch_size=ppo_minibatch_size,
            ppo_clip=ppo_clip,
            value_loss_weight=value_loss_weight,
            entropy_weight=entropy_weight,
        )
        completed += current_batch
        point = {
            "completed_episodes": completed,
            "average_reward": sum(mean_rewards) / len(mean_rewards),
            "actions": len(transitions),
            **last_metrics,
        }
        all_points.append(point)
        if eval_interval > 0 and completed % eval_interval == 0:
            last_eval = evaluate_recurrent_masked_policy(
                engine,
                model,
                games_per_seat=eval_games_per_seat,
                seed=eval_seed + completed,
                device=device,
            )
            point["eval"] = last_eval
            best_eval, best_eval_score = _maybe_save_best_eval(
                model,
                output_path,
                completed,
                last_eval,
                best_eval,
                best_eval_score,
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "architecture": "masked-state-rnn",
                    "hidden_size": hidden_size,
                    "action_space_size": ACTION_SPACE_SIZE,
                    "episodes": episodes,
                    "batch_size": batch_size,
                    "seed": seed,
                    "learning_rate": learning_rate,
                    "points": all_points,
                    "curve": {"points": all_points},
                    "latest_evaluation": last_eval,
                },
            )
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "status": "running",
                    "phase": "training",
                    "output_model": str(output_path),
                    "start_model": str(start_model_path) if start_model_path else "scratch",
                    "model": {
                        "architecture": "masked-state-rnn",
                        "hidden_size": hidden_size,
                        "action_space_size": ACTION_SPACE_SIZE,
                    },
                    "training": {
                        "episodes": episodes,
                        "batch_size": batch_size,
                        "seed": seed,
                        "learning_rate": learning_rate,
                        "ppo_epochs": ppo_epochs,
                        "ppo_minibatch_size": ppo_minibatch_size,
                        "eval_interval": eval_interval,
                        "eval_games_per_seat": eval_games_per_seat,
                    },
                    "curve": {
                        "points": all_points,
                    },
                    "latest_point": point,
                    "latest_evaluation": last_eval,
                    "best_evaluation": best_eval,
                    "best_model": str(_best_eval_path(output_path)) if best_eval else None,
                    "progress": {
                        "completed_episodes": completed,
                        "total_episodes": episodes,
                        "percent": completed / max(1, episodes),
                    },
                }
            )
    training_record = {
        "kind": "masked_state_policy_training",
        "backend": "torch",
        "architecture": "masked-state-rnn",
        "hidden_size": hidden_size,
        "action_space_size": ACTION_SPACE_SIZE,
        "episodes": episodes,
        "batch_size": batch_size,
        "seed": seed,
        "learning_rate": learning_rate,
        "points": all_points,
        "curve": {
            "points": all_points,
        },
        "latest_evaluation": last_eval,
        "best_evaluation": best_eval,
        "best_model": str(_best_eval_path(output_path)) if best_eval else None,
    }
    model.save_checkpoint(output_path, training_record=training_record)
    record = {
        **training_record,
        "status": "completed",
        "output_model": str(output_path),
        "device": str(device),
        "final_metrics": last_metrics,
    }
    if record_history:
        append_history(record)
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "completed",
                "progress": {
                    "completed_episodes": episodes,
                    "total_episodes": episodes,
                    "percent": 1.0,
                },
            }
        )
    return record


def _append_transformer_context(
    context: torch.Tensor, state: torch.Tensor
) -> torch.Tensor:
    return torch.cat([context[1:], state.squeeze(0).unsqueeze(0)], dim=0)


def _choose_transformer_model_action(
    model: TransformerMaskedStatePolicy,
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    context: torch.Tensor,
    device: torch.device,
    sample: bool,
    temperature: float,
) -> tuple[KCAction, TransformerMaskedTransition | None, torch.Tensor]:
    actions = engine.legal_actions(pointer)
    legal_ids, by_id = _legal_action_map(actions)
    if not legal_ids:
        raise RuntimeError("transformer masked policy was asked to move with no legal actions")
    state = _state_tensor(engine, pointer, player_id, device)
    next_context = _append_transformer_context(context.detach(), state)
    logits, values = model.forward_context(next_context.unsqueeze(0))
    masked = _masked_logits(logits[0] / max(0.05, temperature), legal_ids)
    distribution = torch.distributions.Categorical(logits=masked)
    selected = distribution.sample() if sample else torch.argmax(masked)
    selected_id = int(selected.item())
    action = by_id[selected_id]
    transition = None
    if sample:
        transition = TransformerMaskedTransition(
            context=next_context.detach().cpu().tolist(),
            legal_ids=legal_ids,
            action_id=selected_id,
            log_probability=float(distribution.log_prob(selected).detach().cpu().item()),
            value=float(values[0].detach().cpu().item()),
            player_id=player_id,
        )
    return action, transition, next_context.detach()


def rollout_transformer_masked_episode(
    engine: CEngine,
    model: TransformerMaskedStatePolicy,
    *,
    seed: int,
    device: torch.device,
    temperature: float,
    max_actions: int = 512,
) -> TransformerMaskedEpisode:
    pointer = engine.new_engine(seed, controllers=_all_external_controllers())
    contexts = model.initial_context(4, device)
    transitions: list[TransformerMaskedTransition] = []
    try:
        for _ in range(max_actions):
            phase = engine.phase(pointer)
            if phase == KC_PHASE_GAME_OVER:
                scores = engine.final_scores(pointer)
                rewards = _player_rewards(scores)
                for transition in transitions:
                    transition.reward = rewards[transition.player_id]
                return TransformerMaskedEpisode(
                    transitions=transitions,
                    scores=scores,
                    rewards=rewards,
                    winner_id=_winner_id(scores),
                )
            actions = engine.legal_actions(pointer)
            if not actions:
                status = engine.step_automatic(pointer)
                if status < 0:
                    raise RuntimeError(f"automatic transformer rollout step failed: {status}")
                continue
            player_id = int(actions[0].player_id)
            if phase == KC_PHASE_REQUISITION:
                engine.apply_action(pointer, actions[0])
                continue
            action, transition, next_context = _choose_transformer_model_action(
                model,
                engine,
                pointer,
                player_id=player_id,
                context=contexts[player_id],
                device=device,
                sample=True,
                temperature=temperature,
            )
            contexts[player_id] = next_context
            if transition is not None:
                transitions.append(transition)
            engine.apply_policy_action(pointer, action)
        raise RuntimeError("transformer masked rollout exceeded action limit")
    finally:
        engine.free_engine(pointer)


def _transformer_ppo_update(
    model: TransformerMaskedStatePolicy,
    optimizer: torch.optim.Optimizer,
    transitions: list[TransformerMaskedTransition],
    *,
    device: torch.device,
    ppo_epochs: int,
    minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
) -> dict[str, float]:
    if not transitions:
        return {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    contexts = torch.tensor([item.context for item in transitions], dtype=torch.float32, device=device)
    actions = torch.tensor([item.action_id for item in transitions], dtype=torch.long, device=device)
    old_log_probs = torch.tensor(
        [item.log_probability for item in transitions], dtype=torch.float32, device=device
    )
    returns = torch.tensor(
        [item.reward for item in transitions], dtype=torch.float32, device=device
    )
    old_values = torch.tensor([item.value for item in transitions], dtype=torch.float32, device=device)
    advantages = returns - old_values
    if advantages.numel() > 1:
        advantages = (advantages - advantages.mean()) / advantages.std().clamp_min(1.0e-6)
    legal_ids = [item.legal_ids for item in transitions]
    indices = list(range(len(transitions)))
    metrics = {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    steps = 0
    for _ in range(ppo_epochs):
        random.shuffle(indices)
        for start in range(0, len(indices), minibatch_size):
            batch_indices = indices[start : start + minibatch_size]
            batch_contexts = contexts[batch_indices]
            batch_actions = actions[batch_indices]
            batch_old_log_probs = old_log_probs[batch_indices]
            batch_returns = returns[batch_indices]
            batch_advantages = advantages[batch_indices]
            batch_legal = [legal_ids[index] for index in batch_indices]
            logits, values = model.forward_context(batch_contexts)
            masked = _batch_masked_logits(logits, batch_legal)
            distribution = torch.distributions.Categorical(logits=masked)
            log_probs = distribution.log_prob(batch_actions)
            ratio = torch.exp(log_probs - batch_old_log_probs)
            clipped = torch.clamp(ratio, 1.0 - ppo_clip, 1.0 + ppo_clip)
            policy_loss = -torch.minimum(
                ratio * batch_advantages, clipped * batch_advantages
            ).mean()
            value_loss = F.mse_loss(values, batch_returns)
            entropy = distribution.entropy().mean()
            loss = policy_loss + value_loss_weight * value_loss - entropy_weight * entropy
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            metrics["loss"] += float(loss.detach().cpu().item())
            metrics["policy_loss"] += float(policy_loss.detach().cpu().item())
            metrics["value_loss"] += float(value_loss.detach().cpu().item())
            metrics["entropy"] += float(entropy.detach().cpu().item())
            steps += 1
    if steps:
        for key in metrics:
            metrics[key] /= steps
    return metrics


def evaluate_transformer_masked_policy(
    engine: CEngine,
    model: TransformerMaskedStatePolicy,
    *,
    games_per_seat: int,
    seed: int,
    device: torch.device,
) -> dict[str, Any]:
    model.eval()
    wins = 0
    ties = 0
    total = 0
    margins: list[float] = []
    try:
        for model_seat in range(4):
            for offset in range(games_per_seat):
                pointer = engine.new_engine(
                    seed + model_seat * games_per_seat + offset,
                    controllers=_all_external_controllers(),
                )
                contexts = model.initial_context(4, device)
                try:
                    for _ in range(512):
                        phase = engine.phase(pointer)
                        if phase == KC_PHASE_GAME_OVER:
                            break
                        actions = engine.legal_actions(pointer)
                        if not actions:
                            status = engine.step_automatic(pointer)
                            if status < 0:
                                raise RuntimeError(f"transformer eval automatic step failed: {status}")
                            continue
                        player_id = int(actions[0].player_id)
                        if phase == KC_PHASE_REQUISITION:
                            engine.apply_action(pointer, actions[0])
                        elif player_id == model_seat:
                            action, _, next_context = _choose_transformer_model_action(
                                model,
                                engine,
                                pointer,
                                player_id=player_id,
                                context=contexts[player_id],
                                device=device,
                                sample=False,
                                temperature=1.0,
                            )
                            contexts[player_id] = next_context
                            engine.apply_policy_action(pointer, action)
                        else:
                            engine.apply_policy_action(pointer, engine.heuristic_action(pointer))
                    scores = engine.final_scores(pointer)
                    best = max(scores)
                    if scores[model_seat] == best:
                        if scores.count(best) > 1:
                            ties += 1
                        else:
                            wins += 1
                    opponent_best = max(score for index, score in enumerate(scores) if index != model_seat)
                    margins.append(float(scores[model_seat] - opponent_best))
                    total += 1
                finally:
                    engine.free_engine(pointer)
    finally:
        model.train()
    return {
        "games": total,
        "games_per_seat": games_per_seat,
        "wins": wins,
        "ties": ties,
        "win_rate": wins / total if total else 0.0,
        "tie_rate": ties / total if total else 0.0,
        "average_margin": sum(margins) / len(margins) if margins else 0.0,
    }


def train_transformer_masked_state_policy(
    engine: CEngine,
    *,
    output_path: Path,
    start_model_path: Path | None,
    hidden_size: int,
    layer_count: int,
    head_count: int,
    context_length: int,
    dropout: float,
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
    eval_interval: int = 0,
    eval_games_per_seat: int = 4,
    eval_seed: int = 91_000_000,
    record_history: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    if start_model_path is None:
        model = TransformerMaskedStatePolicy.scratch(
            hidden_size=hidden_size,
            layer_count=layer_count,
            head_count=head_count,
            context_length=context_length,
            dropout=dropout,
            seed=scratch_seed,
            scale=scratch_scale,
            device=device,
        )
    else:
        model = TransformerMaskedStatePolicy.from_checkpoint(start_model_path, device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    all_points: list[dict[str, Any]] = []
    completed = 0
    last_metrics: dict[str, float] = {}
    last_eval: dict[str, Any] | None = None
    best_eval: dict[str, Any] | None = None
    best_eval_score: float | None = None
    while completed < episodes:
        current_batch = min(batch_size, episodes - completed)
        batch_episodes = [
            rollout_transformer_masked_episode(
                engine,
                model,
                seed=seed + completed + index,
                device=device,
                temperature=temperature,
            )
            for index in range(current_batch)
        ]
        transitions = [
            transition
            for episode in batch_episodes
            for transition in episode.transitions
        ]
        reward_by_player = [0.0, 0.0, 0.0, 0.0]
        reward_counts = [0, 0, 0, 0]
        for episode in batch_episodes:
            for player_id, reward in enumerate(episode.rewards):
                reward_by_player[player_id] += reward
                reward_counts[player_id] += 1
        mean_rewards = [
            reward_by_player[index] / max(1, reward_counts[index]) for index in range(4)
        ]
        last_metrics = _transformer_ppo_update(
            model,
            optimizer,
            transitions,
            device=device,
            ppo_epochs=ppo_epochs,
            minibatch_size=ppo_minibatch_size,
            ppo_clip=ppo_clip,
            value_loss_weight=value_loss_weight,
            entropy_weight=entropy_weight,
        )
        completed += current_batch
        point = {
            "completed_episodes": completed,
            "average_reward": sum(mean_rewards) / len(mean_rewards),
            "actions": len(transitions),
            **last_metrics,
        }
        all_points.append(point)
        if eval_interval > 0 and completed % eval_interval == 0:
            last_eval = evaluate_transformer_masked_policy(
                engine,
                model,
                games_per_seat=eval_games_per_seat,
                seed=eval_seed + completed,
                device=device,
            )
            point["eval"] = last_eval
            best_eval, best_eval_score = _maybe_save_best_eval(
                model,
                output_path,
                completed,
                last_eval,
                best_eval,
                best_eval_score,
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "architecture": "masked-state-transformer",
                    "hidden_size": hidden_size,
                    "layer_count": layer_count,
                    "head_count": head_count,
                    "context_length": context_length,
                    "action_space_size": ACTION_SPACE_SIZE,
                    "episodes": episodes,
                    "batch_size": batch_size,
                    "seed": seed,
                    "learning_rate": learning_rate,
                    "points": all_points,
                    "curve": {"points": all_points},
                    "latest_evaluation": last_eval,
                },
            )
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "status": "running",
                    "phase": "training",
                    "output_model": str(output_path),
                    "start_model": str(start_model_path) if start_model_path else "scratch",
                    "model": {
                        "architecture": "masked-state-transformer",
                        "hidden_size": hidden_size,
                        "layer_count": layer_count,
                        "head_count": head_count,
                        "context_length": context_length,
                        "action_space_size": ACTION_SPACE_SIZE,
                    },
                    "training": {
                        "episodes": episodes,
                        "batch_size": batch_size,
                        "seed": seed,
                        "learning_rate": learning_rate,
                        "ppo_epochs": ppo_epochs,
                        "ppo_minibatch_size": ppo_minibatch_size,
                        "eval_interval": eval_interval,
                        "eval_games_per_seat": eval_games_per_seat,
                    },
                    "curve": {
                        "points": all_points,
                    },
                    "latest_point": point,
                    "latest_evaluation": last_eval,
                    "best_evaluation": best_eval,
                    "best_model": str(_best_eval_path(output_path)) if best_eval else None,
                    "progress": {
                        "completed_episodes": completed,
                        "total_episodes": episodes,
                        "percent": completed / max(1, episodes),
                    },
                }
            )
    training_record = {
        "kind": "masked_state_policy_training",
        "backend": "torch",
        "architecture": "masked-state-transformer",
        "hidden_size": hidden_size,
        "layer_count": layer_count,
        "head_count": head_count,
        "context_length": context_length,
        "action_space_size": ACTION_SPACE_SIZE,
        "episodes": episodes,
        "batch_size": batch_size,
        "seed": seed,
        "learning_rate": learning_rate,
        "points": all_points,
        "curve": {
            "points": all_points,
        },
        "latest_evaluation": last_eval,
        "best_evaluation": best_eval,
        "best_model": str(_best_eval_path(output_path)) if best_eval else None,
    }
    model.save_checkpoint(output_path, training_record=training_record)
    record = {
        **training_record,
        "status": "completed",
        "output_model": str(output_path),
        "device": str(device),
        "final_metrics": last_metrics,
    }
    if record_history:
        append_history(record)
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "completed",
                "progress": {
                    "completed_episodes": episodes,
                    "total_episodes": episodes,
                    "percent": 1.0,
                },
            }
        )
    return record


def train_masked_state_policy(
    engine: CEngine,
    *,
    output_path: Path,
    start_model_path: Path | None,
    layer_sizes: list[int],
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
    eval_interval: int = 0,
    eval_games_per_seat: int = 4,
    eval_seed: int = 91_000_000,
    round_curriculum: bool = False,
    curriculum_rounds: int = 2,
    round_plot_cards: int = 6,
    round_famine_rate: float = 0.2,
    record_history: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    if start_model_path is None:
        model = MaskedStatePolicy.scratch(
            layer_sizes=layer_sizes,
            seed=scratch_seed,
            scale=scratch_scale,
            device=device,
        )
    else:
        model = MaskedStatePolicy.from_checkpoint(start_model_path, device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    all_points: list[dict[str, Any]] = []
    completed = 0
    last_metrics: dict[str, float] = {}
    last_eval: dict[str, Any] | None = None
    best_eval: dict[str, Any] | None = None
    best_eval_score: float | None = None
    while completed < episodes:
        current_batch = min(batch_size, episodes - completed)
        batch_episodes = [
            rollout_masked_episode(
                engine,
                model,
                seed=seed + completed + index,
                device=device,
                temperature=temperature,
                round_curriculum=round_curriculum,
                curriculum_rounds=curriculum_rounds,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
            for index in range(current_batch)
        ]
        transitions = [
            transition
            for episode in batch_episodes
            for transition in episode.transitions
        ]
        reward_by_player = [0.0, 0.0, 0.0, 0.0]
        reward_counts = [0, 0, 0, 0]
        for episode in batch_episodes:
            for player_id, reward in enumerate(episode.rewards):
                reward_by_player[player_id] += reward
                reward_counts[player_id] += 1
        mean_rewards = [
            reward_by_player[index] / max(1, reward_counts[index]) for index in range(4)
        ]
        last_metrics = _ppo_update(
            model,
            optimizer,
            transitions,
            device=device,
            ppo_epochs=ppo_epochs,
            minibatch_size=ppo_minibatch_size,
            ppo_clip=ppo_clip,
            value_loss_weight=value_loss_weight,
            entropy_weight=entropy_weight,
        )
        completed += current_batch
        point = {
            "completed_episodes": completed,
            "average_reward": sum(mean_rewards) / len(mean_rewards),
            "actions": len(transitions),
            **last_metrics,
        }
        all_points.append(point)
        if eval_interval > 0 and completed % eval_interval == 0:
            last_eval = evaluate_masked_policy(
                engine,
                model,
                games_per_seat=eval_games_per_seat,
                seed=eval_seed + completed,
                device=device,
                round_curriculum=round_curriculum,
                curriculum_rounds=curriculum_rounds,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
            point["eval"] = last_eval
            best_eval, best_eval_score = _maybe_save_best_eval(
                model,
                output_path,
                completed,
                last_eval,
                best_eval,
                best_eval_score,
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "architecture": "masked-state-mlp",
                    "layers": layer_sizes,
                    "action_space_size": ACTION_SPACE_SIZE,
                    "episodes": episodes,
                    "batch_size": batch_size,
                    "seed": seed,
                    "learning_rate": learning_rate,
                    "points": all_points,
                    "curve": {"points": all_points},
                    "latest_evaluation": last_eval,
                },
            )
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "status": "running",
                    "phase": "training",
                    "output_model": str(output_path),
                    "start_model": str(start_model_path) if start_model_path else "scratch",
                    "model": {
                        "architecture": "masked-state-mlp",
                        "layers": layer_sizes,
                        "action_space_size": ACTION_SPACE_SIZE,
                    },
                    "training": {
                        "episodes": episodes,
                        "batch_size": batch_size,
                        "seed": seed,
                        "learning_rate": learning_rate,
                        "ppo_epochs": ppo_epochs,
                        "ppo_minibatch_size": ppo_minibatch_size,
                        "eval_interval": eval_interval,
                        "eval_games_per_seat": eval_games_per_seat,
                    },
                    "curve": {
                        "points": all_points,
                    },
                    "latest_point": point,
                    "latest_evaluation": last_eval,
                    "best_evaluation": best_eval,
                    "best_model": str(_best_eval_path(output_path)) if best_eval else None,
                    "progress": {
                        "completed_episodes": completed,
                        "total_episodes": episodes,
                        "percent": completed / max(1, episodes),
                    },
                }
            )
    training_record = {
        "kind": "masked_state_policy_training",
        "backend": "torch",
        "architecture": "masked-state-mlp",
        "layers": layer_sizes,
        "action_space_size": ACTION_SPACE_SIZE,
        "episodes": episodes,
        "batch_size": batch_size,
        "seed": seed,
        "learning_rate": learning_rate,
        "points": all_points,
        "curve": {
            "points": all_points,
        },
        "latest_evaluation": last_eval,
        "best_evaluation": best_eval,
        "best_model": str(_best_eval_path(output_path)) if best_eval else None,
    }
    model.save_checkpoint(output_path, training_record=training_record)
    record = {
        **training_record,
        "status": "completed",
        "output_model": str(output_path),
        "device": str(device),
        "final_metrics": last_metrics,
    }
    if record_history:
        append_history(record)
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "completed",
                "progress": {
                    "completed_episodes": episodes,
                    "total_episodes": episodes,
                    "percent": 1.0,
                },
            }
        )
    return record


ROUTED_HEAD_TRUMP = 0
ROUTED_HEAD_SWAP = 1
ROUTED_HEAD_PLAY = 2
ROUTED_HEAD_ASSIGN = 3
ROUTED_HEAD_SPECIAL = 4
ROUTED_HEAD_COUNT = 5
ROUTED_ACTION_FEATURE_SIZE = 48


@dataclass
class RoutedTransformerMaskedTransition:
    context: list[list[float]]
    action_features: list[list[float]]
    action_head_ids: list[int]
    selected_index: int
    log_probability: float
    value: float
    player_id: int
    reward: float = 0.0


@dataclass
class RoutedTransformerMaskedEpisode:
    transitions: list[RoutedTransformerMaskedTransition]
    scores: list[int]
    rewards: list[float]
    winner_id: int


def _one_hot(index: int, size: int) -> list[float]:
    values = [0.0] * size
    if 0 <= index < size:
        values[index] = 1.0
    return values


def _card_features(card: KCCard) -> list[float]:
    suit = int(card.suit)
    value = int(card.value)
    valid = 1.0 if 0 <= suit < CARD_SUIT_COUNT and 0 <= value < CARD_VALUE_COUNT else 0.0
    return [
        valid,
        *_one_hot(suit, CARD_SUIT_COUNT),
        float(value) / 14.0 if valid else 0.0,
        1.0 if suit == 4 and value == 14 else 0.0,
    ]


def _routed_action_head_id(action: KCAction) -> int | None:
    kind = int(action.kind)
    if kind == KC_ACTION_SET_TRUMP:
        return ROUTED_HEAD_TRUMP
    if kind == KC_ACTION_SWAP:
        return ROUTED_HEAD_SWAP
    if kind == KC_ACTION_PLAY_CARD:
        return ROUTED_HEAD_PLAY
    if kind == KC_ACTION_ASSIGN:
        return ROUTED_HEAD_ASSIGN
    if kind in SPECIAL_ACTION_IDS:
        return ROUTED_HEAD_SPECIAL
    return None


def _routed_action_features(action: KCAction) -> list[float] | None:
    head_id = _routed_action_head_id(action)
    if head_id is None:
        return None
    kind = int(action.kind)
    features = [
        *_one_hot(head_id, ROUTED_HEAD_COUNT),
        *_one_hot(kind - 1, 8),
        *_one_hot(int(action.suit), 4),
        *_card_features(action.card),
        *_card_features(action.hand_card),
        *_card_features(action.plot_card),
        *_one_hot(int(action.plot_zone), 2),
        *_one_hot(int(action.target_suit), 4),
        float(max(0, min(3, int(action.player_id)))) / 3.0,
    ]
    if len(features) != ROUTED_ACTION_FEATURE_SIZE:
        raise RuntimeError(
            f"routed action feature size mismatch: {len(features)} != {ROUTED_ACTION_FEATURE_SIZE}"
        )
    return features


def _routed_legal_actions(
    actions: list[KCAction],
) -> tuple[list[KCAction], list[list[float]], list[int]]:
    routed_actions: list[KCAction] = []
    action_features: list[list[float]] = []
    action_head_ids: list[int] = []
    for action in actions:
        head_id = _routed_action_head_id(action)
        features = _routed_action_features(action)
        if head_id is None or features is None:
            continue
        routed_actions.append(action)
        action_features.append(features)
        action_head_ids.append(head_id)
    return routed_actions, action_features, action_head_ids


class RoutedTransformerMaskedStatePolicy(nn.Module):
    def __init__(
        self,
        *,
        input_size: int = STATE_INPUT_SIZE,
        hidden_size: int = 128,
        layer_count: int = 2,
        head_count: int = 4,
        context_length: int = 8,
        dropout: float = 0.0,
        action_feature_size: int = ROUTED_ACTION_FEATURE_SIZE,
    ) -> None:
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.layer_count = layer_count
        self.head_count = head_count
        self.context_length = context_length
        self.action_feature_size = action_feature_size
        self.input = nn.Linear(input_size, hidden_size)
        self.position = nn.Parameter(torch.zeros(context_length, hidden_size))
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=hidden_size,
            nhead=head_count,
            dim_feedforward=hidden_size * 4,
            dropout=dropout,
            activation="gelu",
            batch_first=True,
            norm_first=False,
        )
        self.encoder = nn.TransformerEncoder(encoder_layer, num_layers=layer_count)
        self.norm = nn.LayerNorm(hidden_size)
        self.action_input = nn.Linear(action_feature_size, hidden_size)
        self.policy_heads = nn.ModuleList(
            [
                nn.Sequential(
                    nn.Linear(hidden_size * 2, hidden_size),
                    nn.GELU(),
                    nn.Linear(hidden_size, 1),
                )
                for _ in range(ROUTED_HEAD_COUNT)
            ]
        )
        self.value_head = nn.Linear(hidden_size, 1)

    def initial_context(self, batch_size: int, device: torch.device) -> torch.Tensor:
        return torch.zeros(
            (batch_size, self.context_length, self.input_size),
            dtype=torch.float32,
            device=device,
        )

    def encode_context(self, contexts: torch.Tensor) -> torch.Tensor:
        hidden = self.input(contexts) + self.position.unsqueeze(0)
        encoded = self.encoder(hidden)
        return self.norm(encoded[:, -1, :])

    def score_actions(
        self,
        contexts: torch.Tensor,
        action_features: torch.Tensor,
        action_head_ids: torch.Tensor,
        action_mask: torch.Tensor,
    ) -> tuple[torch.Tensor, torch.Tensor]:
        state = self.encode_context(contexts)
        action_hidden = F.gelu(self.action_input(action_features))
        state_expanded = state.unsqueeze(1).expand(-1, action_hidden.shape[1], -1)
        combined = torch.cat([state_expanded, action_hidden], dim=2)
        scores = torch.full(
            action_head_ids.shape,
            -1.0e9,
            dtype=torch.float32,
            device=contexts.device,
        )
        for head_id, head in enumerate(self.policy_heads):
            head_mask = action_mask & (action_head_ids == head_id)
            if head_mask.any():
                scores[head_mask] = head(combined[head_mask]).squeeze(1)
        values = self.value_head(state).squeeze(1)
        return scores, values

    @classmethod
    def scratch(
        cls,
        *,
        hidden_size: int,
        layer_count: int,
        head_count: int,
        context_length: int,
        dropout: float,
        seed: int,
        scale: float,
        device: torch.device,
    ) -> "RoutedTransformerMaskedStatePolicy":
        torch.manual_seed(seed)
        random.seed(seed)
        model = cls(
            hidden_size=hidden_size,
            layer_count=layer_count,
            head_count=head_count,
            context_length=context_length,
            dropout=dropout,
        )
        with torch.no_grad():
            for parameter in model.parameters():
                if parameter.ndim >= 2:
                    nn.init.normal_(parameter, mean=0.0, std=scale)
                else:
                    parameter.zero_()
        return model.to(device)

    @classmethod
    def from_checkpoint(
        cls, path: Path, device: torch.device
    ) -> "RoutedTransformerMaskedStatePolicy":
        checkpoint = torch.load(path, map_location="cpu")
        model = cls(
            input_size=int(checkpoint.get("input_size", STATE_INPUT_SIZE)),
            hidden_size=int(checkpoint["hidden_size"]),
            layer_count=int(checkpoint["layer_count"]),
            head_count=int(checkpoint["head_count"]),
            context_length=int(checkpoint["context_length"]),
            action_feature_size=int(
                checkpoint.get("action_feature_size", ROUTED_ACTION_FEATURE_SIZE)
            ),
        )
        model.load_state_dict(checkpoint["state_dict"])
        return model.to(device)

    def save_checkpoint(
        self, path: Path, *, training_record: dict[str, Any] | None = None
    ) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "format": "kolkhoz-masked-state-routed-transformer-policy-v1",
                "architecture": "masked-state-routed-transformer",
                "action_encoding": "phase-routed-candidate",
                "input_size": self.input_size,
                "hidden_size": self.hidden_size,
                "layer_count": self.layer_count,
                "head_count": self.head_count,
                "context_length": self.context_length,
                "action_feature_size": self.action_feature_size,
                "routed_head_count": ROUTED_HEAD_COUNT,
                "state_dict": self.state_dict(),
                "training_record": training_record,
            },
            path,
        )


def _choose_routed_transformer_model_action(
    model: RoutedTransformerMaskedStatePolicy,
    engine: CEngine,
    pointer: Any,
    *,
    player_id: int,
    context: torch.Tensor,
    device: torch.device,
    sample: bool,
    temperature: float,
) -> tuple[KCAction, RoutedTransformerMaskedTransition | None, torch.Tensor]:
    actions = engine.legal_actions(pointer)
    routed_actions, action_features, action_head_ids = _routed_legal_actions(actions)
    if not routed_actions:
        raise RuntimeError("routed transformer policy was asked to move with no legal actions")
    state = _state_tensor(engine, pointer, player_id, device)
    next_context = _append_transformer_context(context.detach(), state)
    features_tensor = torch.tensor(
        [action_features], dtype=torch.float32, device=device
    )
    head_ids_tensor = torch.tensor([action_head_ids], dtype=torch.long, device=device)
    action_mask = torch.ones(head_ids_tensor.shape, dtype=torch.bool, device=device)
    scores, values = model.score_actions(
        next_context.unsqueeze(0),
        features_tensor,
        head_ids_tensor,
        action_mask,
    )
    distribution = torch.distributions.Categorical(
        logits=scores[0] / max(0.05, temperature)
    )
    selected = distribution.sample() if sample else torch.argmax(scores[0])
    selected_index = int(selected.item())
    action = routed_actions[selected_index]
    transition = None
    if sample:
        transition = RoutedTransformerMaskedTransition(
            context=next_context.detach().cpu().tolist(),
            action_features=action_features,
            action_head_ids=action_head_ids,
            selected_index=selected_index,
            log_probability=float(distribution.log_prob(selected).detach().cpu().item()),
            value=float(values[0].detach().cpu().item()),
            player_id=player_id,
        )
    return action, transition, next_context.detach()


def rollout_routed_transformer_masked_episode(
    engine: CEngine,
    model: RoutedTransformerMaskedStatePolicy,
    *,
    seed: int,
    device: torch.device,
    temperature: float,
    max_actions: int = 512,
) -> RoutedTransformerMaskedEpisode:
    pointer = engine.new_engine(seed, controllers=_all_external_controllers())
    contexts = model.initial_context(4, device)
    transitions: list[RoutedTransformerMaskedTransition] = []
    try:
        for _ in range(max_actions):
            phase = engine.phase(pointer)
            if phase == KC_PHASE_GAME_OVER:
                scores = engine.final_scores(pointer)
                rewards = _player_rewards(scores)
                for transition in transitions:
                    transition.reward = rewards[transition.player_id]
                return RoutedTransformerMaskedEpisode(
                    transitions=transitions,
                    scores=scores,
                    rewards=rewards,
                    winner_id=_winner_id(scores),
                )
            actions = engine.legal_actions(pointer)
            if not actions:
                status = engine.step_automatic(pointer)
                if status < 0:
                    raise RuntimeError(f"automatic routed transformer rollout step failed: {status}")
                continue
            player_id = int(actions[0].player_id)
            if phase == KC_PHASE_REQUISITION:
                engine.apply_action(pointer, actions[0])
                continue
            action, transition, next_context = _choose_routed_transformer_model_action(
                model,
                engine,
                pointer,
                player_id=player_id,
                context=contexts[player_id],
                device=device,
                sample=True,
                temperature=temperature,
            )
            contexts[player_id] = next_context
            if transition is not None:
                transitions.append(transition)
            engine.apply_policy_action(pointer, action)
        raise RuntimeError("routed transformer masked rollout exceeded action limit")
    finally:
        engine.free_engine(pointer)


def _routed_transformer_ppo_update(
    model: RoutedTransformerMaskedStatePolicy,
    optimizer: torch.optim.Optimizer,
    transitions: list[RoutedTransformerMaskedTransition],
    *,
    device: torch.device,
    ppo_epochs: int,
    minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
) -> dict[str, float]:
    if not transitions:
        return {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    contexts = torch.tensor([item.context for item in transitions], dtype=torch.float32, device=device)
    max_actions = max(len(item.action_features) for item in transitions)
    action_features = torch.zeros(
        (len(transitions), max_actions, ROUTED_ACTION_FEATURE_SIZE),
        dtype=torch.float32,
        device=device,
    )
    action_head_ids = torch.zeros(
        (len(transitions), max_actions), dtype=torch.long, device=device
    )
    action_mask = torch.zeros(
        (len(transitions), max_actions), dtype=torch.bool, device=device
    )
    for row, item in enumerate(transitions):
        count = len(item.action_features)
        action_features[row, :count] = torch.tensor(
            item.action_features, dtype=torch.float32, device=device
        )
        action_head_ids[row, :count] = torch.tensor(
            item.action_head_ids, dtype=torch.long, device=device
        )
        action_mask[row, :count] = True
    selected_indices = torch.tensor(
        [item.selected_index for item in transitions], dtype=torch.long, device=device
    )
    old_log_probs = torch.tensor(
        [item.log_probability for item in transitions], dtype=torch.float32, device=device
    )
    returns = torch.tensor(
        [item.reward for item in transitions], dtype=torch.float32, device=device
    )
    old_values = torch.tensor([item.value for item in transitions], dtype=torch.float32, device=device)
    advantages = returns - old_values
    if advantages.numel() > 1:
        advantages = (advantages - advantages.mean()) / advantages.std().clamp_min(1.0e-6)
    indices = list(range(len(transitions)))
    metrics = {"loss": 0.0, "policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0}
    steps = 0
    for _ in range(ppo_epochs):
        random.shuffle(indices)
        for start in range(0, len(indices), minibatch_size):
            batch_indices = indices[start : start + minibatch_size]
            batch_contexts = contexts[batch_indices]
            batch_features = action_features[batch_indices]
            batch_head_ids = action_head_ids[batch_indices]
            batch_mask = action_mask[batch_indices]
            batch_selected = selected_indices[batch_indices]
            batch_old_log_probs = old_log_probs[batch_indices]
            batch_returns = returns[batch_indices]
            batch_advantages = advantages[batch_indices]
            scores, values = model.score_actions(
                batch_contexts,
                batch_features,
                batch_head_ids,
                batch_mask,
            )
            distribution = torch.distributions.Categorical(logits=scores)
            log_probs = distribution.log_prob(batch_selected)
            ratio = torch.exp(log_probs - batch_old_log_probs)
            clipped = torch.clamp(ratio, 1.0 - ppo_clip, 1.0 + ppo_clip)
            policy_loss = -torch.minimum(
                ratio * batch_advantages, clipped * batch_advantages
            ).mean()
            value_loss = F.mse_loss(values, batch_returns)
            entropy = distribution.entropy().mean()
            loss = policy_loss + value_loss_weight * value_loss - entropy_weight * entropy
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            metrics["loss"] += float(loss.detach().cpu().item())
            metrics["policy_loss"] += float(policy_loss.detach().cpu().item())
            metrics["value_loss"] += float(value_loss.detach().cpu().item())
            metrics["entropy"] += float(entropy.detach().cpu().item())
            steps += 1
    if steps:
        for key in metrics:
            metrics[key] /= steps
    return metrics


def evaluate_routed_transformer_masked_policy(
    engine: CEngine,
    model: RoutedTransformerMaskedStatePolicy,
    *,
    games_per_seat: int,
    seed: int,
    device: torch.device,
) -> dict[str, Any]:
    model.eval()
    wins = 0
    ties = 0
    total = 0
    margins: list[float] = []
    try:
        for model_seat in range(4):
            for offset in range(games_per_seat):
                pointer = engine.new_engine(
                    seed + model_seat * games_per_seat + offset,
                    controllers=_all_external_controllers(),
                )
                contexts = model.initial_context(4, device)
                try:
                    for _ in range(512):
                        phase = engine.phase(pointer)
                        if phase == KC_PHASE_GAME_OVER:
                            break
                        actions = engine.legal_actions(pointer)
                        if not actions:
                            status = engine.step_automatic(pointer)
                            if status < 0:
                                raise RuntimeError(
                                    f"routed transformer eval automatic step failed: {status}"
                                )
                            continue
                        player_id = int(actions[0].player_id)
                        if phase == KC_PHASE_REQUISITION:
                            engine.apply_action(pointer, actions[0])
                        elif player_id == model_seat:
                            action, _, next_context = _choose_routed_transformer_model_action(
                                model,
                                engine,
                                pointer,
                                player_id=player_id,
                                context=contexts[player_id],
                                device=device,
                                sample=False,
                                temperature=1.0,
                            )
                            contexts[player_id] = next_context
                            engine.apply_policy_action(pointer, action)
                        else:
                            engine.apply_policy_action(pointer, engine.heuristic_action(pointer))
                    scores = engine.final_scores(pointer)
                    best = max(scores)
                    if scores[model_seat] == best:
                        if scores.count(best) > 1:
                            ties += 1
                        else:
                            wins += 1
                    opponent_best = max(
                        score for index, score in enumerate(scores) if index != model_seat
                    )
                    margins.append(float(scores[model_seat] - opponent_best))
                    total += 1
                finally:
                    engine.free_engine(pointer)
    finally:
        model.train()
    return {
        "games": total,
        "games_per_seat": games_per_seat,
        "wins": wins,
        "ties": ties,
        "win_rate": wins / total if total else 0.0,
        "tie_rate": ties / total if total else 0.0,
        "average_margin": sum(margins) / len(margins) if margins else 0.0,
    }


def train_routed_transformer_masked_state_policy(
    engine: CEngine,
    *,
    output_path: Path,
    start_model_path: Path | None,
    hidden_size: int,
    layer_count: int,
    head_count: int,
    context_length: int,
    dropout: float,
    scratch_seed: int,
    scratch_scale: float,
    episodes: int,
    batch_size: int,
    seed: int,
    learning_rate: float,
    temperature: float,
    prefer_mps: bool,
    ppo_epochs: int,
    ppo_minibatch_size: int,
    ppo_clip: float,
    value_loss_weight: float,
    entropy_weight: float,
    eval_interval: int = 0,
    eval_games_per_seat: int = 4,
    eval_seed: int = 91_000_000,
    record_history: bool = False,
    progress_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    device = best_device(prefer_mps)
    if start_model_path is None:
        model = RoutedTransformerMaskedStatePolicy.scratch(
            hidden_size=hidden_size,
            layer_count=layer_count,
            head_count=head_count,
            context_length=context_length,
            dropout=dropout,
            seed=scratch_seed,
            scale=scratch_scale,
            device=device,
        )
    else:
        model = RoutedTransformerMaskedStatePolicy.from_checkpoint(start_model_path, device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    all_points: list[dict[str, Any]] = []
    completed = 0
    last_metrics: dict[str, float] = {}
    last_eval: dict[str, Any] | None = None
    best_eval: dict[str, Any] | None = None
    best_eval_score: float | None = None
    while completed < episodes:
        current_batch = min(batch_size, episodes - completed)
        batch_episodes = [
            rollout_routed_transformer_masked_episode(
                engine,
                model,
                seed=seed + completed + index,
                device=device,
                temperature=temperature,
            )
            for index in range(current_batch)
        ]
        transitions = [
            transition
            for episode in batch_episodes
            for transition in episode.transitions
        ]
        reward_by_player = [0.0, 0.0, 0.0, 0.0]
        reward_counts = [0, 0, 0, 0]
        for episode in batch_episodes:
            for player_id, reward in enumerate(episode.rewards):
                reward_by_player[player_id] += reward
                reward_counts[player_id] += 1
        mean_rewards = [
            reward_by_player[index] / max(1, reward_counts[index]) for index in range(4)
        ]
        last_metrics = _routed_transformer_ppo_update(
            model,
            optimizer,
            transitions,
            device=device,
            ppo_epochs=ppo_epochs,
            minibatch_size=ppo_minibatch_size,
            ppo_clip=ppo_clip,
            value_loss_weight=value_loss_weight,
            entropy_weight=entropy_weight,
        )
        completed += current_batch
        point = {
            "completed_episodes": completed,
            "average_reward": sum(mean_rewards) / len(mean_rewards),
            "actions": len(transitions),
            **last_metrics,
        }
        all_points.append(point)
        if eval_interval > 0 and completed % eval_interval == 0:
            last_eval = evaluate_routed_transformer_masked_policy(
                engine,
                model,
                games_per_seat=eval_games_per_seat,
                seed=eval_seed + completed,
                device=device,
            )
            point["eval"] = last_eval
            best_eval, best_eval_score = _maybe_save_best_eval(
                model,
                output_path,
                completed,
                last_eval,
                best_eval,
                best_eval_score,
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "architecture": "masked-state-routed-transformer",
                    "action_encoding": "phase-routed-candidate",
                    "hidden_size": hidden_size,
                    "layer_count": layer_count,
                    "head_count": head_count,
                    "context_length": context_length,
                    "action_feature_size": ROUTED_ACTION_FEATURE_SIZE,
                    "routed_head_count": ROUTED_HEAD_COUNT,
                    "episodes": episodes,
                    "batch_size": batch_size,
                    "seed": seed,
                    "learning_rate": learning_rate,
                    "points": all_points,
                    "curve": {"points": all_points},
                    "latest_evaluation": last_eval,
                },
            )
        if progress_callback is not None:
            progress_callback(
                {
                    "kind": "masked_state_policy_training",
                    "backend": "torch",
                    "status": "running",
                    "phase": "training",
                    "output_model": str(output_path),
                    "start_model": str(start_model_path) if start_model_path else "scratch",
                    "model": {
                        "architecture": "masked-state-routed-transformer",
                        "action_encoding": "phase-routed-candidate",
                        "hidden_size": hidden_size,
                        "layer_count": layer_count,
                        "head_count": head_count,
                        "context_length": context_length,
                        "action_feature_size": ROUTED_ACTION_FEATURE_SIZE,
                        "routed_head_count": ROUTED_HEAD_COUNT,
                    },
                    "training": {
                        "episodes": episodes,
                        "batch_size": batch_size,
                        "seed": seed,
                        "learning_rate": learning_rate,
                        "ppo_epochs": ppo_epochs,
                        "ppo_minibatch_size": ppo_minibatch_size,
                        "eval_interval": eval_interval,
                        "eval_games_per_seat": eval_games_per_seat,
                    },
                    "curve": {
                        "points": all_points,
                    },
                    "latest_point": point,
                    "latest_evaluation": last_eval,
                    "best_evaluation": best_eval,
                    "best_model": str(_best_eval_path(output_path)) if best_eval else None,
                    "progress": {
                        "completed_episodes": completed,
                        "total_episodes": episodes,
                        "percent": completed / max(1, episodes),
                    },
                }
            )
    training_record = {
        "kind": "masked_state_policy_training",
        "backend": "torch",
        "architecture": "masked-state-routed-transformer",
        "action_encoding": "phase-routed-candidate",
        "hidden_size": hidden_size,
        "layer_count": layer_count,
        "head_count": head_count,
        "context_length": context_length,
        "action_feature_size": ROUTED_ACTION_FEATURE_SIZE,
        "routed_head_count": ROUTED_HEAD_COUNT,
        "episodes": episodes,
        "batch_size": batch_size,
        "seed": seed,
        "learning_rate": learning_rate,
        "points": all_points,
        "curve": {
            "points": all_points,
        },
        "latest_evaluation": last_eval,
        "best_evaluation": best_eval,
        "best_model": str(_best_eval_path(output_path)) if best_eval else None,
    }
    model.save_checkpoint(output_path, training_record=training_record)
    record = {
        **training_record,
        "status": "completed",
        "output_model": str(output_path),
        "device": str(device),
        "final_metrics": last_metrics,
    }
    if record_history:
        append_history(record)
    if progress_callback is not None:
        progress_callback(
            {
                **record,
                "phase": "completed",
                "progress": {
                    "completed_episodes": episodes,
                    "total_episodes": episodes,
                    "percent": 1.0,
                },
            }
        )
    return record
