from __future__ import annotations

import argparse
from pathlib import Path

from research.kolkhoz_research.model import PolicyArtifact

from .ai import ModelCache
from .engine import KolkhozCEngineFactory


def load_policy_models(repo_root: Path) -> ModelCache[object]:
    paths = {
        "mediumAI": repo_root / "policies/medium_policy.json",
        "neuralAI": repo_root / "policies/hard_policy.json",
    }
    models = ModelCache(paths, lambda path: PolicyArtifact.load(path).c_buffer())
    for controller in paths:
        models.get(controller)
    return models


def run_policy_canary(models: ModelCache[object]) -> None:
    factory = KolkhozCEngineFactory()
    for seed, controller in ((1701, "mediumAI"), (1702, "neuralAI")):
        engine = factory.create(
            seed,
            {"variants": {}, "controllers": ["human"] * 4},
        )
        try:
            player_id = engine.waiting_player()
            if player_id < 0:
                raise RuntimeError(f"{controller} canary has no waiting player")
            engine.set_controller(player_id, controller)
            action = engine.policy_action(models.get(controller))
            if action not in engine.legal_actions():
                raise RuntimeError(f"{controller} selected an illegal canary action")
            engine.apply_ai_action(action)
        finally:
            engine.close()


def verify_production_assets(repo_root: Path) -> ModelCache[object]:
    models = load_policy_models(repo_root)
    run_policy_canary(models)
    return models


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    verify_production_assets(args.repo_root.resolve())
    print("Production policy assets and real-engine AI canaries passed")


if __name__ == "__main__":
    main()
