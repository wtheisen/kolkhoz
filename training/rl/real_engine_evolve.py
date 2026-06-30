#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
import re
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SWIFT_PACKAGE = ROOT / "ios" / "KolkhozSwiftUI"
EVAL_RE = re.compile(
    r"policy_wins=(?P<wins>\d+)\s+heuristic_wins=(?P<losses>\d+)\s+ties=(?P<ties>\d+)\s+avg_best_score_margin=(?P<margin>-?\d+(?:\.\d+)?)"
)


def load_model(path: Path) -> dict:
    return json.loads(path.read_text())


def save_model(path: Path, model: dict) -> None:
    path.write_text(json.dumps(model, indent=2) + "\n")


def mutate(model: dict, sigma: float, rng: random.Random) -> dict:
    candidate = json.loads(json.dumps(model))
    for key in ("w1", "b1", "w2"):
        candidate[key] = [value + rng.gauss(0, sigma) for value in candidate[key]]
    candidate["b2"] = candidate["b2"] + rng.gauss(0, sigma)
    return candidate


def evaluate(model_path: Path, games: int, seed: int) -> tuple[float, str]:
    result = subprocess.run(
        [
            "swift",
            "run",
            "KolkhozPolicyEval",
            "--model",
            str(model_path),
            "--games",
            str(games),
            "--seed",
            str(seed),
        ],
        cwd=SWIFT_PACKAGE,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
    )
    match = EVAL_RE.search(result.stdout)
    if not match:
        raise RuntimeError(f"Could not parse evaluator output:\n{result.stdout}")
    wins = int(match.group("wins"))
    losses = int(match.group("losses"))
    margin = float(match.group("margin"))
    score = margin + 0.25 * (wins - losses)
    return score, match.group(0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Black-box tune a Kolkhoz policy against the real Swift engine.")
    parser.add_argument("--start", required=True, help="Starting policy JSON.")
    parser.add_argument("--output", required=True, help="Best policy JSON to write.")
    parser.add_argument("--generations", type=int, default=5)
    parser.add_argument("--population", type=int, default=4)
    parser.add_argument("--games", type=int, default=40)
    parser.add_argument("--seed", type=int, default=90_000)
    parser.add_argument("--sigma", type=float, default=0.02)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    best = load_model(Path(args.start))

    with tempfile.TemporaryDirectory(prefix="kolkhoz-real-evolve-") as tmp:
        tmp_dir = Path(tmp)
        best_path = tmp_dir / "best.json"
        save_model(best_path, best)
        best_score, best_summary = evaluate(best_path, args.games, args.seed)
        print(f"generation=0 score={best_score:.2f} {best_summary}")

        for generation in range(1, args.generations + 1):
            generation_seed = args.seed + generation * 10_000
            for index in range(args.population):
                candidate = mutate(best, args.sigma, rng)
                candidate_path = tmp_dir / f"candidate-{generation}-{index}.json"
                save_model(candidate_path, candidate)
                score, summary = evaluate(candidate_path, args.games, generation_seed + index * args.games)
                print(f"generation={generation} candidate={index} score={score:.2f} {summary}")
                if score > best_score:
                    best = candidate
                    best_score = score
                    best_summary = summary
                    save_model(best_path, best)
                    print(f"accepted generation={generation} candidate={index} score={best_score:.2f}")

        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        save_model(output, best)
        print(f"best_score={best_score:.2f} {best_summary}")
        print(f"exported {output}")


if __name__ == "__main__":
    main()
