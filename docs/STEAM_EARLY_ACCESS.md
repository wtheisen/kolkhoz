# Steam Early Access release

Kolkhoz ships on Steam as the same free demo used elsewhere. The permanent **Full
Game Unlock** remains $4.99 and is purchased through Steam Wallet. The server links
the verified Steam transaction to the signed-in Kolkhoz account, so it unlocks every
platform. If that is the account's only valid purchase and Steam refunds or reverses
it, hourly reconciliation locks the full game everywhere again.

## Steamworks setup

1. Create the Steam app, Windows depot, default package, and store page in Steamworks.
2. Enable the Microtransactions API and define item `1` as the Full Game Unlock. The
   server sends the authoritative USD price of 499 cents to `InitTxn`; Steam handles
   wallet authorization and regional conversion.
3. Request Early Access review after the store page, questionnaire, pricing, content
   survey, capsules, screenshots, trailer, and playable build are complete.
4. Create a restricted SteamPipe build account with edit permission for this app.

Do not put the publisher Web API key or SteamPipe credentials in the app or repository.

## Server configuration

Apply `server/commerce_schema.sql`, then configure the production server:

```text
KOLKHOZ_STEAM_APP_ID=<numeric app id>
KOLKHOZ_STEAM_PUBLISHER_KEY=<publisher web api key>
KOLKHOZ_RUN_STEAM_RECONCILER=true
KOLKHOZ_STEAM_RECONCILE_INTERVAL_SECONDS=3600
```

Use `KOLKHOZ_STEAM_SANDBOX=true` only while testing against Valve's sandbox API.
Run the reconciler on one worker process. The publisher key never crosses the server
boundary.

## GitHub repository secrets

- `KOLKHOZ_SUPABASE_URL`
- `KOLKHOZ_SUPABASE_PUBLISHABLE_KEY`
- `STEAMWORKS_SDK_URL`: secret HTTPS download URL for the Steamworks SDK zip
- `STEAMWORKS_SDK_SHA256`: uppercase SHA-256 of that private SDK archive
- `STEAMWORKS_SDK_AUTHORIZATION`: optional HTTP Authorization header for the download
- `STEAM_BUILDER_USERNAME` and `STEAM_BUILDER_PASSWORD`
- `STEAM_CONFIG_VDF_BASE64`: optional pre-authorized Steam Guard machine token

Run **Build Steam depot** with the AppID and Windows depot ID. Leave upload disabled
for a downloadable candidate artifact. Enable it after the build account is authorized;
an optional Steam branch name can be set live after upload.

The normal Windows entrypoint never imports Steamworks. Steam builds use
`lib/main_steam.dart` and copy `steam_api64.dll` from the private SDK into the depot.
This keeps the standalone Windows release functional without Steam installed.

## Release checklist

- Test purchase approved, canceled, restored, and refunded in the Steam sandbox.
- Confirm the same account unlocks on iOS, Android, macOS, and Windows after purchase.
- Confirm a sole refunded Steam receipt locks all platforms; confirm another valid
  independent store receipt continues to grant access.
- Verify Steam overlay behavior, controller input, cloud sign-in, offline cached play,
  and a clean install from the candidate branch.
- Complete Valve's build and store review before choosing the Early Access launch date.
