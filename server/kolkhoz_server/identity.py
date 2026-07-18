from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import ssl
import struct
import threading
import time
import uuid
from dataclasses import dataclass
from http import HTTPStatus
from typing import Callable, Mapping, Protocol
from urllib import parse, request

from .errors import ServerError
from .store import ConnectionPool

try:
    import certifi
except ImportError:
    certifi = None


SESSION_SECONDS = 90 * 24 * 60 * 60
LINK_SECONDS = 8 * 60
MAX_LINK_ATTEMPTS = 8


class CredentialError(ValueError):
    pass


class LinkError(ValueError):
    pass


@dataclass(frozen=True)
class VerifiedIdentity:
    provider: str
    subject: str
    credential_fingerprint: str
    credential_expires_at: float
    display_name: str | None = None


class PlatformVerifier(Protocol):
    def verify(self, payload: Mapping[str, object], now: float) -> VerifiedIdentity: ...


class AppleGameCenterVerifier:
    """Verify GameKit's signed identity tuple exactly as documented by Apple."""

    def __init__(self, *, bundle_id: str, max_age_seconds: int = 300) -> None:
        self.bundle_id = bundle_id
        self.max_age_seconds = max_age_seconds
        self.ssl_context = ssl.create_default_context(
            cafile=certifi.where() if certifi else None
        )

    def verify(self, payload: Mapping[str, object], now: float) -> VerifiedIdentity:
        try:
            subject = str(payload["teamPlayerID"])
            public_key_url = str(payload["publicKeyURL"])
            signature = base64.b64decode(str(payload["signature"]), validate=True)
            salt = base64.b64decode(str(payload["salt"]), validate=True)
            timestamp = int(payload["timestamp"])
        except (KeyError, TypeError, ValueError) as error:
            raise CredentialError("invalid Game Center credential") from error
        timestamp_seconds = timestamp / 1000
        if not subject or abs(now - timestamp_seconds) > self.max_age_seconds:
            raise CredentialError("expired Game Center credential")
        parsed = parse.urlsplit(public_key_url)
        if parsed.scheme != "https" or parsed.hostname not in {
            "static.gc.apple.com",
            "static.gc.apple.com.cn",
        }:
            raise CredentialError("untrusted Game Center public key URL")
        try:
            from cryptography import x509
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.asymmetric import padding

            with request.urlopen(
                public_key_url, timeout=5, context=self.ssl_context
            ) as response:
                certificate = x509.load_der_x509_certificate(response.read())
            signed = (
                subject.encode()
                + self.bundle_id.encode()
                + struct.pack(">Q", timestamp)
                + salt
            )
            certificate.public_key().verify(
                signature, signed, padding.PKCS1v15(), hashes.SHA256()
            )
        except Exception as error:
            raise CredentialError("invalid Game Center signature") from error
        fingerprint = hashlib.sha256(signature + salt + str(timestamp).encode()).hexdigest()
        return VerifiedIdentity(
            "game_center", subject, fingerprint, timestamp_seconds + self.max_age_seconds
        )


class GooglePlayGamesVerifier:
    """Exchange a PGS v2 one-time server auth code, then read players/me."""

    def __init__(self, *, client_id: str, client_secret: str) -> None:
        self.client_id = client_id
        self.client_secret = client_secret
        self.ssl_context = ssl.create_default_context(
            cafile=certifi.where() if certifi else None
        )

    def verify(self, payload: Mapping[str, object], now: float) -> VerifiedIdentity:
        code = str(payload.get("serverAuthCode") or "")
        if not code:
            raise CredentialError("missing Play Games server authorization code")
        fingerprint = hashlib.sha256(code.encode()).hexdigest()
        form = parse.urlencode(
            {
                "code": code,
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "grant_type": "authorization_code",
            }
        ).encode()
        try:
            token_request = request.Request(
                "https://oauth2.googleapis.com/token",
                data=form,
                headers={"content-type": "application/x-www-form-urlencoded"},
            )
            with request.urlopen(
                token_request, timeout=5, context=self.ssl_context
            ) as response:
                token = json.loads(response.read())
            access_token = str(token["access_token"])
            player_request = request.Request(
                "https://games.googleapis.com/games/v1/players/me",
                headers={"authorization": f"Bearer {access_token}"},
            )
            with request.urlopen(
                player_request, timeout=5, context=self.ssl_context
            ) as response:
                player = json.loads(response.read())
            subject = str(player["playerId"])
        except Exception as error:
            raise CredentialError("invalid Play Games credential") from error
        if not subject:
            raise CredentialError("Play Games player ID was unavailable")
        return VerifiedIdentity(
            "play_games",
            subject,
            fingerprint,
            now + 300,
            str(player.get("displayName") or "") or None,
        )


class IdentityRepository(Protocol):
    def authenticate(self, identity: VerifiedIdentity, display_name: str, device_id: str, now: float) -> dict[str, object]: ...
    def claim(self, player_id: str, identity: VerifiedIdentity, device_id: str, now: float) -> dict[str, object]: ...
    def guest(self, guest_hash: str, display_name: str, device_id: str, now: float) -> dict[str, object]: ...
    def player_for_token(self, token_hash: str, now: float) -> str | None: ...
    def create_link(self, player_id: str, code_hash: str, expires_at: float, now: float) -> str: ...
    def link_status(self, player_id: str, request_id: str, now: float) -> dict[str, object]: ...
    def cancel_link(self, player_id: str, request_id: str, now: float) -> dict[str, object]: ...
    def redeem_link(self, target_player_id: str, code_hash: str, now: float) -> dict[str, object]: ...
    def approve_link(self, source_player_id: str, request_id: str, now: float) -> dict[str, object]: ...
    def delete_player(self, player_id: str, now: float) -> None: ...


class IdentityService:
    def __init__(
        self,
        repository: IdentityRepository,
        verifiers: Mapping[str, PlatformVerifier],
        *,
        secret: bytes,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.repository = repository
        self.verifiers = dict(verifiers)
        self.secret = secret
        self.clock = clock

    def authenticate(self, provider: str, payload: Mapping[str, object], *, display_name: str, device_id: str, claim_player_id: str | None = None) -> dict[str, object]:
        verifier = self.verifiers.get(provider)
        if verifier is None:
            raise CredentialError("unsupported identity provider")
        now = self.clock()
        verified = verifier.verify(payload, now)
        if claim_player_id is not None:
            return self.repository.claim(claim_player_id, verified, device_id, now)
        return self.repository.authenticate(verified, _name(display_name, verified.display_name), device_id, now)

    def guest(self, installation_id: str, *, display_name: str, device_id: str) -> dict[str, object]:
        if len(installation_id) < 16:
            raise CredentialError("invalid guest installation identity")
        return self.repository.guest(self._hash(f"guest:{installation_id}"), _name(display_name), device_id, self.clock())

    def create_link(self, player_id: str) -> dict[str, object]:
        now = self.clock()
        raw = "-".join(secrets.token_hex(3).upper()[index:index + 3] for index in (0, 3))
        request_id = self.repository.create_link(player_id, self._hash(f"link:{raw}"), now + LINK_SECONDS, now)
        return {"requestID": request_id, "code": raw, "qrPayload": f"kolkhoz://link?code={raw}", "expiresAt": now + LINK_SECONDS, "status": "pending"}

    def redeem(self, player_id: str, code: str) -> dict[str, object]:
        return self.repository.redeem_link(player_id, self._hash(f"link:{_code(code)}"), self.clock())

    def _hash(self, value: str) -> str:
        return hmac.new(self.secret, value.encode(), hashlib.sha256).hexdigest()


class IdentitySessionVerifier:
    def __init__(
        self,
        repository: IdentityRepository,
        *,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.repository = repository
        self.clock = clock

    def user_id(self, authorization: str | None) -> str | None:
        if not authorization or not authorization.startswith("Bearer khz_"):
            return None
        token = authorization.removeprefix("Bearer ").strip()
        return self.repository.player_for_token(
            hashlib.sha256(token.encode()).hexdigest(), self.clock()
        )


class CompositeAuthVerifier:
    def __init__(self, *verifiers: object) -> None:
        self.verifiers = verifiers

    def user_id(self, authorization: str | None) -> str | None:
        if authorization is None:
            return None
        for verifier in self.verifiers:
            if authorization.startswith("Bearer khz_") != isinstance(verifier, IdentitySessionVerifier):
                continue
            value = verifier.user_id(authorization)  # type: ignore[attr-defined]
            if value is not None:
                return value
        raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")

    def invalidate_user(self, user_id: str) -> None:
        for verifier in self.verifiers:
            invalidate = getattr(verifier, "invalidate_user", None)
            if invalidate is not None:
                invalidate(user_id)


class PostgresIdentityRepository:
    def __init__(self, pool: ConnectionPool) -> None:
        self.pool = pool

    def authenticate(self, identity: VerifiedIdentity, display_name: str, device_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            cursor = connection.execute(  # type: ignore[attr-defined]
                "select player_id::text from server_linked_identities where provider=%s and provider_subject=%s for update",
                (identity.provider, identity.subject),
            )
            row = cursor.fetchone()
            if row:
                player_id = str(row[0])
                connection.execute("update server_linked_identities set last_authenticated_at=to_timestamp(%s) where provider=%s and provider_subject=%s", (now, identity.provider, identity.subject))  # type: ignore[attr-defined]
            else:
                player_id = str(uuid.uuid4())
                connection.execute("insert into server_players(id,display_name) values(%s,%s)", (player_id, display_name))  # type: ignore[attr-defined]
                connection.execute("insert into public.profiles(user_id,display_name) values(%s,%s)", (player_id, display_name))  # type: ignore[attr-defined]
                connection.execute("insert into server_linked_identities(id,player_id,provider,provider_subject) values(%s,%s,%s,%s)", (str(uuid.uuid4()), player_id, identity.provider, identity.subject))  # type: ignore[attr-defined]
            replay = connection.execute("insert into server_platform_credential_replays(credential_hash,provider,expires_at) values(%s,%s,to_timestamp(%s)) on conflict do nothing returning credential_hash", (identity.credential_fingerprint, identity.provider, identity.credential_expires_at)).fetchone()  # type: ignore[attr-defined]
            if replay is None:
                raise CredentialError("platform credential has already been used")
            return self._session(connection, player_id, device_id, now, identity.provider)

    def claim(self, player_id: str, identity: VerifiedIdentity, device_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            player = connection.execute(  # type: ignore[attr-defined]
                "select id from server_players where id=%s and status='active' for update",
                (player_id,),
            ).fetchone()
            if player is None:
                raise LinkError("the existing player profile was not found")
            linked = connection.execute(  # type: ignore[attr-defined]
                "select id::text,player_id::text from server_linked_identities where provider=%s and provider_subject=%s for update",
                (identity.provider, identity.subject),
            ).fetchone()
            if linked is not None and str(linked[1]) != player_id:
                raise LinkError("this platform identity is already linked to another player")
            other = connection.execute(  # type: ignore[attr-defined]
                "select provider_subject from server_linked_identities where player_id=%s and provider=%s for update",
                (player_id, identity.provider),
            ).fetchone()
            if other is not None and str(other[0]) != identity.subject:
                raise LinkError("this player already has a different platform identity")
            replay = connection.execute(  # type: ignore[attr-defined]
                "insert into server_platform_credential_replays(credential_hash,provider,expires_at) values(%s,%s,to_timestamp(%s)) on conflict do nothing returning credential_hash",
                (identity.credential_fingerprint, identity.provider, identity.credential_expires_at),
            ).fetchone()
            if replay is None:
                raise CredentialError("platform credential has already been used")
            if linked is None:
                connection.execute(  # type: ignore[attr-defined]
                    "insert into server_linked_identities(id,player_id,provider,provider_subject,last_authenticated_at) values(%s,%s,%s,%s,to_timestamp(%s))",
                    (str(uuid.uuid4()), player_id, identity.provider, identity.subject, now),
                )
                connection.execute(  # type: ignore[attr-defined]
                    "insert into server_identity_audit(player_id,event_type,provider,metadata) values(%s,'legacy_identity_claimed',%s,%s::jsonb)",
                    (player_id, identity.provider, json.dumps({"providerSubjectHash": hashlib.sha256(identity.subject.encode()).hexdigest()})),
                )
            else:
                connection.execute(  # type: ignore[attr-defined]
                    "update server_linked_identities set last_authenticated_at=to_timestamp(%s) where id=%s",
                    (now, linked[0]),
                )
            connection.execute(  # type: ignore[attr-defined]
                "update server_players set guest_installation_hash=null,updated_at=to_timestamp(%s) where id=%s",
                (now, player_id),
            )
            return self._session(connection, player_id, device_id, now, identity.provider)

    def guest(self, guest_hash: str, display_name: str, device_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute("select id::text from server_players where guest_installation_hash=%s for update", (guest_hash,)).fetchone()  # type: ignore[attr-defined]
            player_id = str(row[0]) if row else str(uuid.uuid4())
            if not row:
                connection.execute("insert into server_players(id,display_name,guest_installation_hash) values(%s,%s,%s)", (player_id, display_name, guest_hash))  # type: ignore[attr-defined]
                connection.execute("insert into public.profiles(user_id,display_name) values(%s,%s)", (player_id, display_name))  # type: ignore[attr-defined]
            return self._session(connection, player_id, device_id, now, None)

    def _session(self, connection: object, player_id: str, device_id: str, now: float, provider: str | None) -> dict[str, object]:
        token = "khz_" + secrets.token_urlsafe(32)
        connection.execute("insert into server_identity_sessions(id,player_id,token_hash,device_id,expires_at) values(%s,%s,%s,%s,to_timestamp(%s))", (str(uuid.uuid4()), player_id, hashlib.sha256(token.encode()).hexdigest(), device_id, now + SESSION_SECONDS))  # type: ignore[attr-defined]
        row = connection.execute("select display_name, guest_installation_hash is not null from server_players where id=%s", (player_id,)).fetchone()  # type: ignore[attr-defined]
        return {"accessToken": token, "expiresAt": now + SESSION_SECONDS, "player": {"id": player_id, "displayName": row[0], "guest": bool(row[1]), "provider": provider}}

    def player_for_token(self, token_hash: str, now: float) -> str | None:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute("update server_identity_sessions set last_used_at=to_timestamp(%s) where token_hash=%s and revoked_at is null and expires_at>to_timestamp(%s) returning player_id::text", (now, token_hash, now)).fetchone()  # type: ignore[attr-defined]
            return str(row[0]) if row else None

    def create_link(self, player_id: str, code_hash: str, expires_at: float, now: float) -> str:
        if not self._attempt(player_id, "link_create", now, limit=6):
            raise LinkError("too many device-link requests; try again later")
        request_id = str(uuid.uuid4())
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute("update server_device_link_requests set status='cancelled',cancelled_at=to_timestamp(%s),updated_at=to_timestamp(%s) where source_player_id=%s and status in ('pending','target_confirmed')", (now, now, player_id))  # type: ignore[attr-defined]
            connection.execute("insert into server_device_link_requests(id,source_player_id,code_hash,expires_at) values(%s,%s,%s,to_timestamp(%s))", (request_id, player_id, code_hash, expires_at))  # type: ignore[attr-defined]
        return request_id

    def link_status(self, player_id: str, request_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute("update server_device_link_requests set status='expired',updated_at=to_timestamp(%s) where id=%s and status in ('pending','target_confirmed') and expires_at<=to_timestamp(%s)", (now, request_id, now))  # type: ignore[attr-defined]
            row = connection.execute("select status,extract(epoch from expires_at),target_player_id::text,conflict_reason,source_player_id::text,target_session_issued_at is not null from server_device_link_requests where id=%s and (source_player_id=%s or target_player_id=%s) for update", (request_id, player_id, player_id)).fetchone()  # type: ignore[attr-defined]
            if row and row[0] == "approved" and row[2] == player_id and not row[5]:
                result = self._session(connection, str(row[4]), "linked-device", now, None)
                connection.execute("update server_identity_sessions set revoked_at=to_timestamp(%s) where player_id=%s and revoked_at is null", (now, player_id))  # type: ignore[attr-defined]
                connection.execute("update server_device_link_requests set target_session_issued_at=to_timestamp(%s),updated_at=to_timestamp(%s) where id=%s", (now, now, request_id))  # type: ignore[attr-defined]
                result.update({"requestID": request_id, "status": "approved"})
                return result
        if not row: raise LinkError("link request not found")
        return {"requestID": request_id, "status": row[0], "expiresAt": float(row[1]), "targetPlayerID": row[2], "message": row[3]}

    def cancel_link(self, player_id: str, request_id: str, now: float) -> dict[str, object]:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute("update server_device_link_requests set status='cancelled',cancelled_at=to_timestamp(%s),updated_at=to_timestamp(%s) where id=%s and source_player_id=%s and status in ('pending','target_confirmed') returning id", (now, now, request_id, player_id)).fetchone()  # type: ignore[attr-defined]
        if not row: raise LinkError("link request cannot be cancelled")
        return {"requestID": request_id, "status": "cancelled"}

    def redeem_link(self, target_player_id: str, code_hash: str, now: float) -> dict[str, object]:
        if not self._attempt(target_player_id, "link_redeem", now, limit=MAX_LINK_ATTEMPTS):
            raise LinkError("too many device-link attempts; try again later")
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute("select id::text,source_player_id::text,status,expires_at>to_timestamp(%s) from server_device_link_requests where code_hash=%s for update", (now, code_hash)).fetchone()  # type: ignore[attr-defined]
            if not row: raise LinkError("invalid device-link code")
            if row[2] != "pending" or not row[3]: raise LinkError("device-link code is no longer valid")
            identity = connection.execute("select id::text,provider from server_linked_identities where player_id=%s order by last_authenticated_at desc limit 1", (target_player_id,)).fetchone()  # type: ignore[attr-defined]
            if not identity: raise LinkError("authenticate Game Center or Play Games before linking")
            source = connection.execute("select display_name from server_players where id=%s", (row[1],)).fetchone()  # type: ignore[attr-defined]
            target = connection.execute("select display_name from server_players where id=%s", (target_player_id,)).fetchone()  # type: ignore[attr-defined]
            connection.execute("update server_device_link_requests set status='target_confirmed',target_player_id=%s,target_identity_id=%s,target_confirmed_at=to_timestamp(%s),updated_at=to_timestamp(%s) where id=%s", (target_player_id, identity[0], now, now, row[0]))  # type: ignore[attr-defined]
            connection.execute("delete from server_identity_rate_limits where player_id=%s and action='link_redeem'", (target_player_id,))  # type: ignore[attr-defined]
            return {"requestID": row[0], "status": "target_confirmed", "source": {"id": row[1], "displayName": source[0]}, "target": {"id": target_player_id, "displayName": target[0], "provider": identity[1]}}

    def approve_link(self, source_player_id: str, request_id: str, now: float) -> dict[str, object]:
        conflict = False
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute("select target_player_id::text,target_identity_id::text,status,expires_at>to_timestamp(%s) from server_device_link_requests where id=%s and source_player_id=%s for update", (now, request_id, source_player_id)).fetchone()  # type: ignore[attr-defined]
            if not row or row[2] != "target_confirmed" or not row[3]: raise LinkError("link request is not ready for approval")
            meaningful = connection.execute(
                """select
                       exists(select 1 from server_game_results where user_id=%s)
                    or exists(select 1 from server_entitlements where user_id=%s)
                    or exists(select 1 from server_store_purchases where user_id=%s)
                    or exists(
                        select 1 from public.profile_progression
                         where user_id=%s
                           and (
                               progress <> '{}'::jsonb
                               or cardinality(completed) > 0
                               or cardinality(unlocks) > 0
                           )
                    )""",
                (row[0], row[0], row[0], row[0]),
            ).fetchone()[0]  # type: ignore[attr-defined]
            if meaningful:
                connection.execute("update server_device_link_requests set status='conflict',conflict_reason='The target profile has progress or purchases and cannot be merged automatically.',updated_at=to_timestamp(%s) where id=%s", (now, request_id))  # type: ignore[attr-defined]
                connection.execute("insert into server_identity_audit(player_id,event_type,other_player_id,metadata) values(%s,'link_conflict',%s,%s::jsonb)", (source_player_id, row[0], json.dumps({"requestID": request_id})))  # type: ignore[attr-defined]
                conflict = True
            else:
                connection.execute("update server_linked_identities set player_id=%s,last_authenticated_at=to_timestamp(%s) where id=%s", (source_player_id, now, row[1]))  # type: ignore[attr-defined]
                connection.execute("update server_device_link_requests set status='approved',approved_at=to_timestamp(%s),redeemed_at=to_timestamp(%s),updated_at=to_timestamp(%s) where id=%s", (now, now, now, request_id))  # type: ignore[attr-defined]
                connection.execute("update server_device_link_requests set status='cancelled',cancelled_at=to_timestamp(%s),updated_at=to_timestamp(%s) where source_player_id=%s and id<>%s and status in ('pending','target_confirmed')", (now, now, source_player_id, request_id))  # type: ignore[attr-defined]
        if conflict:
            raise LinkError("profiles with progress or purchases cannot be combined")
        return {"requestID": request_id, "status": "approved"}

    def delete_player(self, player_id: str, now: float) -> None:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            connection.execute("update server_seats seats set user_id='deleted:' || seats.session_id::text || ':' || seats.player_id::text,token_hash=repeat('0',64),abandoned=true,autopilot=true,last_seen_at=null from server_sessions sessions where seats.session_id=sessions.session_id and seats.user_id=%s and sessions.status='active'", (player_id,))  # type: ignore[attr-defined]
            connection.execute("update server_seats seats set occupied=false,user_id=null,token_hash=null,last_seen_at=null,abandoned=false,autopilot=false from server_sessions sessions where seats.session_id=sessions.session_id and seats.user_id=%s and sessions.status<>'active'", (player_id,))  # type: ignore[attr-defined]
            connection.execute("update server_sessions set created_by_user_id=null where created_by_user_id=%s", (player_id,))  # type: ignore[attr-defined]
            connection.execute("delete from server_players where id=%s", (player_id,))  # type: ignore[attr-defined]

    def _attempt(self, player_id: str, action: str, now: float, *, limit: int) -> bool:
        with self.pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            row = connection.execute(
                """insert into server_identity_rate_limits(player_id,action,window_started_at,attempts)
                   values(%s,%s,to_timestamp(%s),1)
                   on conflict(player_id,action) do update set
                     window_started_at=case when server_identity_rate_limits.window_started_at < to_timestamp(%s) - interval '10 minutes' then to_timestamp(%s) else server_identity_rate_limits.window_started_at end,
                     attempts=case when server_identity_rate_limits.window_started_at < to_timestamp(%s) - interval '10 minutes' then 1 else server_identity_rate_limits.attempts + 1 end
                   returning attempts""",
                (player_id, action, now, now, now, now),
            ).fetchone()  # type: ignore[attr-defined]
        return int(row[0]) <= limit


class InMemoryIdentityRepository:
    """Deterministic contract implementation used by service and concurrency tests."""

    def __init__(self) -> None:
        self.players: dict[str, dict[str, object]] = {}
        self.identities: dict[tuple[str, str], dict[str, object]] = {}
        self.sessions: dict[str, dict[str, object]] = {}
        self.replays: set[str] = set()
        self.links: dict[str, dict[str, object]] = {}
        self.meaningful_players: set[str] = set()
        self.attempts: dict[tuple[str, str], tuple[float, int]] = {}
        self.lock = threading.Lock()

    def authenticate(self, identity: VerifiedIdentity, display_name: str, device_id: str, now: float) -> dict[str, object]:
        with self.lock:
            if identity.credential_fingerprint in self.replays:
                raise CredentialError("platform credential has already been used")
            self.replays.add(identity.credential_fingerprint)
            key = (identity.provider, identity.subject)
            linked = self.identities.get(key)
            if linked is None:
                player_id = str(uuid.uuid4())
                self.players[player_id] = {"displayName": display_name, "guestHash": None, "deleted": False}
                linked = {"id": str(uuid.uuid4()), "playerID": player_id, "provider": identity.provider}
                self.identities[key] = linked
            return self._session(str(linked["playerID"]), device_id, now, identity.provider)

    def claim(self, player_id: str, identity: VerifiedIdentity, device_id: str, now: float) -> dict[str, object]:
        with self.lock:
            player = self.players.get(player_id)
            if player is None or player["deleted"]:
                raise LinkError("the existing player profile was not found")
            key = (identity.provider, identity.subject)
            linked = self.identities.get(key)
            if linked is not None and linked["playerID"] != player_id:
                raise LinkError("this platform identity is already linked to another player")
            other = next(
                (
                    value
                    for (provider, subject), value in self.identities.items()
                    if value["playerID"] == player_id
                    and provider == identity.provider
                    and subject != identity.subject
                ),
                None,
            )
            if other is not None:
                raise LinkError("this player already has a different platform identity")
            if identity.credential_fingerprint in self.replays:
                raise CredentialError("platform credential has already been used")
            self.replays.add(identity.credential_fingerprint)
            if linked is None:
                self.identities[key] = {
                    "id": str(uuid.uuid4()),
                    "playerID": player_id,
                    "provider": identity.provider,
                }
            player["guestHash"] = None
            return self._session(player_id, device_id, now, identity.provider)

    def guest(self, guest_hash: str, display_name: str, device_id: str, now: float) -> dict[str, object]:
        with self.lock:
            player_id = next((key for key, value in self.players.items() if value["guestHash"] == guest_hash), None)
            if player_id is None:
                player_id = str(uuid.uuid4())
                self.players[player_id] = {"displayName": display_name, "guestHash": guest_hash, "deleted": False}
            return self._session(player_id, device_id, now, None)

    def _session(self, player_id: str, device_id: str, now: float, provider: str | None) -> dict[str, object]:
        token = "khz_" + secrets.token_urlsafe(24)
        self.sessions[hashlib.sha256(token.encode()).hexdigest()] = {"playerID": player_id, "expiresAt": now + SESSION_SECONDS, "revoked": False}
        player = self.players[player_id]
        return {"accessToken": token, "expiresAt": now + SESSION_SECONDS, "player": {"id": player_id, "displayName": player["displayName"], "guest": player["guestHash"] is not None, "provider": provider}}

    def player_for_token(self, token_hash: str, now: float) -> str | None:
        with self.lock:
            session = self.sessions.get(token_hash)
            if session is None or session["revoked"] or float(session["expiresAt"]) <= now:
                return None
            return str(session["playerID"])

    def create_link(self, player_id: str, code_hash: str, expires_at: float, now: float) -> str:
        with self.lock:
            if not self._attempt(player_id, "link_create", now, 6):
                raise LinkError("too many device-link requests; try again later")
            for link in self.links.values():
                if link["sourcePlayerID"] == player_id and link["status"] in {"pending", "target_confirmed"}:
                    link["status"] = "cancelled"
            request_id = str(uuid.uuid4())
            self.links[request_id] = {"requestID": request_id, "sourcePlayerID": player_id, "codeHash": code_hash, "expiresAt": expires_at, "status": "pending", "targetPlayerID": None, "targetIdentity": None, "message": None}
            return request_id

    def link_status(self, player_id: str, request_id: str, now: float) -> dict[str, object]:
        with self.lock:
            link = self.links.get(request_id)
            if link is None or player_id not in {link["sourcePlayerID"], link["targetPlayerID"]}:
                raise LinkError("link request not found")
            self._expire(link, now)
            if link["status"] == "approved" and link["targetPlayerID"] == player_id and not link.get("targetSessionIssued"):
                result = self._session(str(link["sourcePlayerID"]), "linked-device", now, None)
                for session in self.sessions.values():
                    if session["playerID"] == player_id:
                        session["revoked"] = True
                link["targetSessionIssued"] = True
                result.update({"requestID": request_id, "status": "approved"})
                return result
            return {key: link.get(key) for key in ("requestID", "status", "expiresAt", "targetPlayerID", "message")}

    def cancel_link(self, player_id: str, request_id: str, now: float) -> dict[str, object]:
        with self.lock:
            link = self._link(request_id, player_id)
            if link["status"] not in {"pending", "target_confirmed"}:
                raise LinkError("link request cannot be cancelled")
            link["status"] = "cancelled"
            return {"requestID": request_id, "status": "cancelled"}

    def redeem_link(self, target_player_id: str, code_hash: str, now: float) -> dict[str, object]:
        with self.lock:
            if not self._attempt(target_player_id, "link_redeem", now, MAX_LINK_ATTEMPTS):
                raise LinkError("too many device-link attempts; try again later")
            link = next((value for value in self.links.values() if hmac.compare_digest(str(value["codeHash"]), code_hash)), None)
            if link is None:
                raise LinkError("invalid device-link code")
            self._expire(link, now)
            if link["status"] != "pending":
                raise LinkError("device-link code is no longer valid")
            identity = next((value for value in self.identities.values() if value["playerID"] == target_player_id), None)
            if identity is None:
                raise LinkError("authenticate Game Center or Play Games before linking")
            link.update({"status": "target_confirmed", "targetPlayerID": target_player_id, "targetIdentity": identity["id"]})
            self.attempts.pop((target_player_id, "link_redeem"), None)
            source = self.players[str(link["sourcePlayerID"])]
            target = self.players[target_player_id]
            return {"requestID": link["requestID"], "status": "target_confirmed", "source": {"id": link["sourcePlayerID"], "displayName": source["displayName"]}, "target": {"id": target_player_id, "displayName": target["displayName"], "provider": identity["provider"]}}

    def approve_link(self, source_player_id: str, request_id: str, now: float) -> dict[str, object]:
        with self.lock:
            link = self._link(request_id, source_player_id)
            self._expire(link, now)
            if link["status"] != "target_confirmed":
                raise LinkError("link request is not ready for approval")
            target = str(link["targetPlayerID"])
            if target in self.meaningful_players:
                link.update({"status": "conflict", "message": "The target profile has progress or purchases and cannot be merged automatically."})
                raise LinkError("profiles with progress or purchases cannot be combined")
            for identity in self.identities.values():
                if identity["id"] == link["targetIdentity"]:
                    identity["playerID"] = source_player_id
            link["status"] = "approved"
            return {"requestID": request_id, "status": "approved"}

    def delete_player(self, player_id: str, now: float) -> None:
        with self.lock:
            self.players[player_id].update({"deleted": True, "displayName": "Deleted Player", "guestHash": None})
            self.identities = {key: value for key, value in self.identities.items() if value["playerID"] != player_id}
            for session in self.sessions.values():
                if session["playerID"] == player_id:
                    session["revoked"] = True

    def _link(self, request_id: str, source_player_id: str) -> dict[str, object]:
        link = self.links.get(request_id)
        if link is None or link["sourcePlayerID"] != source_player_id:
            raise LinkError("link request not found")
        return link

    def _attempt(self, player_id: str, action: str, now: float, limit: int) -> bool:
        started, count = self.attempts.get((player_id, action), (now, 0))
        if now - started >= 600:
            started, count = now, 0
        count += 1
        self.attempts[(player_id, action)] = (started, count)
        return count <= limit

    @staticmethod
    def _expire(link: dict[str, object], now: float) -> None:
        if link["status"] in {"pending", "target_confirmed"} and float(link["expiresAt"]) <= now:
            link["status"] = "expired"


def _name(preferred: str, fallback: str | None = None) -> str:
    value = (preferred or fallback or "Comrade").strip()
    return value[:48] or "Comrade"


def _code(value: str) -> str:
    normalized = value.strip().upper().replace(" ", "").replace("-", "")
    if len(normalized) != 6 or any(character not in "0123456789ABCDEF" for character in normalized):
        raise LinkError("invalid device-link code")
    return normalized[:3] + "-" + normalized[3:]


def identity_service_from_environment(pool: ConnectionPool) -> IdentityService:
    secret = os.environ.get("KOLKHOZ_IDENTITY_SECRET")
    if not secret or len(secret) < 32:
        raise RuntimeError("KOLKHOZ_IDENTITY_SECRET must contain at least 32 characters")
    verifiers: dict[str, PlatformVerifier] = {}
    bundle_id = os.environ.get("KOLKHOZ_APPLE_BUNDLE_ID")
    if bundle_id:
        verifiers["game_center"] = AppleGameCenterVerifier(bundle_id=bundle_id)
    google_id = os.environ.get("KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_ID")
    google_secret = os.environ.get("KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_SECRET")
    if google_id and google_secret:
        verifiers["play_games"] = GooglePlayGamesVerifier(client_id=google_id, client_secret=google_secret)
    return IdentityService(PostgresIdentityRepository(pool), verifiers, secret=secret.encode())
