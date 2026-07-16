# App Review notes and submission checklist

## Notes for App Review

Kolkhoz is a landscape-only strategic trick-taking card game. A limited demo can be played
offline without creating an account. A non-consumable In-App Purchase unlocks the complete game.
An account is required before purchase because the unlock is linked to that Kolkhoz account and
is available on every supported platform. Online multiplayer, social features, progression
syncing, and push notifications also require the account and network access.

Suggested review path:

1. Launch the app in landscape orientation.
2. From the lobby, start an offline demo game without creating an account.
3. Open Rules or How to Play from the lobby for an explanation of planning, tricks, assignments, plots, and requisition.
4. Sign in with the review account below to test an account that already owns the Full Game Unlock.
5. Use Restore Purchase from the unlock dialog to exercise storefront recovery.
6. Notification permission is optional and is requested only in connection with online activity.

Review account (fill immediately before submission):

- Email: `[APP_REVIEW_EMAIL]`
- Password: `[APP_REVIEW_PASSWORD]`

The app uses a Soviet collective-farm setting as fictional satire and game flavor. It contains no
real-money gambling, purchasable randomized items, user-generated chat, or political advocacy.

## Submission blockers

- [x] Apple Developer Program enrollment approved
- [x] App record created for bundle ID `com.williamtheisen.kolkhoz` (Apple ID `6790769553`)
- [ ] Current paid-applications agreement accepted, if required by the chosen price
- [x] Non-consumable `com.williamtheisen.kolkhoz.fullgame` created (Apple ID `6790770004`)
- [ ] Non-consumable submitted with the app version
- [x] App Store Server Notification V2 production and sandbox URLs configured
- [x] Apple root certificates and App Apple ID configured on the Kolkhoz server
- [x] Apple sandbox signed `TEST` notification delivered successfully
- [ ] Apple production signed `TEST` notification verified after the first production release
- [ ] Purchase, restore, refund, and account-link conflict tested in StoreKit sandbox
- [ ] APNs authentication key created and installed in Firebase
- [ ] Push notifications verified on a physical iPhone with a release/profile build
- [x] In-app account-deletion initiation added in Profile → Account; deletion surrenders the Full Game Unlock
- [ ] App Review account created and verified against production
- [x] App Review contact information and detailed review instructions saved on iOS version 1.0
- [ ] Updated privacy and support pages published and checked publicly
- [x] App Information subtitle, Games/Card/Strategy classification, content rights, and age rating saved
- [x] iOS 1.0 product description, promotional text, keywords, URLs, and copyright saved
- [ ] Five final 6.9-inch landscape screenshots captured and uploaded
- [x] Release archive `1.0.0 (1)` built, signed, and uploaded to App Store Connect
- [x] Release archive `1.0.0 (1)` processed and export-compliance cleared by App Store Connect
- [x] Release build `1.0.0 (1)` attached to iOS version 1.0
- [x] Internal TestFlight group created with automatic distribution; Account Holder invited to build `1.0.0 (1)`
- [x] External TestFlight group created with one tester; build `1.0.0 (1)` submitted to Beta App Review
- [ ] External build `1.0.0 (1)` approved and available to testers
- [x] App Privacy questionnaire reconciled with the final build and SDK versions and published July 14, 2026
- [x] Age-rating questionnaire completed; global 12+ with regional equivalents
- [x] Full Game Unlock price set to $4.99 USD with availability in all current and future storefronts
- [ ] Full Game Unlock review screenshot captured and uploaded

## Account deletion

Apple requires apps that support account creation to let users initiate deletion from within the
app. An email-only deletion process on the support page is useful for users now, but does not by
itself satisfy that App Review requirement for this app.

Implemented: signed-in players can initiate permanent deletion from Profile → Account. The
confirmation states that deletion also surrenders the Full Game Unlock.
