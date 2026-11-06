import AstroData
import Foundation
import RetroCore
import Testing
@testable import Editorial

@Suite struct PromotionMomentTests {
    let calculator: CycleCalculator
    let period: RetrogradePeriod

    init() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let ephemeris = try BundledEphemeris.load()
        calculator = CycleCalculator(ephemeris: ephemeris, calendar: utc)
        // A real Mercury retrograde from the bundled data (the second one in the file, so the
        // neighbouring events exist on both sides).
        period = ephemeris.retrogrades.filter { $0.planet == .mercury }[1]
    }

    private func ending(at instant: Date) -> Bool {
        calculator.status(of: .mercury, at: instant).map(PromotionMoment.isRetrogradeEnding) ?? false
    }

    private let day: TimeInterval = 86_400

    @Test func onlyInTheLastWeekOfRetrograde() {
        #expect(!ending(at: period.stationDirect - 8 * day))
        #expect(ending(at: period.stationDirect - 7 * day))
        #expect(ending(at: period.stationDirect - 3_600)) // the day it turns direct
    }

    @Test func notOnceDirectOrBeforeRetrograde() {
        #expect(!ending(at: period.stationDirect + 3_600))     // post-shadow
        #expect(!ending(at: period.stationRetrograde - 3_600)) // pre-shadow
        #expect(!ending(at: period.stationRetrograde + 3_600)) // retrograde just began
    }

    @Test func copy() {
        let message = PromotionMoment.message(for: .mercury)
        #expect(message.headline == "MERCURY’S CLOCKING OUT.")
        #expect(message.body == "Prices are dropping.")
        #expect(message.signOff == "The chaos will return. Your backup stays.")
    }
}
