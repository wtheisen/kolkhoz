#!/usr/bin/env python3
"""Bounded distributed recovery drill for the local staging topology."""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable
from pathlib import Path
import secrets
import subprocess
import time
import urllib.error
import urllib.request
import zlib

import websockets


HERE = Path(__file__).resolve().parent
COMPOSE = ("docker", "compose", "-f", str(HERE / "compose.yaml"))
LB = "http://127.0.0.1:18080"
WS = "ws://127.0.0.1:18080"
identity = secrets.randbelow(900) + 1
USER_ID = f"20000000-0000-4000-8000-{identity:012d}"
BEARER = f"staging:{USER_ID}"


def compose(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        (*COMPOSE, *arguments), check=check, text=True, capture_output=True
    )


def request(
    method: str,
    path: str,
    *,
    seat_token: str | None = None,
    body: dict[str, object] | None = None,
    timeout: float = 15,
) -> dict[str, object]:
    headers = {"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}
    if seat_token:
        headers["X-Kolkhoz-Seat-Token"] = seat_token
    call = urllib.request.Request(
        LB + path,
        json.dumps(body or {}).encode() if method != "GET" else None,
        headers,
        method=method,
    )
    with urllib.request.urlopen(call, timeout=timeout) as response:
        value = json.load(response)
    assert isinstance(value, dict)
    return value


def state(session_id: str, player_id: int, seat_token: str) -> dict[str, object]:
    return request(
        "GET",
        f"/sessions/{session_id}/state?viewerID={player_id}",
        seat_token=seat_token,
    )


def act(session_id: str, player_id: int, seat_token: str) -> dict[str, object]:
    current = state(session_id, player_id, seat_token)
    legal = current["legalActions"]
    assert isinstance(legal, list) and legal
    return request(
        "POST",
        f"/sessions/{session_id}/actions",
        seat_token=seat_token,
        body={
            "playerID": player_id,
            "actionLogCount": current["actionLogCount"],
            "action": legal[0],
        },
    )


def wait_healthy(seconds: float = 35) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            request("GET", "/ready", timeout=2)
            return
        except Exception:
            time.sleep(0.5)
    raise RuntimeError("staging load balancer did not recover")


def expect_bounded_failure(
    operation: Callable[[], object], *, maximum: float = 16
) -> None:
    started = time.monotonic()
    try:
        operation()
    except Exception:
        elapsed = time.monotonic() - started
        assert elapsed <= maximum, elapsed
        return
    raise AssertionError("dependency interruption unexpectedly succeeded")


async def websocket_reconnect(
    session_id: str, player_id: int, seat_token: str, before: int
) -> None:
    headers = {
        "Authorization": f"Bearer {BEARER}",
        "X-Kolkhoz-Seat-Token": seat_token,
    }
    uri = f"{WS}/sessions/{session_id}/realtime?viewerID={player_id}&afterRevision={before}"
    async with websockets.connect(uri, additional_headers=headers) as socket:
        initial = json.loads(await asyncio.wait_for(socket.recv(), 5))
        assert initial["type"] == "state"
        catch_up = json.loads(await asyncio.wait_for(socket.recv(), 5))
        assert catch_up["type"] == "catchUp" and catch_up["updates"]


def main() -> None:
    takeover = "kolkhoz-staging-chaos-takeover"
    paused: set[str] = set()
    stopped_owner: str | None = None
    try:
        created = request(
            "POST",
            "/sessions",
            body={
                "controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"],
                "seed": int(time.time_ns()),
            },
        )
        session_id = str(created["sessionID"])
        player_id = int(created["playerID"])
        seat_token = str(created["seatToken"])
        first = act(session_id, player_id, seat_token)

        partition = zlib.crc32(session_id.encode()) % 16
        stopped_owner = "worker-a" if partition < 8 else "worker-b"
        takeover_source = "worker-b" if stopped_owner == "worker-a" else "worker-a"
        compose("stop", stopped_owner)
        owned = "0,1,2,3,4,5,6,7" if partition < 8 else "8,9,10,11,12,13,14,15"
        compose(
            "run",
            "-d",
            "--no-deps",
            "--name",
            takeover,
            "-e",
            f"KOLKHOZ_WORKER_ID={takeover}-worker",
            "-e",
            f"KOLKHOZ_COMMAND_PARTITIONS={owned}",
            takeover_source,
        )
        time.sleep(17)
        recovered = act(session_id, player_id, seat_token)
        assert int(recovered["actionLogCount"]) > int(first["actionLogCount"])

        subprocess.run(("docker", "rm", "-f", takeover), capture_output=True)
        compose("start", stopped_owner)
        stopped_owner = None
        time.sleep(17)

        before = int(recovered["actionLogCount"])
        compose("restart", "gateway-a")
        wait_healthy()
        act(session_id, player_id, seat_token)
        asyncio.run(websocket_reconnect(session_id, player_id, seat_token, before))

        for dependency in ("redis", "postgres"):
            compose("pause", dependency)
            paused.add(dependency)
            expect_bounded_failure(lambda: state(session_id, player_id, seat_token))
            compose("unpause", dependency)
            paused.remove(dependency)
            wait_healthy()
            state(session_id, player_id, seat_token)

        for service in ("gateway-a", "gateway-b", "worker-a", "worker-b"):
            compose("restart", service)
            wait_healthy()
        state(session_id, player_id, seat_token)
        print(f"staging chaos: ok session={session_id} partition={partition}")
    finally:
        for dependency in paused:
            compose("unpause", dependency, check=False)
        subprocess.run(("docker", "rm", "-f", takeover), capture_output=True)
        if stopped_owner is not None:
            compose("start", stopped_owner, check=False)


if __name__ == "__main__":
    main()
