# RETROGRADE — Executive Summary & Development Brief

**Version:** 1.0  
**Date:** November 2, 2026  
**Status:** Pre-development — product definition  
**Purpose:** Product source of truth for Claude Code implementation, used with the approved Figma mockups.  
**Figma:** https://www.figma.com/design/yYMmVuIbzEqQ6ZjjrGc66P/Retrograde-App?node-id=0-1

## 1. Executive Summary

**Retrograde** is a playful, reassuring astrology-inspired iOS companion that helps users navigate planetary retrograde cycles through a countdown, daily astrological context, and practical activities. The initial release focuses on **Mercury retrograde**. The architecture should accommodate additional planets and planet-specific experiences later.

Three product pillars:
1. **Understand the cycle:** Mercury's status, countdown, and retrograde progress.
2. **Navigate each day:** Calendar of daily intensity, astronomical influences, and suggested habits.
3. **Take practical action:** Interactive, cycle-specific Survival Kit tasks.

Retrograde uses a **freemium subscription** model at launch. Free users receive the countdown and widget, the first task in each Survival Kit section, and detailed calendar insights for a rolling four-day window. Premium unlocks all tasks and full calendar insights. No mandatory app account is required at launch.

Longer term, Retrograde may participate in a shared pricing/membership offering with other independently developed apps, potentially including **Between Lines**.

## 2. Vision and Product Principles

**Positioning:** Your cosmic reality check — a playful guide to slowing down, reflecting, and handling everyday life with more intention.

**Brand language:** “A little chaos. A lot of backup.”

- Playful, not fatalistic or alarmist.
- Actionable, not passive: pair insights with useful habits.
- Reassuring, not anxiety-inducing.
- Simple enough for casual astrology followers.
- Privacy-conscious and low-friction.
- Astrology is a **reflection prompt, not a prediction**. Do not present intensity as an objective scientific measurement.

## 3. Audience

Casual astrology followers, people curious about Mercury retrograde, and users who enjoy practical self-care, reflective habits, and engaging daily guidance. No prior astrology knowledge should be required.

## 4. Launch Features

### 4.1 Overview — Mercury Dashboard

- Display Mercury's current retrograde/direct status.
- Countdown to the next relevant transition and visual progress through the current cycle.
- Clear, playful explanation of Mercury retrograde.
- Communication, technology, and planning guidance.
- Navigation to the Survival Kit.
- **Add to Home Screen** launches the flow for adding a **real iOS Home Screen widget** displaying status, countdown, and progress without opening the app. Follow iOS widget refresh constraints; tapping opens the app.

### 4.2 Survival Kit

Four Mercury categories in the Figma designs:

1. **Communication:** thoughtful messaging, clarity, drafting, and pauses.
2. **Tech Backup:** backups, device preparedness, and information security.
3. **Flexible Planning:** confirmations, buffers, and contingency plans.
4. **Journal:** reflective prompts and small wins.

**Task interaction:** User selects an unlocked task → dedicated task experience opens → user completes or engages with activity → taps **Mark as done** → returns to Survival Kit list with that task checked. Completion persists across app restarts.

Task experiences may include guided breathing (timer), a 10-second pause timer, copyable messages, checklists, and reflection prompts. Journaling tasks direct users to their own Notes, WhatsApp, or other appropriate app; **do not store journal entries in Retrograde**. A copy prompt/share-sheet action may be offered where helpful.

**Cycle-aware model:** Tasks belong to a specific planetary cycle. Plan for other planets with their own categories, task sets, and completion state. Whether task completion resets with each new Mercury retrograde period remains to be decided.

### 4.3 Calendar

- Browse the entire supported calendar, including dates outside the free window.
- Show Mercury Rx/direct markers, overlapping planetary retrogrades, and lunar cycles.
- Show a **visual daily intensity cue** for all dates, including locked dates.
- Four intensity levels: **Calm, Mild, Elevated, Intense**.
- For unlocked dates: display intensity details, astrological influences, plain-language interpretation, and a practical habit.
- **Verified astronomical data** is required for retrograde events and moon cycles; never ship invented demo dates as factual data.
- Investigate licensed third-party astronomy/astrology data and editorial resources before implementing an intensity system. The four-level rating is interpretive; document any mapping or editorial methodology. Avoid inventing a complex astronomical calculation engine unless necessary.

### 4.4 Notifications

Optional alerts, configurable in-app:

- Mercury retrograde begins/ends.
- Advance reminders before Mercury retrograde begins/ends.
- New Survival Kit tasks.
- Reminders for incomplete tasks.

Respect iOS notification permission, user preferences, and duplicate prevention. Exact lead times and frequencies are open decisions. Figma notification screens are designs, **not evidence of functioning implementation**.

### 4.5 Onboarding

Intended first-launch sequence:

1. Brand/launch animation: **Mercury moves from right to left** across the screen.
2. Notification explanation and optional permission prompt.
3. Premium paywall with an attractive introductory offer and clear **Continue free** option.
4. Overview.

No mandatory app account or account page at launch. Support Reduce Motion and avoid repeatedly presenting first-run onboarding after completion.

### 4.6 Sharing

Support the Figma sharing experience inviting users to share the app. No social network or in-app community is part of launch scope.

## 5. Free and Premium Entitlements

| Capability | Free | Premium |
|---|---|---|
| Mercury overview, status, countdown | Full | Full |
| iOS Home Screen countdown/progress widget | Yes | Yes |
| Survival Kit | **First task in each of 4 sections** | **All tasks** |
| Persistent task completion | Yes, accessible tasks | Yes, all tasks |
| Calendar browsing | All supported dates | All supported dates |
| Calendar visual indicators/intensity cues | Visible for all dates | Visible for all dates |
| Detailed calendar insights | **Rolling today + next 3 days** | **All supported dates** |
| Mercury notifications | Yes | Yes |
| Other planets | Not at launch | Future roadmap, packaging TBD |

**Free calendar access is rolling, not a one-time trial.** Example: on November 2, insights are available for November 2–5; on November 3, for November 3–6. Past dates and dates beyond the rolling window remain browseable, with visual activity/intensity cues but no detailed interpretation. Locked-date selection should offer a contextual Premium upgrade.

**Locked Survival Kit tasks** remain visible, dimmed or blurred, with a lock cue. Tapping one opens an appropriate Premium upsell. Premium subscribers see all tasks.

### 5.1 Subscriptions

- Premium available at **initial App Store launch**.
- Use **Apple In-App Purchases / StoreKit** for subscriptions and entitlement checks.
- Consider monthly and annual plans; **prices not yet decided**.
- Present a clearly described introductory offer after notification onboarding. The offer's eligibility, price, and duration are not yet decided.
- Include purchase restoration, entitlement updates, expiry/cancellation handling, subscription management, and required legal disclosures.
- Free access must remain available when the paywall is dismissed.
- Keep pricing and entitlement logic configurable, not hardcoded into UI.

### 5.2 Future Cross-App Pricing

Future pricing could include individual subscriptions, portfolio membership, cross-app discounts, or bundles with apps such as **Between Lines**. **Do not build a multi-app billing system for launch.**

Design entitlement checks as a layer separate from UI, with concepts such as `retrograde.premium` and possible future portfolio entitlements. **Do not assume** a subscription purchased in one standalone App Store app automatically unlocks another; verify Apple policies, subscription group limitations, shared identity, and backend requirements before planning cross-app billing.

## 6. Identity, Persistence, and Privacy

- **No mandatory Sign in with Apple** or Retrograde account at launch. Apple Account billing through StoreKit is distinct from app sign-in.
- Store task completion, onboarding state, and preferences locally.
- Use appropriate shared storage for widget data.
- No in-app journal entry storage.
- Premium purchase restoration through Apple purchase infrastructure.
- Future roadmap: optional Sign in with Apple, cloud sync, account management, and shared entitlements across apps.
- Recognize that local progress may not automatically transfer to another device before sync is introduced.
- Prepare privacy policy and App Store privacy disclosures.

## 7. Navigation and Screen Inventory

**Three primary destinations from Figma:** Overview, Survival Kit, Calendar.

Supporting flows: launch animation, notification prompt/settings, Premium paywall, task details, app sharing, subscription management and restore purchases, legal/support information.

**Figma is the visual source of truth** for layout, typography, colors, components, and interaction patterns. This brief is the source of truth for functional behavior and commercial access rules. Flag contradictions and missing states; do not invent extra tabs or account screens.

## 8. Technical Direction

**Platform:** iOS App Store first. A **SwiftUI-first** approach is a strong initial recommendation given the iOS-only scope, Home Screen widget, notifications, and StoreKit; Claude Code should validate the choice during technical discovery rather than assume it is settled.

**Suggested workflow:** Claude Code in VS Code for coding and reviews, Xcode for simulator, signing, widget/native integration, device testing, and submission. Both use the same project directory.

**Architecture:** Separate UI/presentation, planetary cycles, astronomical data, editorial daily insights, Survival Kit definitions, interactive task experiences, completion persistence, calendar access control, subscription entitlements, notifications, and widgets. Avoid coupling all features directly to Mercury so additional planets can be added later.

**Data:** Keep verified astronomical event records separate from interpretive copy and daily intensity methodology. Define data coverage, timezone behavior, source attribution/licensing, update strategy, caching, and missing-data states.

**Quality:** VoiceOver, accessible contrast/tap targets, reduced motion, date/timezone edge cases, offline handling, durable task progress, reliable purchase restore, and notification scheduling.

## 9. Acceptance Criteria for Initial Release

### Overview and Widget
- Correct Mercury status, transition countdown, and progress based on verified data.
- Native Home Screen widget displays countdown/progress and opens Retrograde.

### Survival Kit
- Four Mercury categories with first task free and remaining tasks visibly locked.
- Each unlocked task opens the corresponding experience.
- **Mark as done** returns to list with checked state.
- Completion persists across restarts.
- Premium unlocks all tasks.

### Calendar
- All supported dates browseable.
- Free detailed insights limited to **today plus the next three days**, rolling daily.
- Locked dates retain meaningful visual activity/intensity indicators.
- Premium unlocks all available detailed insights.
- Astronomical events sourced from verified data; intensity methodology documented.

### Premium
- Introductory paywall appears in onboarding and can be skipped.
- Purchase, restore, entitlement update, renewal, and expiry behavior tested.
- Locked features update correctly after purchase.

### Notifications
- Permission request optional; settings saved; enabled alerts scheduled; disabled alerts not sent.

### Onboarding
- Right-to-left Mercury animation, notification prompt, Premium offer, and Overview in intended sequence.
- No required account creation; onboarding completion persists.

## 10. Development Phases with Claude Code

**Phase 1 — Discovery (no production code):** Inspect Figma and brief; compare SwiftUI and React Native/Expo; propose architecture, data models, external sources, native dependencies, testing, risks, and milestones. Request approval before implementation.

**Phase 2 — Foundation:** Project/repository, design system and navigation, local persistence, verified Mercury data.

**Phase 3 — Core experience:** Overview, Survival Kit, interactive tasks, completion, Calendar, free content gating.

**Phase 4 — Monetization and native integration:** StoreKit Premium/paywall, notifications, Home Screen widget.

**Phase 5 — Polish and launch:** Animation, visual QA against Figma, accessibility, device testing, TestFlight, App Store assets/disclosures, review submission.

**Working agreement:** For each phase, review requirements and mockups → propose approach → flag assumptions → implement a small testable increment → run tests → summarize changes and open questions → await review before major changes.

## 11. Open Decisions and Dependencies

| Topic | Open item |
|---|---|
| Stack | Confirm SwiftUI vs alternatives after technical discovery |
| Astronomical sources | Verified provider, license, coverage, updates |
| Daily intensity | Third-party editorial source or documented lightweight mapping |
| Pricing | Monthly/annual prices and introductory discount terms |
| Task lifecycle | Completion reset/archive behavior across Mercury cycles |
| Notifications | Lead times, task reminder cadence, scheduling logic |
| Calendar | Historical/future coverage and offline caching |
| Widget | Supported sizes, final UI, refresh strategy |
| Publishing | Individual vs organization Apple Developer account |
| Legal | Privacy policy, terms, subscription disclosures |

## 12. Post-Launch Roadmap

- Other retrograde planets and planet-specific Survival Kits.
- Optional user accounts, Sign in with Apple, cloud synchronization.
- Personalization and user-selected planetary interests.
- Portfolio membership, cross-app discovery, and possible bundles with **Between Lines** or other future apps, subject to App Store and identity architecture feasibility.

---

## Final Product Definition

**Retrograde is an iOS astrology-inspired companion focused initially on Mercury retrograde. It combines an interactive cycle countdown, a daily astrological calendar, and a practical Survival Kit. Users access essential features free; Premium unlocks the complete task library and detailed calendar insights.**

The initial release should be polished, playful, and low-friction, without mandatory account creation. Build for future planets and possible cross-app subscription models without implementing speculative complexity at launch.

**Source-of-truth rule:** This brief defines product intent and functional requirements; approved Figma mockups define the intended visual experience. Resolve contradictions explicitly before coding.
