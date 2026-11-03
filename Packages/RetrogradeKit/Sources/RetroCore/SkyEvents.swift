import Foundation

public enum Planet: String, CaseIterable, Codable, Sendable {
    case mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto
}

public enum ZodiacSign: String, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces
}

/// One retrograde cycle of a planet, including its shadow periods.
/// All instants are exact (UT-based `Date`s); converting to calendar days is the caller's job.
public struct RetrogradePeriod: Equatable, Sendable {
    public let planet: Planet
    /// Planet first reaches the longitude where it will later station direct.
    public let preShadowStart: Date
    public let stationRetrograde: Date
    public let stationDirect: Date
    /// Planet gets back to the longitude where it stationed retrograde.
    public let postShadowEnd: Date
    public let stationRetrogradeLongitude: Double
    public let stationDirectLongitude: Double

    public init(
        planet: Planet, preShadowStart: Date, stationRetrograde: Date, stationDirect: Date,
        postShadowEnd: Date, stationRetrogradeLongitude: Double, stationDirectLongitude: Double
    ) {
        self.planet = planet
        self.preShadowStart = preShadowStart
        self.stationRetrograde = stationRetrograde
        self.stationDirect = stationDirect
        self.postShadowEnd = postShadowEnd
        self.stationRetrogradeLongitude = stationRetrogradeLongitude
        self.stationDirectLongitude = stationDirectLongitude
    }

    public var stationRetrogradeSign: ZodiacSign { .containing(longitude: stationRetrogradeLongitude) }
    public var stationDirectSign: ZodiacSign { .containing(longitude: stationDirectLongitude) }
}

public extension ZodiacSign {
    static func containing(longitude: Double) -> ZodiacSign {
        let normalized = (longitude.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return allCases[Int(normalized / 30)]
    }
}

public enum MoonPhase: String, CaseIterable, Codable, Sendable {
    case new, firstQuarter, full, lastQuarter
}

public struct MoonPhaseEvent: Equatable, Sendable {
    public let phase: MoonPhase
    public let time: Date

    public init(phase: MoonPhase, time: Date) {
        self.phase = phase
        self.time = time
    }
}

/// A planet crossing into a zodiac sign. `retrograde` is true when it re-enters
/// the previous sign while moving backward.
public struct SignIngress: Equatable, Sendable {
    public let planet: Planet
    public let sign: ZodiacSign
    public let time: Date
    public let retrograde: Bool

    public init(planet: Planet, sign: ZodiacSign, time: Date, retrograde: Bool) {
        self.planet = planet
        self.sign = sign
        self.time = time
        self.retrograde = retrograde
    }
}

public struct DataSource: Equatable, Sendable {
    public let name: String
    public let url: URL
    public let use: String

    public init(name: String, url: URL, use: String) {
        self.name = name
        self.url = url
        self.use = use
    }
}

/// The verified astronomical events the app knows about.
public struct Ephemeris: Sendable {
    /// First and last calendar day the data fully covers.
    public let coverage: ClosedRange<CalendarDay>
    public let retrogrades: [RetrogradePeriod]
    public let ingresses: [SignIngress]
    public let moonPhases: [MoonPhaseEvent]
    public let sources: [DataSource]

    public init(
        coverage: ClosedRange<CalendarDay>, retrogrades: [RetrogradePeriod],
        ingresses: [SignIngress] = [], moonPhases: [MoonPhaseEvent] = [], sources: [DataSource] = []
    ) {
        self.coverage = coverage
        self.retrogrades = retrogrades.sorted { $0.stationRetrograde < $1.stationRetrograde }
        self.ingresses = ingresses.sorted { $0.time < $1.time }
        self.moonPhases = moonPhases.sorted { $0.time < $1.time }
        self.sources = sources
    }

    public func retrogrades(of planet: Planet) -> [RetrogradePeriod] {
        retrogrades.filter { $0.planet == planet }
    }
}
