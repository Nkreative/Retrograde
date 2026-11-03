import Foundation

/// Where a planet is in its cycle at a given instant: what the Overview and widget show.
///
/// A cycle runs pre-shadow → retrograde → post-shadow → direct → (next pre-shadow).
/// Each stage has its own window, which the progress bar and "Day X of Y" describe,
/// and a countdown target:
///
/// | Stage | Window | Countdown to |
/// |---|---|---|
/// | preShadow | pre-shadow start → station retrograde | station retrograde |
/// | retrograde | station retrograde → station direct | station direct |
/// | postShadow | station direct → post-shadow end | post-shadow end |
/// | direct | previous post-shadow end → next station retrograde | next station retrograde |
///
/// The direct window deliberately runs to the next retrograde (not to the next shadow) so its
/// countdown is "days till the next plot twist"; once the pre-shadow begins, the stage switches.
public struct CycleStatus: Equatable, Sendable {
    public enum Stage: CaseIterable, Sendable {
        case preShadow, retrograde, postShadow, direct
    }

    public let planet: Planet
    public let stage: Stage
    /// The retrograde this stage belongs to: the upcoming one before it starts, otherwise the current or just-ended one.
    public let period: RetrogradePeriod
    public let windowStart: Date
    public let windowEnd: Date
    public let countdownTarget: Date
    /// 1-based calendar day within the window ("Day 12 of 22").
    public let day: Int
    public let totalDays: Int
    /// Calendar days from today to the countdown target; 0 on the day itself.
    public let daysUntilTarget: Int
    /// Fraction of the window elapsed, by exact time (0...1).
    public let progress: Double

    public var isRetrograde: Bool { stage == .retrograde }
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

    /// Status at `instant`, or nil when the data doesn't reach the neighbouring events.
    public func status(of planet: Planet, at instant: Date) -> CycleStatus? {
        let list = periods[planet] ?? []
        if let p = list.first(where: { $0.stationRetrograde <= instant && instant < $0.stationDirect }) {
            return make(planet, .retrograde, p, from: p.stationRetrograde, to: p.stationDirect, target: p.stationDirect, at: instant)
        }
        if let p = list.first(where: { $0.stationDirect <= instant && instant < $0.postShadowEnd }) {
            return make(planet, .postShadow, p, from: p.stationDirect, to: p.postShadowEnd, target: p.postShadowEnd, at: instant)
        }
        guard let next = list.first(where: { $0.stationRetrograde > instant }) else { return nil }
        if instant >= next.preShadowStart {
            return make(planet, .preShadow, next, from: next.preShadowStart, to: next.stationRetrograde, target: next.stationRetrograde, at: instant)
        }
        guard let previous = list.last(where: { $0.postShadowEnd <= instant }) else { return nil }
        return make(planet, .direct, next, from: previous.postShadowEnd, to: next.stationRetrograde, target: next.stationRetrograde, at: instant)
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

    private func make(
        _ planet: Planet, _ stage: CycleStatus.Stage, _ period: RetrogradePeriod,
        from start: Date, to end: Date, target: Date, at instant: Date
    ) -> CycleStatus {
        let firstDay = CalendarDay(start, in: calendar)
        let today = CalendarDay(instant, in: calendar)
        let progress = instant.timeIntervalSince(start) / end.timeIntervalSince(start)
        return CycleStatus(
            planet: planet, stage: stage, period: period, windowStart: start, windowEnd: end, countdownTarget: target,
            day: firstDay.days(to: today) + 1,
            totalDays: firstDay.days(to: CalendarDay(end, in: calendar)) + 1,
            daysUntilTarget: max(today.days(to: CalendarDay(target, in: calendar)), 0),
            progress: min(max(progress, 0), 1)
        )
    }
}
