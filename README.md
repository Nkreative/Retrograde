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
| `  DesignSystem` | Figma colours, type ramp (Archivo Black, Space Mono, Inter — bundled, SIL OFL), icons, header, buttons, cards, tab bar. Debug builds show a review catalog when launched with `-catalog 1` (2, 3); `-tab survivalKit` opens a tab; `-now 2026-10-10T12:00:00Z` pretends it's that moment (to review other Mercury stages); `-entitlement free|yearly|lifetime|lifetimeAndYearly|expiredYearly|gracePeriod|billingIssue` sets a throwaway Premium state (`-premium YES` = lifetime); `-entitlementSource simulated` uses the persistent simulator with `-simulatorScript "buyYearly@5,expireYearly@10"` for timed actions; `-openSettings YES` opens Settings (`-scrollSettings about`, `-settingsPath notifications|terms|privacy|support`); `-openNotifications YES` opens the Notification Center (`-sampleNotifications YES` fills it with sample entries); `-notificationAuth denied|allowed|notDetermined` fakes the permission status; the Premium simulator is in Settings › Developer; `-markDone <id,id>` ticks tasks; `-openTask <id>` opens a task; `-scrollKit bottom` opens the kit scrolled to the end; `-autostartTimer YES` starts task timers on open; `-expandSections all` (or `communication,journal`) expands kit sections; `-showPaywall YES` opens the paywall (`-scrollPaywall bottom` scrolls to the plans); `-promotionPreview YES` previews the Lifetime launch special (a window starting yesterday, simulator price $9.99); `-onboarding reset|skip` replays or skips first-launch onboarding; `-selectDay 2026-11-13`, `-calendarExpanded YES` and `-scrollCalendar detail` for the Calendar. |
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

Open `Retrograde.xcodeproj` in Xcode to run on a simulator or device. Signing uses your Apple Developer account (set the Team under Signing & Capabilities).
