import AstroData
import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI
import WidgetKit

/// The widget extension (not compiled into the app). Everything it shows is worked out here from
/// the sky data bundled with it, so it needs no network, no account and no data from the app.
@main
struct RetrogradeWidgets: WidgetBundle {
    init() {
        RetroFonts.register()
    }

    var body: some Widget {
        MercuryCycleWidget()
    }
}

struct MercuryCycleWidget: Widget {
    static let kind = "MercuryCycle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CycleProvider()) { entry in
            MercuryWidgetView(content: entry.content)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(WidgetLink.overview)
        }
        .configurationDisplayName("Mercury")
        .description("Mercury’s phase, countdown and progress at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct CycleEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent?
}

struct CycleProvider: TimelineProvider {
    /// Loaded once per widget process; nil only if the bundled file were unreadable.
    private static let ephemeris = try? BundledEphemeris.load()

    /// Built for each request so it uses the person's time zone at that moment.
    private var timeline: WidgetTimeline? {
        Self.ephemeris.map { WidgetTimeline(calculator: CycleCalculator(ephemeris: $0, calendar: .current), calendar: .current) }
    }

    func placeholder(in context: Context) -> CycleEntry {
        CycleEntry(date: .now, content: timeline?.content(at: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleEntry>) -> Void) {
        let now = Date.now
        guard let timeline else {
            let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
            completion(Timeline(entries: [CycleEntry(date: now, content: nil)], policy: .after(tomorrow)))
            return
        }
        let entries = timeline.entries(from: now).map { CycleEntry(date: $0.date, content: $0.content) }
        completion(Timeline(entries: entries, policy: .after(timeline.refreshDate(after: now))))
    }
}

#Preview(as: .systemMedium) {
    MercuryCycleWidget()
} timeline: {
    CycleEntry(date: .now, content: nil)
}
