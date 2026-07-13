"""Canonical HTTP compatibility contract for the Flutter online client.

Keeping the inventory separate from the transport makes missing parity visible while
the greenfield gateway is implemented route by route.  Paths use ``{name}`` for one
non-empty URL segment.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Route:
    method: str
    path: str
    operation: str

    @property
    def pattern(self) -> re.Pattern[str]:
        parts = self.path.strip("/").split("/")
        expression = "/".join(
            r"[^/]+" if part.startswith("{") and part.endswith("}") else re.escape(part)
            for part in parts
        )
        return re.compile(rf"^/{expression}/?$")

    def matches(self, method: str, path: str) -> bool:
        return (
            self.method == method.upper() and self.pattern.fullmatch(path) is not None
        )


# This is the complete route matrix exposed by the production server as of
# 2026-07-11, including public leaderboard and profile lookup.
ROUTES: tuple[Route, ...] = (
    Route("GET", "/health", "health"),
    Route("GET", "/metrics", "metrics"),
    Route("GET", "/canary", "canary"),
    Route("GET", "/admin/operations", "admin.operations"),
    Route("POST", "/presence", "presence.heartbeat"),
    Route("POST", "/active-session/sync", "active_session.sync"),
    Route("PUT", "/installations/{installationID}", "installations.upsert"),
    Route("DELETE", "/installations/{installationID}", "installations.delete"),
    Route("GET", "/leaderboard", "profiles.leaderboard"),
    Route("GET", "/profiles/{userID}", "profiles.get_public"),
    Route("GET", "/results/recent", "results.recent"),
    Route("GET", "/results/{sessionID}/replay", "results.replay"),
    Route("POST", "/results/{sessionID}/rematch", "results.rematch"),
    Route("GET", "/challenges/daily", "challenges.daily"),
    Route("POST", "/challenges/daily/start", "challenges.daily.start"),
    Route("GET", "/comrades", "comrades.list"),
    Route("POST", "/comrades", "comrades.request"),
    Route("POST", "/comrades/respond", "comrades.respond"),
    Route("POST", "/comrades/remove", "comrades.remove"),
    Route("GET", "/sessions", "sessions.list"),
    Route("GET", "/sessions/watchable", "sessions.watchable"),
    Route("POST", "/sessions", "sessions.create"),
    Route("GET", "/sessions/invites", "sessions.invites.pending"),
    Route("POST", "/sessions/matchmake", "sessions.matchmake"),
    Route("GET", "/sessions/{sessionID}", "sessions.get"),
    Route("POST", "/sessions/{sessionID}/invites", "sessions.invites.send"),
    Route(
        "POST",
        "/sessions/{sessionID}/invites/decline",
        "sessions.invites.decline",
    ),
    Route("POST", "/sessions/{sessionID}/join", "sessions.join"),
    Route(
        "POST",
        "/sessions/{sessionID}/players/{playerID}/leave",
        "sessions.players.leave",
    ),
    Route(
        "POST",
        "/sessions/{sessionID}/players/{playerID}/kick",
        "sessions.players.kick",
    ),
    Route("GET", "/sessions/{sessionID}/state", "sessions.state"),
    Route("GET", "/sessions/{sessionID}/spectate", "sessions.spectate"),
    Route("GET", "/sessions/{sessionID}/actions", "sessions.actions.since"),
    Route(
        "GET",
        "/sessions/{sessionID}/players/{playerID}/actions",
        "sessions.actions.legal",
    ),
    Route("POST", "/sessions/{sessionID}/actions", "sessions.actions.submit"),
    Route("POST", "/sessions/{sessionID}/reactions", "sessions.reactions.submit"),
)


def resolve_route(method: str, path: str) -> Route | None:
    """Return the unique compatibility route for a request, if any."""
    matches = [route for route in ROUTES if route.matches(method, path)]
    if not matches:
        return None

    def specificity(route: Route) -> int:
        return sum(
            not (part.startswith("{") and part.endswith("}"))
            for part in route.path.strip("/").split("/")
        )

    best_specificity = max(specificity(route) for route in matches)
    best = [route for route in matches if specificity(route) == best_specificity]
    if len(best) > 1:
        raise RuntimeError(f"ambiguous route contract for {method} {path}")
    return best[0]
