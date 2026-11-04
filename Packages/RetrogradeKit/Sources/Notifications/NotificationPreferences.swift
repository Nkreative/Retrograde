import Foundation
import Observation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// The alerts a person can choose, as in the approved Notifications mockup. M11 schedules from
/// these; nothing here schedules or asks for permission.
public enum NotificationKind: String, CaseIterable, Codable, Sendable {
    // Mercury
    case mercuryTurnsRetrograde
    case mercuryTurnsDirect
    /// Lead-time alerts before Mercury turns retrograde (see `leadTimes`).
    case beforeMercuryRetrograde
    /// Lead-time alerts before Mercury turns direct (see `leadTimes`).
    case beforeMercuryDirect
    // Survival Kit
    case newCycleTasks
    case unfinishedTasks

    public var enabledByDefault: Bool {
        switch self {
        case .mercuryTurnsRetrograde, .mercuryTurnsDirect, .beforeMercuryRetrograde, .newCycleTasks: true
        case .beforeMercuryDirect, .unfinishedTasks: false
        }
    }

    /// How long before the event the "before" alerts fire: 2 weeks and 3 days (approved mockup).
    public static let leadTimes: [DateComponents] = [DateComponents(day: 14), DateComponents(day: 3)]

    /// Unfinished-task reminders repeat every other day.
    public static let unfinishedReminderInterval = DateComponents(day: 2)
}

/// Saved notification choices. Settings edits a draft and saves it; M11 reads `enabled`.
@MainActor
@Observable
public final class NotificationPreferences {
    public private(set) var enabled: Set<NotificationKind>
    @ObservationIgnored private let defaults: UserDefaults

    public static let storageKey = "notifications.preferences.v2"
    /// M9c's first version (retrogradeStarts / retrogradeEnds / dailyGuidance).
    static let legacyKey = "notifications.enabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.array(forKey: Self.storageKey) as? [String] {
            enabled = Set(saved.compactMap(NotificationKind.init(rawValue:)))
        } else if let legacy = defaults.array(forKey: Self.legacyKey) as? [String] {
            enabled = Self.migrate(legacy: Set(legacy))
            defaults.set(enabled.map(\.rawValue).sorted(), forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.legacyKey)
        } else {
            enabled = Self.defaults
        }
    }

    public static var defaults: Set<NotificationKind> { Set(NotificationKind.allCases.filter(\.enabledByDefault)) }

    /// Carries over the first version's choices: its "starts" and "ends" toggles become Mercury
    /// turning retrograde / direct (kept as saved, including off). New options start at their
    /// defaults. "Daily guidance" has no counterpart in the approved set and is dropped.
    static func migrate(legacy: Set<String>) -> Set<NotificationKind> {
        var result = defaults
        for (old, new) in [("retrogradeStarts", NotificationKind.mercuryTurnsRetrograde), ("retrogradeEnds", .mercuryTurnsDirect)] {
            if legacy.contains(old) { result.insert(new) } else { result.remove(new) }
        }
        return result
    }

    public func isEnabled(_ kind: NotificationKind) -> Bool { enabled.contains(kind) }

    public func save(_ choices: Set<NotificationKind>) {
        enabled = choices
        defaults.set(choices.map(\.rawValue).sorted(), forKey: Self.storageKey)
    }
}

/// Whether iOS lets Retrograde show notifications. Reading it never prompts.
public enum NotificationAuthorization: Equatable, Sendable {
    /// Never asked — Retrograde asks once alerts exist (M11).
    case notDetermined
    /// Turned off for Retrograde in iOS Settings.
    case denied
    /// Delivered quietly to Notification Center; iOS lets the app ask once to upgrade to full alerts.
    case provisional
    /// Allowed (including ephemeral).
    case allowed

    /// Ask iOS only when it has never asked (or to upgrade quiet delivery): a person who declined
    /// is never prompted again.
    public var shouldPrompt: Bool { self == .notDetermined || self == .provisional }

    #if canImport(UserNotifications)
    public init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .provisional: self = .provisional
        default: self = .allowed
        }
    }
    #endif
}
