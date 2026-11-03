# Retrograde

A playful iOS companion for Mercury retrograde: countdown, daily calendar and a practical Survival Kit.

- Product requirements: [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)
- Decisions made since the brief: [docs/DECISIONS.md](docs/DECISIONS.md)
- Where the sky data comes from: [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md)
- Designs: [Figma — "Retrograde - DEV handoff new" and "New screens — for review"](https://www.figma.com/design/ZhuAXCczfzx85d3zMGUs9A/Retrograde-updated?node-id=249-2)

## Layout

| Path | What |
|---|---|
| `App/` | SwiftUI app target (iOS 17+). Files added here are picked up by Xcode automatically. |
| `Packages/RetrogradeKit/` | Swift package with the app's logic, testable without the simulator. |
| `  RetroCore` | Planets, retrograde periods, calendar days, cycle status and day markers. |
| `  AstroData` | Loads the bundled, verified `ephemeris.json`. |
| `  Editorial` | Interpretive copy (Overview per cycle stage; daily insights later), separate from the astronomy. |
| `  SurvivalKit` | Kit content per planet (sections, tasks, stable IDs) and free/Premium visibility rules. |
| `  Persistence` | On-device storage (SwiftData) of task completion per retrograde cycle. |
| `  DesignSystem` | Figma colours, type ramp (Archivo Black, Space Mono, Inter — bundled, SIL OFL), icons, header, buttons, cards, tab bar. Debug builds show a review catalog when launched with `-catalog 1` (2, 3); `-tab survivalKit` opens a tab; `-now 2026-10-10T12:00:00Z` pretends it's that moment (to review other Mercury stages); `-premium YES` simulates Premium; `-markDone <id,id>` ticks tasks; `-openTask <id>` opens a task. |
| `tools/ephemeris/` | Script that builds `ephemeris.json` from NASA JPL + USNO, and its checks. |

## Commands

```sh
# Logic tests (fast, on the Mac). Keep build output out of the iCloud-synced Desktop.
cd Packages/RetrogradeKit && swift test --scratch-path ~/Library/Caches/RetrogradeKit-build

# Build the app for the simulator
xcodebuild -project Retrograde.xcodeproj -scheme Retrograde \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build

# Regenerate and verify the sky data (needs internet)
python3 tools/ephemeris/generate_ephemeris.py
python3 -m unittest discover -s tools/ephemeris
```

Open `Retrograde.xcodeproj` in Xcode to run on a simulator or device. Signing uses your Apple Developer account (set the Team under Signing & Capabilities).
