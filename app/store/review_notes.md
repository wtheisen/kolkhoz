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

- [ ] Apple Developer Program enrollment approved
- [ ] App record created for bundle ID `com.williamtheisen.kolkhoz`
- [ ] Current paid-applications agreement accepted, if required by the chosen price
- [ ] Non-consumable `com.williamtheisen.kolkhoz.fullgame` created and submitted with the app version
- [ ] App Store Server Notification V2 production and sandbox URLs configured
- [ ] Apple root certificates and App Apple ID configured on the Kolkhoz server
- [ ] Purchase, restore, refund, and account-link conflict tested in StoreKit sandbox
- [ ] APNs authentication key created and installed in Firebase
- [ ] Push notifications verified on a physical iPhone with a release/profile build
- [ ] In-app account-deletion initiation added in an easy-to-find account/settings location
- [ ] App Review account created and verified against production
- [ ] Updated privacy and support pages published and checked publicly
- [ ] Five final 6.9-inch landscape screenshots captured and uploaded
- [ ] Release archive built, signed, uploaded, and processed by App Store Connect
- [ ] App Privacy questionnaire reconciled with the final build and SDK versions
- [ ] Age-rating questionnaire completed
- [ ] Full Game Unlock price and availability selected

## Account deletion

Apple requires apps that support account creation to let users initiate deletion from within the
app. An email-only deletion process on the support page is useful for users now, but does not by
itself satisfy that App Review requirement for this app.

Implemented: signed-in players can initiate permanent deletion from Profile → Account. The
confirmation states that deletion also surrenders the Full Game Unlock.
