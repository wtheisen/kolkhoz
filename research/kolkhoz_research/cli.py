from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .benchmark import benchmark_candidate, mine_seed_panel, run_tournament
from .c_engine import CEngine, build_shared_library
from .dashboard import serve_dashboard
from .history import append_history, write_current_experiment
from .torch_policy import torch_benchmark_candidate, torch_parity, train_torch_policy
from .training import train_c_mlp


def engine_smoke(args: argparse.Namespace) -> int:
    library = build_shared_library(force=args.rebuild)
    engine = CEngine(library)
    games = []
    checksum = 0
    actions = 0
    for offset in range(args.games):
        seed = args.seed + offset
        result = engine.run_smoke_game(seed)
        games.append({"seed": seed, "actions": result.actions, "checksum": result.checksum})
        checksum ^= int(result.checksum)
        actions += int(result.actions)

    record = {
        "backend": "c-engine",
        "engine": asdict(engine.provenance()),
        "games": games,
        "aggregate": {
            "games": len(games),
            "actions": actions,
            "checksum_xor": checksum,
        },
    }
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def _path(value: str | None) -> Path | None:
    return Path(value) if value else None


def _layers(value: str) -> list[int]:
    layers = [int(item.strip()) for item in value.split(",") if item.strip()]
    if not layers:
        raise argparse.ArgumentTypeError("expected comma-separated hidden layer sizes")
    return layers


def _seats(value: str) -> list[int]:
    seats = [int(item.strip()) for item in value.split(",") if item.strip()]
    if any(seat < 0 or seat > 3 for seat in seats):
        raise argparse.ArgumentTypeError("training seats must be 0,1,2,3")
    return seats


def _emit(record: dict, record_history: bool) -> int:
    if record_history:
        append_history(record)
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def benchmark(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    write_current_experiment(
        {
            "kind": "policy_benchmark",
            "status": "running",
            "phase": "benchmark",
            "candidate_model": str(args.candidate),
            "baseline_model": str(args.baseline) if args.baseline else "heuristic",
            "progress": {"percent": 0.0, "completed_games": 0, "total_games": args.games_per_seat * 4},
        }
    )
    record = benchmark_candidate(
        engine,
        candidate_path=args.candidate,
        baseline_path=args.baseline,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
        bootstrap_samples=args.bootstrap_samples,
        min_win_delta=args.min_win_delta,
        min_rank_delta=args.min_rank_delta,
        min_margin_delta=args.min_margin_delta,
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        include_games=args.include_games,
    )
    record["engine"] = asdict(engine.provenance())
    write_current_experiment(
        {
            **record,
            "phase": "benchmark",
            "progress": {
                "percent": 1.0,
                "completed_games": record["total_games"],
                "total_games": record["total_games"],
            },
        }
    )
    return _emit(record, args.record)


def train(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    write_current_experiment(
        {
            "kind": "policy_training",
            "backend": "c-mlp",
            "status": "running",
            "phase": "training",
            "output_model": str(args.output),
            "start_model": str(args.start_model) if args.start_model else "scratch",
            "model": {"architecture": "mlp", "layers": args.layers},
            "training": {
                "episodes": args.episodes,
                "batch_size": args.batch_size,
                "seed": args.seed,
                "learning_rate": args.learning_rate,
                "optimizer": args.optimizer,
                "thread_count": args.thread_count,
            },
            "progress": {"completed_episodes": 0, "total_episodes": args.episodes, "percent": 0.0},
        }
    )
    record = train_c_mlp(
        engine,
        output_path=args.output,
        start_model_path=args.start_model,
        opponent_model_path=args.opponent_model,
        opponent_mode=args.opponent_mode,
        hidden_layers=args.layers,
        scratch_seed=args.scratch_seed,
        scratch_scale=args.scratch_scale,
        episodes=args.episodes,
        batch_size=args.batch_size,
        seed=args.seed,
        learning_rate=args.learning_rate,
        temperature=args.temperature,
        max_gradient_norm=args.max_gradient_norm,
        l2=args.l2,
        thread_count=args.thread_count,
        optimizer=args.optimizer,
        use_ppo=args.ppo,
        ppo_epochs=args.ppo_epochs,
        ppo_minibatch_size=args.ppo_minibatch_size,
        ppo_clip=args.ppo_clip,
        entropy_weight=args.entropy_weight,
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        paired_baseline=args.paired_baseline,
        training_seats=args.training_seats,
    )
    write_current_experiment(
        {
            **record,
            "phase": "training",
            "model": {"architecture": "mlp", "layers": args.layers},
            "progress": {"completed_episodes": args.episodes, "total_episodes": args.episodes, "percent": 1.0},
        }
    )
    return _emit(record, args.record)


def tournament(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = run_tournament(
        engine,
        model_paths=args.models,
        baseline_path=args.baseline,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def mine_seeds(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = mine_seed_panel(
        engine,
        candidate_path=args.candidate,
        baseline_path=args.baseline,
        start_seed=args.start_seed,
        seed_count=args.seed_count,
        games_per_seed=args.games_per_seed,
        top=args.top,
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def torch_parity_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = torch_parity(
        engine,
        model_path=args.model,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def torch_train_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = train_torch_policy(
        engine,
        start_model_path=args.start_model,
        output_path=args.output,
        architecture=args.architecture,
        layer_sizes=args.layers,
        scratch_seed=args.scratch_seed,
        scratch_scale=args.scratch_scale,
        episodes=args.episodes,
        batch_size=args.batch_size,
        seed=args.seed,
        learning_rate=args.learning_rate,
        temperature=args.temperature,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
        unbatched=args.unbatched,
        progress_callback=write_current_experiment,
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def torch_benchmark_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = torch_benchmark_candidate(
        engine,
        candidate_path=args.candidate,
        baseline_path=args.baseline,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
        bootstrap_samples=args.bootstrap_samples,
        min_win_delta=args.min_win_delta,
        min_rank_delta=args.min_rank_delta,
        min_margin_delta=args.min_margin_delta,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
        include_games=args.include_games,
        progress_callback=write_current_experiment,
    )
    record["engine"] = asdict(engine.provenance())
    write_current_experiment(
        {
            **record,
            "phase": "benchmark",
            "progress": {
                "percent": 1.0,
                "completed_games": record["total_games"],
                "total_games": record["total_games"],
            },
        }
    )
    return _emit(record, args.record)


def dashboard_command(args: argparse.Namespace) -> int:
    serve_dashboard(host=args.host, port=args.port)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog="kolkhoz-research")
    subparsers = parser.add_subparsers(dest="command", required=True)

    smoke = subparsers.add_parser("engine-smoke", help="run deterministic C-engine smoke games")
    smoke.add_argument("--games", type=int, default=8)
    smoke.add_argument("--seed", type=int, default=1_000_000)
    smoke.add_argument("--rebuild", action="store_true")
    smoke.set_defaults(func=engine_smoke)

    bench = subparsers.add_parser("benchmark", help="paired candidate-vs-baseline rotated-seat benchmark")
    bench.add_argument("--candidate", type=Path, required=True)
    bench.add_argument("--baseline", type=_path, default=None, help="baseline model; omit for heuristic baseline")
    bench.add_argument("--games-per-seat", type=int, default=32)
    bench.add_argument("--seed", type=int, default=13_500_000)
    bench.add_argument("--bootstrap-samples", type=int, default=1000)
    bench.add_argument("--min-win-delta", type=float, default=0.0)
    bench.add_argument("--min-rank-delta", type=float, default=0.0)
    bench.add_argument("--min-margin-delta", type=float, default=0.0)
    bench.add_argument("--round-curriculum", action="store_true")
    bench.add_argument("--round-plot-cards", type=int, default=6)
    bench.add_argument("--round-famine-rate", type=float, default=0.2)
    bench.add_argument("--include-games", action="store_true")
    bench.add_argument("--record", action="store_true")
    bench.add_argument("--rebuild", action="store_true")
    bench.set_defaults(func=benchmark)

    train_parser = subparsers.add_parser("train", help="train a C-backed MLP policy artifact")
    train_parser.add_argument("--output", type=Path, required=True)
    train_parser.add_argument("--start-model", type=_path, default=None)
    train_parser.add_argument("--opponent-model", type=_path, default=None)
    train_parser.add_argument("--opponent-mode", choices=["self-play", "heuristic", "model"], default="heuristic")
    train_parser.add_argument("--layers", type=_layers, default=[128, 128])
    train_parser.add_argument("--scratch-seed", type=int, default=1)
    train_parser.add_argument("--scratch-scale", type=float, default=0.05)
    train_parser.add_argument("--episodes", type=int, default=512)
    train_parser.add_argument("--batch-size", type=int, default=128)
    train_parser.add_argument("--seed", type=int, default=9_810_000)
    train_parser.add_argument("--learning-rate", type=float, default=0.01)
    train_parser.add_argument("--temperature", type=float, default=1.0)
    train_parser.add_argument("--max-gradient-norm", type=float, default=5.0)
    train_parser.add_argument("--l2", type=float, default=0.0)
    train_parser.add_argument("--thread-count", type=int, default=4)
    train_parser.add_argument("--optimizer", choices=["sgd", "adam"], default="adam")
    train_parser.add_argument("--ppo", action="store_true")
    train_parser.add_argument("--ppo-epochs", type=int, default=4)
    train_parser.add_argument("--ppo-minibatch-size", type=int, default=256)
    train_parser.add_argument("--ppo-clip", type=float, default=0.2)
    train_parser.add_argument("--entropy-weight", type=float, default=0.0)
    train_parser.add_argument("--round-curriculum", action="store_true")
    train_parser.add_argument("--round-plot-cards", type=int, default=6)
    train_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    train_parser.add_argument("--paired-baseline", action="store_true")
    train_parser.add_argument("--training-seats", type=_seats, default=[0, 1, 2, 3])
    train_parser.add_argument("--record", action="store_true")
    train_parser.add_argument("--rebuild", action="store_true")
    train_parser.set_defaults(func=train)

    tournament_parser = subparsers.add_parser("tournament", help="round-robin model-pool tournament")
    tournament_parser.add_argument("--models", type=Path, nargs="+", required=True)
    tournament_parser.add_argument("--baseline", type=_path, default=None)
    tournament_parser.add_argument("--games-per-seat", type=int, default=16)
    tournament_parser.add_argument("--seed", type=int, default=21_000_000)
    tournament_parser.add_argument("--record", action="store_true")
    tournament_parser.add_argument("--rebuild", action="store_true")
    tournament_parser.set_defaults(func=tournament)

    mine = subparsers.add_parser("mine-seeds", help="find hard seed panels for a candidate")
    mine.add_argument("--candidate", type=Path, required=True)
    mine.add_argument("--baseline", type=_path, default=None)
    mine.add_argument("--start-seed", type=int, default=31_000_000)
    mine.add_argument("--seed-count", type=int, default=16)
    mine.add_argument("--games-per-seed", type=int, default=4)
    mine.add_argument("--top", type=int, default=8)
    mine.add_argument("--record", action="store_true")
    mine.add_argument("--rebuild", action="store_true")
    mine.set_defaults(func=mine_seeds)

    torch_parity_parser = subparsers.add_parser("torch-parity", help="compare a Torch/MPS policy import against C MLP greedy evaluation")
    torch_parity_parser.add_argument("--model", type=Path, required=True)
    torch_parity_parser.add_argument("--games-per-seat", type=int, default=4)
    torch_parity_parser.add_argument("--seed", type=int, default=41_000_000)
    torch_parity_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_parity_parser.add_argument("--cpu", action="store_true", help="force CPU instead of MPS")
    torch_parity_parser.add_argument("--record", action="store_true")
    torch_parity_parser.add_argument("--rebuild", action="store_true")
    torch_parity_parser.set_defaults(func=torch_parity_command)

    torch_train_parser = subparsers.add_parser("torch-train", help="train a Torch policy with batched C-engine rollouts")
    torch_train_parser.add_argument("--start-model", type=_path, default=None)
    torch_train_parser.add_argument("--output", type=Path, required=True)
    torch_train_parser.add_argument("--architecture", choices=["mlp", "residual-mlp", "action-transformer"], default="mlp")
    torch_train_parser.add_argument("--layers", type=_layers, default=[512, 512])
    torch_train_parser.add_argument("--scratch-seed", type=int, default=1)
    torch_train_parser.add_argument("--scratch-scale", type=float, default=0.02)
    torch_train_parser.add_argument("--episodes", type=int, default=32)
    torch_train_parser.add_argument("--batch-size", type=int, default=8)
    torch_train_parser.add_argument("--seed", type=int, default=42_000_000)
    torch_train_parser.add_argument("--learning-rate", type=float, default=1e-4)
    torch_train_parser.add_argument("--temperature", type=float, default=1.0)
    torch_train_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_train_parser.add_argument("--unbatched", action="store_true", help="use the old one-game-at-a-time rollout path")
    torch_train_parser.add_argument("--cpu", action="store_true", help="force CPU instead of MPS")
    torch_train_parser.add_argument("--record", action="store_true")
    torch_train_parser.add_argument("--rebuild", action="store_true")
    torch_train_parser.set_defaults(func=torch_train_command)

    torch_bench_parser = subparsers.add_parser("torch-benchmark", help="paired benchmark for Torch .pt or C JSON policies")
    torch_bench_parser.add_argument("--candidate", type=Path, required=True)
    torch_bench_parser.add_argument("--baseline", type=_path, default=None, help="baseline model; omit for heuristic baseline")
    torch_bench_parser.add_argument("--games-per-seat", type=int, default=32)
    torch_bench_parser.add_argument("--seed", type=int, default=43_000_000)
    torch_bench_parser.add_argument("--bootstrap-samples", type=int, default=1000)
    torch_bench_parser.add_argument("--min-win-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--min-rank-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--min-margin-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_bench_parser.add_argument("--include-games", action="store_true")
    torch_bench_parser.add_argument("--cpu", action="store_true", help="force CPU instead of MPS")
    torch_bench_parser.add_argument("--record", action="store_true")
    torch_bench_parser.add_argument("--rebuild", action="store_true")
    torch_bench_parser.set_defaults(func=torch_benchmark_command)

    dashboard_parser = subparsers.add_parser("dashboard", help="serve the local research dashboard")
    dashboard_parser.add_argument("--host", default="127.0.0.1")
    dashboard_parser.add_argument("--port", type=int, default=8765)
    dashboard_parser.set_defaults(func=dashboard_command)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
