#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib import request as urlrequest
from urllib.parse import urlencode


EMAIL = "codex-smoke@kolkhoz.local"
INSTALLATION_ID = "codex-smoke-production-installation"
SMOKE_SEED = 538316889
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
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            **(headers or {}),
        },
    )
    for attempt in range(3):
        try:
            with urlrequest.urlopen(request, timeout=15) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError:
            raise
        except (TimeoutError, URLError):
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError("request retry loop exited unexpectedly")


def _server_games_played(online_url: str, headers: dict[str, str]) -> int:
    payload = request_json(f"{online_url}/profile", headers=headers)
    stats = payload.get("stats") if isinstance(payload, dict) else None
    if not isinstance(stats, dict):
        raise RuntimeError("online server did not return profile statistics")
    return int(stats.get("games_played", 0))


def _submit_or_refresh(
    online_url: str,
    session_id: str,
    player_id: int,
    action_log_count: int,
    action: object,
    headers: dict[str, str],
) -> object:
    try:
        return request_json(
            f"{online_url}/sessions/{session_id}/actions",
            method="POST",
            body={
                "sessionID": session_id,
                "playerID": player_id,
                "actionLogCount": action_log_count,
                "action": action,
            },
            headers=headers,
        )
    except HTTPError as error:
        if error.code not in (400, 409):
            raise
    query = urlencode({"viewerID": player_id})
    return request_json(
        f"{online_url}/sessions/{session_id}/state?{query}", headers=headers
    )


def _identity_token(online_url: str, legacy_token: str) -> str:
    payload = request_json(
        f"{online_url}/identity/legacy",
        method="POST",
        body={"installationID": INSTALLATION_ID},
        headers={
            "Authorization": f"Bearer {legacy_token}",
            "X-Kolkhoz-Device-ID": INSTALLATION_ID,
        },
    )
    if not isinstance(payload, dict) or not payload.get("accessToken"):
        raise RuntimeError("online server did not return an identity session")
    return str(payload["accessToken"])


def _create_or_sync(
    online_url: str, body: dict[str, object], headers: dict[str, str]
) -> object:
    try:
        return request_json(
            f"{online_url}/sessions", method="POST", body=body, headers=headers
        )
    except HTTPError as error:
        if error.code != 409:
            raise
    return request_json(
        f"{online_url}/active-session/sync",
        method="POST",
        headers=headers,
    )


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
    legacy_token = str(auth["access_token"])
    user = auth.get("user") if isinstance(auth.get("user"), dict) else {}
    user_id = str(user.get("id") or "")
    identity_token = _identity_token(online_url, legacy_token)
    headers = {
        "Authorization": f"Bearer {identity_token}",
        "X-Kolkhoz-Device-ID": INSTALLATION_ID,
    }
    games_before = _server_games_played(online_url, headers)

    created = _create_or_sync(
        online_url,
        {
            "seed": SMOKE_SEED,
            "variants": {"heroOfSovietUnion": False},
            "controllers": ["human", "heuristicAI", "neuralAI", "heuristicAI"],
            "ranked": False,
            "browserJoinable": False,
        },
        headers,
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
            replay = request_json(
                f"{online_url}/results/{session_id}/replay", headers=headers
            )
            replay_events = replay.get("events", []) if isinstance(replay, dict) else []
            actions = [
                event["action"]
                for event in replay_events
                if isinstance(event, dict) and isinstance(event.get("action"), dict)
            ]
            action_kinds = [
                int(action.get("kind", -1))
                for action in actions
                if isinstance(action, dict)
            ]
            reward_reveals = action_kinds.count(10)
            trump_reveals = action_kinds.count(11)
            pass_actions = action_kinds.count(9)
            joker_actions = sum(
                1
                for action in actions
                if isinstance(action, dict)
                and any(
                    isinstance(action.get(key), dict)
                    and int(action[key].get("suit", -1)) == 4
                    and int(action[key].get("value", -1)) == 0
                    for key in ("card", "handCard", "plotCard")
                )
            )
            if reward_reveals != 12 or trump_reveals != 1:
                raise RuntimeError(
                    "planning reveals did not match a game through Year 5 "
                    f"(rewards={reward_reveals}, trump={trump_reveals})"
                )
            if pass_actions != 0:
                raise RuntimeError(
                    f"default game unexpectedly passed {pass_actions} cards"
                )
            if joker_actions == 0:
                raise RuntimeError("completed game did not expose a zero-value Joker")
            reveal_sources = {
                str(action.get("source"))
                for action in actions
                if int(action.get("kind", -1)) in (10, 11)
            }
            if reveal_sources != {"automatic"}:
                raise RuntimeError(
                    f"planning reveals were not server-owned: {sorted(reveal_sources)}"
                )
            games_after = _server_games_played(online_url, headers)
            if games_after != games_before + 1:
                raise RuntimeError(
                    "games-played count did not advance exactly once "
                    f"({games_before} -> {games_after})"
                )
            return {
                "status": "passed",
                "userID": user_id,
                "sessionID": session_id,
                "actionsSubmitted": actions_submitted,
                "winnerID": snapshot["winnerID"],
                "gamesPlayed": games_after,
                "scores": snapshot.get("scores", []),
                "rewardReveals": reward_reveals,
                "trumpReveals": trump_reveals,
                "passActions": pass_actions,
                "jokerActions": joker_actions,
            }

        legal_actions = update.get("legalActions")
        if isinstance(legal_actions, list) and legal_actions:
            action = rng.choice(legal_actions)
            update = _submit_or_refresh(
                online_url,
                session_id,
                player_id,
                int(update.get("actionLogCount", 0)),
                action,
                {**headers, "X-Kolkhoz-Seat-Token": seat_token},
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
