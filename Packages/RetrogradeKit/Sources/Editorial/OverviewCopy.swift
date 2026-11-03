import RetroCore

/// Interpretive copy for the Overview, one set per cycle stage. Astrology is framed as a
/// reflection prompt, never a prediction. Retrograde and direct copy is from the approved
/// Figma screens; the shadow-stage copy follows the same voice.
public struct OverviewCopy: Equatable, Sendable {
    public enum Topic: CaseIterable, Sendable {
        case communication, techBackup, planning
    }

    public struct Tip: Equatable, Sendable {
        public let topic: Topic
        public let title: String
        public let action: String
    }

    /// Small label after the countdown number ("days to exhale").
    public let countdownUnit: String
    /// Singular form ("day to exhale").
    public let countdownUnitSingular: String
    /// Shown after a large "TODAY" on the target day ("Mercury turns direct").
    public let countdownToday: String
    /// Right-hand label above the bar; "%d" is the day and total ("DAY 12 / 22").
    public let dayLabel: String
    public let barStart: String
    public let barEnd: String
    public let heroHeadline: String
    public let sectionTitle: String
    /// The emphasised planet name is drawn in heavier type; this is the rest of the sentence.
    public let explanation: String
    public let tips: [Tip]
    public let callToAction: String

    public func countdownUnit(for days: Int) -> String {
        days == 1 ? countdownUnitSingular : countdownUnit
    }

    public func dayLabel(day: Int, of total: Int) -> String {
        dayLabel.replacingOccurrences(of: "{day}", with: "\(day)").replacingOccurrences(of: "{total}", with: "\(total)")
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
        sectionTitle: "SO, WHAT DOES IT MEAN?",
        explanation: "appears to move backward. In astrology, that’s your cue to slow down, not spiral.",
        tips: [
            Tip(topic: .communication, title: "Texts get lost in translation.", action: "Reread before you hit send. Yes, even that one."),
            Tip(topic: .techBackup, title: "Tech picks a dramatic moment.", action: "Save your work. Back up the important stuff."),
            Tip(topic: .planning, title: "Plans need a little wiggle room.", action: "Double-check details. Leave a little earlier."),
        ],
        callToAction: "Go to my survival kit"
    )

    static let mercuryPostShadow = OverviewCopy(
        countdownUnit: "days till the dust settles",
        countdownUnitSingular: "day till the dust settles",
        countdownToday: "the shadow lifts",
        dayLabel: "SHADOW · DAY {day} / {total}",
        barStart: "POST-SHADOW",
        barEnd: "ALL CLEAR",
        heroHeadline: "BACK ON TRACK.\nMOSTLY.",
        sectionTitle: "STILL RETRACING ITS STEPS.",
        explanation: "is moving forward again, back over the ground it covered in retrograde. Loose ends are easier to tie up now.",
        tips: [
            Tip(topic: .communication, title: "Revisit, then release.", action: "Reply to what got lost in the noise."),
            Tip(topic: .techBackup, title: "Check the fixes.", action: "Make sure restored files actually open."),
            Tip(topic: .planning, title: "Ease back in.", action: "Reschedule what you postponed, one at a time."),
        ],
        callToAction: "Go to my survival kit"
    )

    static let mercuryDirect = OverviewCopy(
        countdownUnit: "days till the next plot twist",
        countdownUnitSingular: "day till the next plot twist",
        countdownToday: "Mercury turns retrograde",
        dayLabel: "DIRECT · DAY {day}",
        barStart: "DIRECT",
        barEnd: "NEXT RX",
        heroHeadline: "ALL CLEAR.\nFOR NOW.",
        sectionTitle: "MERCURY IS DIRECT.",
        explanation: "is moving forward again. A good window to launch, sign and send, and to restock your backup for next time.",
        tips: [
            Tip(topic: .communication, title: "Say the thing.", action: "Send the message you’ve been drafting."),
            Tip(topic: .techBackup, title: "Do the tech chores.", action: "Updates, backups, the files you put off."),
            Tip(topic: .planning, title: "Lock in plans.", action: "Book, sign, confirm. Fewer plot twists now."),
        ],
        callToAction: "Prep my survival kit"
    )

    static let mercuryPreShadow = OverviewCopy(
        countdownUnit: "days till the slowdown",
        countdownUnitSingular: "day till the slowdown",
        countdownToday: "Mercury turns retrograde",
        dayLabel: "SHADOW · DAY {day} / {total}",
        barStart: "PRE-SHADOW",
        barEnd: "RETROGRADE",
        heroHeadline: "WARM-UP LAP.\nBACK IT UP.",
        sectionTitle: "MERCURY IS IN ITS SHADOW.",
        explanation: "is still moving forward, over ground it’s about to retrace. Wrap things up and get your backup ready before it turns.",
        tips: [
            Tip(topic: .communication, title: "Finish the conversation.", action: "Close loops now, not mid-retrograde."),
            Tip(topic: .techBackup, title: "Back up while it’s easy.", action: "Save copies before anything gets dramatic."),
            Tip(topic: .planning, title: "Pad the calendar.", action: "Leave buffers around plans in the weeks ahead."),
        ],
        callToAction: "Prep my survival kit"
    )
}
