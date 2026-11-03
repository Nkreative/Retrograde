# Daily intensity — methodology v1

**What it is:** an astrology-inspired *reflection score*. It counts how many traditionally "noisy" sky events fall on a day and turns that into one of four levels. It is a prompt to slow down and plan kindly — **not a prediction** of what will happen, and not a scientific measurement. The app says so wherever the score appears.

**Status:** provisionally approved 2026-11-03. Code: `IntensityCalculator` (`Packages/RetrogradeKit/Sources/RetroCore/DailyIntensity.swift`), `methodologyVersion = 1`.

## Inputs

Only verified events from the bundled ephemeris (see [DATA_SOURCES.md](DATA_SOURCES.md)): retrograde stations and shadow boundaries for Mercury–Pluto (NASA/JPL Horizons), new and full Moons (US Naval Observatory), Mercury's sign ingresses (Horizons). No other data, no randomness, no personal information.

## Rules

Each day starts at 0 and adds:

| Event on that day | Points |
|---|---|
| Mercury is retrograde (station-retrograde day through station-direct day) | +2 |
| Mercury stations (turns retrograde or direct) that day | +3, on top of the above |
| The day before or after a Mercury station | +1 |
| Mercury is in its pre- or post-shadow (not retrograde) | +1 |
| Venus or Mars is retrograde | +1 each |
| Venus or Mars stations that day | +1 more |
| Jupiter, Saturn, Uranus, Neptune or Pluto stations that day | +1 |
| New Moon or Full Moon that day | +1 |
| Mercury enters a new sign (either direction) | +1 |

**Levels:** 0 → Calm · 1–2 → Mild · 3–4 → Elevated · 5+ → Intense.

Outer planets count only on their station days: each is retrograde ~40 % of the year, so counting every retrograde day would lift almost every day a level without adding meaning. Their retrogrades still appear in the calendar's "also retrograde" chips.

Eclipses are not scored in v1 (deferred).

## Conventions

- **Days are local.** Every event is a UT instant from the ephemeris and is assigned to the calendar day it falls on in the person's current time zone (`Calendar.autoupdatingCurrent`). A station at 07:13 UT on 24 Oct 2026 scores on 23 Oct in Honolulu and 24 Oct in London. Day counts ("Day 11 of 21") use the same local days.
- **Zodiac:** tropical zodiac — signs are 30° slices of geocentric apparent ecliptic longitude measured from the March equinox point (ecliptic of date), as used in Western astrology. Mercury "enters" a sign when its longitude crosses a 30° boundary; a retrograde re-entry into the previous sign also counts. Sidereal (Vedic) zodiac is not used.
- **Coverage:** 2025-01-01 to 2030-12-31. Days outside coverage have no score; the app says the dates aren't mapped yet rather than guessing.
- **Deterministic:** the same data, day and time zone always give the same score and the same ordered list of influences (strongest first).

## Resulting distribution (UTC days)

| Year | Calm | Mild | Elevated | Intense |
|---|---|---|---|---|
| 2025 | 118 | 205 | 36 | 6 |
| 2026 | 161 | 167 | 31 | 6 |
| 2027 | 146 | 175 | 38 | 6 |
| 2028 | 159 | 162 | 39 | 6 |
| 2029 | 101 | 222 | 35 | 7 |
| 2030 | 149 | 183 | 26 | 7 |

Mercury station days are the only route to Intense (with rare stacking), so Intense appears ~6–7 times a year. Mild is common because Mercury spends roughly a third of the year in shadow.

## Verification

- `DailyIntensityTests` pin: thresholds; both Oct/Nov 2026 Mercury stations scoring Intense; a day-by-day walkthrough of autumn 2026; local-day assignment (Honolulu vs London); the yearly distribution above; no score outside coverage; determinism.
- `tools/intensity/calibrate.py` is an independent Python implementation of the same rules over the same file; its yearly counts must equal the Swift tests'.

## Changing the method

Any change to points, thresholds, events or conventions: bump `methodologyVersion`, update this document and its distribution table, update the calibration script, and record it in [DECISIONS.md](DECISIONS.md).
