"""Durable, token-safe push notification delivery."""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass
from typing import Callable, Mapping, Protocol

from .metrics import ServerMetrics


PREFERENCE_FOR_EVENT = {
    "comrade_request": "social",
    "comrade_accepted": "social",
    "game_invitation": "invites",
    "invitation_accepted": "invites",
    "game_started": "invites",
    "your_turn": "turns",
    "game_finished": "results",
}


@dataclass(frozen=True)
class Installation:
    installation_id: str
    user_id: str
    token: str
    preferences: Mapping[str, bool]


@dataclass(frozen=True)
class OutboxItem:
    id: int
    user_id: str
    event_type: str
    payload: Mapping[str, str]
    attempts: int


class InvalidPushToken(Exception):
    pass


class PushTransport(Protocol):
    def send(self, token: str, payload: Mapping[str, str]) -> None: ...


class NotificationRepository(Protocol):
    def register_installation(
        self,
        *,
        installation_id: str,
        user_id: str,
        platform: str,
        token: str,
        preferences: Mapping[str, bool],
    ) -> None: ...

    def delete_installation(self, *, installation_id: str, user_id: str) -> bool: ...
    def enqueue(
        self,
        *,
        user_id: str,
        event_type: str,
        dedupe_key: str,
        payload: Mapping[str, str],
    ) -> bool: ...
    def claim(self, *, limit: int, lock_seconds: float) -> list[OutboxItem]: ...
    def installations(self, item: OutboxItem) -> list[Installation]: ...
    def mark_sent(self, item_id: int) -> None: ...
    def mark_delivery(
        self, item_id: int, installation_id: str, *, status: str
    ) -> None: ...
    def mark_failed(
        self, item_id: int, *, error_code: str, retry_at: float | None
    ) -> None: ...
    def disable_installation(self, installation_id: str) -> None: ...
    def actively_viewing(
        self, *, user_id: str, session_id: str, since: float
    ) -> bool: ...


class PostgresNotificationRepository:
    def __init__(self, pool: object) -> None:
        try:
            from psycopg.types.json import Jsonb
        except ImportError as error:
            raise RuntimeError("PostgreSQL notifications require psycopg") from error
        self._pool = pool
        self._jsonb = Jsonb

    def register_installation(
        self,
        *,
        installation_id: str,
        user_id: str,
        platform: str,
        token: str,
        preferences: Mapping[str, bool],
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():
            connection.execute(
                """insert into server_push_installations
                       (installation_id,user_id,platform,token,preferences,enabled,updated_at)
                     values (%s,%s,%s,%s,%s,true,now())
                     on conflict (installation_id) do update set
                       user_id=excluded.user_id, platform=excluded.platform,
                       token=excluded.token, preferences=excluded.preferences,
                       enabled=true, updated_at=now()""",
                (
                    installation_id,
                    user_id,
                    platform,
                    token,
                    self._jsonb(dict(preferences)),
                ),
            )

    def delete_installation(self, *, installation_id: str, user_id: str) -> bool:
        with self._pool.connection() as connection, connection.transaction():
            row = connection.execute(
                "delete from server_push_installations where installation_id=%s and user_id=%s returning installation_id",
                (installation_id, user_id),
            ).fetchone()
        return row is not None

    def enqueue(
        self,
        *,
        user_id: str,
        event_type: str,
        dedupe_key: str,
        payload: Mapping[str, str],
    ) -> bool:
        with self._pool.connection() as connection, connection.transaction():
            row = connection.execute(
                """insert into server_notification_outbox
                       (user_id,event_type,dedupe_key,payload)
                     values (%s,%s,%s,%s) on conflict (dedupe_key) do nothing
                     returning id""",
                (user_id, event_type, dedupe_key, self._jsonb(dict(payload))),
            ).fetchone()
        return row is not None

    def claim(self, *, limit: int, lock_seconds: float) -> list[OutboxItem]:
        with self._pool.connection() as connection, connection.transaction():
            rows = connection.execute(
                """with due as (
                       select id from server_notification_outbox
                        where status in ('pending','sending')
                          and next_attempt_at <= now()
                          and (locked_until is null or locked_until < now())
                        order by id for update skip locked limit %s
                     )
                     update server_notification_outbox o set
                       status='sending', attempts=o.attempts+1,
                       locked_until=now()+(%s * interval '1 second')
                     from due where o.id=due.id
                     returning o.id,o.user_id,o.event_type,o.payload,o.attempts""",
                (limit, lock_seconds),
            ).fetchall()
        return [
            OutboxItem(int(r[0]), str(r[1]), str(r[2]), dict(r[3]), int(r[4]))
            for r in rows
        ]

    def installations(self, item: OutboxItem) -> list[Installation]:
        preference = PREFERENCE_FOR_EVENT[item.event_type]
        with self._pool.connection() as connection:
            rows = connection.execute(
                """select i.installation_id,i.user_id,i.token,i.preferences
                     from server_push_installations i
                     left join server_notification_deliveries d
                       on d.outbox_id=%s and d.installation_id=i.installation_id
                     where i.user_id=%s and i.enabled and d.outbox_id is null
                       and coalesce((i.preferences->>%s)::boolean,true)""",
                (item.id, item.user_id, preference),
            ).fetchall()
        return [Installation(str(r[0]), str(r[1]), str(r[2]), dict(r[3])) for r in rows]

    def mark_sent(self, item_id: int) -> None:
        with self._pool.connection() as connection, connection.transaction():
            connection.execute(
                "update server_notification_outbox set status='sent',sent_at=now(),locked_until=null,last_error_code=null where id=%s",
                (item_id,),
            )

    def mark_delivery(self, item_id: int, installation_id: str, *, status: str) -> None:
        if status not in {"delivered", "invalid"}:
            raise ValueError("invalid delivery status")
        with self._pool.connection() as connection, connection.transaction():
            connection.execute(
                """insert into server_notification_deliveries
                       (outbox_id,installation_id,status)
                     values (%s,%s,%s) on conflict do nothing""",
                (item_id, installation_id, status),
            )

    def mark_failed(
        self, item_id: int, *, error_code: str, retry_at: float | None
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():
            connection.execute(
                """update server_notification_outbox set status=%s,
                       next_attempt_at=coalesce(to_timestamp(%s),next_attempt_at),
                       locked_until=null,last_error_code=%s where id=%s""",
                (
                    "pending" if retry_at is not None else "failed",
                    retry_at,
                    error_code,
                    item_id,
                ),
            )

    def disable_installation(self, installation_id: str) -> None:
        with self._pool.connection() as connection, connection.transaction():
            connection.execute(
                "update server_push_installations set enabled=false,updated_at=now() where installation_id=%s",
                (installation_id,),
            )

    def actively_viewing(self, *, user_id: str, session_id: str, since: float) -> bool:
        with self._pool.connection() as connection:
            return (
                connection.execute(
                    """select 1 from server_device_leases where user_id=%s
                     and session_id=%s::uuid and last_seen_at>=to_timestamp(%s) limit 1""",
                    (user_id, session_id, since),
                ).fetchone()
                is not None
            )


class FirebasePushTransport:
    def __init__(self, *, project_id: str) -> None:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            firebase_admin.initialize_app(
                credentials.ApplicationDefault(), {"projectId": project_id}
            )

    def send(self, token: str, payload: Mapping[str, str]) -> None:
        from firebase_admin import exceptions, messaging

        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    data=dict(payload),
                    notification=messaging.Notification(
                        title=payload.get("title", "Kolkhoz"),
                        body=payload.get("body", "Kolkhoz has an update."),
                    ),
                    apns=messaging.APNSConfig(
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(sound="default", content_available=True)
                        )
                    ),
                )
            )
        except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as error:
            raise InvalidPushToken from error
        except exceptions.FirebaseError:
            raise


class NotificationService:
    def __init__(self, repository: NotificationRepository) -> None:
        self.repository = repository

    def notify(
        self,
        *,
        user_id: str | None,
        event_type: str,
        dedupe_key: str,
        session_id: str | None = None,
        title: str,
        body: str,
    ) -> bool:
        if not user_id or event_type not in PREFERENCE_FOR_EVENT:
            return False
        if (
            event_type == "your_turn"
            and session_id
            and self.repository.actively_viewing(
                user_id=user_id, session_id=session_id, since=time.time() - 35
            )
        ):
            return False
        payload = {"type": event_type, "title": title, "body": body}
        if session_id:
            payload["sessionID"] = session_id
        return self.repository.enqueue(
            user_id=user_id,
            event_type=event_type,
            dedupe_key=dedupe_key,
            payload=payload,
        )


class NotificationWorker:
    def __init__(
        self,
        repository: NotificationRepository,
        transport: PushTransport,
        *,
        metrics: ServerMetrics | None = None,
        max_attempts: int = 8,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.repository, self.transport = repository, transport
        self.metrics, self.max_attempts, self.clock = (
            metrics or ServerMetrics(),
            max_attempts,
            clock,
        )

    def run_once(self, *, limit: int = 32) -> int:
        items = self.repository.claim(limit=limit, lock_seconds=60)
        for item in items:
            failed = False
            for installation in self.repository.installations(item):
                try:
                    self.transport.send(installation.token, item.payload)
                    self.repository.mark_delivery(
                        item.id, installation.installation_id, status="delivered"
                    )
                    self.metrics.increment("notifications.delivered")
                except InvalidPushToken:
                    self.repository.disable_installation(installation.installation_id)
                    self.repository.mark_delivery(
                        item.id, installation.installation_id, status="invalid"
                    )
                    self.metrics.increment("notifications.invalid_token")
                except Exception:
                    failed = True
                    logging.warning(
                        "notification delivery failed",
                        extra={"event_type": item.event_type},
                    )
                    self.metrics.increment("notifications.delivery_failure")
            if failed:
                retry_at = (
                    None
                    if item.attempts >= self.max_attempts
                    else self.clock() + min(3600, 5 * 2 ** (item.attempts - 1))
                )
                self.repository.mark_failed(
                    item.id, error_code="transport_error", retry_at=retry_at
                )
            else:
                self.repository.mark_sent(item.id)
        return len(items)


class NotificationWorkerService:
    def __init__(
        self, worker: NotificationWorker, *, interval_seconds: float = 1
    ) -> None:
        self.worker, self.interval_seconds = worker, interval_seconds
        self._stop = threading.Event()
        self._thread = threading.Thread(
            target=self._run, name="notification-outbox", daemon=True
        )
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.wait(self.interval_seconds):
            try:
                self.worker.run_once()
            except Exception:
                logging.exception("notification worker iteration failed")

    def close(self) -> None:
        self._stop.set()
        self._thread.join(timeout=5)
