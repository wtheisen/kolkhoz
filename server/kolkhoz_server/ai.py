from __future__ import annotations

import hashlib
import threading
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Generic, Iterator, Mapping, Protocol, Sequence, TypeVar

from .model import JsonObject


HUMAN = "human"
HEURISTIC_AI = "heuristicAI"
POLICY_CONTROLLERS = frozenset(("mediumAI", "neuralAI"))
AUTOMATIC_GUARD_LIMIT = 200
BOT_ACTION_DELAY_MIN_SECONDS = 1.5
BOT_ACTION_DELAY_MAX_SECONDS = 8.0

Model = TypeVar("Model")


class AutomaticEngine(Protocol, Generic[Model]):
    """The AI surface exposed by an engine owned by exactly one worker shard."""

    def waiting_player(self) -> int: ...
    def legal_actions(self) -> Sequence[JsonObject]: ...
    def heuristic_action(self) -> JsonObject: ...
    def policy_action(self, model: Model) -> JsonObject: ...
    def apply_ai_action(self, action: JsonObject) -> None: ...
    def controller(self, player_id: int) -> str: ...
    def set_controller(self, player_id: int, controller: str) -> None: ...


class ModelCache(Generic[Model]):
    """Process-local immutable model cache with synchronization only on first load."""

    def __init__(
        self,
        paths: Mapping[str, Path | str],
        loader: Callable[[Path], Model],
    ) -> None:
        self._paths = {name: Path(path) for name, path in paths.items()}
        self._loader = loader
        self._models: dict[str, Model] = {}
        self._lock = threading.Lock()

    def get(self, controller: str) -> Model:
        cached = self._models.get(controller)
        if cached is not None:
            return cached
        with self._lock:
            cached = self._models.get(controller)
            if cached is not None:
                return cached
            path = self._paths.get(controller)
            if path is None:
                raise ValueError(f"policy {controller!r} is not configured")
            try:
                model = self._loader(path)
            except Exception as error:
                raise RuntimeError(
                    f"policy {controller!r} failed to load: {error}"
                ) from error
            self._models[controller] = model
            return model

    def sha256(self) -> str | None:
        available = {name: path for name, path in self._paths.items() if path.exists()}
        if not available:
            return None
        digest = hashlib.sha256()
        for name, path in sorted(available.items()):
            digest.update(name.encode())
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        return digest.hexdigest()


@dataclass
class AutomaticState:
    session_id: str
    controllers: tuple[str, ...]
    browser_joinable: bool = True
    population_kind: str | None = None
    action_count: int = 0
    seat_user_ids: dict[int, str] = field(default_factory=dict)
    controller_overrides: dict[int, str] = field(default_factory=dict)
    ready_at: dict[int, float] = field(default_factory=dict)

    def effective_controller(self, player_id: int) -> str:
        return self.controller_overrides.get(player_id, self.controllers[player_id])

    def assign_profile_bot(self, player_id: int, profile: Mapping[str, object]) -> None:
        controller = str(profile.get("controller", ""))
        user_id = str(profile.get("user_id", profile.get("userID", "")))
        if controller not in {HEURISTIC_AI, *POLICY_CONTROLLERS} or not user_id:
            raise ValueError("invalid profile bot")
        self.seat_user_ids[player_id] = user_id
        self.controller_overrides[player_id] = controller

    def restore_profile_bots(
        self, profiles_by_user_id: Mapping[str, Mapping[str, object]]
    ) -> None:
        for player_id, user_id in self.seat_user_ids.items():
            profile = profiles_by_user_id.get(user_id)
            if profile is not None:
                self.assign_profile_bot(player_id, profile)


def deterministic_profile(
    session_id: str,
    controller: str,
    ordinal: int,
    profiles: Sequence[Mapping[str, object]],
) -> Mapping[str, object]:
    if not profiles:
        raise ValueError("no profiles available")
    offset = int.from_bytes(
        hashlib.sha256(f"{session_id}:{controller}".encode()).digest()[:4], "big"
    )
    return profiles[(offset + ordinal) % len(profiles)]


def bot_action_delay(state: AutomaticState, player_id: int) -> float:
    digest = hashlib.sha256(
        (
            f"{state.session_id}:{player_id}:{state.action_count}:"
            f"{state.seat_user_ids.get(player_id, '')}"
        ).encode()
    ).digest()
    jitter = int.from_bytes(digest[:4], "big") / 0xFFFFFFFF
    return (
        BOT_ACTION_DELAY_MIN_SECONDS
        + (BOT_ACTION_DELAY_MAX_SECONDS - BOT_ACTION_DELAY_MIN_SECONDS) * jitter
    )


@contextmanager
def effective_controller(
    engine: AutomaticEngine[object], player_id: int, controller: str
) -> Iterator[None]:
    """Temporarily expose a profile-bot controller to policy feature extraction."""

    original = engine.controller(player_id)
    engine.set_controller(player_id, controller)
    try:
        yield
    finally:
        engine.set_controller(player_id, original)


class AutomaticAdvancer(Generic[Model]):
    """Advances bots inside a shard mailbox; it owns no locks or global game state."""

    def __init__(self, models: ModelCache[Model]) -> None:
        self.models = models

    def advance(
        self,
        engine: AutomaticEngine[Model],
        state: AutomaticState,
        *,
        now: float,
        record: Callable[[JsonObject, str], None],
    ) -> int:
        applied = 0
        for _ in range(AUTOMATIC_GUARD_LIMIT):
            player_id = engine.waiting_player()
            if player_id < 0 or player_id >= len(state.controllers):
                return applied
            controller = state.effective_controller(player_id)
            if controller == HUMAN:
                return applied
            if self._should_delay(state, player_id):
                ready_at = state.ready_at.get(player_id)
                if ready_at is None:
                    state.ready_at[player_id] = now + bot_action_delay(state, player_id)
                    return applied
                if now < ready_at:
                    return applied
            action = self._choose(engine, player_id, controller)
            if int(action.get("playerID", -1)) != player_id:
                action = self._first_legal(engine, player_id)
            engine.apply_ai_action(action)
            state.ready_at.pop(player_id, None)
            record(action, "automatic")
            state.action_count += 1
            applied += 1
        raise RuntimeError("automatic controller loop exceeded guard limit")

    @staticmethod
    def _should_delay(state: AutomaticState, player_id: int) -> bool:
        return (
            state.population_kind != "rating_seed"
            and state.browser_joinable
            and HUMAN in state.controllers
            and state.effective_controller(player_id) != HUMAN
        )

    def _choose(
        self, engine: AutomaticEngine[Model], player_id: int, controller: str
    ) -> JsonObject:
        if controller == HEURISTIC_AI:
            return engine.heuristic_action()
        if controller in POLICY_CONTROLLERS:
            model = self.models.get(controller)
            # Profile bots can override a seat whose native controller is human.
            # Policy features must see the effective controller for this call only.
            with effective_controller(engine, player_id, controller):  # type: ignore[arg-type]
                return engine.policy_action(model)
        raise ValueError(f"unknown controller: {controller}")

    @staticmethod
    def _first_legal(engine: AutomaticEngine[Model], player_id: int) -> JsonObject:
        for action in engine.legal_actions():
            if int(action.get("playerID", -1)) == player_id:
                return action
        raise RuntimeError(f"automatic player {player_id} has no legal action")
