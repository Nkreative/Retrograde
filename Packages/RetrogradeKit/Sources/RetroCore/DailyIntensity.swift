import Foundation

/// Retrograde's daily intensity: an astrology-inspired reflection score built only from verified
/// sky events. It is a prompt to reflect, not a prediction. Methodology: docs/INTENSITY_METHODOLOGY.md.
public enum IntensityLevel: Int, CaseIterable, Comparable, Sendable {
    case calm = 1, mild, elevated, intense

    /// 0 = Calm · 1–2 = Mild · 3–4 = Elevated · 5+ = Intense.
    public init(score: Int) {
        switch score {
        case ...0: self = .calm
        case 1...2: self = .mild
        case 3...4: self = .elevated
        default: self = .intense
        }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// One sky event that adds to a day's score.
public struct Influence: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Mercury retrograde, `day` of `totalDays` (calendar days in the person's time zone).
        case mercuryRetrograde(day: Int, totalDays: Int)
        /// Mercury changes direction today (added on top of `mercuryRetrograde`).
        case mercuryStation(turningDirect: Bool)
        /// The day before or after a Mercury station.
        case nearMercuryStation
        case mercuryShadow(beforeRetrograde: Bool)
        /// Venus or Mars retrograde.
        case planetRetrograde(Planet)
        /// A planet other than Mercury changes direction today.
        case planetStation(Planet, turningDirect: Bool)
        case newMoon
        case fullMoon
        /// Mercury moves into a sign (tropical zodiac), forwards or, while retrograde, backwards.
        case mercuryIngress(ZodiacSign, retrograde: Bool)
    }

    public let kind: Kind
    public let points: Int

    public init(kind: Kind, points: Int) {
        self.kind = kind
        self.points = points
    }
}

public struct DailyIntensity: Sendable {
    public let day: CalendarDay
    /// Strongest first.
    public let influences: [Influence]
    public var score: Int { influences.reduce(0) { $0 + $1.points } }
    public var level: IntensityLevel { IntensityLevel(score: score) }
    public let methodologyVersion: Int

    public init(day: CalendarDay, influences: [Influence], methodologyVersion: Int) {
        self.day = day
        self.influences = influences
        self.methodologyVersion = methodologyVersion
    }
}

/// Scores calendar days in the person's calendar and time zone. Deterministic: the same data,
/// day and time zone always give the same result.
public struct IntensityCalculator: Sendable {
    public static let methodologyVersion = 1

    /// Points per event (methodology v1).
    public enum Points {
        public static let mercuryRetrograde = 2
        public static let mercuryStation = 3
        public static let nearMercuryStation = 1
        public static let mercuryShadow = 1
        public static let venusMarsRetrograde = 1
        public static let otherStation = 1
        public static let newOrFullMoon = 1
        public static let mercuryIngress = 1
    }

    private struct LocalPeriod: Sendable {
        let planet: Planet
        let rx: CalendarDay, direct: CalendarDay, preShadow: CalendarDay, postShadow: CalendarDay
    }

    private let coverage: ClosedRange<CalendarDay>
    // Every event's local day, worked out once for this time zone.
    private let periods: [LocalPeriod]
    private let moons: [CalendarDay: [MoonPhase]]
    private let mercuryIngresses: [CalendarDay: [SignIngress]]

    public init(ephemeris: Ephemeris, calendar: Calendar = .current) {
        func local(_ date: Date) -> CalendarDay { CalendarDay(date, in: calendar) }
        coverage = ephemeris.coverage
        periods = ephemeris.retrogrades.map {
            LocalPeriod(planet: $0.planet, rx: local($0.stationRetrograde), direct: local($0.stationDirect),
                        preShadow: local($0.preShadowStart), postShadow: local($0.postShadowEnd))
        }
        moons = Dictionary(grouping: ephemeris.moonPhases, by: { local($0.time) }).mapValues { $0.map(\.phase) }
        mercuryIngresses = Dictionary(grouping: ephemeris.ingresses.filter { $0.planet == .mercury }, by: { local($0.time) })
    }

    /// The primary moon phase on a local day, if any (for calendar markers).
    public func moonPhase(on day: CalendarDay) -> MoonPhase? { moons[day]?.first }

    /// Nil outside the data's coverage.
    public func intensity(on day: CalendarDay) -> DailyIntensity? {
        guard coverage.contains(day) else { return nil }
        var found: [Influence] = []

        for p in periods {
            let rx = p.rx, direct = p.direct
            switch p.planet {
            case .mercury:
                if (rx...direct).contains(day) {
                    found.append(Influence(kind: .mercuryRetrograde(day: rx.days(to: day) + 1, totalDays: rx.days(to: direct) + 1), points: Points.mercuryRetrograde))
                } else if (p.preShadow...p.postShadow).contains(day) {
                    found.append(Influence(kind: .mercuryShadow(beforeRetrograde: day < rx), points: Points.mercuryShadow))
                }
                if day == rx || day == direct {
                    found.append(Influence(kind: .mercuryStation(turningDirect: day == direct), points: Points.mercuryStation))
                } else if [rx.adding(days: -1), rx.adding(days: 1), direct.adding(days: -1), direct.adding(days: 1)].contains(day) {
                    found.append(Influence(kind: .nearMercuryStation, points: Points.nearMercuryStation))
                }
            case .venus, .mars:
                if (rx...direct).contains(day) {
                    found.append(Influence(kind: .planetRetrograde(p.planet), points: Points.venusMarsRetrograde))
                }
                if day == rx || day == direct {
                    found.append(Influence(kind: .planetStation(p.planet, turningDirect: day == direct), points: Points.otherStation))
                }
            default:
                if day == rx || day == direct {
                    found.append(Influence(kind: .planetStation(p.planet, turningDirect: day == direct), points: Points.otherStation))
                }
            }
        }
        for phase in moons[day] ?? [] {
            switch phase {
            case .new: found.append(Influence(kind: .newMoon, points: Points.newOrFullMoon))
            case .full: found.append(Influence(kind: .fullMoon, points: Points.newOrFullMoon))
            default: break
            }
        }
        for ingress in mercuryIngresses[day] ?? [] {
            found.append(Influence(kind: .mercuryIngress(ingress.sign, retrograde: ingress.retrograde), points: Points.mercuryIngress))
        }
        // Strongest first; ties keep the order above, which is stable for the same data.
        let ordered = found.enumerated().sorted { ($0.element.points, -$0.offset) > ($1.element.points, -$1.offset) }.map(\.element)
        return DailyIntensity(day: day, influences: ordered, methodologyVersion: Self.methodologyVersion)
    }
}
