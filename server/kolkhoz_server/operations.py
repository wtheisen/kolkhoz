"""Admin-only operational read model. No secrets are selected or returned."""

from __future__ import annotations

import time


class PostgresOperationsRepository:
    def __init__(self, pool: object) -> None:
        self._pool = pool

    def snapshot(self, *, version: str) -> dict[str, object]:
        with self._pool.connection() as connection:
            games = connection.execute(
                """select s.session_id::text,s.status,-1,
                          s.turn_player_id,
                          extract(epoch from now()-s.updated_at),
                          seat.controller
                     from server_sessions s
                     left join server_seats seat
                       on seat.session_id=s.session_id
                      and seat.player_id=s.turn_player_id
                    where s.status in ('open','active')
                    order by s.updated_at asc limit 200"""
            ).fetchall()
            failures = connection.execute(
                """select id,event_type,attempts,last_error_code,
                          extract(epoch from created_at)
                     from server_notification_outbox
                    where status='failed' order by id desc limit 100"""
            ).fetchall()
            counts = connection.execute(
                """select
                     count(*) filter (where status='pending'),
                     count(*) filter (where status='failed')
                   from server_notification_outbox"""
            ).fetchone()
        game_values = [
            {
                "sessionID": str(row[0]),
                "status": str(row[1]),
                "phase": int(row[2]),
                "currentActor": int(row[3]) if row[3] is not None else None,
                "lastActionAgeSeconds": float(row[4]),
                "expectedActor": (
                    "human" if str(row[5]) == "human" else "AI"
                    if row[5] is not None else None
                ),
                "suspicious": bool(
                    str(row[1]) == "active" and float(row[4]) > 180
                ),
            }
            for row in games
        ]
        return {
            "generatedAt": time.time(),
            "deploymentVersion": version,
            "games": game_values,
            "suspiciousGames": [game for game in game_values if game["suspicious"]],
            "notificationOutbox": {
                "pending": int(counts[0]),
                "failed": int(counts[1]),
                "failures": [
                    {
                        "id": int(row[0]),
                        "eventType": str(row[1]),
                        "attempts": int(row[2]),
                        "errorCode": str(row[3] or "unknown"),
                        "createdAt": float(row[4]),
                    }
                    for row in failures
                ],
            },
            "recentServerErrors": [],
            "aiCanary": {"status": "unknown"},
            "backup": {"status": "unknown"},
            "watchdog": {"status": "unknown"},
        }
