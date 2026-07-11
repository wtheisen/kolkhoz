from __future__ import annotations

import threading
import time
from pathlib import Path
from tempfile import TemporaryDirectory

import pytest

from server.kolkhoz_server.commands import (
    CommandBackpressure,
    CommandClient,
    CommandResult,
    CommandTimeout,
    CommandWorker,
    CommandWorkerService,
    GameCommand,
    InMemoryCommandBroker,
    RedisStreamsCommandBroker,
    RoutedGameRuntime,
    RuntimeCommandHandler,
    session_partition,
)
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import RevisionConflict, SQLiteEventStore
from server.kolkhoz_server.api import OnlineApplication, Request
from server.kolkhoz_server.auth import StaticAuthVerifier
from server.kolkhoz_server.lobby import SQLiteLobbyRepository


def command(command_id: str, session_id: str, value: int) -> GameCommand:
    return GameCommand(
        command_id,
        session_id,
        "action",
        {"value": value},
        fencing_token=42,
        expected_revision=value,
    )


def test_partition_is_stable_and_session_commands_remain_ordered():
    broker = InMemoryCommandBroker(partition_count=8)
    seen = []

    for value in range(10):
        broker.publish(command(f"command-{value}", "session-a", value))

    partition = session_partition("session-a", 8)
    worker = CommandWorker(
        broker,
        "worker-a",
        (partition,),
        lambda item: (
            seen.append((item.payload["value"], item.fencing_token))
            or CommandResult(item.command_id, item.session_id, True, {})
        ),
    )
    while worker.run_once():
        pass

    assert seen == [(value, 42) for value in range(10)]
    assert session_partition("session-a", 8) == partition


def test_unacknowledged_command_is_redelivered_to_failover_worker():
    now = [10.0]
    broker = InMemoryCommandBroker(
        partition_count=1,
        visibility_timeout_seconds=5,
        clock=lambda: now[0],
    )
    broker.publish(command("command-1", "session-a", 0))
    abandoned = broker.receive(0, "failed-worker", 0)
    assert abandoned is not None

    now[0] += 6
    redelivered = broker.receive(0, "replacement-worker", 0)

    assert redelivered is not None
    assert redelivered.command == abandoned.command
    assert redelivered.attempts == 2


def test_command_idempotency_returns_canonical_result_without_reexecution():
    broker = InMemoryCommandBroker(partition_count=1)
    executions = []
    worker = CommandWorker(
        broker,
        "worker-a",
        (0,),
        lambda item: (
            executions.append(item.command_id)
            or CommandResult(item.command_id, item.session_id, True, {"revision": 1})
        ),
    )
    item = command("same-command", "session-a", 0)
    broker.publish(item)
    worker.run_once()
    broker.publish(item)
    worker.run_once()

    assert executions == ["same-command"]
    assert broker.result("same-command") == CommandResult(
        "same-command", "session-a", True, {"revision": 1}
    )


def test_poison_command_retries_then_moves_to_dead_letter():
    broker = InMemoryCommandBroker(partition_count=1, max_attempts=3)
    broker.publish(command("poison", "session-a", 0))
    worker = CommandWorker(
        broker,
        "worker-a",
        (0,),
        lambda _item: (_ for _ in ()).throw(ValueError("invalid payload")),
    )

    assert worker.run_once()
    assert worker.run_once()
    assert worker.run_once()
    assert not worker.run_once()
    assert len(broker.dead_letters) == 1
    assert broker.dead_letters[0].error == "invalid payload"
    assert broker.dead_letters[0].delivery.attempts == 3


def test_bounded_partition_rejects_load_and_client_times_out():
    broker = InMemoryCommandBroker(partition_count=1, capacity_per_partition=1)
    broker.publish(command("first", "session-a", 0))
    with pytest.raises(CommandBackpressure):
        broker.publish(command("second", "session-b", 0))

    waiting_broker = InMemoryCommandBroker(partition_count=1)
    with pytest.raises(CommandTimeout):
        CommandClient(waiting_broker).execute(
            command("waiting", "session-c", 0), timeout_seconds=0.001
        )


def test_request_reply_unblocks_when_worker_completes():
    broker = InMemoryCommandBroker(partition_count=1)
    worker = CommandWorker(
        broker,
        "worker-a",
        (0,),
        lambda item: CommandResult(
            item.command_id, item.session_id, True, {"revision": 7}
        ),
    )
    thread = threading.Thread(target=lambda: (time.sleep(0.01), worker.run_once()))
    thread.start()
    result = CommandClient(broker).execute(
        command("request", "session-a", 0), timeout_seconds=1
    )
    thread.join()

    assert result.payload == {"revision": 7}


class FakeStreamsRedis:
    def __init__(self):
        self.streams = {}
        self.pending = {}
        self.values = {}
        self.next_id = 1

    def eval(self, _script, _keys, stream, capacity, encoded, attempts):
        entries = self.streams.setdefault(stream, [])
        if len(entries) >= int(capacity):
            return 0
        delivery_id = f"{self.next_id}-0"
        self.next_id += 1
        entries.append((delivery_id, {"command": encoded, "attempts": str(attempts)}))
        return 1

    def xgroup_create(self, stream, _group, **_kwargs):
        self.streams.setdefault(stream, [])

    def xautoclaim(self, stream, group, consumer, **_kwargs):
        key = (stream, group)
        items = self.pending.get(key, [])
        if not items:
            return ("0-0", [])
        delivery_id, fields, _owner = items[0]
        items[0] = (delivery_id, fields, consumer)
        return (delivery_id, [(delivery_id, fields)])

    def xreadgroup(self, group, consumer, streams, **_kwargs):
        stream = next(iter(streams))
        entries = self.streams[stream]
        pending_ids = {item[0] for item in self.pending.setdefault((stream, group), [])}
        available = [item for item in entries if item[0] not in pending_ids]
        if not available:
            return []
        delivery_id, fields = available[0]
        self.pending[(stream, group)].append((delivery_id, fields, consumer))
        return [(stream, [(delivery_id, fields)])]

    def xack(self, stream, group, delivery_id):
        key = (stream, group)
        self.pending[key] = [
            item for item in self.pending.get(key, []) if item[0] != delivery_id
        ]

    def xadd(self, stream, fields, **_kwargs):
        delivery_id = f"{self.next_id}-0"
        self.next_id += 1
        self.streams.setdefault(stream, []).append((delivery_id, fields))
        return delivery_id

    def set(self, key, value, **_kwargs):
        if key in self.values and _kwargs.get("nx"):
            return False
        self.values[key] = value
        return True

    def get(self, key):
        return self.values.get(key)


def test_redis_streams_adapter_routes_reclaims_and_deduplicates_results():
    redis = FakeStreamsRedis()
    broker = RedisStreamsCommandBroker(
        redis, namespace="test", partition_count=4, max_stream_length=2
    )
    item = command("redis-command", "session-a", 3)
    partition = session_partition("session-a", 4)
    broker.publish(item)

    first = broker.receive(partition, "failed-worker", 0)
    assert first is not None
    reclaimed = broker.receive(partition, "replacement-worker", 0)
    assert reclaimed == first

    accepted = broker.store_result(
        CommandResult(item.command_id, item.session_id, True, {"revision": 4})
    )
    duplicate = broker.store_result(
        CommandResult(item.command_id, item.session_id, False, {}, "duplicate")
    )
    broker.acknowledge(reclaimed)

    assert duplicate == accepted
    assert broker.result(item.command_id) == accepted


def test_redis_streams_capacity_rejects_without_trimming_commands():
    redis = FakeStreamsRedis()
    broker = RedisStreamsCommandBroker(
        redis, namespace="test", partition_count=1, max_stream_length=1
    )
    broker.publish(command("first", "session-a", 0))

    with pytest.raises(CommandBackpressure):
        broker.publish(command("second", "session-b", 0))

    assert len(redis.streams["test:partition:0"]) == 1


class TinyEngine:
    def __init__(self, seed, _variants):
        self.value = seed

    def apply(self, action):
        self.value += int(action["delta"])

    def view(self, viewer_id=None):
        return {"value": self.value, "viewerID": viewer_id}

    def close(self):
        return None


class TinyFactory:
    def create(self, seed, variants):
        return TinyEngine(seed, variants)


def test_routed_runtime_executes_on_remote_worker_and_preserves_domain_errors():
    with TemporaryDirectory() as directory:
        database = Path(directory) / "events.sqlite3"
        worker_runtime = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        gateway_runtime = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        broker = InMemoryCommandBroker(partition_count=4)
        worker = CommandWorkerService(
            CommandWorker(
                broker,
                "remote-owner",
                tuple(range(4)),
                RuntimeCommandHandler(worker_runtime),
            ),
            poll_timeout_seconds=0.01,
        )
        routed = RoutedGameRuntime(
            gateway_runtime, CommandClient(broker), timeout_seconds=1
        )
        worker.start()
        try:
            created = routed.create_game(seed=5, session_id="cross-host")
            updated = routed.submit_action(
                "cross-host", expected_revision=0, action={"delta": 7}
            )
            remote_state = routed.state("cross-host", viewer_id=2)
            with pytest.raises(RevisionConflict):
                routed.submit_action(
                    "cross-host", expected_revision=0, action={"delta": 100}
                )
        finally:
            worker.close()
            gateway_runtime.close()
            worker_runtime.close()

    assert created.state["value"] == 5
    assert updated.state["value"] == 12
    assert updated.revision == 1
    assert remote_state.state == {"value": 12, "viewerID": 2}


def test_two_gateway_apps_rebuild_incremental_updates_without_sticky_routing():
    with TemporaryDirectory() as directory:
        database = Path(directory) / "cross-gateway.sqlite3"
        worker_runtime = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        gateway_a = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        gateway_b = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        broker = InMemoryCommandBroker(partition_count=1)
        worker = CommandWorkerService(
            CommandWorker(
                broker, "remote-owner", (0,), RuntimeCommandHandler(worker_runtime)
            ),
            poll_timeout_seconds=0.01,
        )
        routed_a = RoutedGameRuntime(
            gateway_a, CommandClient(broker), timeout_seconds=1
        )
        routed_b = RoutedGameRuntime(
            gateway_b, CommandClient(broker), timeout_seconds=1
        )
        lobby_a = SQLiteLobbyRepository(database)
        lobby_b = SQLiteLobbyRepository(database)
        auth = StaticAuthVerifier({"token": "user-1"})
        app_a = OnlineApplication(
            routed_a, lobby_a, auth=auth, lobby_countdown_seconds=0
        )
        app_b = OnlineApplication(
            routed_b, lobby_b, auth=auth, lobby_countdown_seconds=0
        )
        headers = {"authorization": "Bearer token"}
        worker.start()
        try:
            created = app_a.dispatch(
                Request("POST", "/sessions", headers, {"seed": 5})
            ).body
            session_id = created["sessionID"]
            seat_token = created["seatToken"]
            lobby_a.set_status(session_id, "active", now=time.time())
            game_headers = {
                **headers,
                "x-kolkhoz-seat-token": seat_token,
            }
            app_a.dispatch(
                Request(
                    "POST",
                    f"/sessions/{session_id}/actions",
                    game_headers,
                    {
                        "playerID": 0,
                        "actionLogCount": 0,
                        "action": {"playerID": 0, "delta": 7},
                    },
                )
            )

            caught_up = app_b.dispatch(
                Request(
                    "GET",
                    f"/sessions/{session_id}/actions?viewerID=0&afterRevision=0",
                    game_headers,
                    {},
                )
            ).body
            assert caught_up["resyncUpdate"] is None
            assert [value["revision"] for value in caught_up["updates"]] == [1]
            assert caught_up["updates"][0]["update"]["snapshot"] == {
                "value": 12,
                "viewerID": 0,
            }

            routed_a.submit_action(
                session_id,
                expected_revision=1,
                action={"playerID": 0, "delta": 1},
            )
            two_frames = app_b.dispatch(
                Request(
                    "GET",
                    f"/sessions/{session_id}/actions?viewerID=0&afterRevision=0",
                    game_headers,
                    {},
                )
            ).body
            assert [
                value["update"]["actionLogCount"] for value in two_frames["updates"]
            ] == [1, 2]
            assert [
                len(value["update"]["gameLogActions"])
                for value in two_frames["updates"]
            ] == [1, 2]

            for expected in range(2, 34):
                routed_a.submit_action(
                    session_id,
                    expected_revision=expected,
                    action={"playerID": 0, "delta": 1},
                )
            stale = app_b.dispatch(
                Request(
                    "GET",
                    f"/sessions/{session_id}/actions?viewerID=0&afterRevision=0",
                    game_headers,
                    {},
                )
            ).body
            assert stale["updates"] == []
            assert stale["resyncUpdate"]["actionLogCount"] == 34
        finally:
            worker.close()
            gateway_a.close()
            gateway_b.close()
            worker_runtime.close()


def test_action_redelivery_after_database_commit_returns_durable_result_once():
    """Model a worker death after COMMIT but before Redis result/XACK."""
    with TemporaryDirectory() as directory:
        database = Path(directory) / "events.sqlite3"
        runtime = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        runtime.create_game(seed=5, session_id="crash-window")
        broker = InMemoryCommandBroker(partition_count=1)
        failures = [1]

        def crash_once(_command, _result):
            if failures:
                failures.pop()
                raise RuntimeError("simulated process death after commit")

        worker = CommandWorker(
            broker,
            "worker-a",
            (0,),
            RuntimeCommandHandler(runtime),
            after_handler=crash_once,
        )
        item = GameCommand(
            "durable-action",
            "crash-window",
            "game.submit_action",
            {"action": {"delta": 7}, "viewerID": 2},
            fencing_token=42,
            expected_revision=0,
        )
        broker.publish(item)

        assert worker.run_once()
        assert broker.result(item.command_id) is None
        assert len(runtime.events("crash-window")) == 1

        assert worker.run_once()
        result = broker.result(item.command_id)
        assert result is not None
        assert result.ok
        assert result.payload == {
            "session_id": "crash-window",
            "revision": 1,
            "state": {"value": 12, "viewerID": 2},
            "event": None,
        }
        assert len(runtime.events("crash-window")) == 1
        assert runtime.state("crash-window").state["value"] == 12
        runtime.close()


def test_autopilot_receipt_survives_crash_redelivery_and_runtime_restart():
    with TemporaryDirectory() as directory:
        database = Path(directory) / "events.sqlite3"
        runtime = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        runtime.create_game(
            seed=5,
            session_id="autopilot-recovery",
            variants={"controllers": ["human"] * 4},
        )
        broker = InMemoryCommandBroker(partition_count=1)
        failures = [1]

        def crash_once(_command, _result):
            if failures:
                failures.pop()
                raise RuntimeError("simulated death after autopilot commit")

        worker = CommandWorker(
            broker,
            "worker-a",
            (0,),
            RuntimeCommandHandler(runtime),
            after_handler=crash_once,
        )
        item = GameCommand(
            "durable-autopilot",
            "autopilot-recovery",
            "game.set_autopilot",
            {"playerID": 0, "controller": "heuristicAI"},
            fencing_token=42,
        )
        broker.publish(item)

        assert worker.run_once()
        assert broker.result(item.command_id) is None
        assert runtime.store.game(item.session_id).revision == 0
        assert (
            runtime.store.game(item.session_id).variants["controllers"][0]
            == "heuristicAI"
        )
        assert worker.run_once()
        assert broker.result(item.command_id) == CommandResult(
            item.command_id, item.session_id, True, {}
        )
        assert runtime.store.game(item.session_id).revision == 0
        runtime.close()

        replacement = GameRuntime(
            SQLiteEventStore(database), engine_factory=TinyFactory(), shard_count=1
        )
        replacement.state(item.session_id)
        shard = replacement._shards[replacement.shard_index(item.session_id)]
        assert (
            shard.automatic_states[item.session_id].effective_controller(0)
            == "heuristicAI"
        )
        replacement.close()
