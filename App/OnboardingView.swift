import DesignSystem
import Notifications
import Persistence
import SwiftUI
import UserNotifications

/// First launch, as in the approved Figma frames: the splash for about 2 seconds, then the
/// notifications screen with Mercury drifting across. The paywall follows (presented by the app).
struct OnboardingView: View {
    @Environment(OnboardingProgress.self) private var progress
    /// Called once the notifications screen is done (onboarding is then complete).
    let onFinished: () -> Void
    @State private var showsSplash = Self.startsWithSplash

    var body: some View {
        ZStack {
            if showsSplash {
                SplashView().transition(.opacity)
            } else {
                NotificationsOnboarding(finish: finish).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showsSplash)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .retroScreenBackground()
        .task {
            guard showsSplash else { return }
            try? await Task.sleep(for: SplashView.duration)
            showsSplash = false
        }
    }

    private func finish() {
        progress.complete()
        onFinished()
    }

    private static var startsWithSplash: Bool {
        #if DEBUG
        // `-skipSplash YES` opens the notifications screen directly, for review screenshots.
        return !UserDefaults.standard.bool(forKey: "skipSplash")
        #else
        return true
        #endif
    }
}

// MARK: - Splash

/// The approved splash (Figma "Retrograde — title only"): logo and wordmark, centred on the screen.
struct SplashView: View {
    static let duration: Duration = .seconds(2)

    var body: some View {
        VStack(spacing: 29) {
            SplashLogo()
            Text("RETROGRADE")
                .retroText(.hero)
                .foregroundStyle(RetroColor.text)
        }
        // A logo: its proportions are fixed rather than following the text size.
        .dynamicTypeSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Retrograde")
    }
}

// MARK: - Notifications

/// "GET NOTIFIED!" — the approved notifications screen. Positions follow the 430 × 932 pt Figma
/// frame, scaled to the screen; when the text is too large to fit, the screen scrolls as one with
/// the buttons after the text.
private struct NotificationsOnboarding: View {
    let finish: () -> Void
    @State private var authorization: NotificationAuthorization?
    @State private var asking = false

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let y = { (figma: CGFloat) in figma / 932 * screen - geo.safeAreaInsets.top }
            ViewThatFits(in: .vertical) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: max(y(401), 0))
                        .overlay(alignment: .topLeading) { MercuryDrift().offset(y: y(212)) }
                    message
                    Spacer(minLength: 24)
                    actions
                    Color.clear.frame(height: max(screen - 808 / 932 * screen - geo.safeAreaInsets.bottom, 16))
                }
                scrolling
            }
        }
        .task {
            authorization = await NotificationPermission.current()
            #if DEBUG
            // `-onboardingTap enable|later` taps a button after a moment (same code as a real tap),
            // to review the permission prompt and the hand-off to Premium.
            switch UserDefaults.standard.string(forKey: "onboardingTap") {
            case "enable": try? await Task.sleep(for: .seconds(1.5)); await enable()
            case "later": try? await Task.sleep(for: .seconds(1.5)); finish()
            default: break
            }
            #endif
        }
    }

    private var scrolling: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    MercuryDrift().padding(.top, 24)
                    message
                    actions.id(Self.actionsID)
                }
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            #if DEBUG
            .onAppear {
                // `-scrollOnboarding bottom` shows the buttons at large text sizes, for review screenshots.
                if UserDefaults.standard.string(forKey: "scrollOnboarding") == "bottom" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { proxy.scrollTo(Self.actionsID, anchor: .bottom) }
                }
            }
            #endif
        }
    }

    private static let actionsID = "onboarding-actions"

    private var message: some View {
        VStack(spacing: 8) {
            Text("GET NOTIFIED!")
                .retroText(.section)
                .foregroundStyle(RetroColor.text)
                .accessibilityAddTraits(.isHeader)
            Text("Get alerts before and when it goes retrograde, plus reminders for the best times to review, revise, and move forward.")
                .retroText(.body)
                .lineSpacing(6)
                .foregroundStyle(RetroColor.textMuted)
                .frame(maxWidth: 266)
            if authorization == .denied {
                // Already declined in iOS: never asked again, just told where to change it.
                Text("Notifications are off for Retrograde. You can turn them on in iOS Settings anytime.")
                    .retroText(.body)
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(maxWidth: 266)
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RetroMetrics.screenPadding)
    }

    private var actions: some View {
        VStack(spacing: 15) {
            if authorization?.shouldPrompt ?? true {
                PrimaryButton(asking ? "Asking…" : "Turn on notifications") { Task { await enable() } }
                    .disabled(asking)
                Button("No I will feel it no need to tell me", action: finish)
                    .retroText(.button)
                    .foregroundStyle(RetroColor.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(asking)
            } else {
                // Already decided in iOS (allowed or declined): never prompt, just continue.
                PrimaryButton("Continue", action: finish)
            }
        }
        .padding(.horizontal, RetroMetrics.screenPadding)
    }

    /// Asks iOS only on this tap, and only if it never has (or to upgrade quiet delivery);
    /// whatever the answer, onboarding continues. Nothing is scheduled yet (M11).
    private func enable() async {
        asking = true
        if await NotificationPermission.current().shouldPrompt {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        asking = false
        finish()
    }
}

/// Mercury crossing the upper part of the screen from right to left, as in the three Figma
/// frames (x 361 → 187 → −34 pt on the 430 pt frame). With Reduce Motion it fades in at the
/// middle position instead.
private struct MercuryDrift: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var visible = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            MercuryArtwork()
                .offset(x: w * (reduceMotion ? 187 : arrived ? -34 : 361) / 430)
                .opacity(reduceMotion && !visible ? 0 : 1)
        }
        .frame(height: MercuryArtwork.size.height)
        .onAppear(perform: start)
        .accessibilityHidden(true)
    }

    private func start() {
        #if DEBUG
        // `-mercuryAt start|end` holds Mercury still, for review screenshots.
        switch UserDefaults.standard.string(forKey: "mercuryAt") {
        case "start": visible = true; return
        case "end": arrived = true; visible = true; return
        default: break
        }
        #endif
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.4)) { visible = true }
        } else {
            withAnimation(.easeInOut(duration: 5).delay(0.3)) { arrived = true }
        }
    }
}

/// The Figma planet ("Hero BG"): the approved Mercury artwork cropped to its disc and turned as in
/// the mockup (image at 467.52 % × 481.9 %, offset −183.58 % / −70.77 %, rotated 170.11°).
private struct MercuryArtwork: View {
    static let size = CGSize(width: 95.642, height: 92.88)

    var body: some View {
        let disc = CGSize(width: 83.176, height: 79.781)
        Image("OnboardingMercury")
            .resizable()
            .frame(width: disc.width * 4.6752, height: disc.height * 4.819)
            .offset(x: disc.width * -1.8358, y: disc.height * -0.7077)
            .frame(width: disc.width, height: disc.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .rotationEffect(.degrees(170.11))
            .frame(width: Self.size.width, height: Self.size.height)
    }
}
