"""Store-neutral purchase verification and account entitlements."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Protocol


FULL_GAME_ENTITLEMENT = "full_game"


class PurchaseVerificationError(ValueError):
    pass


class PurchaseAlreadyClaimed(ValueError):
    pass


@dataclass(frozen=True)
class VerifiedPurchase:
    provider: str
    original_transaction_id: str
    product_id: str
    account_reference: str
    active: bool
    purchased_at_ms: int | None = None


class PurchaseVerifier(Protocol):
    provider: str

    def verify_purchase(self, verification_data: str) -> VerifiedPurchase: ...

    def verify_notification(self, signed_payload: str) -> VerifiedPurchase | None: ...


class EntitlementRepository(Protocol):
    def active_entitlements(self, *, user_id: str) -> set[str]: ...

    def claim(
        self, *, user_id: str, entitlement_id: str, purchase: VerifiedPurchase
    ) -> None: ...

    def apply_store_status(self, purchase: VerifiedPurchase) -> None: ...


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


class PostgresEntitlementRepository:
    def __init__(self, pool: object) -> None:
        self._pool = pool

    def active_entitlements(self, *, user_id: str) -> set[str]:
        with self._pool.connection() as connection:
            rows = connection.execute(
                """select entitlement_id from server_entitlements
                     where user_id=%s::uuid and active""",
                (user_id,),
            ).fetchall()
        return {str(row[0]) for row in rows}

    def claim(
        self, *, user_id: str, entitlement_id: str, purchase: VerifiedPurchase
    ) -> None:
        with self._pool.connection() as connection, connection.transaction():
            existing = connection.execute(
                """select user_id from server_store_purchases
                     where provider=%s and original_transaction_id=%s
                     for update""",
                (purchase.provider, purchase.original_transaction_id),
            ).fetchone()
            if existing is not None and str(existing[0]) != user_id:
                raise PurchaseAlreadyClaimed(
                    "purchase is already linked to another account"
                )
            connection.execute(
                """insert into server_store_purchases
                       (provider,original_transaction_id,user_id,product_id,
                        account_reference,active,purchased_at,updated_at)
                     values (%s,%s,%s::uuid,%s,%s,%s,
                             case when %s is null then null
                                  else to_timestamp(%s / 1000.0) end,now())
                     on conflict (provider,original_transaction_id) do update set
                       product_id=excluded.product_id,
                       account_reference=excluded.account_reference,
                       active=excluded.active,
                       purchased_at=coalesce(server_store_purchases.purchased_at,
                                             excluded.purchased_at),
                       updated_at=now()""",
                (
                    purchase.provider,
                    purchase.original_transaction_id,
                    user_id,
                    purchase.product_id,
                    purchase.account_reference,
                    purchase.active,
                    purchase.purchased_at_ms,
                    purchase.purchased_at_ms,
                ),
            )
            connection.execute(
                """insert into server_entitlements
                       (user_id,entitlement_id,active,source_provider,
                        source_transaction_id,updated_at)
                     values (%s::uuid,%s,%s,%s,%s,now())
                     on conflict (user_id,entitlement_id) do update set
                       active=excluded.active,
                       source_provider=excluded.source_provider,
                       source_transaction_id=excluded.source_transaction_id,
                       updated_at=now()""",
                (
                    user_id,
                    entitlement_id,
                    purchase.active,
                    purchase.provider,
                    purchase.original_transaction_id,
                ),
            )

    def apply_store_status(self, purchase: VerifiedPurchase) -> None:
        with self._pool.connection() as connection, connection.transaction():
            row = connection.execute(
                """update server_store_purchases set active=%s,updated_at=now()
                     where provider=%s and original_transaction_id=%s
                     returning user_id""",
                (
                    purchase.active,
                    purchase.provider,
                    purchase.original_transaction_id,
                ),
            ).fetchone()
            if row is None:
                return
            connection.execute(
                """update server_entitlements set active=%s,updated_at=now()
                     where user_id=%s and source_provider=%s
                       and source_transaction_id=%s""",
                (
                    purchase.active,
                    row[0],
                    purchase.provider,
                    purchase.original_transaction_id,
                ),
            )


class CommerceService:
    def __init__(
        self,
        repository: EntitlementRepository,
        verifiers: Mapping[str, PurchaseVerifier],
    ) -> None:
        self.repository = repository
        self.verifiers = dict(verifiers)

    def status(self, *, user_id: str) -> dict[str, object]:
        entitlements = sorted(self.repository.active_entitlements(user_id=user_id))
        return {
            "entitlements": entitlements,
            "fullGame": FULL_GAME_ENTITLEMENT in entitlements,
        }

    def claim(
        self, *, user_id: str, provider: str, verification_data: str
    ) -> dict[str, object]:
        verifier = self.verifiers.get(provider)
        if verifier is None:
            raise PurchaseVerificationError("purchase provider is not configured")
        purchase = verifier.verify_purchase(verification_data)
        if purchase.provider != provider:
            raise PurchaseVerificationError("purchase provider does not match")
        if not purchase.active:
            raise PurchaseVerificationError("purchase is not active")
        if purchase.account_reference.lower() != user_id.lower():
            raise PurchaseVerificationError(
                "purchase is linked to a different Kolkhoz account"
            )
        self.repository.claim(
            user_id=user_id,
            entitlement_id=FULL_GAME_ENTITLEMENT,
            purchase=purchase,
        )
        return self.status(user_id=user_id)

    def notification(self, *, provider: str, signed_payload: str) -> None:
        verifier = self.verifiers.get(provider)
        if verifier is None:
            raise PurchaseVerificationError("purchase provider is not configured")
        purchase = verifier.verify_notification(signed_payload)
        if purchase is not None:
            self.repository.apply_store_status(purchase)


class ApplePurchaseVerifier:
    provider = "apple"

    def __init__(
        self,
        signed_data_verifiers: tuple[object, ...],
        *,
        full_game_product_id: str,
    ) -> None:
        self._signed_data_verifiers = signed_data_verifiers
        self._full_game_product_id = full_game_product_id

    @classmethod
    def from_environment(cls) -> ApplePurchaseVerifier | None:
        certificate_paths = tuple(
            Path(value.strip())
            for value in os.environ.get("APPLE_ROOT_CERTIFICATE_PATHS", "").split(",")
            if value.strip()
        )
        if not certificate_paths:
            return None
        try:
            from appstoreserverlibrary.models.Environment import Environment
            from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
        except ImportError as error:
            raise RuntimeError(
                "Apple commerce requires app-store-server-library"
            ) from error
        roots = [path.read_bytes() for path in certificate_paths]
        bundle_id = os.environ.get("APPLE_APP_BUNDLE_ID", "com.williamtheisen.kolkhoz")
        app_apple_id_value = os.environ.get("APPLE_APP_ID")
        verifiers: list[object] = []
        if app_apple_id_value:
            verifiers.append(
                SignedDataVerifier(
                    roots,
                    True,
                    Environment.PRODUCTION,
                    bundle_id,
                    int(app_apple_id_value),
                )
            )
        sandbox = SignedDataVerifier(roots, True, Environment.SANDBOX, bundle_id, None)
        verifiers.append(sandbox)
        return cls(
            tuple(verifiers),
            full_game_product_id=os.environ.get(
                "KOLKHOZ_APPLE_FULL_GAME_PRODUCT_ID",
                "com.williamtheisen.kolkhoz.fullgame",
            ),
        )

    def verify_purchase(self, verification_data: str) -> VerifiedPurchase:
        transaction = self._verify(
            "verify_and_decode_signed_transaction", verification_data
        )
        return self._purchase(transaction)

    def verify_notification(self, signed_payload: str) -> VerifiedPurchase | None:
        notification = self._verify("verify_and_decode_notification", signed_payload)
        data = getattr(notification, "data", None)
        signed_transaction = getattr(data, "signedTransactionInfo", None)
        if not signed_transaction:
            return None
        transaction = self._verify(
            "verify_and_decode_signed_transaction", str(signed_transaction)
        )
        return self._purchase(transaction)

    def _verify(self, method: str, value: str) -> object:
        last_error: Exception | None = None
        for verifier in self._signed_data_verifiers:
            try:
                return getattr(verifier, method)(value)
            except Exception as error:
                last_error = error
        raise PurchaseVerificationError(
            "Apple could not verify the transaction"
        ) from last_error

    def _purchase(self, transaction: object) -> VerifiedPurchase:
        product_id = str(getattr(transaction, "productId", "") or "")
        if product_id != self._full_game_product_id:
            raise PurchaseVerificationError("unexpected Apple product")
        ownership = str(getattr(transaction, "inAppOwnershipType", "") or "")
        if ownership.endswith("FAMILY_SHARED"):
            raise PurchaseVerificationError("family-shared purchases are not supported")
        original_id = str(
            getattr(transaction, "originalTransactionId", "")
            or getattr(transaction, "transactionId", "")
        )
        account_reference = str(getattr(transaction, "appAccountToken", "") or "")
        if not original_id or not account_reference:
            raise PurchaseVerificationError(
                "Apple transaction is missing account linkage"
            )
        return VerifiedPurchase(
            provider=self.provider,
            original_transaction_id=original_id,
            product_id=product_id,
            account_reference=account_reference,
            active=getattr(transaction, "revocationDate", None) is None,
            purchased_at_ms=getattr(transaction, "purchaseDate", None),
        )
