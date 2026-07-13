from __future__ import annotations

from pathlib import Path

import pytest

from server.kolkhoz_server.preflight import verify_production_assets


def test_production_policy_assets_load_and_play_real_engine_actions() -> None:
    verify_production_assets(Path(__file__).resolve().parents[2])


def test_missing_policy_fails_before_server_start(tmp_path: Path) -> None:
    (tmp_path / "policies").mkdir()
    with pytest.raises(RuntimeError, match="mediumAI.*failed to load"):
        verify_production_assets(tmp_path)
