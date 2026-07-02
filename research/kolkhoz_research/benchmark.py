from __future__ import annotations

import random
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from .c_engine import CEngine, KCPolicyModelBuffer
from .model import PolicyArtifact


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
    pass_gate = (
        intervals["win_delta"]["low"] >= min_win_delta
        and intervals["rank_delta"]["low"] >= min_rank_delta
        and intervals["margin_delta"]["low"] >= min_margin_delta
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
        "intervals": intervals,
        "summary": {
            "candidate_win_rate": _mean([record.candidate.win for record in records]),
            "baseline_win_rate": _mean([record.baseline.win for record in records]),
            "candidate_average_rank": _mean([record.candidate.rank for record in records]),
            "baseline_average_rank": _mean([record.baseline.rank for record in records]),
            "candidate_average_margin": _mean([record.candidate.margin for record in records]),
            "baseline_average_margin": _mean([record.baseline.margin for record in records]),
        },
        "status": "passed_gate" if pass_gate else "rejected",
    }
    if include_games:
        record["games"] = games
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
