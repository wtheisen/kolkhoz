"""Steam Wallet checkout and account-wide entitlement reconciliation."""

from __future__ import annotations

import json
import logging
import os
import secrets
import ssl
import threading
import time
from dataclasses import dataclass
from typing import Mapping, Protocol
from urllib import parse, request

from .commerce import CommerceService, VerifiedPurchase
from .store import ConnectionPool

try:
    import certifi
except ImportError:
    certifi = None


STEAM_PROVIDER = "steam"
STEAM_PRODUCT_ID = "full_game"
STEAM_ITEM_ID = 1
STEAM_TICKET_IDENTITY = "kolkhoz-commerce"
REVERSED_STEAM_STATUSES = frozenset(
    {
        "refunded",
        "partialrefund",
        "chargedback",
        "refundedsuspectedfraud",
        "refundedfriendlyfraud",
    }
)


class SteamCommerceError(ValueError):
    pass


@dataclass(frozen=True)
class SteamOrder:
    order_id: int
    user_id: str
    steam_id: str
    status: str
    transaction_id: str | None = None


@dataclass(frozen=True)
class SteamTransaction:
    order_id: int
    transaction_id: str
    status: str


class SteamOrderRepository(Protocol):
    def create(self, *, user_id: str, steam_id: str) -> SteamOrder: ...

    def get(self, order_id: int) -> SteamOrder | None: ...

    def for_steam_user(self, steam_id: str) -> tuple[SteamOrder, ...]: ...

    def reconcilable(self, *, limit: int) -> tuple[SteamOrder, ...]: ...

    def update(
        self, *, order_id: int, status: str, transaction_id: str | None = None
    ) -> SteamOrder: ...


class InMemorySteamOrderRepository:
    def __init__(self) -> None:
        self.orders: dict[int, SteamOrder] = {}
        self._next_order_id = 1

    def create(self, *, user_id: str, steam_id: str) -> SteamOrder:
        order = SteamOrder(self._next_order_id, user_id, steam_id, "created")
        self.orders[order.order_id] = order
        self._next_order_id += 1
        return order

    def get(self, order_id: int) -> SteamOrder | None:
        return self.orders.get(order_id)

    def for_steam_user(self, steam_id: str) -> tuple[SteamOrder, ...]:
        return tuple(
            order for order in self.orders.values() if order.steam_id == steam_id
        )

    def reconcilable(self, *, limit: int) -> tuple[SteamOrder, ...]:
        return tuple(self.orders.values())[:limit]

    def update(
        self, *, order_id: int, status: str, transaction_id: str | None = None
    ) -> SteamOrder:
        current = self.orders[order_id]
        updated = SteamOrder(
            current.order_id,
            current.user_id,
            current.steam_id,
            status,
            transaction_id if transaction_id is not None else current.transaction_id,
        )
        self.orders[order_id] = updated
        return updated


class PostgresSteamOrderRepository:
    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    def create(self, *, user_id: str, steam_id: str) -> SteamOrder:
        for _ in range(8):
            order_id = secrets.randbits(63)
            with self._pool.connection() as connection:
                row = connection.execute(
                    """insert into server_steam_orders
                           (order_id,user_id,steam_id,status,updated_at)
                         values (%s,%s::uuid,%s,'created',now())
                         on conflict (order_id) do nothing
                         returning order_id,user_id,steam_id,status,transaction_id""",
                    (order_id, user_id, steam_id),
                ).fetchone()
            if row is not None:
                return _steam_order(row)
        raise SteamCommerceError("could not allocate a Steam order")

    def get(self, order_id: int) -> SteamOrder | None:
        with self._pool.connection() as connection:
            row = connection.execute(
                """select order_id,user_id,steam_id,status,transaction_id
                     from server_steam_orders where order_id=%s""",
                (order_id,),
            ).fetchone()
        return None if row is None else _steam_order(row)

    def for_steam_user(self, steam_id: str) -> tuple[SteamOrder, ...]:
        with self._pool.connection() as connection:
            rows = connection.execute(
                """select order_id,user_id,steam_id,status,transaction_id
                     from server_steam_orders where steam_id=%s
                     order by created_at""",
                (steam_id,),
            ).fetchall()
        return tuple(_steam_order(row) for row in rows)

    def reconcilable(self, *, limit: int) -> tuple[SteamOrder, ...]:
        with self._pool.connection() as connection:
            rows = connection.execute(
                """select order_id,user_id,steam_id,status,transaction_id
                     from server_steam_orders
                     where status not in ('created','failed','denied')
                     order by updated_at asc limit %s""",
                (limit,),
            ).fetchall()
        return tuple(_steam_order(row) for row in rows)

    def update(
        self, *, order_id: int, status: str, transaction_id: str | None = None
    ) -> SteamOrder:
        with self._pool.connection() as connection:
            row = connection.execute(
                """update server_steam_orders
                     set status=%s,
                         transaction_id=coalesce(%s,transaction_id),
                         updated_at=now()
                     where order_id=%s
                     returning order_id,user_id,steam_id,status,transaction_id""",
                (status, transaction_id, order_id),
            ).fetchone()
        if row is None:
            raise SteamCommerceError("unknown Steam order")
        return _steam_order(row)


class SteamGateway(Protocol):
    app_id: int

    def authenticate_ticket(self, ticket: str) -> str: ...

    def initialize_transaction(
        self, *, order_id: int, steam_id: str, language: str
    ) -> SteamTransaction: ...

    def finalize_transaction(self, order_id: int) -> SteamTransaction: ...

    def query_transaction(self, order_id: int) -> SteamTransaction: ...


class SteamWebGateway:
    """Small fail-closed adapter around Valve's publisher-only Web API."""

    def __init__(
        self,
        *,
        app_id: int,
        publisher_key: str,
        sandbox: bool = False,
        timeout_seconds: float = 8,
    ) -> None:
        if app_id <= 0 or not publisher_key:
            raise ValueError("Steam AppID and publisher key are required")
        self.app_id = app_id
        self._publisher_key = publisher_key
        self._microtxn_interface = (
            "ISteamMicroTxnSandbox" if sandbox else "ISteamMicroTxn"
        )
        self._timeout_seconds = timeout_seconds
        self._ssl_context = ssl.create_default_context(
            cafile=certifi.where() if certifi else None
        )

    @classmethod
    def from_environment(cls) -> SteamWebGateway | None:
        app_id = os.environ.get("KOLKHOZ_STEAM_APP_ID", "").strip()
        publisher_key = os.environ.get("KOLKHOZ_STEAM_PUBLISHER_KEY", "").strip()
        if not app_id and not publisher_key:
            return None
        if not app_id or not publisher_key:
            raise RuntimeError(
                "KOLKHOZ_STEAM_APP_ID and KOLKHOZ_STEAM_PUBLISHER_KEY "
                "must be configured together"
            )
        try:
            parsed_app_id = int(app_id)
        except ValueError as error:
            raise RuntimeError("KOLKHOZ_STEAM_APP_ID must be an integer") from error
        return cls(
            app_id=parsed_app_id,
            publisher_key=publisher_key,
            sandbox=_enabled("KOLKHOZ_STEAM_SANDBOX", False),
        )

    def authenticate_ticket(self, ticket: str) -> str:
        if not ticket or len(ticket) > 5120 or len(ticket) % 2:
            raise SteamCommerceError("invalid Steam authentication ticket")
        try:
            bytes.fromhex(ticket)
        except ValueError as error:
            raise SteamCommerceError("invalid Steam authentication ticket") from error
        params = self._call(
            "ISteamUserAuth",
            "AuthenticateUserTicket",
            "v1",
            {
                "appid": str(self.app_id),
                "ticket": ticket,
                "identity": STEAM_TICKET_IDENTITY,
            },
            post=False,
        )
        steam_id = str(params.get("steamid") or "")
        if not steam_id.isdigit():
            raise SteamCommerceError("Steam did not return a valid user")
        return steam_id

    def initialize_transaction(
        self, *, order_id: int, steam_id: str, language: str
    ) -> SteamTransaction:
        params = self._call(
            self._microtxn_interface,
            "InitTxn",
            "v3",
            {
                "orderid": str(order_id),
                "steamid": steam_id,
                "appid": str(self.app_id),
                "itemcount": "1",
                "language": language[:2].lower() or "en",
                "currency": "USD",
                "itemid[0]": str(STEAM_ITEM_ID),
                "qty[0]": "1",
                "amount[0]": "499",
                "description[0]": "Kolkhoz Full Game Unlock",
                "category[0]": "full_game",
                "usersession": "client",
            },
            post=True,
        )
        return _steam_transaction(order_id, params, "initialized")

    def finalize_transaction(self, order_id: int) -> SteamTransaction:
        params = self._call(
            self._microtxn_interface,
            "FinalizeTxn",
            "v2",
            {"orderid": str(order_id), "appid": str(self.app_id)},
            post=True,
        )
        return _steam_transaction(order_id, params, "succeeded")

    def query_transaction(self, order_id: int) -> SteamTransaction:
        params = self._call(
            self._microtxn_interface,
            "QueryTxn",
            "v3",
            {"orderid": str(order_id), "appid": str(self.app_id)},
            post=False,
        )
        return _steam_transaction(
            order_id, params, str(params.get("status") or "unknown").lower()
        )

    def _call(
        self,
        interface: str,
        method: str,
        version: str,
        values: Mapping[str, str],
        *,
        post: bool,
    ) -> Mapping[str, object]:
        form = parse.urlencode({"key": self._publisher_key, **values})
        url = f"https://partner.steam-api.com/{interface}/{method}/{version}/"
        api_request = request.Request(
            url if post else f"{url}?{form}",
            data=form.encode() if post else None,
            headers=(
                {"content-type": "application/x-www-form-urlencoded"} if post else {}
            ),
            method="POST" if post else "GET",
        )
        try:
            with request.urlopen(
                api_request,
                timeout=self._timeout_seconds,
                context=self._ssl_context,
            ) as response:
                decoded = json.loads(response.read())
            envelope = decoded["response"]
            if str(envelope.get("result") or "OK").upper() != "OK":
                raise SteamCommerceError(_steam_error(envelope))
            params = envelope.get("params") or envelope
            if str(params.get("result") or "OK").upper() != "OK":
                raise SteamCommerceError(_steam_error(envelope))
            return params
        except SteamCommerceError:
            raise
        except Exception as error:
            raise SteamCommerceError("Steam commerce service is unavailable") from error


class SteamPurchaseService:
    def __init__(
        self,
        commerce: CommerceService,
        orders: SteamOrderRepository,
        gateway: SteamGateway,
    ) -> None:
        self.commerce = commerce
        self.orders = orders
        self.gateway = gateway

    def start(
        self, *, user_id: str, ticket: str, language: str = "en"
    ) -> dict[str, object]:
        if self.commerce.status(user_id=user_id)["fullGame"]:
            return {**self.commerce.status(user_id=user_id), "alreadyOwned": True}
        steam_id = self.gateway.authenticate_ticket(ticket)
        if any(
            order.user_id != user_id for order in self.orders.for_steam_user(steam_id)
        ):
            raise SteamCommerceError(
                "this Steam account is linked to another Kolkhoz account"
            )
        order = self.orders.create(user_id=user_id, steam_id=steam_id)
        try:
            transaction = self.gateway.initialize_transaction(
                order_id=order.order_id,
                steam_id=steam_id,
                language=language,
            )
        except Exception:
            self.orders.update(order_id=order.order_id, status="failed")
            raise
        order = self.orders.update(
            order_id=order.order_id,
            status="initialized",
            transaction_id=transaction.transaction_id,
        )
        return {
            "orderID": str(order.order_id),
            "steamID": order.steam_id,
            "price": "$4.99",
            "currency": "USD",
        }

    def authorize(
        self, *, user_id: str, order_id: int, authorized: bool
    ) -> dict[str, object]:
        order = self._owned_order(user_id, order_id)
        if order.status == "succeeded":
            return self.commerce.status(user_id=user_id)
        if not authorized:
            self.orders.update(order_id=order_id, status="denied")
            return self.commerce.status(user_id=user_id)
        transaction = self.gateway.finalize_transaction(order_id)
        order = self.orders.update(
            order_id=order_id,
            status="succeeded",
            transaction_id=transaction.transaction_id,
        )
        return self.commerce.grant_verified(
            user_id=user_id, purchase=self._purchase(order, active=True)
        )

    def sync(self, *, user_id: str, ticket: str) -> dict[str, object]:
        steam_id = self.gateway.authenticate_ticket(ticket)
        for order in self.orders.for_steam_user(steam_id):
            if order.user_id != user_id:
                raise SteamCommerceError(
                    "this Steam account is linked to another Kolkhoz account"
                )
            transaction = self.gateway.query_transaction(order.order_id)
            order = self.orders.update(
                order_id=order.order_id,
                status=transaction.status,
                transaction_id=transaction.transaction_id,
            )
            if transaction.status == "approved":
                self.authorize(
                    user_id=user_id, order_id=order.order_id, authorized=True
                )
            elif transaction.status == "succeeded":
                self.commerce.grant_verified(
                    user_id=user_id, purchase=self._purchase(order, active=True)
                )
            elif transaction.status in REVERSED_STEAM_STATUSES:
                self.commerce.apply_verified_status(self._purchase(order, active=False))
        return self.commerce.status(user_id=user_id)

    def reconcile(self, *, limit: int = 100) -> int:
        reconciled = 0
        for order in self.orders.reconcilable(limit=limit):
            transaction = self.gateway.query_transaction(order.order_id)
            order = self.orders.update(
                order_id=order.order_id,
                status=transaction.status,
                transaction_id=transaction.transaction_id,
            )
            if transaction.status == "approved":
                self.authorize(
                    user_id=order.user_id,
                    order_id=order.order_id,
                    authorized=True,
                )
            elif transaction.status == "succeeded":
                self.commerce.grant_verified(
                    user_id=order.user_id, purchase=self._purchase(order, active=True)
                )
            elif transaction.status in REVERSED_STEAM_STATUSES:
                self.commerce.apply_verified_status(self._purchase(order, active=False))
            reconciled += 1
        return reconciled

    def _owned_order(self, user_id: str, order_id: int) -> SteamOrder:
        order = self.orders.get(order_id)
        if order is None:
            raise SteamCommerceError("unknown Steam order")
        if order.user_id != user_id:
            raise SteamCommerceError("Steam order belongs to another account")
        return order

    @staticmethod
    def _purchase(order: SteamOrder, *, active: bool) -> VerifiedPurchase:
        return VerifiedPurchase(
            provider=STEAM_PROVIDER,
            original_transaction_id=f"order:{order.order_id}",
            product_id=STEAM_PRODUCT_ID,
            account_reference=order.user_id,
            active=active,
            purchased_at_ms=int(time.time() * 1000),
        )


class SteamReconciliationService:
    def __init__(
        self,
        purchases: SteamPurchaseService,
        *,
        interval_seconds: float = 3600,
        batch_size: int = 100,
    ) -> None:
        self.purchases = purchases
        self.interval_seconds = interval_seconds
        self.batch_size = batch_size
        self._stop = threading.Event()
        self._thread = threading.Thread(
            target=self._run, name="steam-commerce-reconciler", daemon=True
        )
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.wait(self.interval_seconds):
            try:
                self.purchases.reconcile(limit=self.batch_size)
            except Exception:
                logging.exception("Steam commerce reconciliation failed")

    def close(self) -> None:
        self._stop.set()
        self._thread.join(timeout=5)


def _steam_order(row: object) -> SteamOrder:
    return SteamOrder(
        order_id=int(row[0]),  # type: ignore[index]
        user_id=str(row[1]),  # type: ignore[index]
        steam_id=str(row[2]),  # type: ignore[index]
        status=str(row[3]),  # type: ignore[index]
        transaction_id=None if row[4] is None else str(row[4]),  # type: ignore[index]
    )


def _steam_transaction(
    order_id: int, params: Mapping[str, object], fallback_status: str
) -> SteamTransaction:
    transaction_id = str(params.get("transid") or params.get("transactionid") or "")
    return SteamTransaction(
        order_id=order_id,
        transaction_id=transaction_id,
        status=str(params.get("status") or fallback_status).lower(),
    )


def _steam_error(envelope: Mapping[str, object]) -> str:
    error = envelope.get("error")
    if isinstance(error, Mapping):
        description = str(error.get("errordesc") or error.get("errorcode") or "")
        if description:
            return description
    return "Steam rejected the commerce request"


def _enabled(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}
