from __future__ import annotations

import queue
import threading
from collections import defaultdict
from contextlib import contextmanager
from typing import Iterator

from .model import StoredEvent


class EventHub:
    """Process-local fanout boundary for a future WebSocket gateway.

    Durable catch-up always comes from EventStore; this hub only reduces latency
    for currently connected gateways.
    """

    def __init__(self) -> None:
        self._subscribers: dict[str, set[queue.Queue[StoredEvent]]] = defaultdict(set)
        self._lock = threading.Lock()

    @contextmanager
    def subscribe(self, session_id: str) -> Iterator[queue.Queue[StoredEvent]]:
        mailbox: queue.Queue[StoredEvent] = queue.Queue(maxsize=64)
        with self._lock:
            self._subscribers[session_id].add(mailbox)
        try:
            yield mailbox
        finally:
            with self._lock:
                subscribers = self._subscribers.get(session_id)
                if subscribers is not None:
                    subscribers.discard(mailbox)
                    if not subscribers:
                        self._subscribers.pop(session_id, None)

    def publish(self, event: StoredEvent) -> None:
        with self._lock:
            subscribers = tuple(self._subscribers.get(event.session_id, ()))
        for mailbox in subscribers:
            try:
                mailbox.put_nowait(event)
            except queue.Full:
                # A slow gateway reconnects using its last durable revision.
                pass
