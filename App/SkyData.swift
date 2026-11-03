import AstroData
import Foundation
import RetroCore

/// The verified sky data, loaded once and shared by every screen.
enum SkyData {
    /// Follows the person's time zone and calendar even if they change while the app is open.
    static let calculator: CycleCalculator? = ephemeris.map { CycleCalculator(ephemeris: $0, calendar: .autoupdatingCurrent) }

    static let ephemeris: Ephemeris? = try? BundledEphemeris.load()

    /// Daily intensity for the person's current time zone. The calculator works out every event's
    /// local day once, so it's rebuilt only when the time zone changes.
    @MainActor static func intensity() -> IntensityCalculator? {
        let zone = TimeZone.current.identifier
        if let cached = intensityCache, cached.zone == zone { return cached.calculator }
        guard let ephemeris else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let calculator = IntensityCalculator(ephemeris: ephemeris, calendar: calendar)
        intensityCache = (zone, calculator)
        return calculator
    }

    @MainActor private static var intensityCache: (zone: String, calculator: IntensityCalculator)?
}
