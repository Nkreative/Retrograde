import Foundation

/// Which calendar days show their full details. Free: a rolling window of today plus the next
/// three days (local time), renewed every day — not a one-time trial. Premium: every covered day.
/// Every day keeps its visible markers and intensity level regardless.
public struct CalendarAccessPolicy: Sendable {
    /// Days after today included free (today + 3 = four days).
    public let freeDaysAhead: Int

    public static let launch = CalendarAccessPolicy(freeDaysAhead: 3)

    public init(freeDaysAhead: Int) {
        self.freeDaysAhead = freeDaysAhead
    }

    public func freeWindow(today: CalendarDay) -> ClosedRange<CalendarDay> {
        today...today.adding(days: freeDaysAhead)
    }

    public func detailsUnlocked(_ day: CalendarDay, today: CalendarDay, isPremium: Bool) -> Bool {
        isPremium || freeWindow(today: today).contains(day)
    }

    /// For a future locked day, the first day it becomes free ("Come back Nov 4"); nil for past days.
    public func freeFrom(_ day: CalendarDay, today: CalendarDay) -> CalendarDay? {
        day > today ? day.adding(days: -freeDaysAhead) : nil
    }
}

/// The collapsed calendar strip: seven consecutive days starting today (no past days), stepping
/// forward in blocks of seven, so the week containing today never has gaps.
public enum RollingWeek {
    public static func days(from start: CalendarDay, block: Int) -> [CalendarDay] {
        (0..<7).map { start.adding(days: block * 7 + $0) }
    }

    /// The block (0 = starting today) containing `day`; days before `start` belong to block 0.
    public static func block(containing day: CalendarDay, from start: CalendarDay) -> Int {
        max(start.days(to: day), 0) / 7
    }
}

/// The weeks shown for a month: full weeks from the person's first weekday, including the
/// neighbouring months' days that complete the first and last rows.
public struct MonthGrid: Sendable {
    public let year: Int
    public let month: Int
    /// Rows of seven days.
    public let weeks: [[CalendarDay]]

    public init(year: Int, month: Int, firstWeekday: Int) {
        self.year = year
        self.month = month
        let first = CalendarDay(year: year, month: month, day: 1)
        let lead = (first.weekday - firstWeekday + 7) % 7
        var day = first.adding(days: -lead)
        var weeks: [[CalendarDay]] = []
        repeat {
            weeks.append((0..<7).map { day.adding(days: $0) })
            day = day.adding(days: 7)
        } while day.month == month && day.year == year
        self.weeks = weeks
    }

    public func contains(_ day: CalendarDay) -> Bool { day.year == year && day.month == month }

    /// The row containing `day`, if it's on this grid.
    public func week(containing day: CalendarDay) -> [CalendarDay]? { weeks.first { $0.contains(day) } }

    public var id: ID { ID(year: year, month: month) }

    public struct ID: Hashable, Comparable, Sendable {
        public let year: Int
        public let month: Int

        public init(year: Int, month: Int) {
            self.year = year
            self.month = month
        }

        public init(_ day: CalendarDay) {
            self.init(year: day.year, month: day.month)
        }

        public func adding(months: Int) -> ID {
            let index = year * 12 + (month - 1) + months
            return ID(year: index / 12, month: index % 12 + 1)
        }

        public static func < (a: Self, b: Self) -> Bool { (a.year, a.month) < (b.year, b.month) }
    }
}

extension CalendarDay {
    /// 1 = Sunday … 7 = Saturday (Gregorian).
    public var weekday: Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.component(.weekday, from: start(in: utc))
    }
}
