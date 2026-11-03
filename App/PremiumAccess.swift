import Observation
import SwiftUI

/// Whether the person has Premium. Until StoreKit arrives (M9) this is always free,
/// except in debug builds launched with `-premium YES` for review.
@MainActor
@Observable
final class PremiumAccess {
    private(set) var isPremium: Bool

    init() {
        #if DEBUG
        isPremium = UserDefaults.standard.bool(forKey: "premium")
        #else
        isPremium = false
        #endif
    }
}
