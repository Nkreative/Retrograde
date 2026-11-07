# Purchases (StoreKit 2)

## Products

| | Lifetime | Yearly |
|---|---|---|
| Product ID | `com.nkreative.retrograde.premium.lifetime` | `com.nkreative.retrograde.premium.yearly` |
| Type | Non-consumable | Auto-renewable subscription, 1 year |
| Group | — | Retrograde Premium |
| US base price | $19.99 | $9.99 |
| Promotions | US $9.99 (50% off) during the 14-day launch window and the Mercury windows, then $19.99 (scheduled price changes, see below) | — |
| Introductory offer | — (not available for one-time purchases) | **$6.99 for the first year**, then $9.99/year: pay up front, 1 year, for eligible new subscribers. In App Store Connect it's the only Yearly introductory offer, US, from Nov 6, 2026 with no end date |
| Free trial | — | **none** (earlier trial configurations were removed) |
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
| Device, Sandbox | Real App Store sign-in, Restore after reinstall, offline/online, renewals and expiry (sandbox renews a yearly subscription quickly; the rate is set under Settings › Developer › Sandbox Apple Account) | Run the **Retrograde (Sandbox)** scheme on the iPhone; needs the App Store Connect setup below |
| TestFlight | Release build end to end | Before submission |

**Yearly expiry in the app-hosted tests:** `expiryEndsPremium`, `lifetimeTakesOverFromAnExpiredYearly` and `noFirstYearOfferForSomeoneWhoAlreadySubscribed` let the subscription run out on its own (`buyYearlyAndLetItExpire` in `AppTests/StoreKitEntitlementTests.swift`): the test session runs one billing period every 2 seconds (`timeRate = .oneRenewalEveryTwoSeconds`), auto-renew is turned off, and the test waits until the verified expiry has passed. They used to force the expiry with `expireSubscription`, which was unreliable: StoreKit's test environment kept returning the pre-expiry transaction to the app for 10 s or more (on 2026-11-04 five suite runs had 2, 2, 2, 1 and 1 failures among these tests; on 2026-11-06 both failed in every run). The change is in the tests only; the purchase and entitlement code is unchanged.

Restore's sign-in dialog can't run unattended, so Restore is covered by the reinstall and failure tests plus the Sandbox check.

## Xcode schemes

| Scheme | StoreKit while running from Xcode | Use it for |
|---|---|---|
| **Retrograde** | Xcode's local test store (`StoreKit/Retrograde.storekit`, a copy of the App Store products) | Day-to-day work in the simulator: paywall and Premium states without an Apple Account, Debug › StoreKit › Manage Transactions. Purchases made this way live only in Xcode's test store and disappear when the app is deleted. |
| **Retrograde (Sandbox)** | None, so the real App Store in its Sandbox environment | Testing on the iPhone with a Sandbox Apple Account (Settings › Developer › Sandbox Apple Account): real purchase sheets, Restore after reinstall, renewals, cancellation and expiry. |

Both schemes archive with the Release configuration, which always uses the real App Store; the local test file only applies to Run from Xcode and isn't part of the app. The app-hosted StoreKit tests load `Retrograde.storekit` themselves (`SKTestSession`), whichever scheme runs them.

## Device validation (Sandbox)

Validated on a physical iPhone with the **Retrograde (Sandbox)** scheme and a US Sandbox Apple Account (November 2026):

| Check | Result |
|---|---|
| Lifetime purchase ($19.99 sheet, "for testing only") | Passed: Premium unlocked and stayed unlocked after relaunch |
| Delete and reinstall, then Restore Purchases | Passed: Lifetime found and Premium unlocked again |
| Yearly purchase | Passed: Premium unlocked |
| Cancellation (auto-renew turned off) | Passed: Premium kept until the end of the period |
| Expiration | Passed: the subscription expired and Premium locked again |

Early on, a purchase made with the **Retrograde** scheme (Xcode's local test store) couldn't be restored after reinstalling: that's expected, since local test purchases never reach the Sandbox account. Use the Sandbox scheme for anything involving the real App Store.

## App Store Connect checklist

### Before local StoreKit testing
Nothing — `StoreKit/Retrograde.storekit` is in the project and the **Retrograde** scheme uses it.

### Current App Store Connect status (2026-11-06)

| Item | Status |
|---|---|
| Apple Developer enrollment | Individual |
| Paid Apps Agreement | Active |
| Bundle ID `com.nkreative.retrograde` | Registered |
| Yearly `com.nkreative.retrograde.premium.yearly` | Created — US $9.99/year; one introductory offer: **$6.99 for the first year** (pay up front, 1 year), US, from Nov 6, 2026, no end date; no free trial |
| Lifetime `com.nkreative.retrograde.premium.lifetime` | Created — US $19.99 |
| Submission | Both products created, **not yet submitted** for review (they go with the first app version) |

The app shows an introductory offer only when StoreKit returns one for the person's storefront *and* confirms they're eligible (Apple allows one introductory offer per subscription group per person, ever). Everyone else sees the regular $9.99/year. The local test file (`StoreKit/Retrograde.storekit`) has the v1.0 offer with no territory or date limits, so local tests always see it for new subscribers.

### Launch configuration

**1. Yearly: "$6.99 for the first year".** Configured in App Store Connect › Apps › Retrograde › Monetization › Subscriptions › Retrograde Premium › **Yearly** › Subscription Prices › Introductory Offers: one offer, **Pay up front**, duration **1 year**, **$6.99** in the US, starting Nov 6, 2026 with no end date. Apple allows one current introductory offer per country, and each person can use only one introductory offer per subscription group. Nothing in the app needs to change when the offer changes: it reads the offer, its price and eligibility from StoreKit. People who subscribed at $6.99 renew at $9.99/year after their first year; Apple shows them the renewal price at purchase and the paywall's terms say so. To end the offer later, set an end date; after it, new subscribers see $9.99/year and no offer.

**How the paywall shows it** (all from StoreKit, nothing hardcoded):
- Plan line: "$6.99 for the first year, then $9.99/year"; price "$6.99 first yr" with the regular $9.99 crossed out; button "Start Premium"; terms "$6.99 for the first year, charged to your Apple Account at confirmation. Then $9.99 per year. Renews automatically unless cancelled at least 24 hours before the current period ends."
- Badge "FIRST YEAR · 30% OFF" only when StoreKit's own two prices support it: a pay-up-front offer that covers exactly one billing period and costs less than the regular price, in the same storefront. The percentage is rounded down ((9.99 − 6.99) / 9.99 = 30.03 % → 30 %), so it's never overstated. In another currency it's worked out from that storefront's prices.
- Someone not eligible (they've had Yearly or an earlier intro offer) sees "$9.99 / yr", "Renews yearly. Cancel anytime." and no badge.
- A free trial or a pay-as-you-go offer, if one is ever configured instead, is described as such ("3 days free, then …"; "$0.99/month for the first 3 months, then …"), with no discount badge.

**2. Lifetime launch special (50% off for 14 days).** Lifetime is a one-time purchase, so Apple's introductory offers don't apply; the launch special is a scheduled **price change** on the same product:
1. App Store Connect › Lifetime › Price Schedule › Add Price Change: United States **$9.99**, starting on the launch date. Leave other countries at their normal price (the in-app badge is only validated for the US — see below).
2. Add a second price change: United States back to **$19.99**, starting exactly **14 calendar days later** (App Store Connect price changes start at 12:00 a.m. Pacific).
3. Tell me the start date. I set `LaunchPromotion.launch.start` in `Packages/RetrogradeKit/Sources/Entitlements/LaunchPromotion.swift` to that date (midnight Pacific) and ship the update. Until it's set, the app shows no badge and no crossed-out price, even if StoreKit already charges $9.99.

**3. Mercury promotions (recurring).** The same $9.99 Lifetime price runs for the 7 calendar days before every Mercury direct station, for everyone. The app works the windows out from the bundled sky data (Pacific time, as App Store Connect schedules price changes): the 7 days before the station's Pacific date, midnight to midnight. For each one, add two Lifetime price changes in App Store Connect › Lifetime › Price Schedule (US): $9.99 on the first date and $19.99 on the second. Nothing needs to change in the app. If a Mercury window overlaps the launch window, schedule one continuous $9.99 period covering both; the app shows a single offer ending when the regular price returns, never a bigger discount.

| Mercury turns direct | $9.99 from (12:00 am PT) | $19.99 again from (12:00 am PT) | Offer days |
|---|---|---|---|
| Nov 13, 2026 7:54 AM PT | Nov 6, 2026 | Nov 13, 2026 | Nov 6 – Nov 12 |
| Mar 3, 2027 4:32 AM PT | Feb 24, 2027 | Mar 3, 2027 | Feb 24 – Mar 2 |
| Jul 4, 2027 12:39 PM PT | Jun 27, 2027 | Jul 4, 2027 | Jun 27 – Jul 3 |
| Oct 28, 2027 7:11 AM PT | Oct 21, 2027 | Oct 28, 2027 | Oct 21 – Oct 27 |
| Feb 14, 2028 4:38 AM PT | Feb 7, 2028 | Feb 14, 2028 | Feb 7 – Feb 13 |
| Jun 13, 2028 11:06 PM PT | Jun 6, 2028 | Jun 13, 2028 | Jun 6 – Jun 12 |
| Oct 11, 2028 3:28 AM PT | Oct 4, 2028 | Oct 11, 2028 | Oct 4 – Oct 10 |
| Jan 27, 2029 10:40 AM PT | Jan 20, 2029 | Jan 27, 2029 | Jan 20 – Jan 26 |
| May 25, 2029 12:21 PM PT | May 18, 2029 | May 25, 2029 | May 18 – May 24 |
| Sep 24, 2029 7:02 PM PT | Sep 17, 2029 | Sep 24, 2029 | Sep 17 – Sep 23 |
| Jan 10, 2030 9:46 PM PT | Jan 3, 2030 | Jan 10, 2030 | Jan 3 – Jan 9 |
| May 6, 2030 1:15 PM PT | Apr 29, 2030 | May 6, 2030 | Apr 29 – May 5 |
| Sep 8, 2030 2:28 AM PT | Sep 1, 2030 | Sep 8, 2030 | Sep 1 – Sep 7 |
| Dec 25, 2030 1:15 PM PT | Dec 18, 2030 | Dec 25, 2030 | Dec 18 – Dec 24 |
| Apr 18, 2031 4:16 AM PT | Apr 11, 2031 | Apr 18, 2031 | Apr 11 – Apr 17 |

If App Store Connect isn't charging $9.99, the app shows the regular price and no offer, even inside a Mercury window.

**How the app decides to show "LAUNCH OFFER" / "MERCURY OFFER" and the crossed-out $19.99** — all must be true, otherwise the plan shows StoreKit's price with no promotion:
- the current time is within the launch window (a configured start, 14 days) or a Mercury window (7 days before a verified direct station); it ends by itself, no update needed;
- the person's storefront is one the promotion lists (US only), in the listed currency (USD);
- StoreKit's actual Lifetime price for that storefront is exactly the configured promotional price ($9.99).

During the offer the Lifetime card shows a "LAUNCH OFFER" badge (instead of "BEST VALUE"), $19.99 crossed out beside StoreKit's $9.99, and "Launch offer ends <last day>.": the last full day before the regular price returns, on the Pacific calendar (a Dec 1 start reads "ends Dec 14"). The offer is the same for everyone (a scheduled App Store price, not a per-person offer); it starts at the public launch and lasts 14 calendar days. The price the person pays and sees is always StoreKit's. The app never hardcodes it, and never assumes a discount just because the price happens to be $9.99. To extend the special to other countries, add each storefront's currency, regular and promotional price to `LaunchPromotion.launch.prices` and schedule the matching price change in App Store Connect.

### Before Sandbox testing (on your iPhone)
Done: legal entity decision (individual for now), Paid Apps Agreement, bundle ID, both products.
Still to check or do:
1. **Billing Grace Period:** confirm it's on (16 days) and which renewals it covers.
2. **Product metadata:** each product has an English display name and description; the group "Retrograde Premium" has a display name.
3. **Users and Access → Sandbox → Test Accounts:** create one or two testers with unused email addresses (a US tester sees the first-year offer and the Lifetime launch badge while they're active; a tester in a country without the offer sees the regular price only).
4. **On the iPhone:** Settings › Developer › Sandbox Apple Account → sign in with a tester. Run from Xcode with your team selected, using the **Retrograde (Sandbox)** scheme (no StoreKit configuration file).

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
