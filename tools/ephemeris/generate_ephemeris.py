#!/usr/bin/env python3
"""Generate Retrograde's bundled ephemeris data file.

Sources
  * Planet positions: NASA/JPL Horizons API (https://ssd.jpl.nasa.gov/horizons/).
    Geocentric apparent ecliptic-of-date longitude (QUANTITIES=31), i.e. the
    tropical-zodiac longitude astrologers use, sampled hourly in UT.
  * Moon phases: US Naval Observatory Astronomical Applications API
    (https://aa.usno.navy.mil/data/api), primary phases in UT.

Derived events
  * Stations: the instant the longitude stops increasing (station retrograde)
    or stops decreasing (station direct). Found where the hourly longitude
    changes direction, then refined with a least-squares parabola.
  * Shadows: pre-shadow starts when the planet first reaches the longitude where
    it will later station direct; post-shadow ends when it gets back to the
    longitude where it stationed retrograde.
  * Sign ingresses: crossings of each 30-degree boundary.

Usage
  python3 tools/ephemeris/generate_ephemeris.py [--out PATH]

Standard library only. Re-running produces the same events (Horizons and USNO
data are deterministic); only `generatedAt` changes.
"""

import argparse
import datetime as dt
import json
import time
import urllib.parse
import urllib.request

COVERAGE_START = dt.date(2025, 1, 1)
COVERAGE_END = dt.date(2030, 12, 31)
# Fetch well beyond coverage so shadow periods of slow planets are complete.
FETCH_START = dt.date(2023, 7, 1)
FETCH_END = dt.date(2032, 7, 1)

PLANETS = [
    # (id used in app, Horizons body id, half-width in hours of the station fit window)
    ("mercury", "199", 3),
    ("venus", "299", 6),
    ("mars", "499", 6),
    ("jupiter", "599", 72),
    ("saturn", "699", 72),
    ("uranus", "799", 96),
    ("neptune", "899", 96),
    ("pluto", "999", 96),
]

SIGNS = ["aries", "taurus", "gemini", "cancer", "leo", "virgo",
         "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"]

MOON_PHASES = {"New Moon": "new", "First Quarter": "firstQuarter",
               "Full Moon": "full", "Last Quarter": "lastQuarter"}

HORIZONS_URL = "https://ssd.jpl.nasa.gov/api/horizons.api"
USNO_URL = "https://aa.usno.navy.mil/api/moon/phases/year"
EPOCH = dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc)


def http_json(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=120) as resp:
                return json.load(resp)
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))


def hours(t):
    return (t - EPOCH).total_seconds() / 3600.0


def from_hours(h):
    return EPOCH + dt.timedelta(hours=h)


def iso(t):
    t = (t + dt.timedelta(seconds=30)).replace(second=0, microsecond=0)
    return t.strftime("%Y-%m-%dT%H:%MZ")


# ---------------------------------------------------------------- Horizons

def fetch_longitudes(body):
    """Hourly (hours since 2000-01-01 UT, longitude deg) for the whole fetch range."""
    samples = []
    chunk_start = FETCH_START
    while chunk_start < FETCH_END:
        chunk_end = min(dt.date(chunk_start.year + 3, chunk_start.month, chunk_start.day), FETCH_END)
        params = {
            "format": "json", "COMMAND": f"'{body}'", "OBJ_DATA": "'NO'", "MAKE_EPHEM": "'YES'",
            "EPHEM_TYPE": "'OBSERVER'", "CENTER": "'500@399'", "QUANTITIES": "'31'",
            "START_TIME": f"'{chunk_start.isoformat()}'", "STOP_TIME": f"'{chunk_end.isoformat()}'",
            "STEP_SIZE": "'1h'", "CSV_FORMAT": "'YES'",
        }
        result = http_json(HORIZONS_URL + "?" + urllib.parse.urlencode(params))["result"]
        if "$$SOE" not in result:
            raise RuntimeError(f"Horizons returned no ephemeris for {body}:\n{result[:2000]}")
        body_text = result.split("$$SOE")[1].split("$$EOE")[0]
        for line in body_text.strip().splitlines():
            cols = [c.strip() for c in line.split(",")]
            t = dt.datetime.strptime(cols[0], "%Y-%b-%d %H:%M").replace(tzinfo=dt.timezone.utc)
            lon = float(cols[3])
            if samples and hours(t) <= samples[-1][0]:
                continue  # chunk boundaries overlap by one sample
            samples.append((hours(t), lon))
        chunk_start = chunk_end
        time.sleep(0.5)
    return unwrap(samples)


def unwrap(samples):
    out, offset, prev = [], 0.0, None
    for h, lon in samples:
        if prev is not None:
            if lon - prev < -180:
                offset += 360
            elif lon - prev > 180:
                offset -= 360
        out.append((h, lon + offset))
        prev = lon
    return out


# ---------------------------------------------------------------- events

def fit_vertex(points):
    """Least-squares parabola through (h, lon); returns (h, lon) of its vertex."""
    h0 = points[len(points) // 2][0]
    xs = [p[0] - h0 for p in points]
    ys = [p[1] for p in points]
    n = len(xs)
    sx = [sum(x ** k for x in xs) for k in range(5)]
    sy = [sum(y * x ** k for x, y in zip(xs, ys)) for k in range(3)]
    # Normal equations for y = a + b x + c x^2.
    m = [[sx[0], sx[1], sx[2], sy[0]],
         [sx[1], sx[2], sx[3], sy[1]],
         [sx[2], sx[3], sx[4], sy[2]]]
    for i in range(3):
        pivot = max(range(i, 3), key=lambda r: abs(m[r][i]))
        m[i], m[pivot] = m[pivot], m[i]
        for r in range(3):
            if r != i:
                f = m[r][i] / m[i][i]
                m[r] = [a - f * b for a, b in zip(m[r], m[i])]
    a, b, c = (m[i][3] / m[i][i] for i in range(3))
    x = -b / (2 * c)
    return h0 + x, a + b * x + c * x * x


def find_stations(series, half_window):
    stations = []
    for i in range(1, len(series) - 1):
        d_prev = series[i][1] - series[i - 1][1]
        d_next = series[i + 1][1] - series[i][1]
        if d_prev > 0 >= d_next:
            kind = "retrograde"
        elif d_prev < 0 <= d_next:
            kind = "direct"
        else:
            continue
        lo, hi = max(0, i - half_window), min(len(series), i + half_window + 1)
        h, lon = fit_vertex(series[lo:hi])
        if stations and stations[-1]["kind"] == kind:
            continue  # numerical jitter at a near-stationary sample
        if stations and h - stations[-1]["h"] < 24:
            stations.pop()  # jitter produced a spurious pair; drop both
            continue
        stations.append({"kind": kind, "h": h, "lon": lon, "index": i})
    return stations


def crossing(series, target, start, stop, step):
    """First index-walk crossing of `target` between indices start and stop."""
    i = start
    while (step > 0 and i + step <= stop) or (step < 0 and i + step >= stop):
        a, b = series[i], series[i + step]
        if (a[1] - target) * (b[1] - target) <= 0 and a[1] != b[1]:
            frac = (target - a[1]) / (b[1] - a[1])
            return a[0] + frac * (b[0] - a[0])
        i += step
    return None


def retrograde_periods(planet, series, half_window):
    stations = find_stations(series, half_window)
    periods = []
    for rx, d in zip(stations, stations[1:]):
        if rx["kind"] != "retrograde" or d["kind"] != "direct":
            continue
        # Pre-shadow: walking back from station retrograde, the last time the
        # planet was at the station-direct longitude.
        pre = crossing(series, d["lon"], rx["index"], 0, -1)
        # Post-shadow: walking forward from station direct, the first time it
        # gets back to the station-retrograde longitude.
        post = crossing(series, rx["lon"], d["index"], len(series) - 1, 1)
        if pre is None or post is None:
            continue  # shadow falls outside fetched data
        periods.append({
            "planet": planet,
            "preShadowStart": from_hours(pre),
            "stationRetrograde": from_hours(rx["h"]),
            "stationDirect": from_hours(d["h"]),
            "postShadowEnd": from_hours(post),
            "stationRetrogradeLongitude": round(rx["lon"] % 360, 4),
            "stationDirectLongitude": round(d["lon"] % 360, 4),
        })
    return periods


def ingresses(planet, series):
    events = []
    for a, b in zip(series, series[1:]):
        lo, hi = sorted((a[1], b[1]))
        boundary = (int(lo // 30) + 1) * 30
        if lo < boundary <= hi:
            frac = (boundary - a[1]) / (b[1] - a[1])
            moving_forward = b[1] > a[1]
            sign_index = int((boundary % 360) // 30) if moving_forward else int(((boundary - 30) % 360) // 30)
            events.append({
                "planet": planet,
                "sign": SIGNS[sign_index],
                "time": from_hours(a[0] + frac * (b[0] - a[0])),
                "retrograde": not moving_forward,
            })
    return events


def moon_phases():
    events = []
    for year in range(COVERAGE_START.year, COVERAGE_END.year + 1):
        data = http_json(f"{USNO_URL}?year={year}")
        for p in data["phasedata"]:
            hh, mm = (int(x) for x in p["time"].split(":"))
            t = dt.datetime(p["year"], p["month"], p["day"], hh, mm, tzinfo=dt.timezone.utc)
            events.append({"phase": MOON_PHASES[p["phase"]], "time": t})
        time.sleep(0.5)
    return events


# ---------------------------------------------------------------- output

def in_coverage(start, end):
    lo = dt.datetime.combine(COVERAGE_START, dt.time(), dt.timezone.utc)
    hi = dt.datetime.combine(COVERAGE_END + dt.timedelta(days=1), dt.time(), dt.timezone.utc)
    return end >= lo and start < hi


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="Packages/RetrogradeKit/Sources/AstroData/Resources/ephemeris.json")
    args = parser.parse_args()

    periods, ingress_events = [], []
    for planet, body, half_window in PLANETS:
        print(f"Fetching {planet}…", flush=True)
        series = fetch_longitudes(body)
        found = retrograde_periods(planet, series, half_window)
        inside = [i for i, p in enumerate(found) if in_coverage(p["preShadowStart"], p["postShadowEnd"])]
        # Keep one period either side so every covered day has a previous and next station.
        periods += found[max(0, inside[0] - 1):inside[-1] + 2]
        ingress_events += [e for e in ingresses(planet, series) if in_coverage(e["time"], e["time"])]
    print("Fetching moon phases…", flush=True)
    moons = moon_phases()

    def ser(event):
        return {k: iso(v) if isinstance(v, dt.datetime) else v for k, v in event.items()}

    doc = {
        "schemaVersion": 1,
        "generatedAt": iso(dt.datetime.now(dt.timezone.utc)),
        "coverage": {"start": COVERAGE_START.isoformat(), "end": COVERAGE_END.isoformat()},
        "sources": [
            {"name": "NASA/JPL Horizons", "url": "https://ssd.jpl.nasa.gov/horizons/",
             "use": "Geocentric apparent ecliptic-of-date longitudes, hourly UT; stations, shadows and ingresses derived."},
            {"name": "US Naval Observatory, Astronomical Applications Department", "url": "https://aa.usno.navy.mil/data/api",
             "use": "Primary moon phases, UT."},
        ],
        "retrogrades": [ser(p) for p in sorted(periods, key=lambda p: p["stationRetrograde"])],
        "ingresses": [ser(e) for e in sorted(ingress_events, key=lambda e: e["time"])],
        "moonPhases": [ser(m) for m in sorted(moons, key=lambda m: m["time"])],
    }
    with open(args.out, "w") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    print(f"Wrote {args.out}: {len(doc['retrogrades'])} retrogrades, "
          f"{len(doc['ingresses'])} ingresses, {len(doc['moonPhases'])} moon phases")


if __name__ == "__main__":
    main()
