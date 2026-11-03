#!/usr/bin/env python3
"""Checks the generated ephemeris file against published dates and basic invariants.

Run: python3 -m unittest discover -s tools/ephemeris
"""

import datetime as dt
import json
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(ROOT, "Packages/RetrogradeKit/Sources/AstroData/Resources/ephemeris.json")


def parse(s):
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%MZ")


def day(s):
    return dt.datetime.strptime(s, "%Y-%m-%d")


class EphemerisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(DATA) as f:
            cls.doc = json.load(f)
        with open(os.path.join(HERE, "known_dates.json")) as f:
            cls.known = json.load(f)

    def test_matches_published_station_dates(self):
        for row in self.known["stations"]:
            with self.subTest(row=row):
                match = [p for p in self.doc["retrogrades"] if p["planet"] == row["planet"]
                         and abs(parse(p["stationRetrograde"]) - day(row["stationRetrograde"])) < dt.timedelta(days=2)]
                self.assertEqual(len(match), 1, "no retrograde near published date")
                for key in ("stationRetrograde", "stationDirect"):
                    self.assertLessEqual(abs(parse(match[0][key]).date() - day(row[key]).date()), dt.timedelta(days=1))

    def test_matches_published_moon_phases(self):
        for row in self.known["moonPhases"]:
            with self.subTest(row=row):
                self.assertTrue(any(m["phase"] == row["phase"] and m["time"].startswith(row["date"])
                                    for m in self.doc["moonPhases"]))

    def test_period_events_are_ordered(self):
        for p in self.doc["retrogrades"]:
            with self.subTest(p=p):
                times = [parse(p[k]) for k in ("preShadowStart", "stationRetrograde", "stationDirect", "postShadowEnd")]
                self.assertEqual(times, sorted(times))

    def test_retrogrades_of_a_planet_do_not_overlap(self):
        for planet in {p["planet"] for p in self.doc["retrogrades"]}:
            periods = [p for p in self.doc["retrogrades"] if p["planet"] == planet]
            for a, b in zip(periods, periods[1:]):
                self.assertLess(parse(a["stationDirect"]), parse(b["stationRetrograde"]))

    def test_mercury_has_three_or_four_retrogrades_a_year(self):
        for year in range(2025, 2031):
            n = sum(1 for p in self.doc["retrogrades"]
                    if p["planet"] == "mercury" and p["stationRetrograde"].startswith(str(year)))
            self.assertIn(n, (3, 4), year)

    def test_moon_phases_cycle_in_order(self):
        order = ["new", "firstQuarter", "full", "lastQuarter"]
        phases = [m["phase"] for m in self.doc["moonPhases"]]
        for a, b in zip(phases, phases[1:]):
            self.assertEqual(order[(order.index(a) + 1) % 4], b)

    def test_coverage_is_complete(self):
        self.assertEqual(self.doc["coverage"], {"start": "2025-01-01", "end": "2030-12-31"})
        first, last = self.doc["moonPhases"][0]["time"], self.doc["moonPhases"][-1]["time"]
        self.assertTrue(first.startswith("2025-01"))
        self.assertTrue(last.startswith("2030-12"))


if __name__ == "__main__":
    unittest.main()
