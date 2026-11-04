# Decisions since the product brief

Resolves the open items in PRODUCT_BRIEF.md §11. Newest first.

## 2026-11-04 (M9b paywall)

- **Live StoreKit paywall:** prices, billing period and the free trial come from StoreKit for the person's storefront (`PlanOffer`); the trial appears only when the storefront has an introductory offer *and* StoreKit says the person is eligible — otherwise Yearly reads "Renews yearly. Cancel anytime." with no trial wording. Wording is generated from those values (`PaywallCopy`), never hardcoded amounts.
- **Disclosure under the button** follows the selected plan: Yearly with trial — free period, then price and frequency, charged when the trial ends, auto-renews unless cancelled 24 h before, how to manage; Yearly without trial — price per year at confirmation, same renewal terms; Lifetime — one-time payment, no renewal.
- **States** (`PurchaseFlow`): loading (placeholder cards), unavailable (retry, purchase disabled), purchasing (button "Processing…", all actions blocked so a second tap can't start another purchase), pending approval, purchase failed, restore failed, nothing to restore. Success closes the paywall as soon as Premium is verified, including a later Ask to Buy approval.
- **Links:** Terms → Apple's standard EULA. Privacy appears only once `AppLinks.privacyPolicy` is set (debug builds show "PRIVACY (URL NOT SET)" as a reminder; release builds hide it).
- **Scheme:** the shared scheme's `-now` argument is kept but off; tick it in Scheme › Arguments to test a date.

## 2026-11-03 (M9 decisions & M9a StoreKit)

- **Products (final):** Yearly `com.nkreative.retrograde.premium.yearly` — auto-renewable, 1 year, US $9.99, 7-day free trial for eligible new subscribers; Lifetime `com.nkreative.retrograde.premium.lifetime` — non-consumable, US $19.99, no trial. Group "Retrograde Premium". Bundle ID `com.nkreative.retrograde`. International availability with Apple's localized pricing; Family Sharing off; billing grace period on (16 days); Apple's standard EULA; dedicated privacy policy and support page (URLs/email configurable placeholders until supplied; never published as placeholders). Lifetime stays the default paywall selection with BEST VALUE.
- **Settings scope (M9c):** Premium status/plan, Restore, Manage Subscription, Request a Refund, notification preferences (stored now, scheduled in M11), methodology, data sources and credits, privacy, terms, support, version. Widgets (M12) and sharing (M13) aren't shown as active until built.
- **Progress:** "X of 27 done" keeps counting completed Premium tasks after a downgrade; completion history is kept across entitlement changes.
- **M9a — StoreKit is the authority:** `StoreKitEntitlementSource` reads only verified transactions (`currentEntitlements`, the Yearly product's latest transaction and its verified subscription status) into an `EntitlementSnapshot`; `EntitlementRules` map it (Lifetime first; grace period = Premium; billing retry, expired, refunded/revoked = not). Apple's dates only. Failed reads keep the last verified snapshot. No app-side cache — StoreKit's on-device signed transactions provide offline access. Unfinished and updated transactions are processed then finished. Details: [STOREKIT.md](STOREKIT.md).
- **Simulator** moved behind an explicit debug switch (`-entitlementSource simulated` or `-entitlement <state>`); compiled out of release builds.

## 2026-11-03 (M8 entitlements)

- **One source of truth:** `EntitlementStore` (Entitlements module) — every screen reads `isPremium` from it (Survival Kit, Calendar, paywall; Settings will in M9). Status is derived from purchase transactions: **Lifetime** (never expires, always wins), else **Yearly** active until its expiry instant, else **Yearly expired**, else **Free**. Both paid plans unlock the same `retrograde.premium` features. Product IDs: `com.nkreative.retrograde.premium.lifetime` / `.yearly` (placeholders until App Store Connect).
- **Persistence:** the device keeps its own record (read at launch); the App Store account is the source for Restore. In M8 the account is simulated (debug only); M9 swaps in StoreKit with no change to screens or rules.
- **Downgrade keeps progress:** task completion lives separately per cycle; Premium-only ticks are hidden while locked but stay counted and reappear on upgrade.
- **Production builds:** no purchase account (always Free until M9); the simulator view, its storage and all `simulate…` functions are compiled out (verified by searching the Release binary).
- **Debug tools:** gear button opens the Premium simulator (until Settings in M9); launch arguments `-entitlement free|yearly|lifetime|expiredYearly` (throwaway state), `-simulatorScript "buyYearly@5,expireYearly@10"` (timed actions on the persistent simulated account), `-openSimulator YES`.

## 2026-11-03 (M7 day access)

- **One access rule per day** (`DayDetailContent`): an unlocked day (free window or Premium) shows every detail section — summary, events, habit and other planets in retrograde; a locked day shows none of them, only the single locked panel with "Unlock every day". Date, level and calendar markers are always visible. No separate per-section Premium checks or teasers.
- **Header count label** reads "5 Retrogrades" (singular "1 Retrograde"), Mercury included, for the selected date; it drops to its own line if the month row is too narrow, never shrinking.

## 2026-11-03 (M7 Calendar simplification)

- **Calendar card simplified:** removed "DAILY INTENSITY · CALMER → MORE CHALLENGING" and the "also retrograde this month" chips. Day cells keep their four intensity bars; the full scale stays in Selected Day.
- **Retrograde count badge** beside the month/year (label refined in "M7 day access").
- **Other planets in retrograde** moved into Selected Day, under the insights and habit: planets other than Mercury retrograde *on that date*, with their retrograde dates (access refined in "M7 day access"). The header count stays visible to everyone.
- **Collapsed strip starts today:** seven days from today (weekday letters follow those days), stepping forward in blocks of seven; it can't go back before today, so there are no gaps. The expanded month view keeps full history and past-day selection; collapsing with a past day selected returns to today's strip and keeps the selection. Free/Premium access unchanged.

## 2026-11-03 (M7 Calendar)

- **Editorial approved with changes:** tags renamed (RETROGRADE, TURNING POINT, NEAR STATION, SHADOW, MOON PHASE, SIGN CHANGE); gentle tone on Intense days; 8 habits per level across communication, technology, planning and reflection; predictive phrasing removed (e.g. turning direct: "Mercury's apparent backward motion ends today. A good moment to revisit what you've been putting off."). Rules and tone in [editorial/DAILY_INSIGHTS.md](editorial/DAILY_INSIGHTS.md); enforced by tests.
- **Calendar:** week strip by default, Expand/Collapse to the full month; arrows (and swipe) move by week or month within 2025–2030. Weeks start on the person's locale first weekday (Figma showed Sunday). Each day: Rx/Sh/D, four intensity bars, moon icon on primary phases, today dot, lock when details are Premium. Context line shows the month's Mercury retrograde or the next one. (Simplified after review — see above.)
- **Day detail:** level and four-step scale for every day; summary, events and habit for unlocked days. Free: today + next 3 days (local, rolling). Locked future days say when they become free ("Come back Nov 10"); past days point to Premium; "Unlock every day" opens the paywall.
- **Outside 2025–2030:** days show no markers or level, the detail says the sky isn't mapped yet, and if today is past 2030 a note asks to update the app.

## 2026-11-03 (M7 methodology)

- **Daily intensity v1 provisionally approved:** points and four levels as in [INTENSITY_METHODOLOGY.md](INTENSITY_METHODOLOGY.md). Mercury shadow days stay +1. Eclipses deferred. Tropical zodiac for sign changes; days assigned in the person's local time zone. Versioned (`methodologyVersion = 1`), deterministic, framed as a reflection score, not a prediction.
- **Editorial copy** reviewed and approved with changes (see M7 Calendar).

## 2026-11-03 (Overview artwork)

- **Approved "cosmic chaos" artwork** replaces the Overview hero (asset `OverviewHero`, 1774 × 887 JPEG). Shown whole at 2:1 so the girl, tangled orbits and all floating icons stay in frame; the stage headline stays live text in a dark band above it that blends into the artwork's night sky. The paywall keeps its own separate artwork.

## 2026-11-03 (paywall artwork)

- **Approved Premium artwork** (girl silhouetted against the moon) is the paywall hero — now in the preview and for the final StoreKit paywall in M9. Asset `PaywallHero` (1199 × 1312, JPEG). Shown edge to edge, scaled to screen width (never stretched), positioned so the whole moon, the girl and the icons sit below the status bar; the empty foreground is cropped and both edges fade into the background. The close button is pinned top-right with a dark backing so it's always reachable. The layout adapts to screen height (artwork window 0.86 × width on tall phones, 0.78 on shorter ones, tighter spacing) so both plans and the purchase button are visible without scrolling on iPhone 18 Pro Max and 17e; Continue free and the legal text may need a short scroll.

## 2026-11-03 (M6 refinements)

- **Locked tasks open Premium** (replaces the earlier "locked rows do nothing"): tapping any locked or blurred task, or the "23 more tasks in Premium" card, opens the paywall. Until M9 it's a preview built from the approved paywall (Lifetime default, BEST VALUE, Yearly alternative); the buy button is inactive. Access rules unchanged.
- **Collapsible sections:** every section starts collapsed showing its first three tasks, with an "Expand · N more" / "Collapse" pill (the calendar's pill style) at the bottom of the card. Sections toggle independently; expanded shows all tasks including locked/blurred ones. Same for Premium. Reduce Motion turns the animation off.
- **Kit progress is green:** bar, marker and "X of 27 done" use mint `#52E3A4` (11.6:1 on the background). Mercury's cycle bar stays pink.

## 2026-11-03 (M6)

- **Task screens:** all 27 tasks use their Figma content via seven reusable experiences — breathing timer (1), pause timer (1), numbered steps (10), tick-off checklist (5), copyable message (3, including Ask for clarity's highlighted box), journal prompt (7). Content lives in `SurvivalKit/MercuryTaskGuides.swift`.
- **Timers:** Start → Pause/Restart → Resume/Restart → Restart when finished; a soft haptic plays once at zero. "Mark as done" works at any time. Breathing highlights the current breath with a live count; its disc grows/shrinks with the breath unless Reduce Motion is on.
- **Copy:** "Copy message" added to the two example-message tasks too (Figma had it only on Ask for clarity) for consistency. A brief "Copied" confirmation shows and is announced to VoiceOver.
- **Journal:** Copy prompt + Open in… (iOS share sheet). Nothing typed is stored; the app never sees it.
- **Checklist ticks** are for the moment only (not saved); "Mark as done" is what's recorded.
- **Large text:** content scales fully; the header and tab bar stop growing at the xLarge size (like system bars), and tab labels support press-and-hold to enlarge.
- **Journal icon:** notebook (`book.closed`) replaces the duplicate speech bubble.

## 2026-11-03 (M5)

- **Overview refinements (approved):** "YOU ARE HERE" follows the progress marker and, at either end of the bar, replaces that end's label. The direct stage shows no day count, just the countdown to the next retrograde. Pre/post-shadow copy and the direct countdown target are approved.
- **Survival Kit visibility:** free = first task per section unlocked, next two shown locked (40 % opacity + lock), the rest also blurred; (superseded: locked rows now open Premium, see M6 refinements). Premium = all unlocked, no nudge card. Rule values live in `TaskAccessPolicy.launch`.
- **Completion per cycle:** each "Mark as done" is stored on the device against the retrograde it belongs to (`mercury-2026-10-24`). The kit switches to a fresh, empty cycle the moment the next retrograde begins; earlier cycles' history is kept. "X of 27 done" counts the current cycle.
- **Kit progress bars** (refined after review): two separate groups 18 pt apart, each bar with its labels underneath — pink cycle bar with a pink "Day 11 of 21", yellow kit bar with a yellow "2 of 27 done"; smaller 9 pt markers. Labels stay centred because they are counts, not positions.
- **Task row icons:** checkbox and lock share a 16 pt slot, drawn at the same visible size (13 pt), centred on the first line of text; unlocked rows are tappable edge to edge.
- **Tab bar** sits below the scrolling content rather than over it, so the last card is always fully visible.
- **Journal icon** matches Figma (same speech bubble as Communication) — flagged in case it was a placeholder.
- **Until M9:** Premium is off except in debug builds launched with `-premium YES`; the "23 more tasks in Premium" card doesn't open anything yet. Task screens show a placeholder body until M6.

## 2026-11-03 (M4)

- **Overview stages:** pre-shadow → retrograde → post-shadow → direct, each with its own countdown and bar:
  pre-shadow counts to the retrograde ("days till the slowdown", PRE-SHADOW → RETROGRADE); retrograde counts to direct ("days to exhale", RETROGRADE → DIRECT); post-shadow counts to the shadow's end ("days till the dust settles", POST-SHADOW → ALL CLEAR); direct counts to the next retrograde ("days till the next plot twist", DIRECT → NEXT RX). On the target day the number becomes "TODAY".
- **Shadow-stage screens** reuse the approved Overview layout (per the Figma note); their copy is new and lives in `Packages/RetrogradeKit/Sources/Editorial/OverviewCopy.swift` for review.
- **Narrow phones:** if the countdown and day label don't fit on one line, the day label moves underneath.
- **Not yet wired:** "Add to Home Screen" (M12) and the header buttons (Share M13, Notifications M11, Settings M9).

## 2026-11-03 (M3)

- **Typography:** Figma fonts bundled — Archivo Black, Space Mono (Regular, Bold), Inter 4.1 (Regular, SemiBold, Bold); SIL Open Font License, licence files in `DesignSystem/Resources/Fonts`, to be credited in Settings. Sizes scale with Dynamic Type.
- **Icons:** SF Symbols for standard interface icons; the logo and all three tab-bar icons are drawn from the Figma vectors so the tab bar stays one consistent set (SF's nearest symbols differ in weight and shape). No Font Awesome dependency.
- **Header on narrow phones:** at Figma's 430 pt width the header matches exactly; below that the three buttons shrink 40 → 36 pt and the wordmark may scale slightly rather than wrap.

## 2026-11-03

- **Paywall plans:** Lifetime access (one-time purchase, "BEST VALUE", selected by default, button "Get lifetime access") and Yearly subscription (intro offer, button "Start Premium"). No monthly plan. Custom paywall on StoreKit 2 (Apple's subscription-only screen can't show a one-time purchase). Premium = active yearly **or** lifetime owned. ✕ visible immediately; "Continue free" always available.
- **Free Survival Kit:** per section, first task unlocked, next two shown locked as a preview, rest blurred. Locked/blurred tasks are not tappable; the "23 more tasks in Premium" card leads to the paywall.
- **Progress:** "X of 27 done" counts tasks marked done in the current cycle's kit, for free and Premium users.
- **Calendar:** one toggle — "Expand" (week → month) / "Collapse" (month → week).
- **Header:** share, bell (Notifications), gear (Settings) on every screen. Settings sheet holds plan, Restore purchases, Manage subscription, help and legal links. No account page.
- **Bundle ID:** `com.nkreative.retrograde` (placeholder until confirmed; changeable before first App Store upload).

## 2026-11-02

- **Stack:** SwiftUI, iOS 17 minimum, dark mode only.
- **Task completion** resets when each new Mercury retrograde begins.
- **Notifications:** when Mercury turns retrograde / direct; "before" alerts 2 weeks and 3 days ahead of each; unfinished-task reminders every other day.
- **Data:** NASA JPL Horizons + USNO, 2025–2030; shadow periods in scope (needed for future planets).
- **Intensity:** in-house, documented rule-based rating; editorial copy written in the app's voice (see M7 methodology above).
- **Apple Developer account:** individual.
- **Process:** any screen not in the approved Figma must be drawn on the Figma review page and approved before it is built.
