from __future__ import annotations

import unittest

from server.kolkhoz_server.commerce import (
    CommerceService,
    InMemoryEntitlementRepository,
)
from server.kolkhoz_server.steam_commerce import (
    InMemorySteamOrderRepository,
    SteamCommerceError,
    SteamPurchaseService,
    SteamTransaction,
)


class FakeSteamGateway:
    app_id = 1234

    def __init__(self) -> None:
        self.steam_id = "76561198000000000"
        self.statuses: dict[int, str] = {}
        self.finalized: list[int] = []

    def authenticate_ticket(self, ticket: str) -> str:
        if ticket != "ticket":
            raise SteamCommerceError("invalid Steam authentication ticket")
        return self.steam_id

    def initialize_transaction(
        self, *, order_id: int, steam_id: str, language: str
    ) -> SteamTransaction:
        self.statuses[order_id] = "initialized"
        return SteamTransaction(order_id, f"txn-{order_id}", "initialized")

    def finalize_transaction(self, order_id: int) -> SteamTransaction:
        self.finalized.append(order_id)
        self.statuses[order_id] = "succeeded"
        return SteamTransaction(order_id, f"txn-{order_id}", "succeeded")

    def query_transaction(self, order_id: int) -> SteamTransaction:
        return SteamTransaction(order_id, f"txn-{order_id}", self.statuses[order_id])


class SteamCommerceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.entitlements = InMemoryEntitlementRepository()
        self.commerce = CommerceService(self.entitlements, {})
        self.orders = InMemorySteamOrderRepository()
        self.gateway = FakeSteamGateway()
        self.service = SteamPurchaseService(self.commerce, self.orders, self.gateway)

    def test_authorized_wallet_purchase_unlocks_account(self) -> None:
        started = self.service.start(
            user_id="user-1", ticket="ticket", language="en-US"
        )
        order_id = int(started["orderID"])

        status = self.service.authorize(
            user_id="user-1", order_id=order_id, authorized=True
        )

        self.assertTrue(status["fullGame"])
        self.assertEqual(self.gateway.finalized, [order_id])

    def test_denied_wallet_purchase_does_not_unlock(self) -> None:
        started = self.service.start(user_id="user-1", ticket="ticket")

        status = self.service.authorize(
            user_id="user-1",
            order_id=int(started["orderID"]),
            authorized=False,
        )

        self.assertFalse(status["fullGame"])

    def test_refund_sync_revokes_the_only_account_grant(self) -> None:
        started = self.service.start(user_id="user-1", ticket="ticket")
        order_id = int(started["orderID"])
        self.service.authorize(user_id="user-1", order_id=order_id, authorized=True)
        self.gateway.statuses[order_id] = "refunded"

        status = self.service.sync(user_id="user-1", ticket="ticket")

        self.assertFalse(status["fullGame"])

    def test_background_reconciliation_revokes_refund_everywhere(self) -> None:
        started = self.service.start(user_id="user-1", ticket="ticket")
        order_id = int(started["orderID"])
        self.service.authorize(user_id="user-1", order_id=order_id, authorized=True)
        self.gateway.statuses[order_id] = "refunded"

        self.assertEqual(self.service.reconcile(), 1)
        self.assertFalse(self.commerce.status(user_id="user-1")["fullGame"])

    def test_steam_account_cannot_move_to_another_kolkhoz_account(self) -> None:
        self.service.start(user_id="user-1", ticket="ticket")

        with self.assertRaisesRegex(SteamCommerceError, "another Kolkhoz account"):
            self.service.start(user_id="user-2", ticket="ticket")

    def test_owned_account_does_not_start_a_duplicate_checkout(self) -> None:
        started = self.service.start(user_id="user-1", ticket="ticket")
        self.service.authorize(
            user_id="user-1",
            order_id=int(started["orderID"]),
            authorized=True,
        )

        repeated = self.service.start(user_id="user-1", ticket="ticket")

        self.assertTrue(repeated["alreadyOwned"])
        self.assertEqual(len(self.orders.orders), 1)


if __name__ == "__main__":
    unittest.main()
