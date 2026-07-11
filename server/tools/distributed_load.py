"""HTTP/WebSocket load probe for an actually deployed greenfield stack."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import statistics
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlencode, urlparse, urlunparse


@dataclass(frozen=True)
class Identity:
    token: str
    device_id: str


@dataclass(frozen=True)
class Session:
    session_id: str
    player_id: int
    seat_token: str
    identity: Identity


class Measurements:
    def __init__(self) -> None:
        self.values: dict[str, list[float]] = {}
        self.errors: list[str] = []
        self._lock = threading.Lock()

    def record(self, operation: str, milliseconds: float) -> None:
        with self._lock:
            self.values.setdefault(operation, []).append(milliseconds)

    def summary(self) -> dict[str, object]:
        with self._lock:
            snapshot = {key: list(values) for key, values in self.values.items()}
        return {
            operation: _latency(values)
            for operation, values in sorted(snapshot.items())
        }

    def error(self, error: object) -> None:
        with self._lock:
            self.errors.append(str(error))

    def error_snapshot(self) -> list[str]:
        with self._lock:
            return list(self.errors)


class Client:
    def __init__(self, base_url: str, timeout: float, measurements: Measurements):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.measurements = measurements

    def request(
        self,
        operation: str,
        method: str,
        path: str,
        identity: Identity,
        body: dict[str, object] | None = None,
        seat_token: str | None = None,
    ) -> dict[str, Any]:
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {identity.token}",
            "Content-Type": "application/json",
            "X-Kolkhoz-Device-ID": identity.device_id,
        }
        if seat_token:
            headers["X-Kolkhoz-Seat-Token"] = seat_token
        encoded = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            self.base_url + path, data=encoded, method=method, headers=headers
        )
        started = time.perf_counter()
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                payload = json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as error:
            try:
                message = error.read().decode(errors="replace")
            finally:
                error.close()
            raise RuntimeError(f"{operation} returned HTTP {error.code}: {message}")
        finally:
            self.measurements.record(operation, (time.perf_counter() - started) * 1_000)
        if not isinstance(payload, dict):
            raise RuntimeError(f"{operation} returned a non-object response")
        return payload


def load_identities(path: Path) -> list[Identity]:
    raw = json.loads(path.read_text())
    if not isinstance(raw, list):
        raise ValueError("identity file must contain a JSON list")
    identities = []
    for index, value in enumerate(raw):
        if isinstance(value, str):
            identities.append(Identity(value, f"load-device-{index}"))
        elif isinstance(value, dict) and isinstance(value.get("token"), str):
            identities.append(
                Identity(
                    value["token"],
                    str(value.get("deviceID") or f"load-device-{index}"),
                )
            )
        else:
            raise ValueError(f"invalid identity at index {index}")
    if not identities:
        raise ValueError("identity file must not be empty")
    return identities


def staging_identities(count: int, *, offset: int = 0) -> list[Identity]:
    if count < 1 or offset < 0 or offset + count > 1_024:
        raise ValueError("staging identity range must be within 1 through 1024")
    return [
        Identity(
            f"staging:20000000-0000-4000-8000-{index:012d}",
            f"load-device-{index}",
        )
        for index in range(offset + 1, offset + count + 1)
    ]


def create_session(client: Client, identity: Identity) -> Session:
    payload = client.request(
        "create",
        "POST",
        "/sessions",
        identity,
        {
            "controllers": ["human", "heuristicAI", "heuristicAI", "heuristicAI"],
            "browserJoinable": False,
        },
    )
    return Session(
        str(payload["sessionID"]),
        int(payload["playerID"]),
        str(payload["seatToken"]),
        identity,
    )


def exercise_session(client: Client, session: Session, action_limit: int) -> None:
    for _ in range(action_limit):
        update = client.request(
            "state",
            "GET",
            f"/sessions/{session.session_id}/state?viewerID={session.player_id}",
            session.identity,
            seat_token=session.seat_token,
        )
        actions = update.get("legalActions")
        if not isinstance(actions, list) or not actions:
            return
        action = dict(actions[0])
        action["playerID"] = session.player_id
        client.request(
            "action",
            "POST",
            f"/sessions/{session.session_id}/actions",
            session.identity,
            {
                "playerID": session.player_id,
                "actionLogCount": int(update["actionLogCount"]),
                "action": action,
            },
            session.seat_token,
        )


async def hold_websocket(
    base_url: str, session: Session, duration: float, measurements: Measurements
) -> None:
    from websockets.asyncio.client import connect

    parsed = urlparse(base_url)
    target = urlunparse(
        (
            "wss" if parsed.scheme == "https" else "ws",
            parsed.netloc,
            f"/sessions/{session.session_id}/realtime",
            "",
            urlencode({"viewerID": session.player_id, "afterRevision": -1}),
            "",
        )
    )
    started = time.perf_counter()
    async with connect(
        target,
        additional_headers={
            "Authorization": f"Bearer {session.identity.token}",
            "X-Kolkhoz-Seat-Token": session.seat_token,
            "X-Kolkhoz-Device-ID": session.identity.device_id,
        },
        open_timeout=10,
    ) as socket:
        await asyncio.wait_for(socket.recv(), timeout=10)
        measurements.record("websocketConnect", (time.perf_counter() - started) * 1_000)
        await asyncio.sleep(duration)


async def hold_websockets(
    base_url: str,
    sessions: list[Session],
    duration: float,
    measurements: Measurements,
) -> list[object]:
    return await asyncio.gather(
        *(
            hold_websocket(base_url, session, duration, measurements)
            for session in sessions
        ),
        return_exceptions=True,
    )


def run(args: argparse.Namespace) -> dict[str, object]:
    identities = (
        load_identities(args.identities)
        if args.identities is not None
        else staging_identities(args.staging_identities, offset=args.staging_offset)
    )
    if len(identities) < args.games:
        raise ValueError("one distinct identity is required per active game")
    measurements = Measurements()
    client = Client(args.base_url, args.timeout, measurements)
    health = client.request("health", "GET", "/health", identities[0])
    sessions: list[Session] = []
    started = time.perf_counter()
    with ThreadPoolExecutor(max_workers=args.concurrency) as executor:
        futures = [
            executor.submit(create_session, client, identity)
            for identity in identities[: args.games]
        ]
        for future in as_completed(futures):
            try:
                sessions.append(future.result())
            except Exception as error:
                measurements.error(error)
        action_futures = [
            executor.submit(exercise_session, client, session, args.actions_per_game)
            for session in sessions
        ]
        for future in as_completed(action_futures):
            try:
                future.result()
            except Exception as error:
                measurements.error(error)

    websocket_count = min(args.websockets, len(sessions))
    if websocket_count:
        results = asyncio.run(
            hold_websockets(
                args.base_url,
                sessions[:websocket_count],
                args.websocket_seconds,
                measurements,
            )
        )
        for value in results:
            if isinstance(value, Exception):
                measurements.error(value)

    elapsed = time.perf_counter() - started
    errors = measurements.error_snapshot()
    return {
        "schemaVersion": 1,
        "evidence": "deployed-http-websocket-stack",
        "baseURL": args.base_url,
        "health": health,
        "requestedGames": args.games,
        "createdGames": len(sessions),
        "actionsPerGameLimit": args.actions_per_game,
        "websocketsHeld": websocket_count,
        "elapsedSeconds": round(elapsed, 3),
        "operationsPerSecond": round(
            sum(len(values) for values in measurements.values.values())
            / max(elapsed, 0.001),
            3,
        ),
        "latency": measurements.summary(),
        "errors": errors[:100],
        "passed": not errors and len(sessions) == args.games,
    }


def _latency(values: list[float]) -> dict[str, float | int]:
    ordered = sorted(values)

    def percentile(fraction: float) -> float:
        index = min(len(ordered) - 1, max(0, math.ceil(len(ordered) * fraction) - 1))
        return ordered[index]

    return {
        "count": len(ordered),
        "meanMs": round(statistics.fmean(ordered), 3),
        "p50Ms": round(percentile(0.50), 3),
        "p95Ms": round(percentile(0.95), 3),
        "p99Ms": round(percentile(0.99), 3),
        "maxMs": round(ordered[-1], 3),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    identities = parser.add_mutually_exclusive_group(required=True)
    identities.add_argument("--identities", type=Path)
    identities.add_argument("--staging-identities", type=int)
    parser.add_argument("--staging-offset", type=int, default=0)
    parser.add_argument("--games", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=32)
    parser.add_argument("--actions-per-game", type=int, default=1)
    parser.add_argument("--websockets", type=int, default=0)
    parser.add_argument("--websocket-seconds", type=float, default=10)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if min(args.games, args.concurrency, args.actions_per_game) < 1:
        raise SystemExit("games, concurrency, and actions-per-game must be positive")
    result = run(args)
    encoded = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(encoded + "\n")
    print(encoded)
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
