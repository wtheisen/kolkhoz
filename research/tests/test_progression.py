from pathlib import Path
import re

from research.kolkhoz_research.progression import TARGETS, evaluate_online_progression


def test_online_progression_accumulates_and_unlocks_once() -> None:
    state = None
    for game in range(5):
        state = evaluate_online_progression(
            state,
            {
                "won": game < 3,
                "score": 100,
                "medals": 5,
                "margin": 25,
                "full_five_year_game": True,
                "saboteur_exiled": game == 0,
                "exiled_plot_cards": 0,
            },
        )

    assert state["progress"]["challenge.games_5"] == 5
    assert state["progress"]["challenge.wins_3"] == 3
    assert state["progress"]["challenge.score_500"] == 500
    assert state["unlocks"] == [
        "unlock.card_back.granary",
        "unlock.card_back.harvest",
        "unlock.card_back.winter",
    ]
    assert "achievement.saboteur_exiled" in state["completed"]


def test_server_catalog_matches_flutter() -> None:
    dart_catalog = (
        Path(__file__).resolve().parents[2]
        / "clients/flutter_app/lib/src/progression/progression.dart"
    ).read_text()
    dart_ids = set(re.findall(r"id: '([^']+)'", dart_catalog))

    assert set(TARGETS) == dart_ids
