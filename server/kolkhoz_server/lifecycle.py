from __future__ import annotations

import logging
import threading
import time
import uuid
from collections.abc import Callable

from .lobby import LifecycleIntent, LobbyRepository


class LifecycleReconciler:
    """Converges durable lobby provisioning/deletion intents with the event store."""

    def __init__(
        self,
        repository: LobbyRepository,
        runtime: object,
        *,
        owner_id: str | None = None,
        batch_size: int = 64,
        lease_seconds: float = 30,
        retry_seconds: float = 2,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.repository = repository
        self.runtime = runtime
        self.owner_id = owner_id or str(uuid.uuid4())
        self.batch_size = batch_size
        self.lease_seconds = lease_seconds
        self.retry_seconds = retry_seconds
        self.clock = clock
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self, *, now: float | None = None) -> int:
        current = self.clock() if now is None else now
        intents = self.repository.claim_lifecycle_intents(
            owner=self.owner_id,
            now=current,
            lease_seconds=self.lease_seconds,
            limit=self.batch_size,
        )
        completed = 0
        for intent in intents:
            try:
                self._apply(intent)
                self.repository.complete_lifecycle_intent(
                    intent.session_id,
                    intent.operation,
                    fencing_token=intent.fencing_token,
                )
                completed += 1
            except Exception:
                logging.exception(
                    "lifecycle reconciliation failed for %s %s",
                    intent.operation,
                    intent.session_id,
                )
                self.repository.retry_lifecycle_intent(
                    intent, now=current, delay_seconds=self.retry_seconds
                )
        return completed

    def _apply(self, intent: LifecycleIntent) -> None:
        if intent.operation == "delete":
            try:
                self.runtime.delete_game(intent.session_id)
            except KeyError:
                pass
            return
        try:
            self.repository.session(intent.session_id)
        except KeyError:
            return
        try:
            self.runtime.store.game(intent.session_id)
            return
        except KeyError:
            pass
        assert intent.seed is not None
        self.runtime.create_game(
            seed=intent.seed,
            variants={
                "variants": intent.variants or {},
                "controllers": intent.controllers or [],
            },
            session_id=intent.session_id,
        )

    def start(self, *, interval_seconds: float = 1) -> None:
        if self._thread is not None:
            raise RuntimeError("lifecycle reconciler is already running")

        def run() -> None:
            while not self._stop.wait(interval_seconds):
                self.run_once()

        self._thread = threading.Thread(
            target=run, name=f"kolkhoz-lifecycle-{self.owner_id}", daemon=True
        )
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None
