from __future__ import annotations

import unittest

from server.kolkhoz_server.auth import CachingAuthVerifier


class _Verifier:
    def __init__(self) -> None:
        self.calls = 0

    def user_id(self, authorization: str | None) -> str | None:
        self.calls += 1
        return authorization


class CachingAuthVerifierTests(unittest.TestCase):
    def test_caches_until_ttl_and_evicts_oldest(self) -> None:
        now = [0.0]
        delegate = _Verifier()
        verifier = CachingAuthVerifier(
            delegate,  # type: ignore[arg-type]
            ttl_seconds=2,
            capacity=1,
            clock=lambda: now[0],
        )
        self.assertEqual(verifier.user_id("Bearer one"), "Bearer one")
        self.assertEqual(verifier.user_id("Bearer one"), "Bearer one")
        self.assertEqual(delegate.calls, 1)
        verifier.user_id("Bearer two")
        verifier.user_id("Bearer one")
        self.assertEqual(delegate.calls, 3)
        now[0] = 3
        verifier.user_id("Bearer one")
        self.assertEqual(delegate.calls, 4)

    def test_does_not_cache_anonymous_result(self) -> None:
        delegate = _Verifier()
        verifier = CachingAuthVerifier(delegate)  # type: ignore[arg-type]
        self.assertIsNone(verifier.user_id(None))
        self.assertEqual(delegate.calls, 0)


if __name__ == "__main__":
    unittest.main()
