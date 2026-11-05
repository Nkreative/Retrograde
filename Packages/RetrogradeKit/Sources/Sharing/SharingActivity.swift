import Foundation
import Observation
import RetroCore

/// What was shared: the app, or a Calendar day's insight.
public enum SharedItem: Codable, Hashable, Sendable {
    case app
    /// The day as `yyyy-MM-dd`.
    case dailyInsight(day: String)

    public static func dailyInsight(_ day: CalendarDay) -> SharedItem { .dailyInsight(day: day.description) }

    public var insightDay: CalendarDay? {
        if case let .dailyInsight(day) = self { CalendarDay(iso: day) } else { nil }
    }
}

/// One share the person finished in the iOS share sheet.
public struct ShareRecord: Codable, Equatable, Sendable {
    public let item: SharedItem
    public let sharedAt: Date

    public init(item: SharedItem, sharedAt: Date) {
        self.item = item
        self.sharedAt = sharedAt
    }
}

/// The person’s sharing history, kept on the device and listed on the Overview. A share is
/// recorded only when iOS reports the share sheet's action as completed (sent, posted, copied or
/// saved); a cancelled or failed one is not. iOS doesn't say who received anything or whether it
/// arrived, so neither is claimed, and nothing about the destination app or recipients is kept.
@MainActor
@Observable
public final class SharingActivity {
    public private(set) var records: [ShareRecord] = []
    @ObservationIgnored private let defaults: UserDefaults?

    public static let storageKey = "sharing.activity.v1"
    /// Oldest entries are dropped past this, to keep the history small.
    public static let limit = 200

    /// `defaults` nil keeps the history in memory only (tests, previews).
    public init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([ShareRecord].self, from: data) {
            records = saved
        }
    }

    /// Called when the share sheet closes, with whether iOS reported the action as completed.
    public func shareSheetFinished(_ item: SharedItem, completed: Bool, at date: Date = .now) {
        guard completed else { return }
        records.append(ShareRecord(item: item, sharedAt: date))
        if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
        persist()
    }

    /// The latest finished shares, newest first.
    public func recent(_ count: Int) -> [ShareRecord] {
        Array(records.suffix(count).reversed())
    }

    public var appShareCount: Int { records.filter { $0.item == .app }.count }

    /// Days whose insight was shared, most recently shared first, each once.
    public var sharedInsightDays: [CalendarDay] {
        var seen = Set<CalendarDay>()
        return records.reversed().compactMap(\.item.insightDay).filter { seen.insert($0).inserted }
    }

    private func persist() {
        guard let defaults, let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
