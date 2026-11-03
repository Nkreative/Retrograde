import AstroData
import Foundation
import RetroCore

/// The verified sky data, loaded once and shared by every screen.
enum SkyData {
    /// Follows the person's time zone and calendar even if they change while the app is open.
    static let calculator: CycleCalculator? = ephemeris.map { CycleCalculator(ephemeris: $0, calendar: .autoupdatingCurrent) }

    static let ephemeris: Ephemeris? = try? BundledEphemeris.load()
}
