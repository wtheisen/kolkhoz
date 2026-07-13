# Draft App Privacy disclosures

These answers reflect the current online account, multiplayer, and notification implementation.
Re-check every answer against the shipping build and each third-party SDK before submission.

## Data linked to the user

| App Store data type | What Kolkhoz uses | Purpose |
| --- | --- | --- |
| Contact Info — Email Address | Supabase account email | App Functionality; account authentication, recovery, and support |
| Identifiers — User ID | Supabase user UUID and Kolkhoz account identifiers | App Functionality; account, social, progression, and online-game ownership |
| Identifiers — Device ID | App installation identifier and push token | App Functionality; notification delivery and device registration |
| User Content — Other User Content | Display name and selected built-in portrait | App Functionality; player profile and social surfaces |
| Usage Data — Product Interaction | Invitations, comrade relationships, game actions, results, ratings, and progression | App Functionality; multiplayer execution, social features, leaderboards, and progression |
| Purchases — Purchase History | Store provider, product and transaction identifiers, entitlement status, and refund/revocation state | App Functionality; link the full-game unlock to the player's Kolkhoz account across platforms |

## Data not collected for App Store disclosure

- No advertising data or third-party advertising
- No cross-app or cross-website tracking
- No precise or coarse location
- No contacts address-book access
- No payment-card, bank-account, or other financial information; storefronts process payment details
- No photos, videos, audio, microphone, camera, health, or fitness data
- No crash-reporting or third-party product analytics SDK currently identified
- Offline game state and local preferences remain on the device unless used in an online feature

## Third-party processors to include in the final review

- Supabase: authentication and hosted account/game data
- Firebase Cloud Messaging: push-token registration and notification delivery
- Apple Push Notification service: notification delivery on Apple devices
- Apple App Store: purchase processing and signed transaction status
- Better Stack: server uptime and heartbeat monitoring; not an in-app analytics or tracking SDK

## Tracking answer

**Does this app use data for tracking?** No.

Kolkhoz does not combine app data with third-party data for advertising, advertising measurement,
or sale to data brokers.
