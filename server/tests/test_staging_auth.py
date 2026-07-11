from __future__ import annotations

import unittest

from server.kolkhoz_server.auth import StagingAuthVerifier
from server.kolkhoz_server.errors import ServerError


class StagingAuthVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.verifier = StagingAuthVerifier({"host-token": "host-id"})

    def test_accepts_fixed_and_canonical_uuid_tokens(self) -> None:
        self.assertEqual(self.verifier.user_id("Bearer host-token"), "host-id")
        user_id = "10000000-0000-4000-8000-000000000099"
        self.assertEqual(self.verifier.user_id(f"Bearer staging:{user_id}"), user_id)

    def test_rejects_malformed_dynamic_identity(self) -> None:
        with self.assertRaises(ServerError):
            self.verifier.user_id("Bearer staging:not-a-uuid")


if __name__ == "__main__":
    unittest.main()
