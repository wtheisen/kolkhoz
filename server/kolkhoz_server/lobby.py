from __future__ import annotations

import secrets
import time
import uuid
from dataclasses import dataclass
from typing import Protocol

from .model import JsonObject


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    invite_code: str
    seed: int
    variants: JsonObject
    controllers: list[str]
    ranked: bool
    browser_joinable: bool
    status: str
    created_by_user_id: str | None
    created_at: float
    updated_at: float
    expires_at: float
    lobby_countdown_ends_at: float | None


@dataclass(frozen=True)
class SeatRecord:
    player_id: int
    controller: str
    occupied: bool
    user_id: str | None
    token_hash: str | None
    last_seen_at: float | None
    timeouts: int
    abandoned: bool
    autopilot: bool


@dataclass(frozen=True)
class DueTurn:
    session_id: str
    player_id: int
    deadline_at: float
    claim_owner: str
    fencing_token: int


@dataclass(frozen=True)
class TimeoutResult:
    timeouts: int
    forced_autopilot: bool
    completed: bool = False


@dataclass(frozen=True)
class LifecycleIntent:
    session_id: str
    operation: str
    seed: int | None
    variants: JsonObject | None
    controllers: list[str] | None
    fencing_token: int


class SeatUnavailable(RuntimeError):
    pass


class LobbyRepository(Protocol):
    def create(self, record: SessionRecord, seats: list[SeatRecord]) -> None: ...
    def session(self, session_id_or_invite: str) -> SessionRecord: ...
    def seats(self, session_id: str) -> list[SeatRecord]: ...
    def list_open(self, now: float) -> list[SessionRecord]: ...
    def list_watchable(self, now: float) -> list[SessionRecord]: ...
    def automatic_due_sessions(self, *, now: float, limit: int) -> list[str]: ...
    def activate_ready_sessions(self, *, now: float) -> list[str]: ...
    def finish_session(
        self, session_id: str, *, now: float, expires_at: float
    ) -> bool: ...
    def expire_sessions(self, *, now: float, limit: int) -> list[str]: ...
    def occupy_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        user_id: str,
        token_hash: str,
        now: float,
    ) -> None: ...
    def release_seat(self, session_id: str, player_id: int, *, now: float) -> None: ...
    def release_seat_and_delete_if_empty(
        self, session_id: str, player_id: int, *, now: float
    ) -> bool: ...
    def kick_seat(
        self,
        session_id: str,
        target_player_id: int,
        *,
        host_user_id: str,
        now: float,
    ) -> None: ...
    def set_status(
        self,
        session_id: str,
        status: str,
        *,
        now: float,
        countdown_ends_at: float | None = None,
    ) -> None: ...
    def delete_session(self, session_id: str) -> None: ...
    def append_reaction(
        self,
        session_id: str,
        *,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> dict[str, object]: ...
    def reactions(self, session_id: str) -> list[dict[str, object]]: ...
    def invite(self, session_id: str, user_ids: set[str], *, now: float) -> None: ...
    def invites_for_user(self, user_id: str) -> list[SessionRecord]: ...
    def decline_invite(self, session_id: str, user_id: str) -> None: ...
    def mark_presence(self, user_id: str, *, now: float) -> None: ...
    def acquire_device_lease(
        self,
        user_id: str,
        device_id: str,
        session_id: str,
        *,
        now: float,
        ttl_seconds: float,
    ) -> bool: ...
    def online_user_ids(self, *, since: float) -> set[str]: ...
    def metrics_state(self, *, now: float, presence_since: float) -> JsonObject: ...
    def set_turn_deadline(
        self,
        session_id: str,
        player_id: int | None,
        *,
        deadline_at: float | None,
        now: float,
    ) -> None: ...
    def turn_state(self, session_id: str) -> tuple[int | None, float | None]: ...
    def claim_due_turns(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[DueTurn]: ...
    def consume_timeout(self, claim: DueTurn, *, now: float) -> TimeoutResult: ...
    def complete_timeout(self, claim: DueTurn) -> None: ...
    def touch_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        now: float,
        session_ttl_seconds: float | None = None,
    ) -> None: ...
    def complete_lifecycle_intent(
        self, session_id: str, operation: str, *, fencing_token: int | None = None
    ) -> None: ...
    def claim_lifecycle_intents(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[LifecycleIntent]: ...
    def retry_lifecycle_intent(
        self, intent: LifecycleIntent, *, now: float, delay_seconds: float
    ) -> None: ...


def new_session_record(
    *,
    seed: int,
    variants: JsonObject,
    controllers: list[str],
    ranked: bool,
    browser_joinable: bool,
    created_by_user_id: str | None,
    ttl_seconds: float,
) -> SessionRecord:
    now = time.time()
    return SessionRecord(
        str(uuid.uuid4()),
        "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(5)),
        seed,
        dict(variants),
        list(controllers),
        ranked,
        browser_joinable,
        "open",
        created_by_user_id,
        now,
        now,
        now + ttl_seconds,
        None,
    )
