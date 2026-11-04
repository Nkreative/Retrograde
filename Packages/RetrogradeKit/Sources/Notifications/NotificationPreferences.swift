import Foundation
import Observation

/// The alerts a person can choose. M11 schedules from these; Settings only stores them.
public enum NotificationKind: String, CaseIterable, Codable, Sendable {
    /// A retrograde begins (a planet stations retrograde).
    case retrogradeStarts
    /// A retrograde ends (a planet turns direct).
    case retrogradeEnds
    /// One daily note with the day's intensity and habit.
    case dailyGuidance

    /// On for a fresh install: the two Mercury turning points; daily guidance is opt-in.
    public var enabledByDefault: Bool { self != .dailyGuidance }
}

/// Saved notification choices. Changing them never asks for iOS permission; M11 asks when
/// delivery exists and only for kinds the person turned on.
@MainActor
@Observable
public final class NotificationPreferences {
    public private(set) var enabled: Set<NotificationKind>
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "notifications.enabled") {
        self.defaults = defaults
        self.key = key
        if let saved = defaults.array(forKey: key) as? [String] {
            enabled = Set(saved.compactMap(NotificationKind.init(rawValue:)))
        } else {
            enabled = Set(NotificationKind.allCases.filter(\.enabledByDefault))
        }
    }

    public func isEnabled(_ kind: NotificationKind) -> Bool { enabled.contains(kind) }

    public func set(_ kind: NotificationKind, _ on: Bool) {
        if on { enabled.insert(kind) } else { enabled.remove(kind) }
        defaults.set(enabled.map(\.rawValue).sorted(), forKey: key)
    }
}
