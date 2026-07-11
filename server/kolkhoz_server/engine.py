from __future__ import annotations

from typing import Protocol

from .model import JsonObject


class GameEngine(Protocol):
    def apply(self, action: JsonObject) -> None: ...
    def view(self, viewer_id: int | None = None) -> JsonObject: ...
    def close(self) -> None: ...


class EngineFactory(Protocol):
    def create(self, seed: int, variants: JsonObject) -> GameEngine: ...


class KolkhozCEngineFactory:
    """Adapter from shard ownership to the authoritative portable C engine."""

    def __init__(self) -> None:
        from research.kolkhoz_research.c_engine import CEngine

        self._engine = CEngine()

    def create(self, seed: int, variants: JsonObject) -> GameEngine:
        from .contracts import (
            controllers_native,
            normalize_controllers,
            variants_native,
        )

        game_variants = variants.get("variants", variants)
        controllers = normalize_controllers(variants.get("controllers"))
        return KolkhozCEngine(
            self._engine,
            seed,
            variants=variants_native(game_variants),  # type: ignore[arg-type]
            controllers=controllers_native(controllers),
        )

    def provenance(self) -> JsonObject:
        value = self._engine.provenance()
        return {"gitSHA": value.git_sha, "engineSHA256": value.c_sha256}


class KolkhozCEngine:
    def __init__(
        self, engine: object, seed: int, *, variants: object, controllers: object
    ) -> None:
        self._engine = engine
        self._pointer = engine.new_engine(
            seed, variants=variants, controllers=controllers
        )

    def apply(self, action: JsonObject) -> None:
        from .contracts import action_from_json

        native = action_from_json(action)
        legal = self._engine.legal_actions(self._pointer)
        signature = self._signature(native)
        if not any(self._signature(candidate) == signature for candidate in legal):
            raise ValueError("illegal action")
        self._engine.apply_action(self._pointer, native)

    def waiting_player(self) -> int:
        return self._engine.waiting_player(self._pointer)

    def legal_actions(self) -> list[JsonObject]:
        return [
            self._action_json(action)
            for action in self._engine.legal_actions(self._pointer)
        ]

    def heuristic_action(self) -> JsonObject:
        return self._action_json(self._engine.heuristic_action(self._pointer))

    def policy_action(self, model: object) -> JsonObject:
        action = self._engine.policy_action(self._pointer, model)
        if action is None:
            legal = self.legal_actions()
            if not legal:
                raise RuntimeError("policy controller has no legal action")
            return legal[0]
        return self._action_json(action)

    def apply_ai_action(self, action: JsonObject) -> None:
        from .contracts import action_from_json

        self._engine.apply_ai_action(self._pointer, action_from_json(action))

    def controller(self, player_id: int) -> str:
        from .contracts import CONTROLLER_CODES

        code = int(self._engine.snapshot(self._pointer).controllers.seats[player_id])
        return next(
            (name for name, value in CONTROLLER_CODES.items() if value == code),
            "human",
        )

    def set_controller(self, player_id: int, controller: str) -> None:
        from .contracts import CONTROLLER_CODES

        self._engine.snapshot(self._pointer).controllers.seats[player_id] = (
            CONTROLLER_CODES[controller]
        )

    @staticmethod
    def _signature(action: object) -> tuple[int, ...]:
        return (
            int(action.kind),
            int(action.player_id),
            int(action.suit),
            int(action.card.suit),
            int(action.card.value),
            int(action.hand_card.suit),
            int(action.hand_card.value),
            int(action.plot_card.suit),
            int(action.plot_card.value),
            int(action.plot_zone),
            int(action.target_suit),
        )

    def view(self, viewer_id: int | None = None) -> JsonObject:
        from .contracts import snapshot_json

        legal = self._engine.legal_actions(self._pointer)
        value = snapshot_json(self._engine, self._pointer, viewer_id)
        value["legalActions"] = [self._action_json(action) for action in legal]
        return value

    @staticmethod
    def _action_json(action: object) -> JsonObject:
        def card(value: object) -> JsonObject:
            return {"suit": int(value.suit), "value": int(value.value)}

        return {
            "kind": int(action.kind),
            "playerID": int(action.player_id),
            "suit": int(action.suit),
            "card": card(action.card),
            "handCard": card(action.hand_card),
            "plotCard": card(action.plot_card),
            "plotZone": int(action.plot_zone),
            "targetSuit": int(action.target_suit),
        }

    def close(self) -> None:
        self._engine.free_engine(self._pointer)
