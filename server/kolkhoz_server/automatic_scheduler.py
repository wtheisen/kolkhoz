from __future__ import annotations

import logging
import threading
import time
from collections.abc import Callable
from typing import TYPE_CHECKING

from .lobby import LobbyRepository

if TYPE_CHECKING:
    from .metrics import ServerMetrics


class AutomaticTurnScheduler:
    def __init__(
        self,
        repository: LobbyRepository,
        advance: Callable[[str], None],
        *,
        batch_size: int = 64,
        metrics: ServerMetrics | None = None,
    ) -> None:
        self.repository = repository
        self.advance = advance
        self.batch_size = batch_size
        self.metrics = metrics
        self.consecutive_failures = 0
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self, *, now: float | None = None) -> int:
        current = time.time() if now is None else now
        completed = 0
        failed = False
        for session_id in self.repository.automatic_due_sessions(
            now=current, limit=self.batch_size
        ):
            try:
                self.advance(session_id)
                completed += 1
            except Exception:
                failed = True
                logging.exception(
                    "automatic turn advancement failed for %s", session_id
                )
                if self.metrics is not None:
                    self.metrics.increment("automatic.failures")
        self.consecutive_failures = self.consecutive_failures + 1 if failed else 0
        if self.metrics is not None:
            self.metrics.gauge("automatic.healthy", int(self.healthy))
        return completed

    @property
    def healthy(self) -> bool:
        return self.consecutive_failures == 0 and (
            self._thread is None or self._thread.is_alive()
        )

    def start(self, *, interval_seconds: float = 1) -> None:
        if self._thread is not None:
            raise RuntimeError("automatic turn scheduler is already running")

        def run() -> None:
            while not self._stop.wait(interval_seconds):
                self.run_once()

        self._thread = threading.Thread(
            target=run, name="kolkhoz-automatic-turns", daemon=True
        )
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None
