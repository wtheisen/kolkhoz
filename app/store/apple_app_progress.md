# Apple App Store progress

Last updated: July 14, 2026

This is the handoff document for resuming Kolkhoz's Apple release setup. The current plan is a
free download with an offline demo and one $4.99 non-consumable purchase that unlocks the full
game on every supported platform through the player's Kolkhoz account.

## Current state

- Apple Developer Program enrollment is approved.
- App Store Connect app: `Kolkhoz`
- Bundle ID: `com.williamtheisen.kolkhoz`
- App Apple ID: `6790769553`
- iOS version: `1.0`, Prepare for Submission
- Uploaded and attached build: `1.0.0 (1)`
- External TestFlight build: submitted to Beta App Review and waiting for approval
- App Privacy responses: published July 14, 2026
- Age rating: global 12+ with regional equivalents
- Store release setting currently selected in App Store Connect: automatic release after approval

Do not submit version 1.0 yet. The visual design and purchase UI are still changing, so the
required screenshots should be captured only after those surfaces are final.

## Completed in App Store Connect

### App information

- Name: `Kolkhoz`
- Subtitle: `Tricks, plots, and famine`
- Primary category: Games
- Game subcategories: Card and Strategy
- Content rights: third-party content is present and properly licensed. This covers licensed
  fonts and CC0 audio.
- Apple's standard license agreement is selected.
- Age-rating questionnaire is complete. The material answers were:
  - infrequent alcohol reference because the rules include the “Drunkard” role;
  - frequent contests because online players compete for ratings/rankings;
  - no gambling, simulated gambling, loot boxes, violence, sexual content, chat, advertising,
    unrestricted web access, or broadly distributed user-generated content.

### Product page metadata

The prepared metadata in `app/store/app_store_metadata.md` has been entered and saved:

- promotional text;
- description;
- keywords;
- support and marketing URLs;
- copyright;
- version number;
- build `1.0.0 (1)`.

App Review contact information and detailed review instructions are saved. The contact email and
phone number are intentionally not duplicated in this repository.

### Full Game Unlock

- Type: non-consumable
- Reference name: `Full Game Unlock`
- Product ID: `com.williamtheisen.kolkhoz.fullgame`
- Apple ID: `6790770004`
- Base price: $4.99 USD with Apple's regional equivalents
- Availability: all 175 current storefronts
- Future storefronts: automatically included
- Localization:
  - display name: `Full Game Unlock`
  - description: `Unlock the complete game on all supported platforms.`
- Review instructions are saved.
- Family Sharing is currently off. Cross-platform sharing is handled by the player's Kolkhoz
  account rather than Apple Family Sharing.

The purchase still shows **Missing Metadata** because its required App Review screenshot has not
been uploaded. This is intentionally deferred until the unlock UI is final.

### Privacy and server integration

- Privacy Policy URL: `https://kolkhoz.williamtheisen.com/privacy.html`
- User Privacy Choices / support URL: `https://kolkhoz.williamtheisen.com/support.html`
- Six data types are declared as linked to the user: email address, other user content, user ID,
  device ID, purchase history, and product interaction.
- Product Interaction is declared for App Functionality and Analytics so authoritative game
  traces may be analyzed and used to improve or train AI opponents.
- No advertising or cross-app tracking is declared.
- App Store Server Notification V2 production and sandbox URLs are configured.
- Apple root certificates and the App Apple ID are configured on the server.
- A signed Apple sandbox `TEST` notification was received successfully.

### TestFlight

- Internal testing group exists with automatic distribution.
- The Account Holder was invited to build `1.0.0 (1)`.
- External group `External Playtesters` exists.
- One external tester was added.
- Build `1.0.0 (1)` was submitted to Beta App Review.

## Intentional pause points

### Screenshots

Do not capture or upload screenshots until the visual design is stable. Two separate screenshot
sets are needed:

1. The Full Game Unlock App Review screenshot, showing the actual purchase dialog and the
   one-time unlock clearly.
2. Final landscape App Store product screenshots. The current plan calls for five polished
   screenshots, with the strongest three first because Apple uses the first three most widely.

After the UI is final, boot an iPhone Pro Max simulator, build and run the Flutter iOS app, open
the unlock dialog, and capture real app output. Do not use design mockups for the IAP review
screenshot.

### App Review account

Create a dedicated production App Review account shortly before submission. It should already
own the Full Game Unlock so reviewers can test the cross-platform entitlement and Restore
Purchase path. Enter its credentials in App Store Connect; do not commit them to this repository.

## Remaining work before submission

1. Finalize the lobby, purchase dialog, and other screenshot-visible UI.
2. Capture and upload the Full Game Unlock review screenshot.
3. Confirm that the purchase changes from Missing Metadata to Ready to Submit.
4. Attach the Full Game Unlock to iOS version 1.0 in the version's In-App Purchases and
   Subscriptions section.
5. Capture and upload the final landscape product screenshots.
6. Create and verify the dedicated App Review account, then enter its credentials.
7. Test purchase, restore, refund/revocation, and account-link conflict behavior in StoreKit
   sandbox.
8. Create and install an APNs authentication key in Firebase, then verify push notifications on
   a physical iPhone using a profile or release build.
9. Publicly re-check the privacy and support pages against the final build.
10. Confirm the external TestFlight build has passed Beta App Review.
11. Complete the Paid Applications agreement after Apple's address update finishes processing.
12. Review Digital Services Act trader information and determine whether Vietnam should remain
    available or requires a game license for this release.
13. Decide whether the first release should remain automatic after approval or switch to manual
    release.
14. Decide whether the macOS 1.0 record will ship at the same time as iOS or later.
15. Add the app version and Full Game Unlock to an App Review submission only after every item
    above that affects the shipping build is complete.

After the first production release, send and verify an Apple production signed `TEST`
notification.

## Local release configuration already changed

- `app/ios/Runner/Info.plist` declares `ITSAppUsesNonExemptEncryption` as false.
- The iOS app requires full-screen landscape presentation.
- In-app account deletion is available from Profile → Account and warns that deletion also
  surrenders the Full Game Unlock.

## Related documents

- `app/store/app_store_metadata.md` — product-page copy and classification
- `app/store/privacy_disclosures.md` — published privacy-label inventory
- `app/store/review_notes.md` — detailed reviewer path and submission checklist
- `app/store/README.md` — store-document overview
- `app/store/screenshots/README.md` — screenshot requirements and capture notes

When resuming, start with the remaining-work list above and reconcile this document with the
shipping build before changing App Store Connect.
