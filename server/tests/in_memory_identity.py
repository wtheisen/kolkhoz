from __future__ import annotations

import hashlib
import hmac
import secrets
import threading
import uuid

from server.kolkhoz_server.identity import (
    MAX_LINK_ATTEMPTS,
    SESSION_SECONDS,
    CredentialError,
    LinkError,
    VerifiedIdentity,
    _guest_name,
)


class InMemoryIdentityRepository:
    """Deterministic contract implementation used by service and concurrency tests."""

    def __init__(self) -> None:
        self.players: dict[str, dict[str, object]] = {}
        self.identities: dict[tuple[str, str], dict[str, object]] = {}
        self.sessions: dict[str, dict[str, object]] = {}
        self.replays: set[str] = set()
        self.links: dict[str, dict[str, object]] = {}
        self.recovery_emails: dict[str, str] = {}
        self.email_codes: dict[tuple[str, str], dict[str, object]] = {}
        self.legacy_devices: dict[str, str] = {}
        self.meaningful_players: set[str] = set()
        self.attempts: dict[tuple[str, str], tuple[float, int]] = {}
        self.abuse_attempts: dict[tuple[str, str], tuple[float, int]] = {}
        self.lock = threading.Lock()

    def authenticate(
        self, identity: VerifiedIdentity, display_name: str, device_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            if identity.credential_fingerprint in self.replays:
                raise CredentialError("platform credential has already been used")
            self.replays.add(identity.credential_fingerprint)
            key = (identity.provider, identity.subject)
            linked = self.identities.get(key)
            if linked is None:
                player_id = str(uuid.uuid4())
                self.players[player_id] = {
                    "displayName": display_name,
                    "guestHash": None,
                    "deleted": False,
                }
                linked = {
                    "id": str(uuid.uuid4()),
                    "playerID": player_id,
                    "provider": identity.provider,
                }
                self.identities[key] = linked
            return self._session(
                str(linked["playerID"]), device_id, now, identity.provider
            )

    def claim(
        self, player_id: str, identity: VerifiedIdentity, device_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            player = self.players.get(player_id)
            if player is None or player["deleted"]:
                raise LinkError("the existing player profile was not found")
            key = (identity.provider, identity.subject)
            linked = self.identities.get(key)
            if linked is not None and linked["playerID"] != player_id:
                raise LinkError(
                    "this platform identity is already linked to another player"
                )
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

    def guest(
        self, guest_hash: str, display_name: str, device_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            player_id = self.legacy_devices.get(guest_hash)
            if player_id is None:
                player_id = next(
                    (
                        key
                        for key, value in self.players.items()
                        if value["guestHash"] == guest_hash
                    ),
                    None,
                )
            if player_id is None:
                player_id = str(uuid.uuid4())
                self.players[player_id] = {
                    "displayName": _guest_name(player_id),
                    "guestHash": guest_hash,
                    "deleted": False,
                }
            return self._session(player_id, device_id, now, None)

    def migrate_legacy(
        self, player_id: str, guest_hash: str, device_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            player = self.players.get(player_id)
            if player is None or player["deleted"]:
                raise LinkError("the existing player profile was not found")
            current = self.legacy_devices.get(guest_hash)
            guest_owner = next(
                (
                    key
                    for key, value in self.players.items()
                    if value["guestHash"] == guest_hash and not value["deleted"]
                ),
                None,
            )
            current = current or guest_owner
            if current is not None and current != player_id:
                raise LinkError(
                    "this device already has a different Kolkhoz profile; link it from Profile"
                )
            self.legacy_devices[guest_hash] = player_id
            return self._session(player_id, device_id, now, None)

    def _session(
        self, player_id: str, device_id: str, now: float, provider: str | None
    ) -> dict[str, object]:
        token = "khz_" + secrets.token_urlsafe(24)
        self.sessions[hashlib.sha256(token.encode()).hexdigest()] = {
            "playerID": player_id,
            "expiresAt": now + SESSION_SECONDS,
            "revoked": False,
        }
        player = self.players[player_id]
        portable = (
            player["guestHash"] is None or player_id in self.recovery_emails.values()
        )
        email = next(
            (key for key, value in self.recovery_emails.items() if value == player_id),
            None,
        )
        return {
            "accessToken": token,
            "expiresAt": now + SESSION_SECONDS,
            "player": {
                "id": player_id,
                "displayName": player["displayName"],
                "guest": not portable,
                "portable": portable,
                "recoveryEmail": email,
                "provider": provider,
            },
        }

    def player_for_token(self, token_hash: str, now: float) -> str | None:
        with self.lock:
            session = self.sessions.get(token_hash)
            if (
                session is None
                or session["revoked"]
                or float(session["expiresAt"]) <= now
            ):
                return None
            return str(session["playerID"])

    def create_link(
        self, player_id: str, code_hash: str, expires_at: float, now: float
    ) -> str:
        with self.lock:
            if not self._attempt(player_id, "link_create", now, 6):
                raise LinkError("too many device-link requests; try again later")
            for link in self.links.values():
                if link["sourcePlayerID"] == player_id and link["status"] in {
                    "pending",
                    "target_confirmed",
                }:
                    link["status"] = "cancelled"
            request_id = str(uuid.uuid4())
            self.links[request_id] = {
                "requestID": request_id,
                "sourcePlayerID": player_id,
                "codeHash": code_hash,
                "expiresAt": expires_at,
                "status": "pending",
                "targetPlayerID": None,
                "targetIdentity": None,
                "message": None,
            }
            return request_id

    def link_status(
        self, player_id: str, request_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            link = self.links.get(request_id)
            if link is None or player_id not in {
                link["sourcePlayerID"],
                link["targetPlayerID"],
            }:
                raise LinkError("link request not found")
            self._expire(link, now)
            if (
                link["status"] == "approved"
                and link["targetPlayerID"] == player_id
                and not link.get("targetSessionIssued")
            ):
                result = self._session(
                    str(link["sourcePlayerID"]), "linked-device", now, None
                )
                for session in self.sessions.values():
                    if session["playerID"] == player_id:
                        session["revoked"] = True
                link["targetSessionIssued"] = True
                result.update({"requestID": request_id, "status": "approved"})
                return result
            return {
                key: link.get(key)
                for key in (
                    "requestID",
                    "status",
                    "expiresAt",
                    "targetPlayerID",
                    "message",
                )
            }

    def cancel_link(
        self, player_id: str, request_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            link = self._link(request_id, player_id)
            if link["status"] not in {"pending", "target_confirmed"}:
                raise LinkError("link request cannot be cancelled")
            link["status"] = "cancelled"
            return {"requestID": request_id, "status": "cancelled"}

    def redeem_link(
        self, target_player_id: str, code_hash: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            if not self._attempt(
                target_player_id, "link_redeem", now, MAX_LINK_ATTEMPTS
            ):
                raise LinkError("too many device-link attempts; try again later")
            link = next(
                (
                    value
                    for value in self.links.values()
                    if hmac.compare_digest(str(value["codeHash"]), code_hash)
                ),
                None,
            )
            if link is None:
                raise LinkError("invalid device-link code")
            self._expire(link, now)
            if link["status"] != "pending":
                raise LinkError("device-link code is no longer valid")
            identity = next(
                (
                    value
                    for value in self.identities.values()
                    if value["playerID"] == target_player_id
                ),
                None,
            )
            player = self.players[target_player_id]
            if identity is None and player["guestHash"] is None:
                raise LinkError("this installation has no linkable credential")
            link.update(
                {
                    "status": "target_confirmed",
                    "targetPlayerID": target_player_id,
                    "targetIdentity": identity["id"] if identity else None,
                    "targetDevice": player["guestHash"],
                }
            )
            self.attempts.pop((target_player_id, "link_redeem"), None)
            source = self.players[str(link["sourcePlayerID"])]
            target = self.players[target_player_id]
            return {
                "requestID": link["requestID"],
                "status": "target_confirmed",
                "source": {
                    "id": link["sourcePlayerID"],
                    "displayName": source["displayName"],
                },
                "target": {
                    "id": target_player_id,
                    "displayName": target["displayName"],
                    "provider": identity["provider"] if identity else "device",
                },
            }

    def approve_link(
        self, source_player_id: str, request_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            link = self._link(request_id, source_player_id)
            self._expire(link, now)
            if link["status"] != "target_confirmed":
                raise LinkError("link request is not ready for approval")
            target = str(link["targetPlayerID"])
            if target in self.meaningful_players:
                link.update(
                    {
                        "status": "conflict",
                        "message": "The target profile has games, progress, or purchases and cannot be merged automatically.",
                    }
                )
                raise LinkError(
                    "profiles with games, progress, or purchases cannot be combined"
                )
            for identity in self.identities.values():
                if (
                    link.get("targetIdentity") is not None
                    and identity["id"] == link["targetIdentity"]
                ):
                    identity["playerID"] = source_player_id
            if link.get("targetDevice") is not None:
                self.players[source_player_id]["guestHash"] = link["targetDevice"]
                self.players[target]["guestHash"] = None
            link["status"] = "approved"
            return {"requestID": request_id, "status": "approved"}

    def create_email_code(
        self, player_id: str, email: str, code_hash: str, expires_at: float, now: float
    ) -> None:
        with self.lock:
            if not self._attempt(player_id, "email_code", now, 5):
                raise CredentialError("too many email codes requested; try again later")
            email_hash = hashlib.sha256(email.encode()).hexdigest()
            if not self._attempt_abuse("email_destination", email_hash, now, 5):
                raise CredentialError(
                    "too many login codes sent to this email; try again later"
                )
            self.email_codes[(player_id, email)] = {
                "codeHash": code_hash,
                "expiresAt": expires_at,
                "attempts": 0,
                "consumed": False,
            }

    def verify_email_code(
        self, player_id: str, email: str, code_hash: str, device_id: str, now: float
    ) -> dict[str, object]:
        with self.lock:
            challenge = self.email_codes.get((player_id, email))
            if (
                challenge is None
                or challenge["consumed"]
                or float(challenge["expiresAt"]) <= now
            ):
                raise CredentialError("email login code expired; request another code")
            if not hmac.compare_digest(str(challenge["codeHash"]), code_hash):
                challenge["attempts"] = int(challenge["attempts"]) + 1
                raise CredentialError("invalid email login code")
            challenge["consumed"] = True
            target = self.recovery_emails.get(email)
            if target is None:
                self.recovery_emails[email] = player_id
                self.players[player_id]["guestHash"] = None
                result = self._session(player_id, device_id, now, None)
                result["emailAction"] = "recovery_email_added"
                return result
            if target == player_id:
                result = self._session(player_id, device_id, now, None)
                result["emailAction"] = "already_linked"
                return result
            if (
                player_id in self.recovery_emails.values()
                or player_id in self.meaningful_players
            ):
                raise LinkError(
                    "this device's profile already has games, progress, or purchases; contact support to combine accounts"
                )
            for identity in self.identities.values():
                if identity["playerID"] == player_id:
                    identity["playerID"] = target
            self.players[target]["guestHash"] = self.players[player_id]["guestHash"]
            self.players[player_id]["deleted"] = True
            result = self._session(target, device_id, now, None)
            result["emailAction"] = "existing_account_linked"
            return result

    def account_status(self, player_id: str) -> dict[str, object]:
        email = next(
            (key for key, value in self.recovery_emails.items() if value == player_id),
            None,
        )
        provider = next(
            (
                value["provider"]
                for value in self.identities.values()
                if value["playerID"] == player_id
            ),
            None,
        )
        portable = email is not None or provider is not None
        return {
            "portable": portable,
            "guest": not portable,
            "recoveryEmail": email,
            "provider": provider,
            "progression": {},
        }

    def delete_player(self, player_id: str, now: float) -> None:
        with self.lock:
            self.players[player_id].update(
                {"deleted": True, "displayName": "Deleted Player", "guestHash": None}
            )
            self.identities = {
                key: value
                for key, value in self.identities.items()
                if value["playerID"] != player_id
            }
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

    def _attempt_abuse(self, scope: str, key: str, now: float, limit: int) -> bool:
        started, count = self.abuse_attempts.get((scope, key), (now, 0))
        if now - started >= 600:
            started, count = now, 0
        count += 1
        self.abuse_attempts[(scope, key)] = (started, count)
        return count <= limit

    @staticmethod
    def _expire(link: dict[str, object], now: float) -> None:
        if (
            link["status"] in {"pending", "target_confirmed"}
            and float(link["expiresAt"]) <= now
        ):
            link["status"] = "expired"
