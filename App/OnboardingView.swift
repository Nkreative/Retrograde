import DesignSystem
import Notifications
import Persistence
import SwiftUI
import UserNotifications

/// First-launch onboarding: Mercury's apparent backward motion, what Retrograde does, and an
/// optional notification permission request. The paywall follows (presented by the app shell).
struct OnboardingView: View {
    @Environment(OnboardingProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called once the notifications step is done (onboarding is then complete).
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            switch progress.step {
            case .mercury: MercuryPage(next: next)
            case .features: FeaturesPage(next: next)
            case .notifications, .completed: NotificationsPage(finish: finish)
            }
        }
        .id(progress.step)
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35), value: progress.step)
        .retroScreenBackground()
        .overlay(alignment: .top) { PageHeader() }
    }

    private func next() { progress.advance() }

    private func finish() {
        progress.complete()
        onFinished()
    }
}

/// Back arrow (from page 2) and page dots.
private struct PageHeader: View {
    @Environment(OnboardingProgress.self) private var progress

    var body: some View {
        HStack {
            if progress.pageIndex > 0, !progress.isComplete {
                Button { progress.back() } label: {
                    Image(systemName: RetroSymbol.back).font(.system(size: 15, weight: .semibold)).foregroundStyle(RetroColor.text)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<OnboardingProgress.pageCount, id: \.self) { i in
                    Capsule().fill(i == progress.pageIndex ? RetroColor.pink : RetroColor.line)
                        .frame(width: i == progress.pageIndex ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(min(progress.pageIndex, 2) + 1) of \(OnboardingProgress.pageCount)")
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, RetroMetrics.screenPadding - 10)
    }
}

/// Shared page layout: scrollable content with the call to action pinned above the home indicator,
/// so it stays visible on small phones and at large text sizes.
private struct OnboardingPage<Visual: View, Extra: View, Actions: View>: View {
    let headline: String
    let message: String
    @ViewBuilder let visual: Visual
    @ViewBuilder let extra: Extra
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                visual.frame(maxWidth: .infinity)
                Text(headline).retroText(.hero).foregroundStyle(RetroColor.text).accessibilityAddTraits(.isHeader)
                Text(message).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
                extra
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 56)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) { actions }
                .padding(.horizontal, RetroMetrics.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(RetroColor.background.opacity(0.96))
        }
    }
}

// MARK: - 1. Mercury

private struct MercuryPage: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            headline: "MERCURY’S DOING IT AGAIN.",
            message: "Sometimes Mercury appears to move backward across the sky. We call it retrograde.",
            visual: { RetrogradeLoop().frame(height: 250) },
            extra: { EmptyView() },
            actions: { PrimaryButton("Next", action: next) }
        )
    }
}

/// Mercury's apparent path against the stars as seen from Earth: drifting one way, looping back,
/// then carrying on. With Reduce Motion the whole path is drawn still.
struct RetrogradeLoop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let cycle: Double = 8 // seconds per pass, including a pause

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if reduceMotion {
                    LoopCanvas(progress: 1, dot: 0.5)
                } else {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle) / (Self.cycle - 1.2)
                        let p = min(t, 1)
                        LoopCanvas(progress: p, dot: p)
                    }
                }
            }
            .background(RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel))
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel).strokeBorder(RetroColor.line, lineWidth: 1))
            Text("Its apparent path, as seen from Earth. Mercury doesn’t really reverse — Earth’s view of it shifts.")
                .retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animation: Mercury drifts across the stars, loops backward for a while, then carries on. This is its apparent path seen from Earth; the planet doesn’t actually reverse.")
    }
}

private struct LoopCanvas: View {
    /// How much of the path is drawn (0…1) and where Mercury is.
    let progress: Double
    let dot: Double

    var body: some View {
        Canvas { ctx, size in
            // Background stars (fixed positions).
            var rng = SeededRandom(seed: 7)
            for _ in 0..<46 {
                let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                let r = 0.6 + rng.next() * 1.3
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(RetroColor.text.opacity(0.25 + rng.next() * 0.5)))
            }
            // The path, drawn up to `progress`; the backward stretch in pink.
            let steps = 220
            let drawn = Int(Double(steps) * progress)
            if drawn > 1 {
                for i in 1...drawn {
                    let a = point(Double(i - 1) / Double(steps), in: size), b = point(Double(i) / Double(steps), in: size)
                    var seg = Path(); seg.move(to: a); seg.addLine(to: b)
                    let backward = b.x > a.x
                    ctx.stroke(seg, with: .color(backward ? RetroColor.pink : RetroColor.pinkSoft.opacity(0.55)),
                               style: StrokeStyle(lineWidth: backward ? 2.4 : 1.6, lineCap: .round))
                }
            }
            // Mercury, with a soft glow.
            let m = point(dot, in: size)
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - 14, y: m.y - 14, width: 28, height: 28)), with: .color(RetroColor.yellow.opacity(0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - 6, y: m.y - 6, width: 12, height: 12)), with: .color(RetroColor.yellow))
            ctx.draw(Text("MERCURY").font(RetroTextStyle.monoTiny.font).foregroundColor(RetroColor.text), at: CGPoint(x: m.x, y: m.y + 20))
        }
    }

    /// Right-to-left drift with one backward loop in the middle (x' > 0 around s = 0.5).
    private func point(_ s: Double, in size: CGSize) -> CGPoint {
        let w = size.width, h = size.height
        let x = w * (0.9 - 0.8 * s) - 0.21 * w * sin(2 * .pi * s)
        let y = h * 0.56 + h * 0.2 * cos(2 * .pi * s) - h * 0.08 * (s - 0.5)
        return CGPoint(x: x, y: y)
    }
}

/// Deterministic pseudo-random numbers so the stars stay put between frames.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: - 2. Features

private struct FeaturesPage: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            headline: "LESS GUESSING. MORE PREPARING.",
            message: "Know what’s coming, check the cosmic calendar, and keep your Survival Kit close.",
            visual: {
                Image("OverviewHero").resizable().aspectRatio(2, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel))
                    .accessibilityHidden(true)
            },
            extra: {
                VStack(alignment: .leading, spacing: 14) {
                    feature(RetroSymbol.planning, "Countdowns for every stage", "Days until Mercury turns, from shadow to retrograde to direct.")
                    feature(RetroSymbol.moon, "A daily cosmic calendar", "Each day’s intensity, what’s shaping it, and a habit to try.")
                    feature(RetroSymbol.firstAid, "Your Survival Kit", "Small, practical moves for messages, tech, plans and reflection.")
                }
                .padding(.top, 4)
            },
            actions: { PrimaryButton("Next", action: next) }
        )
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(systemImage: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 3. Notifications

private struct NotificationsPage: View {
    let finish: () -> Void
    @State private var authorization: NotificationAuthorization?
    @State private var asking = false

    var body: some View {
        OnboardingPage(
            headline: "NO COSMIC SURPRISES.",
            message: "Get a heads-up when Mercury changes direction and when your Survival Kit needs attention.",
            visual: { BellArt().frame(height: 170) },
            extra: {
                Text(note).retroText(.body).foregroundStyle(RetroColor.textMuted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
            },
            actions: {
                if authorization == nil || authorization == .notDetermined {
                    PrimaryButton(asking ? "Asking…" : "Enable notifications", systemImage: RetroSymbol.notifications) {
                        Task { await enable() }
                    }
                    .disabled(asking)
                    Button("Maybe later", action: finish)
                        .retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(asking)
                } else {
                    // Already decided in iOS: never prompt again, just continue.
                    PrimaryButton("Continue", action: finish)
                }
            }
        )
        .task { authorization = await NotificationPermission.current() }
    }

    private var note: String {
        switch authorization {
        case .allowed: "Notifications are on. Choose exactly which alerts you get in Settings › Notifications."
        case .denied: "Notifications are off for Retrograde in iOS Settings. You can turn them on there anytime, and choose your alerts in Settings › Notifications."
        default: "You choose which alerts you get in Settings › Notifications — Mercury turning points, heads-ups before them, and Survival Kit reminders."
        }
    }

    /// Asks iOS only if it never has; whatever the answer, onboarding continues.
    private func enable() async {
        asking = true
        if await NotificationPermission.current().shouldPrompt {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        asking = false
        finish()
    }
}

private struct BellArt: View {
    var body: some View {
        ZStack {
            Circle().fill(RetroColor.pink.opacity(0.12)).frame(width: 150, height: 150)
            Circle().strokeBorder(RetroColor.line, lineWidth: 1).frame(width: 112, height: 112)
            Image(systemName: "bell.badge").font(.system(size: 50, weight: .light)).foregroundStyle(RetroColor.text, RetroColor.pink)
        }
        .accessibilityHidden(true)
    }
}
