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
