import AstroData
import Editorial
import Foundation
import Persistence
import RetroCore
import SurvivalKit
import Testing
@testable import Entitlements

let t0 = Date(timeIntervalSince1970: 1_793_750_400) // 2026-11-03 12:00 UTC
let day: TimeInterval = 86_400

// MARK: - Rules (every StoreKit state)

@Suite struct EntitlementRuleTests {
    private func yearly(_ state: YearlySubscription.State, expires: TimeInterval = 300 * day, renew: Bool = true, grace: TimeInterval? = nil) -> YearlySubscription {
        YearlySubscription(state: state, expiresAt: t0 + expires, willAutoRenew: renew, gracePeriodEndsAt: grace.map { t0 + $0 })
    }

    private func status(lifetime: Bool = false, _ y: YearlySubscription? = nil, at now: Date = t0) -> PremiumStatus {
        EntitlementRules.status(of: EntitlementSnapshot(ownsLifetime: lifetime, yearly: y), at: now)
    }

    @Test func freeWithoutPurchases() {
        #expect(status() == .free)
    }

    @Test func yearlyUsesAppleVerifiedDates() {
        // The renewal date is whatever Apple verified — not purchase date + 365 days.
        let s = status(yearly(.subscribed, expires: 17 * day))
        #expect(s == .yearly(until: t0 + 17 * day, willRenew: true))
        #expect(s.isPremium)
        #expect(status(yearly(.subscribed, renew: false)) == .yearly(until: t0 + 300 * day, willRenew: false)) // cancelled, still active
    }

    @Test func neverHonoursAPassedExpiry() {
        #expect(status(yearly(.subscribed, expires: -1)) == .yearlyExpired(on: t0 - 1))
    }

    @Test func gracePeriodKeepsPremiumUntilItEnds() {
        let grace = yearly(.inGracePeriod, expires: -2 * day, grace: 14 * day)
        #expect(status(grace) == .yearlyGracePeriod(until: t0 + 14 * day))
        #expect(status(grace).isPremium)
        #expect(status(grace, at: t0 + 15 * day) == .yearlyBillingIssue)
    }

    @Test func billingRetryExpiryAndRevocationDoNotUnlock() {
        #expect(!status(yearly(.inBillingRetry, expires: -1)).isPremium)
        #expect(status(yearly(.expired, expires: -1)) == .yearlyExpired(on: t0 - 1))
        #expect(status(yearly(.revoked)) == .free) // refunded
    }

    @Test func lifetimeTakesPrecedence() {
        #expect(status(lifetime: true) == .lifetime(yearlyStillRenewing: false))
        #expect(status(lifetime: true, yearly(.subscribed)) == .lifetime(yearlyStillRenewing: true))
        #expect(status(lifetime: true, yearly(.subscribed, renew: false)) == .lifetime(yearlyStillRenewing: false))
        #expect(status(lifetime: true, yearly(.expired, expires: -1)) == .lifetime(yearlyStillRenewing: false))
        #expect(status(lifetime: true, yearly(.revoked)) == .lifetime(yearlyStillRenewing: false))
        #expect(status(lifetime: true, at: t0 + 50 * 365 * day).isPremium) // never expires
    }

    @Test func refundedLifetimeFallsBackToYearly() {
        // A refunded Lifetime isn't in the snapshot (ownsLifetime == false); an active Yearly still counts.
        #expect(status(lifetime: false, yearly(.subscribed)).isPremium)
    }
}

// MARK: - Store

/// A source whose answers the test controls.
final class ScriptedSource: EntitlementSource, @unchecked Sendable {
    var snapshot = EntitlementSnapshot.none
    var failReads = false
    var purchaseOutcome = PurchaseOutcome.purchased
    var restoreCalls = 0
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self)

    func currentSnapshot() async throws -> EntitlementSnapshot {
        if failReads { throw URLError(.notConnectedToInternet) }
        return snapshot
    }

    func changes() -> AsyncStream<Void> { stream }

    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        purchaseCalls += 1
        if holdPurchases { await withCheckedContinuation { purchaseGate = $0 } }
        if failPurchase { throw URLError(.cannotConnectToHost) }
        if purchaseOutcome == .purchased {
            snapshot = plan == .lifetime ? EntitlementSnapshot(ownsLifetime: true)
                : EntitlementSnapshot(yearly: YearlySubscription(state: .subscribed, expiresAt: t0 + 365 * day, willAutoRenew: true))
        }
        return purchaseOutcome
    }

    func restore() async throws {
        restoreCalls += 1
        if failRestore { throw URLError(.notConnectedToInternet) }
    }

    var offerList: [PlanOffer] = [
        PlanOffer(plan: .lifetime, displayPrice: "$19.99"),
        PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year), introOffer: .freeTrial(.init(value: 1, unit: .week))),
    ]
    var failOffers = false
    var failPurchase = false
    var failRestore = false
    var purchaseCalls = 0
    /// When set, purchases wait here until the test resumes them.
    var purchaseGate: CheckedContinuation<Void, Never>?
    var holdPurchases = false

    func offers() async throws -> [PlanOffer] {
        if failOffers { throw URLError(.notConnectedToInternet) }
        return offerList
    }
}

/// Waits briefly for the store's change listener to apply an update.
@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@MainActor
@Suite struct EntitlementStoreTests {
    @Test func failedRefreshNeverRevokesVerifiedPremium() async {
        let source = ScriptedSource()
        let store = EntitlementStore(source: source, now: { t0 })
        source.snapshot = EntitlementSnapshot(ownsLifetime: true)
        await store.refresh()
        #expect(store.isPremium)
        source.failReads = true // offline / StoreKit unavailable
        source.snapshot = .none
        await store.refresh()
        #expect(store.isPremium)
        source.failReads = false // back online: StoreKit's answer wins
        await store.refresh()
        #expect(!store.isPremium)
    }

    @Test func pendingPurchaseUnlocksWhenApproved() async throws {
        let source = ScriptedSource()
        let store = EntitlementStore(source: source, now: { t0 })
        await store.start()
        source.purchaseOutcome = .pending
        #expect(try await store.purchase(.lifetime) == .pending)
        #expect(store.isPurchasePending && !store.isPremium)
        source.snapshot = EntitlementSnapshot(ownsLifetime: true) // parent approves
        source.continuation.yield()
        #expect(await eventually { store.isPremium && !store.isPurchasePending })
    }

    @Test func cancelledPurchaseChangesNothing() async throws {
        let source = ScriptedSource()
        source.purchaseOutcome = .cancelled
        let store = EntitlementStore(source: source, now: { t0 })
        #expect(try await store.purchase(.yearly) == .cancelled)
        #expect(!store.isPremium && !store.isPurchasePending)
    }

    @Test func restoreResyncsThenRereads() async throws {
        let source = ScriptedSource()
        let store = EntitlementStore(source: source, now: { t0 })
        source.snapshot = EntitlementSnapshot(ownsLifetime: true) // e.g. after reinstall, before re-reading
        try await store.restorePurchases()
        #expect(source.restoreCalls == 1)
        #expect(store.status == .lifetime(yearlyStillRenewing: false))
    }

    @Test func listensForChangesAfterStart() async {
        let source = ScriptedSource()
        let store = EntitlementStore(source: source, now: { t0 })
        await store.start()
        source.snapshot = EntitlementSnapshot(ownsLifetime: true) // e.g. bought on another device
        source.continuation.yield()
        #expect(await eventually { store.isPremium })
        source.snapshot = .none // refunded
        source.continuation.yield()
        #expect(await eventually { !store.isPremium })
    }
}

// MARK: - Debug simulator

@MainActor
@Suite struct SimulatorTests {
    @Test func walksEveryState() async throws {
        let sim = SimulatedEntitlementSource(storage: InMemoryAccountStorage(), now: { t0 })
        let store = EntitlementStore(source: sim, now: { t0 })
        _ = try await store.purchase(.yearly)
        #expect(store.isPremium)
        sim.turnOffAutoRenew(); await store.refresh()
        guard case .yearly(_, willRenew: false) = store.status else { Issue.record("expected cancelled-but-active"); return }
        sim.enterGracePeriod(); await store.refresh()
        #expect(store.isPremium)
        sim.enterBillingRetry(); await store.refresh()
        #expect(store.status == .yearlyBillingIssue)
        sim.expireYearly(); await store.refresh()
        #expect(!store.isPremium)
        _ = try await store.purchase(.lifetime)
        #expect(store.status == .lifetime(yearlyStillRenewing: false))
        sim.refund(.lifetime); await store.refresh()
        #expect(!store.isPremium)
    }

    @Test func persistsAcrossRelaunch() async throws {
        let suite = "entitlements-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func relaunch() async -> EntitlementStore {
            let store = EntitlementStore(source: SimulatedEntitlementSource(storage: DefaultsAccountStorage(defaults: defaults, key: "account"), now: { t0 }), now: { t0 })
            await store.refresh()
            return store
        }
        _ = try await relaunch().purchase(.yearly)
        #expect(await relaunch().isPremium)
        SimulatedEntitlementSource(storage: DefaultsAccountStorage(defaults: defaults, key: "account"), now: { t0 }).expireYearly()
        guard case .yearlyExpired = await relaunch().status else { Issue.record("expiry should persist"); return }
    }
}

// MARK: - End to end with the access rules

@MainActor
@Suite struct EntitlementAccessTests {
    let kit = SurvivalKit.for(.mercury)!
    let policy = TaskAccessPolicy.launch
    let today = CalendarDay(year: 2026, month: 11, day: 3)

    private func unlockedTaskCount(_ premium: Bool) -> Int {
        kit.sections.reduce(0) { total, section in
            total + section.tasks.indices.filter { policy.visibility(ofTaskAt: $0, isPremium: premium) == .unlocked }.count
        }
    }

    private func unlockedDays(_ premium: Bool, intensity: IntensityCalculator) -> Int {
        var count = 0
        var d = CalendarDay(year: 2025, month: 1, day: 1)
        while d <= CalendarDay(year: 2030, month: 12, day: 31) {
            if case .unlocked = DayDetailContent.make(day: d, today: today, isPremium: premium, policy: .launch, intensity: intensity)!.details { count += 1 }
            d = d.adding(days: 1)
        }
        return count
    }

    @Test func upgradeAndDowngradeFlipEveryLockImmediately() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let intensity = IntensityCalculator(ephemeris: try BundledEphemeris.load(), calendar: utc)
        let sim = SimulatedEntitlementSource(storage: InMemoryAccountStorage(), now: { t0 })
        let store = EntitlementStore(source: sim, now: { t0 })

        #expect(unlockedTaskCount(store.isPremium) == 4)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 4)
        _ = try await store.purchase(.yearly)
        #expect(unlockedTaskCount(store.isPremium) == 27)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 2191)
        sim.expireYearly(); await store.refresh()
        #expect(unlockedTaskCount(store.isPremium) == 4)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 4)
    }

    @Test func downgradeKeepsCompletionAndTheTwentySevenCount() async throws {
        let completions = CompletionStore(container: try CompletionStore.makeContainer(inMemory: true))
        let sim = SimulatedEntitlementSource(storage: InMemoryAccountStorage(), now: { t0 })
        let store = EntitlementStore(source: sim, now: { t0 })
        _ = try await store.purchase(.yearly)
        completions.markDone("mercury.communication.wait-ten-seconds", in: "mercury-2026-10-24") // Premium-only task
        completions.markDone("mercury.communication.breathe-first", in: "mercury-2026-10-24")
        completions.markDone("mercury.tech.back-up-files", in: "mercury-2026-06-29") // earlier cycle
        sim.refund(.yearly); await store.refresh()
        #expect(!store.isPremium)
        // "X of 27 done" keeps counting completed Premium tasks after a downgrade.
        #expect(completions.completedTaskIDs(in: "mercury-2026-10-24").count == 2)
        #expect(completions.completedTaskIDs(in: "mercury-2026-06-29") == ["mercury.tech.back-up-files"])
    }
}
