#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib import request as urlrequest
from urllib.parse import urlencode


EMAIL = "codex-smoke@kolkhoz.local"
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_RESULT_LOG = REPO_ROOT / "research/logs/online_smoke.jsonl"


def request_json(
    url: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    headers: dict[str, str] | None = None,
) -> object:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urlrequest.Request(
        url,
        data=data,
        method=method,
        headers={"Accept": "application/json", "Content-Type": "application/json", **(headers or {})},
    )
    with urlrequest.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def _progression_games(
    supabase_url: str,
    publishable_key: str,
    token: str,
    user_id: str,
) -> int:
    query = urlencode(
        {"select": "progress", "user_id": f"eq.{user_id}", "limit": "1"}
    )
    payload = request_json(
        f"{supabase_url}/rest/v1/profile_progression?{query}",
        headers={"apikey": publishable_key, "Authorization": f"Bearer {token}"},
    )
    if not isinstance(payload, list) or not payload:
        return 0
    row = payload[0] if isinstance(payload[0], dict) else {}
    progress = row.get("progress") if isinstance(row.get("progress"), dict) else {}
    return int(progress.get("challenge.games_5", 0))


def run_smoke() -> dict[str, object]:
    supabase_url = os.environ.get("KOLKHOZ_SUPABASE_URL", "").rstrip("/")
    publishable_key = os.environ.get("KOLKHOZ_SUPABASE_PUBLISHABLE_KEY", "")
    password = os.environ.get("KOLKHOZ_SMOKE_PASSWORD", "")
    online_url = os.environ.get(
        "KOLKHOZ_ONLINE_BASE_URL", "https://online.kolkhoz.williamtheisen.com"
    ).rstrip("/")
    if not supabase_url or not publishable_key or not password:
        raise SystemExit(
            "KOLKHOZ_SUPABASE_URL, KOLKHOZ_SUPABASE_PUBLISHABLE_KEY, and "
            "KOLKHOZ_SMOKE_PASSWORD are required"
        )

    auth = request_json(
        f"{supabase_url}/auth/v1/token?grant_type=password",
        method="POST",
        body={"email": EMAIL, "password": password},
        headers={"apikey": publishable_key},
    )
    if not isinstance(auth, dict) or not auth.get("access_token"):
        raise RuntimeError("Supabase did not return an access token")
    token = str(auth["access_token"])
    user = auth.get("user") if isinstance(auth.get("user"), dict) else {}
    user_id = str(user.get("id") or "")
    headers = {"Authorization": f"Bearer {token}"}
    games_before = _progression_games(
        supabase_url, publishable_key, token, user_id
    )

    created = request_json(
        f"{online_url}/sessions",
        method="POST",
        body={
            "seed": random.SystemRandom().randint(1, 2**31 - 1),
            "controllers": ["human", "heuristicAI", "neuralAI", "heuristicAI"],
            "ranked": False,
            "browserJoinable": False,
        },
        headers=headers,
    )
    if not isinstance(created, dict):
        raise RuntimeError("online server returned an invalid session response")
    session_id = str(created["sessionID"])
    player_id = int(created["playerID"])
    seat_token = str(created["seatToken"])
    update = created["update"]
    if not isinstance(update, dict):
        raise RuntimeError("online server returned an invalid session update")

    actions_submitted = 0
    deadline = time.monotonic() + 240
    rng = random.Random(0xC0DE)
    while time.monotonic() < deadline:
        snapshot = update.get("snapshot")
        if isinstance(snapshot, dict) and int(snapshot.get("winnerID", -1)) >= 0:
            games_after = _progression_games(
                supabase_url, publishable_key, token, user_id
            )
            if games_after != games_before + 1:
                raise RuntimeError(
                    "progression game count did not advance exactly once "
                    f"({games_before} -> {games_after})"
                )
            return {
                "status": "passed",
                "userID": user_id,
                "sessionID": session_id,
                "actionsSubmitted": actions_submitted,
                "winnerID": snapshot["winnerID"],
                "progressionGames": games_after,
                "scores": snapshot.get("scores", []),
            }

        legal_actions = update.get("legalActions")
        if isinstance(legal_actions, list) and legal_actions:
            action = rng.choice(legal_actions)
            update = request_json(
                f"{online_url}/sessions/{session_id}/actions",
                method="POST",
                body={
                    "sessionID": session_id,
                    "playerID": player_id,
                    "actionLogCount": int(update.get("actionLogCount", 0)),
                    "action": action,
                },
                headers={**headers, "X-Kolkhoz-Seat-Token": seat_token},
            )
            if not isinstance(update, dict):
                raise RuntimeError("online server returned an invalid action update")
            actions_submitted += 1
            continue

        query = urlencode({"viewerID": player_id})
        update = request_json(
            f"{online_url}/sessions/{session_id}/state?{query}",
            headers={**headers, "X-Kolkhoz-Seat-Token": seat_token},
        )
        if not isinstance(update, dict):
            raise RuntimeError("online server returned an invalid state update")
        time.sleep(0.2)

    raise TimeoutError(f"authenticated bot game {session_id} did not finish")


def _append_result(result: dict[str, object]) -> None:
    path = Path(
        os.environ.get("KOLKHOZ_SMOKE_RESULT_LOG", str(DEFAULT_RESULT_LOG))
    ).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(result, separators=(",", ":")) + "\n")


def main() -> int:
    started = datetime.now(timezone.utc)
    try:
        result = run_smoke()
    except Exception as error:
        result = {
            "status": "failed",
            "error": f"{type(error).__name__}: {error}",
        }
        exit_code = 1
    else:
        exit_code = 0
    finished = datetime.now(timezone.utc)
    result["startedAt"] = started.isoformat()
    result["finishedAt"] = finished.isoformat()
    result["durationSeconds"] = round((finished - started).total_seconds(), 3)
    _append_result(result)
    output = json.dumps(result, indent=2)
    print(output, file=sys.stdout if exit_code == 0 else sys.stderr)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
