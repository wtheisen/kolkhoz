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

    def test_automatic_scheduler_defaults_to_command_worker_role(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            run_worker = _enabled("KOLKHOZ_RUN_COMMAND_WORKER")
            self.assertTrue(_enabled("KOLKHOZ_RUN_AUTOMATIC_SCHEDULER", run_worker))
        with patch.dict(
            os.environ, {"KOLKHOZ_RUN_COMMAND_WORKER": "false"}, clear=True
        ):
            run_worker = _enabled("KOLKHOZ_RUN_COMMAND_WORKER")
            self.assertFalse(_enabled("KOLKHOZ_RUN_AUTOMATIC_SCHEDULER", run_worker))

    def test_legacy_auth_configuration_is_optional(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(_production_auth_verifier())

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
