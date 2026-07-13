from __future__ import annotations

import unittest
from types import SimpleNamespace

from server.kolkhoz_server.commerce import (
    ApplePurchaseVerifier,
    CommerceService,
    FULL_GAME_ENTITLEMENT,
    InMemoryEntitlementRepository,
    PurchaseAlreadyClaimed,
    PurchaseVerificationError,
    VerifiedPurchase,
)


class FakeVerifier:
    provider = "apple"

    def __init__(self) -> None:
        self.purchase = VerifiedPurchase(
            provider="apple",
            original_transaction_id="transaction-1",
            product_id="com.williamtheisen.kolkhoz.fullgame",
            account_reference="user-1",
            active=True,
        )

    def verify_purchase(self, verification_data: str) -> VerifiedPurchase:
        if verification_data != "valid":
            raise PurchaseVerificationError("invalid purchase")
        return self.purchase

    def verify_notification(self, signed_payload: str) -> VerifiedPurchase | None:
        if signed_payload == "refund":
            return VerifiedPurchase(**{**self.purchase.__dict__, "active": False})
        return None


class CommerceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = InMemoryEntitlementRepository()
        self.verifier = FakeVerifier()
        self.service = CommerceService(self.repository, {"apple": self.verifier})

    def test_verified_purchase_unlocks_once_and_is_idempotent(self) -> None:
        status = self.service.claim(
            user_id="user-1", provider="apple", verification_data="valid"
        )
        self.assertTrue(status["fullGame"])
        self.assertEqual(status["entitlements"], [FULL_GAME_ENTITLEMENT])
        repeated = self.service.claim(
            user_id="user-1", provider="apple", verification_data="valid"
        )
        self.assertTrue(repeated["fullGame"])

    def test_purchase_cannot_be_claimed_by_another_account(self) -> None:
        self.service.claim(
            user_id="user-1", provider="apple", verification_data="valid"
        )
        self.verifier.purchase = VerifiedPurchase(
            **{**self.verifier.purchase.__dict__, "account_reference": "user-2"}
        )
        with self.assertRaises(PurchaseAlreadyClaimed):
            self.service.claim(
                user_id="user-2", provider="apple", verification_data="valid"
            )

    def test_account_reference_must_match_authenticated_user(self) -> None:
        with self.assertRaises(PurchaseVerificationError):
            self.service.claim(
                user_id="user-2", provider="apple", verification_data="valid"
            )

    def test_refund_revokes_cross_platform_entitlement(self) -> None:
        self.service.claim(
            user_id="user-1", provider="apple", verification_data="valid"
        )
        self.service.notification(provider="apple", signed_payload="refund")
        self.assertFalse(self.service.status(user_id="user-1")["fullGame"])

    def test_apple_adapter_uses_storekit_2_signed_transaction(self) -> None:
        class SignedVerifier:
            def verify_and_decode_signed_transaction(self, value: str) -> object:
                self.value = value
                return SimpleNamespace(
                    productId="com.williamtheisen.kolkhoz.fullgame",
                    originalTransactionId="apple-1",
                    appAccountToken="user-1",
                    inAppOwnershipType="PURCHASED",
                    revocationDate=None,
                    purchaseDate=123,
                )

        signed = SignedVerifier()
        verifier = ApplePurchaseVerifier(
            (signed,),
            full_game_product_id="com.williamtheisen.kolkhoz.fullgame",
        )
        purchase = verifier.verify_purchase("signed-jws")
        self.assertEqual(signed.value, "signed-jws")
        self.assertEqual(purchase.original_transaction_id, "apple-1")
        self.assertEqual(purchase.account_reference, "user-1")


if __name__ == "__main__":
    unittest.main()
