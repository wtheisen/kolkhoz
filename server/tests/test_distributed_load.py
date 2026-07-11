from __future__ import annotations

import json
from argparse import Namespace
from pathlib import Path

import pytest

from server.tools.distributed_load import (
    Measurements,
    _latency,
    load_identities,
    run,
    staging_identities,
)


def test_load_identities_accepts_tokens_and_explicit_devices(tmp_path: Path) -> None:
    source = tmp_path / "identities.json"
    source.write_text(
        json.dumps(["one", {"token": "two", "deviceID": "custom-device"}])
    )
    identities = load_identities(source)
    assert [(item.token, item.device_id) for item in identities] == [
        ("one", "load-device-0"),
        ("two", "custom-device"),
    ]


def test_latency_reports_tail_percentiles() -> None:
    assert _latency([1, 2, 3, 100]) == {
        "count": 4,
        "meanMs": 26.5,
        "p50Ms": 2,
        "p95Ms": 100,
        "p99Ms": 100,
        "maxMs": 100,
    }


def test_staging_identities_match_seeded_uuid_contract() -> None:
    identities = staging_identities(2, offset=10)
    assert identities[0].token == ("staging:20000000-0000-4000-8000-000000000011")
    assert identities[1].device_id == "load-device-12"


def test_measurements_bounds_reported_errors() -> None:
    measurements = Measurements()
    measurements.record("state", 3)
    for index in range(120):
        measurements.error(index)
    assert measurements.summary()["state"]["count"] == 1


def test_run_requires_one_identity_per_active_game(tmp_path: Path) -> None:
    source = tmp_path / "identities.json"
    source.write_text('["only-token"]')
    args = Namespace(
        identities=source,
        games=2,
        base_url="http://127.0.0.1:1",
        timeout=0.1,
        concurrency=1,
        actions_per_game=1,
        websockets=0,
        websocket_seconds=0,
    )
    with pytest.raises(ValueError, match="distinct identity"):
        run(args)
