from __future__ import annotations

from server.kolkhoz_server.automatic_scheduler import AutomaticTurnScheduler


class Repository:
    def __init__(self) -> None:
        self.sessions = ["a", "b"]

    def automatic_due_sessions(self, *, now: float, limit: int) -> list[str]:
        return self.sessions[:limit]


def test_scheduler_advances_every_due_automatic_session() -> None:
    advanced: list[str] = []
    scheduler = AutomaticTurnScheduler(Repository(), advanced.append)  # type: ignore[arg-type]
    assert scheduler.run_once(now=10) == 2
    assert advanced == ["a", "b"]
    assert scheduler.healthy


def test_scheduler_surfaces_failures_as_unhealthy() -> None:
    scheduler = AutomaticTurnScheduler(  # type: ignore[arg-type]
        Repository(), lambda session_id: (_ for _ in ()).throw(RuntimeError(session_id))
    )
    assert scheduler.run_once(now=10) == 0
    assert not scheduler.healthy
