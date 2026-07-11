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
        return KolkhozCEngine(self._engine, seed)

    def provenance(self) -> JsonObject:
        value = self._engine.provenance()
        return {"gitSHA": value.git_sha, "engineSHA256": value.c_sha256}


class KolkhozCEngine:
    def __init__(self, engine: object, seed: int) -> None:
        from research.kolkhoz_research.c_engine import KCControllers

        self._engine = engine
        controllers = KCControllers()
        for index in range(4):
            controllers.seats[index] = 0
        self._pointer = engine.new_engine(seed, controllers=controllers)

    def apply(self, action: JsonObject) -> None:
        from research.kolkhoz_research.c_engine import KCAction, KCCard

        def card(name: str) -> KCCard:
            value = action.get(name)
            if not isinstance(value, dict):
                return KCCard(-1, 0)
            return KCCard(int(value.get("suit", -1)), int(value.get("value", 0)))

        native = KCAction(
            int(action["kind"]),
            int(action["playerID"]),
            int(action.get("suit", -1)),
            card("card"),
            card("handCard"),
            card("plotCard"),
            int(action.get("plotZone", -1)),
            int(action.get("targetSuit", -1)),
        )
        legal = self._engine.legal_actions(self._pointer)
        signature = self._signature(native)
        if not any(self._signature(candidate) == signature for candidate in legal):
            raise ValueError("illegal action")
        self._engine.apply_action(self._pointer, native)

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
        legal = self._engine.legal_actions(self._pointer)
        return {
            "year": self._engine.year(self._pointer),
            "phase": self._engine.phase(self._pointer),
            "waitingPlayerID": self._engine.waiting_player(self._pointer),
            "winnerID": self._engine.winner_id(self._pointer),
            "legalActions": [self._action_json(action) for action in legal],
        }

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
