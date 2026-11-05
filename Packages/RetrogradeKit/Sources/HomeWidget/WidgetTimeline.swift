import Foundation
import RetroCore

/// When the widget changes, worked out ahead so iOS can show it without running Retrograde:
/// now, every local midnight (the countdown and day label move on) and the exact moment a stage
/// changes, for the next two days.
///
/// iOS is asked for a fresh timeline after the next midnight, so about once a day. The second day
/// is a safety margin in case iOS refreshes late. A time zone change is picked up at that refresh,
/// or straight away when Retrograde is open (the app asks iOS to reload the widget).
public struct WidgetTimeline: Sendable {
    public struct Entry: Equatable, Sendable {
        public let date: Date
        /// nil when the bundled sky data doesn't cover this date.
        public let content: WidgetContent?
    }

    public static let horizonDays = 2

    private let calculator: CycleCalculator
    private let calendar: Calendar
    private let planet: Planet

    public init(calculator: CycleCalculator, calendar: Calendar, planet: Planet = .mercury) {
        self.calculator = calculator
        self.calendar = calendar
        self.planet = planet
    }

    public func content(at instant: Date) -> WidgetContent? {
        calculator.status(of: planet, at: instant).flatMap(WidgetContent.init(status:))
    }

    /// Entries from `now`, soonest first, with no two at the same instant.
    public func entries(from now: Date) -> [Entry] {
        let today = CalendarDay(now, in: calendar)
        let end = today.adding(days: Self.horizonDays).start(in: calendar)
        var dates: Set<Date> = [now]
        for offset in 1...Self.horizonDays {
            dates.insert(today.adding(days: offset).start(in: calendar))
        }
        // Stage changes before the horizon (a short stage could end twice within it).
        var instant = now
        while let change = calculator.status(of: planet, at: instant)?.stageEnd, change > instant, change < end {
            dates.insert(change)
            instant = change
        }
        return dates.sorted().map { Entry(date: $0, content: content(at: $0)) }
    }

    /// When to ask iOS for the next timeline: the next local midnight.
    public func refreshDate(after now: Date) -> Date {
        CalendarDay(now, in: calendar).adding(days: 1).start(in: calendar)
    }
}
