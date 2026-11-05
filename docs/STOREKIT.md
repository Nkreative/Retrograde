# Purchases (StoreKit 2)

## Products

| | Lifetime | Yearly |
|---|---|---|
| Product ID | `com.nkreative.retrograde.premium.lifetime` | `com.nkreative.retrograde.premium.yearly` |
| Type | Non-consumable | Auto-renewable subscription, 1 year |
| Group | — | Retrograde Premium |
| US base price | $19.99 | $9.99 |
| Launch promotion | US $9.99 (50% off) for 14 days after launch, then $19.99 (a scheduled price change) | **$6.99 for the first year**, then $9.99/year, for eligible new subscribers, 14 days after launch (an introductory offer, pay up front) |
| Free trial | — | **none in v1.0** (the earlier 3-day trial is replaced by the first-year offer) |
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
| iOS simulator, app-hosted | Real StoreKit 2 against the local config: products/prices/the $6.99 first-year offer, purchase, cancel auto-renew, expiry, billing retry, grace period, refunds, Lifetime precedence, Ask to Buy, updates without refresh, load/status/sync outages | `xcodebuild test -project Retrograde.xcodeproj -scheme Retrograde -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'` |
| Xcode, by hand | Paywall and Settings in each state | Run the Retrograde scheme (uses the local config); Debug › StoreKit › Manage Transactions to refund, expire, approve |
| Device, Sandbox | Real App Store sign-in, Restore after reinstall, offline/online, renewals (sandbox yearly ≈ 1 hour) | Needs the App Store Connect setup below |
| TestFlight | Release build end to end | Before submission |

**Known unreliable step (Yearly expiry):** `expiryEndsPremium` and `lifetimeTakesOverFromAnExpiredYearly` depend on StoreKit's test environment showing an expired Yearly to the app, which it sometimes doesn't within 10 s (see `expireYearly` in `AppTests/StoreKitEntitlementTests.swift`). On 2026-11-04 (M12 validation, iPhone 18 Pro Max simulator, iOS 27.0) it failed more often than measured in M10: 5 runs of the suite had 2, 2, 2, 1 and 1 failures, always among these two tests; the approved M11 commit failed the same way in the same session. The tests and purchase code are unchanged; the other 21 StoreKit tests passed every time.

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
| Yearly `com.nkreative.retrograde.premium.yearly` | Created — US $9.99/year; a 7-day free trial is configured for the **US and Canada** — **replace it with the first-year offer** (see below) |
| Lifetime `com.nkreative.retrograde.premium.lifetime` | Created — US $19.99 |
| Submission | Both products created, **not yet submitted** for review (they go with the first app version) |

The app shows an introductory offer only when StoreKit returns one for the person's storefront *and* confirms they're eligible (Apple allows one introductory offer per subscription group per person, ever). Everyone else sees the regular $9.99/year. The local test file (`StoreKit/Retrograde.storekit`) has the v1.0 offer with no territory or date limits, so local tests always see it for new subscribers.

### Launch configuration

**1. Yearly: replace the free trial with "$6.99 for the first year".** Apple lets a subscription have only one current introductory offer per country (plus one scheduled for later), and each person can use only one introductory offer per subscription group, so the trial and the first-year price can't both be offered to the same new subscriber. For v1.0 the first-year price replaces the trial. Don't do this until the launch date is set:

1. App Store Connect › Apps › Retrograde › Monetization › Subscriptions › Retrograde Premium › **Yearly** › Subscription Prices › Introductory Offers.
2. **Remove the 7-day free trial:** it has never been live, so delete it (if it has a start date that has passed, set its end date instead; an offer that has run can't be deleted).
3. **Create the new offer:** Create Introductory Offer → countries: the ones you choose (the trial was the US and Canada) → **start date: the launch date; end date: 14 days later** → type **Pay up front** → duration **1 year** → price **$6.99** in the US (App Store Connect suggests equivalents elsewhere; check each one).
4. Save. Nothing needs to change in the app: it reads the offer, its price and eligibility from StoreKit, starts showing it on the start date and stops on the end date. After the end date new subscribers see $9.99/year and no offer, unless another introductory offer (for example a trial) is scheduled to follow; that's a separate decision.
5. People who subscribed at $6.99 renew at $9.99/year after their first year; Apple shows them the renewal price at purchase and the paywall's terms say so.

**How the paywall shows it** (all from StoreKit, nothing hardcoded):
- Plan line: "$6.99 for the first year, then $9.99/year"; price "$6.99 first yr" with the regular $9.99 crossed out; button "Start Premium"; terms "$6.99 for the first year, charged to your Apple Account at confirmation. Then $9.99 per year. Renews automatically unless cancelled at least 24 hours before the current period ends."
- Badge "FIRST YEAR · 30% OFF" only when StoreKit's own two prices support it: a pay-up-front offer that covers exactly one billing period and costs less than the regular price, in the same storefront. The percentage is rounded down ((9.99 − 6.99) / 9.99 = 30.03 % → 30 %), so it's never overstated. In another currency it's worked out from that storefront's prices.
- Someone not eligible (they've had Yearly or an earlier intro offer) sees "$9.99 / yr", "Renews yearly. Cancel anytime." and no badge.
- A free trial or a pay-as-you-go offer, if one is ever configured instead, is described as such ("3 days free, then …"; "$0.99/month for the first 3 months, then …"), with no discount badge.

**2. Lifetime launch special (50% off for 14 days).** Lifetime is a one-time purchase, so Apple's introductory offers don't apply; the launch special is a scheduled **price change** on the same product:
1. App Store Connect › Lifetime › Price Schedule › Add Price Change: United States **$9.99**, starting on the launch date. Leave other countries at their normal price (the in-app badge is only validated for the US — see below).
2. Add a second price change: United States back to **$19.99**, starting exactly **14 calendar days later** (App Store Connect price changes start at 12:00 a.m. Pacific).
3. Tell me the start date. I set `LaunchPromotion.launch.start` in `Packages/RetrogradeKit/Sources/Entitlements/LaunchPromotion.swift` to that date (midnight Pacific) and ship the update. Until it's set, the app shows no badge and no crossed-out price, even if StoreKit already charges $9.99.

**How the app decides to show "LAUNCH · 50% OFF" and the crossed-out $19.99** — all must be true, otherwise the plan shows StoreKit's price with no promotion:
- the promotion has a configured start, and the current time is within its 14 days (it ends by itself; no update needed);
- the person's storefront is one the promotion lists (US only), in the listed currency (USD);
- StoreKit's actual Lifetime price for that storefront is exactly the configured promotional price ($9.99).

The plan line says "Launch special through <last day>": the last full day before the regular price returns, on the Pacific calendar (e.g. a Dec 1 start reads "through Dec 14"). The price the person pays and sees is always StoreKit's. The app never hardcodes it, and never assumes a discount just because the price happens to be $9.99. To extend the special to other countries, add each storefront's currency, regular and promotional price to `LaunchPromotion.launch.prices` and schedule the matching price change in App Store Connect.

### Before Sandbox testing (on your iPhone)
Done: legal entity decision (individual for now), Paid Apps Agreement, bundle ID, both products.
Still to check or do:
1. **Billing Grace Period:** confirm it's on (16 days) and which renewals it covers.
2. **Product metadata:** each product has an English display name and description; the group "Retrograde Premium" has a display name.
3. **Users and Access → Sandbox → Test Accounts:** create one or two testers with unused email addresses (a US tester sees the first-year offer and the Lifetime launch badge while they're active; a tester in a country without the offer sees the regular price only).
4. **On the iPhone:** Settings › Developer › Sandbox Apple Account → sign in with a tester. Run from Xcode with your team selected, using a scheme whose StoreKit Configuration is None (a separate Sandbox scheme is planned).

### Before TestFlight
11. **App icon:** done in M14.4 (`App/Assets.xcassets/AppIcon.appiconset`, 1024 × 1024, opaque, with dark and tinted versions).
11a. **Privacy manifest:** done in M14 (`App/PrivacyInfo.xcprivacy`): no tracking, no data collected, and the one required-reason API the app uses, UserDefaults, for its own settings (reason CA92.1).
12. **Export compliance:** done in M14: `ITSAppUsesNonExemptEncryption = NO` (the app makes no network connections of its own and uses no encryption beyond Apple's operating system).
13. **Archive and upload** from Xcode (Product › Archive › Distribute › App Store Connect).
14. **TestFlight:** internal testing is immediate; external testers need Beta App Review and test information (feedback email, description).

### Before App Store submission
15a. **Support contact in the app:** done in M14.3 — https://apps.nkreative.com/retrograde/support and support@nkreative.com (`AppLinks`); also entered in App Store Connect.
15. **Privacy policy in the app:** done in M14.3 — https://apps.nkreative.com/retrograde/privacy (`AppLinks.privacyPolicy`); also entered in App Store Connect. The archive check (build phase "Require release links") now passes and also requires the support links.
15b. **App Information:** subtitle, category (Lifestyle suggested), age rating questionnaire, copyright line, **Privacy Policy URL** and **Support URL** (both required).
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
