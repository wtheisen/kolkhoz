from __future__ import annotations

import unittest

from server.kolkhoz_server.notifications import (
    Installation,
    InvalidPushToken,
    NotificationService,
    NotificationWorker,
    OutboxItem,
)


class MemoryNotificationRepository:
    def __init__(self) -> None:
        self.rows: list[OutboxItem] = []
        self.keys: set[str] = set()
        self.devices = [
            Installation("device-123", "human", "valid-token-value", {"turns": True})
        ]
        self.disabled: set[str] = set()
        self.sent: list[int] = []
        self.failures: list[tuple[int, str, float | None]] = []
        self.deliveries: set[tuple[int, str]] = set()
        self.viewing = False

    def register_installation(self, **values: object) -> None:
        self.devices = [
            Installation(
                str(values["installation_id"]),
                str(values["user_id"]),
                str(values["token"]),
                dict(values["preferences"]),  # type: ignore[arg-type]
            )
        ]

    def delete_installation(self, **values: object) -> bool:
        before = len(self.devices)
        self.devices = [
            item
            for item in self.devices
            if not (
                item.installation_id == values["installation_id"]
                and item.user_id == values["user_id"]
            )
        ]
        return len(self.devices) != before

    def enqueue(self, **values: object) -> bool:
        key = str(values["dedupe_key"])
        if key in self.keys:
            return False
        self.keys.add(key)
        self.rows.append(
            OutboxItem(
                len(self.rows) + 1,
                str(values["user_id"]),
                str(values["event_type"]),
                dict(values["payload"]),  # type: ignore[arg-type]
                0,
            )
        )
        return True

    def claim(self, *, limit: int, lock_seconds: float) -> list[OutboxItem]:
        return [
            OutboxItem(row.id, row.user_id, row.event_type, row.payload, row.attempts + 1)
            for row in self.rows[:limit]
            if row.id not in self.sent
        ]

    def installations(self, item: OutboxItem) -> list[Installation]:
        return [
            device
            for device in self.devices
            if device.user_id == item.user_id and device.installation_id not in self.disabled
            and (item.id, device.installation_id) not in self.deliveries
        ]

    def mark_sent(self, item_id: int) -> None:
        self.sent.append(item_id)

    def mark_delivery(self, item_id: int, installation_id: str, *, status: str) -> None:
        self.deliveries.add((item_id, installation_id))

    def mark_failed(self, item_id: int, *, error_code: str, retry_at: float | None) -> None:
        self.failures.append((item_id, error_code, retry_at))

    def disable_installation(self, installation_id: str) -> None:
        self.disabled.add(installation_id)

    def actively_viewing(self, **values: object) -> bool:
        return self.viewing


class FakeTransport:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.payloads: list[dict[str, str]] = []

    def send(self, token: str, payload: object) -> None:
        if self.error:
            raise self.error
        self.payloads.append(dict(payload))  # type: ignore[arg-type]


class NotificationTests(unittest.TestCase):
    def test_event_generation_is_deduplicated_and_excludes_ai(self) -> None:
        repository = MemoryNotificationRepository()
        notifications = NotificationService(repository)
        self.assertFalse(
            notifications.notify(
                user_id=None,
                event_type="your_turn",
                dedupe_key="turn:ai",
                session_id="00000000-0000-4000-8000-000000000001",
                title="Your turn",
                body="Move",
            )
        )
        values = dict(
            user_id="human",
            event_type="your_turn",
            dedupe_key="turn:game:7",
            session_id="00000000-0000-4000-8000-000000000001",
            title="Your turn",
            body="Move",
        )
        self.assertTrue(notifications.notify(**values))
        self.assertFalse(notifications.notify(**values))
        self.assertEqual(len(repository.rows), 1)

    def test_turn_is_suppressed_while_game_is_actively_viewed(self) -> None:
        repository = MemoryNotificationRepository()
        repository.viewing = True
        self.assertFalse(
            NotificationService(repository).notify(
                user_id="human",
                event_type="your_turn",
                dedupe_key="turn:game:8",
                session_id="00000000-0000-4000-8000-000000000001",
                title="Your turn",
                body="Move",
            )
        )

    def test_worker_retries_without_blocking_the_outbox(self) -> None:
        repository = MemoryNotificationRepository()
        NotificationService(repository).notify(
            user_id="human", event_type="comrade_request", dedupe_key="social:1",
            title="Request", body="Request"
        )
        worker = NotificationWorker(
            repository, FakeTransport(RuntimeError("offline")), clock=lambda: 100.0
        )
        self.assertEqual(worker.run_once(), 1)
        self.assertEqual(repository.failures, [(1, "transport_error", 105.0)])
        self.assertEqual(repository.sent, [])

    def test_invalid_token_is_disabled_and_item_completes(self) -> None:
        repository = MemoryNotificationRepository()
        NotificationService(repository).notify(
            user_id="human", event_type="game_finished", dedupe_key="finished:1",
            session_id="00000000-0000-4000-8000-000000000001",
            title="Finished", body="Results"
        )
        NotificationWorker(repository, FakeTransport(InvalidPushToken())).run_once()
        self.assertEqual(repository.disabled, {"device-123"})
        self.assertEqual(repository.sent, [1])

    def test_retry_does_not_resend_to_an_installation_that_succeeded(self) -> None:
        repository = MemoryNotificationRepository()
        repository.devices.append(
            Installation("device-456", "human", "failing-token-value", {"turns": True})
        )
        NotificationService(repository).notify(
            user_id="human", event_type="your_turn", dedupe_key="turn:9",
            session_id="00000000-0000-4000-8000-000000000001",
            title="Turn", body="Move"
        )

        class OneFailure(FakeTransport):
            def send(self, token: str, payload: object) -> None:
                if token == "failing-token-value":
                    raise RuntimeError("offline")
                super().send(token, payload)

        transport = OneFailure()
        NotificationWorker(repository, transport, clock=lambda: 10).run_once()
        self.assertEqual(len(transport.payloads), 1)
        NotificationWorker(repository, transport, clock=lambda: 20).run_once()
        self.assertEqual(len(transport.payloads), 1)


if __name__ == "__main__":
    unittest.main()
