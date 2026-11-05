import Foundation
import Observation

/// Whether the Overview offers to add the Home Screen widget. Retrograde asks iOS which of its
/// widgets are placed (best effort: iOS's list has been seen to lag behind, keeping a removed
/// widget), so this only decides whether to *offer*; nothing ever claims a widget is installed.
///
/// - iOS lists at least one Retrograde widget → the prompts hide.
/// - iOS lists none → they may show again. The dashboard tip, if dismissed with ✕, stays hidden
///   until a widget has been listed and then removed.
/// - A check that fails isn't recorded, so the last answer stands.
@MainActor
@Observable
public final class WidgetPrompt {
    /// The last answer from iOS: at least one widget listed.
    public private(set) var widgetListed: Bool
    public private(set) var tipDismissed: Bool
    @ObservationIgnored private let defaults: UserDefaults?

    public static let listedKey = "widgetPrompt.widgetListed"
    public static let dismissedKey = "widgetPrompt.tipDismissed"
    /// Where the dashboard tip's ✕ was saved before this existed (M13.1).
    public static let legacyDismissedKey = "overview.widgetTipHidden"

    /// `defaults` nil keeps it in memory only (tests, previews).
    public init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        widgetListed = defaults?.bool(forKey: Self.listedKey) ?? false
        tipDismissed = (defaults?.object(forKey: Self.dismissedKey) as? Bool) ?? defaults?.bool(forKey: Self.legacyDismissedKey) ?? false
    }

    /// The Overview's "Add to Home Screen" pill.
    public var offersWidget: Bool { !widgetListed }
    /// The dashboard's widget tip.
    public var showsTip: Bool { !widgetListed && !tipDismissed }

    public func dismissTip() {
        tipDismissed = true
        persist()
    }

    /// A check that completed: how many Retrograde widgets iOS listed (any size, any number).
    public func record(widgetCount: Int) {
        if widgetCount > 0 {
            widgetListed = true
        } else {
            if widgetListed { tipDismissed = false } // listed, then removed: the tip may return
            widgetListed = false
        }
        persist()
    }

    private func persist() {
        defaults?.set(widgetListed, forKey: Self.listedKey)
        defaults?.set(tipDismissed, forKey: Self.dismissedKey)
    }
}
