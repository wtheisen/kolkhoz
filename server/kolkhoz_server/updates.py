from __future__ import annotations

from collections import deque
from collections.abc import Callable, Iterable, Mapping
from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .contracts import privacy_safe_action_log
from .model import JsonObject


ACTION_UPDATE_CACHE_LIMIT = 32


class UnknownRevision(ValueError):
    """Raised when a client claims a revision that cannot exist."""

    def __init__(self, stream: str, requested: int, current: int) -> None:
        super().__init__(
            f"unknown {stream} revision: requested {requested}, current {current}"
        )
        self.stream = stream
        self.requested = requested
        self.current = current


class NonSequentialRevision(ValueError):
    """Raised when a shard tries to publish events out of commit order."""

    def __init__(self, stream: str, expected: int, actual: int) -> None:
        super().__init__(
            f"non-sequential {stream} revision: expected {expected}, got {actual}"
        )
        self.stream = stream
        self.expected = expected
        self.actual = actual


@dataclass(frozen=True)
class _ActionRevision:
    revision: int
    action: JsonObject
    updates_by_viewer: dict[int | None, JsonObject]


class ShardUpdateBuffer:
    """Bounded update state owned exclusively by one game-worker shard.

    No lock is needed: the session's shard is the only writer and reader. Durable
    action events remain authoritative; this buffer only retains the projections
    needed for smooth, per-action animation by recently connected clients.

    ``current_revision`` and ``reaction_revision`` allow a recovered shard to
    start at durable watermarks without rebuilding historical projections.
    """

    def __init__(
        self,
        session_id: str,
        *,
        current_revision: int = 0,
        reaction_revision: int = 0,
        capacity: int = ACTION_UPDATE_CACHE_LIMIT,
    ) -> None:
        if current_revision < 0 or reaction_revision < 0:
            raise ValueError("revision watermarks must be non-negative")
        if capacity < 1:
            raise ValueError("capacity must be positive")
        self.session_id = session_id
        self.current_revision = current_revision
        self.reaction_revision = reaction_revision
        self._actions: deque[_ActionRevision] = deque(maxlen=capacity)
        self._reactions: deque[JsonObject] = deque(maxlen=capacity)

    def record_action(
        self,
        revision: int,
        action: Mapping[str, Any],
        updates_by_viewer: Mapping[int | None, Mapping[str, Any]],
    ) -> None:
        """Record one committed action and its already-projected viewer states."""

        self._validate_next("action", revision, self.current_revision)
        if not updates_by_viewer:
            raise ValueError("updates_by_viewer must not be empty")
        self._actions.append(
            _ActionRevision(
                revision,
                deepcopy(dict(action)),
                {
                    viewer: deepcopy(dict(update))
                    for viewer, update in updates_by_viewer.items()
                },
            )
        )
        self.current_revision = revision

    def record_reaction(self, reaction: Mapping[str, Any]) -> None:
        revision = _required_revision(reaction)
        self._validate_next("reaction", revision, self.reaction_revision)
        self._reactions.append(deepcopy(dict(reaction)))
        self.reaction_revision = revision

    def updates_since(
        self,
        after_revision: int,
        viewer_id: int | None,
        *,
        resync_update: Mapping[str, Any] | Callable[[], Mapping[str, Any]],
        after_reaction_revision: int | None = None,
        durable_reactions: Iterable[Mapping[str, Any]] = (),
    ) -> JsonObject:
        """Return animation updates, or a current full projection when too old.

        Reactions use their own monotonic revision. Callers may provide reactions
        read from durable storage to fill a gap older than the in-memory window.
        If durable input does not cover that gap, the normal full resync also
        repairs the reaction stream.
        """

        self._validate_known("action", after_revision, self.current_revision)
        if after_reaction_revision is None:
            after_reaction_revision = self.reaction_revision
        self._validate_known(
            "reaction", after_reaction_revision, self.reaction_revision
        )

        action_stale = after_revision < self._oldest_action_revision() - 1
        reactions, reaction_stale = self._reactions_since(
            after_reaction_revision, durable_reactions
        )
        needs_resync = action_stale or reaction_stale
        if needs_resync:
            full_update = resync_update() if callable(resync_update) else resync_update
            return {
                "sessionID": self.session_id,
                "actionLogCount": self.current_revision,
                "reactionLogCount": self.reaction_revision,
                "updates": [],
                "reactions": [],
                "resyncUpdate": deepcopy(dict(full_update)),
            }

        updates = [
            self._viewer_action_update(entry, viewer_id)
            for entry in self._actions
            if entry.revision > after_revision
        ]
        return {
            "sessionID": self.session_id,
            "actionLogCount": self.current_revision,
            "reactionLogCount": self.reaction_revision,
            "updates": updates,
            "reactions": reactions,
            "resyncUpdate": None,
        }

    def _viewer_action_update(
        self, entry: _ActionRevision, viewer_id: int | None
    ) -> JsonObject:
        update = entry.updates_by_viewer.get(viewer_id)
        if update is None:
            update = entry.updates_by_viewer.get(None)
        if update is None:
            raise ValueError(f"missing projection for viewer {viewer_id!r}")
        safe_update = deepcopy(update)
        game_over = int(_mapping(safe_update.get("snapshot")).get("phase", -1)) == 5
        action = privacy_safe_action_log(
            [entry.action], viewer_id, game_over=game_over
        )[0]
        return {
            "revision": entry.revision,
            "action": action,
            "update": safe_update,
        }

    def _reactions_since(
        self,
        after_revision: int,
        durable_reactions: Iterable[Mapping[str, Any]],
    ) -> tuple[list[JsonObject], bool]:
        if after_revision == self.reaction_revision:
            return [], False
        cached_oldest = (
            _required_revision(self._reactions[0])
            if self._reactions
            else self.reaction_revision + 1
        )
        if after_revision >= cached_oldest - 1:
            return (
                [
                    deepcopy(reaction)
                    for reaction in self._reactions
                    if _required_revision(reaction) > after_revision
                ],
                False,
            )

        durable = sorted(
            (
                deepcopy(dict(reaction))
                for reaction in durable_reactions
                if _required_revision(reaction) > after_revision
            ),
            key=_required_revision,
        )
        expected = list(range(after_revision + 1, self.reaction_revision + 1))
        actual = [_required_revision(reaction) for reaction in durable]
        return (durable, actual != expected)

    def _oldest_action_revision(self) -> int:
        return self._actions[0].revision if self._actions else self.current_revision + 1

    @staticmethod
    def _validate_known(stream: str, requested: int, current: int) -> None:
        if requested < 0 or requested > current:
            raise UnknownRevision(stream, requested, current)

    @staticmethod
    def _validate_next(stream: str, revision: int, current: int) -> None:
        if revision != current + 1:
            raise NonSequentialRevision(stream, current + 1, revision)


def _required_revision(value: Mapping[str, Any]) -> int:
    revision = value.get("revision")
    if isinstance(revision, bool) or not isinstance(revision, int):
        raise ValueError("revision must be an integer")
    return revision


def _mapping(value: object) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}
