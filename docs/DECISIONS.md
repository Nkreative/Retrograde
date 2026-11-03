# Decisions since the product brief

Resolves the open items in PRODUCT_BRIEF.md §11. Newest first.

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
- **Intensity:** in-house, documented rule-based rating; editorial copy written in the app's voice.
- **Apple Developer account:** individual.
- **Process:** any screen not in the approved Figma must be drawn on the Figma review page and approved before it is built.
