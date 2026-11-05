import Foundation
import Observation

/// Where tapping a notification takes the person.
public enum NotificationDestination: Codable, Equatable, Sendable {
    /// A Calendar day, as `yyyy-MM-dd` (local).
    case calendarDay(String)
    /// A Survival Kit section id (e.g. "communication").
    case survivalKitSection(String)
    /// The Survival Kit tab.
    case survivalKit

    /// Key in an iOS notification's `userInfo` carrying `userInfoValue`.
    public static let userInfoKey = "retrograde.destination"

    /// A compact string form for the iOS notification (e.g. "calendarDay:2026-11-13").
    public var userInfoValue: String {
        switch self {
        case let .calendarDay(day): "calendarDay:\(day)"
        case let .survivalKitSection(id): "survivalKitSection:\(id)"
        case .survivalKit: "survivalKit"
        }
    }

    public init?(userInfoValue: String) {
        let parts = userInfoValue.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count) {
        case ("calendarDay", 2): self = .calendarDay(parts[1])
        case ("survivalKitSection", 2): self = .survivalKitSection(parts[1])
        case ("survivalKit", 1): self = .survivalKit
        default: return nil
        }
    }
}

/// One notification Retrograde scheduled for this person. An entry is recorded when the alert is
/// scheduled with iOS; the history never invents entries and never assumes iOS showed one.
public struct NotificationRecord: Codable, Equatable, Identifiable, Sendable {
    /// What is actually known about delivery.
    public enum Delivery: String, Codable, Sendable {
        /// Scheduled with iOS; its time hasn't come.
        case scheduled
        /// Its time has passed; whether iOS showed it is unknown (permission off, Focus, removed…).
        case due
        /// Confirmed by iOS: shown while the app was open, opened by the person, or listed among
        /// the delivered notifications iOS still keeps for the app.
        case delivered
    }

    /// Stable per event, e.g. "mercury-2026-10-24.retrograde.lead-3d"; also the iOS request id.
    /// Rescheduling the same event reuses it, so it never appears twice.
    public let id: String
    public let kind: NotificationKind
    public var title: String
    public var body: String
    /// When iOS is set to show it.
    public var fireDate: Date
    public var destination: NotificationDestination?
    public var deliveryConfirmedAt: Date?
    public var readAt: Date?

    public init(id: String, kind: NotificationKind, title: String, body: String, fireDate: Date, destination: NotificationDestination? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.destination = destination
    }

    public func delivery(at now: Date) -> Delivery {
        if deliveryConfirmedAt != nil { return .delivered }
        return fireDate <= now ? .due : .scheduled
    }

    public var isRead: Bool { readAt != nil }
}

/// Notification history, persisted on the device. The Notification Center shows only entries whose
/// time has come — future scheduled alerts stay hidden — newest first.
@MainActor
@Observable
public final class NotificationHistory {
    public private(set) var records: [NotificationRecord] = []
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let now: () -> Date

    public static let storageKey = "notifications.history.v1"

    /// `defaults` nil keeps history in memory only (previews, debug samples).
    public init(defaults: UserDefaults? = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults?.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([NotificationRecord].self, from: data) {
            records = saved
        }
    }

    /// Entries whose time has come, newest first.
    public var visible: [NotificationRecord] {
        let t = now()
        return records.filter { $0.delivery(at: t) != .scheduled }.sorted { $0.fireDate > $1.fireDate }
    }

    public var unreadCount: Int { visible.filter { !$0.isRead }.count }

    /// Adds an entry, or updates the existing one with the same id (rescheduling). An update keeps
    /// read and delivery state, unless the alert moved later than a confirmed delivery.
    public func record(_ record: NotificationRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) {
            var merged = record
            merged.readAt = records[i].readAt
            merged.deliveryConfirmedAt = records[i].deliveryConfirmedAt
            records[i] = merged
        } else {
            records.append(record)
        }
        persist()
    }

    /// Removes a scheduled entry that was cancelled before its time (e.g. the person turned it off).
    public func cancel(id: String) {
        guard let i = records.firstIndex(where: { $0.id == id }), records[i].delivery(at: now()) == .scheduled else { return }
        records.remove(at: i)
        persist()
    }

    /// Removes every entry still waiting for its time that isn't in `ids` (no longer scheduled: a
    /// preference turned off, permission withdrawn, the plan changed). Past entries stay.
    public func cancelScheduled(keeping ids: Set<String>) {
        let t = now()
        let before = records.count
        records.removeAll { $0.delivery(at: t) == .scheduled && !ids.contains($0.id) }
        if records.count != before { persist() }
    }

    /// Called when iOS reports the notification (shown in the app, or opened by the person).
    public func confirmDelivery(id: String) {
        update(id) { if $0.deliveryConfirmedAt == nil { $0.deliveryConfirmedAt = self.now() } }
    }

    public func markRead(id: String) {
        update(id) { if $0.readAt == nil { $0.readAt = self.now() } }
    }

    public func markAllRead() {
        let t = now()
        let ids = Set(visible.filter { !$0.isRead }.map(\.id))
        guard !ids.isEmpty else { return }
        for i in records.indices where ids.contains(records[i].id) { records[i].readAt = t }
        persist()
    }

    private func update(_ id: String, _ change: (inout NotificationRecord) -> Void) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        change(&records[i])
        persist()
    }

    private func persist() {
        guard let defaults else { return }
        defaults.set(try? JSONEncoder().encode(records), forKey: Self.storageKey)
    }

    #if DEBUG
    /// Debug screenshots only: replaces the in-memory history. Ignored when persisting.
    public func debugReplace(with records: [NotificationRecord]) {
        guard defaults == nil else { return }
        self.records = records
    }
    #endif
}
