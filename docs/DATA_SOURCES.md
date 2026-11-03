# Sky data: sources and method

The app never invents astronomical dates. Everything comes from `Packages/RetrogradeKit/Sources/AstroData/Resources/ephemeris.json`, produced by `tools/ephemeris/generate_ephemeris.py`.

## Sources

| Data | Source | Terms |
|---|---|---|
| Planet positions (Mercury → Pluto) | [NASA/JPL Horizons](https://ssd.jpl.nasa.gov/horizons/) API — geocentric apparent ecliptic-of-date longitude (the tropical-zodiac longitude used in astrology), hourly, UT | US Government work; JPL asks for acknowledgement. Credited in the app's Settings → "Where our sky data comes from". |
| Moon phases (new, first quarter, full, last quarter) | [US Naval Observatory](https://aa.usno.navy.mil/data/api) Astronomical Applications API, UT | Public domain (US Government work). |

## What is derived

- **Stations** (retrograde begins / ends): the instant the longitude stops increasing or decreasing. Found where hourly samples change direction, refined with a least-squares parabola. Typically within a few minutes of published tables.
- **Shadow periods**: pre-shadow starts when the planet first reaches the longitude where it will later station direct; post-shadow ends when it gets back to the longitude where it stationed retrograde.
- **Sign ingresses**: crossings of each 30° boundary, flagged when re-entered while retrograde.

## Coverage and updates

- Covers **2025-01-01 → 2030-12-31**, plus one retrograde before and after per planet so every covered day has a previous and next station.
- Re-run the script and its tests to extend coverage; bump `schemaVersion` only if the file format changes.
- `tools/ephemeris/known_dates.json` lists published station and moon-phase dates; the tests fail if the generated file disagrees by more than a day. Add rows when spot-checking new years.

## Time zones

Events are stored as UT instants. The app converts them to the person's calendar day: a station counts on the local date it happens (e.g. Mercury's 24 Oct 2026 07:10 UT station is 23 Oct in Hawaii). Day counts ("Day 11 of 21") use calendar days in the person's time zone.

## Daily intensity

Not part of this file. The Calm / Mild / Elevated / Intense rating is an editorial, rule-based reading of these events, documented separately in `docs/INTENSITY_METHODOLOGY.md` (milestone M7).
