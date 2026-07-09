from __future__ import annotations

import math
import random
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from .c_engine import CEngine, KCControllers, KCPolicyModelBuffer, REPO_ROOT
from .model import PolicyArtifact
from .ratings import DEFAULT_MU, DEFAULT_SIGMA, RatingInput, display_rating, rate_multiplayer


PHASE_GAME_OVER = 5
BOT_RATING_CONTROLLERS = ("heuristicAI", "mediumAI", "neuralAI")
DEFAULT_BOT_POLICY_PATHS = {
    "mediumAI": REPO_ROOT / "clients/flutter_app/assets/policies/medium_policy.json",
    "neuralAI": REPO_ROOT / "clients/flutter_app/assets/policies/hard_policy.json",
}


@dataclass(frozen=True)
class GameMetrics:
    win: float
    rank: float
    margin: float


@dataclass(frozen=True)
class PairedRecord:
    seed: int
    seat: int
    candidate: GameMetrics
    baseline: GameMetrics
    win_delta: float
    rank_delta: float
    margin_delta: float


@dataclass(frozen=True)
class BotRatingVirtualPlayer:
    key: str
    controller: str


@dataclass
class BotRatingState:
    key: str
    controller: str
    mu: float = DEFAULT_MU
    sigma: float = DEFAULT_SIGMA
    games: int = 0
    wins: int = 0
    rank_total: float = 0.0
    score_total: float = 0.0


def _rank(scores: list[int], medals: list[int], player_id: int) -> int:
    rank = 1
    own = (scores[player_id], medals[player_id], player_id)
    for other in range(4):
        if other == player_id:
            continue
        rival = (scores[other], medals[other], other)
        if rival > own:
            rank += 1
    return rank


def _metrics(scores: list[int], medals: list[int], winner: int, seat: int) -> GameMetrics:
    best_opponent = max(scores[player] for player in range(4) if player != seat)
    return GameMetrics(
        win=1.0 if winner == seat else 0.0,
        rank=float(_rank(scores, medals, seat)),
        margin=float(scores[seat] - best_opponent),
    )


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _ci(values: list[float], samples: int, seed: int) -> dict[str, float]:
    if not values:
        return {"low": 0.0, "mean": 0.0, "high": 0.0}
    if samples <= 0 or len(values) == 1:
        mean = _mean(values)
        return {"low": mean, "mean": mean, "high": mean}
    rng = random.Random(seed)
    means = []
    for _ in range(samples):
        means.append(_mean([values[rng.randrange(len(values))] for _ in values]))
    means.sort()
    low = means[int(0.025 * (len(means) - 1))]
    high = means[int(0.975 * (len(means) - 1))]
    return {"low": low, "mean": _mean(values), "high": high}


def _quantile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, round(q * (len(ordered) - 1))))
    return ordered[index]


def _bootstrap_positive_rate(
    values: list[float], samples: int, seed: int, threshold: float = 0.0
) -> float:
    if not values:
        return 0.0
    if samples <= 0 or len(values) == 1:
        return 1.0 if _mean(values) > threshold else 0.0
    rng = random.Random(seed)
    positive = 0
    for _ in range(samples):
        sample_mean = _mean([values[rng.randrange(len(values))] for _ in values])
        positive += 1 if sample_mean > threshold else 0
    return positive / samples


def _histogram(values: list[float], bucket_size: float = 5.0) -> list[dict[str, float]]:
    if not values:
        return []
    low = math.floor(min(values) / bucket_size) * bucket_size
    high = math.ceil(max(values) / bucket_size) * bucket_size
    if low == high:
        high = low + bucket_size
    bucket_count = int((high - low) / bucket_size)
    counts = [0 for _ in range(bucket_count)]
    for value in values:
        index = min(bucket_count - 1, max(0, int((value - low) / bucket_size)))
        counts[index] += 1
    total = len(values)
    return [
        {
            "low": low + index * bucket_size,
            "high": low + (index + 1) * bucket_size,
            "count": count,
            "rate": count / total,
        }
        for index, count in enumerate(counts)
    ]


def _record_delta(record: Any, key: str) -> float:
    if isinstance(record, dict):
        return float(record[key])
    return float(getattr(record, key))


def _record_metric(record: Any, side: str, key: str) -> float:
    if isinstance(record, dict):
        return float(record[side][key])
    return float(getattr(getattr(record, side), key))


def _margin_shape(records: list[Any], bootstrap_samples: int, seed: int) -> dict[str, Any]:
    win_values = [_record_delta(record, "win_delta") for record in records]
    rank_values = [_record_delta(record, "rank_delta") for record in records]
    margin_values = [_record_delta(record, "margin_delta") for record in records]
    candidate_margins = [_record_metric(record, "candidate", "margin") for record in records]
    winning_margins = [
        _record_metric(record, "candidate", "margin")
        for record in records
        if _record_metric(record, "candidate", "win") > 0.5
    ]
    losing_margins = [
        _record_metric(record, "candidate", "margin")
        for record in records
        if _record_metric(record, "candidate", "win") <= 0.5
    ]
    close_losses = [value for value in losing_margins if value >= -5.0]
    blowout_losses = [value for value in losing_margins if value <= -15.0]
    return {
        "positive_rates": {
            "win_delta": _bootstrap_positive_rate(
                win_values, bootstrap_samples, seed ^ 0x5010
            ),
            "rank_delta": _bootstrap_positive_rate(
                rank_values, bootstrap_samples, seed ^ 0x5011
            ),
            "margin_delta": _bootstrap_positive_rate(
                margin_values, bootstrap_samples, seed ^ 0x5012
            ),
        },
        "margin_delta_quantiles": {
            "p10": _quantile(margin_values, 0.10),
            "p25": _quantile(margin_values, 0.25),
            "median": _quantile(margin_values, 0.50),
            "p75": _quantile(margin_values, 0.75),
            "p90": _quantile(margin_values, 0.90),
        },
        "candidate_margin_quantiles": {
            "p10": _quantile(candidate_margins, 0.10),
            "p25": _quantile(candidate_margins, 0.25),
            "median": _quantile(candidate_margins, 0.50),
            "p75": _quantile(candidate_margins, 0.75),
            "p90": _quantile(candidate_margins, 0.90),
        },
        "win_loss_shape": {
            "wins": len(winning_margins),
            "losses": len(losing_margins),
            "mean_winning_margin": _mean(winning_margins),
            "mean_losing_margin": _mean(losing_margins),
            "median_winning_margin": _quantile(winning_margins, 0.50),
            "median_losing_margin": _quantile(losing_margins, 0.50),
            "close_loss_rate": len(close_losses) / len(losing_margins)
            if losing_margins
            else 0.0,
            "blowout_loss_rate": len(blowout_losses) / len(losing_margins)
            if losing_margins
            else 0.0,
        },
        "margin_delta_histogram": _histogram(margin_values),
    }


def _promotion_decision(
    *,
    win_values: list[float],
    rank_values: list[float],
    margin_values: list[float],
    intervals: dict[str, dict[str, float]],
    bootstrap_samples: int,
    seed: int,
    objective: str,
    utility_win_weight: float,
    utility_rank_weight: float,
    utility_margin_weight: float,
    min_win_delta: float,
    min_rank_delta: float,
    min_margin_delta: float,
    min_utility_delta: float,
    candidate_pool_min_utility_delta: float,
    risk_min_win_delta_mean: float | None,
    risk_min_rank_delta_mean: float | None,
    risk_min_margin_delta_mean: float | None,
    evidence_grade: str,
) -> dict[str, Any]:
    utility_values = [
        utility_win_weight * win
        + utility_rank_weight * rank
        + utility_margin_weight * margin
        for win, rank, margin in zip(win_values, rank_values, margin_values)
    ]
    utility_interval = _ci(utility_values, bootstrap_samples, seed ^ 0xA11C)
    intervals["utility_delta"] = utility_interval

    means = {
        "win_delta": _mean(win_values),
        "rank_delta": _mean(rank_values),
        "margin_delta": _mean(margin_values),
        "utility_delta": utility_interval["mean"],
    }
    risk_budgets = {
        "min_win_delta_mean": risk_min_win_delta_mean,
        "min_rank_delta_mean": risk_min_rank_delta_mean,
        "min_margin_delta_mean": risk_min_margin_delta_mean,
    }
    risk_checks = {
        "win_delta_mean": risk_min_win_delta_mean is None
        or means["win_delta"] >= risk_min_win_delta_mean,
        "rank_delta_mean": risk_min_rank_delta_mean is None
        or means["rank_delta"] >= risk_min_rank_delta_mean,
        "margin_delta_mean": risk_min_margin_delta_mean is None
        or means["margin_delta"] >= risk_min_margin_delta_mean,
    }
    risk_pass = all(risk_checks.values())
    threshold_budgets = {
        "min_win_delta": min_win_delta,
        "min_rank_delta": min_rank_delta,
        "min_margin_delta": min_margin_delta,
    }
    threshold_checks = {
        "win_delta_low": intervals["win_delta"]["low"] >= min_win_delta,
        "rank_delta_low": intervals["rank_delta"]["low"] >= min_rank_delta,
        "margin_delta_low": intervals["margin_delta"]["low"] >= min_margin_delta,
    }
    threshold_pass = all(threshold_checks.values())
    candidate_pool_threshold_checks = {
        "win_delta_mean": means["win_delta"] >= min_win_delta,
        "rank_delta_mean": means["rank_delta"] >= min_rank_delta,
        "margin_delta_mean": means["margin_delta"] >= min_margin_delta,
    }
    candidate_pool_threshold_pass = all(candidate_pool_threshold_checks.values())

    if objective != "utility":
        raise ValueError(f"unknown promotion objective {objective!r}")
    pass_gate = (
        utility_interval["low"] >= min_utility_delta
        and threshold_pass
        and risk_pass
    )
    candidate_pool = (
        not pass_gate
        and utility_interval["mean"] > candidate_pool_min_utility_delta
        and candidate_pool_threshold_pass
        and risk_pass
    )
    primary_objective = "paired_utility_delta"

    promotion_eligible = bool(pass_gate and evidence_grade == "promotion")
    status = (
        "passed_promotion_gate"
        if promotion_eligible
        else (
            "passed_selection_gate"
            if pass_gate
            else ("candidate_pool" if candidate_pool else "rejected")
        )
    )
    return {
        "status": status,
        "pass_gate": pass_gate,
        "candidate_pool": candidate_pool,
        "promotion_eligible": promotion_eligible,
        "primary_objective": primary_objective,
        "objective": {
            "mode": objective,
            "utility_weights": {
                "win": utility_win_weight,
                "rank": utility_rank_weight,
                "margin": utility_margin_weight,
            },
            "min_utility_delta": min_utility_delta,
            "candidate_pool_min_utility_delta": candidate_pool_min_utility_delta,
            "threshold_budgets": threshold_budgets,
            "threshold_checks": threshold_checks,
            "threshold_pass": threshold_pass,
            "candidate_pool_threshold_checks": candidate_pool_threshold_checks,
            "candidate_pool_threshold_pass": candidate_pool_threshold_pass,
            "risk_budgets": risk_budgets,
            "risk_checks": risk_checks,
            "risk_pass": risk_pass,
            "means": means,
        },
    }


def _empty_model() -> KCPolicyModelBuffer:
    return KCPolicyModelBuffer()


def run_policy_game(
    engine: CEngine,
    *,
    seed: int,
    model: PolicyArtifact | None,
    model_is_heuristic: bool,
    opponent: PolicyArtifact | None,
    opponent_is_heuristic: bool,
    seat: int,
    round_curriculum: bool = False,
    round_plot_cards: int = 0,
    round_famine_rate: float = 0.0,
) -> dict[str, Any]:
    model_buffer = _empty_model() if model is None else model.c_buffer()
    opponent_buffer = _empty_model() if opponent is None else opponent.c_buffer()
    result = engine.run_policy_matchup_game(
        seed=seed,
        model=model_buffer,
        model_is_heuristic=model_is_heuristic,
        opponent_model=opponent_buffer,
        opponent_is_heuristic=opponent_is_heuristic,
        model_seat=seat,
        round_curriculum=round_curriculum,
        round_plot_cards=round_plot_cards,
        round_famine_rate=round_famine_rate,
    )
    if result.status != 0:
        raise RuntimeError(f"C policy game failed with status {result.status}")
    scores = [int(result.scores[index]) for index in range(4)]
    medals = [int(result.medals[index]) for index in range(4)]
    return {
        "seed": seed,
        "seat": seat,
        "actions": int(result.actions),
        "checksum": int(result.checksum),
        "scores": scores,
        "medals": medals,
        "winner_id": int(result.winner_id),
        "metrics": asdict(_metrics(scores, medals, int(result.winner_id), seat)),
    }


def benchmark_candidate(
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
) -> dict[str, Any]:
    candidate = PolicyArtifact.load(candidate_path)
    baseline = PolicyArtifact.load(baseline_path) if baseline_path else None
    baseline_is_heuristic = baseline is None
    records: list[PairedRecord] = []
    games: list[dict[str, Any]] = []

    for seat in range(4):
        for offset in range(games_per_seat):
            game_seed = seed + seat * games_per_seat + offset
            candidate_game = run_policy_game(
                engine,
                seed=game_seed,
                model=candidate,
                model_is_heuristic=False,
                opponent=baseline,
                opponent_is_heuristic=baseline_is_heuristic,
                seat=seat,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
            baseline_game = run_policy_game(
                engine,
                seed=game_seed,
                model=baseline,
                model_is_heuristic=baseline_is_heuristic,
                opponent=baseline,
                opponent_is_heuristic=baseline_is_heuristic,
                seat=seat,
                round_curriculum=round_curriculum,
                round_plot_cards=round_plot_cards,
                round_famine_rate=round_famine_rate,
            )
            candidate_metrics = GameMetrics(**candidate_game["metrics"])
            baseline_metrics = GameMetrics(**baseline_game["metrics"])
            records.append(
                PairedRecord(
                    seed=game_seed,
                    seat=seat,
                    candidate=candidate_metrics,
                    baseline=baseline_metrics,
                    win_delta=candidate_metrics.win - baseline_metrics.win,
                    rank_delta=baseline_metrics.rank - candidate_metrics.rank,
                    margin_delta=candidate_metrics.margin - baseline_metrics.margin,
                )
            )
            if include_games:
                games.append({"candidate": candidate_game, "baseline": baseline_game})

    win_values = [record.win_delta for record in records]
    rank_values = [record.rank_delta for record in records]
    margin_values = [record.margin_delta for record in records]
    intervals = {
        "win_delta": _ci(win_values, bootstrap_samples, seed ^ 0xB00A),
        "rank_delta": _ci(rank_values, bootstrap_samples, seed ^ 0xB00B),
        "margin_delta": _ci(margin_values, bootstrap_samples, seed ^ 0xB00C),
    }
    evidence_grade = "promotion" if (
        games_per_seat >= promotion_min_games_per_seat
        and bootstrap_samples >= promotion_min_bootstrap_samples
        and len(records) >= promotion_min_games_per_seat * 4
    ) else "selection"
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
        "kind": "policy_benchmark",
        "candidate_model": str(candidate_path),
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "games_per_seat": games_per_seat,
        "total_games": len(records),
        "seed": seed,
        "round_curriculum": round_curriculum,
        "curriculum_rounds": 2 if round_curriculum else None,
        "round_plot_cards": round_plot_cards,
        "round_famine_rate": round_famine_rate,
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
            "candidate_win_rate": _mean([record.candidate.win for record in records]),
            "baseline_win_rate": _mean([record.baseline.win for record in records]),
            "candidate_average_rank": _mean([record.candidate.rank for record in records]),
            "baseline_average_rank": _mean([record.baseline.rank for record in records]),
            "candidate_average_margin": _mean([record.candidate.margin for record in records]),
            "baseline_average_margin": _mean([record.baseline.margin for record in records]),
        },
        "status": decision["status"],
    }
    if include_games:
        record["games"] = games
    return record


def _load_bot_policy_buffers(
    policy_paths: dict[str, Path] | None = None,
) -> dict[str, KCPolicyModelBuffer]:
    paths = {**DEFAULT_BOT_POLICY_PATHS, **(policy_paths or {})}
    buffers: dict[str, KCPolicyModelBuffer] = {}
    for controller, path in paths.items():
        if controller == "heuristicAI":
            continue
        buffers[controller] = PolicyArtifact.load(path).c_buffer()
    return buffers


def _bot_rating_virtual_players(
    *,
    controllers: tuple[str, ...] = BOT_RATING_CONTROLLERS,
    virtual_players_per_controller: int,
) -> list[BotRatingVirtualPlayer]:
    players: list[BotRatingVirtualPlayer] = []
    for controller in controllers:
        for index in range(virtual_players_per_controller):
            players.append(
                BotRatingVirtualPlayer(
                    key=f"{controller}-{index + 1}",
                    controller=controller,
                )
            )
    return players


def _bot_rating_lineup(
    *,
    controllers: tuple[str, ...],
    players_by_controller: dict[str, list[BotRatingVirtualPlayer]],
    game_index: int,
    seed: int,
) -> list[BotRatingVirtualPlayer]:
    duplicate_controller = controllers[game_index % len(controllers)]
    controller_lineup = list(controllers) + [duplicate_controller]
    rng = random.Random(seed + game_index * 104_729)
    rng.shuffle(controller_lineup)

    usage: dict[str, int] = {}
    lineup: list[BotRatingVirtualPlayer] = []
    for seat, controller in enumerate(controller_lineup):
        players = players_by_controller[controller]
        occurrence = usage.get(controller, 0)
        usage[controller] = occurrence + 1
        player_index = (game_index + seat + occurrence) % len(players)
        lineup.append(players[player_index])
    return lineup


def _run_bot_rating_game(
    engine: CEngine,
    *,
    seed: int,
    lineup: list[BotRatingVirtualPlayer],
    policy_buffers: dict[str, KCPolicyModelBuffer],
    max_actions: int = 1000,
) -> dict[str, Any]:
    controller_codes = tuple(
        1 if player.controller == "heuristicAI" else 2 for player in lineup
    )
    pointer = engine.new_engine(seed, controllers=KCControllers(controller_codes))
    actions = 0
    checksum = 0
    policy_fallbacks = 0
    try:
        while engine.phase(pointer) != PHASE_GAME_OVER and actions < max_actions:
            player_id = engine.waiting_player(pointer)
            if player_id < 0 or player_id >= len(lineup):
                break
            controller = lineup[player_id].controller
            if controller == "heuristicAI":
                action = engine.heuristic_action(pointer)
            else:
                action = engine.policy_action(pointer, policy_buffers[controller])
                if action is None:
                    try:
                        action = engine.heuristic_action(pointer)
                    except RuntimeError:
                        status = engine.step_policy_automatic(
                            pointer,
                            policy_buffers[controller],
                        )
                        if status < 0:
                            raise RuntimeError(
                                f"{controller} automatic step failed with status {status}"
                            )
                        if status > 0:
                            actions += 1
                            checksum = (
                                (checksum * 131) ^ (int(player_id) << 8) ^ 0x7F
                            ) & 0x7FFFFFFF
                            continue
                        raise RuntimeError(
                            f"{controller} could not choose an action "
                            f"(phase={engine.phase(pointer)}, player={player_id})"
                        )
                    policy_fallbacks += 1
            if action.player_id != player_id:
                legal_actions = [
                    item for item in engine.legal_actions(pointer) if item.player_id == player_id
                ]
                if not legal_actions:
                    break
                action = legal_actions[0]
            engine.apply_ai_action(pointer, action)
            actions += 1
            checksum = ((checksum * 131) ^ int(action.kind) ^ (int(action.player_id) << 8)) & 0x7FFFFFFF

        if engine.phase(pointer) != PHASE_GAME_OVER:
            raise RuntimeError(
                f"bot rating game did not finish within {max_actions} actions"
            )
        scores = engine.final_scores(pointer)
        medals = engine.total_medals(pointer)
        winner = engine.winner_id(pointer)
        return {
            "seed": seed,
            "actions": actions,
            "checksum": checksum,
            "policy_fallbacks": policy_fallbacks,
            "winner_id": winner,
            "scores": scores,
            "medals": medals,
            "players": [
                {"key": player.key, "controller": player.controller}
                for player in lineup
            ],
        }
    finally:
        engine.free_engine(pointer)


def run_bot_rating_simulation(
    engine: CEngine,
    *,
    games: int,
    seed: int,
    virtual_players_per_controller: int = 4,
    anchor_controller: str = "neuralAI",
    anchor_rating: int = 1000,
    policy_paths: dict[str, Path] | None = None,
    include_games: bool = False,
) -> dict[str, Any]:
    if games <= 0:
        raise ValueError("games must be positive")
    if virtual_players_per_controller < 2:
        raise ValueError("virtual_players_per_controller must be at least 2")
    if anchor_controller not in BOT_RATING_CONTROLLERS:
        raise ValueError(f"unknown anchor controller {anchor_controller!r}")

    virtual_players = _bot_rating_virtual_players(
        virtual_players_per_controller=virtual_players_per_controller
    )
    players_by_controller: dict[str, list[BotRatingVirtualPlayer]] = {
        controller: [
            player for player in virtual_players if player.controller == controller
        ]
        for controller in BOT_RATING_CONTROLLERS
    }
    states = {
        player.key: BotRatingState(key=player.key, controller=player.controller)
        for player in virtual_players
    }
    policy_buffers = _load_bot_policy_buffers(policy_paths)
    game_records: list[dict[str, Any]] = []

    for game_index in range(games):
        game_seed = seed + game_index
        lineup = _bot_rating_lineup(
            controllers=BOT_RATING_CONTROLLERS,
            players_by_controller=players_by_controller,
            game_index=game_index,
            seed=seed,
        )
        game = _run_bot_rating_game(
            engine,
            seed=game_seed,
            lineup=lineup,
            policy_buffers=policy_buffers,
        )
        participants: list[RatingInput] = []
        for seat, player in enumerate(lineup):
            state = states[player.key]
            rank = float(_rank(game["scores"], game["medals"], seat))
            participants.append(
                RatingInput(
                    key=player.key,
                    rank=rank,
                    score=float(game["scores"][seat]),
                    mu=state.mu,
                    sigma=state.sigma,
                )
            )
            state.games += 1
            state.wins += 1 if game["winner_id"] == seat else 0
            state.rank_total += rank
            state.score_total += float(game["scores"][seat])

        outputs = rate_multiplayer(participants)
        for key, output in outputs.items():
            states[key].mu = output.mu
            states[key].sigma = output.sigma

        if include_games:
            game_records.append(game)

    controller_rows = []
    anchor_states = [
        state for state in states.values() if state.controller == anchor_controller
    ]
    anchor_mu = _mean([state.mu for state in anchor_states])
    anchor_sigma = _mean([state.sigma for state in anchor_states])
    anchored_mu = DEFAULT_MU + (
        anchor_rating
        - 1000
        + (anchor_sigma - DEFAULT_SIGMA) * 8.0
    ) / 32.0
    mu_shift = anchored_mu - anchor_mu
    for controller in BOT_RATING_CONTROLLERS:
        controller_states = [
            state for state in states.values() if state.controller == controller
        ]
        mean_mu = _mean([state.mu for state in controller_states])
        mean_sigma = _mean([state.sigma for state in controller_states])
        total_games = sum(state.games for state in controller_states)
        total_wins = sum(state.wins for state in controller_states)
        controller_rows.append(
            {
                "controller": controller,
                "display_rating": display_rating(mean_mu + mu_shift, mean_sigma),
                "relative_display_rating": display_rating(mean_mu, mean_sigma),
                "mu": mean_mu + mu_shift,
                "relative_mu": mean_mu,
                "sigma": mean_sigma,
                "games": total_games,
                "win_rate": total_wins / total_games if total_games else 0.0,
                "average_rank": (
                    sum(state.rank_total for state in controller_states) / total_games
                    if total_games
                    else 0.0
                ),
                "average_score": (
                    sum(state.score_total for state in controller_states) / total_games
                    if total_games
                    else 0.0
                ),
            }
        )
    controller_rows.sort(key=lambda item: item["display_rating"], reverse=True)

    virtual_player_rows = [
        {
            "key": state.key,
            "controller": state.controller,
            "display_rating": display_rating(state.mu + mu_shift, state.sigma),
            "relative_display_rating": display_rating(state.mu, state.sigma),
            "mu": state.mu + mu_shift,
            "relative_mu": state.mu,
            "sigma": state.sigma,
            "games": state.games,
            "win_rate": state.wins / state.games if state.games else 0.0,
            "average_rank": state.rank_total / state.games if state.games else 0.0,
            "average_score": state.score_total / state.games if state.games else 0.0,
        }
        for state in sorted(states.values(), key=lambda item: item.key)
    ]

    record: dict[str, Any] = {
        "kind": "bot_rating_simulation",
        "controllers": list(BOT_RATING_CONTROLLERS),
        "games": games,
        "seed": seed,
        "virtual_players_per_controller": virtual_players_per_controller,
        "anchor": {
            "controller": anchor_controller,
            "display_rating": anchor_rating,
            "note": "absolute ratings are anchored; relative_display_rating is unanchored",
        },
        "policy_paths": {
            controller: str(path)
            for controller, path in {**DEFAULT_BOT_POLICY_PATHS, **(policy_paths or {})}.items()
        },
        "standings": controller_rows,
        "virtual_players": virtual_player_rows,
    }
    if include_games:
        record["game_records"] = game_records
    return record


def mine_seed_panel(
    engine: CEngine,
    *,
    candidate_path: Path,
    baseline_path: Path | None,
    start_seed: int,
    seed_count: int,
    games_per_seed: int,
    top: int,
) -> dict[str, Any]:
    panels = []
    for offset in range(seed_count):
        panel_seed = start_seed + offset * 10_000
        result = benchmark_candidate(
            engine,
            candidate_path=candidate_path,
            baseline_path=baseline_path,
            games_per_seat=games_per_seed,
            seed=panel_seed,
            bootstrap_samples=0,
        )
        panels.append(
            {
                "seed": panel_seed,
                "games_per_seat": games_per_seed,
                "win_delta": result["intervals"]["win_delta"]["mean"],
                "rank_delta": result["intervals"]["rank_delta"]["mean"],
                "margin_delta": result["intervals"]["margin_delta"]["mean"],
            }
        )
    panels.sort(key=lambda item: (item["win_delta"], item["rank_delta"], item["margin_delta"]))
    return {
        "kind": "seed_mining",
        "candidate_model": str(candidate_path),
        "baseline_model": str(baseline_path) if baseline_path else "heuristic",
        "start_seed": start_seed,
        "seed_count": seed_count,
        "hardest": panels[:top],
    }


def run_tournament(
    engine: CEngine,
    *,
    model_paths: list[Path],
    baseline_path: Path | None,
    games_per_seat: int,
    seed: int,
) -> dict[str, Any]:
    entries = [
        {"name": f"{path.parent.name}/{path.stem}", "path": path, "score": 0.0, "matches": 0}
        for path in model_paths
    ]
    matches = []
    for left_index, left in enumerate(entries):
        for right_index in range(left_index + 1, len(entries)):
            right = entries[right_index]
            result = benchmark_candidate(
                engine,
                candidate_path=left["path"],
                baseline_path=right["path"],
                games_per_seat=games_per_seat,
                seed=seed + len(matches) * 100_000,
                bootstrap_samples=0,
            )
            delta = result["intervals"]["win_delta"]["mean"]
            left["score"] += delta
            right["score"] -= delta
            left["matches"] += 1
            right["matches"] += 1
            matches.append(result)
    if baseline_path:
        for index, entry in enumerate(entries):
            result = benchmark_candidate(
                engine,
                candidate_path=entry["path"],
                baseline_path=baseline_path,
                games_per_seat=games_per_seat,
                seed=seed + 5_000_000 + index * 100_000,
                bootstrap_samples=0,
            )
            entry["baseline_win_delta"] = result["intervals"]["win_delta"]["mean"]
    standings = sorted(
        [
            {
                "name": str(entry["name"]),
                "path": str(entry["path"]),
                "score": entry["score"],
                "matches": entry["matches"],
                **({"baseline_win_delta": entry["baseline_win_delta"]} if "baseline_win_delta" in entry else {}),
            }
            for entry in entries
        ],
        key=lambda item: item["score"],
        reverse=True,
    )
    return {"kind": "policy_tournament", "standings": standings, "matches": matches}
