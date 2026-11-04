import Foundation
import Testing
@testable import Entitlements

@Suite struct PremiumSummaryTests {
    let date = Date(timeIntervalSince1970: 1_812_000_000)
    private func summary(_ status: PremiumStatus, loaded: Bool = true) -> PremiumSummary {
        PremiumSummary.make(status: status, hasLoaded: loaded, formatDate: { _ in "Dec 2, 2027" })
    }

    @Test func free() {
        let s = summary(.free)
        #expect(s.title == "Free" && s.actions == [.upgrade, .restore])
    }

    @Test func neverClaimsFreeBeforeTheFirstVerifiedRead() {
        let s = summary(.free, loaded: false)
        #expect(s.title == "Checking your purchases…")
        #expect(!s.actions.contains(.upgrade))
    }

    @Test func yearlyShowsTheVerifiedDate() {
        #expect(summary(.yearly(until: date, willRenew: true)).detail == "Renews Dec 2, 2027.")
        #expect(summary(.yearly(until: date, willRenew: false)).detail == "Ends Dec 2, 2027. Auto-renew is off.")
        #expect(summary(.yearly(until: date, willRenew: true)).actions.contains(.manageSubscription))
        #expect(summary(.yearly(until: nil, willRenew: true)).detail == nil) // no date invented
    }

    @Test func lifetimeDoesNotRenew() {
        let s = summary(.lifetime(yearlyStillRenewing: false))
        #expect(s.title == "Premium · Lifetime" && s.detail!.contains("never renews"))
        #expect(s.notice == nil && !s.actions.contains(.manageSubscription) && !s.actions.contains(.upgrade))
    }

    @Test func lifetimePlusRenewingYearlyWarnsToCancel() {
        let s = summary(.lifetime(yearlyStillRenewing: true))
        #expect(s.title == "Premium · Lifetime")
        #expect(s.notice!.contains("Cancel it in Manage Subscription"))
        #expect(s.actions.first == .manageSubscription)
    }

    @Test func paymentProblems() {
        let grace = summary(.yearlyGracePeriod(until: date))
        #expect(grace.title == "Premium · Yearly" && grace.tone == .warning && grace.notice!.contains("until Dec 2, 2027"))
        let retry = summary(.yearlyBillingIssue)
        #expect(retry.tone == .warning && retry.actions.first == .manageSubscription)
    }

    @Test func expiredAndRefunded() {
        #expect(summary(.yearlyExpired(on: date)).detail == "Your Yearly subscription ended Dec 2, 2027.")
        #expect(summary(.yearlyExpired(on: date)).actions == [.upgrade, .restore])
        // A refund shows plain Free (EntitlementRules maps revoked purchases to .free).
        #expect(summary(.free).title == "Free")
    }

    @Test func everyStateOffersRestore() {
        let all: [PremiumStatus] = [.free, .lifetime(yearlyStillRenewing: true), .lifetime(yearlyStillRenewing: false),
                                    .yearly(until: date, willRenew: true), .yearlyGracePeriod(until: date),
                                    .yearlyBillingIssue, .yearlyExpired(on: date)]
        #expect(all.allSatisfy { summary($0).actions.contains(.restore) })
    }
}
