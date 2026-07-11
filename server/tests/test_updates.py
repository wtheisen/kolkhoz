from __future__ import annotations

import unittest

from server.kolkhoz_server.updates import (
    ACTION_UPDATE_CACHE_LIMIT,
    NonSequentialRevision,
    ShardUpdateBuffer,
    UnknownRevision,
)


def update(revision: int, viewer: int | None) -> dict[str, object]:
    return {
        "actionLogCount": revision,
        "viewerID": viewer,
        "snapshot": {"phase": 2},
    }


class ShardUpdateBufferTests(unittest.TestCase):
    def test_returns_ordered_viewer_specific_privacy_safe_updates(self) -> None:
        stream = ShardUpdateBuffer("game")
        for revision in range(1, 4):
            stream.record_action(
                revision,
                {
                    "kind": 2,
                    "playerID": 1,
                    "handCard": {"suit": 2, "value": 10},
                    "plotCard": {"suit": 3, "value": 9},
                },
                {0: update(revision, 0), 1: update(revision, 1)},
            )

        other = stream.updates_since(1, 0, resync_update={})
        owner = stream.updates_since(2, 1, resync_update={})

        self.assertEqual([item["revision"] for item in other["updates"]], [2, 3])
        self.assertEqual(other["updates"][-1]["update"]["viewerID"], 0)
        self.assertEqual(
            other["updates"][-1]["action"]["handCard"],
            {"suit": -1, "value": -1},
        )
        self.assertEqual(
            owner["updates"][0]["action"]["handCard"],
            {"suit": 2, "value": 10},
        )
        other["updates"][-1]["update"]["snapshot"]["phase"] = 99
        fresh = stream.updates_since(2, 0, resync_update={})
        self.assertEqual(fresh["updates"][0]["update"]["snapshot"]["phase"], 2)

    def test_cache_is_bounded_and_old_client_receives_resync(self) -> None:
        stream = ShardUpdateBuffer("game")
        for revision in range(1, ACTION_UPDATE_CACHE_LIMIT + 9):
            stream.record_action(
                revision,
                {"kind": 0, "playerID": 0},
                {0: update(revision, 0)},
            )

        resync = stream.updates_since(
            0,
            0,
            resync_update=lambda: update(stream.current_revision, 0),
        )
        recent = stream.updates_since(stream.current_revision - 2, 0, resync_update={})

        self.assertEqual(resync["updates"], [])
        self.assertEqual(
            resync["resyncUpdate"]["actionLogCount"], stream.current_revision
        )
        self.assertEqual(
            [item["revision"] for item in recent["updates"]],
            [stream.current_revision - 1, stream.current_revision],
        )

    def test_recovered_watermark_requires_resync_for_uncached_history(self) -> None:
        stream = ShardUpdateBuffer("game", current_revision=50)

        current = stream.updates_since(50, 0, resync_update={})
        stale = stream.updates_since(49, 0, resync_update={"actionLogCount": 50})

        self.assertEqual(current["updates"], [])
        self.assertIsNone(current["resyncUpdate"])
        self.assertEqual(stale["resyncUpdate"], {"actionLogCount": 50})

    def test_reactions_catch_up_from_cache_or_durable_storage(self) -> None:
        stream = ShardUpdateBuffer("game", capacity=2)
        for revision in range(1, 5):
            stream.record_reaction(
                {"revision": revision, "reactionID": f"reaction-{revision}"}
            )

        cached = stream.updates_since(
            0,
            None,
            resync_update={},
            after_reaction_revision=2,
        )
        durable = stream.updates_since(
            0,
            None,
            resync_update={},
            after_reaction_revision=0,
            durable_reactions=[
                {"revision": revision, "reactionID": f"reaction-{revision}"}
                for revision in range(1, 5)
            ],
        )

        self.assertEqual([item["revision"] for item in cached["reactions"]], [3, 4])
        self.assertEqual(
            [item["revision"] for item in durable["reactions"]], [1, 2, 3, 4]
        )
        self.assertIsNone(durable["resyncUpdate"])

    def test_missing_durable_reaction_gap_triggers_full_resync(self) -> None:
        stream = ShardUpdateBuffer("game", capacity=1)
        stream.record_reaction({"revision": 1})
        stream.record_reaction({"revision": 2})

        response = stream.updates_since(
            0,
            None,
            resync_update={"reactions": [{"revision": 1}, {"revision": 2}]},
            after_reaction_revision=0,
            durable_reactions=[{"revision": 2}],
        )

        self.assertEqual(response["reactions"], [])
        self.assertIsNotNone(response["resyncUpdate"])

    def test_rejects_unknown_and_non_sequential_revisions(self) -> None:
        stream = ShardUpdateBuffer("game")
        with self.assertRaises(NonSequentialRevision):
            stream.record_action(2, {}, {None: {}})
        with self.assertRaises(NonSequentialRevision):
            stream.record_reaction({"revision": 2})
        with self.assertRaises(UnknownRevision):
            stream.updates_since(-1, None, resync_update={})
        with self.assertRaises(UnknownRevision):
            stream.updates_since(1, None, resync_update={})


if __name__ == "__main__":
    unittest.main()
