#if DEBUG
import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI
import WidgetKit

/// Debug review aid (`-widgetPreview YES`): the real widget view at this iPhone's small and medium
/// widget sizes, for today and for the middle of each phase of the current cycle, from the bundled data.
/// iOS draws the actual widget; this only lets it be reviewed without a Home Screen.
/// `-widgetOnly DIRECT` (or TODAY, PRE-SHADOW, RETROGRADE, POST-SHADOW) shows just that one.
struct WidgetPreviewScreen: View {
    var now: Date = .now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(shown, id: \.title) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sample.title).retroText(.mono).foregroundStyle(RetroColor.textMuted)
                        HStack(alignment: .top, spacing: 12) {
                            WidgetFrame(family: .systemSmall) { MercuryWidgetView(content: sample.content, family: .systemSmall) }
                            Spacer(minLength: 0)
                        }
                        WidgetFrame(family: .systemMedium) { MercuryWidgetView(content: sample.content, family: .systemMedium) }
                    }
                }
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.vertical, 12)
        }
        .retroScreenBackground()
    }

    private var shown: [(title: String, content: WidgetContent?)] {
        guard let only = UserDefaults.standard.string(forKey: "widgetOnly") else { return samples }
        return samples.filter { $0.title == only }
    }

    private var samples: [(title: String, content: WidgetContent?)] {
        guard let ephemeris = SkyData.ephemeris else { return [("TODAY · NO DATA", nil)] }
        let timeline = WidgetTimeline(calculator: CycleCalculator(ephemeris: ephemeris, calendar: .current), calendar: .current)
        if ProcessInfo.processInfo.arguments.contains("missing") { return [("NO SKY DATA", nil)] }
        guard let period = SkyData.calculator?.status(of: .mercury, at: now)?.period else { return [("TODAY", timeline.content(at: now))] }
        func middle(_ a: Date, _ b: Date) -> Date { a.addingTimeInterval(b.timeIntervalSince(a) / 2) }
        return [
            ("TODAY", timeline.content(at: now)),
            ("PRE-SHADOW", timeline.content(at: middle(period.preShadowStart, period.stationRetrograde))),
            ("RETROGRADE", timeline.content(at: middle(period.stationRetrograde, period.stationDirect))),
            ("POST-SHADOW", timeline.content(at: middle(period.stationDirect, period.postShadowEnd))),
            ("DIRECT", timeline.content(at: period.postShadowEnd.addingTimeInterval(20 * 86_400))),
        ]
    }
}

/// iOS's small or medium widget frame for this screen width, with its rounded corners and 16 pt margins.
private struct WidgetFrame<Content: View>: View {
    let family: WidgetFamily
    @ViewBuilder let content: Content

    var body: some View {
        let width = UIScreen.main.bounds.width
        let height: CGFloat = width >= 428 ? 170 : width >= 390 ? 158 : 148
        let medium: CGFloat = width >= 428 ? 364 : width >= 390 ? 338 : 321
        content
            .padding(16)
            .frame(width: family == .systemSmall ? height : medium, height: height)
            .background(WidgetBackground())
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }
}
#endif
