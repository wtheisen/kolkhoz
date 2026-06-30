#!/usr/bin/env python3
"""Generate Kolkhoz AI training and benchmark visualizations.

The numbers here mirror training/rl/EXPERIMENTS.md. Keep this script boring and
explicit so regenerated charts are easy to audit against the logged runs.
"""

from pathlib import Path
import json

import matplotlib.pyplot as plt
import numpy as np


OUT_DIR = Path(__file__).resolve().parent / "visualizations"
HISTORY_PATH = Path(__file__).resolve().parent / "runs" / "policy_training_stats_probe_history.json"
SCRATCH_HISTORY_PATH = Path(__file__).resolve().parent / "runs" / "policy_training_scratch_probe_history.json"
MODEL_COLOR = "#2f6f9f"
HEURISTIC_COLOR = "#d9822b"
CONTROL_COLOR = "#8a8f98"
PASS_COLOR = "#2f8f5b"
FAIL_COLOR = "#b43d3d"
GRID_COLOR = "#d8dde6"


def save(fig: plt.Figure, name: str) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(OUT_DIR / name, dpi=180, bbox_inches="tight")
    plt.close(fig)


def interval_errors(rows, key: str) -> np.ndarray:
    means = np.array([row[key] for row in rows])
    lows = np.array([row[f"{key}_low"] for row in rows])
    highs = np.array([row[f"{key}_high"] for row in rows])
    return np.vstack([means - lows, highs - means])


def style_axis(ax, title: str, ylabel: str | None = None) -> None:
    ax.set_title(title, fontsize=13, fontweight="bold", pad=12)
    if ylabel:
        ax.set_ylabel(ylabel)
    ax.grid(axis="y", color=GRID_COLOR, linewidth=0.8, alpha=0.9)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def full_game_winrates() -> None:
    rows = [
        {
            "label": "Promoted\nseed 11100000",
            "model_top": 0.6200,
            "heuristic_top": 0.2742,
            "model_strict": 0.6002,
            "heuristic_strict": 0.2492,
            "gate": "pass",
        },
        {
            "label": "Random control\nseed 11100000",
            "model_top": 0.2482,
            "heuristic_top": 0.2742,
            "model_strict": 0.2233,
            "heuristic_strict": 0.2492,
            "gate": "fail",
        },
        {
            "label": "Promoted\nseed 12100000",
            "model_top": 0.6188,
            "heuristic_top": 0.2705,
            "model_strict": 0.6000,
            "heuristic_strict": 0.2412,
            "gate": "pass",
        },
    ]
    x = np.arange(len(rows))
    width = 0.34
    fig, ax = plt.subplots(figsize=(10, 5.4))
    ax.bar(x - width / 2, [r["model_strict"] for r in rows], width, label="Model strict win", color=MODEL_COLOR)
    ax.bar(
        x + width / 2,
        [r["heuristic_strict"] for r in rows],
        width,
        label="Heuristic strict win",
        color=HEURISTIC_COLOR,
    )
    for index, row in enumerate(rows):
        marker_color = PASS_COLOR if row["gate"] == "pass" else FAIL_COLOR
        ax.text(index, 0.70, row["gate"].upper(), ha="center", va="center", color=marker_color, fontweight="bold")
    ax.set_xticks(x)
    ax.set_xticklabels([r["label"] for r in rows])
    ax.set_ylim(0, 0.76)
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=2)
    style_axis(ax, "Full-Game Strict Win Rates", "Strict win rate")
    save(fig, "full_game_strict_winrates.png")


def full_game_deltas() -> None:
    rows = [
        {
            "label": "Promoted\n11100000",
            "top": 0.3458,
            "top_low": 0.3254,
            "top_high": 0.3661,
            "strict": 0.3510,
            "strict_low": 0.3309,
            "strict_high": 0.3711,
            "rank": 0.7298,
            "rank_low": 0.6821,
            "rank_high": 0.7774,
            "margin": 13.7673,
            "margin_low": 13.1025,
            "margin_high": 14.4320,
        },
        {
            "label": "Random\n11100000",
            "top": -0.0260,
            "top_low": -0.0449,
            "top_high": -0.0071,
            "strict": -0.0260,
            "strict_low": -0.0443,
            "strict_high": -0.0077,
            "rank": -0.1040,
            "rank_low": -0.1522,
            "rank_high": -0.0558,
            "margin": -0.8167,
            "margin_low": -1.3105,
            "margin_high": -0.3230,
        },
        {
            "label": "Promoted\n12100000",
            "top": 0.3483,
            "top_low": 0.3281,
            "top_high": 0.3684,
            "strict": 0.3588,
            "strict_low": 0.3387,
            "strict_high": 0.3788,
            "rank": 0.7430,
            "rank_low": 0.6957,
            "rank_high": 0.7903,
            "margin": 13.7643,
            "margin_low": 13.1161,
            "margin_high": 14.4124,
        },
    ]
    x = np.arange(len(rows))
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.5))
    metrics = [
        ("strict", "Strict Win Delta", "win-rate points"),
        ("rank", "Rank Delta", "rank positions"),
        ("margin", "Margin Delta", "score margin"),
    ]
    for ax, (key, title, ylabel) in zip(axes, metrics):
        colors = [MODEL_COLOR, CONTROL_COLOR, MODEL_COLOR]
        ax.axhline(0, color="#333333", linewidth=1)
        ax.errorbar(
            x,
            [row[key] for row in rows],
            yerr=interval_errors(rows, key),
            fmt="none",
            ecolor="#333333",
            elinewidth=1.5,
            capsize=5,
        )
        ax.bar(x, [row[key] for row in rows], color=colors, width=0.58)
        ax.set_xticks(x)
        ax.set_xticklabels([row["label"] for row in rows], fontsize=9)
        style_axis(ax, title, ylabel)
    fig.suptitle("Paired Full-Game Deltas vs Same-Seed Heuristic Baseline", fontsize=14, fontweight="bold")
    save(fig, "full_game_metric_deltas.png")


def architecture_comparison() -> None:
    rows = [
        {
            "label": "h48\nseed44",
            "candidate": 0.6350,
            "heuristic": 0.2950,
            "delta": 0.3400,
            "delta_low": 0.2742,
            "delta_high": 0.4058,
        },
        {
            "label": "h48\nseed33",
            "candidate": 0.6075,
            "heuristic": 0.2950,
            "delta": 0.3125,
            "delta_low": 0.2467,
            "delta_high": 0.3783,
        },
        {
            "label": "h64\nseed55",
            "candidate": 0.5725,
            "heuristic": 0.2950,
            "delta": 0.2775,
            "delta_low": 0.2131,
            "delta_high": 0.3419,
        },
        {
            "label": "h96\nseed22",
            "candidate": 0.5775,
            "heuristic": 0.2950,
            "delta": 0.2825,
            "delta_low": 0.2176,
            "delta_high": 0.3474,
        },
    ]
    x = np.arange(len(rows))
    fig, ax = plt.subplots(figsize=(9.5, 5.2))
    ax.bar(x, [row["candidate"] for row in rows], color=MODEL_COLOR, width=0.58, label="Candidate win rate")
    ax.plot(x, [row["heuristic"] for row in rows], color=HEURISTIC_COLOR, marker="o", linewidth=2.5, label="Heuristic baseline")
    ax.errorbar(
        x,
        [row["delta"] for row in rows],
        yerr=interval_errors(rows, "delta"),
        fmt="none",
        ecolor="#333333",
        capsize=5,
        label="Win delta 95% CI",
    )
    ax.set_xticks(x)
    ax.set_xticklabels([row["label"] for row in rows])
    ax.set_ylim(0, 0.74)
    ax.legend(frameon=False, loc="upper right")
    style_axis(ax, "Architecture Sweep Win Rates", "Win rate")
    save(fig, "architecture_winrates.png")


def weakest_seat() -> None:
    rows = [
        {"seed": "11100000", "candidate": 0.4840, "heuristic": 0.2520, "delta": 0.2320, "low": 0.1913, "high": 0.2727},
        {"seed": "12100000", "candidate": 0.4880, "heuristic": 0.2460, "delta": 0.2420, "low": 0.2009, "high": 0.2831},
    ]
    x = np.arange(len(rows))
    width = 0.34
    fig, ax = plt.subplots(figsize=(8.2, 5))
    ax.bar(x - width / 2, [row["candidate"] for row in rows], width, color=MODEL_COLOR, label="Model strict win")
    ax.bar(x + width / 2, [row["heuristic"] for row in rows], width, color=HEURISTIC_COLOR, label="Heuristic strict win")
    for index, row in enumerate(rows):
        y = max(row["candidate"], row["heuristic"]) + 0.045
        ax.errorbar(index, y, yerr=[[row["delta"] - row["low"]], [row["high"] - row["delta"]]], fmt="o", color="#333333", capsize=5)
        ax.text(index, y + 0.035, f"delta {row['delta']:.3f}", ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels([f"Seat 3\nseed {row['seed']}" for row in rows])
    ax.set_ylim(0, 0.62)
    ax.legend(frameon=False, loc="upper right")
    style_axis(ax, "Weakest Seat Still Beats Heuristic", "Strict win rate")
    save(fig, "weakest_seat_strict_winrates.png")


def training_progress_proxy() -> None:
    rows = [
        {"label": "Random\ncontrol", "strict": 0.2233, "rank_delta": -0.1040, "margin_delta": -0.8167, "gate": "fail"},
        {"label": "Architecture\nbest h48", "strict": 0.6002, "rank_delta": 0.7298, "margin_delta": 13.7673, "gate": "pass"},
        {"label": "Promoted\nfresh seed", "strict": 0.6000, "rank_delta": 0.7430, "margin_delta": 13.7643, "gate": "pass"},
    ]
    fig, ax1 = plt.subplots(figsize=(9, 5.2))
    x = np.arange(len(rows))
    ax1.plot(x, [row["strict"] for row in rows], color=MODEL_COLOR, marker="o", linewidth=3, label="Strict win rate")
    ax1.set_ylabel("Strict win rate", color=MODEL_COLOR)
    ax1.tick_params(axis="y", labelcolor=MODEL_COLOR)
    ax1.set_ylim(0, 0.72)
    ax2 = ax1.twinx()
    ax2.plot(x, [row["margin_delta"] for row in rows], color=PASS_COLOR, marker="s", linewidth=2.5, label="Margin delta")
    ax2.axhline(0, color="#333333", linewidth=1)
    ax2.set_ylabel("Score margin delta", color=PASS_COLOR)
    ax2.tick_params(axis="y", labelcolor=PASS_COLOR)
    ax1.set_xticks(x)
    ax1.set_xticklabels([row["label"] for row in rows])
    style_axis(ax1, "Training Outcome Proxy", None)
    lines = ax1.get_lines() + ax2.get_lines()
    ax1.legend(lines, [line.get_label() for line in lines], frameon=False, loc="upper left")
    save(fig, "training_outcome_proxy.png")


def plot_training_reward_history(history_path: Path, output_name: str, title: str) -> None:
    if not history_path.exists():
        return

    events = json.loads(history_path.read_text())
    x = np.arange(len(events))
    scores = np.array([event["score"] for event in events])
    accepted_points = [(i, event) for i, event in enumerate(events) if event["prefix"] == "accepted"]
    validation_points = [(i, event) for i, event in enumerate(events) if event["prefix"] == "validation"]
    parent_points = [(i, event) for i, event in enumerate(events) if event["prefix"] == "parent"]
    candidate_points = [(i, event) for i, event in enumerate(events) if event["prefix"] == "evaluated"]
    best_so_far = np.maximum.accumulate(
        [event["score"] if event["prefix"] in {"baseline", "accepted", "final"} else -1e9 for event in events]
    )
    last_best = events[0]["score"]
    for i, value in enumerate(best_so_far):
        if value < -1e8:
            best_so_far[i] = last_best
        else:
            last_best = value

    fig, ax = plt.subplots(figsize=(12, 5.5))
    if candidate_points:
        ax.scatter(
            [i for i, _ in candidate_points],
            [event["score"] for _, event in candidate_points],
            color=CONTROL_COLOR,
            alpha=0.55,
            s=26,
            label="Mutated candidates",
        )
    if parent_points:
        ax.scatter(
            [i for i, _ in parent_points],
            [event["score"] for _, event in parent_points],
            color=HEURISTIC_COLOR,
            s=42,
            label="Parent on generation seed",
        )
    if validation_points:
        ax.scatter(
            [i for i, _ in validation_points],
            [event["score"] for _, event in validation_points],
            color="#6a4c93",
            s=48,
            label="Validation",
        )
    if accepted_points:
        ax.scatter(
            [i for i, _ in accepted_points],
            [event["score"] for _, event in accepted_points],
            color=PASS_COLOR,
            marker="*",
            s=160,
            label="Accepted best",
            zorder=4,
        )
    ax.plot(x, best_so_far, color=MODEL_COLOR, linewidth=2.5, label="Accepted reward best-so-far")
    ax.set_xlabel("Evaluation step")
    style_axis(ax, title, "Reward score")
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=3)
    save(fig, output_name)


def plot_training_components_history(history_path: Path, output_name: str, title: str) -> None:
    if not history_path.exists():
        return

    events = json.loads(history_path.read_text())
    accepted_like = [event for event in events if event["prefix"] in {"baseline", "accepted", "final"}]
    x = np.arange(len(accepted_like))

    fig, axes = plt.subplots(1, 3, figsize=(13, 4.6))
    components = [
        ("score", "Reward Score", "score"),
        ("winRate", "Win Rate", "top-or-tied win rate"),
        ("averageMargin", "Average Margin", "score margin"),
    ]
    for ax, (key, metric_title, ylabel) in zip(axes, components):
        ax.plot(x, [event[key] for event in accepted_like], color=MODEL_COLOR, marker="o", linewidth=2.5)
        ax.set_xticks(x)
        ax.set_xticklabels(
            [event["prefix"] if event["prefix"] != "accepted" else f"gen\n{event['generation']}" for event in accepted_like],
            fontsize=9,
        )
        style_axis(ax, metric_title, ylabel)
    fig.suptitle(title, fontsize=14, fontweight="bold")
    save(fig, output_name)


def main() -> None:
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 10,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
        }
    )
    full_game_winrates()
    full_game_deltas()
    architecture_comparison()
    weakest_seat()
    training_progress_proxy()
    plot_training_reward_history(
        HISTORY_PATH,
        "finetune_reward_over_time.png",
        "Real-Engine Fine-Tuning Reward Over Time",
    )
    plot_training_components_history(
        HISTORY_PATH,
        "finetune_accepted_components.png",
        "Accepted Fine-Tuned Model Stats",
    )
    plot_training_reward_history(
        SCRATCH_HISTORY_PATH,
        "scratch_reward_over_time.png",
        "Real-Engine Scratch Training Reward Over Time",
    )
    plot_training_components_history(
        SCRATCH_HISTORY_PATH,
        "scratch_accepted_components.png",
        "Accepted Scratch Model Training Stats",
    )
    print(f"wrote visualizations to {OUT_DIR}")


if __name__ == "__main__":
    main()
