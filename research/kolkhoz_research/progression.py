from __future__ import annotations

from typing import Any


TARGETS = {
    "achievement.first_game": 1,
    "achievement.clear_victory": 1,
    "achievement.medalist": 1,
    "achievement.no_requisition": 1,
    "achievement.saboteur_exiled": 1,
    "achievement.first_win": 1,
    "achievement.century": 1,
    "challenge.games_5": 5,
    "challenge.wins_3": 3,
    "challenge.score_500": 500,
    "challenge.medals_25": 25,
    "challenge.games_10": 10,
    "challenge.wins_5": 5,
    "challenge.score_1000": 1000,
}

UNLOCK_REWARDS = {
    "challenge.games_5": "unlock.card_back.harvest",
    "challenge.wins_3": "unlock.card_back.granary",
    "challenge.score_500": "unlock.card_back.winter",
}


def evaluate_online_progression(
    current: dict[str, Any] | None,
    result: dict[str, object],
) -> dict[str, object]:
    current = current or {}
    raw_progress = current.get("progress")
    progress = {
        str(key): max(int(value), 0)
        for key, value in (raw_progress.items() if isinstance(raw_progress, dict) else ())
        if isinstance(value, int)
    }
    completed = {
        str(value) for value in current.get("completed", []) if isinstance(value, str)
    }
    unlocks = {
        str(value) for value in current.get("unlocks", []) if isinstance(value, str)
    }

    def add(item_id: str, amount: int) -> None:
        progress[item_id] = progress.get(item_id, 0) + max(amount, 0)

    won = bool(result.get("won"))
    score = _int(result.get("score"))
    medals = _int(result.get("medals"))
    add("achievement.first_game", 1)
    add("challenge.games_5", 1)
    add("challenge.games_10", 1)
    add("challenge.score_500", score)
    add("challenge.score_1000", score)
    add("challenge.medals_25", medals)
    if won:
        add("achievement.first_win", 1)
        add("challenge.wins_5", 1)
        if bool(result.get("full_five_year_game")):
            add("challenge.wins_3", 1)
        if _int(result.get("margin")) >= 25:
            add("achievement.clear_victory", 1)
    if score >= 100:
        add("achievement.century", 1)
    if medals >= 5:
        add("achievement.medalist", 1)
    if bool(result.get("saboteur_exiled")):
        add("achievement.saboteur_exiled", 1)
    if _int(result.get("exiled_plot_cards")) == 0:
        add("achievement.no_requisition", 1)

    for item_id, target in TARGETS.items():
        progress[item_id] = min(progress.get(item_id, 0), target)
        if progress[item_id] >= target:
            completed.add(item_id)
            reward = UNLOCK_REWARDS.get(item_id)
            if reward is not None:
                unlocks.add(reward)
    return {
        "progress": progress,
        "completed": sorted(completed),
        "unlocks": sorted(unlocks),
    }


def _int(value: object) -> int:
    return value if isinstance(value, int) else 0
