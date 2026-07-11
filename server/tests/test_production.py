from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from server.kolkhoz_server.auth import CachingAuthVerifier
from server.kolkhoz_server.production import _enabled, _production_auth_verifier


class ProductionConfigurationTests(unittest.TestCase):
    def test_role_flags_are_explicit_and_default_on(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            self.assertTrue(_enabled("KOLKHOZ_RUN_COMMAND_WORKER"))
        with patch.dict(os.environ, {"ROLE": "false"}, clear=True):
            self.assertFalse(_enabled("ROLE"))

    def test_auth_configuration_fails_closed(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, "required in production"):
                _production_auth_verifier()

    def test_auth_configuration_builds_verifier(self) -> None:
        with patch.dict(
            os.environ,
            {
                "KOLKHOZ_SUPABASE_URL": "https://example.supabase.co",
                "KOLKHOZ_SUPABASE_PUBLISHABLE_KEY": "public-key",
            },
            clear=True,
        ):
            verifier = _production_auth_verifier()
        self.assertIsInstance(verifier, CachingAuthVerifier)


if __name__ == "__main__":
    unittest.main()
