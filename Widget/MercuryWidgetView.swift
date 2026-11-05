import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI
import WidgetKit

/// The Home Screen widget, small and medium (Figma "6 · M14.5 Widget redesign"): MERCURY, the
/// phase, the Overview's countdown line, the stage's progress bar and its day label, beside the
/// approved Mercury artwork. Shared by the widget extension and the app (how-to sheet, debug preview).
struct MercuryWidgetView: View {
    /// nil when the bundled sky data doesn't cover today.
    let content: WidgetContent?
    var family: WidgetFamily = .systemMedium

    var body: some View {
        Group {
            if let content {
                switch family {
                case .systemSmall: SmallCycleCard(content: content)
                default: MediumCycleCard(content: content)
                }
            } else {
                MissingSkyCard()
            }
        }
        // Past this, the fixed-size widget can't fit its lines; larger settings still get large text.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Where the widget leads when tapped.
enum WidgetLink {
    static let overview = URL(string: "retrograde://overview")!

    static func opensOverview(_ url: URL) -> Bool {
        url.scheme == overview.scheme && url.host() == overview.host()
    }
}

/// The widget's background: the app's night sky.
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [RetroColor.surfaceRaised, RetroColor.background], startPoint: .top, endPoint: .bottom)
    }
}

private struct SmallCycleCard: View {
    let content: WidgetContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(content.planetName)
                        .retroText(.widgetTitleSmall)
                        .foregroundStyle(RetroColor.text)
                    PhaseLabel(content: content, style: .widgetPhaseSmall)
                }
                Spacer(minLength: 0)
                MercuryPlanet(disc: 46, accent: content.stage.accent)
                    .offset(x: 3, y: -4)
            }
            Spacer(minLength: 2)
            Text(content.countdown)
                .retroText(.widgetCountdownSmall)
                .foregroundStyle(RetroColor.yellow)
                .widgetAccentable()
            Text(content.countdownText)
                .retroText(.widgetCaption)
                .foregroundStyle(RetroColor.text)
                .lineLimit(2)
                .minimumScaleFactor(1) // wraps onto a second line rather than shrinking or cutting off
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            CycleProgressBar(progress: content.progress, fill: content.stage.accent, markerSize: 9)
            Text(content.leading)
                .retroText(.widgetLabel)
                .foregroundStyle(RetroColor.textMuted)
                .padding(.top, 5)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

private struct MediumCycleCard: View {
    let content: WidgetContent

    var body: some View {
        HStack(spacing: 18) {
            MercuryPlanet(disc: 84, accent: content.stage.accent)
                .frame(width: 96)
            VStack(alignment: .leading, spacing: 0) {
                Text(content.planetName)
                    .retroText(.widgetTitle)
                    .foregroundStyle(RetroColor.text)
                PhaseLabel(content: content, style: .widgetPhase)
                    .padding(.top, 4)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(content.countdown)
                        .retroText(.widgetCountdown)
                        .foregroundStyle(RetroColor.yellow)
                        .widgetAccentable()
                        .layoutPriority(1)
                    Text(content.countdownText)
                        .retroText(.widgetUnit)
                        .foregroundStyle(RetroColor.text)
                        .lineLimit(2)
                        .minimumScaleFactor(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                CycleProgressBar(progress: content.progress, fill: content.stage.accent, markerSize: 9)
                HStack {
                    Text(content.leading)
                    Spacer(minLength: 8)
                    Text(content.trailing)
                }
                .retroText(.widgetLabel)
                .foregroundStyle(RetroColor.textMuted)
                .padding(.top, 6)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

/// "● RETROGRADE" in the phase colour.
private struct PhaseLabel: View {
    let content: WidgetContent
    let style: RetroTextStyle

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(content.stage.accent).frame(width: 7, height: 7)
            Text(content.phaseName)
                .retroText(style)
                .foregroundStyle(content.stage.accent)
                .widgetAccentable()
        }
    }
}

/// The approved Mercury artwork (Figma "Hero BG": the same image, crop and turn as the splash and
/// onboarding, pre-cropped as `WidgetMercury`). The planet is never recoloured; a soft glow in the
/// phase colour behind it carries the phase. On tinted Home Screens iOS shows it desaturated.
struct MercuryPlanet: View {
    /// The planet's diameter; the glow spreads beyond it.
    let disc: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.5))
                .frame(width: disc * 1.4, height: disc * 1.4)
                .blur(radius: disc * 0.3)
            Image("WidgetMercury")
                .resizable()
                .interpolation(.high)
                .desaturatedWhenTinted()
                .aspectRatio(contentMode: .fit)
                // The image is the disc's turned square (290 × 282 px for a 252 px disc).
                .frame(width: disc * 290 / 252)
        }
        .frame(width: disc, height: disc)
        .accessibilityHidden(true)
    }
}

private extension Image {
    /// Tinted Home Screens (iOS 18 and later) show the planet in greys rather than hiding it.
    @ViewBuilder func desaturatedWhenTinted() -> some View {
        if #available(iOS 18, *) { widgetAccentedRenderingMode(.desaturated) } else { self }
    }
}

/// Shown if today is outside the bundled data (it covers 2025–2030), in the Overview's words.
private struct MissingSkyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MERCURY")
                .retroText(.section)
                .foregroundStyle(RetroColor.text)
            Text("WE’RE STILL MAPPING THIS STRETCH OF SKY.")
                .retroText(.cardTitle)
                .foregroundStyle(RetroColor.text)
            Text("Update the app to see the latest cycles.")
                .retroText(.widgetNote)
                .foregroundStyle(RetroColor.textMuted)
        }
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

extension CycleStatus.Stage {
    /// Mauve while Mercury is in its shadow ahead of the turn, pink in retrograde, soft pink as it
    /// retraces its steps, mint once it's clear.
    var accent: Color {
        switch self {
        case .preShadow: RetroColor.mauve
        case .retrograde: RetroColor.pink
        case .postShadow: RetroColor.pinkSoft
        case .direct: RetroColor.green
        }
    }
}
