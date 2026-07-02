from __future__ import annotations

import argparse
import json
from dataclasses import asdict

from .c_engine import CEngine, build_shared_library


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


def main() -> int:
    parser = argparse.ArgumentParser(prog="kolkhoz-research")
    subparsers = parser.add_subparsers(dest="command", required=True)

    smoke = subparsers.add_parser("engine-smoke", help="run deterministic C-engine smoke games")
    smoke.add_argument("--games", type=int, default=8)
    smoke.add_argument("--seed", type=int, default=1_000_000)
    smoke.add_argument("--rebuild", action="store_true")
    smoke.set_defaults(func=engine_smoke)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())

