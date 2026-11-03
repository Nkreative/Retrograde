import Foundation

/// A date on the wall calendar (no time, no time zone), e.g. 2026-11-03.
/// Convert instants with the person's `Calendar` so "today" follows their time zone.
public struct CalendarDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, in calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Parses `yyyy-MM-dd`.
    public init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    public func start(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> CalendarDay {
        CalendarDay(Self.utc.date(byAdding: .day, value: days, to: start(in: Self.utc))!, in: Self.utc)
    }

    /// Whole days from `self` to `other` (negative if `other` is earlier).
    public func days(to other: CalendarDay) -> Int {
        Self.utc.dateComponents([.day], from: start(in: Self.utc), to: other.start(in: Self.utc)).day!
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    // Day arithmetic in UTC: no daylight-saving gaps, so every day is 24 h.
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}
