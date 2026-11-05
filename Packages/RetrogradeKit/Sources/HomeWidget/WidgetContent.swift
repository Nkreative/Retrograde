import Editorial
import Foundation
import RetroCore

/// What the Home Screen widget shows at one moment: the Overview's stage, countdown and
/// "DAY x / y" label, in the same words. No interpretation of its own.
public struct WidgetContent: Equatable, Sendable {
    public let planet: Planet
    public let stage: CycleStatus.Stage
    /// "MERCURY".
    public let planetName: String
    /// "RETROGRADE", "PRE-SHADOW", "POST-SHADOW", "DIRECT".
    public let phaseName: String
    /// "10", or "TODAY" on the day of the countdown target.
    public let countdown: String
    /// "days to exhale", or "Mercury turns direct" on the day itself.
    public let countdownText: String
    /// Below the bar on the left: the Overview's day label ("DAY 12 / 22"), or the bar's start
    /// label in the direct stage, which has no day count.
    public let leading: String
    /// Below the bar on the right: where the bar ends ("DIRECT").
    public let trailing: String
    /// Fraction of the stage's window elapsed (0...1).
    public let progress: Double

    /// Content for a status; nil for planets without launch copy.
    public init?(status: CycleStatus) {
        guard let copy = OverviewCopy.for(status.planet, status.stage) else { return nil }
        let days = status.daysUntilTarget
        planet = status.planet
        stage = status.stage
        planetName = status.planet.rawValue.uppercased()
        phaseName = Self.phaseName(status.stage)
        countdown = days == 0 ? "TODAY" : "\(days)"
        countdownText = days == 0 ? copy.countdownToday : copy.countdownUnit(for: days)
        leading = copy.dayLabel(day: status.day, of: status.totalDays) ?? copy.barStart
        trailing = copy.barEnd
        progress = status.progress
    }

    /// One sentence for VoiceOver: "Mercury retrograde. 10 days to exhale. Day 12 of 22."
    public var accessibilityLabel: String {
        let name = planet.rawValue.capitalized
        let phase = phaseName.lowercased()
        let countdownSentence = countdown == "TODAY" ? "Today, \(countdownText)" : "\(countdown) \(countdownText)"
        let day = leading.replacingOccurrences(of: "SHADOW · ", with: "")
        let dayPart = day.hasPrefix("DAY ") ? " " + day.capitalized.replacingOccurrences(of: " / ", with: " of ") + "." : ""
        return "\(name) \(phase). \(countdownSentence).\(dayPart)"
    }

    static func phaseName(_ stage: CycleStatus.Stage) -> String {
        switch stage {
        case .preShadow: "PRE-SHADOW"
        case .retrograde: "RETROGRADE"
        case .postShadow: "POST-SHADOW"
        case .direct: "DIRECT"
        }
    }
}
