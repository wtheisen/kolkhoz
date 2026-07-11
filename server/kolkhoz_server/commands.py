"""Durable gateway-to-game-worker command transport.

Commands are partitioned by session ID.  A worker consumes a partition through a
broker consumer group, checks the durable command result before executing, and
propagates the session ownership fencing token to the handler.  Delivery is
at-least-once; handlers must commit the command ID and fencing token with their
game mutation so a crash between mutation and acknowledgement is harmless.
"""

from __future__ import annotations

import json
import logging
import threading
import time
import uuid
import zlib
from collections import deque
from collections.abc import Callable, Mapping
from dataclasses import dataclass, replace
from typing import TYPE_CHECKING, Any, Protocol

if TYPE_CHECKING:
    from .metrics import ServerMetrics


JsonObject = dict[str, Any]


class CommandBackpressure(RuntimeError):
    """The bounded broker cannot accept another command."""


class CommandTimeout(TimeoutError):
    """A command did not produce a result before its request deadline."""


@dataclass(frozen=True, slots=True)
class GameCommand:
    command_id: str
    session_id: str
    kind: str
    payload: Mapping[str, Any]
    fencing_token: int
    expected_revision: int | None = None
    created_at: float = 0.0

    def __post_init__(self) -> None:
        if not self.command_id or not self.session_id or not self.kind:
            raise ValueError("command ID, session ID, and kind are required")
        if self.fencing_token <= 0:
            raise ValueError("fencing token must be positive")


@dataclass(frozen=True, slots=True)
class CommandResult:
    command_id: str
    session_id: str
    ok: bool
    payload: Mapping[str, Any]
    error: str | None = None


@dataclass(frozen=True, slots=True)
class CommandDelivery:
    delivery_id: str
    partition: int
    command: GameCommand
    attempts: int


@dataclass(frozen=True, slots=True)
class DeadLetter:
    delivery: CommandDelivery
    error: str
    failed_at: float


class CommandBroker(Protocol):
    partition_count: int

    def publish(self, command: GameCommand) -> None: ...

    def receive(
        self, partition: int, consumer_id: str, timeout_seconds: float
    ) -> CommandDelivery | None: ...

    def acknowledge(self, delivery: CommandDelivery) -> None: ...

    def retry_or_dead_letter(self, delivery: CommandDelivery, error: str) -> bool: ...

    def store_result(self, result: CommandResult) -> CommandResult: ...

    def result(self, command_id: str) -> CommandResult | None: ...

    def wait_for_result(
        self, command_id: str, timeout_seconds: float
    ) -> CommandResult | None: ...


def session_partition(session_id: str, partition_count: int) -> int:
    """Return a stable partition independent of Python hash randomization."""
    if partition_count <= 0:
        raise ValueError("partition_count must be positive")
    return zlib.crc32(session_id.encode("utf-8")) % partition_count


class CommandClient:
    def __init__(self, broker: CommandBroker) -> None:
        self._broker = broker

    def execute(self, command: GameCommand, timeout_seconds: float) -> CommandResult:
        cached = self._broker.result(command.command_id)
        if cached is not None:
            return cached
        self._broker.publish(command)
        result = self._broker.wait_for_result(command.command_id, timeout_seconds)
        if result is None:
            raise CommandTimeout(f"command {command.command_id} timed out")
        return result


class InMemoryCommandBroker:
    """Deterministic broker used by tests and single-process development."""

    def __init__(
        self,
        *,
        partition_count: int = 16,
        capacity_per_partition: int = 1_024,
        max_attempts: int = 5,
        visibility_timeout_seconds: float = 30.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if min(partition_count, capacity_per_partition, max_attempts) <= 0:
            raise ValueError("partition count, capacity, and attempts must be positive")
        self.partition_count = partition_count
        self._capacity = capacity_per_partition
        self._max_attempts = max_attempts
        self._visibility_timeout = visibility_timeout_seconds
        self._clock = clock
        self._queues = [deque[CommandDelivery]() for _ in range(partition_count)]
        self._pending: dict[str, tuple[CommandDelivery, float]] = {}
        self._results: dict[str, CommandResult] = {}
        self._dead_letters: list[DeadLetter] = []
        self._next_id = 1
        self._condition = threading.Condition()

    @property
    def dead_letters(self) -> tuple[DeadLetter, ...]:
        with self._condition:
            return tuple(self._dead_letters)

    def publish(self, command: GameCommand) -> None:
        partition = session_partition(command.session_id, self.partition_count)
        with self._condition:
            if (
                command.command_id in self._results
                or any(
                    item.command.command_id == command.command_id
                    for item in self._queues[partition]
                )
                or any(
                    item.command.command_id == command.command_id
                    for item, _deadline in self._pending.values()
                )
            ):
                return
            if len(self._queues[partition]) >= self._capacity:
                raise CommandBackpressure(f"command partition {partition} is full")
            delivery = CommandDelivery(
                str(self._next_id), partition, command, attempts=1
            )
            self._next_id += 1
            self._queues[partition].append(delivery)
            self._condition.notify_all()

    def receive(
        self, partition: int, consumer_id: str, timeout_seconds: float
    ) -> CommandDelivery | None:
        del consumer_id
        if not 0 <= partition < self.partition_count:
            raise ValueError("invalid command partition")
        deadline = self._clock() + max(0.0, timeout_seconds)
        with self._condition:
            while True:
                self._redeliver_expired_locked(partition)
                if self._queues[partition]:
                    delivery = self._queues[partition].popleft()
                    self._pending[delivery.delivery_id] = (
                        delivery,
                        self._clock() + self._visibility_timeout,
                    )
                    return delivery
                remaining = deadline - self._clock()
                if remaining <= 0:
                    return None
                self._condition.wait(min(remaining, 0.05))

    def acknowledge(self, delivery: CommandDelivery) -> None:
        with self._condition:
            self._pending.pop(delivery.delivery_id, None)

    def retry_or_dead_letter(self, delivery: CommandDelivery, error: str) -> bool:
        with self._condition:
            self._pending.pop(delivery.delivery_id, None)
            if delivery.attempts >= self._max_attempts:
                self._dead_letters.append(DeadLetter(delivery, error, self._clock()))
                return False
            retried = replace(delivery, attempts=delivery.attempts + 1)
            self._queues[delivery.partition].appendleft(retried)
            self._condition.notify_all()
            return True

    def store_result(self, result: CommandResult) -> CommandResult:
        with self._condition:
            canonical = self._results.setdefault(result.command_id, result)
            self._condition.notify_all()
            return canonical

    def result(self, command_id: str) -> CommandResult | None:
        with self._condition:
            return self._results.get(command_id)

    def wait_for_result(
        self, command_id: str, timeout_seconds: float
    ) -> CommandResult | None:
        deadline = self._clock() + max(0.0, timeout_seconds)
        with self._condition:
            while command_id not in self._results:
                remaining = deadline - self._clock()
                if remaining <= 0:
                    return None
                self._condition.wait(min(remaining, 0.05))
            return self._results[command_id]

    def _redeliver_expired_locked(self, partition: int) -> None:
        now = self._clock()
        expired = [
            delivery_id
            for delivery_id, (delivery, deadline) in self._pending.items()
            if delivery.partition == partition and deadline <= now
        ]
        for delivery_id in expired:
            delivery, _deadline = self._pending.pop(delivery_id)
            if delivery.attempts >= self._max_attempts:
                self._dead_letters.append(
                    DeadLetter(delivery, "visibility timeout", now)
                )
            else:
                self._queues[partition].appendleft(
                    replace(delivery, attempts=delivery.attempts + 1)
                )


class RedisStreamsCommandBroker:
    """Redis Streams production adapter with consumer-group failover."""

    def __init__(
        self,
        client: Any,
        *,
        namespace: str = "kolkhoz:commands",
        partition_count: int = 256,
        max_stream_length: int = 100_000,
        max_attempts: int = 5,
        visibility_timeout_seconds: float = 30.0,
        result_ttl_seconds: int = 86_400,
        metrics: ServerMetrics | None = None,
    ) -> None:
        self._client = client
        self._namespace = namespace.rstrip(":")
        self.partition_count = partition_count
        self._max_stream_length = max_stream_length
        self._max_attempts = max_attempts
        self._visibility_ms = int(visibility_timeout_seconds * 1_000)
        self._result_ttl = result_ttl_seconds
        self._known_groups: set[int] = set()
        self._group_lock = threading.Lock()
        self._metrics = metrics

    @classmethod
    def from_url(cls, url: str, **kwargs: Any) -> RedisStreamsCommandBroker:
        import redis

        return cls(
            redis.Redis.from_url(
                url,
                decode_responses=True,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            ),
            **kwargs,
        )

    def publish(self, command: GameCommand) -> None:
        partition = session_partition(command.session_id, self.partition_count)
        try:
            accepted = self._bounded_xadd(
                self._stream(partition),
                _encode_command(command),
                1,
            )
        except Exception as error:
            if self._metrics is not None:
                self._metrics.increment("redis.command_errors")
                self._metrics.gauge("redis.command_healthy", 0)
            raise CommandBackpressure("command broker rejected the command") from error
        if not accepted:
            if self._metrics is not None:
                self._metrics.increment("redis.command_backpressure")
            raise CommandBackpressure(f"command partition {partition} is full")
        if self._metrics is not None:
            self._metrics.gauge("redis.command_healthy", 1)

    def readiness_check(self) -> None:
        if not self._client.ping():
            raise RuntimeError("Redis command broker ping failed")

    def receive(
        self, partition: int, consumer_id: str, timeout_seconds: float
    ) -> CommandDelivery | None:
        self._ensure_group(partition)
        stream = self._stream(partition)
        claimed = self._client.xautoclaim(
            stream,
            self._group(partition),
            consumer_id,
            min_idle_time=self._visibility_ms,
            start_id="0-0",
            count=1,
        )
        messages = claimed[1] if len(claimed) > 1 else []
        if not messages:
            batches = self._client.xreadgroup(
                self._group(partition),
                consumer_id,
                {stream: ">"},
                count=1,
                block=max(0, int(timeout_seconds * 1_000)),
            )
            messages = batches[0][1] if batches else []
        if not messages:
            return None
        delivery_id, fields = messages[0]
        delivery = CommandDelivery(
            delivery_id=str(delivery_id),
            partition=partition,
            command=_decode_command(fields["command"]),
            attempts=int(fields.get("attempts", 1)),
        )
        if self._metrics is not None:
            self._metrics.observe(
                "redis.command_lag",
                max(0.0, time.time() - delivery.command.created_at)
                if delivery.command.created_at
                else 0.0,
            )
        return delivery

    def acknowledge(self, delivery: CommandDelivery) -> None:
        self._client.xack(
            self._stream(delivery.partition),
            self._group(delivery.partition),
            delivery.delivery_id,
        )

    def retry_or_dead_letter(self, delivery: CommandDelivery, error: str) -> bool:
        if delivery.attempts >= self._max_attempts:
            if self._metrics is not None:
                self._metrics.increment("redis.command_dlq")
            self._client.xadd(
                f"{self._namespace}:dead-letter",
                {
                    "command": _encode_command(delivery.command),
                    "attempts": str(delivery.attempts),
                    "error": error,
                    "failedAt": str(time.time()),
                },
                maxlen=self._max_stream_length,
                approximate=True,
            )
            self.acknowledge(delivery)
            return False
        accepted = self._bounded_xadd(
            self._stream(delivery.partition),
            _encode_command(delivery.command),
            delivery.attempts + 1,
        )
        if not accepted:
            # Leave the original pending. Another owner will reclaim it after the
            # visibility timeout instead of losing it under broker pressure.
            return True
        self.acknowledge(delivery)
        return True

    def store_result(self, result: CommandResult) -> CommandResult:
        key = self._result_key(result.command_id)
        encoded = _encode_result(result)
        if self._client.set(key, encoded, nx=True, ex=self._result_ttl):
            return result
        existing = self.result(result.command_id)
        return existing if existing is not None else result

    def result(self, command_id: str) -> CommandResult | None:
        encoded = self._client.get(self._result_key(command_id))
        return _decode_result(encoded) if encoded is not None else None

    def wait_for_result(
        self, command_id: str, timeout_seconds: float
    ) -> CommandResult | None:
        deadline = time.monotonic() + max(0.0, timeout_seconds)
        delay = 0.005
        while time.monotonic() < deadline:
            result = self.result(command_id)
            if result is not None:
                return result
            time.sleep(min(delay, max(0.0, deadline - time.monotonic())))
            delay = min(delay * 2, 0.05)
        return self.result(command_id)

    def _ensure_group(self, partition: int) -> None:
        if partition in self._known_groups:
            return
        with self._group_lock:
            if partition in self._known_groups:
                return
            try:
                self._client.xgroup_create(
                    self._stream(partition),
                    self._group(partition),
                    id="0-0",
                    mkstream=True,
                )
            except Exception as error:
                if "BUSYGROUP" not in str(error):
                    raise
            self._known_groups.add(partition)

    def _stream(self, partition: int) -> str:
        if not 0 <= partition < self.partition_count:
            raise ValueError("invalid command partition")
        return f"{self._namespace}:partition:{partition}"

    def _group(self, partition: int) -> str:
        return f"{self._namespace}:workers:{partition}"

    def _result_key(self, command_id: str) -> str:
        return f"{self._namespace}:result:{command_id}"

    def _bounded_xadd(self, stream: str, encoded: str, attempts: int) -> bool:
        # MAXLEN trimming is not safe here: it can discard an entry that has not
        # been consumed. The Lua check makes capacity admission and XADD atomic.
        script = """
        if redis.call('XLEN', KEYS[1]) >= tonumber(ARGV[1]) then
          return false
        end
        redis.call('XADD', KEYS[1], '*', 'command', ARGV[2], 'attempts', ARGV[3])
        return true
        """
        return bool(
            self._client.eval(
                script,
                1,
                stream,
                self._max_stream_length,
                encoded,
                attempts,
            )
        )


class CommandWorker:
    """Consume assigned partitions and invoke a fenced game-command handler."""

    def __init__(
        self,
        broker: CommandBroker,
        consumer_id: str,
        partitions: tuple[int, ...],
        handler: Callable[[GameCommand], CommandResult],
        after_handler: Callable[[GameCommand, CommandResult], None] | None = None,
    ) -> None:
        if not partitions:
            raise ValueError("worker must own at least one command partition")
        if len(set(partitions)) != len(partitions) or any(
            partition < 0 or partition >= broker.partition_count
            for partition in partitions
        ):
            raise ValueError("worker command partitions must be unique and in range")
        self._broker = broker
        self._consumer_id = consumer_id
        self._partitions = partitions
        self._handler = handler
        self._after_handler = after_handler
        self._stop = threading.Event()

    def run_once(self, timeout_seconds: float = 0.0) -> bool:
        per_partition = timeout_seconds / len(self._partitions)
        for partition in self._partitions:
            delivery = self._broker.receive(partition, self._consumer_id, per_partition)
            if delivery is None:
                continue
            cached = self._broker.result(delivery.command.command_id)
            if cached is not None:
                self._broker.acknowledge(delivery)
                return True
            try:
                result = self._handler(delivery.command)
                if result.command_id != delivery.command.command_id:
                    raise ValueError("handler returned a mismatched command ID")
                if self._after_handler is not None:
                    self._after_handler(delivery.command, result)
                self._broker.store_result(result)
                self._broker.acknowledge(delivery)
            except Exception as error:
                self._broker.retry_or_dead_letter(delivery, str(error))
            return True
        return False

    def run(self, poll_timeout_seconds: float = 1.0) -> None:
        broker_unavailable = False
        while not self._stop.is_set():
            try:
                self.run_once(poll_timeout_seconds)
                if broker_unavailable:
                    logging.info("command broker receive recovered")
                    broker_unavailable = False
            except Exception:
                # Redis interruption must not permanently remove this process's
                # partition ownership. The broker client reconnects lazily on the
                # next call; bound retry pressure while the dependency is down.
                if not broker_unavailable:
                    logging.exception("command broker receive failed; retrying")
                    broker_unavailable = True
                self._stop.wait(min(max(poll_timeout_seconds, 0.1), 1.0))

    def stop(self) -> None:
        self._stop.set()


class CommandWorkerService:
    """Own the production consumer thread and its bounded shutdown."""

    def __init__(self, worker: CommandWorker, *, poll_timeout_seconds: float = 0.25):
        self._worker = worker
        self._poll_timeout = poll_timeout_seconds
        self._thread = threading.Thread(
            target=worker.run,
            args=(poll_timeout_seconds,),
            name="kolkhoz-command-worker",
            daemon=True,
        )

    def start(self) -> None:
        self._thread.start()

    def close(self) -> None:
        self._worker.stop()
        self._thread.join(timeout=max(2.0, self._poll_timeout * 2))


class RuntimeCommandHandler:
    """Decode durable commands into the small serializable runtime mutation API."""

    def __init__(self, runtime: Any) -> None:
        self._runtime = runtime

    def __call__(self, command: GameCommand) -> CommandResult:
        try:
            if command.kind in {
                "game.create",
                "game.submit_action",
                "game.set_autopilot",
                "game.delete",
            }:
                durable = self._runtime.store.command_receipt(command.command_id)
                if durable is not None:
                    return _decode_durable_result(durable)
            payload = command.payload
            if command.kind == "game.create":
                update = self._runtime.create_game(
                    seed=int(payload["seed"]),
                    variants=dict(payload.get("variants") or {}),
                    session_id=command.session_id,
                    command_id=command.command_id,
                    command_fencing_token=command.fencing_token,
                )
                value: JsonObject = _update_json(update)
            elif command.kind == "game.state":
                value = _update_json(
                    self._runtime.state(
                        command.session_id, viewer_id=payload.get("viewerID")
                    )
                )
            elif command.kind == "game.submit_action":
                if command.expected_revision is None:
                    raise ValueError("submit action requires an expected revision")
                update = self._runtime.submit_action(
                    command.session_id,
                    expected_revision=command.expected_revision,
                    action=dict(payload["action"]),
                    viewer_id=payload.get("viewerID"),
                    command_id=command.command_id,
                    command_fencing_token=command.fencing_token,
                )
                durable = self._runtime.store.command_receipt(command.command_id)
                if durable is None:
                    raise RuntimeError("action committed without its command receipt")
                return _decode_durable_result(durable)
            elif command.kind == "game.advance_automatic":
                # This is a deterministic sequence of individually committed events.
                # A crash may change the retry's `advanced` count, but replay/CAS
                # prevents an already committed action from being applied twice.
                value = {
                    "advanced": self._runtime.advance_automatic(
                        command.session_id, now=payload.get("now")
                    )
                }
            elif command.kind == "game.set_autopilot":
                self._runtime.set_autopilot(
                    command.session_id,
                    int(payload["playerID"]),
                    str(payload.get("controller") or "heuristicAI"),
                    command_id=command.command_id,
                    command_fencing_token=command.fencing_token,
                )
                durable = self._runtime.store.command_receipt(command.command_id)
                if durable is None:
                    raise RuntimeError(
                        "autopilot committed without its command receipt"
                    )
                return _decode_durable_result(durable)
            elif command.kind == "game.delete":
                self._runtime.delete_game(
                    command.session_id,
                    command_id=command.command_id,
                    command_fencing_token=command.fencing_token,
                )
                durable = self._runtime.store.command_receipt(command.command_id)
                if durable is None:
                    raise RuntimeError("delete committed without its command receipt")
                return _decode_durable_result(durable)
            elif command.kind == "game.invalidate":
                self._runtime.invalidate_session(command.session_id)
                value = {}
            else:
                raise ValueError(f"unsupported game command: {command.kind}")
            return CommandResult(command.command_id, command.session_id, True, value)
        except Exception as error:
            # Domain errors are stable command results, not poison messages. Broker
            # failures and process crashes still escape the worker and are retried.
            from .errors import ServerError
            from .store import GameNotFound, RevisionConflict

            if isinstance(error, ServerError) and error.status >= 500:
                # Lease contention, overload, and transient owner failure must be
                # redelivered; caching them would pin a command to the wrong host.
                raise
            if not isinstance(
                error, (GameNotFound, RevisionConflict, ServerError, ValueError)
            ):
                raise
            details: JsonObject = {
                "type": type(error).__name__,
                "message": str(error),
            }
            if isinstance(error, RevisionConflict):
                details.update({"expected": error.expected, "actual": error.actual})
            if isinstance(error, ServerError):
                details["status"] = error.status
            return CommandResult(
                command.command_id,
                command.session_id,
                False,
                details,
                str(error),
            )


class RoutedGameRuntime:
    """Gateway facade: route mutations, retain local reads and dev behavior."""

    def __init__(
        self,
        local_runtime: Any,
        client: CommandClient,
        *,
        fencing_token: int = 1,
        timeout_seconds: float = 10,
    ) -> None:
        self._local = local_runtime
        self._client = client
        self._fencing_token = fencing_token
        self._timeout = timeout_seconds
        self.store = local_runtime.store
        self.hub = local_runtime.hub
        self.owner_id = local_runtime.owner_id
        self._projectors: dict[
            str, Callable[[Any, int, bool], Mapping[int | None, JsonObject]]
        ] = {}

    def __getattr__(self, name: str) -> Any:
        return getattr(self._local, name)

    def serialize(self, session_id: str, operation: Callable[[], Any]) -> Any:
        # Metadata repositories provide their own database transactions. Closures
        # cannot cross a process boundary and must not acquire an engine lease.
        del session_id
        return operation()

    def create_game(
        self,
        *,
        seed: int,
        variants: JsonObject | None = None,
        session_id: str | None = None,
    ) -> Any:
        resolved = session_id or str(uuid.uuid4())
        return self._update(
            self._send(
                resolved,
                "game.create",
                {"seed": seed, "variants": dict(variants or {})},
            )
        )

    def submit_action(
        self,
        session_id: str,
        *,
        expected_revision: int,
        action: JsonObject,
        viewer_id: int | None = None,
        authorize: Callable[[], None] | None = None,
    ) -> Any:
        if authorize is not None:
            authorize()
        return self._update(
            self._send(
                session_id,
                "game.submit_action",
                {"action": action, "viewerID": viewer_id},
                expected_revision=expected_revision,
            )
        )

    def state(self, session_id: str, viewer_id: int | None = None) -> Any:
        return self._update(
            self._send(session_id, "game.state", {"viewerID": viewer_id})
        )

    def record_reaction(
        self,
        session_id: str,
        persist: Callable[[], Mapping[str, object]],
    ) -> JsonObject:
        # Reactions are already durable lobby rows and are returned by catch-up.
        # They do not mutate C-engine state, so no engine-owner lease is needed.
        del session_id
        return dict(persist())

    def advance_automatic(self, session_id: str, *, now: float | None = None) -> int:
        return int(
            self._send(session_id, "game.advance_automatic", {"now": now})["advanced"]
        )

    def set_autopilot(
        self, session_id: str, player_id: int, controller: str = "heuristicAI"
    ) -> None:
        self._send(
            session_id,
            "game.set_autopilot",
            {"playerID": player_id, "controller": controller},
        )

    def delete_game(self, session_id: str) -> None:
        self._send(session_id, "game.delete", {})

    def invalidate_session(self, session_id: str) -> None:
        self._send(session_id, "game.invalidate", {})

    def register_projector(
        self,
        session_id: str,
        projector: Callable[[Any, int, bool], Mapping[int | None, JsonObject]],
    ) -> None:
        # Projectors close over gateway-side profile/lobby services and therefore
        # cannot be serialized to the remote game worker.
        self._projectors[session_id] = projector

    def updates_since(
        self,
        session_id: str,
        *,
        after_revision: int,
        viewer_id: int | None,
        resync_update: Callable[[], Mapping[str, object]],
        after_reaction_revision: int | None = None,
        durable_reactions: list[Mapping[str, object]] | None = None,
    ) -> JsonObject:
        from .updates import ACTION_UPDATE_CACHE_LIMIT, ShardUpdateBuffer

        record = self.store.game(session_id)
        if after_revision < 0 or after_revision > record.revision:
            from .updates import UnknownRevision

            raise UnknownRevision("action", after_revision, record.revision)
        reactions = durable_reactions or []
        reaction_revision = max(
            (int(value["revision"]) for value in reactions), default=0
        )
        buffer = ShardUpdateBuffer(
            session_id,
            current_revision=after_revision,
            reaction_revision=reaction_revision,
        )
        if record.revision - after_revision > ACTION_UPDATE_CACHE_LIMIT:
            # An intentionally empty cache makes ShardUpdateBuffer choose its
            # established full-resync contract for gaps outside bounded retention.
            buffer.current_revision = record.revision
        elif record.revision > after_revision:
            projector = self._projectors.get(session_id)
            if projector is None:
                return {
                    "sessionID": session_id,
                    "actionLogCount": record.revision,
                    "reactionLogCount": reaction_revision,
                    "updates": [],
                    "reactions": [],
                    "resyncUpdate": dict(resync_update()),
                }
            for revision, action, projections in self._local.replay_action_projections(
                session_id,
                after_revision=after_revision,
                projector=projector,
            ):
                buffer.record_action(revision, action, projections)
        return buffer.updates_since(
            after_revision,
            viewer_id,
            resync_update=resync_update,
            after_reaction_revision=after_reaction_revision,
            durable_reactions=reactions,
        )

    def close(self) -> None:
        # The worker lifecycle owns the local runtime. Gateway shutdown must not
        # race it or close the shared store twice.
        return None

    def _send(
        self,
        session_id: str,
        kind: str,
        payload: JsonObject,
        *,
        expected_revision: int | None = None,
    ) -> JsonObject:
        result = self._client.execute(
            GameCommand(
                command_id=str(uuid.uuid4()),
                session_id=session_id,
                kind=kind,
                payload=payload,
                fencing_token=self._fencing_token,
                expected_revision=expected_revision,
                created_at=time.time(),
            ),
            self._timeout,
        )
        if not result.ok:
            _raise_remote_error(result)
        return dict(result.payload)

    @staticmethod
    def _update(payload: JsonObject) -> Any:
        from .model import GameUpdate, StoredEvent

        event_payload = payload.get("event")
        event = StoredEvent(**event_payload) if event_payload is not None else None
        return GameUpdate(
            payload["session_id"],
            int(payload["revision"]),
            dict(payload["state"]),
            event,
        )


def _update_json(update: Any) -> JsonObject:
    event = update.event
    return {
        "session_id": update.session_id,
        "revision": update.revision,
        "state": update.state,
        "event": (
            {
                "session_id": event.session_id,
                "revision": event.revision,
                "kind": event.kind,
                "payload": event.payload,
                "created_at": event.created_at,
            }
            if event is not None
            else None
        ),
    }


def _decode_durable_result(value: Mapping[str, Any]) -> CommandResult:
    return CommandResult(
        command_id=str(value["command_id"]),
        session_id=str(value["session_id"]),
        ok=bool(value["ok"]),
        payload=dict(value.get("payload") or {}),
        error=str(value["error"]) if value.get("error") is not None else None,
    )


def _raise_remote_error(result: CommandResult) -> None:
    from .errors import ServerError
    from .store import GameNotFound, RevisionConflict

    error_type = result.payload.get("type")
    message = str(result.payload.get("message") or result.error or "command failed")
    if error_type == "RevisionConflict":
        raise RevisionConflict(
            int(result.payload["expected"]), int(result.payload["actual"])
        )
    if error_type == "GameNotFound":
        raise GameNotFound(message)
    if error_type == "ServerError":
        raise ServerError(int(result.payload.get("status", 500)), message)
    raise ValueError(message)


def _encode_command(command: GameCommand) -> str:
    return json.dumps(
        {
            "commandId": command.command_id,
            "sessionId": command.session_id,
            "kind": command.kind,
            "payload": command.payload,
            "fencingToken": command.fencing_token,
            "expectedRevision": command.expected_revision,
            "createdAt": command.created_at,
        },
        separators=(",", ":"),
        sort_keys=True,
    )


def _decode_command(encoded: str | bytes) -> GameCommand:
    decoded = json.loads(encoded)
    return GameCommand(
        command_id=decoded["commandId"],
        session_id=decoded["sessionId"],
        kind=decoded["kind"],
        payload=decoded["payload"],
        fencing_token=int(decoded["fencingToken"]),
        expected_revision=decoded.get("expectedRevision"),
        created_at=float(decoded.get("createdAt", 0.0)),
    )


def _encode_result(result: CommandResult) -> str:
    return json.dumps(
        {
            "commandId": result.command_id,
            "sessionId": result.session_id,
            "ok": result.ok,
            "payload": result.payload,
            "error": result.error,
        },
        separators=(",", ":"),
        sort_keys=True,
    )


def _decode_result(encoded: str | bytes) -> CommandResult:
    decoded = json.loads(encoded)
    return CommandResult(
        command_id=decoded["commandId"],
        session_id=decoded["sessionId"],
        ok=bool(decoded["ok"]),
        payload=decoded["payload"],
        error=decoded.get("error"),
    )
