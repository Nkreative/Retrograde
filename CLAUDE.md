# Retrograde — notes for Claude

- Product rules: `PRODUCT_BRIEF.md`; later decisions override it: `docs/DECISIONS.md`.
- Visual source of truth: Figma file `ZhuAXCczfzx85d3zMGUs9A`, pages "Retrograde - DEV handoff new" (249:2) and "New screens — for review" (251:2). Ignore other pages. Any screen not in Figma goes on the review page for approval before it's built.
- The person owning this project is not a developer: explain choices in plain language.

## Code

- Logic lives in `Packages/RetrogradeKit` (no UI there); the app target in `App/` only presents it.
- Keep features planet-agnostic (`Planet`, `RetrogradePeriod`); Mercury is just the launch planet.
- Never hard-code astronomical dates. All sky events come from `ephemeris.json` (see `docs/DATA_SOURCES.md`); test fixtures may copy real values from it.
- Instants are UT `Date`s; anything shown per day goes through `CalendarDay` with the person's `Calendar`.
- Swift 6 language mode, Swift Testing (`import Testing`) for tests.

## Commands

- `cd Packages/RetrogradeKit && swift test --scratch-path ~/Library/Caches/RetrogradeKit-build` — the project sits in an iCloud-synced Desktop, whose file metadata breaks code signing of in-tree `.build` output.
- App build: see README.
