from __future__ import annotations

import hashlib
import queue
import threading
import time
import uuid
from concurrent.futures import Future
from dataclasses import dataclass
from typing import Callable, Mapping, TypeVar

from .engine import EngineFactory, GameEngine, KolkhozCEngineFactory
from .events import EventHub
from .ai import AutomaticAdvancer, AutomaticState
from .model import GameUpdate, JsonObject
from .store import EventStore
from .updates import ShardUpdateBuffer


Result = TypeVar("Result")


@dataclass
class _Envelope:
    session_id: str
    operation: Callable[["_Shard", GameEngine | None], object]
    result: Future[object]


class _Shard:
    def __init__(
        self,
        index: int,
        store: EventStore,
        factory: EngineFactory,
        hub: EventHub,
        advancer: AutomaticAdvancer[object] | None,
    ):
        self.index = index
        self.store = store
        self.factory = factory
        self.hub = hub
        self.advancer = advancer
        self.engines: dict[str, GameEngine] = {}
        self.automatic_states: dict[str, AutomaticState] = {}
        self.update_buffers: dict[str, ShardUpdateBuffer] = {}
        self.projectors: dict[
            str, Callable[[GameEngine], Mapping[int | None, JsonObject]]
        ] = {}
        self.mailbox: queue.Queue[_Envelope | None] = queue.Queue(maxsize=4096)
        self.thread = threading.Thread(
            target=self._run, name=f"kolkhoz-game-shard-{index}", daemon=True
        )
        self.thread.start()

    def _run(self) -> None:
        while True:
            envelope = self.mailbox.get()
            if envelope is None:
                return
            try:
                engine = self.engines.get(envelope.session_id)
                envelope.result.set_result(envelope.operation(self, engine))
            except BaseException as error:
                envelope.result.set_exception(error)

    def load(self, session_id: str) -> GameEngine:
        engine = self.engines.get(session_id)
        if engine is not None:
            return engine
        record = self.store.game(session_id)
        engine = self.factory.create(record.seed, record.variants)
        for event in self.store.events(session_id):
            if event.kind == "action":
                engine.apply(event.payload)
        self.engines[session_id] = engine
        self.automatic_states[session_id] = self._automatic_state(
            session_id, record.variants, record.revision
        )
        self.update_buffers[session_id] = ShardUpdateBuffer(
            session_id, current_revision=record.revision
        )
        return engine

    @staticmethod
    def _automatic_state(
        session_id: str, settings: JsonObject, revision: int
    ) -> AutomaticState:
        controllers = settings.get("controllers")
        return AutomaticState(
            session_id,
            tuple(controllers) if isinstance(controllers, list) else ("human",) * 4,
            action_count=revision,
        )

    def close(self) -> None:
        self.mailbox.put(None)
        self.thread.join(timeout=5)
        for engine in self.engines.values():
            engine.close()
        self.engines.clear()
        self.automatic_states.clear()
        self.update_buffers.clear()
        self.projectors.clear()


class GameRuntime:
    """Routes a session to exactly one single-threaded owner shard."""

    def __init__(
        self,
        store: EventStore,
        *,
        engine_factory: EngineFactory | None = None,
        shard_count: int = 8,
        event_hub: EventHub | None = None,
        automatic_advancer: AutomaticAdvancer[object] | None = None,
    ) -> None:
        if shard_count < 1:
            raise ValueError("shard_count must be positive")
        self.store = store
        self.hub = event_hub or EventHub()
        factory = engine_factory or KolkhozCEngineFactory()
        self._factory = factory
        self._shards = [
            _Shard(index, store, factory, self.hub, automatic_advancer)
            for index in range(shard_count)
        ]

    def shard_index(self, session_id: str) -> int:
        digest = hashlib.blake2b(session_id.encode(), digest_size=8).digest()
        return int.from_bytes(digest, "big") % len(self._shards)

    def metrics_state(self) -> dict[str, object]:
        return {
            "activeSessions": sum(len(shard.engines) for shard in self._shards),
            "shards": len(self._shards),
            "shardQueues": [shard.mailbox.qsize() for shard in self._shards],
            "persistenceQueueDepth": 0,
            "persistenceError": None,
        }

    def health_state(self) -> dict[str, object]:
        provenance = getattr(self._factory, "provenance", None)
        details = provenance() if provenance is not None else {}
        return {
            "status": "ok",
            "gitSHA": details.get("gitSHA", "unknown"),
            "engineSHA256": details.get("engineSHA256", "unknown"),
        }

    def _execute(
        self,
        session_id: str,
        operation: Callable[[_Shard, GameEngine | None], object],
    ) -> object:
        future: Future[object] = Future()
        shard = self._shards[self.shard_index(session_id)]
        shard.mailbox.put(_Envelope(session_id, operation, future), timeout=2)
        return future.result(timeout=10)

    def serialize(self, session_id: str, operation: Callable[[], Result]) -> Result:
        """Run session metadata work on the same ordered mailbox as engine work."""

        def invoke(shard: _Shard, engine: GameEngine | None) -> Result:
            return operation()

        return self._execute(session_id, invoke)  # type: ignore[return-value]

    def create_game(
        self,
        *,
        seed: int,
        variants: JsonObject | None = None,
        session_id: str | None = None,
    ) -> GameUpdate:
        session_id = session_id or str(uuid.uuid4())
        variants = dict(variants or {})

        def create(shard: _Shard, unused: GameEngine | None) -> GameUpdate:
            if unused is not None:
                raise ValueError("session already loaded")
            shard.store.create_game(session_id, seed, variants)
            engine = shard.factory.create(seed, variants)
            shard.engines[session_id] = engine
            shard.automatic_states[session_id] = shard._automatic_state(
                session_id, variants, 0
            )
            shard.update_buffers[session_id] = ShardUpdateBuffer(session_id)
            return GameUpdate(session_id, 0, engine.view())

        return self._execute(session_id, create)  # type: ignore[return-value]

    def state(self, session_id: str, viewer_id: int | None = None) -> GameUpdate:
        def read(shard: _Shard, engine: GameEngine | None) -> GameUpdate:
            engine = engine or shard.load(session_id)
            revision = shard.store.game(session_id).revision
            return GameUpdate(session_id, revision, engine.view(viewer_id))

        return self._execute(session_id, read)  # type: ignore[return-value]

    def events(self, session_id: str, *, after_revision: int = 0):
        return self.store.events(session_id, after_revision=after_revision)

    def submit_action(
        self,
        session_id: str,
        *,
        expected_revision: int,
        action: JsonObject,
        viewer_id: int | None = None,
        authorize: Callable[[], None] | None = None,
    ) -> GameUpdate:
        def submit(shard: _Shard, engine: GameEngine | None) -> GameUpdate:
            if authorize is not None:
                authorize()
            engine = engine or shard.load(session_id)
            record = shard.store.game(session_id)
            if record.revision != expected_revision:
                from .store import RevisionConflict

                raise RevisionConflict(expected_revision, record.revision)
            # The shard is the local single writer, so validate/apply once on its
            # owned engine. The database CAS protects against another process.
            engine.apply(action)
            try:
                event = shard.store.append(
                    session_id,
                    expected_revision=expected_revision,
                    kind="action",
                    payload=action,
                )
            except Exception:
                # The local engine may have advanced before a cross-process CAS
                # conflict. Throw it away; the next command replays durable truth.
                engine.close()
                shard.engines.pop(session_id, None)
                shard.automatic_states.pop(session_id, None)
                raise
            shard.hub.publish(event)
            automatic = shard.automatic_states.get(session_id)
            if automatic is not None:
                automatic.action_count = event.revision
            projector = shard.projectors.get(session_id)
            if projector is not None:
                shard.update_buffers[session_id].record_action(
                    event.revision,
                    action,
                    projector(engine),
                )
            return GameUpdate(session_id, event.revision, engine.view(viewer_id), event)

        return self._execute(session_id, submit)  # type: ignore[return-value]

    def advance_automatic(self, session_id: str, *, now: float | None = None) -> int:
        def advance(shard: _Shard, engine: GameEngine | None) -> int:
            engine = engine or shard.load(session_id)
            if shard.advancer is None:
                return 0
            state = shard.automatic_states[session_id]

            def record(action: JsonObject, source: str) -> None:
                payload = dict(action)
                payload["source"] = source
                event = shard.store.append(
                    session_id,
                    expected_revision=state.action_count,
                    kind="action",
                    payload=payload,
                )
                shard.hub.publish(event)
                projector = shard.projectors.get(session_id)
                if projector is not None:
                    shard.update_buffers[session_id].record_action(
                        event.revision,
                        payload,
                        projector(engine),
                    )

            try:
                return shard.advancer.advance(
                    engine,  # type: ignore[arg-type]
                    state,
                    now=time.time() if now is None else now,
                    record=record,
                )
            except Exception:
                engine.close()
                shard.engines.pop(session_id, None)
                shard.automatic_states.pop(session_id, None)
                raise

        return self._execute(session_id, advance)  # type: ignore[return-value]

    def register_projector(
        self,
        session_id: str,
        projector: Callable[[GameEngine], Mapping[int | None, JsonObject]],
    ) -> None:
        def register(shard: _Shard, engine: GameEngine | None) -> None:
            if session_id not in shard.update_buffers:
                record = shard.store.game(session_id)
                shard.update_buffers[session_id] = ShardUpdateBuffer(
                    session_id, current_revision=record.revision
                )
            shard.projectors[session_id] = projector

        self._execute(session_id, register)

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
        def read(shard: _Shard, engine: GameEngine | None) -> JsonObject:
            if session_id not in shard.update_buffers:
                record = shard.store.game(session_id)
                shard.update_buffers[session_id] = ShardUpdateBuffer(
                    session_id, current_revision=record.revision
                )
            return shard.update_buffers[session_id].updates_since(
                after_revision,
                viewer_id,
                resync_update=resync_update,
                after_reaction_revision=after_reaction_revision,
                durable_reactions=durable_reactions or (),
            )

        return self._execute(session_id, read)  # type: ignore[return-value]

    def record_reaction(
        self,
        session_id: str,
        persist: Callable[[], Mapping[str, object]],
    ) -> JsonObject:
        def record(shard: _Shard, engine: GameEngine | None) -> JsonObject:
            reaction = dict(persist())
            if session_id not in shard.update_buffers:
                current = shard.store.game(session_id).revision
                shard.update_buffers[session_id] = ShardUpdateBuffer(
                    session_id, current_revision=current
                )
            shard.update_buffers[session_id].record_reaction(reaction)
            return reaction

        return self._execute(session_id, record)  # type: ignore[return-value]

    def delete_game(self, session_id: str) -> None:
        def delete(shard: _Shard, engine: GameEngine | None) -> None:
            if engine is not None:
                engine.close()
                shard.engines.pop(session_id, None)
                shard.automatic_states.pop(session_id, None)
                shard.update_buffers.pop(session_id, None)
                shard.projectors.pop(session_id, None)
            shard.store.delete_game(session_id)

        self._execute(session_id, delete)

    def close(self) -> None:
        for shard in self._shards:
            shard.close()
        self.store.close()
