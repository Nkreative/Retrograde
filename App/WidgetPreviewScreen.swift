#if DEBUG
import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI

/// Debug review aid (`-widgetPreview YES`): the real widget view at this iPhone's medium widget
/// size, for today and for the middle of each phase of the current cycle, from the bundled data.
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
                        WidgetFrame { MercuryWidgetView(content: sample.content) }
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

/// iOS's medium widget frame for this screen width, with its rounded corners and 16 pt margins.
private struct WidgetFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let width = UIScreen.main.bounds.width
        let size = width >= 428 ? CGSize(width: 364, height: 170) : width >= 390 ? CGSize(width: 338, height: 158) : CGSize(width: 321, height: 148)
        content
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(WidgetBackground())
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}
#endif
