from __future__ import annotations

import json
import math
import random
import threading
import time
from dataclasses import dataclass
from http import HTTPStatus
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode


DEFAULT_CONTROLLERS = ["human", "human", "heuristicAI", "heuristicAI"]


@dataclass
class VirtualSeat:
    session_id: str
    player_id: int
    seat_token: str
    revision: int
    legal_actions: list[dict[str, object]]


class LoadStats:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self.routes: dict[str, list[float]] = {}
        self.statuses: dict[str, int] = {}
        self.errors: list[str] = []
        self.actions_submitted = 0

    def record(self, route: str, status: int, elapsed: float) -> None:
        with self._lock:
            self.routes.setdefault(route, []).append(elapsed)
            key = f"{route} {status}"
            self.statuses[key] = self.statuses.get(key, 0) + 1

    def record_error(self, message: str) -> None:
        with self._lock:
            if len(self.errors) < 50:
                self.errors.append(message)

    def record_action(self) -> None:
        with self._lock:
            self.actions_submitted += 1

    def snapshot(self) -> dict[str, object]:
        with self._lock:
            routes = {
                route: _latency_summary(samples)
                for route, samples in sorted(self.routes.items())
            }
            total_requests = sum(len(samples) for samples in self.routes.values())
            return {
                "requests": total_requests,
                "actionsSubmitted": self.actions_submitted,
                "routes": routes,
                "statuses": dict(sorted(self.statuses.items())),
                "errors": list(self.errors),
            }


def run_online_load_test(
    *,
    base_url: str,
    players: int,
    duration_seconds: float,
    poll_interval_seconds: float,
    setup_concurrency: int = 16,
    request_timeout_seconds: float = 10.0,
    auth_token: str | None = None,
    seed: int | None = None,
) -> dict[str, object]:
    if players < 1:
        raise ValueError("players must be positive")
    if duration_seconds <= 0:
        raise ValueError("duration must be positive")
    base_url = base_url.rstrip("/")
    stats = LoadStats()
    rng = random.Random(seed)
    seats = _create_virtual_seats(
        base_url=base_url,
        players=players,
        setup_concurrency=setup_concurrency,
        request_timeout_seconds=request_timeout_seconds,
        auth_token=auth_token,
        stats=stats,
        rng=rng,
    )
    started = time.time()
    stop_at = started + duration_seconds
    threads = [
        threading.Thread(
            target=_run_virtual_seat,
            args=(
                base_url,
                seat,
                stop_at,
                poll_interval_seconds,
                request_timeout_seconds,
                auth_token,
                stats,
                rng.randint(0, 2**31 - 1),
            ),
            daemon=True,
        )
        for seat in seats
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        remaining = max(0.1, stop_at - time.time() + request_timeout_seconds)
        thread.join(timeout=remaining)
    elapsed = time.time() - started
    server_metrics = _try_get_json(
        base_url,
        "GET",
        "metrics",
        timeout=request_timeout_seconds,
        auth_token=auth_token,
    )
    snapshot = stats.snapshot()
    return {
        "baseURL": base_url,
        "players": len(seats),
        "sessions": math.ceil(players / 2),
        "durationSeconds": elapsed,
        "client": snapshot,
        "serverMetrics": server_metrics,
    }


def _create_virtual_seats(
    *,
    base_url: str,
    players: int,
    setup_concurrency: int,
    request_timeout_seconds: float,
    auth_token: str | None,
    stats: LoadStats,
    rng: random.Random,
) -> list[VirtualSeat]:
    sessions_needed = math.ceil(players / 2)
    seats: list[VirtualSeat] = []
    seats_lock = threading.RLock()
    next_index = 0
    next_index_lock = threading.RLock()

    def setup_worker() -> None:
        nonlocal next_index
        while True:
            with next_index_lock:
                if next_index >= sessions_needed:
                    return
                session_index = next_index
                next_index += 1
            try:
                created = _request_json(
                    base_url,
                    "POST",
                    "sessions",
                    body={
                        "seed": rng.randint(1, 2**31 - 1),
                        "controllers": DEFAULT_CONTROLLERS,
                        "ranked": False,
                        "browserJoinable": False,
                    },
                    timeout=request_timeout_seconds,
                    auth_token=auth_token,
                    stats=stats,
                    route="POST /sessions",
                )
                session_id = str(created["sessionID"])
                created_update = _object(created["update"])
                host_seat = VirtualSeat(
                    session_id=session_id,
                    player_id=int(created["playerID"]),
                    seat_token=str(created["seatToken"]),
                    revision=int(created_update.get("actionLogCount") or 0),
                    legal_actions=_object_list(created_update.get("legalActions")),
                )
                session_seats = [host_seat]
                if len(seats) + len(session_seats) < players:
                    joined = _request_json(
                        base_url,
                        "POST",
                        f"sessions/{session_id}/join",
                        body={"preferredPlayerID": 1},
                        timeout=request_timeout_seconds,
                        auth_token=auth_token,
                        stats=stats,
                        route="POST /sessions/{session}/join",
                    )
                    joined_update = _object(joined["update"])
                    session_seats.append(
                        VirtualSeat(
                            session_id=session_id,
                            player_id=int(joined["playerID"]),
                            seat_token=str(joined["seatToken"]),
                            revision=int(joined_update.get("actionLogCount") or 0),
                            legal_actions=_object_list(
                                joined_update.get("legalActions")
                            ),
                        )
                    )
                with seats_lock:
                    seats.extend(session_seats[: max(0, players - len(seats))])
            except Exception as error:
                stats.record_error(f"setup session {session_index}: {error}")

    workers = [
        threading.Thread(target=setup_worker, daemon=True)
        for _ in range(max(1, min(setup_concurrency, sessions_needed)))
    ]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()
    if not seats:
        raise RuntimeError("load test could not create any virtual seats")
    return seats[:players]


def _run_virtual_seat(
    base_url: str,
    seat: VirtualSeat,
    stop_at: float,
    poll_interval_seconds: float,
    request_timeout_seconds: float,
    auth_token: str | None,
    stats: LoadStats,
    seed: int,
) -> None:
    rng = random.Random(seed)
    state_refresh_counter = 0
    while time.time() < stop_at:
        try:
            if seat.legal_actions:
                action = seat.legal_actions[0]
                update = _request_json(
                    base_url,
                    "POST",
                    f"sessions/{seat.session_id}/actions",
                    body={
                        "sessionID": seat.session_id,
                        "playerID": seat.player_id,
                        "actionLogCount": seat.revision,
                        "action": action,
                    },
                    timeout=request_timeout_seconds,
                    auth_token=auth_token,
                    seat_token=seat.seat_token,
                    stats=stats,
                    route="POST /sessions/{session}/actions",
                )
                seat.revision = int(update.get("actionLogCount") or seat.revision)
                seat.legal_actions = _object_list(update.get("legalActions"))
                stats.record_action()
            else:
                updates = _request_json(
                    base_url,
                    "GET",
                    f"sessions/{seat.session_id}/actions",
                    query={
                        "viewerID": str(seat.player_id),
                        "afterRevision": str(seat.revision),
                    },
                    timeout=request_timeout_seconds,
                    auth_token=auth_token,
                    seat_token=seat.seat_token,
                    stats=stats,
                    route="GET /sessions/{session}/actions",
                )
                seat.revision = int(updates.get("actionLogCount") or seat.revision)
                latest_updates = _object_list(updates.get("updates"))
                if latest_updates:
                    latest = _object(latest_updates[-1].get("update"))
                    seat.legal_actions = _object_list(latest.get("legalActions"))
                state_refresh_counter += 1
                if state_refresh_counter % 3 == 0 or not latest_updates:
                    state = _request_json(
                        base_url,
                        "GET",
                        f"sessions/{seat.session_id}/state",
                        query={"viewerID": str(seat.player_id)},
                        timeout=request_timeout_seconds,
                        auth_token=auth_token,
                        seat_token=seat.seat_token,
                        stats=stats,
                        route="GET /sessions/{session}/state",
                    )
                    seat.revision = int(state.get("actionLogCount") or seat.revision)
                    seat.legal_actions = _object_list(state.get("legalActions"))
        except HTTPError as error:
            if error.code != HTTPStatus.CONFLICT:
                stats.record_error(f"seat {seat.player_id}: HTTP {error.code}")
            seat.legal_actions = []
        except (OSError, URLError, ValueError, KeyError) as error:
            stats.record_error(f"seat {seat.player_id}: {error}")
        sleep_for = poll_interval_seconds * (0.75 + rng.random() * 0.5)
        time.sleep(max(0.01, sleep_for))


def _request_json(
    base_url: str,
    method: str,
    path: str,
    *,
    body: dict[str, object] | None = None,
    query: dict[str, str] | None = None,
    timeout: float,
    auth_token: str | None,
    seat_token: str | None = None,
    stats: LoadStats | None = None,
    route: str,
) -> dict[str, object]:
    suffix = path.lstrip("/")
    url = f"{base_url}/{suffix}"
    if query:
        url = f"{url}?{urlencode(query)}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if auth_token:
        headers["Authorization"] = f"Bearer {auth_token}"
    if seat_token:
        headers["X-Kolkhoz-Seat-Token"] = seat_token
    started = time.perf_counter()
    status = 0
    try:
        request = urlrequest.Request(url, data=data, method=method, headers=headers)
        with urlrequest.urlopen(request, timeout=timeout) as response:
            status = int(response.status)
            decoded = json.loads(response.read().decode("utf-8"))
            if not isinstance(decoded, dict):
                raise ValueError("expected JSON object")
            return decoded
    except HTTPError as error:
        status = int(error.code)
        raise
    finally:
        if stats is not None:
            stats.record(route, status, time.perf_counter() - started)


def _try_get_json(
    base_url: str,
    method: str,
    path: str,
    *,
    timeout: float,
    auth_token: str | None,
) -> dict[str, object] | None:
    try:
        return _request_json(
            base_url,
            method,
            path,
            timeout=timeout,
            auth_token=auth_token,
            stats=None,
            route=f"{method} /{path}",
        )
    except Exception:
        return None


def _latency_summary(samples: list[float]) -> dict[str, object]:
    ordered = sorted(samples)
    return {
        "count": len(samples),
        "meanMs": (sum(samples) / len(samples)) * 1000 if samples else 0.0,
        "p50Ms": _percentile(ordered, 0.50) * 1000,
        "p95Ms": _percentile(ordered, 0.95) * 1000,
        "p99Ms": _percentile(ordered, 0.99) * 1000,
        "maxMs": (ordered[-1] * 1000) if ordered else 0.0,
    }


def _percentile(samples: list[float], percentile: float) -> float:
    if not samples:
        return 0.0
    index = int(round((len(samples) - 1) * percentile))
    return samples[max(0, min(index, len(samples) - 1))]


def _object(value: object) -> dict[str, object]:
    return value if isinstance(value, dict) else {}


def _object_list(value: object) -> list[dict[str, object]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]
