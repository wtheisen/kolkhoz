from __future__ import annotations

import unittest

from server.kolkhoz_server.results import (
    DEFAULT_MU,
    DEFAULT_SIGMA,
    PostgresResultsRepository,
    RatingInput,
    aggregate_ai_results,
    evaluate_online_progression,
    rate_multiplayer,
)


class ResultsLogicTests(unittest.TestCase):
    def test_ai_results_are_aggregated_once_per_controller(self) -> None:
        results = aggregate_ai_results(
            [
                {"controller": "mediumAI", "score": 80, "rank": 2, "won": False},
                {"controller": "mediumAI", "score": 100, "rank": 1, "won": True},
                {"controller": "human", "score": 120, "rank": 1, "won": True},
            ]
        )
        self.assertEqual(
            results,
            {
                "mediumAI": {
                    "controller": "mediumAI",
                    "score": 90.0,
                    "rank": 1.5,
                    "won": True,
                }
            },
        )

    def test_rating_updates_reward_winner_and_reduce_uncertainty(self) -> None:
        outputs = rate_multiplayer(
            [
                RatingInput("winner", 1, 120),
                RatingInput("loser", 2, 80),
            ]
        )
        self.assertGreater(outputs["winner"].mu, DEFAULT_MU)
        self.assertLess(outputs["loser"].mu, DEFAULT_MU)
        self.assertLess(outputs["winner"].sigma, DEFAULT_SIGMA)
        self.assertGreater(outputs["winner"].display_rating, 1000)

    def test_progression_is_capped_and_unlocks_are_stable(self) -> None:
        value = evaluate_online_progression(
            {"progress": {"challenge.games_5": 4}, "unlocks": []},
            {
                "won": True,
                "score": 510,
                "medals": 5,
                "margin": 25,
                "full_five_year_game": True,
                "saboteur_exiled": True,
                "exiled_plot_cards": 0,
            },
        )
        self.assertEqual(value["progress"]["challenge.games_5"], 5)
        self.assertIn("unlock.card_back.harvest", value["unlocks"])
        self.assertIn("achievement.clear_victory", value["completed"])
        self.assertIn("achievement.no_requisition", value["completed"])


class _Transaction:
    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class _Cursor:
    def __init__(self, rows: list[object]) -> None:
        self.rows = rows
        self.executions: list[tuple[str, tuple[object, ...]]] = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, sql: str, params: tuple[object, ...]) -> None:
        self.executions.append((" ".join(sql.split()), params))

    def fetchone(self):
        return self.rows.pop(0) if self.rows else None

    def fetchall(self):
        return []


class _Connection:
    def __init__(self, cursor: _Cursor) -> None:
        self._cursor = cursor

    def transaction(self):
        return _Transaction()

    def cursor(self):
        return self._cursor


class _Pool:
    def __init__(self, cursor: _Cursor) -> None:
        self.connection_value = _Connection(cursor)

    def connection(self):
        class Checkout(_Transaction):
            def __enter__(inner_self):
                return self.connection_value

        return Checkout()

    def close(self) -> None:
        pass


class ResultsRepositoryTests(unittest.TestCase):
    def test_finished_session_retry_is_a_noop(self) -> None:
        cursor = _Cursor([None])
        repository = PostgresResultsRepository(pool=_Pool(cursor))
        changed = repository.finish_session(
            session_id="session",
            results=[{"user_id": "user", "won": True}],
            ranked=True,
            updated_at=100,
            expires_at=200,
        )
        self.assertFalse(changed)
        self.assertEqual(len(cursor.executions), 1)
        self.assertIn("status <> 'finished'", cursor.executions[0][0])

    def test_abandonment_is_one_transaction_and_returns_penalty(self) -> None:
        from datetime import datetime, timezone

        banned_until = datetime.fromtimestamp(500, timezone.utc)
        cursor = _Cursor([(3, banned_until)])
        repository = PostgresResultsRepository(pool=_Pool(cursor))
        penalty = repository.abandon_seat(
            session_id="session",
            player_id=2,
            user_id="user",
            updated_at=100,
            expires_at=200,
            revision=8,
        )
        self.assertEqual(penalty, {"strikes": 3, "banned_until": 500.0})
        statements = "\n".join(sql for sql, _ in cursor.executions)
        self.assertIn("abandoned = true", statements)
        self.assertIn("online_abandon_strikes = online_abandon_strikes + 1", statements)
        self.assertIn("insert into server_session_updates", statements)


if __name__ == "__main__":
    unittest.main()
