from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from server.kolkhoz_server.tournament import (
    TournamentParticipant,
    plan_round,
    score_table,
    weekly_start,
)


def participant(
    value: int,
    *,
    points: int = 0,
    opponents: tuple[str, ...] = (),
    seats: tuple[int, int, int, int] = (0, 0, 0, 0),
) -> TournamentParticipant:
    return TournamentParticipant(
        user_id=f"p{value}",
        controller="human",
        display_name=f"Player {value}",
        points=Decimal(points),
        opponents=opponents,
        seat_counts=seats,
    )


def test_score_table_splits_unresolved_placement_points() -> None:
    scored = score_table(
        [
            {"user_id": "a", "score": 80, "medals": 3},
            {"user_id": "b", "score": 80, "medals": 3},
            {"user_id": "c", "score": 70, "medals": 9},
            {"user_id": "d", "score": 60, "medals": 0},
        ]
    )

    assert scored["a"] == (1, Decimal("4"))
    assert scored["b"] == (1, Decimal("4"))
    assert scored["c"] == (3, Decimal("1"))
    assert scored["d"] == (4, Decimal("0"))


def test_preliminary_pairing_avoids_repeat_opponents_and_rotates_seats() -> None:
    players = [
        participant(1, points=5, opponents=("p2", "p3", "p4"), seats=(1, 0, 0, 0)),
        participant(2, points=5, opponents=("p1", "p3", "p4"), seats=(0, 1, 0, 0)),
        participant(3, points=3, opponents=("p1", "p2", "p4"), seats=(0, 0, 1, 0)),
        participant(4, points=3, opponents=("p1", "p2", "p3"), seats=(0, 0, 0, 1)),
        participant(5, points=3),
        participant(6, points=1),
        participant(7, points=1),
        participant(8),
    ]

    tables = plan_round(players, round_number=2)

    assert len(tables) == 2
    assert all(len(table) == 4 for table in tables)
    first = next(
        table for table in tables if any(value.user_id == "p1" for value in table)
    )
    assert any(value.user_id == "p5" for value in first)
    for seat, value in enumerate(first):
        assert value.seat_counts[seat] == 0


def test_final_round_groups_players_strictly_by_standings() -> None:
    tables = plan_round(
        [participant(index, points=9 - index) for index in range(1, 9)],
        round_number=4,
    )

    assert {value.user_id for value in tables[0]} == {"p1", "p2", "p3", "p4"}
    assert {value.user_id for value in tables[1]} == {"p5", "p6", "p7", "p8"}


def test_weekly_start_defaults_to_saturday_evening_indiana_time() -> None:
    zone = ZoneInfo("America/Indiana/Indianapolis")
    thursday = datetime(2026, 7, 16, 12, tzinfo=zone).timestamp()
    result = datetime.fromtimestamp(weekly_start(thursday), zone)

    assert result.weekday() == 5
    assert (result.hour, result.minute) == (19, 0)
