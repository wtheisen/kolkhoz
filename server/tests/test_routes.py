from __future__ import annotations

import unittest

from server.kolkhoz_server.routes import ROUTES, resolve_route


class RouteContractTests(unittest.TestCase):
    def test_full_legacy_route_matrix_is_present(self) -> None:
        expected = {
            ("GET", "/health"),
            ("GET", "/metrics"),
            ("GET", "/canary"),
            ("GET", "/admin/operations"),
            ("POST", "/identity/platform/{provider}"),
            ("POST", "/identity/guest"),
            ("POST", "/identity/device-links"),
            ("GET", "/identity/device-links/{requestID}"),
            ("DELETE", "/identity/device-links/{requestID}"),
            ("POST", "/identity/device-links/redeem"),
            ("POST", "/identity/device-links/{requestID}/approve"),
            ("DELETE", "/account"),
            ("PUT", "/installations/{installationID}"),
            ("DELETE", "/installations/{installationID}"),
            ("GET", "/commerce/entitlements"),
            ("POST", "/commerce/purchases/claim"),
            ("POST", "/commerce/providers/apple/notifications"),
            ("POST", "/commerce/providers/steam/purchases"),
            (
                "POST",
                "/commerce/providers/steam/purchases/{orderID}/authorize",
            ),
            ("POST", "/commerce/providers/steam/sync"),
            ("POST", "/presence"),
            ("POST", "/active-session/sync"),
            ("GET", "/leaderboard"),
            ("GET", "/results/recent"),
            ("GET", "/results/{sessionID}/replay"),
            ("POST", "/results/{sessionID}/rematch"),
            ("GET", "/challenges/daily"),
            ("POST", "/challenges/daily/start"),
            ("GET", "/tournaments/weekly"),
            ("POST", "/tournaments/weekly/join"),
            ("POST", "/tournaments/weekly/leave"),
            ("GET", "/profiles/{userID}"),
            ("GET", "/comrades"),
            ("POST", "/comrades"),
            ("POST", "/comrades/respond"),
            ("POST", "/comrades/remove"),
            ("GET", "/sessions"),
            ("GET", "/sessions/watchable"),
            ("POST", "/sessions"),
            ("GET", "/sessions/invites"),
            ("POST", "/sessions/matchmake"),
            ("GET", "/sessions/{sessionID}"),
            ("POST", "/sessions/{sessionID}/invites"),
            ("POST", "/sessions/{sessionID}/invites/decline"),
            ("POST", "/sessions/{sessionID}/join"),
            ("POST", "/sessions/{sessionID}/players/{playerID}/leave"),
            ("POST", "/sessions/{sessionID}/players/{playerID}/kick"),
            ("GET", "/sessions/{sessionID}/state"),
            ("GET", "/sessions/{sessionID}/spectate"),
            ("GET", "/sessions/{sessionID}/actions"),
            ("GET", "/sessions/{sessionID}/players/{playerID}/actions"),
            ("POST", "/sessions/{sessionID}/actions"),
            ("POST", "/sessions/{sessionID}/reactions"),
        }
        self.assertEqual(expected, {(route.method, route.path) for route in ROUTES})

    def test_dynamic_routes_resolve_without_shadowing_static_routes(self) -> None:
        self.assertEqual(
            "sessions.invites.pending",
            resolve_route("GET", "/sessions/invites").operation,
        )
        self.assertEqual(
            "sessions.actions.legal",
            resolve_route("GET", "/sessions/abc/players/2/actions").operation,
        )
        self.assertEqual(
            "profiles.get_public",
            resolve_route("GET", "/profiles/user-123").operation,
        )

    def test_wrong_method_and_unknown_path_do_not_resolve(self) -> None:
        self.assertIsNone(resolve_route("DELETE", "/sessions/abc"))
        self.assertIsNone(resolve_route("GET", "/games/abc"))


if __name__ == "__main__":
    unittest.main()
