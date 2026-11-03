import AstroData
import Editorial
import Foundation
import Persistence
import RetroCore
import SurvivalKit
import Testing
@testable import Entitlements

/// A movable clock so expiry can be tested without waiting a year.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_793_750_400) // 2026-11-03 12:00 UTC
    func advance(days: Double) { now += days * 86_400 }
}

@MainActor
private func makeStore(clock: TestClock, device: EntitlementPersistence = InMemoryEntitlementPersistence(),
                       account: EntitlementPersistence? = InMemoryEntitlementPersistence()) -> EntitlementStore {
    EntitlementStore(device: device, account: account, now: { clock.now })
}

@Suite struct EntitlementRuleTests {
    let t0 = Date(timeIntervalSince1970: 1_793_750_400)

    @Test func statuses() {
        let yearly = PremiumTransaction(plan: .yearly, purchasedAt: t0, expiresAt: t0 + 365 * 86_400)
        let lifetime = PremiumTransaction(plan: .lifetime, purchasedAt: t0, expiresAt: nil)
        #expect(EntitlementRules.status(of: [], at: t0) == .free)
        #expect(EntitlementRules.status(of: [yearly], at: t0 + 10) == .yearly(renewsOn: yearly.expiresAt!))
        #expect(EntitlementRules.status(of: [yearly], at: yearly.expiresAt!) == .yearlyExpired(on: yearly.expiresAt!))
        #expect(EntitlementRules.status(of: [lifetime], at: t0 + 100 * 365 * 86_400) == .lifetime)
    }

    @Test func lifetimeTakesPrecedence() {
        let expired = PremiumTransaction(plan: .yearly, purchasedAt: t0, expiresAt: t0 + 10)
        let active = PremiumTransaction(plan: .yearly, purchasedAt: t0, expiresAt: t0 + 1_000)
        let lifetime = PremiumTransaction(plan: .lifetime, purchasedAt: t0 + 5, expiresAt: nil)
        #expect(EntitlementRules.status(of: [expired, lifetime], at: t0 + 100) == .lifetime)
        #expect(EntitlementRules.status(of: [active, lifetime], at: t0 + 100) == .lifetime)
    }

    @Test func bothPlansUnlockTheSameThing() {
        #expect(PremiumStatus.yearly(renewsOn: t0).isPremium && PremiumStatus.lifetime.isPremium)
        #expect(!PremiumStatus.free.isPremium && !PremiumStatus.yearlyExpired(on: t0).isPremium)
    }
}

@MainActor
@Suite struct EntitlementStoreTests {
    @Test func freeToYearlyToExpiredToRenewed() {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        #expect(store.status == .free)
        store.purchase(.yearly)
        #expect(store.isPremium)
        clock.advance(days: 364)
        #expect(store.isPremium)
        clock.advance(days: 2) // past the anniversary without renewing
        #expect(!store.isPremium)
        guard case .yearlyExpired = store.status else { Issue.record("expected expired"); return }
        store.purchase(.yearly) // resubscribe
        #expect(store.isPremium)
    }

    @Test func simulatedExpiryIsImmediate() {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        store.purchase(.yearly)
        store.simulateYearlyExpiry()
        #expect(!store.isPremium)
        guard case .yearlyExpired = store.status else { Issue.record("expected expired"); return }
    }

    @Test func lifetimeNeverExpiresAndOverridesExpiredYearly() {
        let clock = TestClock()
        let store = makeStore(clock: clock)
        store.purchase(.yearly)
        store.simulateYearlyExpiry()
        store.purchase(.lifetime)
        #expect(store.status == .lifetime)
        clock.advance(days: 365 * 50)
        store.simulateYearlyExpiry()
        #expect(store.status == .lifetime)
    }

    @Test func persistsAcrossRelaunch() throws {
        let suite = "entitlements-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = TestClock()
        let device = DefaultsEntitlementPersistence(defaults: defaults, key: "device")
        let account = DefaultsEntitlementPersistence(defaults: defaults, key: "account")
        makeStore(clock: clock, device: device, account: account).purchase(.yearly)

        // Fresh objects, as after relaunching the app.
        func relaunch() -> EntitlementStore {
            makeStore(clock: clock,
                      device: DefaultsEntitlementPersistence(defaults: defaults, key: "device"),
                      account: DefaultsEntitlementPersistence(defaults: defaults, key: "account"))
        }
        #expect(relaunch().isPremium)
        relaunch().simulateYearlyExpiry()
        guard case .yearlyExpired = relaunch().status else { Issue.record("expiry should persist"); return }
        relaunch().purchase(.lifetime)
        #expect(relaunch().status == .lifetime)
    }

    @Test func restoreRecoversPurchasesAfterReinstall() {
        let clock = TestClock()
        let account = InMemoryEntitlementPersistence()
        let store = makeStore(clock: clock, account: account)
        store.purchase(.lifetime)
        store.simulateReinstall()
        #expect(store.status == .free)
        store.restorePurchases()
        #expect(store.status == .lifetime)
    }

    @Test func restoreWithNothingBoughtStaysFree() {
        let store = makeStore(clock: TestClock())
        store.restorePurchases()
        #expect(store.status == .free)
    }

    @Test func productionWithoutAnAccountCannotBuy() {
        let store = makeStore(clock: TestClock(), account: nil)
        #expect(!store.canPurchase)
        store.purchase(.lifetime)
        #expect(store.status == .free)
    }
}

/// End-to-end: the one store's flag drives every access rule, with no restart in between.
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
        var day = CalendarDay(year: 2025, month: 1, day: 1)
        while day <= CalendarDay(year: 2030, month: 12, day: 31) {
            if case .unlocked = DayDetailContent.make(day: day, today: today, isPremium: premium, policy: .launch, intensity: intensity)!.details { count += 1 }
            day = day.adding(days: 1)
        }
        return count
    }

    @Test func upgradeAndDowngradeFlipEveryLockImmediately() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let intensity = IntensityCalculator(ephemeris: try BundledEphemeris.load(), calendar: utc)
        let store = makeStore(clock: TestClock())

        #expect(unlockedTaskCount(store.isPremium) == 4)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 4) // today + 3

        store.purchase(.yearly)
        #expect(unlockedTaskCount(store.isPremium) == 27)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 2191) // every day 2025–2030

        store.simulateYearlyExpiry()
        #expect(unlockedTaskCount(store.isPremium) == 4)
        #expect(unlockedDays(store.isPremium, intensity: intensity) == 4) // rolling window still works
    }

    @Test func freeWindowKeepsRollingWhilePremiumChanges() {
        let calendarPolicy = CalendarAccessPolicy.launch
        for isPremium in [false, true, false] {
            let tomorrow = today.adding(days: 1)
            #expect(calendarPolicy.detailsUnlocked(tomorrow.adding(days: 3), today: tomorrow, isPremium: isPremium))
            #expect(calendarPolicy.detailsUnlocked(today, today: today, isPremium: isPremium))
        }
    }

    @Test func downgradeKeepsCompletionAndHistory() throws {
        let completions = CompletionStore(container: try CompletionStore.makeContainer(inMemory: true))
        let store = makeStore(clock: TestClock())
        store.purchase(.yearly)
        completions.markDone("mercury.communication.wait-ten-seconds", in: "mercury-2026-10-24") // a Premium-only task
        completions.markDone("mercury.tech.back-up-files", in: "mercury-2026-06-29") // an earlier cycle
        store.simulateYearlyExpiry()
        #expect(!store.isPremium)
        #expect(completions.isDone("mercury.communication.wait-ten-seconds", in: "mercury-2026-10-24"))
        #expect(completions.completedTaskIDs(in: "mercury-2026-06-29") == ["mercury.tech.back-up-files"])
        store.purchase(.lifetime)
        #expect(completions.completedTaskIDs(in: "mercury-2026-10-24").count == 1)
    }
}
