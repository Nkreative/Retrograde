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
                Button("No, I’ll feel it. No need to tell me.", action: finish)
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

/// Mercury entering from the upper right along the Figma path (x 361 pt on the 430 pt frame),
/// slowing gradually and stopping at the centre of the screen, with a soft trail that traces the
/// last stretch of its path and fades away once it stops. With Reduce Motion it simply appears,
/// still, in its final position.
private struct MercuryDrift: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    /// Set once the animation is over (or held for review): drawn still at that moment.
    @State private var stillAt: Double?

    private static let delay = 0.5       // after the screen has faded in
    private static let travel = 3.4      // seconds from entry to stop
    private static let trailLag = 0.8    // the trail shows where Mercury was this long ago
    private static let trailFade = 0.9   // seconds for the trail to disappear after the stop
    private static var total: Double { delay + travel + trailFade }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            if reduceMotion {
                frame(elapsed: Self.total, width: w)
            } else if let stillAt {
                frame(elapsed: stillAt, width: w)
            } else {
                // Redraws every frame only while moving, then replaced by the still final frame.
                TimelineView(.animation(paused: start == nil)) { context in
                    frame(elapsed: start.map { context.date.timeIntervalSince($0) } ?? 0, width: w)
                }
            }
        }
        .frame(height: MercuryArtwork.size.height)
        .task { await run() }
        .accessibilityHidden(true)
    }

    /// Mercury and its trail at a moment of the animation.
    private func frame(elapsed: Double, width w: CGFloat) -> some View {
        let x = position(at: elapsed, width: w)
        let tail = position(at: elapsed - Self.trailLag, width: w)
        let fade = 1 - min(max((elapsed - Self.delay - Self.travel) / Self.trailFade, 0), 1)
        let center = MercuryArtwork.size.width / 2
        let trailHeight: CGFloat = 26
        return ZStack(alignment: .topLeading) {
            // A soft glow from Mercury's centre back along the path it just travelled; it shortens
            // as Mercury slows and fades out after it stops. It stays within Mercury's band of the
            // screen, well above the text.
            Capsule()
                .fill(LinearGradient(colors: [RetroColor.pinkSoft.opacity(0.6), RetroColor.pink.opacity(0.22), RetroColor.pink.opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: max(tail - x, 0) + trailHeight, height: trailHeight)
                .blur(radius: 8)
                .offset(x: x + center - trailHeight / 2, y: (MercuryArtwork.size.height - trailHeight) / 2)
                .opacity(fade)
            MercuryArtwork().offset(x: x)
        }
    }

    /// Left edge of Mercury: enters at the Figma start, eases out to rest centred.
    private func position(at elapsed: Double, width w: CGFloat) -> CGFloat {
        let from = w * 361 / 430
        let to = (w - MercuryArtwork.size.width) / 2
        let u = min(max((elapsed - Self.delay) / Self.travel, 0), 1)
        let eased = 1 - pow(1 - u, 3) // gradual slow-down to a stop
        return from + (to - from) * eased
    }

    private func run() async {
        #if DEBUG
        // `-mercuryAt start|middle|end` holds the animation at that moment, for review screenshots.
        switch UserDefaults.standard.string(forKey: "mercuryAt") {
        case "start": stillAt = 0; return
        case "middle": stillAt = Self.delay + 0.7; return
        case "end": stillAt = Self.total; return
        default: break
        }
        #endif
        guard !reduceMotion else { return }
        start = .now
        try? await Task.sleep(for: .seconds(Self.total + 0.1))
        stillAt = Self.total // trail fully gone: draw the final still frame and stop redrawing
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
