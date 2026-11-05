# Decisions since the product brief

Resolves the open items in PRODUCT_BRIEF.md §11. Newest first.

## 2026-11-05 (M13 sharing)

- **Share Retrograde, two ways in:** the header's share button opens Figma's approved "Invite someone who needs this" screen (synthwave artwork, "The same cosmic vibes, minus the awkward small talk.", Share Retrograde button, "Just the app. Your entries stay yours."); the new Settings row "Share Retrograde" (in the "General" section, as in the Settings mockup; "Alerts" renamed to match) opens the iOS share sheet directly.
- **What it sends:** "I’m getting through Mercury retrograde with Retrograde. The same cosmic vibes, minus the awkward small talk." plus the App Store link. **Release blocker:** the link isn't known yet. `AppLinks.appStore` is nil until App Store Connect assigns the app's Apple ID (`https://apps.apple.com/app/id<Apple ID>`); until then only the message is shared (never a made-up link) and App Store archives fail with an error (build phase "Require release links", alongside the privacy policy check).
- **Share this day:** an outlined "Share this day" button ends every unlocked day's detail on the Calendar, for the day being viewed (today or any other). It opens a preview of the card, then the share sheet. Locked days have no button: a card would show Premium details. Free users share every day they can see — no paywall.
- **The card** (new, not in Figma): 1080 × 1350 px (4:5 portrait), the app's night sky with a soft pink/mauve glow, the brand mark and wordmark small at the top, the date with the year, the level ("Elevated", 03 / 04 and the four bars), the day's summary, the good habit in its wine card, and the Calendar's own line "Intensity is an astrology-inspired reflection score built from verified sky events, not a prediction." All words are the Calendar's (`DailyInsightCopy`), nothing new. Fixed text sizes so it reads the same anywhere; a test lays out every distinct card in 2025–2030 (107) and checks it fits (tallest 403 of 480 pt).
- **Text alternative:** the image is shared with the same words as text (date, intensity, summary, habit, "— Retrograde", and the App Store link once set), for apps that take text; VoiceOver reads the preview the same way.
- **Sharing history** (`SharingActivity`, for the future Overview section): one entry per share the person finished — iOS's share sheet reports "completed" when they sent, posted, copied or saved — with what was shared (the app, or a day's insight and its date) and when. A cancel or failure isn't recorded. iOS doesn't say who received anything or whether it arrived, so the history doesn't claim either; it keeps no destination app, contacts or recipients. On the device only (UserDefaults), at most 200 entries. Not shown anywhere yet.

## 2026-11-04 (M12.1 readability)

- **Type scale raised** after testing on an iPhone (headings, numbers and buttons keep Figma's sizes): body copy 12 → 15 pt (Inter, ~135 % line height), row titles 13 → 15, task instructions 13 → 16, eyebrows/tab labels 10 → 12, small labels 9 → 11, pill and badge labels 8–10 → 11, countdown label 11 → 13, fine print and purchase terms 10–11 → 12, the smallest captions 8 → 10. Nothing in the app is under 10 pt. Every screen uses the shared styles (no raw font names left).
- **Calendar:** day numbers 13 → 16 pt, Rx/Sh/D 8 → 10, lock 6 → 8, Moon 7 → 9, intensity bars 6×3 → 7×4; arrows 44 × 44 tap areas. Cells stop growing past XXXL text (seven must share a row); VoiceOver reads each day in full.
- **Day details:** "What's shaping the day" text 11 → 15 pt (titles 12 → 15), other planets 11–12 → 15, the good habit's title 11 → 16 and its text 11 → 15 (after iPhone review; 16 felt as loud as the title) in full-strength colour (muted text on the wine card was the weakest contrast). The intensity scale's names give way to the bars alone when large text can't fit them.
- **Survival Kit:** task text 12 → 15 pt, checkbox 13 → 16, every task row at least 44 pt tall to tap; progress labels move onto two lines at large text.
- **Overview:** at accessibility text sizes the headline sits above the artwork instead of over it.
- **Notification Center header:** the system bar centred "Notifications" in the space the buttons left, so the wide "Mark all as read" pushed it right of centre — and that button is too wide to balance on any iPhone. The title and Done now share the top row with the title on the screen's centre; "Mark all as read" sits under them, on the left, only while something is unread (hidden when empty or all read). At large text the title moves under Done rather than overlap it.
- **Widget unchanged:** it has its own pinned styles (`monoBody`, `monoLabel`, `widgetCaption`, `widgetNote`); a test holds its sizes.

## 2026-11-04 (M12 Home Screen widget)

- **One medium widget**, free for everyone, no account (Figma review page: "M12 · Home Screen widget (medium) — four phases"; replaces the earlier medium proposal with intensity + habit for this milestone; small and Lock Screen sizes are not part of M12).
- **Shows** MERCURY, the phase (PRE-SHADOW, RETROGRADE, POST-SHADOW, DIRECT), the Overview's countdown line ("10 days to exhale", "TODAY Mercury turns direct"), the stage's progress bar, the Overview's day label ("DAY 11 / 21", "SHADOW · DAY 3 / 17") and where the bar ends. Direct has no day count (as on the Overview), so the bar's labels "DIRECT … NEXT RX" show instead. Accent per phase: mauve pre-shadow, pink retrograde, soft pink post-shadow, mint direct.
- **No interpretation of its own:** `HomeWidget.WidgetContent` is built from `CycleCalculator`'s status and `OverviewCopy`, the same as the Overview. `CycleStatus.stageEnd` (new) says when a stage hands over; direct hands over to the pre-shadow.
- **Timeline** (`WidgetTimeline`): entries now, at each local midnight and at each exact stage change for the next two days; iOS is asked for a new timeline after the next midnight (about once a day). The second day covers a late refresh. Calendar days come from the person's time zone when the timeline is made; daylight saving is handled by the calendar (a 25-hour day still flips at midnight).
- **Time zone changes:** Retrograde asks iOS to redraw the widget when it sees a clock or time zone change; otherwise the widget catches up at its next daily refresh (worst case: until midnight in the old time zone).
- **No App Group:** the widget reads its own copy of the bundled sky data (the package's resource bundle is embedded in the extension) and has no state shared with the app, so no shared container, permission or capability is needed. Works offline. If the data doesn't cover today, it shows the Overview's "WE’RE STILL MAPPING THIS STRETCH OF SKY." message.
- **Tap** anywhere opens the Overview (`retrograde://overview` via `widgetURL`, closing Settings, the Notification Center or the paywall). The link is delivered by iOS to Retrograde directly; no URL scheme is registered, so other apps can't open it.
- **Dynamic Type:** follows the person's text size up to XXL, then holds (a fixed-size widget can't fit more); long lines shrink slightly rather than truncate. VoiceOver reads one sentence: "Mercury retrograde. 9 days to exhale. Day 12 of 21."
- **Not changed:** the Overview's "ADD TO HOME SCREEN" button still does nothing; its how-to sheet is awaiting review in Figma.

## 2026-11-04 (M11 local notifications)

- **What's scheduled** (`NotificationPlanner`, from the bundled ephemeris and the saved choices; same 6 toggles as the approved Settings mockup — each "before" toggle covers both the 2-week and the 3-day alert, which gives exactly the requested defaults: both before-retrograde alerts on, both before-direct alerts off):

  | Alert | When (person's local time) | Opens |
  |---|---|---|
  | Mercury turns retrograde / direct | the exact moment if 09:00–21:00; earlier → 09:00 that day; later → 09:00 next day. Never before the event. | Calendar on that day |
  | 2 weeks / 3 days before | 09:00, that many calendar days before the event's local day | Calendar on the event's day |
  | New cycle's kit | first 18:00 at or after the kit rolls over (station retrograde) | Survival Kit |
  | Unfinished tasks (off by default) | every other day at 18:00 from the kit's start until the post-shadow ends, only while tasks the person can open remain; the count is the real one | Survival Kit |

- **Copy:** "Mercury’s officially going backward." / "Your cosmic backup plan starts now."; "Mercury’s moving forward again." / "The universe has stopped buffering. Mostly."; "Three days until Mercury acts up." / "Maybe back up your files. Just saying."; "Two weeks until Mercury acts up." / "Plenty of time to get ahead of the chaos."; "Two weeks / Three days until Mercury turns direct." / "Still backward. Still survivable." · "The finish line is in sight. Hang in there."; "Your survival kit is ready." / "A little preparation never hurt anyone."; "Your survival kit misses you." / "3 small moves left this cycle. Pick one."
- **Scheduling** (`NotificationScheduler`): local notifications only. Each alert has a stable id (e.g. `mercury-2026-10-24.retrograde.lead-3d`), used for iOS and the history, so re-runs replace rather than duplicate. Only the soonest 60 alerts within 400 days are scheduled (iOS keeps 64). Nothing in the past. Re-run on launch, every return to the app, time zone / daylight-saving / midnight changes, preference saves, Premium changes, task completion and onboarding completion. Turning a preference off cancels its pending alerts and their future history entries. Nothing is scheduled unless iOS allows notifications (allowed or provisional) — and iOS itself refuses to store alerts without permission. Permission is requested only from onboarding or the explicit "Turn on notifications" button in Settings › Notifications.
- **History and delivery:** an entry is recorded when an alert is scheduled; the Notification Center shows it once its time has passed. It's marked delivered only when iOS confirms it: shown while the app was open, opened by a tap, or still listed among iOS's delivered notifications. iOS gives no record of an alert the person cleared without opening or that Focus held back, so those stay "due" (time passed, delivery unknown), never "delivered". Opening one from iOS marks it read.
- **Taps:** open the Calendar on the event's day or the Survival Kit — with the app open, in the background, or launched by the tap (the destination waits until the main screen appears, including after onboarding).
- **Settings › Notifications:** real iOS status (on, quiet, off, not yet asked) with "Turn on notifications" (not yet asked), "Allow banners and sounds" (quiet) or "Open iOS Settings" (off); re-read on return from iOS Settings. Preferences stay independent of the permission.

## 2026-11-04 (M10 final: launch message and copy)

- **Launch message on the paywall:** "MERCURY’S CLOCKING OUT. PRICES ARE DROPPING." / "Celebrate the end of retrograde with 50% off Lifetime Premium." / "The chaos will return. Your backup stays." — a compact card between the benefits and the plans. It appears only when both hold: StoreKit verifies the Lifetime launch price (the discount shown is the verified one), and the bundled sky data says Mercury is retrograde and turns direct within 7 calendar days (`PromotionMoment`, through the day it turns direct). Otherwise the regular paywall copy alone; the headline "FULL BACKUP, EVERY CYCLE." stays in both.
- **Onboarding secondary button:** "No, I’ll feel it. No need to tell me." (Figma wording, punctuation corrected).
- **Mercury animation:** approved as built (centred stop, fading trail, Reduce Motion still).

## 2026-11-04 (M10 revision: onboarding matches the approved Figma frames)

Replaces the three-screen onboarding and its polish notes in the entry below; the paywall, launch promotion, 3-day trial and progress rules there still apply.

- **Splash** (Figma "Retrograde — title only"): the Figma logo (65 × 68 pt, `SplashLogo`) above "RETROGRADE" (Archivo Black 30), centred on the app background, for about 2 seconds, then a crossfade. No progress dots, copy or buttons. iOS's launch screen uses the same background colour, so there's no flash before it. Shown only while onboarding isn't finished: returning users open straight into the app, with no added delay on launch or when coming back from the background.
- **Notifications screen** (Figma "Get notified!" frames): "GET NOTIFIED!", the Figma explanation, "Turn on notifications" and "No, I’ll feel it. No need to tell me." — the Figma copy, used as the source of truth for wording. Mercury is the Figma planet (the Mercury artwork, cropped and turned exactly as in the mockup). It enters from the upper right, partly off-screen, along the Figma path, slows gradually and stops at the centre of the screen, where it stays (about 3.4 seconds). A soft pink glow traces the last stretch of its path, shortens as it slows and fades out completely after it stops; it stays in Mercury's band, above the text. With Reduce Motion, Mercury appears still at its final position, with no movement or trail. Positions follow the 430 × 932 pt frame scaled to each phone; when text is too large to fit, the screen scrolls with the buttons after the text.
- **Permission:** iOS is asked only when "Turn on notifications" is tapped, and only if it has never asked or delivery is provisional (quiet), which iOS allows to be upgraded once. Already allowed: a single Continue. Denied: Continue plus a line pointing to iOS Settings; never asked again. Either button, or Continue, finishes onboarding. Nothing is scheduled yet (M11).
- **After onboarding:** a crossfade into the app, then the existing paywall once for people who aren't Premium (unchanged purchase code, Lifetime selected, launch promotion when verified, 3-day trial when eligible, Continue free, Restore, terms). Onboarding is complete before the paywall, so quitting at any point after it never shows either again. Quitting during the splash or the notifications screen shows onboarding again on the next launch.
- **Removed:** the three-step navigation, page dots, retrograde-loop diagram, features page and bell illustration. Debug-only replay stays (Settings › Developer, `-onboarding reset`), excluded from release builds.

## 2026-11-04 (M10 onboarding and launch promotion)

- **Polish (before sign-off):** screen 1 opens with the approved logo and wordmark from the Figma splash (`BrandMark` + "RETROGRADE"), fading in gently (fade only with Reduce Motion), above the animation; the caption under the animation is now body size; on tall phones the content is centred so the page stays balanced. Pages fit on one screen when they can; when they don't (small phones, large text) the whole page scrolls with the buttons after the content, so nothing hides behind a pinned footer. Paywall: the promotion line reads "Launch special through <last day>", the last full day on App Store Connect's Pacific calendar, derived from the configured start and duration; the crossed-out regular price has clear space before the launch price.

- **Onboarding** (first launch only): three screens. (1) "Mercury's doing it again." Animated apparent motion: Mercury drifts across a starfield and loops backward; with Reduce Motion the whole path is drawn still. (2) "Less guessing. More preparing." The real Overview hero plus three features: what's coming, the cosmic calendar, the Survival Kit. (3) "No cosmic surprises." with Enable notifications / Maybe later. Back arrow and page dots on screens 2 and 3. Screens 1 and 3 build on the Figma onboarding frames (Mercury moving right to left; notification ask); the copy, screen 2 and the three-step layout follow the M10 request and aren't in Figma yet. Add them to the review page if they should be recorded there.
- **Notification permission:** iOS is asked only when Enable notifications is tapped, and only if it has never been asked. If permission was already given or refused, the screen shows one Continue button and points to Settings › Notifications. Nothing is scheduled yet (M11).
- **Progress** (`OnboardingProgress`, saved on the device): an interrupted onboarding resumes on the same screen; once finished it never replays, including after updates. Onboarding counts as finished *before* the paywall appears, so closing the app on the paywall never brings onboarding or the paywall back. Debug builds can replay it from Settings › Developer or with `-onboarding reset`.
- **Paywall after onboarding:** shown once, right after onboarding, only when purchases are verified as not Premium (it waits up to 3 s for StoreKit; anyone already Premium skips it). "Continue free" always closes it; there is no repeated forced paywall. It's the existing paywall (same purchase code), Lifetime selected by default. Nothing starts a purchase or trial on its own.
- **Lifetime launch special:** 50% off for 14 calendar days from the App Store Connect start date, done as a scheduled App Store Connect price change (see `docs/STOREKIT.md`). The badge ("LAUNCH · 50% OFF", replacing BEST VALUE while it runs), crossed-out regular price and "Launch special until <date>" appear only when an explicit configuration (`LaunchPromotion.launch`: start date, 14 days, US $19.99 → $9.99) matches StoreKit's real price and currency for the person's storefront. Outside the window, in other storefronts or on any mismatch, the plan shows StoreKit's price with no promotion. US only for now. The start date is not set yet, so the promotion is off.
- **Yearly trial: 3 days** (was 7) for eligible new subscribers in the US and Canada. Supersedes the 7-day trial in the M9 entries below; App Store Connect must be updated to match.

## 2026-11-04 (M9c follow-up: Notification Center, preferences, legal pages)

- **Two destinations:** bell → Notification Center (history); gear → Settings. Settings has a Notifications row leading to the preferences page; the toggles no longer sit in Settings itself. A pink dot on the bell marks unread notifications.
- **Notification Center** (`NotificationHistory`, Notifications module): newest first, title/message/time/icon, read and unread, Mark all as read, "You're all caught up." empty state, tapping opens the related Calendar day (month view for past days) or Survival Kit section. Persisted on device. It never invents entries: M11 records each alert it schedules under a stable per-event id (so rescheduling or relaunching never duplicates), entries appear only once their time has passed, and delivery is tracked as scheduled / due (time passed, delivery unknown) / delivered (only when iOS reports it). Sample entries exist only in debug builds (`-sampleNotifications YES`).
- **Preferences** (approved mockup): Mercury — turns retrograde (on), turns direct (on), 2 weeks and 3 days before it turns retrograde (on), 2 weeks and 3 days before it turns direct (off); Survival Kit — new cycle's tasks (on), every other day if unfinished (off). Edited as a draft and saved with Save preferences. Shows iOS permission status without prompting, with Open iOS Settings when denied. The first M9c version's choices migrate (its starts/ends toggles keep their saved on/off; "daily guidance" has no counterpart in the approved set and is dropped). Lead times are one constant (`NotificationKind.leadTimes`) — the request said "2 days"; the mockup and the Nov 2 decision say 2 weeks, which is what's used.
- **In-app legal and support:** Privacy Policy and Terms open in an in-app web page (loading, error, retry, open-in-Safari) — the same destinations from Settings and the paywall; Terms is Apple's EULA. Contact Support is a native page with an email action and copy-address fallback when no mail app is set up, plus the support page if configured. Privacy and Support appear only once configured; nothing is invented.

## 2026-11-04 (M9c Settings)

- **Opening Settings:** the existing header gear (top-right on every screen, approved in M3) opens Settings as a sheet with native navigation; the bell opens it too until M11 gives notifications their own screen. No Settings tab. The debug Premium simulator moved into Settings › Developer (debug builds only).
- **Premium** (`PremiumSummary`, from the shared entitlement store): Free → Upgrade (opens the paywall) + Restore; Yearly → "Renews/Ends <Apple's verified date>" + Manage Subscription + Restore + Request a Refund; Lifetime → "never expires and never renews" + Restore + Request a Refund; Lifetime with a still-renewing Yearly → Lifetime first, a reminder to cancel Yearly separately, Manage Subscription first. Payment problems: grace period keeps Premium with a fix-payment notice; billing retry shows "Yearly paused". Before the first verified read it says "Checking your purchases…" rather than Free; failed reads keep the last verified state. Refund requests appear only with real StoreKit (hidden while the debug simulator is used).
- **Notifications:** Retrograde begins (on), Retrograde ends (on), Daily cosmic guidance (off) — saved locally (`NotificationPreferences`, Notifications module) for M11 to schedule; Settings says alerts arrive in an upcoming update and never asks for permission. The earlier "2 weeks / 3 days before" alerts can be added in M11 on the same model.
- **How it works:** plain-language methodology and data-source/font credits screens.
- **About & Support:** Privacy Policy and Contact Support show only once their URL/email is set in `AppLinks` (debug builds flag "URL NOT SET"; release builds hide them); Terms → Apple's EULA; version and build; footer "Retrograde is operated by NKreative LLC." The App Store seller remains the individual account holder — nothing claims NKreative LLC is the seller.

## 2026-11-04 (M9b refinements)

- **Prices** (final): Inter SemiBold 16 pt, right-aligned, with the frequency inline at 12 pt secondary ("$9.99 / yr"). The price group never wraps internally; for long localized prices or large text it moves as a whole below the plan description, and BEST VALUE drops below "Lifetime access".
- **Button:** Lifetime "Get lifetime access"; Yearly "Start 7-day free trial" when StoreKit confirms an eligible trial, otherwise "Start Premium".
- **Terms under the button:** Inter 11 pt at higher contrast; full trial, price, frequency, auto-renewal and cancellation wording kept; the page scrolls rather than shrinking text.
- **Benefits:** "No ads. No account needed." and "The cosmic details behind each day".
- **VoiceOver:** each plan reads name, Best value (Lifetime only), full price with frequency, trial, and selection state.
- **Privacy Policy gate:** an Xcode build step fails App Store archives while `AppLinks.privacyPolicy` is nil; normal builds are unaffected. Set the real URL (NKreative LLC legal pages) before archiving.

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
