# Decisions since the product brief

Resolves the open items in PRODUCT_BRIEF.md §11. Newest first.

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
- **Intensity:** in-house, documented rule-based rating; editorial copy written in the app's voice.
- **Apple Developer account:** individual.
- **Process:** any screen not in the approved Figma must be drawn on the Figma review page and approved before it is built.
