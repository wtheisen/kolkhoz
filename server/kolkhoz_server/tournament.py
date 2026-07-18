from __future__ import annotations

import itertools
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Callable, Mapping, Protocol, Sequence
from zoneinfo import ZoneInfo

from .store import ConnectionPool


PLAYER_COUNT = 4
PRELIMINARY_ROUNDS = 3
TOTAL_ROUNDS = 4
PLACEMENT_POINTS = (Decimal("5"), Decimal("3"), Decimal("1"), Decimal("0"))


@dataclass(frozen=True)
class TournamentParticipant:
    user_id: str
    controller: str
    display_name: str
    is_bot: bool = False
    forfeited: bool = False
    points: Decimal = Decimal("0")
    wins: int = 0
    game_score: int = 0
    opponent_points: Decimal = Decimal("0")
    opponents: tuple[str, ...] = ()
    seat_counts: tuple[int, int, int, int] = (0, 0, 0, 0)
    final_placement: int | None = None


@dataclass(frozen=True)
class TournamentTablePlan:
    table_id: str
    tournament_id: str
    round_number: int
    table_number: int
    session_id: str
    participants: tuple[TournamentParticipant, ...]


class TournamentRepository(Protocol):
    def status(self, *, user_id: str, now: float) -> dict[str, object]: ...
    def join(self, *, user_id: str, now: float) -> dict[str, object]: ...
    def withdraw(self, *, user_id: str, now: float) -> dict[str, object]: ...
    def prepare(self, *, now: float) -> list[TournamentTablePlan]: ...
    def mark_table_active(self, *, table_id: str, now: float) -> bool: ...
    def mark_table_planned(self, *, table_id: str) -> None: ...
    def record_game_finished(
        self, *, session_id: str, results: Sequence[Mapping[str, object]], now: float
    ) -> bool: ...
    def session_context(self, *, session_id: str) -> dict[str, object] | None: ...


def standings_key(participant: TournamentParticipant) -> tuple[object, ...]:
    return (
        participant.final_placement is None,
        participant.final_placement or 0,
        -participant.points,
        -participant.wins,
        -participant.opponent_points,
        -participant.game_score,
        participant.user_id,
    )


def _seat_participants(
    participants: Sequence[TournamentParticipant],
) -> tuple[TournamentParticipant, ...]:
    best = min(
        itertools.permutations(participants),
        key=lambda order: (
            sum(order[seat].seat_counts[seat] for seat in range(PLAYER_COUNT)),
            tuple(order[seat].seat_counts[seat] for seat in range(PLAYER_COUNT)),
            tuple(value.user_id for value in order),
        ),
    )
    return tuple(best)


def plan_round(
    participants: Sequence[TournamentParticipant], *, round_number: int
) -> list[tuple[TournamentParticipant, ...]]:
    if not participants or len(participants) % PLAYER_COUNT:
        raise ValueError("tournament participant count must be divisible by four")
    ranked = sorted(participants, key=standings_key)
    if round_number == TOTAL_ROUNDS:
        return [
            _seat_participants(ranked[index : index + PLAYER_COUNT])
            for index in range(0, len(ranked), PLAYER_COUNT)
        ]

    remaining = list(ranked)
    tables: list[tuple[TournamentParticipant, ...]] = []
    while remaining:
        group = [remaining.pop(0)]
        while len(group) < PLAYER_COUNT:
            candidate = min(
                remaining,
                key=lambda value: (
                    sum(
                        value.opponents.count(member.user_id)
                        + member.opponents.count(value.user_id)
                        for member in group
                    ),
                    min(abs(value.points - member.points) for member in group),
                    standings_key(value),
                ),
            )
            remaining.remove(candidate)
            group.append(candidate)
        tables.append(_seat_participants(group))
    return tables


def score_table(
    results: Sequence[Mapping[str, object]],
) -> dict[str, tuple[int, Decimal]]:
    if len(results) != PLAYER_COUNT:
        raise ValueError("a tournament table requires four results")
    ordered = sorted(
        results,
        key=lambda value: (
            -int(value.get("score", 0)),
            -int(value.get("medals", 0)),
            str(value.get("user_id") or ""),
        ),
    )
    scored: dict[str, tuple[int, Decimal]] = {}
    index = 0
    while index < len(ordered):
        score = int(ordered[index].get("score", 0))
        medals = int(ordered[index].get("medals", 0))
        end = index + 1
        while end < len(ordered) and (
            int(ordered[end].get("score", 0)),
            int(ordered[end].get("medals", 0)),
        ) == (score, medals):
            end += 1
        points = sum(PLACEMENT_POINTS[index:end], Decimal("0")) / (end - index)
        for value in ordered[index:end]:
            user_id = str(value.get("user_id") or "")
            if not user_id:
                raise ValueError("tournament result is missing a user")
            scored[user_id] = (index + 1, points)
        index = end
    return scored


def weekly_start(
    now: float,
    *,
    weekday: int = 5,
    hour: int = 19,
    timezone_name: str = "America/Indiana/Indianapolis",
) -> float:
    zone = ZoneInfo(timezone_name)
    local_now = datetime.fromtimestamp(now, zone)
    days = (weekday - local_now.weekday()) % 7
    candidate = (local_now + timedelta(days=days)).replace(
        hour=hour, minute=0, second=0, microsecond=0
    )
    if candidate < local_now and local_now - candidate > timedelta(hours=12):
        candidate += timedelta(days=7)
    return candidate.timestamp()


class PostgresTournamentRepository:
    def __init__(
        self,
        pool: ConnectionPool,
        *,
        weekday: int = 5,
        hour: int = 19,
        timezone_name: str = "America/Indiana/Indianapolis",
        join_window_seconds: float = 30 * 60,
    ) -> None:
        if weekday not in range(7) or hour not in range(24):
            raise ValueError("invalid weekly tournament schedule")
        self.pool = pool
        self.weekday = weekday
        self.hour = hour
        self.timezone_name = timezone_name
        self.join_window_seconds = join_window_seconds

    def _ensure_scheduled(self, connection: object, now: float) -> str:
        row = connection.execute(  # type: ignore[attr-defined]
            """select tournament_id::text from server_tournaments
                 where status in ('enrollment','playing')
                 order by starts_at limit 1"""
        ).fetchone()
        if row is not None:
            return str(row[0])
        starts_at = weekly_start(
            now,
            weekday=self.weekday,
            hour=self.hour,
            timezone_name=self.timezone_name,
        )
        tournament_id = str(
            uuid.uuid5(uuid.NAMESPACE_URL, f"kolkhoz:weekly:{int(starts_at)}")
        )
        connection.execute(  # type: ignore[attr-defined]
            """insert into server_tournaments (
                   tournament_id, starts_at, join_opens_at, join_closes_at, status
               ) values (%s::uuid, to_timestamp(%s), to_timestamp(%s),
                         to_timestamp(%s), 'enrollment')
               on conflict (starts_at) do nothing""",
            (
                tournament_id,
                starts_at,
                starts_at - self.join_window_seconds,
                starts_at,
            ),
        )
        return tournament_id

    def status(self, *, user_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection:  # type: ignore[attr-defined]
            row = connection.execute(
                """select tournament_id::text, extract(epoch from starts_at),
                          extract(epoch from join_opens_at),
                          extract(epoch from join_closes_at), status, current_round
                     from server_tournaments
                    where status in ('enrollment','playing') or starts_at > to_timestamp(%s)
                       or (status='completed' and updated_at > to_timestamp(%s)-interval '12 hours'
                           and exists (
                               select 1 from server_tournament_entries mine
                                where mine.tournament_id=server_tournaments.tournament_id
                                  and mine.user_id=%s::uuid
                           ))
                    order by case
                               when status='completed' then 0
                               when status in ('enrollment','playing') then 1
                               else 2
                             end,
                             starts_at limit 1""",
                (now, now, user_id),
            ).fetchone()
            if row is None:
                return {"available": False}
            tournament_id = str(row[0])
            entrants = self._participants(connection, tournament_id)
            standings = sorted(entrants, key=standings_key)
            mine = next((value for value in entrants if value.user_id == user_id), None)
            table = connection.execute(
                """select t.table_id::text, t.session_id::text, t.round_number,
                          t.table_number, t.status, s.player_id
                     from server_tournament_tables t
                     join server_tournament_table_seats s using (table_id)
                    where t.tournament_id = %s::uuid and s.user_id = %s::uuid
                      and t.round_number = %s
                    limit 1""",
                (tournament_id, user_id, int(row[5])),
            ).fetchone()
        return {
            "available": True,
            "tournamentID": tournament_id,
            "startsAt": float(row[1]),
            "joinOpensAt": float(row[2]),
            "joinClosesAt": float(row[3]),
            "status": str(row[4]),
            "roundNumber": int(row[5]),
            "totalRounds": TOTAL_ROUNDS,
            "joined": mine is not None and not mine.forfeited,
            "forfeited": mine is not None and mine.forfeited,
            "entrantCount": len(entrants),
            "standings": [
                {
                    "rank": index + 1,
                    "userID": value.user_id,
                    "displayName": value.display_name,
                    "points": float(value.points),
                    "wins": value.wins,
                    "gameScore": value.game_score,
                    "isBot": value.is_bot,
                    "forfeited": value.forfeited,
                }
                for index, value in enumerate(standings)
            ],
            "table": None
            if table is None
            else {
                "tableID": str(table[0]),
                "sessionID": str(table[1]),
                "roundNumber": int(table[2]),
                "tableNumber": int(table[3]),
                "status": str(table[4]),
                "playerID": int(table[5]),
            },
        }

    def session_context(self, *, session_id: str) -> dict[str, object] | None:
        with self.pool.connection() as connection:  # type: ignore[attr-defined]
            row = connection.execute(
                """select t.tournament_id::text,t.round_number,t.table_number,
                          event.current_round,event.status
                     from server_tournament_tables t
                     join server_tournaments event using (tournament_id)
                    where t.session_id=%s::uuid""",
                (session_id,),
            ).fetchone()
        if row is None:
            return None
        return {
            "tournamentID": str(row[0]),
            "roundNumber": int(row[1]),
            "tableNumber": int(row[2]),
            "totalRounds": TOTAL_ROUNDS,
            "status": str(row[4]),
        }

    def join(self, *, user_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            tournament_id = self._ensure_scheduled(connection, now)
            row = connection.execute(
                """select status, extract(epoch from join_opens_at),
                          extract(epoch from join_closes_at)
                     from server_tournaments where tournament_id = %s::uuid
                     for update""",
                (tournament_id,),
            ).fetchone()
            if row is None or str(row[0]) != "enrollment":
                raise ValueError("tournament enrollment is closed")
            if now < float(row[1]) or now >= float(row[2]):
                raise ValueError("tournament enrollment is not open")
            connection.execute(
                """insert into server_tournament_entries (
                       tournament_id, user_id, controller, is_bot, status, joined_at
                   ) values (%s::uuid, %s::uuid, 'human', false, 'active', to_timestamp(%s))
                   on conflict (tournament_id, user_id) do update set
                       controller = 'human', is_bot = false, status = 'active',
                       joined_at = excluded.joined_at""",
                (tournament_id, user_id, now),
            )
        return self.status(user_id=user_id, now=now)

    def withdraw(self, *, user_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(
                """select e.tournament_id::text, t.status
                     from server_tournament_entries e
                     join server_tournaments t using (tournament_id)
                    where e.user_id = %s::uuid and e.status = 'active'
                      and t.status in ('enrollment','playing')
                    for update""",
                (user_id,),
            ).fetchone()
            if row is None:
                raise ValueError("not entered in the weekly tournament")
            status = "withdrawn" if str(row[1]) == "enrollment" else "forfeited"
            connection.execute(
                """update server_tournament_entries
                      set status = %s,
                          controller = case when %s = 'forfeited' then 'mediumAI' else controller end
                    where tournament_id = %s::uuid and user_id = %s::uuid""",
                (status, status, str(row[0]), user_id),
            )
        return self.status(user_id=user_id, now=now)

    def prepare(self, *, now: float) -> list[TournamentTablePlan]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            tournament_id = self._ensure_scheduled(connection, now)
            event = connection.execute(
                """select status, current_round, extract(epoch from join_closes_at)
                     from server_tournaments where tournament_id = %s::uuid
                     for update""",
                (tournament_id,),
            ).fetchone()
            if event is None:
                return []
            status, current_round, join_closes_at = (
                str(event[0]),
                int(event[1]),
                float(event[2]),
            )
            if status == "enrollment" and now >= join_closes_at:
                humans = connection.execute(
                    """select count(*) from server_tournament_entries
                        where tournament_id = %s::uuid and status = 'active' and not is_bot""",
                    (tournament_id,),
                ).fetchone()
                human_count = int(humans[0]) if humans else 0
                if human_count == 0:
                    connection.execute(
                        """update server_tournaments set status='cancelled', updated_at=to_timestamp(%s)
                            where tournament_id=%s::uuid""",
                        (now, tournament_id),
                    )
                    return []
                needed = (-human_count) % PLAYER_COUNT
                if human_count + needed < PLAYER_COUNT:
                    needed += PLAYER_COUNT
                bots = connection.execute(
                    """select b.user_id::text, b.controller
                         from public.server_bot_profiles b
                        where b.active
                          and not exists (
                              select 1 from server_tournament_entries e
                               where e.user_id = b.user_id
                                 and e.status in ('active','forfeited')
                          )
                          and not exists (
                              select 1 from server_seats s join server_sessions g using (session_id)
                               where s.user_id = b.user_id::text and s.occupied
                                 and g.status in ('open','active')
                          )
                        order by b.use_count, b.user_id limit %s""",
                    (needed,),
                ).fetchall()
                if len(bots) != needed:
                    raise RuntimeError("not enough profile bots for weekly tournament")
                for bot in bots:
                    connection.execute(
                        """insert into server_tournament_entries (
                               tournament_id,user_id,controller,is_bot,status,joined_at
                           ) values (%s::uuid,%s::uuid,%s,true,'active',to_timestamp(%s))""",
                        (tournament_id, str(bot[0]), str(bot[1]), now),
                    )
                current_round = 1
                connection.execute(
                    """update server_tournaments set status='playing', current_round=1,
                              updated_at=to_timestamp(%s) where tournament_id=%s::uuid""",
                    (now, tournament_id),
                )
                self._plan_round(connection, tournament_id, current_round, now)
            elif status == "playing":
                counts = connection.execute(
                    """select count(*), count(*) filter (where status='completed')
                         from server_tournament_tables
                        where tournament_id=%s::uuid and round_number=%s""",
                    (tournament_id, current_round),
                ).fetchone()
                total, complete = (int(counts[0]), int(counts[1])) if counts else (0, 0)
                if total > 0 and total == complete:
                    if current_round >= TOTAL_ROUNDS:
                        connection.execute(
                            """update server_tournaments set status='completed',
                                      updated_at=to_timestamp(%s)
                                where tournament_id=%s::uuid""",
                            (now, tournament_id),
                        )
                    else:
                        current_round += 1
                        connection.execute(
                            """update server_tournaments set current_round=%s,
                                      updated_at=to_timestamp(%s)
                                where tournament_id=%s::uuid""",
                            (current_round, now, tournament_id),
                        )
                        self._plan_round(connection, tournament_id, current_round, now)
            rows = connection.execute(
                """select table_id::text from server_tournament_tables
                    where tournament_id=%s::uuid and status='planned'
                    order by round_number,table_number""",
                (tournament_id,),
            ).fetchall()
            return [self._table_plan(connection, str(row[0])) for row in rows]

    def _plan_round(
        self, connection: object, tournament_id: str, round_number: int, now: float
    ) -> None:
        participants = self._participants(connection, tournament_id)
        groups = plan_round(
            [value for value in participants if value.controller != "withdrawn"],
            round_number=round_number,
        )
        for table_index, group in enumerate(groups, 1):
            table_id = str(
                uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"kolkhoz:tournament:{tournament_id}:{round_number}:{table_index}",
                )
            )
            session_id = str(
                uuid.uuid5(uuid.NAMESPACE_URL, f"kolkhoz:tournament-session:{table_id}")
            )
            connection.execute(  # type: ignore[attr-defined]
                """insert into server_tournament_tables (
                       table_id,tournament_id,round_number,table_number,session_id,status,created_at
                   ) values (%s::uuid,%s::uuid,%s,%s,%s::uuid,'planned',to_timestamp(%s))
                   on conflict (tournament_id,round_number,table_number) do nothing""",
                (table_id, tournament_id, round_number, table_index, session_id, now),
            )
            for player_id, participant in enumerate(group):
                connection.execute(  # type: ignore[attr-defined]
                    """insert into server_tournament_table_seats (table_id,user_id,player_id)
                       values (%s::uuid,%s::uuid,%s) on conflict do nothing""",
                    (table_id, participant.user_id, player_id),
                )

    def _participants(
        self, connection: object, tournament_id: str
    ) -> list[TournamentParticipant]:
        rows = connection.execute(  # type: ignore[attr-defined]
            """select e.user_id::text,e.controller,e.is_bot,e.status,
                      e.tournament_points,e.wins,e.game_score,e.final_placement,
                      coalesce(p.display_name,'Player')
                 from server_tournament_entries e
                 left join public.profiles p on p.user_id=e.user_id
                where e.tournament_id=%s::uuid and e.status <> 'withdrawn'""",
            (tournament_id,),
        ).fetchall()
        history = connection.execute(  # type: ignore[attr-defined]
            """select s.user_id::text,s.player_id,array_agg(o.user_id::text)
                 from server_tournament_table_seats s
                 join server_tournament_tables t using (table_id)
                 join server_tournament_table_seats o on o.table_id=s.table_id and o.user_id<>s.user_id
                where t.tournament_id=%s::uuid
                group by s.user_id,s.player_id""",
            (tournament_id,),
        ).fetchall()
        opponents: dict[str, list[str]] = {}
        seats: dict[str, list[int]] = {}
        for user_id, player_id, values in history:
            opponents.setdefault(str(user_id), []).extend(
                str(value) for value in values
            )
            seat_counts = seats.setdefault(str(user_id), [0, 0, 0, 0])
            seat_counts[int(player_id)] += 1
        points_by_user = {str(row[0]): Decimal(str(row[4])) for row in rows}
        return [
            TournamentParticipant(
                user_id=str(row[0]),
                controller=str(row[1]),
                display_name=str(row[8]),
                is_bot=bool(row[2]),
                forfeited=str(row[3]) == "forfeited",
                points=Decimal(str(row[4])),
                wins=int(row[5]),
                game_score=int(row[6]),
                final_placement=None if row[7] is None else int(row[7]),
                opponent_points=sum(
                    (
                        points_by_user.get(value, Decimal("0"))
                        for value in opponents.get(str(row[0]), [])
                    ),
                    Decimal("0"),
                ),
                opponents=tuple(opponents.get(str(row[0]), [])),
                seat_counts=tuple(seats.get(str(row[0]), [0, 0, 0, 0])),  # type: ignore[arg-type]
            )
            for row in rows
        ]

    def _table_plan(self, connection: object, table_id: str) -> TournamentTablePlan:
        row = connection.execute(  # type: ignore[attr-defined]
            """select tournament_id::text,round_number,table_number,session_id::text
                 from server_tournament_tables where table_id=%s::uuid""",
            (table_id,),
        ).fetchone()
        participants = self._participants(connection, str(row[0]))
        by_id = {value.user_id: value for value in participants}
        seats = connection.execute(  # type: ignore[attr-defined]
            """select user_id::text from server_tournament_table_seats
                where table_id=%s::uuid order by player_id""",
            (table_id,),
        ).fetchall()
        return TournamentTablePlan(
            table_id,
            str(row[0]),
            int(row[1]),
            int(row[2]),
            str(row[3]),
            tuple(by_id[str(value[0])] for value in seats),
        )

    def mark_table_active(self, *, table_id: str, now: float) -> bool:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            updated = connection.execute(
                """update server_tournament_tables set status='active'
                    where table_id=%s::uuid and status='planned'""",
                (table_id,),
            )
        return updated.rowcount == 1

    def mark_table_planned(self, *, table_id: str) -> None:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute(
                """update server_tournament_tables set status='planned'
                    where table_id=%s::uuid and status='active'""",
                (table_id,),
            )

    def record_game_finished(
        self, *, session_id: str, results: Sequence[Mapping[str, object]], now: float
    ) -> bool:
        scored = score_table(results)
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            table = connection.execute(
                """select table_id::text,tournament_id::text,round_number,table_number
                     from server_tournament_tables
                    where session_id=%s::uuid and status='active' for update""",
                (session_id,),
            ).fetchone()
            if table is None:
                return False
            result_by_user = {
                str(value.get("user_id") or ""): value for value in results
            }
            for user_id, (placement, points) in scored.items():
                result = result_by_user[user_id]
                connection.execute(
                    """update server_tournament_table_seats
                          set score=%s,medals=%s,placement=%s,tournament_points=%s
                        where table_id=%s::uuid and user_id=%s::uuid""",
                    (
                        int(result.get("score", 0)),
                        int(result.get("medals", 0)),
                        placement,
                        points,
                        str(table[0]),
                        user_id,
                    ),
                )
                connection.execute(
                    """update server_tournament_entries
                          set tournament_points=tournament_points+%s,
                              wins=wins+%s,game_score=game_score+%s
                        where tournament_id=%s::uuid and user_id=%s::uuid""",
                    (
                        points,
                        1 if placement == 1 else 0,
                        int(result.get("score", 0)),
                        str(table[1]),
                        user_id,
                    ),
                )
                if int(table[2]) == TOTAL_ROUNDS:
                    connection.execute(
                        """update server_tournament_entries
                              set final_placement=%s
                            where tournament_id=%s::uuid and user_id=%s::uuid""",
                        (
                            (int(table[3]) - 1) * PLAYER_COUNT + placement,
                            str(table[1]),
                            user_id,
                        ),
                    )
            connection.execute(
                """update server_tournament_entries e
                      set status='forfeited',controller='mediumAI'
                     from server_tournament_table_seats ts
                     join server_seats s on s.session_id=%s::uuid
                                        and s.player_id=ts.player_id
                    where ts.table_id=%s::uuid and e.tournament_id=%s::uuid
                      and e.user_id=ts.user_id and s.abandoned and not e.is_bot""",
                (session_id, str(table[0]), str(table[1])),
            )
            connection.execute(
                """update server_tournament_tables set status='completed',completed_at=to_timestamp(%s)
                    where table_id=%s::uuid""",
                (now, str(table[0])),
            )
        return True


class TournamentScheduler:
    def __init__(
        self,
        repository: TournamentRepository,
        provision: Callable[[TournamentTablePlan], None],
    ) -> None:
        self.repository = repository
        self.provision = provision
        self.consecutive_failures = 0
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self, *, now: float | None = None) -> int:
        plans = self.repository.prepare(now=time.time() if now is None else now)
        completed = 0
        for plan in plans:
            if not self.repository.mark_table_active(
                table_id=plan.table_id, now=time.time()
            ):
                continue
            try:
                self.provision(plan)
                completed += 1
            except Exception:
                self.repository.mark_table_planned(table_id=plan.table_id)
                self.consecutive_failures += 1
                raise
        self.consecutive_failures = 0
        return completed

    @property
    def healthy(self) -> bool:
        return self.consecutive_failures == 0 and (
            self._thread is None or self._thread.is_alive()
        )

    def start(self, *, interval_seconds: float = 1.0) -> None:
        if self._thread is not None:
            raise RuntimeError("tournament scheduler is already running")

        def run() -> None:
            while not self._stop.wait(interval_seconds):
                try:
                    self.run_once()
                except Exception:
                    __import__("logging").exception("weekly tournament tick failed")

        self._thread = threading.Thread(
            target=run, name="kolkhoz-weekly-tournament", daemon=True
        )
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None
