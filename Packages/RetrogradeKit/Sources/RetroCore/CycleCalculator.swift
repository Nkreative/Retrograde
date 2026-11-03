import Foundation

/// Where a planet is in its cycle at a given instant: what the Overview and widget show.
public struct CycleStatus: Equatable, Sendable {
    public enum Phase: Sendable { case retrograde, direct }
    public enum Shadow: Sendable { case none, pre, post }

    public let planet: Planet
    public let phase: Phase
    /// Only set while `phase == .direct`: the planet is retracing (post) or about to retrace (pre) the retrograde zone.
    public let shadow: Shadow
    /// The station that began this phase.
    public let start: Date
    /// The station that ends this phase; the countdown target.
    public let end: Date
    /// 1-based calendar day within the phase ("Day 12 of 22").
    public let day: Int
    public let totalDays: Int
    /// Fraction of the phase elapsed, by exact time (0...1).
    public let progress: Double

    /// Calendar days until the phase ends ("10 days to exhale"); 0 on the last day.
    public var daysRemaining: Int { totalDays - day }
}

/// How a calendar day is marked for a planet (Rx, Sh, D in the Calendar).
public enum DayMarker: Sendable {
    case retrograde, shadow, direct
}

/// Turns retrograde periods into the statuses and day markers the UI shows,
/// using the person's calendar and time zone.
public struct CycleCalculator: Sendable {
    private let periods: [Planet: [RetrogradePeriod]]
    private let calendar: Calendar

    public init(ephemeris: Ephemeris, calendar: Calendar = .current) {
        self.periods = Dictionary(grouping: ephemeris.retrogrades, by: \.planet)
        self.calendar = calendar
    }

    /// Status at `instant`, or nil when the data doesn't reach the stations on both sides.
    public func status(of planet: Planet, at instant: Date) -> CycleStatus? {
        let list = periods[planet] ?? []
        if let current = list.first(where: { $0.stationRetrograde <= instant && instant < $0.stationDirect }) {
            return makeStatus(planet, .retrograde, .none, from: current.stationRetrograde, to: current.stationDirect, at: instant)
        }
        guard let previous = list.last(where: { $0.stationDirect <= instant }),
              let next = list.first(where: { $0.stationRetrograde > instant })
        else { return nil }
        let shadow: CycleStatus.Shadow =
            instant < previous.postShadowEnd ? .post : instant >= next.preShadowStart ? .pre : .none
        return makeStatus(planet, .direct, shadow, from: previous.stationDirect, to: next.stationRetrograde, at: instant)
    }

    /// Marker for a calendar day. A station day counts as retrograde; shadow days
    /// are those between a shadow boundary and its station.
    public func marker(for planet: Planet, on day: CalendarDay) -> DayMarker {
        let list = periods[planet] ?? []
        if list.contains(where: { CalendarDay($0.stationRetrograde, in: calendar)...CalendarDay($0.stationDirect, in: calendar) ~= day }) {
            return .retrograde
        }
        if list.contains(where: { CalendarDay($0.preShadowStart, in: calendar)...CalendarDay($0.postShadowEnd, in: calendar) ~= day }) {
            return .shadow
        }
        return .direct
    }

    private func makeStatus(
        _ planet: Planet, _ phase: CycleStatus.Phase, _ shadow: CycleStatus.Shadow,
        from start: Date, to end: Date, at instant: Date
    ) -> CycleStatus {
        let firstDay = CalendarDay(start, in: calendar)
        let total = firstDay.days(to: CalendarDay(end, in: calendar)) + 1
        let day = firstDay.days(to: CalendarDay(instant, in: calendar)) + 1
        let progress = instant.timeIntervalSince(start) / end.timeIntervalSince(start)
        return CycleStatus(
            planet: planet, phase: phase, shadow: shadow, start: start, end: end,
            day: day, totalDays: total, progress: min(max(progress, 0), 1)
        )
    }
}
