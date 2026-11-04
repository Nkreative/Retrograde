# Purchases (StoreKit 2)

## Products

| | Lifetime | Yearly |
|---|---|---|
| Product ID | `com.nkreative.retrograde.premium.lifetime` | `com.nkreative.retrograde.premium.yearly` |
| Type | Non-consumable | Auto-renewable subscription, 1 year |
| Group | — | Retrograde Premium |
| US base price | $19.99 | $9.99 |
| Intro offer | none | 7-day free trial, eligible new subscribers |
| Family Sharing | off | off |

App bundle ID: `com.nkreative.retrograde`. Both products unlock the same Premium features. Prices, currencies and offer eligibility always come from StoreKit; the app never hardcodes them. `StoreKit/Retrograde.storekit` mirrors these products for local testing — keep it in sync with App Store Connect.

## How Premium is decided

```
StoreKit 2 (verified only) ──► StoreKitEntitlementSource ──► EntitlementSnapshot ──► EntitlementRules ──► EntitlementStore.isPremium ──► Calendar, Survival Kit, paywall, Settings
```

- **Source of truth:** `Transaction.currentEntitlements` (Lifetime) and the Yearly product's latest verified transaction plus its verified `subscriptionStatus` (renewal state, auto-renew, grace end). Unverified results are ignored. Expiry dates are Apple's, never calculated.
- **Rules** (`EntitlementRules`): Lifetime always wins; Yearly is Premium while subscribed (until Apple's expiry) or in the billing grace period; billing retry after grace, expired, refunded or revoked are not Premium.
- **Updates:** at launch the store reads entitlements and starts listening to `Transaction.unfinished` and `Transaction.updates` (renewals, refunds, Ask to Buy approvals, other devices); it re-reads whenever the app becomes active. Verified transactions are finished after they're processed.
- **Failures:** if a read fails, the last verified snapshot stays — a network or product-loading problem never takes Premium away. Products load only for purchasing/display, separately from entitlements.
- **Offline:** StoreKit keeps its signed transactions on the device, so verified entitlements remain available offline. The app keeps no copy of its own; if StoreKit can't return renewal details, the verified transaction's own expiry is used.
- **Restore:** `AppStore.sync()` then a re-read. Purchases belong to the Apple Account, so reinstalling or a new phone needs no Retrograde account.
- **Lifetime while Yearly renews:** status `.lifetime(yearlyStillRenewing: true)`; Settings explains the subscription must be cancelled separately.

Debug builds can swap in the M8 simulator (`-entitlementSource simulated`); it isn't compiled into release builds.

## Testing

| Where | What | How |
|---|---|---|
| Mac, `swift test` | Rules for every state, store behaviour (failed reads, pending, live updates), simulator, access rules | `cd Packages/RetrogradeKit && swift test --scratch-path ~/Library/Caches/RetrogradeKit-build` |
| iOS simulator, app-hosted | Real StoreKit 2 against the local config: products/prices/trial, purchase, cancel auto-renew, expiry, billing retry, grace period, refunds, Lifetime precedence, Ask to Buy, updates without refresh, load/status/sync outages | `xcodebuild test -project Retrograde.xcodeproj -scheme Retrograde -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'` |
| Xcode, by hand | Paywall and Settings in each state | Run the Retrograde scheme (uses the local config); Debug › StoreKit › Manage Transactions to refund, expire, approve |
| Device, Sandbox | Real App Store sign-in, Restore after reinstall, offline/online, renewals (sandbox yearly ≈ 1 hour) | Needs the App Store Connect setup below |
| TestFlight | Release build end to end | Before submission |

Restore's sign-in dialog can't run unattended, so Restore is covered by the reinstall and failure tests plus the Sandbox check.

## App Store Connect checklist

### Before local StoreKit testing
Nothing — `StoreKit/Retrograde.storekit` is in the project and the Retrograde scheme uses it.

### Current App Store Connect status (2026-11-04)

| Item | Status |
|---|---|
| Apple Developer enrollment | Individual |
| Paid Apps Agreement | Active |
| Bundle ID `com.nkreative.retrograde` | Registered |
| Yearly `com.nkreative.retrograde.premium.yearly` | Created — US $9.99/year; 7-day free trial configured for the **US and Canada** |
| Lifetime `com.nkreative.retrograde.premium.lifetime` | Created — US $19.99 |
| Submission | Both products created, **not yet submitted** for review (they go with the first app version) |

Because the trial is configured only for the US and Canada, customers in other countries see the Yearly price without trial wording — the app shows the trial only when StoreKit returns an introductory offer for the person's storefront *and* confirms they're eligible. The local test file (`StoreKit/Retrograde.storekit`) has no territory restriction, so local tests always see the trial for new subscribers.

### Before Sandbox testing (on your iPhone)
Done: legal entity decision (individual for now), Paid Apps Agreement, bundle ID, both products.
Still to check or do:
1. **Billing Grace Period:** confirm it's on (16 days) and which renewals it covers.
2. **Product metadata:** each product has an English display name and description; the group "Retrograde Premium" has a display name.
3. **Users and Access → Sandbox → Test Accounts:** create one or two testers with unused email addresses (one US, optionally one Canada to see the trial, and one elsewhere to see no trial).
4. **On the iPhone:** Settings › Developer › Sandbox Apple Account → sign in with a tester. Run from Xcode with your team selected, using a scheme whose StoreKit Configuration is None (a separate Sandbox scheme is planned).

### Before TestFlight
11. **App icon:** a 1024×1024 icon is required to upload — none exists yet.
12. **Export compliance:** the app uses only Apple's encryption; I'll add `ITSAppUsesNonExemptEncryption = NO`.
13. **Archive and upload** from Xcode (Product › Archive › Distribute › App Store Connect).
14. **TestFlight:** internal testing is immediate; external testers need Beta App Review and test information (feedback email, description).

### Before App Store submission
15. **App Information:** subtitle, category (Lifestyle suggested), age rating questionnaire, copyright line, **Privacy Policy URL** and **Support URL** (both required).
16. **App Privacy:** answer only after the data-flow audit (planned before submission) — don't assume "Data Not Collected".
17. **Version page:** iPhone screenshots (6.9-inch required), description, keywords, promotional text, review notes explaining Premium and that Sandbox purchase works.
18. **Terms of Use:** Apple's standard EULA (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/); linked in the paywall and Settings, and in the description or the EULA field.
19. **In-App Purchases on the version:** first-time products must be added to the version and submitted with it; each needs a review screenshot of the paywall.
20. **Pricing and Availability:** app free; all countries (or as decided).

## Legal entity

Your Apple Developer membership is **individual** (Paid Apps Agreement signed as an individual), while your business is **NKreative LLC**. Revisit this before the first App Store submission:

- On an individual account the App Store shows **your personal legal name** as the developer and seller, not NKreative LLC. You personally are the party to Apple's agreements, and the tax forms and bank account are in your name.
- To sell as **NKreative LLC**, the membership must be an **organization** (needs a D-U-N-S number for the LLC, a business website/domain, and authority to bind the company). Apple Developer Support can convert an existing individual membership to an organization, keeping the account and apps; this is much simpler before the first release than after.
- The privacy policy, support page and copyright line should name whichever entity actually offers the app; the `com.nkreative…` bundle ID works either way.
- This affects contracts and taxes — worth confirming with your accountant or lawyer.
