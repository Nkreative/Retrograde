# Retrograde

A playful iOS companion for Mercury retrograde: countdown, daily calendar and a practical Survival Kit.

- Product requirements: [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)
- Decisions made since the brief: [docs/DECISIONS.md](docs/DECISIONS.md)
- Where the sky data comes from: [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)
- How daily intensity is scored: [docs/INTENSITY_METHODOLOGY.md](docs/INTENSITY_METHODOLOGY.md)
- Purchases, testing and App Store Connect setup: [docs/STOREKIT.md](docs/STOREKIT.md)
- Designs: [Figma — "Retrograde - DEV handoff new" and "New screens — for review"](https://www.figma.com/design/ZhuAXCczfzx85d3zMGUs9A/Retrograde-updated?node-id=249-2)

## Layout

| Path | What |
|---|---|
| `App/` | SwiftUI app target (iOS 17+). Files added here are picked up by Xcode automatically. |
| `Packages/RetrogradeKit/` | Swift package with the app's logic, testable without the simulator. |
| `  RetroCore` | Planets, retrograde periods, calendar days, cycle status and day markers. |
| `  AstroData` | Loads the bundled, verified `ephemeris.json`. |
| `  Editorial` | Interpretive copy (Overview per cycle stage; daily insight summaries, event notes, habits), separate from the astronomy. |
| `  SurvivalKit` | Kit content per planet (sections, tasks, stable IDs) and free/Premium visibility rules. |
| `  Entitlements` | Premium status from StoreKit 2 verified transactions (Lifetime, Yearly incl. grace/billing retry/expiry/refund); one shared store. A simulator exists in debug builds only. |
| `AppTests/` | App-hosted tests against Apple's StoreKit test environment (`StoreKit/Retrograde.storekit`). |
| `StoreKit/` | Local StoreKit configuration mirroring the App Store products. |
| `  Notifications` | Notification preferences (with migration) and the on-device notification history; scheduling arrives in M11. |
| `  Persistence` | On-device storage (SwiftData) of task completion per retrograde cycle. |
| `  DesignSystem` | Figma colours, type ramp (Archivo Black, Space Mono, Inter — bundled, SIL OFL), icons, header, buttons, cards, tab bar. Debug builds show a review catalog when launched with `-catalog 1` (2, 3); `-tab survivalKit` opens a tab; `-now 2026-10-10T12:00:00Z` pretends it's that moment (to review other Mercury stages); `-entitlement free|yearly|lifetime|lifetimeAndYearly|expiredYearly|gracePeriod|billingIssue` sets a throwaway Premium state (`-premium YES` = lifetime); `-entitlementSource simulated` uses the persistent simulator with `-simulatorScript "buyYearly@5,expireYearly@10"` for timed actions; `-openSettings YES` opens Settings (`-scrollSettings about`, `-settingsPath notifications|terms|privacy|support`); `-openNotifications YES` opens the Notification Center (`-sampleNotifications YES` fills it with sample entries); `-notificationAuth denied|allowed|provisional|notDetermined` fakes the permission status Retrograde sees (iOS still refuses to store alerts without real permission); `-openNotification calendarDay:2026-11-13|survivalKit` acts as if a notification launched the app; Settings › Developer › Scheduled alerts lists what iOS has pending and sends a test alert; the Premium simulator is in Settings › Developer; `-markDone <id,id>` ticks tasks; `-openTask <id>` opens a task; `-scrollKit bottom` opens the kit scrolled to the end; `-autostartTimer YES` starts task timers on open; `-expandSections all` (or `communication,journal`) expands kit sections; `-showPaywall YES` opens the paywall (`-scrollPaywall bottom` scrolls to the plans); `-promotionPreview YES` previews the Lifetime launch special (a window starting yesterday, simulator price $9.99; add `-now 2026-11-10T12:00:00Z` to see the end-of-retrograde message); `-onboarding reset|skip` replays or skips first-launch onboarding (`-skipSplash YES` opens the notifications screen directly; `-mercuryAt start|middle|end` holds the Mercury animation at that moment; `-onboardingTap enable|later` taps a button after a moment; `-scrollOnboarding bottom` scrolls to its buttons); `-selectDay 2026-11-13`, `-calendarExpanded YES` and `-scrollCalendar detail` for the Calendar; `-openShareInvite YES` opens the header's share screen; `-shareDay YES` opens the share preview for the selected Calendar day (`-exportShareCard YES` writes the card to `tmp/share-card.png` in the app's container); `-presentShareSheet YES` then opens the iOS share sheet, and `-cancelShareSheet YES` closes it after 6 seconds as a cancel (events in `tmp/share-sheet.log`); `-sampleNotifications read|empty` shows all-read or empty history; `-scrollCalendar detailEnd` scrolls to the end of the day detail; `-widgetPreview YES` shows the Home Screen widget at this iPhone's size, today and in each phase (`-widgetOnly DIRECT` for one, `missing` for the no-data state); `-kitStarted YES|NO` shows the Overview dashboard or the kit introduction for this launch only; `-sampleShares YES|empty` fills the Overview's sharing list with sample entries or empties it (in memory); `-scrollOverview kit|today|sharing|bottom` opens the Overview scrolled there; `-openWidgetHowTo YES` opens the widget how-to; `-widgetListed YES|NO` pretends iOS does or doesn't list a Retrograde widget (iOS isn't asked); `-logWidgetPresence YES` writes what iOS lists to `tmp/widget-presence.log`; `-settingsPath widgets` opens Settings › Widgets (`widgetStatus` opens Settings › Developer › Widget status, debug builds: iOS's last widget report and the saved prompt state, with Refresh); `-widgetPreview YES` shows both sizes. |
| `Widget/` | Home Screen widget extension (WidgetKit). `MercuryWidgetView.swift` is also compiled into the app for the debug preview; `RetrogradeWidget.swift` is the extension only. |
| `  Sharing` (package) | What sharing sends (the app invitation; a day's insight card and its text) and the on-device history of shares the person finished. |
| `  HomeWidget` (package) | What the widget shows (`WidgetContent`, from the cycle status and Overview copy) and when it changes (`WidgetTimeline`). |
| `tools/intensity/` | Independent Python check of the intensity rules (yearly distribution must match the Swift tests). |
| `tools/ephemeris/` | Script that builds `ephemeris.json` from NASA JPL + USNO, and its checks. |

## Commands

```sh
# Logic tests (fast, on the Mac). Keep build output out of the iCloud-synced Desktop.
cd Packages/RetrogradeKit && swift test --scratch-path ~/Library/Caches/RetrogradeKit-build

# StoreKit tests (app-hosted, iOS simulator)
xcodebuild test -project Retrograde.xcodeproj -scheme Retrograde \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' CODE_SIGNING_ALLOWED=NO

# Build the app for the simulator
xcodebuild -project Retrograde.xcodeproj -scheme Retrograde \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build

# Regenerate and verify the sky data (needs internet)
python3 tools/ephemeris/generate_ephemeris.py
python3 -m unittest discover -s tools/ephemeris
```

## Testing the notification permission

iOS remembers a person's answer to the notification request per app installation. Retrograde has no switch to reset it, and the simulator tools can't either (`simctl privacy` doesn't cover notifications) — deleting the app is the reset.

1. **Start clean.** In the Simulator, touch and hold the Retrograde icon › Remove App › Delete App. For a completely fresh device: Device › Erase All Content and Settings. From Terminal: `xcrun simctl uninstall booted com.nkreative.retrograde`.
2. **Run** the Retrograde scheme from Xcode. You'll see the splash, then "GET NOTIFIED!".
3. **First request:** tap "Turn on notifications" — iOS's own prompt appears. Nothing asks before that tap.
4. **Granted:** choose Allow. The paywall follows. To see how onboarding treats someone who already allowed, open the gear › Developer › Replay onboarding (debug builds only): it shows a single Continue and iOS doesn't ask again.
5. **Denied:** delete the app (step 1), run again, tap "Turn on notifications" and choose Don't Allow. Replay onboarding: Continue plus "Notifications are off for Retrograde…", and iOS is never asked again.
6. **Skipped:** on a clean install, tap "No, I’ll feel it. No need to tell me.". iOS isn't asked; replaying onboarding still offers "Turn on notifications".
7. **Switching without reinstalling:** iOS Settings › Notifications › Retrograde › Allow Notifications on/off, then Replay onboarding.

`-notificationAuth denied|allowed|provisional|notDetermined` only changes what Retrograde *sees* for review screenshots; it never changes or resets iOS's permission, and iOS won't store alerts without the real one.

## Testing real notifications on an iPhone

Upcoming Mercury events can be weeks away, so a debug build has a test alert. Use a debug build run from Xcode (Release builds don't include the Developer section).

1. **Install fresh:** delete Retrograde from the iPhone, then run it from Xcode on the phone (select your iPhone as the destination, Team set under Signing & Capabilities).
2. **Permission:** go through onboarding and tap "Turn on notifications" → iOS asks once. Choose **Allow**.
3. **What's scheduled:** gear › Developer › **Scheduled alerts** lists what iOS has pending, with dates in your time zone (alerts for the next Mercury events and, if on, kit reminders). Turn an alert off in gear › Notifications › Save preferences, then reopen Scheduled alerts: its entries are gone. Turn it back on: they return, no duplicates.
4. **Delivery and tap (app closed):** in Scheduled alerts tap **Send a test alert in 10 seconds** (it copies the next real alert), then lock the phone. When it arrives, tap it: Retrograde opens on the right Calendar day or the Survival Kit.
5. **App in the background:** send another test alert, go to the Home Screen, tap the banner.
6. **App open:** send a test alert and stay in the app: the banner still shows.
7. **Notification Center in the app:** real alerts appear under the bell once their time has passed (test alerts aren't recorded). Ones you tapped are read; "Mark all as read" clears the dot.
8. **Denied:** delete the app, reinstall, choose **Don't Allow**. Settings › Notifications shows "Notifications are off for Retrograde" with Open iOS Settings; Scheduled alerts shows nothing pending. Turn notifications on in iOS Settings and return: the status updates and alerts are scheduled.
9. **Time zone:** iOS Settings › General › Date & Time › turn off Set Automatically and pick another time zone, return to Retrograde: Scheduled alerts shows the same alerts at the same local hours (09:00 / 18:00, or the event moment).


## Testing the Home Screen widget on an iPhone

1. **Install:** run the Retrograde scheme from Xcode on the iPhone (the widget is built and signed with the app; Xcode creates its identifier `com.nkreative.retrograde.widget` under your team automatically).
2. **Gallery:** touch and hold an empty spot on the Home Screen › Edit › Add Widget › search "Retrograde" › the Mercury widget (medium) › Add Widget. It shows today's phase, countdown, progress and day label, matching the Overview.
3. **Tap:** open Settings in Retrograde (gear), go to the Home Screen, tap the widget: Retrograde opens on the Overview with Settings closed. Repeat with the app fully closed (swipe it away first).
4. **Offline:** turn on Airplane Mode, remove and re-add the widget: it still shows the right phase.
5. **Time zone:** iOS Settings › General › Date & Time › turn off Set Automatically, pick a zone far away (e.g. Tokyo), open Retrograde once, return to the Home Screen: the countdown and day label follow the new local date. Turn Set Automatically back on afterwards.
6. **Text size:** iOS Settings › Display & Brightness › Text Size, try the largest: text grows up to a limit and stays inside the widget.
7. **Midnight / phase change:** the countdown moves at local midnight and the phase flips at the exact moment Mercury changes stage; check the next morning.

Open `Retrograde.xcodeproj` in Xcode to run on a simulator or device. Signing uses your Apple Developer account (set the Team under Signing & Capabilities).
