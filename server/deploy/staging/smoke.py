#!/usr/bin/env python3
"""Exercise one game through the load balancer and both gateway replicas."""

from __future__ import annotations

import json
import os
import secrets
import urllib.error
import urllib.request


LB = os.environ.get("KOLKHOZ_STAGING_URL", "http://127.0.0.1:18080")
GATEWAYS = (
    os.environ.get("KOLKHOZ_STAGING_GATEWAY_A", "http://127.0.0.1:18787"),
    os.environ.get("KOLKHOZ_STAGING_GATEWAY_B", "http://127.0.0.1:28787"),
)
IDENTITY_OFFSET = int(
    os.environ.get("KOLKHOZ_STAGING_IDENTITY_OFFSET", secrets.randbelow(500) * 2 + 1)
)


def load_token(index: int) -> str:
    return f"staging:20000000-0000-4000-8000-{index:012d}"


HOST_TOKEN = os.environ.get("KOLKHOZ_STAGING_HOST_TOKEN", load_token(IDENTITY_OFFSET))
GUEST_TOKEN = os.environ.get(
    "KOLKHOZ_STAGING_GUEST_TOKEN", load_token(IDENTITY_OFFSET + 1)
)


def request(
    base: str,
    method: str,
    path: str,
    *,
    bearer: str | None = None,
    seat_token: str | None = None,
    body: dict[str, object] | None = None,
) -> object:
    headers = {"Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    if seat_token:
        headers["X-Kolkhoz-Seat-Token"] = seat_token
    encoded = json.dumps(body or {}).encode()
    call = urllib.request.Request(
        base + path, encoded if method != "GET" else None, headers, method=method
    )
    try:
        with urllib.request.urlopen(call, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise RuntimeError(
            f"{method} {base}{path}: HTTP {error.code}: {detail}"
        ) from error


def main() -> None:
    for base in (LB, *GATEWAYS):
        health = request(base, "GET", "/health")
        assert isinstance(health, dict), health

    created = request(
        LB,
        "POST",
        "/sessions",
        bearer=HOST_TOKEN,
        body={
            "seed": 424242,
            "controllers": ["human", "human", "heuristicAI", "heuristicAI"],
        },
    )
    assert isinstance(created, dict)
    session_id = str(created["sessionID"])
    host_id = int(created["playerID"])
    host_seat = str(created["seatToken"])

    joined = request(
        GATEWAYS[1],
        "POST",
        f"/sessions/{session_id}/join",
        bearer=GUEST_TOKEN,
        body={},
    )
    assert isinstance(joined, dict)
    guest_id = int(joined["playerID"])
    guest_seat = str(joined["seatToken"])

    state = request(
        GATEWAYS[0],
        "GET",
        f"/sessions/{session_id}/state?viewerID={host_id}",
        bearer=HOST_TOKEN,
        seat_token=host_seat,
    )
    assert isinstance(state, dict) and state.get("started") is True, state
    waiting = int(state["snapshot"]["waitingPlayer"])
    if waiting != host_id:
        state = request(
            GATEWAYS[1],
            "GET",
            f"/sessions/{session_id}/state?viewerID={guest_id}",
            bearer=GUEST_TOKEN,
            seat_token=guest_seat,
        )
        assert isinstance(state, dict)
    legal = state.get("legalActions")
    assert isinstance(legal, list) and legal, state
    action = legal[0]
    acting_id = int(action["playerID"])
    bearer, seat = (
        (HOST_TOKEN, host_seat) if acting_id == host_id else (GUEST_TOKEN, guest_seat)
    )

    updated = request(
        LB,
        "POST",
        f"/sessions/{session_id}/actions",
        bearer=bearer,
        seat_token=seat,
        body={
            "playerID": acting_id,
            "actionLogCount": int(state["actionLogCount"]),
            "action": action,
        },
    )
    assert isinstance(updated, dict)
    assert int(updated["actionLogCount"]) > int(state["actionLogCount"]), updated

    observed = request(
        GATEWAYS[1],
        "GET",
        f"/sessions/{session_id}/state?viewerID={guest_id}",
        bearer=GUEST_TOKEN,
        seat_token=guest_seat,
    )
    assert isinstance(observed, dict)
    assert observed["actionLogCount"] == updated["actionLogCount"], observed
    print(
        f"staging smoke: ok session={session_id} revision={observed['actionLogCount']}"
    )


if __name__ == "__main__":
    main()
