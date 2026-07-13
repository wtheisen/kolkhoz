from __future__ import annotations

import ctypes

from research.kolkhoz_research.c_engine import CEngine, KCAction, KCControllers
from research.kolkhoz_research.model import PolicyArtifact


def _action_tuple(action: KCAction) -> tuple[int, ...]:
    return (
        action.kind,
        action.player_id,
        action.suit,
        action.card.suit,
        action.card.value,
        action.hand_card.suit,
        action.hand_card.value,
        action.plot_card.suit,
        action.plot_card.value,
        action.plot_zone,
        action.target_suit,
    )


def test_reused_policy_workspace_preserves_action_selection() -> None:
    engine = CEngine()
    artifact = PolicyArtifact.load(
        engine.library_path.parents[2] / "policies" / "medium_policy.json"
    )
    model = artifact.c_buffer()
    pointer = engine.new_engine(731, controllers=KCControllers((2, 2, 2, 2)))
    clone = engine.clone_engine(pointer)
    try:
        one_shot = KCAction()
        assert engine.lib.kc_engine_policy_action(
            clone, model, ctypes.byref(one_shot)
        )

        reused = engine.policy_action(pointer, model)
        assert reused is not None
        assert _action_tuple(reused) == _action_tuple(one_shot)

        workspace = engine._policy_workspace(model)
        assert engine._policy_workspace(model) == workspace
    finally:
        engine.free_engine(clone)
        engine.free_engine(pointer)
