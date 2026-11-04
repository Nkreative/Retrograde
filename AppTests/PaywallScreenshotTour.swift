#if os(iOS)
import Foundation
import StoreKitTest
import Testing
import UIKit
@testable import Entitlements
@testable import Retrograde

/// Drives the real paywall inside the app against the StoreKit test environment and saves a PNG
/// of each state. Off unless RETROGRADE_TOUR_DIR is set (pass `TEST_RUNNER_RETROGRADE_TOUR_DIR=…`
/// to xcodebuild); reported as skipped otherwise.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["RETROGRADE_TOUR_DIR"] != nil))
final class PaywallScreenshotTour {
    let directory: URL
    let session: SKTestSession

    init() throws {
        directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RETROGRADE_TOUR_DIR"]!)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Retrograde.storekit")
        session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    private func wait(_ seconds: Double = 1.2) async { try? await Task.sleep(for: .seconds(seconds)) }

    private func snap(_ name: String) async throws {
        await wait()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try #require(scene.windows.first { $0.isKeyWindow } ?? scene.windows.first)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try #require(image.pngData()).write(to: directory.appendingPathComponent("\(name).png"))
    }

    private func reopenPaywall() async throws {
        let presenter = try #require(PaywallPresenter.current)
        presenter.isPresented = false
        await wait(0.8)
        presenter.present()
        await wait(2.5) // artwork, then offers from StoreKit
    }

    private var flow: PurchaseFlow { get throws { try #require(PaywallDebug.flow) } }

    @Test func tour() async throws {
        try await reopenPaywall()
        try await snap("01_lifetime_default")
        try flow.select(.yearly)
        try await snap("02_yearly_trial")
        PaywallDebug.scrollToBottom?()
        try await snap("03_yearly_terms_and_links")
        try flow.select(.lifetime)
        try await snap("04_lifetime_terms_and_links")

        try await reopenPaywall()
        try flow.debugShow(.loading)
        try await snap("05_loading")
        try flow.debugShow(.purchasing(.lifetime))
        try await snap("06_processing")
        try flow.debugShow(.unavailable)
        try await snap("07_unavailable")

        // Pending and failed purchases are exercised for real by StoreKitEntitlementTests; here the
        // states are shown directly so no sign-in dialog can stall the tour.
        try await reopenPaywall()
        try flow.debugShow(.pending)
        try await snap("08_pending_approval")
        try flow.debugShow(.purchaseFailed)
        try await snap("09_purchase_failed")
        try flow.debugShow(.nothingToRestore)
        try await snap("10_nothing_to_restore")

        // Someone who already had Yearly: no trial language.
        session.clearTransactions()
        PaywallPresenter.current?.isPresented = false
        await wait(1)
        for attempt in 1...8 {
            do { try await session.buyProduct(identifier: PremiumPlan.yearly.productID); break }
            catch where attempt < 8 { await wait(1) }
        }
        for _ in 0..<5 {
            try? session.expireSubscription(productIdentifier: PremiumPlan.yearly.productID)
            await wait(1)
            if case let .verified(t)? = await Transaction.latest(for: PremiumPlan.yearly.productID),
               let expiry = t.expirationDate, expiry < .now { break }
        }
        try await reopenPaywall()
        try flow.select(.yearly)
        try await snap("11_yearly_no_trial")
        PaywallDebug.scrollToBottom?()
        try await snap("12_yearly_no_trial_terms")
        PaywallPresenter.current?.isPresented = false
    }
}
#endif
