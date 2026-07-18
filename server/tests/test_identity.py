from __future__ import annotations

import hashlib
import threading
import unittest
import base64
import json
import struct
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from unittest.mock import patch

from server.kolkhoz_server.api import OnlineApplication, Request
from server.kolkhoz_server.auth import StaticAuthVerifier
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.identity import (
    AppleGameCenterVerifier,
    CompositeAuthVerifier,
    CredentialError,
    GooglePlayGamesVerifier,
    IdentityService,
    IdentitySessionVerifier,
    InMemoryIdentityRepository,
    LinkError,
    VerifiedIdentity,
)


class FakeVerifier:
    def __init__(self, provider: str) -> None:
        self.provider = provider

    def verify(self, payload: dict[str, object], now: float) -> VerifiedIdentity:
        credential = str(payload.get("credential") or "")
        if credential in {"", "forged", "expired"}:
            raise CredentialError("invalid platform credential")
        return VerifiedIdentity(
            self.provider,
            str(payload["subject"]),
            hashlib.sha256(credential.encode()).hexdigest(),
            now + 300,
            str(payload.get("displayName") or "") or None,
        )


class FakeHTTPResponse:
    def __init__(self, body: bytes) -> None:
        self.body = body

    def __enter__(self) -> "FakeHTTPResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def read(self) -> bytes:
        return self.body


class IdentityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = [1_000.0]
        self.repository = InMemoryIdentityRepository()
        self.service = IdentityService(
            self.repository,
            {
                "game_center": FakeVerifier("game_center"),
                "play_games": FakeVerifier("play_games"),
            },
            secret=b"test-secret-that-is-long-enough-for-hmac",
            clock=lambda: self.now[0],
        )

    def authenticate(self, provider: str, subject: str, credential: str) -> dict[str, object]:
        return self.service.authenticate(
            provider,
            {"subject": subject, "credential": credential},
            display_name="Player",
            device_id="device-1",
        )

    def test_first_and_returning_game_center_login_restore_player(self) -> None:
        first = self.authenticate("game_center", "gc-1", "gc-code-1")
        returning = self.authenticate("game_center", "gc-1", "gc-code-2")
        self.assertEqual(first["player"]["id"], returning["player"]["id"])  # type: ignore[index]
        self.assertNotEqual(first["accessToken"], returning["accessToken"])

    def test_first_and_returning_play_games_login_restore_player(self) -> None:
        first = self.authenticate("play_games", "pgs-1", "pgs-code-1")
        returning = self.authenticate("play_games", "pgs-1", "pgs-code-2")
        self.assertEqual(first["player"]["id"], returning["player"]["id"])  # type: ignore[index]

    def test_invalid_and_replayed_credentials_are_rejected(self) -> None:
        with self.assertRaises(CredentialError):
            self.authenticate("game_center", "gc-1", "forged")
        self.authenticate("game_center", "gc-1", "one-time-code")
        with self.assertRaises(CredentialError):
            self.authenticate("game_center", "gc-1", "one-time-code")

    def test_game_center_rejects_expired_and_untrusted_key_payloads(self) -> None:
        verifier = AppleGameCenterVerifier(bundle_id="com.williamtheisen.kolkhoz")
        payload = {
            "teamPlayerID": "gc-1",
            "publicKeyURL": "https://attacker.example/key",
            "signature": base64.b64encode(b"signature").decode(),
            "salt": base64.b64encode(b"salt").decode(),
            "timestamp": int(self.now[0] * 1000),
        }
        with self.assertRaisesRegex(CredentialError, "untrusted"):
            verifier.verify(payload, self.now[0])
        payload["timestamp"] = int((self.now[0] - 301) * 1000)
        with self.assertRaisesRegex(CredentialError, "expired"):
            verifier.verify(payload, self.now[0])

    def test_game_center_accepts_a_valid_signed_identity_tuple(self) -> None:
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import padding, rsa
        from cryptography.x509.oid import NameOID

        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Game Center Test")])
        certificate = (
            x509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(private_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.now(timezone.utc) - timedelta(minutes=1))
            .not_valid_after(datetime.now(timezone.utc) + timedelta(minutes=5))
            .sign(private_key, hashes.SHA256())
        )
        subject = "team-player-1"
        bundle_id = "com.williamtheisen.kolkhoz"
        timestamp = int(self.now[0] * 1000)
        salt = b"game-center-salt"
        signed = subject.encode() + bundle_id.encode() + struct.pack(">Q", timestamp) + salt
        signature = private_key.sign(signed, padding.PKCS1v15(), hashes.SHA256())
        payload = {
            "teamPlayerID": subject,
            "publicKeyURL": "https://static.gc.apple.com/public-key.cer",
            "signature": base64.b64encode(signature).decode(),
            "salt": base64.b64encode(salt).decode(),
            "timestamp": timestamp,
        }
        response = FakeHTTPResponse(
            certificate.public_bytes(serialization.Encoding.DER)
        )
        with patch("server.kolkhoz_server.identity.request.urlopen", return_value=response):
            verified = AppleGameCenterVerifier(bundle_id=bundle_id).verify(
                payload, self.now[0]
            )
        self.assertEqual(verified.provider, "game_center")
        self.assertEqual(verified.subject, subject)

    def test_play_games_exchanges_server_code_and_accepts_players_me(self) -> None:
        responses = [
            FakeHTTPResponse(json.dumps({"access_token": "google-access"}).encode()),
            FakeHTTPResponse(
                json.dumps(
                    {"playerId": "play-games-player-1", "displayName": "Comrade"}
                ).encode()
            ),
        ]
        with patch(
            "server.kolkhoz_server.identity.request.urlopen", side_effect=responses
        ) as urlopen:
            verified = GooglePlayGamesVerifier(
                client_id="server-client-id",
                client_secret="server-client-secret",
            ).verify({"serverAuthCode": "one-time-code"}, self.now[0])
        self.assertEqual(verified.provider, "play_games")
        self.assertEqual(verified.subject, "play-games-player-1")
        self.assertEqual(verified.display_name, "Comrade")
        self.assertEqual(urlopen.call_count, 2)
        self.assertEqual(
            urlopen.call_args_list[0].args[0].full_url,
            "https://oauth2.googleapis.com/token",
        )
        self.assertEqual(
            urlopen.call_args_list[1].args[0].full_url,
            "https://games.googleapis.com/games/v1/players/me",
        )

    def test_guest_fallback_restores_only_same_installation(self) -> None:
        first = self.service.guest(
            "installation-1234567890", display_name="Guest", device_id="one"
        )
        returning = self.service.guest(
            "installation-1234567890", display_name="Guest", device_id="one"
        )
        other = self.service.guest(
            "installation-abcdefghij", display_name="Guest", device_id="two"
        )
        self.assertEqual(first["player"]["id"], returning["player"]["id"])  # type: ignore[index]
        self.assertNotEqual(first["player"]["id"], other["player"]["id"])  # type: ignore[index]
        self.assertNotIn("installation-1234567890", repr(self.repository.players))

    def test_legacy_player_claim_keeps_uuid_and_rejects_cross_account_claim(self) -> None:
        legacy_id = "10000000-0000-4000-8000-000000000001"
        self.repository.players[legacy_id] = {
            "displayName": "Existing Player",
            "guestHash": None,
            "deleted": False,
        }
        claimed = self.service.authenticate(
            "game_center",
            {"subject": "gc-existing", "credential": "claim-proof"},
            display_name="Ignored New Name",
            device_id="iphone",
            claim_player_id=legacy_id,
        )
        self.assertEqual(claimed["player"]["id"], legacy_id)  # type: ignore[index]
        self.assertEqual(
            claimed["player"]["displayName"], "Existing Player"  # type: ignore[index]
        )
        returning = self.authenticate(
            "game_center", "gc-existing", "returning-proof"
        )
        self.assertEqual(returning["player"]["id"], legacy_id)  # type: ignore[index]

        other_id = "10000000-0000-4000-8000-000000000002"
        self.repository.players[other_id] = {
            "displayName": "Other Player",
            "guestHash": None,
            "deleted": False,
        }
        with self.assertRaisesRegex(LinkError, "another player"):
            self.service.authenticate(
                "game_center",
                {"subject": "gc-existing", "credential": "conflict-proof"},
                display_name="Other Player",
                device_id="other-iphone",
                claim_player_id=other_id,
            )

    def test_link_code_is_hashed_and_qr_uses_manual_redemption_path(self) -> None:
        source = self.authenticate("game_center", "gc-source", "gc-source-code")
        target = self.authenticate("play_games", "pg-target", "pg-target-code")
        source_id = str(source["player"]["id"])  # type: ignore[index]
        target_id = str(target["player"]["id"])  # type: ignore[index]
        link = self.service.create_link(source_id)
        stored = self.repository.links[str(link["requestID"])]
        self.assertNotEqual(stored["codeHash"], link["code"])
        self.assertTrue(str(link["qrPayload"]).endswith(str(link["code"])))
        preview = self.service.redeem(target_id, str(link["code"]))
        self.assertEqual(preview["status"], "target_confirmed")
        approved = self.repository.approve_link(
            source_id, str(link["requestID"]), self.now[0]
        )
        self.assertEqual(approved["status"], "approved")
        target_session = self.repository.link_status(
            target_id, str(link["requestID"]), self.now[0]
        )
        self.assertEqual(target_session["player"]["id"], source_id)  # type: ignore[index]
        restored = self.authenticate("play_games", "pg-target", "pg-new-code")
        self.assertEqual(restored["player"]["id"], source_id)  # type: ignore[index]

    def test_expiration_cancellation_and_repeated_use(self) -> None:
        source = self.authenticate("game_center", "gc-source", "gc-code")
        target = self.authenticate("play_games", "pg-target", "pg-code")
        source_id = str(source["player"]["id"])  # type: ignore[index]
        target_id = str(target["player"]["id"])  # type: ignore[index]
        expired = self.service.create_link(source_id)
        self.now[0] += 481
        with self.assertRaises(LinkError):
            self.service.redeem(target_id, str(expired["code"]))
        current = self.service.create_link(source_id)
        self.repository.cancel_link(source_id, str(current["requestID"]), self.now[0])
        with self.assertRaises(LinkError):
            self.service.redeem(target_id, str(current["code"]))
        final = self.service.create_link(source_id)
        self.service.redeem(target_id, str(final["code"]))
        self.repository.approve_link(source_id, str(final["requestID"]), self.now[0])
        with self.assertRaises(LinkError):
            self.service.redeem(target_id, str(final["code"]))

    def test_concurrent_redemption_has_one_winner(self) -> None:
        source = self.authenticate("game_center", "gc-source", "gc-code")
        target = self.authenticate("play_games", "pg-target", "pg-code")
        source_id = str(source["player"]["id"])  # type: ignore[index]
        target_id = str(target["player"]["id"])  # type: ignore[index]
        link = self.service.create_link(source_id)
        outcomes: list[str] = []

        def redeem() -> None:
            try:
                self.service.redeem(target_id, str(link["code"]))
                outcomes.append("won")
            except LinkError:
                outcomes.append("lost")

        threads = [threading.Thread(target=redeem) for _ in range(8)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(outcomes.count("won"), 1)

    def test_incorrect_link_attempts_are_bounded(self) -> None:
        target = self.authenticate("play_games", "pg-target", "pg-code")
        target_id = str(target["player"]["id"])  # type: ignore[index]
        for _ in range(8):
            with self.assertRaisesRegex(LinkError, "invalid"):
                self.service.redeem(target_id, "AAA-BBB")
        with self.assertRaisesRegex(LinkError, "too many"):
            self.service.redeem(target_id, "AAA-BBB")

    def test_meaningful_profile_conflict_preserves_both_players(self) -> None:
        source = self.authenticate("game_center", "gc-source", "gc-code")
        target = self.authenticate("play_games", "pg-target", "pg-code")
        source_id = str(source["player"]["id"])  # type: ignore[index]
        target_id = str(target["player"]["id"])  # type: ignore[index]
        self.repository.meaningful_players.add(target_id)
        link = self.service.create_link(source_id)
        self.service.redeem(target_id, str(link["code"]))
        with self.assertRaises(LinkError):
            self.repository.approve_link(source_id, str(link["requestID"]), self.now[0])
        self.assertEqual(self.repository.links[str(link["requestID"])]["status"], "conflict")
        restored = self.authenticate("play_games", "pg-target", "fresh-code")
        self.assertEqual(restored["player"]["id"], target_id)  # type: ignore[index]

    def test_session_refresh_and_account_deletion_revoke_tokens(self) -> None:
        login = self.authenticate("game_center", "gc-1", "gc-code")
        token = str(login["accessToken"])
        player_id = str(login["player"]["id"])  # type: ignore[index]
        verifier = IdentitySessionVerifier(
            self.repository, clock=lambda: self.now[0]
        )
        self.assertEqual(verifier.user_id(f"Bearer {token}"), player_id)
        self.repository.delete_player(player_id, self.now[0])
        self.assertIsNone(verifier.user_id(f"Bearer {token}"))
        self.assertFalse(self.repository.identities)

    def test_two_device_flow_through_api_rotates_target_session_and_deletes_account(self) -> None:
        repository = InMemoryIdentityRepository()
        service = IdentityService(
            repository,
            {
                "game_center": FakeVerifier("game_center"),
                "play_games": FakeVerifier("play_games"),
            },
            secret=b"test-secret-that-is-long-enough-for-hmac",
        )
        application = OnlineApplication(
            object(),  # type: ignore[arg-type]
            object(),  # type: ignore[arg-type]
            auth=IdentitySessionVerifier(repository),
            identity=service,
        )

        def dispatch(
            method: str,
            target: str,
            body: dict[str, object] | None = None,
            *,
            bearer: str | None = None,
            device_id: str,
        ) -> dict[str, object]:
            headers = {"X-Kolkhoz-Device-ID": device_id}
            if bearer is not None:
                headers["Authorization"] = f"Bearer {bearer}"
            response = application.dispatch(
                Request(method, target, headers, body or {})
            )
            self.assertEqual(response.status, HTTPStatus.OK)
            self.assertIsInstance(response.body, dict)
            return response.body  # type: ignore[return-value]

        source = dispatch(
            "POST",
            "/identity/platform/game_center",
            {"credential": {"subject": "gc-source", "credential": "gc-proof"}},
            device_id="iphone",
        )
        target = dispatch(
            "POST",
            "/identity/platform/play_games",
            {"credential": {"subject": "pg-target", "credential": "pg-proof"}},
            device_id="android",
        )
        source_id = str(source["player"]["id"])  # type: ignore[index]
        target_id = str(target["player"]["id"])  # type: ignore[index]
        source_token = str(source["accessToken"])
        target_token = str(target["accessToken"])
        self.assertNotEqual(source_id, target_id)

        link = dispatch(
            "POST",
            "/identity/device-links",
            bearer=source_token,
            device_id="iphone",
        )
        request_id = str(link["requestID"])
        redeemed = dispatch(
            "POST",
            "/identity/device-links/redeem",
            {"code": link["code"]},
            bearer=target_token,
            device_id="android",
        )
        self.assertEqual(redeemed["status"], "target_confirmed")
        approved = dispatch(
            "POST",
            f"/identity/device-links/{request_id}/approve",
            bearer=source_token,
            device_id="iphone",
        )
        self.assertEqual(approved["status"], "approved")
        linked = dispatch(
            "GET",
            f"/identity/device-links/{request_id}",
            bearer=target_token,
            device_id="android",
        )
        linked_token = str(linked["accessToken"])
        self.assertEqual(linked["player"]["id"], source_id)  # type: ignore[index]
        self.assertNotEqual(linked_token, target_token)

        with self.assertRaises(ServerError) as revoked:
            dispatch(
                "POST",
                "/identity/device-links",
                bearer=target_token,
                device_id="android",
            )
        self.assertEqual(revoked.exception.status, HTTPStatus.UNAUTHORIZED)

        returning = dispatch(
            "POST",
            "/identity/platform/play_games",
            {"credential": {"subject": "pg-target", "credential": "pg-proof-2"}},
            device_id="android",
        )
        self.assertEqual(returning["player"]["id"], source_id)  # type: ignore[index]

        deleted = dispatch(
            "DELETE",
            "/account",
            bearer=linked_token,
            device_id="android",
        )
        self.assertEqual(deleted, {"deleted": True})
        self.assertIsNone(
            application.auth.user_id(f"Bearer {source_token}")  # type: ignore[union-attr]
        )

    def test_api_claims_platform_identity_onto_legacy_bearer_uuid(self) -> None:
        repository = InMemoryIdentityRepository()
        legacy_id = "10000000-0000-4000-8000-000000000001"
        repository.players[legacy_id] = {
            "displayName": "Legacy Supabase Player",
            "guestHash": None,
            "deleted": False,
        }
        service = IdentityService(
            repository,
            {"game_center": FakeVerifier("game_center")},
            secret=b"test-secret-that-is-long-enough-for-hmac",
        )
        application = OnlineApplication(
            object(),  # type: ignore[arg-type]
            object(),  # type: ignore[arg-type]
            auth=CompositeAuthVerifier(
                IdentitySessionVerifier(repository),
                StaticAuthVerifier({"legacy-supabase-token": legacy_id}),
            ),
            identity=service,
        )
        response = application.dispatch(
            Request(
                "POST",
                "/identity/platform/game_center",
                {
                    "Authorization": "Bearer legacy-supabase-token",
                    "X-Kolkhoz-Device-ID": "iphone-4",
                },
                {
                    "credential": {
                        "subject": "gc-legacy-player",
                        "credential": "signed-proof",
                    }
                },
            )
        )
        self.assertEqual(response.status, HTTPStatus.OK)
        self.assertEqual(response.body["player"]["id"], legacy_id)  # type: ignore[index]
        self.assertTrue(str(response.body["accessToken"]).startswith("khz_"))  # type: ignore[index]

        class Accounts:
            def __init__(self) -> None:
                self.deleted: list[str] = []

            def delete(self, player_id: str) -> None:
                self.deleted.append(player_id)

        accounts = Accounts()
        application.accounts = accounts  # type: ignore[assignment]
        deleted = application.dispatch(
            Request(
                "DELETE",
                "/account",
                {
                    "Authorization": f"Bearer {response.body['accessToken']}",  # type: ignore[index]
                    "X-Kolkhoz-Device-ID": "iphone-4",
                },
                {},
            )
        )
        self.assertEqual(deleted.body, {"deleted": True})
        self.assertEqual(accounts.deleted, [legacy_id])


if __name__ == "__main__":
    unittest.main()
