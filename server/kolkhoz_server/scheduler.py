from __future__ import annotations

import logging
import threading
import time
import uuid
from collections.abc import Callable
from typing import TYPE_CHECKING, Mapping, Protocol

from .lobby import DueTurn, LobbyRepository, SeatUnavailable
from .model import GameUpdate

if TYPE_CHECKING:
    from .metrics import ServerMetrics


DEFAULT_TURN_SECONDS = 90.0
DEFAULT_CLAIM_SECONDS = 30.0
DEFAULT_BATCH_SIZE = 128


class ScheduledRuntime(Protocol):
    def state(self, session_id: str, viewer_id: int | None = None) -> GameUpdate: ...
    def set_autopilot(
        self, session_id: str, player_id: int, controller: str = "heuristicAI"
    ) -> None: ...
    def advance_and_state(
        self, session_id: str, *, viewer_id: int | None = None, now: float | None = None
    ) -> GameUpdate: ...
    def consume_timeout(
        self, claim: DueTurn, repository: LobbyRepository, *, now: float
    ) -> GameUpdate: ...


class DeadlineScheduler:
    """Claims only indexed, due sessions and submits work to their owner mailbox.

    Database claim leases make replicas safe: one replica consumes a specific deadline,
    while the runtime's session lease and ordered mailbox fence engine mutation.
    """

    def __init__(
        self,
        repository: LobbyRepository,
        runtime: ScheduledRuntime,
        *,
        owner_id: str | None = None,
        turn_seconds: float = DEFAULT_TURN_SECONDS,
        claim_seconds: float = DEFAULT_CLAIM_SECONDS,
        batch_size: int = DEFAULT_BATCH_SIZE,
        clock: Callable[[], float] = time.time,
        metrics: ServerMetrics | None = None,
        on_state: Callable[[str, Mapping[str, object]], None] | None = None,
    ) -> None:
        if turn_seconds <= 0 or claim_seconds <= 0 or batch_size <= 0:
            raise ValueError("scheduler durations and batch size must be positive")
        self.repository = repository
        self.runtime = runtime
        self.owner_id = owner_id or str(uuid.uuid4())
        self.turn_seconds = turn_seconds
        self.claim_seconds = claim_seconds
        self.batch_size = batch_size
        self.clock = clock
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.metrics = metrics
        self.on_state = on_state

    def run_once(self, *, now: float | None = None) -> int:
        started = time.perf_counter()
        current = self.clock() if now is None else now
        activated = self.repository.activate_ready_sessions(now=current)
        for session_id in activated:
            state = self.runtime.advance_and_state(session_id, now=current)
            if self.on_state is not None:
                self.on_state(session_id, state.state)
            self._schedule_waiting(session_id, self._waiting_player(state), current)
        claims = self.repository.claim_due_turns(
            owner=self.owner_id,
            now=current,
            lease_seconds=self.claim_seconds,
            limit=self.batch_size,
        )
        if self.metrics is not None:
            self.metrics.increment("scheduler.claims", len(claims))
            self.metrics.gauge("scheduler.claim_batch", len(claims))
            if claims:
                self.metrics.gauge(
                    "scheduler.lag_seconds",
                    max(0.0, current - min(claim.deadline_at for claim in claims)),
                )
        completed = 0
        for claim in claims:
            try:
                if self._process(claim, current):
                    completed += 1
            except (KeyError, SeatUnavailable):
                # A human action, leave, or session deletion can legitimately win
                # after the due query. The fenced claim becomes a harmless no-op.
                continue
            except Exception:
                logging.exception("deadline processing failed for %s", claim.session_id)
        if self.metrics is not None:
            self.metrics.increment("scheduler.completed", completed)
            self.metrics.observe("scheduler.tick", time.perf_counter() - started)
        return completed

    def _process(self, claim: DueTurn, now: float) -> bool:
        before = self.runtime.state(claim.session_id)
        waiting = self._waiting_player(before)
        if waiting != claim.player_id:
            self._schedule_waiting(claim.session_id, waiting, now)
            return False

        after = self.runtime.consume_timeout(claim, self.repository, now=now)
        if self.on_state is not None:
            self.on_state(claim.session_id, after.state)
        next_player = self._waiting_player(after)
        self._schedule_waiting(claim.session_id, next_player, now)
        return True

    @staticmethod
    def _waiting_player(update: GameUpdate) -> int | None:
        raw = update.state.get("waitingPlayer")
        if isinstance(raw, int) and 0 <= raw < 4:
            return raw
        return None

    def _schedule_waiting(
        self, session_id: str, player_id: int | None, now: float
    ) -> None:
        eligible = False
        if player_id is not None:
            eligible = any(
                seat.player_id == player_id
                and seat.controller == "human"
                and seat.occupied
                and not seat.autopilot
                for seat in self.repository.seats(session_id)
            )
        self.repository.set_turn_deadline(
            session_id,
            player_id if eligible else None,
            deadline_at=now + self.turn_seconds if eligible else None,
            now=now,
        )

    def start(self, *, interval_seconds: float = 1.0) -> None:
        if interval_seconds <= 0:
            raise ValueError("interval_seconds must be positive")
        if self._thread is not None:
            raise RuntimeError("scheduler is already running")
        self._stop.clear()

        def run() -> None:
            while not self._stop.wait(interval_seconds):
                self.run_once()

        self._thread = threading.Thread(
            target=run, name=f"kolkhoz-deadlines-{self.owner_id}", daemon=True
        )
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None
