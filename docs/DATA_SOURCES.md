# Sky data: sources and method

The app never invents astronomical dates. Everything comes from `Packages/RetrogradeKit/Sources/AstroData/Resources/ephemeris.json`, produced by `tools/ephemeris/generate_ephemeris.py`.

## Sources

| Data | Source | Terms |
|---|---|---|
| Planet positions (Mercury → Pluto) | [NASA/JPL Horizons](https://ssd.jpl.nasa.gov/horizons/) API — geocentric apparent ecliptic-of-date longitude (the tropical-zodiac longitude used in astrology), hourly, UT | US Government work; JPL asks for acknowledgement. Credited in the app's Settings → "Where our sky data comes from". |
| Moon phases (new, first quarter, full, last quarter) | [US Naval Observatory](https://aa.usno.navy.mil/data/api) Astronomical Applications API, UT | Public domain (US Government work). |

## What is derived

- **Stations** (retrograde begins / ends): the instant the longitude stops increasing or decreasing. Found where hourly samples change direction, refined with a least-squares parabola over a short window (±3 h for Mercury, ±6 h Venus/Mars, ±3–4 days for slow outer planets, whose stations are inherently fuzzy by hours).
- **Shadow periods**: pre-shadow starts when the planet first reaches the longitude where it will later station direct; post-shadow ends when it gets back to the longitude where it stationed retrograde.
- **Sign ingresses**: crossings of each 30° boundary, flagged when re-entered while retrograde.

## Coverage and updates

- Covers **2025-01-01 → 2030-12-31**, plus one retrograde before and after per planet so every covered day has a previous and next station.
- Re-run the script and its tests to extend coverage; bump `schemaVersion` only if the file format changes.
- `tools/ephemeris/known_dates.json` lists published station and moon-phase dates; the tests fail if the generated file disagrees by more than a day. Add rows when spot-checking new years.

## Verification log

**2026-11-03 — independent check of Mercury's Oct–Nov 2026 retrograde (before M3).**

| Event | Generated (v1, first run) | Skyfield 1.49 + JPL DE440s | Published ephemerides | Generated (now) |
|---|---|---|---|---|
| Pre-shadow starts | 2026-10-04 09:09 UT | 09:09 | — | 09:09 |
| Stations retrograde | 2026-10-24 **07:10** UT | 07:13 | 07:12 ([Chani](https://chani.com/this-year/key-dates/2026-astrological-key-dates-mercury-retrogrades): 12:12 am PT; [Jagannath Hora](https://jagannathhora.com/?p=1414)) | 07:13 |
| Stations direct | 2026-11-13 **15:56** UT | 15:54 | 15:53–15:54 ([Chani](https://chani.com/this-year/key-dates/2026-astrological-key-dates-mercury-retrogrades): 7:53 am PT; [Jagannath Hora](https://jagannathhora.com/?p=1414)) | 15:54 |
| Post-shadow ends | 2026-11-30 06:16 UT | 06:16 | — | 06:16 |

Findings:
1. **Dates were correct**; station **times** were 2–3 minutes off. Cause: the parabola fit for Mercury used ±12 h of hourly samples, too wide for its fast-changing motion. Narrowed to ±3 h (Venus/Mars ±6 h); all Mercury/Venus stations in 2025–2026 now agree with Skyfield within 1–2 minutes. No calendar day changed for any time zone.
2. **The reference list itself had errors**: Venus 2025 (Mar 1 → Apr 12) and Mars direct (Feb 23, 2025) were US-local dates, not UT. Correct UT dates, confirmed by Skyfield and Horizons: Venus 2025-03-02 00:36 → 2025-04-13 01:02, Mars direct 2025-02-24 02:00. A ±1-day tolerance had hidden this; the checks now require exact UT dates, and Mercury Oct–Nov 2026 must match the independent times within 2 minutes.
3. One published source ([Sterngucker](https://www.sterngucker.de/en/planets/mercury/mercury-retrograde/), DE421) lists 08:13 for the retrograde station; it disagrees with all other sources and both independent calculations by an hour, most likely a time-zone labelling slip.

## Time zones

Events are stored as UT instants. The app converts them to the person's calendar day: a station counts on the local date it happens (e.g. Mercury's 24 Oct 2026 07:13 UT station is 23 Oct in Hawaii). Day counts ("Day 11 of 21") use calendar days in the person's time zone.

## Daily intensity

Not part of this file. The Calm / Mild / Elevated / Intense rating is an editorial, rule-based reading of these events, documented separately in `docs/INTENSITY_METHODOLOGY.md` (milestone M7).
