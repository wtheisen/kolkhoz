# Passwordless Player Identity Setup

Kolkhoz owns the canonical player UUID. Game Center and Google Play Games are
verified linked credentials for that UUID; neither display names nor raw client-supplied
player IDs are trusted. A declined/unavailable platform login falls back to a guest tied
to an installation secret stored in the OS secure store.

## Server

Apply `server/identity_schema.sql` after the existing schemas. Configure these values
outside the repository:

```text
KOLKHOZ_IDENTITY_SECRET=<at least 32 cryptographically random characters>
KOLKHOZ_APPLE_BUNDLE_ID=com.williamtheisen.kolkhoz
KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_ID=<web OAuth client ID>
KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_SECRET=<web OAuth client secret>
KOLKHOZ_RESEND_API_KEY=<server-only Resend API key>
KOLKHOZ_RECOVERY_EMAIL_FROM=Kolkhoz <login@your-verified-domain.example>
```

The identity secret HMACs guest installation identifiers and link codes. Rotate it only
with a migration plan because outstanding link codes and guest restorations depend on it.
Never log platform payloads, auth codes, raw link codes, or `khz_` session tokens.

Resend is a delivery transport only. Kolkhoz generates, hashes, expires, rate-limits,
and verifies six-digit email codes. A verified recovery email is an attached credential
on the canonical player UUID; it never creates a second account type.

## App Store Connect and Game Center

1. Enable Game Center for bundle ID `com.williamtheisen.kolkhoz` in Certificates,
   Identifiers & Profiles and on the App Store Connect app record.
2. Regenerate/download development and distribution provisioning profiles after enabling
   the capability. The checked-in iOS and macOS release entitlements request Game Center.
3. Add Game Center sandbox testers in App Store Connect. Sign the device into the sandbox
   Game Center account and install a development/TestFlight build.
4. Confirm the native bridge returns `teamPlayerID`, `publicKeyURL`, `signature`, `salt`,
   and `timestamp`. The server accepts only a recent signature, an Apple static-key HTTPS
   URL, and a valid signature over the scoped player ID, bundle ID, timestamp, and salt.
5. Test returning login on another Apple device with the same Game Center account.

Reference: [Apple authenticating a player](https://developer.apple.com/documentation/gamekit/authenticating-a-player)
and [identity verification signature](https://developer.apple.com/documentation/gamekit/gklocalplayer/fetchitems%28foridentityverificationsignature%3A%29).

## Google Play Console and Play Games Services v2

1. Create/link a Play Games Services project for Android package
   `com.williamtheisen.kolkhoz`.
2. Create Android credentials for every signing certificate used by internal/debug and
   production builds. Package name and SHA fingerprint must match the installed APK/AAB.
3. Create a **game server** credential backed by a Web application OAuth client. Put that
   web client ID in both the Android Gradle property
   `KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_ID` and the server environment; keep its client secret
   only on the server.
4. Publish the PGS configuration to an internal test track and add tester accounts.
5. Verify automatic v2 platform authentication, then `requestServerSideAccess` returns a
   one-time code. The server exchanges it and reads `players/me`; the app never sends or
   chooses the accepted Play Games player ID.

Reference: [PGS v2 platform authentication](https://developer.android.com/games/pgs/platform-authentication),
[server-side access](https://developer.android.com/games/pgs/android/server-access), and
[Play Console setup](https://developer.android.com/games/pgs/console/setup).

Build locally with:

```bash
cd app
ORG_GRADLE_PROJECT_KOLKHOZ_PLAY_GAMES_SERVER_CLIENT_ID=<web-client-id> \
  flutter build apk --debug
```

Alternatively put the value temporarily in `~/.gradle/gradle.properties`; never commit it.
Release builds also fail closed unless `KOLKHOZ_ANDROID_KEYSTORE_PATH`,
`KOLKHOZ_ANDROID_KEYSTORE_PASSWORD`, `KOLKHOZ_ANDROID_KEY_ALIAS`, and
`KOLKHOZ_ANDROID_KEY_PASSWORD` are supplied as Gradle properties. The release certificate's
SHA fingerprint must match the Play Console Android credential.

## Device linking and QR testing

The in-app scanner reads `kolkhoz://link?code=ABC-123` directly, so no associated domain
or external URL handler is required. Camera descriptions/permissions are configured for
iOS, macOS, and Android. Manual entry and QR scanning call the same redemption endpoint.

1. Authenticate an Apple source and create a link; verify only the hash appears in
   `server_device_link_requests` and expiry is eight minutes.
2. On Android, authenticate PGS, scan or enter the code, inspect both profiles, and confirm.
3. Refresh the source, inspect the target, and approve. The target receives a rotated
   session for the source UUID.
4. Repeat with an established target that has a result, progression, entitlement, or
   purchase. It must end in `conflict`; neither profile nor history is changed.
5. Test cancel, expiry, repeated use, wrong code, and simultaneous redemption.

## Operational requirements

- Console capabilities, OAuth credentials, testers, signing fingerprints, and regenerated
  provisioning profiles must be completed by an account owner; no real secrets belong in
  this repository.
- The migration copies confirmed legacy email addresses onto the same canonical player
  UUID. The new app does not start Supabase sessions. The server may continue accepting
  old bearer tokens temporarily so installed older builds can migrate, but new builds
  use only `khz_` sessions, platform credentials, device credentials, and recovery email
  codes. Remove the compatibility verifier after older builds and support obligations
  have expired.
- Monitor unauthorized platform attempts, link conflicts, rate-limit responses, and
  session revocations without recording credential material.
