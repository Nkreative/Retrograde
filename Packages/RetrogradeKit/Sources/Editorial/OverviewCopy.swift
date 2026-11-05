import RetroCore

/// Interpretive copy for the Overview, one set per cycle stage. Astrology is framed as a
/// reflection prompt, never a prediction. Retrograde and direct copy is from the approved
/// Figma screens; the shadow-stage copy follows the same voice.
public struct OverviewCopy: Equatable, Sendable {
    /// Small label after the countdown number ("days to exhale").
    public let countdownUnit: String
    /// Singular form ("day to exhale").
    public let countdownUnitSingular: String
    /// Shown after a large "TODAY" on the target day ("Mercury turns direct").
    public let countdownToday: String
    /// Right-hand label above the bar ("DAY {day} / {total}"); nil where a day count would confuse (direct).
    public let dayLabel: String?
    public let barStart: String
    public let barEnd: String
    public let heroHeadline: String
    /// When the Survival Kit helps, in the kit introduction ("for the next {days}"); `{days}` is
    /// the countdown ("9 days").
    let kitTiming: String
    /// Used instead on the countdown's last day.
    let kitTimingToday: String

    public func countdownUnit(for days: Int) -> String {
        days == 1 ? countdownUnitSingular : countdownUnit
    }

    public func dayLabel(day: Int, of total: Int) -> String? {
        dayLabel?.replacingOccurrences(of: "{day}", with: "\(day)").replacingOccurrences(of: "{total}", with: "\(total)")
    }

    /// The Overview's Survival Kit introduction (approved M13.1 Figma), timed to the stage.
    public func kitIntroduction(daysUntilTarget days: Int) -> String {
        let timing = days == 0 ? kitTimingToday
            : kitTiming.replacingOccurrences(of: "{days}", with: days == 1 ? "1 day" : "\(days) days")
        return "Quick, practical tasks \(timing): slow down your messages, back up what matters, pad your plans and write it out. Tick them off as you go."
    }

    /// Copy for a planet's stage; nil for planets without launch copy.
    public static func `for`(_ planet: Planet, _ stage: CycleStatus.Stage) -> OverviewCopy? {
        guard planet == .mercury else { return nil }
        return switch stage {
        case .retrograde: mercuryRetrograde
        case .direct: mercuryDirect
        case .preShadow: mercuryPreShadow
        case .postShadow: mercuryPostShadow
        }
    }

    static let mercuryRetrograde = OverviewCopy(
        countdownUnit: "days to exhale",
        countdownUnitSingular: "day to exhale",
        countdownToday: "Mercury turns direct",
        dayLabel: "DAY {day} / {total}",
        barStart: "RETROGRADE",
        barEnd: "DIRECT",
        heroHeadline: "A LITTLE CHAOS.\nA LOT OF BACKUP.",
        kitTiming: "for the next {days}",
        kitTimingToday: "for the rest of this retrograde"
    )

    static let mercuryPostShadow = OverviewCopy(
        countdownUnit: "days till the dust settles",
        countdownUnitSingular: "day till the dust settles",
        countdownToday: "the shadow lifts",
        dayLabel: "SHADOW · DAY {day} / {total}",
        barStart: "POST-SHADOW",
        barEnd: "ALL CLEAR",
        heroHeadline: "BACK ON TRACK.\nMOSTLY.",
        kitTiming: "while Mercury retraces its steps",
        kitTimingToday: "while Mercury retraces its steps"
    )

    static let mercuryDirect = OverviewCopy(
        countdownUnit: "days till the next plot twist",
        countdownUnitSingular: "day till the next plot twist",
        countdownToday: "Mercury turns retrograde",
        // The direct window starts when the last shadow ends, so a day count reads as if it
        // belonged to the previous cycle; the countdown alone is clearer.
        dayLabel: nil,
        barStart: "DIRECT",
        barEnd: "NEXT RX",
        heroHeadline: "ALL CLEAR.\nFOR NOW.",
        kitTiming: "to get ready for the next retrograde",
        kitTimingToday: "to get ready for the next retrograde"
    )

    static let mercuryPreShadow = OverviewCopy(
        countdownUnit: "days till the slowdown",
        countdownUnitSingular: "day till the slowdown",
        countdownToday: "Mercury turns retrograde",
        dayLabel: "SHADOW · DAY {day} / {total}",
        barStart: "PRE-SHADOW",
        barEnd: "RETROGRADE",
        heroHeadline: "WARM-UP LAP.\nBACK IT UP.",
        kitTiming: "before Mercury turns",
        kitTimingToday: "before Mercury turns today"
    )
}
