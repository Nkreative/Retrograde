import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI
import WidgetKit

/// The medium Home Screen widget (Figma "M12 · Home Screen widget"): MERCURY, the phase, the
/// Overview's countdown line, the stage's progress bar and its day label. Shared by the widget
/// extension and the app's debug preview.
struct MercuryWidgetView: View {
    /// nil when the bundled sky data doesn't cover today.
    let content: WidgetContent?

    var body: some View {
        Group {
            if let content {
                CycleCard(content: content)
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

private struct CycleCard: View {
    let content: WidgetContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.planetName)
                        .retroText(.section)
                        .foregroundStyle(RetroColor.text)
                    HStack(spacing: 6) {
                        Circle().fill(content.stage.accent).frame(width: 7, height: 7)
                        Text(content.phaseName)
                            .retroText(.monoLabel)
                            .foregroundStyle(content.stage.accent)
                            .widgetAccentable()
                    }
                }
                Spacer(minLength: 0)
                OrbitMark(accent: content.stage.accent)
            }
            Spacer(minLength: 2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.countdown)
                    .retroText(.display)
                    .foregroundStyle(RetroColor.yellow)
                    .widgetAccentable()
                    .layoutPriority(1)
                Text(content.countdownText)
                    .retroText(.monoBody)
                    .foregroundStyle(RetroColor.text)
                    .lineLimit(2)
            }
            .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            CycleProgressBar(progress: content.progress, fill: content.stage.accent)
            HStack {
                Text(content.leading)
                Spacer(minLength: 8)
                Text(content.trailing)
            }
            .retroText(.widgetCaption)
            .foregroundStyle(RetroColor.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.top, 7)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

/// Mercury on a tilted orbit, in the phase colour.
private struct OrbitMark: View {
    let accent: Color

    var body: some View {
        let size = CGSize(width: 70, height: 24)
        let angle = Angle.degrees(205) // front-left of the orbit
        ZStack {
            Ellipse()
                .stroke(RetroColor.line, lineWidth: 1.5)
                .frame(width: size.width, height: size.height)
            Circle()
                .fill(accent)
                .frame(width: 12, height: 12)
                .shadow(color: accent.opacity(0.7), radius: 6)
                .offset(x: size.width / 2 * cos(angle.radians), y: -size.height / 2 * sin(angle.radians))
        }
        .rotationEffect(.degrees(-18))
        .frame(width: 76, height: 44)
        .accessibilityHidden(true)
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
