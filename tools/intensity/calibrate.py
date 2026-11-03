"""Independent re-implementation of intensity methodology v1 (docs/INTENSITY_METHODOLOGY.md).

Scores every UTC day 2025-2030 from ephemeris.json and prints the level distribution, plus a
sample walkthrough. The Swift tests (DailyIntensityTests) must report the same yearly counts.

Usage: python3 tools/intensity/calibrate.py Packages/RetrogradeKit/Sources/AstroData/Resources/ephemeris.json
"""
import collections, datetime as dt, json, sys

doc = json.load(open(sys.argv[1]))
day = lambda s: dt.date.fromisoformat(s[:10])
ONE = dt.timedelta(days=1)

def influences(d):
    out = []
    for r in doc["retrogrades"]:
        p = r["planet"]
        rx, dr, pre, post = day(r["stationRetrograde"]), day(r["stationDirect"]), day(r["preShadowStart"]), day(r["postShadowEnd"])
        if p == "mercury":
            if rx <= d <= dr: out.append(("Mercury retrograde", 2))
            elif pre <= d <= post: out.append(("Mercury shadow", 1))
            if d in (rx, dr): out.append(("Mercury stations", 3))
            elif d in (rx - ONE, rx + ONE, dr - ONE, dr + ONE): out.append(("near a Mercury station", 1))
        elif p in ("venus", "mars"):
            if rx <= d <= dr: out.append((f"{p.title()} retrograde", 1))
            if d in (rx, dr): out.append((f"{p.title()} stations", 1))
        elif d in (rx, dr):
            out.append((f"{p.title()} stations", 1))
    for m in doc["moonPhases"]:
        if m["phase"] in ("new", "full") and day(m["time"]) == d:
            out.append((f"{m['phase'].title()} Moon", 1))
    for i in doc["ingresses"]:
        if i["planet"] == "mercury" and day(i["time"]) == d:
            out.append(("Mercury changes sign", 1))
    return out

def level(score):
    return "Calm" if score == 0 else "Mild" if score <= 2 else "Elevated" if score <= 4 else "Intense"

for year in range(2025, 2031):
    counts = collections.Counter()
    d = dt.date(year, 1, 1)
    while d.year == year:
        counts[level(sum(w for _, w in influences(d)))] += 1
        d += ONE
    total = sum(counts.values())
    print(year, "  ".join(f"{k} {counts[k] * 100 / total:4.1f}%" for k in ("Calm", "Mild", "Elevated", "Intense")))

print("\nSample: 20 Oct - 2 Dec 2026")
d = dt.date(2026, 10, 20)
while d <= dt.date(2026, 12, 2):
    inf = influences(d); s = sum(w for _, w in inf)
    print(d, f"{s:>2}", f"{level(s):<9}", ", ".join(f"{n} +{w}" for n, w in inf))
    d += ONE

print("\nEXACT")
for year in range(2025, 2031):
    counts = collections.Counter()
    d = dt.date(year, 1, 1)
    while d.year == year:
        counts[level(sum(w for _, w in influences(d)))] += 1
        d += ONE
    print(year, [counts[k] for k in ("Calm", "Mild", "Elevated", "Intense")])
