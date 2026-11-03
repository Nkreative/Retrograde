import RetroCore

/// Everything the Calendar shows for one day, decided by a single access rule: if the day is
/// unlocked (free window or Premium) every detail section is included; if not, none are and the
/// one locked panel covers them all. Date, level and markers are always visible.
public struct DayDetailContent: Sendable {
    public enum Details: Sendable {
        /// Insights, events, habit and the other planets retrograde that day.
        case unlocked(insight: DailyInsight, otherRetrogrades: [IntensityCalculator.RetrogradeOnDay])
        /// One paywall for all details. `freeFrom` is when a future day enters the free window.
        case locked(freeFrom: CalendarDay?, preview: DailyInsight.Row?)
    }

    public let day: CalendarDay
    public let level: IntensityLevel
    /// Planets retrograde on the day, Mercury included (shown with the month header).
    public let retrogradeCount: Int
    public let details: Details

    public var retrogradeLabel: String { Self.retrogradeLabel(retrogradeCount) }

    public static func retrogradeLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "Retrograde" : "Retrogrades")"
    }

    /// Nil outside the verified data.
    public static func make(
        day: CalendarDay, today: CalendarDay, isPremium: Bool,
        policy: CalendarAccessPolicy, intensity: IntensityCalculator
    ) -> DayDetailContent? {
        guard let reading = intensity.intensity(on: day) else { return nil }
        let retrogrades = intensity.retrogrades(on: day)
        let insight = DailyInsightCopy.insight(for: reading)
        let details: Details = policy.detailsUnlocked(day, today: today, isPremium: isPremium)
            ? .unlocked(insight: insight, otherRetrogrades: retrogrades.filter { $0.planet != .mercury })
            : .locked(freeFrom: policy.freeFrom(day, today: today), preview: insight.rows.first)
        return DayDetailContent(day: day, level: reading.level, retrogradeCount: retrogrades.count, details: details)
    }
}
