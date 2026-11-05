import Editorial
import Foundation
import RetroCore

/// What "Share Retrograde" sends: the invitation line from the approved Figma share screen and,
/// once it's configured, the App Store link. Without a link only the line is shared — never a
/// made-up address.
public struct AppInvitation: Equatable, Sendable {
    public static let message = "I’m getting through Mercury retrograde with Retrograde. The same cosmic vibes, minus the awkward small talk."

    public let appStoreURL: URL?

    public init(appStoreURL: URL?) {
        self.appStoreURL = appStoreURL
    }

    /// The message and, when there is one, the link on its own line.
    public var text: String {
        appStoreURL.map { "\(Self.message)\n\($0.absoluteString)" } ?? Self.message
    }
}

/// A day's insight as a share card: the same date, level, summary and habit the Calendar shows
/// for that day. Only a day whose details the person can see can be shared, so a locked day
/// never leaks into an image.
public struct InsightShareCard: Equatable, Identifiable, Sendable {
    public let day: CalendarDay
    public let level: IntensityLevel
    public let summary: String
    public let habit: String

    public var id: CalendarDay { day }

    /// Nil when the day's details are locked.
    public init?(_ content: DayDetailContent) {
        guard case let .unlocked(insight, _) = content.details else { return nil }
        day = content.day
        level = content.level
        summary = insight.summary
        habit = insight.habit.text
    }

    public var levelName: String { DailyInsightCopy.levelName(level) }

    /// "03 / 04", as on the Calendar.
    public var levelPosition: String { String(format: "%02d / 04", level.rawValue) }

    /// "Wednesday, Nov 4, 2026": with the year, since the card is read away from the app.
    public func dateTitle(locale: Locale = .autoupdatingCurrent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.abbreviated).day().year()
        style.locale = locale
        style.timeZone = calendar.timeZone
        return day.start(in: calendar).formatted(style)
    }

    /// The card in words: shared alongside the image, and read by VoiceOver for it.
    public func text(locale: Locale = .autoupdatingCurrent, appStoreURL: URL? = nil) -> String {
        var lines = [
            dateTitle(locale: locale),
            "Retrograde intensity: \(levelName) (\(level.rawValue) of 4)",
            summary,
            "Good habit for this day: \(habit)",
            "— Retrograde",
        ]
        if let appStoreURL { lines.append(appStoreURL.absoluteString) }
        return lines.joined(separator: "\n")
    }
}
