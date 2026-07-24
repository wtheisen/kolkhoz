from __future__ import annotations

from dataclasses import dataclass
from typing import Any


JsonObject = dict[str, Any]
ENGINE_REPLAY_CONTRACT_VERSION = 1


@dataclass(frozen=True)
class GameRecord:
    session_id: str
    seed: int
    variants: JsonObject
    revision: int
    engine_build_sha: str = "unknown"
    engine_sha256: str = "unknown"
    engine_contract_version: int = ENGINE_REPLAY_CONTRACT_VERSION


@dataclass(frozen=True)
class StoredEvent:
    session_id: str
    revision: int
    kind: str
    payload: JsonObject
    created_at: float


@dataclass(frozen=True)
class GameUpdate:
    session_id: str
    revision: int
    state: JsonObject
    event: StoredEvent | None = None
