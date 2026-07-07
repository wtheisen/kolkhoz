from __future__ import annotations

import argparse
import json
import os
import shutil
from dataclasses import asdict
from pathlib import Path

from .artifact_cleanup import cleanup_artifacts
from .benchmark import benchmark_candidate, mine_seed_panel, run_tournament
from .c_engine import CEngine, build_shared_library
from .dashboard import serve_dashboard
from .history import append_history, write_current_experiment
from .masked_state_policy import train_masked_state_policy
from .online_server import SupabaseAuthVerifier, serve_online
from .online_store import PostgresOnlineSessionStore
from .torch_policy import (
    distill_action_transformer_policy,
    generate_supervised_trajectories,
    pretrain_torch_policy_from_trajectories,
    search_oracle_benchmark,
    trajectory_oracle_benchmark,
    torch_benchmark_candidate,
    torch_parity,
    train_torch_policy,
)
from .training import train_c_mlp


DEFAULT_CLEANUP_ROOTS = [Path("training/rl/runs"), Path("research/runs")]


def engine_smoke(args: argparse.Namespace) -> int:
    library = build_shared_library(force=args.rebuild)
    engine = CEngine(library)
    games = []
    checksum = 0
    actions = 0
    for offset in range(args.games):
        seed = args.seed + offset
        result = engine.run_smoke_game(seed)
        games.append(
            {"seed": seed, "actions": result.actions, "checksum": result.checksum}
        )
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


def _curriculum_rounds(value: str) -> list[int]:
    rounds = [int(item.strip()) for item in value.split(",") if item.strip()]
    if not rounds:
        raise argparse.ArgumentTypeError(
            "expected comma-separated curriculum round counts"
        )
    if any(item < 1 or item > 5 for item in rounds):
        raise argparse.ArgumentTypeError(
            "curriculum round counts must be between 1 and 5"
        )
    return rounds


def _phase_weights(value: str) -> dict[str, float]:
    weights: dict[str, float] = {}
    for item in value.split(","):
        if not item.strip():
            continue
        if "=" not in item:
            raise argparse.ArgumentTypeError(
                "phase weights must use phase=weight entries"
            )
        phase, raw_weight = item.split("=", 1)
        phase = phase.strip()
        if not phase:
            raise argparse.ArgumentTypeError("phase weight entry has no phase name")
        try:
            weight = float(raw_weight)
        except ValueError as error:
            raise argparse.ArgumentTypeError(
                f"invalid phase weight {raw_weight!r}"
            ) from error
        if weight < 0.0:
            raise argparse.ArgumentTypeError("phase weights must be non-negative")
        weights[phase] = weight
    return weights


def _emit(record: dict, record_history: bool) -> int:
    if record_history:
        append_history(record)
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def _current_experiment_callback(args: argparse.Namespace):
    return write_current_experiment if getattr(args, "record", False) else None


def _auto_cleanup_artifacts(args: argparse.Namespace) -> None:
    if getattr(args, "skip_cleanup_artifacts", False):
        return
    record = cleanup_artifacts(
        roots=DEFAULT_CLEANUP_ROOTS,
        keep_json_checkpoints=2,
        keep_torch_checkpoints=2,
        keep_latest_runs_per_experiment=1,
        protected_paths=[],
        delete=True,
        include_files=False,
    )
    print(json.dumps({"post_training_cleanup": record}, indent=2, sort_keys=True))


def _add_promotion_objective_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--promotion-objective",
        choices=["utility"],
        default="utility",
        help="promotion decision rule",
    )
    parser.add_argument("--promotion-utility-win-weight", type=float, default=1.0)
    parser.add_argument("--promotion-utility-rank-weight", type=float, default=0.05)
    parser.add_argument("--promotion-utility-margin-weight", type=float, default=0.001)
    parser.add_argument("--min-utility-delta", type=float, default=0.0)
    parser.add_argument("--candidate-pool-min-utility-delta", type=float, default=0.0)
    parser.add_argument("--risk-min-win-delta-mean", type=float, default=None)
    parser.add_argument("--risk-min-rank-delta-mean", type=float, default=None)
    parser.add_argument("--risk-min-margin-delta-mean", type=float, default=None)


def benchmark(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    if args.record:
        write_current_experiment(
            {
                "kind": "policy_benchmark",
                "status": "running",
                "phase": "benchmark",
                "candidate_model": str(args.candidate),
                "baseline_model": str(args.baseline) if args.baseline else "heuristic",
                "progress": {
                    "percent": 0.0,
                    "completed_games": 0,
                    "total_games": args.games_per_seat * 4,
                },
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
        promotion_min_games_per_seat=args.promotion_min_games_per_seat,
        promotion_min_bootstrap_samples=args.promotion_min_bootstrap_samples,
        promotion_objective=args.promotion_objective,
        promotion_utility_win_weight=args.promotion_utility_win_weight,
        promotion_utility_rank_weight=args.promotion_utility_rank_weight,
        promotion_utility_margin_weight=args.promotion_utility_margin_weight,
        min_utility_delta=args.min_utility_delta,
        candidate_pool_min_utility_delta=args.candidate_pool_min_utility_delta,
        risk_min_win_delta_mean=args.risk_min_win_delta_mean,
        risk_min_rank_delta_mean=args.risk_min_rank_delta_mean,
        risk_min_margin_delta_mean=args.risk_min_margin_delta_mean,
    )
    record["engine"] = asdict(engine.provenance())
    if args.record:
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
    if args.record:
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
                "progress": {
                    "completed_episodes": 0,
                    "total_episodes": args.episodes,
                    "percent": 0.0,
                },
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
    if args.record:
        write_current_experiment(
            {
                **record,
                "phase": "training",
                "model": {"architecture": "mlp", "layers": args.layers},
                "progress": {
                    "completed_episodes": args.episodes,
                    "total_episodes": args.episodes,
                    "percent": 1.0,
                },
            }
        )
    status = _emit(record, args.record)
    _auto_cleanup_artifacts(args)
    return status


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
    status = _emit(record, args.record)
    _auto_cleanup_artifacts(args)
    return status


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
    if args.serious_run:
        if args.reward_mode not in {
            "paired-baseline-delta",
            "paired-baseline-round-delta",
        }:
            raise SystemExit(
                "--serious-run requires --reward-mode paired-baseline-delta or paired-baseline-round-delta"
            )
        if args.eval_baseline is None:
            raise SystemExit("--serious-run requires --eval-baseline")
        if args.eval_interval <= 0:
            raise SystemExit("--serious-run requires --eval-interval > 0")
        if args.eval_games_per_seat <= 0:
            raise SystemExit("--serious-run requires --eval-games-per-seat > 0")
        if args.eval_seed is None:
            raise SystemExit("--serious-run requires --eval-seed")
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
        transformer_dropout=args.transformer_dropout,
        opponent_model_paths=args.opponent_model or [],
        opponent_mode=args.opponent_mode,
        opponent_schedule=args.opponent_schedule,
        win_weight=args.win_weight,
        rank_weight=args.rank_weight,
        margin_weight=args.margin_weight,
        reward_mode=args.reward_mode,
        reward_baseline_path=args.reward_baseline,
        round_rank_weight=args.round_rank_weight,
        round_margin_weight=args.round_margin_weight,
        two_round_rank_weight=args.two_round_rank_weight,
        two_round_margin_weight=args.two_round_margin_weight,
        reward_schedule=args.reward_schedule,
        early_win_weight=args.early_win_weight,
        early_rank_weight=args.early_rank_weight,
        early_margin_weight=args.early_margin_weight,
        late_win_weight=args.late_win_weight,
        late_rank_weight=args.late_rank_weight,
        late_margin_weight=args.late_margin_weight,
        advantage_mode=args.advantage_mode,
        policy_loss_reduction=args.policy_loss_reduction,
        use_ppo=args.ppo,
        ppo_epochs=args.ppo_epochs,
        ppo_minibatch_size=args.ppo_minibatch_size,
        ppo_clip=args.ppo_clip,
        value_loss_weight=args.value_loss_weight,
        entropy_weight=args.entropy_weight,
        reference_model_path=args.reference_model,
        reference_kl_weight=args.reference_kl_weight,
        eval_interval=args.eval_interval,
        eval_games_per_seat=args.eval_games_per_seat,
        eval_seed=args.eval_seed,
        eval_bootstrap_samples=args.eval_bootstrap_samples,
        eval_baseline_path=args.eval_baseline,
        eval_include_heuristic=args.eval_include_heuristic,
        select_best_eval_checkpoint=args.select_best_eval_checkpoint,
        eval_patience=args.eval_patience,
        round_curriculum=args.round_curriculum,
        curriculum_schedule=args.curriculum_schedule,
        curriculum_rounds=args.curriculum_rounds,
        scaled_curriculum_rounds=args.scaled_curriculum_rounds,
        mixed_curriculum_profile=args.mixed_curriculum_profile,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        unbatched=args.unbatched,
        record_eval_history=args.record,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def masked_state_train_command(args: argparse.Namespace) -> int:
    if args.round_curriculum:
        raise SystemExit(
            "masked-state-train does not support --round-curriculum yet; use full-game episodes"
        )
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = train_masked_state_policy(
        engine,
        output_path=args.output,
        start_model_path=args.start_model,
        layer_sizes=args.layers,
        scratch_seed=args.scratch_seed,
        scratch_scale=args.scratch_scale,
        episodes=args.episodes,
        batch_size=args.batch_size,
        seed=args.seed,
        learning_rate=args.learning_rate,
        temperature=args.temperature,
        prefer_mps=not args.cpu,
        ppo_epochs=args.ppo_epochs,
        ppo_minibatch_size=args.ppo_minibatch_size,
        ppo_clip=args.ppo_clip,
        value_loss_weight=args.value_loss_weight,
        entropy_weight=args.entropy_weight,
        eval_interval=args.eval_interval,
        eval_games_per_seat=args.eval_games_per_seat,
        eval_seed=args.eval_seed,
        round_curriculum=args.round_curriculum,
        curriculum_rounds=args.curriculum_rounds,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        record_history=args.record,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, False)


def supervised_generate_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = generate_supervised_trajectories(
        engine,
        output_path=args.output,
        games=args.games,
        seed=args.seed,
        input_size=args.input_size,
        seats=args.seats,
        max_search_actions=args.max_search_actions,
        rollout_action_limit=args.rollout_action_limit,
        rollout_model_path=args.rollout_model,
        rollout_sample=args.rollout_sample,
        rollout_temperature=args.rollout_temperature,
        rollouts_per_action=args.rollouts_per_action,
        determinize_search=args.determinize_search,
        search_horizon=args.search_horizon,
        search_target=args.search_target,
        target_temperature=args.search_temperature,
        min_search_q_margin=args.min_search_q_margin,
        min_search_q_std=args.min_search_q_std,
        skip_forced_targets=args.skip_forced_targets,
        win_weight=args.win_weight,
        rank_weight=args.rank_weight,
        margin_weight=args.margin_weight,
        prefer_mps=not args.cpu,
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        curriculum_rounds=args.curriculum_rounds,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    return _emit(record, args.record)


def supervised_pretrain_command(args: argparse.Namespace) -> int:
    record = pretrain_torch_policy_from_trajectories(
        trajectory_paths=args.trajectory,
        output_path=args.output,
        start_model_path=args.start_model,
        architecture=args.architecture,
        layer_sizes=args.layers,
        scratch_seed=args.scratch_seed,
        scratch_scale=args.scratch_scale,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        value_loss_weight=args.value_loss_weight,
        target_temperature=args.target_temperature,
        min_policy_q_margin=args.min_policy_q_margin,
        policy_confidence_scale=args.policy_confidence_scale,
        min_policy_weight=args.min_policy_weight,
        q_value_loss_weight=args.q_value_loss_weight,
        phase_sample_weights=args.phase_sample_weights,
        limit_states=args.limit_states,
        prefer_mps=not args.cpu,
        transformer_dropout=args.transformer_dropout,
        progress_callback=_current_experiment_callback(args),
    )
    return _emit(record, args.record)


def torch_distill_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = distill_action_transformer_policy(
        engine,
        teacher_model_path=args.teacher,
        output_path=args.output,
        layer_sizes=args.layers,
        scratch_seed=args.scratch_seed,
        scratch_scale=args.scratch_scale,
        states=args.states,
        batch_size=args.batch_size,
        seed=args.seed,
        learning_rate=args.learning_rate,
        distill_temperature=args.distill_temperature,
        forced_action_weight=args.distill_forced_action_weight,
        swap_weight=args.distill_swap_weight,
        play_weight=args.distill_play_weight,
        assignment_weight=args.distill_assignment_weight,
        high_candidate_weight=args.distill_high_candidate_weight,
        high_candidate_threshold=args.distill_high_candidate_threshold,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
        progress_callback=_current_experiment_callback(args),
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
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        include_games=args.include_games,
        promotion_min_games_per_seat=args.promotion_min_games_per_seat,
        promotion_min_bootstrap_samples=args.promotion_min_bootstrap_samples,
        promotion_objective=args.promotion_objective,
        promotion_utility_win_weight=args.promotion_utility_win_weight,
        promotion_utility_rank_weight=args.promotion_utility_rank_weight,
        promotion_utility_margin_weight=args.promotion_utility_margin_weight,
        min_utility_delta=args.min_utility_delta,
        candidate_pool_min_utility_delta=args.candidate_pool_min_utility_delta,
        risk_min_win_delta_mean=args.risk_min_win_delta_mean,
        risk_min_rank_delta_mean=args.risk_min_rank_delta_mean,
        risk_min_margin_delta_mean=args.risk_min_margin_delta_mean,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    if args.record:
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


def _dedupe_paths(paths: list[Path]) -> list[Path]:
    seen: set[str] = set()
    result: list[Path] = []
    for path in paths:
        key = os.fspath(path)
        if key in seen:
            continue
        seen.add(key)
        result.append(path)
    return result


def self_play_improve_command(args: argparse.Namespace) -> int:
    if args.generations <= 0:
        raise SystemExit("--generations must be positive")
    if args.episodes_per_generation <= 0:
        raise SystemExit("--episodes-per-generation must be positive")
    if args.benchmark_games_per_seat <= 0:
        raise SystemExit("--benchmark-games-per-seat must be positive")
    if args.reward_mode not in {
        "paired-baseline-delta",
        "paired-baseline-round-delta",
    }:
        raise SystemExit(
            "self-play improvement requires paired-baseline reward mode"
        )

    engine = CEngine(build_shared_library(force=args.rebuild))
    args.run_dir.mkdir(parents=True, exist_ok=True)
    promoted_best_path = args.run_dir / "best.pt"
    seed_best_path = args.run_dir / f"seed_best{args.start_model.suffix or '.model'}"
    current_best_path = seed_best_path
    if current_best_path.exists() and not args.overwrite_best:
        raise SystemExit(
            f"{current_best_path} already exists; pass --overwrite-best to replace it"
        )
    if promoted_best_path.exists() and not args.overwrite_best:
        raise SystemExit(
            f"{promoted_best_path} already exists; pass --overwrite-best to replace it"
        )
    shutil.copyfile(args.start_model, current_best_path)

    promoted_pool: list[Path] = [current_best_path]
    if args.opponent_model:
        promoted_pool.extend(args.opponent_model)
    promoted_pool = _dedupe_paths(promoted_pool)

    generations: list[dict] = []
    status = "completed"
    stopped_reason: str | None = None

    def write_loop_current(
        *,
        phase: str,
        generation: int,
        extra: dict | None = None,
    ) -> None:
        if not args.record:
            return
        payload = {
            "kind": "self_play_improvement_loop",
            "status": "running",
            "phase": phase,
            "run_dir": str(args.run_dir),
            "start_model": str(args.start_model),
            "current_best_model": str(current_best_path),
            "generation": generation,
            "generations": args.generations,
            "promoted_count": sum(1 for item in generations if item.get("promoted")),
            "completed_generations": len(generations),
            "progress": {
                "completed_generations": len(generations),
                "total_generations": args.generations,
                "percent": min(1.0, len(generations) / max(1, args.generations)),
            },
            "latest_generation": generations[-1] if generations else None,
        }
        if extra:
            payload.update(extra)
        write_current_experiment(payload)

    write_loop_current(phase="starting", generation=0)

    for generation in range(1, args.generations + 1):
        generation_dir = args.run_dir / f"generation_{generation:03d}"
        generation_dir.mkdir(parents=True, exist_ok=True)
        challenger_path = generation_dir / "candidate.pt"
        train_seed = args.seed + (generation - 1) * args.seed_stride
        benchmark_seed = args.benchmark_seed + (generation - 1) * args.seed_stride
        baseline_path = current_best_path
        opponent_pool = _dedupe_paths([baseline_path, *promoted_pool])

        def training_progress(update: dict) -> None:
            if not args.record:
                return
            write_current_experiment(
                {
                    **update,
                    "kind": "self_play_improvement_loop",
                    "loop_phase": "training",
                    "phase": "training",
                    "run_dir": str(args.run_dir),
                    "generation": generation,
                    "generations": args.generations,
                    "current_best_model": str(baseline_path),
                    "candidate_model": str(challenger_path),
                    "completed_generations": len(generations),
                    "latest_generation": generations[-1] if generations else None,
                }
            )

        train_record = train_torch_policy(
            engine,
            start_model_path=baseline_path,
            output_path=challenger_path,
            architecture=args.architecture,
            layer_sizes=args.layers,
            scratch_seed=args.scratch_seed + generation - 1,
            scratch_scale=args.scratch_scale,
            episodes=args.episodes_per_generation,
            batch_size=args.batch_size,
            seed=train_seed,
            learning_rate=args.learning_rate,
            temperature=args.temperature,
            prefer_mps=not args.cpu,
            rollout_envs=args.rollout_envs,
            transformer_dropout=args.transformer_dropout,
            opponent_model_paths=opponent_pool,
            opponent_mode="model-pool",
            opponent_schedule=args.opponent_schedule,
            win_weight=args.win_weight,
            rank_weight=args.rank_weight,
            margin_weight=args.margin_weight,
            reward_mode=args.reward_mode,
            reward_baseline_path=baseline_path,
            round_rank_weight=args.round_rank_weight,
            round_margin_weight=args.round_margin_weight,
            two_round_rank_weight=args.two_round_rank_weight,
            two_round_margin_weight=args.two_round_margin_weight,
            reward_schedule=args.reward_schedule,
            early_win_weight=args.early_win_weight,
            early_rank_weight=args.early_rank_weight,
            early_margin_weight=args.early_margin_weight,
            late_win_weight=args.late_win_weight,
            late_rank_weight=args.late_rank_weight,
            late_margin_weight=args.late_margin_weight,
            advantage_mode=args.advantage_mode,
            policy_loss_reduction=args.policy_loss_reduction,
            use_ppo=True,
            ppo_epochs=args.ppo_epochs,
            ppo_minibatch_size=args.ppo_minibatch_size,
            ppo_clip=args.ppo_clip,
            value_loss_weight=args.value_loss_weight,
            entropy_weight=args.entropy_weight,
            reference_model_path=baseline_path if args.reference_kl_weight > 0 else None,
            reference_kl_weight=args.reference_kl_weight,
            eval_interval=args.eval_interval,
            eval_games_per_seat=args.eval_games_per_seat,
            eval_seed=args.eval_seed + (generation - 1) * args.seed_stride,
            eval_bootstrap_samples=args.eval_bootstrap_samples,
            eval_baseline_path=baseline_path,
            eval_include_heuristic=args.eval_include_heuristic,
            select_best_eval_checkpoint=args.select_best_eval_checkpoint,
            eval_patience=args.eval_patience,
            round_curriculum=args.round_curriculum,
            curriculum_schedule=args.curriculum_schedule,
            curriculum_rounds=args.curriculum_rounds,
            scaled_curriculum_rounds=args.scaled_curriculum_rounds,
            mixed_curriculum_profile=args.mixed_curriculum_profile,
            round_plot_cards=args.round_plot_cards,
            round_famine_rate=args.round_famine_rate,
            unbatched=args.unbatched,
            record_eval_history=args.record,
            reinitialize_architecture=args.reinitialize_architecture,
            progress_callback=training_progress,
        )
        train_record["engine"] = asdict(engine.provenance())
        train_path = generation_dir / "training.json"
        train_path.write_text(
            json.dumps(train_record, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        def benchmark_progress(update: dict) -> None:
            if not args.record:
                return
            write_current_experiment(
                {
                    **update,
                    "kind": "self_play_improvement_loop",
                    "loop_phase": "benchmark",
                    "phase": "benchmark",
                    "run_dir": str(args.run_dir),
                    "generation": generation,
                    "generations": args.generations,
                    "current_best_model": str(baseline_path),
                    "candidate_model": str(challenger_path),
                    "completed_generations": len(generations),
                    "latest_generation": generations[-1] if generations else None,
                }
            )

        benchmark_record = torch_benchmark_candidate(
            engine,
            candidate_path=challenger_path,
            baseline_path=baseline_path,
            games_per_seat=args.benchmark_games_per_seat,
            seed=benchmark_seed,
            bootstrap_samples=args.benchmark_bootstrap_samples,
            min_win_delta=args.min_win_delta,
            min_rank_delta=args.min_rank_delta,
            min_margin_delta=args.min_margin_delta,
            prefer_mps=not args.cpu,
            rollout_envs=args.benchmark_rollout_envs,
            round_curriculum=args.benchmark_round_curriculum,
            round_plot_cards=args.round_plot_cards,
            round_famine_rate=args.round_famine_rate,
            include_games=args.include_games,
            promotion_min_games_per_seat=args.promotion_min_games_per_seat,
            promotion_min_bootstrap_samples=args.promotion_min_bootstrap_samples,
            promotion_objective=args.promotion_objective,
            promotion_utility_win_weight=args.promotion_utility_win_weight,
            promotion_utility_rank_weight=args.promotion_utility_rank_weight,
            promotion_utility_margin_weight=args.promotion_utility_margin_weight,
            min_utility_delta=args.min_utility_delta,
            candidate_pool_min_utility_delta=args.candidate_pool_min_utility_delta,
            risk_min_win_delta_mean=args.risk_min_win_delta_mean,
            risk_min_rank_delta_mean=args.risk_min_rank_delta_mean,
            risk_min_margin_delta_mean=args.risk_min_margin_delta_mean,
            progress_callback=benchmark_progress,
        )
        benchmark_record["engine"] = asdict(engine.provenance())
        benchmark_path = generation_dir / "benchmark.json"
        benchmark_path.write_text(
            json.dumps(benchmark_record, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        promoted = bool(benchmark_record.get("evidence", {}).get("promotion_eligible"))
        if args.promote_on_selection and benchmark_record.get("status") in {
            "passed_selection_gate",
            "passed_promotion_gate",
        }:
            promoted = True
        if promoted:
            shutil.copyfile(challenger_path, promoted_best_path)
            current_best_path = challenger_path
            promoted_pool.append(challenger_path)
            promoted_pool = _dedupe_paths(promoted_pool)

        generation_record = {
            "generation": generation,
            "seed": train_seed,
            "benchmark_seed": benchmark_seed,
            "start_model": str(baseline_path),
            "candidate_model": str(challenger_path),
            "training_record": str(train_path),
            "benchmark_record": str(benchmark_path),
            "benchmark_status": benchmark_record.get("status"),
            "promoted": promoted,
            "summary": benchmark_record.get("summary"),
            "intervals": benchmark_record.get("intervals"),
            "early_stop": train_record.get("early_stop"),
        }
        generations.append(generation_record)
        append_history(
            {
                "kind": "self_play_improvement_generation",
                "run_dir": str(args.run_dir),
                **generation_record,
            }
        )
        write_loop_current(phase="generation_complete", generation=generation)

        if (
            not promoted
            and args.stop_on_rejection
            and benchmark_record.get("status") == "rejected"
        ):
            status = "stopped"
            stopped_reason = "rejected"
            break

    record = {
        "kind": "self_play_improvement_loop",
        "status": status,
        "stopped_reason": stopped_reason,
        "run_dir": str(args.run_dir),
        "start_model": str(args.start_model),
        "best_model": str(
            promoted_best_path if promoted_best_path.exists() else current_best_path
        ),
        "generations": generations,
        "requested_generations": args.generations,
        "completed_generations": len(generations),
        "promoted_count": sum(1 for item in generations if item.get("promoted")),
        "training": {
            "episodes_per_generation": args.episodes_per_generation,
            "batch_size": args.batch_size,
            "rollout_envs": args.rollout_envs,
            "reward_mode": args.reward_mode,
            "opponent_schedule": args.opponent_schedule,
            "ppo_epochs": args.ppo_epochs,
            "ppo_minibatch_size": args.ppo_minibatch_size,
            "ppo_clip": args.ppo_clip,
            "reference_kl_weight": args.reference_kl_weight,
        },
        "benchmark": {
            "games_per_seat": args.benchmark_games_per_seat,
            "bootstrap_samples": args.benchmark_bootstrap_samples,
            "min_win_delta": args.min_win_delta,
            "min_rank_delta": args.min_rank_delta,
            "min_margin_delta": args.min_margin_delta,
            "promotion_min_games_per_seat": args.promotion_min_games_per_seat,
            "promotion_min_bootstrap_samples": args.promotion_min_bootstrap_samples,
            "promote_on_selection": args.promote_on_selection,
            "promotion_objective": args.promotion_objective,
            "promotion_utility_weights": {
                "win": args.promotion_utility_win_weight,
                "rank": args.promotion_utility_rank_weight,
                "margin": args.promotion_utility_margin_weight,
            },
            "min_utility_delta": args.min_utility_delta,
            "candidate_pool_min_utility_delta": args.candidate_pool_min_utility_delta,
            "risk_budgets": {
                "min_win_delta_mean": args.risk_min_win_delta_mean,
                "min_rank_delta_mean": args.risk_min_rank_delta_mean,
                "min_margin_delta_mean": args.risk_min_margin_delta_mean,
            },
        },
        "engine": asdict(engine.provenance()),
    }
    summary_path = args.run_dir / "self_play_improvement.json"
    summary_path.write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if args.record:
        write_current_experiment(
            {
                **record,
                "phase": "complete",
                "progress": {
                    "completed_generations": len(generations),
                    "total_generations": args.generations,
                    "percent": min(1.0, len(generations) / max(1, args.generations)),
                },
            }
        )
    return _emit(record, args.record)


def trajectory_oracle_benchmark_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = trajectory_oracle_benchmark(
        engine,
        trajectory_paths=args.trajectory,
        baseline_path=args.baseline,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
        bootstrap_samples=args.bootstrap_samples,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
        input_size=args.input_size,
        oracle_all_seats=args.oracle_all_seats,
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        include_games=args.include_games,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    if args.record:
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


def search_oracle_benchmark_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    record = search_oracle_benchmark(
        engine,
        baseline_path=args.baseline,
        games_per_seat=args.games_per_seat,
        seed=args.seed,
        bootstrap_samples=args.bootstrap_samples,
        prefer_mps=not args.cpu,
        rollout_envs=args.rollout_envs,
        input_size=args.input_size,
        oracle_all_seats=args.oracle_all_seats,
        max_search_actions=args.max_search_actions,
        rollout_action_limit=args.rollout_action_limit,
        rollouts_per_action=args.rollouts_per_action,
        determinize_search=args.determinize_search,
        search_horizon=args.search_horizon,
        search_target=args.search_target,
        target_temperature=args.search_temperature,
        win_weight=args.win_weight,
        rank_weight=args.rank_weight,
        margin_weight=args.margin_weight,
        round_curriculum=args.round_curriculum,
        round_plot_cards=args.round_plot_cards,
        round_famine_rate=args.round_famine_rate,
        curriculum_rounds=args.curriculum_rounds,
        include_games=args.include_games,
        progress_callback=_current_experiment_callback(args),
    )
    record["engine"] = asdict(engine.provenance())
    if args.record:
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
    serve_dashboard(
        host=args.host, port=args.port, username=args.username, password=args.password
    )
    return 0


def serve_online_command(args: argparse.Namespace) -> int:
    engine = CEngine(build_shared_library(force=args.rebuild))
    database_url = args.database_url or os.environ.get("KOLKHOZ_ONLINE_DATABASE_URL")
    store = PostgresOnlineSessionStore(database_url) if database_url else None
    serve_online(
        host=args.host,
        port=args.port,
        engine=engine,
        store=store,
        auth_verifier=SupabaseAuthVerifier.from_environment(),
    )
    return 0


def cleanup_artifacts_command(args: argparse.Namespace) -> int:
    roots = args.root or DEFAULT_CLEANUP_ROOTS
    record = cleanup_artifacts(
        roots=roots,
        keep_json_checkpoints=args.keep_json_checkpoints,
        keep_torch_checkpoints=args.keep_torch_checkpoints,
        keep_latest_runs_per_experiment=args.keep_latest_runs_per_experiment,
        protected_paths=args.protect,
        delete=args.delete,
        include_files=args.include_files,
    )
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog="kolkhoz-research")
    subparsers = parser.add_subparsers(dest="command", required=True)

    smoke = subparsers.add_parser(
        "engine-smoke", help="run deterministic C-engine smoke games"
    )
    smoke.add_argument("--games", type=int, default=8)
    smoke.add_argument("--seed", type=int, default=1_000_000)
    smoke.add_argument("--rebuild", action="store_true")
    smoke.set_defaults(func=engine_smoke)

    bench = subparsers.add_parser(
        "benchmark", help="paired candidate-vs-baseline rotated-seat benchmark"
    )
    bench.add_argument("--candidate", type=Path, required=True)
    bench.add_argument(
        "--baseline",
        type=_path,
        default=None,
        help="baseline model; omit for heuristic baseline",
    )
    bench.add_argument("--games-per-seat", type=int, default=32)
    bench.add_argument("--seed", type=int, default=13_500_000)
    bench.add_argument("--bootstrap-samples", type=int, default=1000)
    bench.add_argument("--min-win-delta", type=float, default=0.0)
    bench.add_argument("--min-rank-delta", type=float, default=0.0)
    bench.add_argument("--min-margin-delta", type=float, default=0.0)
    bench.add_argument(
        "--round-curriculum",
        action="store_true",
        help="benchmark on two-round curriculum episodes; famine can only occur in the second round",
    )
    bench.add_argument("--round-plot-cards", type=int, default=6)
    bench.add_argument("--round-famine-rate", type=float, default=0.2)
    bench.add_argument("--include-games", action="store_true")
    bench.add_argument("--promotion-min-games-per-seat", type=int, default=64)
    bench.add_argument("--promotion-min-bootstrap-samples", type=int, default=1000)
    _add_promotion_objective_args(bench)
    bench.add_argument("--record", action="store_true")
    bench.add_argument("--rebuild", action="store_true")
    bench.set_defaults(func=benchmark)

    train_parser = subparsers.add_parser(
        "train", help="train a C-backed MLP policy artifact"
    )
    train_parser.add_argument("--output", type=Path, required=True)
    train_parser.add_argument("--start-model", type=_path, default=None)
    train_parser.add_argument("--opponent-model", type=_path, default=None)
    train_parser.add_argument(
        "--opponent-mode",
        choices=["self-play", "heuristic", "model"],
        default="heuristic",
    )
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
    train_parser.add_argument(
        "--round-curriculum",
        action="store_true",
        help="train on two-round curriculum episodes; famine can only occur in the second round",
    )
    train_parser.add_argument("--round-plot-cards", type=int, default=6)
    train_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    train_parser.add_argument("--paired-baseline", action="store_true")
    train_parser.add_argument("--training-seats", type=_seats, default=[0, 1, 2, 3])
    train_parser.add_argument("--record", action="store_true")
    train_parser.add_argument("--rebuild", action="store_true")
    train_parser.add_argument(
        "--skip-cleanup-artifacts",
        action="store_true",
        help="do not prune stale local checkpoints after successful training",
    )
    train_parser.set_defaults(func=train)

    tournament_parser = subparsers.add_parser(
        "tournament", help="round-robin model-pool tournament"
    )
    tournament_parser.add_argument("--models", type=Path, nargs="+", required=True)
    tournament_parser.add_argument("--baseline", type=_path, default=None)
    tournament_parser.add_argument("--games-per-seat", type=int, default=16)
    tournament_parser.add_argument("--seed", type=int, default=21_000_000)
    tournament_parser.add_argument("--record", action="store_true")
    tournament_parser.add_argument("--rebuild", action="store_true")
    tournament_parser.set_defaults(func=tournament)

    mine = subparsers.add_parser(
        "mine-seeds", help="find hard seed panels for a candidate"
    )
    mine.add_argument("--candidate", type=Path, required=True)
    mine.add_argument("--baseline", type=_path, default=None)
    mine.add_argument("--start-seed", type=int, default=31_000_000)
    mine.add_argument("--seed-count", type=int, default=16)
    mine.add_argument("--games-per-seed", type=int, default=4)
    mine.add_argument("--top", type=int, default=8)
    mine.add_argument("--record", action="store_true")
    mine.add_argument("--rebuild", action="store_true")
    mine.set_defaults(func=mine_seeds)

    torch_parity_parser = subparsers.add_parser(
        "torch-parity",
        help="compare a Torch/MPS policy import against C MLP greedy evaluation",
    )
    torch_parity_parser.add_argument("--model", type=Path, required=True)
    torch_parity_parser.add_argument("--games-per-seat", type=int, default=4)
    torch_parity_parser.add_argument("--seed", type=int, default=41_000_000)
    torch_parity_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_parity_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    torch_parity_parser.add_argument("--record", action="store_true")
    torch_parity_parser.add_argument("--rebuild", action="store_true")
    torch_parity_parser.set_defaults(func=torch_parity_command)

    torch_train_parser = subparsers.add_parser(
        "torch-train", help="train a Torch policy with batched C-engine rollouts"
    )
    torch_train_parser.add_argument("--start-model", type=_path, default=None)
    torch_train_parser.add_argument("--output", type=Path, required=True)
    torch_train_parser.add_argument(
        "--architecture",
        choices=[
            "mlp",
            "residual-mlp",
            "residual-layernorm-mlp",
            "action-transformer",
        ],
        default="mlp",
    )
    torch_train_parser.add_argument("--layers", type=_layers, default=[512, 512])
    torch_train_parser.add_argument("--scratch-seed", type=int, default=1)
    torch_train_parser.add_argument("--scratch-scale", type=float, default=0.02)
    torch_train_parser.add_argument("--episodes", type=int, default=32)
    torch_train_parser.add_argument("--batch-size", type=int, default=8)
    torch_train_parser.add_argument("--seed", type=int, default=42_000_000)
    torch_train_parser.add_argument("--learning-rate", type=float, default=1e-4)
    torch_train_parser.add_argument("--temperature", type=float, default=1.0)
    torch_train_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_train_parser.add_argument(
        "--transformer-dropout",
        type=float,
        default=None,
        help="override action-transformer encoder dropout for this run",
    )
    torch_train_parser.add_argument(
        "--opponent-mode",
        choices=["heuristic", "self-play", "model-pool"],
        default="heuristic",
    )
    torch_train_parser.add_argument(
        "--opponent-schedule",
        choices=["constant", "weak-to-baseline"],
        default="constant",
    )
    torch_train_parser.add_argument(
        "--opponent-model",
        type=Path,
        action="append",
        help="baseline/model-pool opponent; repeat for multiple models",
    )
    torch_train_parser.add_argument("--win-weight", type=float, default=1.0)
    torch_train_parser.add_argument("--rank-weight", type=float, default=0.1)
    torch_train_parser.add_argument("--margin-weight", type=float, default=0.005)
    torch_train_parser.add_argument(
        "--reward-mode",
        choices=["absolute", "paired-baseline-delta", "paired-baseline-round-delta"],
        default="absolute",
    )
    torch_train_parser.add_argument(
        "--reward-baseline",
        type=_path,
        default=None,
        help="baseline model for paired-baseline-delta reward; defaults to eval baseline or first opponent model",
    )
    torch_train_parser.add_argument("--round-rank-weight", type=float, default=0.10)
    torch_train_parser.add_argument("--round-margin-weight", type=float, default=0.002)
    torch_train_parser.add_argument("--two-round-rank-weight", type=float, default=0.15)
    torch_train_parser.add_argument(
        "--two-round-margin-weight", type=float, default=0.003
    )
    torch_train_parser.add_argument(
        "--reward-schedule", choices=["constant", "staged"], default="constant"
    )
    torch_train_parser.add_argument("--early-win-weight", type=float, default=None)
    torch_train_parser.add_argument("--early-rank-weight", type=float, default=0.2)
    torch_train_parser.add_argument("--early-margin-weight", type=float, default=0.01)
    torch_train_parser.add_argument("--late-win-weight", type=float, default=None)
    torch_train_parser.add_argument("--late-rank-weight", type=float, default=0.03)
    torch_train_parser.add_argument("--late-margin-weight", type=float, default=0.001)
    torch_train_parser.add_argument(
        "--advantage-mode",
        choices=["curriculum", "batch", "none"],
        default="curriculum",
    )
    torch_train_parser.add_argument(
        "--policy-loss-reduction",
        choices=["episode-mean", "episode-sum", "episode-sqrt", "action-mean"],
        default="episode-mean",
    )
    torch_train_parser.add_argument(
        "--ppo",
        action="store_true",
        help="use PPO clipped multi-epoch updates for Torch policy training",
    )
    torch_train_parser.add_argument("--ppo-epochs", type=int, default=4)
    torch_train_parser.add_argument("--ppo-minibatch-size", type=int, default=256)
    torch_train_parser.add_argument("--ppo-clip", type=float, default=0.2)
    torch_train_parser.add_argument("--value-loss-weight", type=float, default=0.5)
    torch_train_parser.add_argument("--entropy-weight", type=float, default=0.01)
    torch_train_parser.add_argument(
        "--reference-model",
        type=_path,
        default=None,
        help="frozen policy for KL regularization; defaults to start model when reference KL weight is positive",
    )
    torch_train_parser.add_argument("--reference-kl-weight", type=float, default=0.0)
    torch_train_parser.add_argument(
        "--eval-interval",
        type=int,
        default=0,
        help="run a paired full-game eval every N completed training episodes; 0 disables",
    )
    torch_train_parser.add_argument("--eval-games-per-seat", type=int, default=8)
    torch_train_parser.add_argument("--eval-seed", type=int, default=52_000_000)
    torch_train_parser.add_argument("--eval-bootstrap-samples", type=int, default=500)
    torch_train_parser.add_argument(
        "--eval-baseline",
        type=Path,
        default=None,
        help="baseline for periodic full-game eval; defaults to the first opponent model or heuristic",
    )
    torch_train_parser.add_argument(
        "--eval-include-heuristic",
        action="store_true",
        help="also run each periodic eval against the built-in heuristic opponent",
    )
    torch_train_parser.add_argument(
        "--select-best-eval-checkpoint",
        action="store_true",
        help="save the best current-best eval checkpoint as the output model instead of the final checkpoint",
    )
    torch_train_parser.add_argument(
        "--eval-patience",
        type=int,
        default=0,
        help="stop after this many non-improving primary evals; 0 disables",
    )
    torch_train_parser.add_argument(
        "--serious-run",
        action="store_true",
        help="require paired reward plus periodic paired full-game eval settings",
    )
    torch_train_parser.add_argument(
        "--round-curriculum",
        action="store_true",
        help="train on two-round curriculum episodes; famine can only occur in the second round",
    )
    torch_train_parser.add_argument(
        "--curriculum-schedule",
        choices=["constant", "scaled", "mixed"],
        default="constant",
    )
    torch_train_parser.add_argument(
        "--curriculum-rounds",
        type=int,
        default=2,
        help="round count for constant round curriculum; 5 means full game",
    )
    torch_train_parser.add_argument(
        "--scaled-curriculum-rounds", type=_curriculum_rounds, default=[2, 3, 4, 5]
    )
    torch_train_parser.add_argument(
        "--mixed-curriculum-profile",
        choices=["default", "full-game-heavy"],
        default="default",
    )
    torch_train_parser.add_argument("--round-plot-cards", type=int, default=6)
    torch_train_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    torch_train_parser.add_argument(
        "--unbatched",
        action="store_true",
        help="use the old one-game-at-a-time rollout path",
    )
    torch_train_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    torch_train_parser.add_argument("--record", action="store_true")
    torch_train_parser.add_argument("--rebuild", action="store_true")
    torch_train_parser.add_argument(
        "--skip-cleanup-artifacts",
        action="store_true",
        help="do not prune stale local checkpoints after successful training",
    )
    torch_train_parser.set_defaults(func=torch_train_command)

    masked_state_parser = subparsers.add_parser(
        "masked-state-train",
        help="train a board-state policy with masked fixed-action PPO",
    )
    masked_state_parser.add_argument("--start-model", type=_path, default=None)
    masked_state_parser.add_argument("--output", type=Path, required=True)
    masked_state_parser.add_argument("--layers", type=_layers, default=[256, 256])
    masked_state_parser.add_argument("--scratch-seed", type=int, default=1)
    masked_state_parser.add_argument("--scratch-scale", type=float, default=0.02)
    masked_state_parser.add_argument("--episodes", type=int, default=32)
    masked_state_parser.add_argument("--batch-size", type=int, default=8)
    masked_state_parser.add_argument("--seed", type=int, default=92_000_000)
    masked_state_parser.add_argument("--learning-rate", type=float, default=1e-4)
    masked_state_parser.add_argument("--temperature", type=float, default=1.0)
    masked_state_parser.add_argument("--ppo-epochs", type=int, default=4)
    masked_state_parser.add_argument("--ppo-minibatch-size", type=int, default=256)
    masked_state_parser.add_argument("--ppo-clip", type=float, default=0.2)
    masked_state_parser.add_argument("--value-loss-weight", type=float, default=0.5)
    masked_state_parser.add_argument("--entropy-weight", type=float, default=0.01)
    masked_state_parser.add_argument("--eval-interval", type=int, default=0)
    masked_state_parser.add_argument("--eval-games-per-seat", type=int, default=4)
    masked_state_parser.add_argument("--eval-seed", type=int, default=93_000_000)
    masked_state_parser.add_argument("--round-curriculum", action="store_true")
    masked_state_parser.add_argument("--curriculum-rounds", type=int, default=2)
    masked_state_parser.add_argument("--round-plot-cards", type=int, default=6)
    masked_state_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    masked_state_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    masked_state_parser.add_argument("--record", action="store_true")
    masked_state_parser.add_argument("--rebuild", action="store_true")
    masked_state_parser.set_defaults(func=masked_state_train_command)

    self_play_parser = subparsers.add_parser(
        "self-play-improve",
        help="run a policy-improvement loop with train, paired benchmark, and promotion",
    )
    self_play_parser.add_argument("--start-model", type=Path, required=True)
    self_play_parser.add_argument("--run-dir", type=Path, required=True)
    self_play_parser.add_argument("--generations", type=int, default=3)
    self_play_parser.add_argument("--episodes-per-generation", type=int, default=4096)
    self_play_parser.add_argument("--seed", type=int, default=72_000_000)
    self_play_parser.add_argument("--seed-stride", type=int, default=100_000)
    self_play_parser.add_argument(
        "--architecture",
        choices=[
            "mlp",
            "residual-mlp",
            "residual-layernorm-mlp",
            "action-transformer",
        ],
        default="action-transformer",
    )
    self_play_parser.add_argument(
        "--reinitialize-architecture",
        action="store_true",
        help="build the requested architecture from --start-model instead of resuming its checkpoint architecture",
    )
    self_play_parser.add_argument("--layers", type=_layers, default=[192, 4, 4, 768])
    self_play_parser.add_argument("--scratch-seed", type=int, default=1)
    self_play_parser.add_argument("--scratch-scale", type=float, default=0.02)
    self_play_parser.add_argument("--batch-size", type=int, default=32)
    self_play_parser.add_argument("--learning-rate", type=float, default=8e-5)
    self_play_parser.add_argument("--temperature", type=float, default=1.0)
    self_play_parser.add_argument("--rollout-envs", type=int, default=32)
    self_play_parser.add_argument("--transformer-dropout", type=float, default=0.05)
    self_play_parser.add_argument(
        "--opponent-model",
        type=Path,
        action="append",
        help="extra fixed opponent for the pool; repeatable",
    )
    self_play_parser.add_argument(
        "--opponent-schedule",
        choices=["constant", "weak-to-baseline"],
        default="constant",
    )
    self_play_parser.add_argument("--win-weight", type=float, default=1.0)
    self_play_parser.add_argument("--rank-weight", type=float, default=0.05)
    self_play_parser.add_argument("--margin-weight", type=float, default=0.001)
    self_play_parser.add_argument(
        "--reward-mode",
        choices=["paired-baseline-delta", "paired-baseline-round-delta"],
        default="paired-baseline-round-delta",
    )
    self_play_parser.add_argument("--round-rank-weight", type=float, default=0.10)
    self_play_parser.add_argument("--round-margin-weight", type=float, default=0.002)
    self_play_parser.add_argument("--two-round-rank-weight", type=float, default=0.15)
    self_play_parser.add_argument(
        "--two-round-margin-weight", type=float, default=0.003
    )
    self_play_parser.add_argument(
        "--reward-schedule", choices=["constant", "staged"], default="staged"
    )
    self_play_parser.add_argument("--early-win-weight", type=float, default=None)
    self_play_parser.add_argument("--early-rank-weight", type=float, default=0.2)
    self_play_parser.add_argument("--early-margin-weight", type=float, default=0.01)
    self_play_parser.add_argument("--late-win-weight", type=float, default=None)
    self_play_parser.add_argument("--late-rank-weight", type=float, default=0.03)
    self_play_parser.add_argument("--late-margin-weight", type=float, default=0.001)
    self_play_parser.add_argument(
        "--advantage-mode",
        choices=["curriculum", "batch", "none"],
        default="curriculum",
    )
    self_play_parser.add_argument(
        "--policy-loss-reduction",
        choices=["episode-mean", "episode-sum", "episode-sqrt", "action-mean"],
        default="episode-mean",
    )
    self_play_parser.add_argument("--ppo-epochs", type=int, default=4)
    self_play_parser.add_argument("--ppo-minibatch-size", type=int, default=128)
    self_play_parser.add_argument("--ppo-clip", type=float, default=0.2)
    self_play_parser.add_argument("--value-loss-weight", type=float, default=0.5)
    self_play_parser.add_argument("--entropy-weight", type=float, default=0.01)
    self_play_parser.add_argument("--reference-kl-weight", type=float, default=0.01)
    self_play_parser.add_argument("--eval-interval", type=int, default=1024)
    self_play_parser.add_argument("--eval-games-per-seat", type=int, default=4)
    self_play_parser.add_argument("--eval-seed", type=int, default=73_000_000)
    self_play_parser.add_argument("--eval-bootstrap-samples", type=int, default=500)
    self_play_parser.add_argument("--eval-include-heuristic", action="store_true")
    self_play_parser.add_argument("--select-best-eval-checkpoint", action="store_true")
    self_play_parser.add_argument("--eval-patience", type=int, default=0)
    self_play_parser.add_argument("--round-curriculum", action="store_true")
    self_play_parser.add_argument(
        "--curriculum-schedule",
        choices=["constant", "scaled", "mixed"],
        default="mixed",
    )
    self_play_parser.add_argument("--curriculum-rounds", type=int, default=2)
    self_play_parser.add_argument(
        "--scaled-curriculum-rounds", type=_curriculum_rounds, default=[2, 3, 4, 5]
    )
    self_play_parser.add_argument(
        "--mixed-curriculum-profile",
        choices=["default", "full-game-heavy"],
        default="full-game-heavy",
    )
    self_play_parser.add_argument("--round-plot-cards", type=int, default=6)
    self_play_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    self_play_parser.add_argument("--unbatched", action="store_true")
    self_play_parser.add_argument("--benchmark-games-per-seat", type=int, default=32)
    self_play_parser.add_argument("--benchmark-seed", type=int, default=74_000_000)
    self_play_parser.add_argument("--benchmark-bootstrap-samples", type=int, default=1000)
    self_play_parser.add_argument("--benchmark-rollout-envs", type=int, default=64)
    self_play_parser.add_argument("--benchmark-round-curriculum", action="store_true")
    self_play_parser.add_argument("--min-win-delta", type=float, default=0.0)
    self_play_parser.add_argument("--min-rank-delta", type=float, default=0.0)
    self_play_parser.add_argument("--min-margin-delta", type=float, default=0.0)
    self_play_parser.add_argument("--promotion-min-games-per-seat", type=int, default=64)
    self_play_parser.add_argument(
        "--promotion-min-bootstrap-samples", type=int, default=1000
    )
    _add_promotion_objective_args(self_play_parser)
    self_play_parser.add_argument(
        "--promote-on-selection",
        action="store_true",
        help="allow promotion when the benchmark passes but has selection-grade evidence",
    )
    self_play_parser.add_argument("--stop-on-rejection", action="store_true")
    self_play_parser.add_argument("--include-games", action="store_true")
    self_play_parser.add_argument("--overwrite-best", action="store_true")
    self_play_parser.add_argument("--cpu", action="store_true")
    self_play_parser.add_argument("--record", action="store_true")
    self_play_parser.add_argument("--rebuild", action="store_true")
    self_play_parser.set_defaults(func=self_play_improve_command)

    supervised_generate_parser = subparsers.add_parser(
        "supervised-generate",
        help="generate legal C-engine supervised trajectories with rollout-search soft targets",
    )
    supervised_generate_parser.add_argument("--output", type=Path, required=True)
    supervised_generate_parser.add_argument("--games", type=int, default=8)
    supervised_generate_parser.add_argument("--seed", type=int, default=61_000_000)
    supervised_generate_parser.add_argument("--input-size", type=int, default=200)
    supervised_generate_parser.add_argument(
        "--seats", type=_seats, default=[0, 1, 2, 3]
    )
    supervised_generate_parser.add_argument("--max-search-actions", type=int, default=8)
    supervised_generate_parser.add_argument(
        "--rollout-action-limit", type=int, default=512
    )
    supervised_generate_parser.add_argument(
        "--rollout-model",
        type=_path,
        default=None,
        help="policy used to continue searched lines and as paired-target baseline; omit for heuristic",
    )
    supervised_generate_parser.add_argument(
        "--rollout-sample",
        action="store_true",
        help="sample rollout-model continuations instead of taking greedy actions",
    )
    supervised_generate_parser.add_argument(
        "--rollout-temperature", type=float, default=1.0
    )
    supervised_generate_parser.add_argument(
        "--rollouts-per-action", type=int, default=1
    )
    supervised_generate_parser.add_argument(
        "--no-determinize-search",
        action="store_false",
        dest="determinize_search",
        help="roll out from the true hidden state instead of sampled information-set completions",
    )
    supervised_generate_parser.set_defaults(determinize_search=True)
    supervised_generate_parser.add_argument(
        "--search-horizon",
        choices=["end-trick", "end-year", "full-game"],
        default="full-game",
    )
    supervised_generate_parser.add_argument(
        "--search-target",
        choices=["absolute", "paired-baseline"],
        default="paired-baseline",
    )
    supervised_generate_parser.add_argument(
        "--search-temperature",
        type=float,
        default=0.25,
        help="temperature used to serialize target_policy from searched q_values",
    )
    supervised_generate_parser.add_argument(
        "--min-search-q-margin",
        type=float,
        default=0.0,
        help="omit supervised records whose searched best-vs-second q margin is lower than this",
    )
    supervised_generate_parser.add_argument(
        "--min-search-q-std",
        type=float,
        default=0.0,
        help="omit supervised records whose searched q-value standard deviation is lower than this",
    )
    supervised_generate_parser.add_argument(
        "--skip-forced-targets",
        action="store_true",
        help="omit one-legal-action states from the supervised dataset",
    )
    supervised_generate_parser.add_argument("--win-weight", type=float, default=1.0)
    supervised_generate_parser.add_argument("--rank-weight", type=float, default=0.05)
    supervised_generate_parser.add_argument(
        "--margin-weight", type=float, default=0.001
    )
    supervised_generate_parser.add_argument("--round-curriculum", action="store_true")
    supervised_generate_parser.add_argument("--curriculum-rounds", type=int, default=5)
    supervised_generate_parser.add_argument("--round-plot-cards", type=int, default=6)
    supervised_generate_parser.add_argument(
        "--round-famine-rate", type=float, default=0.2
    )
    supervised_generate_parser.add_argument("--cpu", action="store_true")
    supervised_generate_parser.add_argument("--record", action="store_true")
    supervised_generate_parser.add_argument("--rebuild", action="store_true")
    supervised_generate_parser.set_defaults(func=supervised_generate_command)

    supervised_pretrain_parser = subparsers.add_parser(
        "supervised-pretrain",
        help="pretrain a Torch policy/value head from supervised trajectory JSONL",
    )
    supervised_pretrain_parser.add_argument(
        "--trajectory", type=Path, action="append", required=True
    )
    supervised_pretrain_parser.add_argument("--output", type=Path, required=True)
    supervised_pretrain_parser.add_argument("--start-model", type=_path, default=None)
    supervised_pretrain_parser.add_argument(
        "--architecture",
        choices=[
            "mlp",
            "residual-mlp",
            "residual-layernorm-mlp",
            "action-transformer",
        ],
        default="action-transformer",
    )
    supervised_pretrain_parser.add_argument(
        "--layers", type=_layers, default=[256, 4, 4, 1024]
    )
    supervised_pretrain_parser.add_argument("--scratch-seed", type=int, default=61)
    supervised_pretrain_parser.add_argument("--scratch-scale", type=float, default=0.02)
    supervised_pretrain_parser.add_argument("--epochs", type=int, default=3)
    supervised_pretrain_parser.add_argument("--batch-size", type=int, default=64)
    supervised_pretrain_parser.add_argument("--learning-rate", type=float, default=3e-4)
    supervised_pretrain_parser.add_argument(
        "--value-loss-weight", type=float, default=0.1
    )
    supervised_pretrain_parser.add_argument(
        "--target-temperature",
        type=float,
        default=0.25,
        help="temperature for softmaxing trajectory q_values during pretraining",
    )
    supervised_pretrain_parser.add_argument(
        "--min-policy-q-margin",
        type=float,
        default=0.0,
        help="ignore soft policy labels whose top-two q_values differ by less than this margin",
    )
    supervised_pretrain_parser.add_argument(
        "--policy-confidence-scale",
        type=float,
        default=0.05,
        help="q-margin span needed for full policy-label weight; <=0 disables confidence scaling",
    )
    supervised_pretrain_parser.add_argument(
        "--min-policy-weight",
        type=float,
        default=0.0,
        help="minimum policy-label weight for nonzero-margin soft targets",
    )
    supervised_pretrain_parser.add_argument(
        "--q-value-loss-weight",
        type=float,
        default=0.0,
        help="optional action-score regression weight toward centered q_value logits",
    )
    supervised_pretrain_parser.add_argument(
        "--phase-sample-weights",
        type=_phase_weights,
        default=None,
        help="comma-separated phase=weight sampling weights, e.g. assignment=2.0,trick=1.25",
    )
    supervised_pretrain_parser.add_argument("--limit-states", type=int, default=None)
    supervised_pretrain_parser.add_argument(
        "--transformer-dropout", type=float, default=None
    )
    supervised_pretrain_parser.add_argument("--cpu", action="store_true")
    supervised_pretrain_parser.add_argument("--record", action="store_true")
    supervised_pretrain_parser.set_defaults(func=supervised_pretrain_command)

    torch_distill_parser = subparsers.add_parser(
        "torch-distill",
        help="distill a C/MLP policy into an action-transformer checkpoint",
    )
    torch_distill_parser.add_argument("--teacher", type=Path, required=True)
    torch_distill_parser.add_argument("--output", type=Path, required=True)
    torch_distill_parser.add_argument(
        "--layers", type=_layers, default=[256, 4, 4, 1024]
    )
    torch_distill_parser.add_argument("--scratch-seed", type=int, default=1)
    torch_distill_parser.add_argument("--scratch-scale", type=float, default=0.02)
    torch_distill_parser.add_argument("--states", type=int, default=65536)
    torch_distill_parser.add_argument("--batch-size", type=int, default=64)
    torch_distill_parser.add_argument("--seed", type=int, default=57_600_000)
    torch_distill_parser.add_argument("--learning-rate", type=float, default=3e-4)
    torch_distill_parser.add_argument("--distill-temperature", type=float, default=1.0)
    torch_distill_parser.add_argument(
        "--distill-forced-action-weight", type=float, default=1.0
    )
    torch_distill_parser.add_argument("--distill-swap-weight", type=float, default=1.0)
    torch_distill_parser.add_argument("--distill-play-weight", type=float, default=1.0)
    torch_distill_parser.add_argument(
        "--distill-assignment-weight", type=float, default=1.0
    )
    torch_distill_parser.add_argument(
        "--distill-high-candidate-weight", type=float, default=1.0
    )
    torch_distill_parser.add_argument(
        "--distill-high-candidate-threshold", type=int, default=5
    )
    torch_distill_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_distill_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    torch_distill_parser.add_argument("--record", action="store_true")
    torch_distill_parser.add_argument("--rebuild", action="store_true")
    torch_distill_parser.set_defaults(func=torch_distill_command)

    torch_bench_parser = subparsers.add_parser(
        "torch-benchmark", help="paired benchmark for Torch .pt or C JSON policies"
    )
    torch_bench_parser.add_argument("--candidate", type=Path, required=True)
    torch_bench_parser.add_argument(
        "--baseline",
        type=_path,
        default=None,
        help="baseline model; omit for heuristic baseline",
    )
    torch_bench_parser.add_argument("--games-per-seat", type=int, default=32)
    torch_bench_parser.add_argument("--seed", type=int, default=43_000_000)
    torch_bench_parser.add_argument("--bootstrap-samples", type=int, default=1000)
    torch_bench_parser.add_argument("--min-win-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--min-rank-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--min-margin-delta", type=float, default=0.0)
    torch_bench_parser.add_argument("--rollout-envs", type=int, default=64)
    torch_bench_parser.add_argument(
        "--round-curriculum",
        action="store_true",
        help="benchmark on two-round curriculum episodes; famine can only occur in the second round",
    )
    torch_bench_parser.add_argument("--round-plot-cards", type=int, default=6)
    torch_bench_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    torch_bench_parser.add_argument("--include-games", action="store_true")
    torch_bench_parser.add_argument(
        "--promotion-min-games-per-seat", type=int, default=64
    )
    torch_bench_parser.add_argument(
        "--promotion-min-bootstrap-samples", type=int, default=1000
    )
    _add_promotion_objective_args(torch_bench_parser)
    torch_bench_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    torch_bench_parser.add_argument("--record", action="store_true")
    torch_bench_parser.add_argument("--rebuild", action="store_true")
    torch_bench_parser.set_defaults(func=torch_benchmark_command)

    oracle_bench_parser = subparsers.add_parser(
        "trajectory-oracle-benchmark",
        help="benchmark a table oracle that plays stored supervised target actions on matching states",
    )
    oracle_bench_parser.add_argument(
        "--trajectory", type=Path, action="append", required=True
    )
    oracle_bench_parser.add_argument(
        "--baseline",
        type=_path,
        default=None,
        help="fallback/opponent model; omit for heuristic",
    )
    oracle_bench_parser.add_argument("--games-per-seat", type=int, default=64)
    oracle_bench_parser.add_argument("--seed", type=int, default=62_100_000)
    oracle_bench_parser.add_argument("--bootstrap-samples", type=int, default=1000)
    oracle_bench_parser.add_argument("--rollout-envs", type=int, default=64)
    oracle_bench_parser.add_argument("--input-size", type=int, default=200)
    oracle_bench_parser.add_argument(
        "--oracle-all-seats",
        action="store_true",
        help="apply the trajectory oracle to every player, matching how trajectories were generated",
    )
    oracle_bench_parser.add_argument("--round-curriculum", action="store_true")
    oracle_bench_parser.add_argument("--round-plot-cards", type=int, default=6)
    oracle_bench_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    oracle_bench_parser.add_argument("--include-games", action="store_true")
    oracle_bench_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    oracle_bench_parser.add_argument("--record", action="store_true")
    oracle_bench_parser.add_argument("--rebuild", action="store_true")
    oracle_bench_parser.set_defaults(func=trajectory_oracle_benchmark_command)

    search_oracle_parser = subparsers.add_parser(
        "search-oracle-benchmark",
        help="benchmark live one-ply rollout-search target selection during play",
    )
    search_oracle_parser.add_argument(
        "--baseline",
        type=_path,
        default=None,
        help="fallback/opponent/paired-baseline model; omit for heuristic",
    )
    search_oracle_parser.add_argument("--games-per-seat", type=int, default=4)
    search_oracle_parser.add_argument("--seed", type=int, default=62_100_000)
    search_oracle_parser.add_argument("--bootstrap-samples", type=int, default=1000)
    search_oracle_parser.add_argument("--rollout-envs", type=int, default=16)
    search_oracle_parser.add_argument("--input-size", type=int, default=200)
    search_oracle_parser.add_argument(
        "--oracle-all-seats",
        action="store_true",
        help="apply search oracle to every player; otherwise only the benchmark seat",
    )
    search_oracle_parser.add_argument("--max-search-actions", type=int, default=12)
    search_oracle_parser.add_argument("--rollout-action-limit", type=int, default=512)
    search_oracle_parser.add_argument("--rollouts-per-action", type=int, default=2)
    search_oracle_parser.add_argument(
        "--no-determinize-search",
        action="store_false",
        dest="determinize_search",
    )
    search_oracle_parser.set_defaults(determinize_search=True)
    search_oracle_parser.add_argument(
        "--search-horizon",
        choices=["end-trick", "end-year", "full-game"],
        default="full-game",
    )
    search_oracle_parser.add_argument(
        "--search-target",
        choices=["absolute", "paired-baseline"],
        default="paired-baseline",
    )
    search_oracle_parser.add_argument("--search-temperature", type=float, default=0.2)
    search_oracle_parser.add_argument("--win-weight", type=float, default=1.0)
    search_oracle_parser.add_argument("--rank-weight", type=float, default=0.05)
    search_oracle_parser.add_argument("--margin-weight", type=float, default=0.001)
    search_oracle_parser.add_argument("--round-curriculum", action="store_true")
    search_oracle_parser.add_argument("--curriculum-rounds", type=int, default=5)
    search_oracle_parser.add_argument("--round-plot-cards", type=int, default=6)
    search_oracle_parser.add_argument("--round-famine-rate", type=float, default=0.2)
    search_oracle_parser.add_argument("--include-games", action="store_true")
    search_oracle_parser.add_argument(
        "--cpu", action="store_true", help="force CPU instead of MPS"
    )
    search_oracle_parser.add_argument("--record", action="store_true")
    search_oracle_parser.add_argument("--rebuild", action="store_true")
    search_oracle_parser.set_defaults(func=search_oracle_benchmark_command)

    dashboard_parser = subparsers.add_parser(
        "dashboard", help="serve the local research dashboard"
    )
    dashboard_parser.add_argument("--host", default="127.0.0.1")
    dashboard_parser.add_argument("--port", type=int, default=8765)
    dashboard_parser.add_argument(
        "--username", default=os.environ.get("KOLKHOZ_DASHBOARD_USERNAME", "kolkhoz")
    )
    dashboard_parser.add_argument(
        "--password", default=os.environ.get("KOLKHOZ_DASHBOARD_PASSWORD")
    )
    dashboard_parser.set_defaults(func=dashboard_command)

    online_parser = subparsers.add_parser(
        "serve-online", help="serve C-engine online sessions for Flutter clients"
    )
    online_parser.add_argument("--host", default="0.0.0.0")
    online_parser.add_argument("--port", type=int, default=8787)
    online_parser.add_argument("--rebuild", action="store_true")
    online_parser.add_argument(
        "--database-url",
        default=None,
        help=(
            "optional Supabase/Postgres connection string; defaults to "
            "KOLKHOZ_ONLINE_DATABASE_URL"
        ),
    )
    online_parser.set_defaults(func=serve_online_command)

    cleanup_parser = subparsers.add_parser(
        "cleanup-artifacts", help="dry-run or delete stale local training checkpoints"
    )
    cleanup_parser.add_argument("--root", type=Path, action="append", default=None)
    cleanup_parser.add_argument(
        "--keep-json-checkpoints",
        type=int,
        default=2,
        help="latest candidate_e*.json snapshots to keep per run",
    )
    cleanup_parser.add_argument(
        "--keep-torch-checkpoints",
        type=int,
        default=2,
        help="latest/best Torch checkpoints to keep per run",
    )
    cleanup_parser.add_argument(
        "--keep-latest-runs-per-experiment",
        type=int,
        default=1,
        help="keep every checkpoint from the latest N run directories in each experiment family",
    )
    cleanup_parser.add_argument(
        "--protect",
        type=Path,
        action="append",
        default=[],
        help="extra model/checkpoint path to preserve; repeatable",
    )
    cleanup_parser.add_argument(
        "--include-files",
        action="store_true",
        help="include every selected file in the JSON output",
    )
    cleanup_parser.add_argument(
        "--delete", action="store_true", help="delete selected files; omit for dry-run"
    )
    cleanup_parser.set_defaults(func=cleanup_artifacts_command)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
