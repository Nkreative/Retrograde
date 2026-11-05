import Foundation
import RetroCore

/// One alert Retrograde asks iOS to show.
public struct PlannedNotification: Equatable, Sendable {
    /// Stable per event (e.g. "mercury-2026-10-24.retrograde.lead-3d"): the iOS request id and the
    /// history id, so rescheduling replaces rather than duplicates.
    public let id: String
    public let kind: NotificationKind
    public let title: String
    public let body: String
    public let fireDate: Date
    public let destination: NotificationDestination

    public var record: NotificationRecord {
        NotificationRecord(id: id, kind: kind, title: title, body: body, fireDate: fireDate, destination: destination)
    }
}

/// Turns the verified retrograde periods and the person's choices into the alerts to schedule,
/// in their calendar and time zone. Pure: the same inputs always give the same plan.
///
/// | Alert | When (local time) | Opens |
/// |---|---|---|
/// | Turns retrograde / direct | the exact moment if 09:00–21:00; earlier → 09:00 that day; later → 09:00 next day (never before the event) | Calendar, that day |
/// | 2 weeks / 3 days before | 09:00, that many calendar days before the event's day | Calendar, the event's day |
/// | New cycle's kit | 18:00 on or after the moment the kit rolls over (station retrograde) | Survival Kit |
/// | Unfinished tasks | every other day at 18:00 from the kit's start until the post-shadow ends, while tasks the person can open remain | Survival Kit |
public struct NotificationPlanner: Sendable {
    /// iOS keeps only the soonest 64 pending local notifications per app; stay under it.
    public static let pendingLimit = 60
    /// How far ahead to plan. The schedule is rebuilt on every launch and return to the app.
    public static let horizonDays = 400

    static let morningHour = 9
    static let eveningHour = 18
    static let latestHour = 21

    public let periods: [RetrogradePeriod]
    public let calendar: Calendar

    public init(periods: [RetrogradePeriod], calendar: Calendar) {
        self.periods = periods
        self.calendar = calendar
    }

    /// The alerts to schedule after `now`, soonest first, at most `pendingLimit`.
    /// - Parameter remainingTasks: tasks the person can open and hasn't finished in a cycle.
    public func plan(enabled: Set<NotificationKind>, remainingTasks: (RetrogradePeriod) -> Int, now: Date) -> [PlannedNotification] {
        guard let horizon = calendar.date(byAdding: .day, value: Self.horizonDays, to: now) else { return [] }
        var plan: [PlannedNotification] = []
        for period in periods where period.postShadowEnd > now && period.preShadowStart < horizon {
            plan += alerts(for: period, enabled: enabled, remainingTasks: remainingTasks)
        }
        return plan
            .filter { $0.fireDate > now && $0.fireDate <= horizon }
            .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
            .prefix(Self.pendingLimit)
            .map { $0 }
    }

    private func alerts(for period: RetrogradePeriod, enabled: Set<NotificationKind>, remainingTasks: (RetrogradePeriod) -> Int) -> [PlannedNotification] {
        let planet = period.planet
        let retrogradeDay = CalendarDay(period.stationRetrograde, in: calendar)
        let directDay = CalendarDay(period.stationDirect, in: calendar)
        var result: [PlannedNotification] = []

        func add(_ suffix: String, _ kind: NotificationKind, _ content: NotificationCopy.Content, _ fire: Date?, _ destination: NotificationDestination) {
            guard let fire else { return }
            result.append(PlannedNotification(id: "\(period.id).\(suffix)", kind: kind, title: content.title, body: content.body,
                                              fireDate: fire, destination: destination))
        }

        if enabled.contains(.mercuryTurnsRetrograde) {
            add("retrograde", .mercuryTurnsRetrograde, NotificationCopy.turnsRetrograde(planet),
                eventTime(period.stationRetrograde), .calendarDay(retrogradeDay.description))
        }
        if enabled.contains(.mercuryTurnsDirect) {
            add("direct", .mercuryTurnsDirect, NotificationCopy.turnsDirect(planet),
                eventTime(period.stationDirect), .calendarDay(directDay.description))
        }
        for lead in NotificationKind.leadTimes.compactMap(\.day) {
            if enabled.contains(.beforeMercuryRetrograde) {
                add("retrograde.lead-\(lead)d", .beforeMercuryRetrograde, NotificationCopy.beforeRetrograde(planet, days: lead),
                    time(Self.morningHour, on: retrogradeDay.adding(days: -lead)), .calendarDay(retrogradeDay.description))
            }
            if enabled.contains(.beforeMercuryDirect) {
                add("direct.lead-\(lead)d", .beforeMercuryDirect, NotificationCopy.beforeDirect(planet, days: lead),
                    time(Self.morningHour, on: directDay.adding(days: -lead)), .calendarDay(directDay.description))
            }
        }
        if enabled.contains(.newCycleTasks) {
            add("kit.ready", .newCycleTasks, NotificationCopy.kitReady, eveningTime(onOrAfter: period.stationRetrograde), .survivalKit)
        }
        if enabled.contains(.unfinishedTasks) {
            let remaining = remainingTasks(period)
            if remaining > 0, let interval = NotificationKind.unfinishedReminderInterval.day {
                var day = retrogradeDay.adding(days: interval)
                while let fire = time(Self.eveningHour, on: day), fire < period.postShadowEnd {
                    add("kit.reminder.\(day)", .unfinishedTasks, NotificationCopy.unfinishedTasks(remaining: remaining), fire, .survivalKit)
                    day = day.adding(days: interval)
                }
            }
        }
        return result
    }

    /// `hour`:00 on `day` in the person's time zone (daylight saving handled by the calendar).
    func time(_ hour: Int, on day: CalendarDay) -> Date? {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day.start(in: calendar))
    }

    /// An event alert at a sociable hour and never before the event itself.
    func eventTime(_ instant: Date) -> Date? {
        let day = CalendarDay(instant, in: calendar)
        guard let morning = time(Self.morningHour, on: day), let night = time(Self.latestHour, on: day) else { return nil }
        if instant < morning { return morning }
        if instant <= night { return instant }
        return time(Self.morningHour, on: day.adding(days: 1))
    }

    /// The first 18:00 at or after `instant`.
    func eveningTime(onOrAfter instant: Date) -> Date? {
        let day = CalendarDay(instant, in: calendar)
        guard let evening = time(Self.eveningHour, on: day) else { return nil }
        return instant <= evening ? evening : time(Self.eveningHour, on: day.adding(days: 1))
    }
}
