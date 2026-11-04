import Observation

/// The paywall's purchase logic, separate from its layout: loading offers, the selected plan,
/// purchase and restore, and the states in between. One action at a time — a purchase or restore
/// in progress blocks another.
@MainActor
@Observable
public final class PurchaseFlow {
    public enum Phase: Equatable, Sendable {
        case loading
        case ready
        /// No product could be loaded (offline, App Store unavailable).
        case unavailable
        case purchasing(PremiumPlan)
        case restoring
        /// Waiting for Ask to Buy or similar approval; Premium unlocks when it's approved.
        case pending
        case purchaseFailed
        case restoreFailed
        /// Restore worked but this Apple Account has no Premium purchase.
        case nothingToRestore
    }

    /// Lifetime is selected by default (approved design).
    public private(set) var selectedPlan: PremiumPlan = .lifetime
    public private(set) var phase: Phase = .loading
    public private(set) var offers: [PremiumPlan: PlanOffer] = [:]

    @ObservationIgnored private let store: EntitlementStore

    public init(store: EntitlementStore) {
        self.store = store
    }

    public var selectedOffer: PlanOffer? { offers[selectedPlan] }

    public var isBusy: Bool {
        switch phase {
        case .loading, .purchasing, .restoring: true
        default: false
        }
    }

    public var canPurchase: Bool { !isBusy && phase != .pending && phase != .unavailable && selectedOffer != nil }

    public func load() async {
        guard phase != .ready || offers.isEmpty else { return }
        phase = .loading
        do {
            offers = Dictionary(uniqueKeysWithValues: try await store.offers().map { ($0.plan, $0) })
            if offers[selectedPlan] == nil, let available = PremiumPlan.paywallOrder.first(where: { offers[$0] != nil }) {
                selectedPlan = available
            }
            phase = offers.isEmpty ? .unavailable : .ready
        } catch {
            offers = [:]
            phase = .unavailable
        }
    }

    public func select(_ plan: PremiumPlan) {
        guard !isBusy, offers[plan] != nil else { return }
        selectedPlan = plan
        if phase == .purchaseFailed || phase == .restoreFailed || phase == .nothingToRestore { phase = .ready }
    }

    /// Buys the selected plan. Returns true once Premium is active (the paywall can close).
    @discardableResult
    public func purchase() async -> Bool {
        guard canPurchase else { return false }
        let plan = selectedPlan
        phase = .purchasing(plan)
        do {
            switch try await store.purchase(plan) {
            case .purchased:
                phase = .ready
                return store.isPremium
            case .pending:
                phase = .pending
                return false
            case .cancelled:
                phase = .ready
                return false
            }
        } catch {
            phase = .purchaseFailed
            return false
        }
    }

    /// Restores purchases. Returns true if Premium is active afterwards.
    @discardableResult
    public func restore() async -> Bool {
        guard !isBusy else { return false }
        phase = .restoring
        do {
            try await store.restorePurchases()
            phase = store.isPremium ? .ready : .nothingToRestore
            return store.isPremium
        } catch {
            phase = .restoreFailed
            return false
        }
    }

    #if DEBUG
    /// Review and screenshot aid only.
    public func debugShow(_ phase: Phase) {
        if phase == .unavailable { offers = [:] }
        self.phase = phase
    }
    #endif
}

extension PremiumPlan {
    /// Lifetime first, as in the approved paywall.
    public static let paywallOrder: [PremiumPlan] = [.lifetime, .yearly]
}
