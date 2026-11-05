import DesignSystem
import Editorial
import Entitlements
import Persistence
import RetroCore
import SwiftUI

/// The Overview. Until the person starts the Survival Kit it introduces the kit under the Mercury
/// countdown and artwork (State A); after that it's their dashboard (State B, `OverviewDashboard`),
/// for good, new cycles included. Everything date-related comes from the verified ephemeris.
struct OverviewScreen: View {
    /// Debug-only clock override for reviewing other cycle stages; nil uses the real time.
    var now: Date?
    @Environment(SurvivalKitActivation.self) private var activation
    @Environment(EntitlementStore.self) private var premium
    @Environment(AppRouter.self) private var router
    @Environment(WidgetPrompt.self) private var widgetPrompt

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = now ?? context.date
            let status = SkyData.calculator?.status(of: .mercury, at: date)
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if activation.isStarted {
                            OverviewDashboard(now: date, status: status)
                        } else if let status, let copy = OverviewCopy.for(.mercury, status.stage) {
                            introduction(status, copy)
                        } else {
                            MissingSkyData()
                        }
                    }
                    .id(Self.bottomID)
                }
                #if DEBUG
                .onAppear {
                    // `-scrollOverview kit|today|sharing|bottom` opens it scrolled there, for review screenshots.
                    if let target = UserDefaults.standard.string(forKey: "scrollOverview") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if target == Self.bottomID { proxy.scrollTo(target, anchor: .bottom) } else { proxy.scrollTo(target, anchor: .top) }
                        }
                    }
                }
                #endif
            }
        }
    }

    private static let bottomID = "bottom"

    private func introduction(_ status: CycleStatus, _ copy: OverviewCopy) -> some View {
        // Progress group, then the headline + artwork group close beneath it (tightened ~50 pt
        // after review so the hero reads as part of the same story).
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CountdownRow(status: status, copy: copy)
                LabeledProgress(progress: status.progress, start: copy.barStart, current: "YOU ARE HERE", end: copy.barEnd)
                if widgetPrompt.offersWidget {
                    HStack {
                        Spacer()
                        PillButton("ADD TO HOME SCREEN", systemImage: RetroSymbol.add, action: router.openWidgetHowTo)
                            .accessibilityHint("Shows how to add the widget")
                    }
                    .padding(.top, -6) // sits just under the bar labels
                }
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                HeroCard(headline: copy.heroHeadline)
                KitIntroCard(
                    introduction: copy.kitIntroduction(daysUntilTarget: status.daysUntilTarget),
                    isPremium: premium.isPremium,
                    onStart: {
                        activation.start()
                        router.openKit()
                    }
                )
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, RetroMetrics.screenPadding)
    }
}

/// State A's Survival Kit card (approved M13.1 Figma): what the kit is for, its four sections, and
/// the one main action.
private struct KitIntroCard: View {
    let introduction: String
    let isPremium: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR SURVIVAL KIT").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                Text("SMALL MOVES. YOU’LL GET IT DONE.")
                    .retroText(.section)
                    .foregroundStyle(RetroColor.text)
                    .accessibilityAddTraits(.isHeader)
                Text(introduction).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            TopicChips()
            VStack(spacing: 12) {
                PrimaryButton("Start Survival Kit", systemImage: RetroSymbol.firstAid, layout: .leading, showsArrow: true, action: onStart)
                    .accessibilityHint("Opens the Survival Kit")
                Text(isPremium ? "Premium: every task is unlocked." : "Free: the first task in every section. No account needed.")
                    .retroText(.finePrint)
                    .foregroundStyle(RetroColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .retroCard(fill: RetroColor.surfaceRaised)
    }
}

/// MESSAGES · TECH · PLANS · JOURNAL, in one row where it fits, else two, else one per line.
/// Decorative: the introduction above says the same in words.
private struct TopicChips: View {
    private static let topics: [(symbol: String, title: String)] = [
        (RetroSymbol.communication, "MESSAGES"), (RetroSymbol.techBackup, "TECH"),
        (RetroSymbol.planning, "PLANS"), (RetroSymbol.journal, "JOURNAL"),
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) { chips(Self.topics) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) { chips(Array(Self.topics.prefix(2))) }
                HStack(spacing: 5) { chips(Array(Self.topics.suffix(2))) }
            }
            VStack(alignment: .leading, spacing: 6) { chips(Self.topics) }
        }
        .accessibilityHidden(true)
    }

    private func chips(_ topics: [(symbol: String, title: String)]) -> some View {
        ForEach(topics, id: \.title) { topic in
            HStack(spacing: 4) {
                Image(systemName: topic.symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(RetroColor.pink)
                Text(topic.title).retroText(.monoSmall).foregroundStyle(RetroColor.text)
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(RetroColor.chip, in: Capsule())
        }
    }
}

/// "10 days to exhale ······ DAY 12 / 22", or "TODAY Mercury turns direct" on the day itself.
private struct CountdownRow: View {
    let status: CycleStatus
    let copy: OverviewCopy

    var body: some View {
        let days = status.daysUntilTarget
        let unit = days == 0 ? copy.countdownToday : copy.countdownUnit(for: days)
        let dayLabel = copy.dayLabel(day: status.day, of: status.totalDays)
        let countdown = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(days == 0 ? "TODAY" : "\(days)")
                .retroText(.display)
                .foregroundStyle(RetroColor.yellow)
            Text(unit)
                .retroText(.monoLarge)
                .foregroundStyle(RetroColor.text)
        }
        Group {
            if let dayLabel {
                let day = Text(dayLabel)
                    .retroText(.mono)
                    .foregroundStyle(RetroColor.textMuted)
                // Figma's single row where it fits; on narrow phones or large text the day label drops below.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        countdown
                        Spacer(minLength: 12)
                        day
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        countdown
                        day
                    }
                }
            } else {
                countdown.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 0 ? "Today, \(unit)" : "\(days) \(unit)")
        .accessibilityValue(dayLabel?.capitalized ?? "")
    }
}

/// The approved "cosmic chaos" artwork, shown whole at its 2:1 proportions (so the girl, the
/// tangled orbits and every icon stay in frame). The stage headline is live text in a dark band
/// that blends into the artwork's night sky, overlapping only the empty top edge.
private struct HeroCard: View {
    let headline: String
    /// Height of the dark band above the artwork; the headline dips just into the sky below it.
    @ScaledMetric(relativeTo: .title) private var band: CGFloat = 60
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // Large text wraps the headline onto more lines than the band holds: put it above.
            VStack(alignment: .leading, spacing: 8) {
                headlineText
                artwork
            }
        } else {
            banded
        }
    }

    private var headlineText: some View {
        Text(headline)
            .retroText(.hero)
            .foregroundStyle(RetroColor.text)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var artwork: some View {
        Image("OverviewHero")
            .resizable()
            .aspectRatio(2, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var banded: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: band)
            artwork.overlay(alignment: .top) {
                // The artwork's top rows are already near the background colour; this removes the seam.
                LinearGradient(colors: [RetroColor.background, RetroColor.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
            }
        }
        .overlay(alignment: .topLeading) { headlineText }
    }
}

/// Shown if the date is outside the bundled data (it covers 2025–2030).
struct MissingSkyData: View {
    /// False inside a screen that already has margins (the dashboard).
    var padded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WE’RE STILL MAPPING THIS STRETCH OF SKY.")
                .retroText(.cardTitle)
                .foregroundStyle(RetroColor.text)
            Text("Retrograde only shows verified dates. Update the app to see the latest cycles.")
                .retroText(.body)
                .foregroundStyle(RetroColor.textMuted)
        }
        .retroCard()
        .padding(.horizontal, padded ? RetroMetrics.screenPadding : 0)
        .padding(.top, padded ? 6 : 0)
    }
}
