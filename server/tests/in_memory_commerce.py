from __future__ import annotations

from server.kolkhoz_server.commerce import (
    FULL_GAME_ENTITLEMENT,
    PurchaseAlreadyClaimed,
    VerifiedPurchase,
)


class InMemoryEntitlementRepository:
    """Deterministic repository for contract tests and local composition."""

    def __init__(self) -> None:
        self.purchases: dict[tuple[str, str], tuple[str, VerifiedPurchase]] = {}
        self.entitlements: dict[tuple[str, str], bool] = {}

    def active_entitlements(self, *, user_id: str) -> set[str]:
        return {
            entitlement_id
            for (owner_id, entitlement_id), active in self.entitlements.items()
            if owner_id == user_id and active
        }

    def claim(
        self, *, user_id: str, entitlement_id: str, purchase: VerifiedPurchase
    ) -> None:
        key = (purchase.provider, purchase.original_transaction_id)
        existing = self.purchases.get(key)
        if existing is not None and existing[0] != user_id:
            raise PurchaseAlreadyClaimed(
                "purchase is already linked to another account"
            )
        self.purchases[key] = (user_id, purchase)
        self.entitlements[(user_id, entitlement_id)] = purchase.active

    def apply_store_status(self, purchase: VerifiedPurchase) -> None:
        existing = self.purchases.get(
            (purchase.provider, purchase.original_transaction_id)
        )
        if existing is None:
            return
        user_id, _ = existing
        self.purchases[(purchase.provider, purchase.original_transaction_id)] = (
            user_id,
            purchase,
        )
        self.entitlements[(user_id, FULL_GAME_ENTITLEMENT)] = purchase.active
