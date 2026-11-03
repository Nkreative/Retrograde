import RetroCore

/// A calendar day's detail: a summary for its level, one row per sky event, and a practical habit.
/// Wording is a reflection prompt, never a prediction (approved editorial direction, M7).
public struct DailyInsight: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        /// RETROGRADE, TURNING POINT, NEAR STATION, SHADOW, MOON PHASE or SIGN CHANGE.
        public let tag: String
        public let text: String
    }

    public enum HabitTopic: CaseIterable, Sendable { case communication, technology, planning, reflection }

    public struct Habit: Equatable, Sendable {
        public let topic: HabitTopic
        public let text: String
    }

    public let level: IntensityLevel
    public let summary: String
    /// Empty on a quiet day; see `quietDayRow`.
    public let rows: [Row]
    public let habit: Habit
}

public enum DailyInsightCopy {
    public static let quietDayText = "Nothing notable in the sky today. Enjoy the quiet."

    /// Deterministic: a given day always reads the same, and neighbouring days rotate lines.
    public static func insight(for reading: DailyIntensity) -> DailyInsight {
        let n = reading.day.ordinal
        return DailyInsight(
            level: reading.level,
            summary: pick(summaryPool(for: reading), n),
            rows: reading.influences.map(row),
            habit: pick(habits[reading.level]!, n)
        )
    }

    public static func levelName(_ level: IntensityLevel) -> String {
        switch level {
        case .calm: "Calm"
        case .mild: "Mild"
        case .elevated: "Elevated"
        case .intense: "Intense"
        }
    }

    private static func pick<T>(_ pool: [T], _ n: Int) -> T { pool[((n % pool.count) + pool.count) % pool.count] }

    // MARK: - Summaries

    private static func summaryPool(for reading: DailyIntensity) -> [String] {
        let kinds = reading.influences.map(\.kind)
        let strongest = kinds.first
        switch reading.level {
        case .intense:
            if case let .mercuryStation(turningDirect) = strongest {
                return turningDirect ? summaries.intenseTurningDirect : summaries.intenseTurningRetrograde
            }
            return summaries.intense
        case .elevated:
            return kinds.contains { if case .mercuryRetrograde = $0 { true } else { false } } ? summaries.elevatedRetrograde : summaries.elevated
        case .mild:
            switch strongest {
            case .mercuryShadow: return summaries.mildShadow
            case .newMoon, .fullMoon: return summaries.mildMoon
            default: return summaries.mild
            }
        case .calm:
            return summaries.calm
        }
    }

    static let summaries = (
        calm: [
            "Nothing loud in the sky today. A good day to do the thing you’ve been circling.",
            "Quiet orbit. Make plans, send the email, book the table.",
            "Clear-ish skies. Use the calm to get a little ahead.",
            "A low-noise day. Your future self would love a small head start.",
        ],
        mild: [
            "A little background hum. Nothing a second read-through can’t handle.",
            "Slightly busier sky. A few minutes of slack goes a long way.",
            "Mostly mellow, with a couple of things in the mix. Carry on, kindly.",
        ],
        mildShadow: [
            "Mercury’s in its shadow. Tie up loose ends while things feel steady.",
            "Shadow days: a gentle nudge to finish what’s half-done.",
        ],
        mildMoon: [
            "The Moon’s having a moment. Notice it; you don’t have to act on it.",
        ],
        elevated: [
            "A little louder, not a lost cause. Slow down where details matter.",
            "A few things stacking up. Buffers and simple plans are your friends.",
            "Busy sky, steady you. Double-check, then let it go.",
        ],
        elevatedRetrograde: [
            "Review-mode Mercury. Revisit before you send, and leave room for replies to wander.",
            "Mercury’s still in reverse. A great day for rereading, re-checking and recharging.",
            "Retrograde season, mid-cycle. Fewer assumptions, more clarifying questions.",
        ],
        intense: [
            "Lots overlapping in the sky today. Keep it gentle and keep it simple.",
            "Peak sky traffic. Lower the stakes where you can; the important stuff can wait a day.",
        ],
        intenseTurningDirect: [
            "Mercury turns direct today. A good moment to revisit what you’ve been putting off, one thing at a time.",
        ],
        intenseTurningRetrograde: [
            "Mercury turns retrograde today. A perfect excuse to back up, slow down and read twice.",
        ]
    )

    // MARK: - Event rows

    static func row(_ influence: Influence) -> DailyInsight.Row {
        switch influence.kind {
        case let .mercuryRetrograde(day, total):
            .init(title: "Mercury retrograde", tag: "RETROGRADE",
                  text: "Day \(day) of \(total) of Mercury’s review mode. Revisit details and leave room for replies to wander.")
        case .mercuryStation(turningDirect: true):
            .init(title: "Mercury turns direct", tag: "TURNING POINT",
                  text: "Mercury’s apparent backward motion ends today. A good moment to revisit what you’ve been putting off.")
        case .mercuryStation(turningDirect: false):
            .init(title: "Mercury turns retrograde", tag: "TURNING POINT",
                  text: "Mercury appears to pause and reverse today. A nice excuse to slow down and read things twice.")
        case .nearMercuryStation:
            .init(title: "Mercury near a turning point", tag: "NEAR STATION",
                  text: "Mercury is barely moving in the sky around now. Give yourself a little extra margin.")
        case .mercuryShadow(beforeRetrograde: true):
            .init(title: "Mercury pre-shadow", tag: "SHADOW",
                  text: "Mercury is crossing the stretch of sky it’s about to retrace. Handy for wrapping things up.")
        case .mercuryShadow(beforeRetrograde: false):
            .init(title: "Mercury post-shadow", tag: "SHADOW",
                  text: "Mercury is retracing its retrograde path. A tidy time to tie up loose ends.")
        case .planetRetrograde(.venus):
            .init(title: "Venus retrograde", tag: "RETROGRADE",
                  text: "Venus is in review mode. Astrologers link it to relationships, money and taste: a cue to revisit before you commit.")
        case let .planetRetrograde(planet):
            .init(title: "\(planet.name) retrograde", tag: "RETROGRADE",
                  text: "Mars is in review mode. Astrologers link it to drive and energy: pace yourself, and restart rather than force.")
        case let .planetStation(planet, turningDirect):
            .init(title: "\(planet.name) turns \(turningDirect ? "direct" : "retrograde")", tag: "TURNING POINT",
                  text: planet == .venus || planet == .mars
                      ? "\(planet.name) changes direction today. Notice what’s shifting before you act on it."
                      : "A slow, background shift in the sky. A nice prompt for a moment of reflection.")
        case .newMoon:
            .init(title: "New Moon", tag: "MOON PHASE",
                  text: "A fresh-start Moon. Nice for setting an intention, with no pressure to force outcomes.")
        case .fullMoon:
            .init(title: "Full Moon", tag: "MOON PHASE",
                  text: "Feelings can look bigger under a Full Moon. Pause before reacting.")
        case let .mercuryIngress(sign, retrograde):
            .init(title: retrograde ? "Mercury slips back into \(sign.name)" : "Mercury enters \(sign.name)", tag: "SIGN CHANGE",
                  text: "A change of scenery for Mercury. Notice whether your conversations change tone.")
        }
    }

    // MARK: - Habits (interleaved by topic so neighbouring days rotate topics)

    static let habits: [IntensityLevel: [DailyInsight.Habit]] = [
        .calm: interleave(
            communication: ["Send the message you’ve been drafting.", "Reach out to someone you’ve been meaning to thank."],
            technology: ["Do one 10-minute tech chore: updates or a backup.", "Clear out one folder of downloads you don’t need."],
            planning: ["Book the appointment you keep postponing.", "Plan one thing to look forward to this week."],
            reflection: ["Write down one thing that’s going well.", "Take a five-minute walk without your phone."]
        ),
        .mild: interleave(
            communication: ["Read important messages once more before sending.", "Confirm one plan with the person involved."],
            technology: ["Check your phone’s backup ran recently.", "Charge your power bank so it’s ready when you are."],
            planning: ["Add 10 minutes to anything time-sensitive today.", "Close one loose loop from earlier this week."],
            reflection: ["Notice one thing that’s draining you, and one that isn’t.", "End the day by writing down one small win."]
        ),
        .elevated: interleave(
            communication: ["Save the draft. Read it out loud, check what you actually mean, then send.", "Ask a clarifying question instead of assuming."],
            technology: ["Back up the one file you’d miss most.", "Write one important phone number on paper."],
            planning: ["Confirm time, place and booking before you leave.", "Pick one nonessential plan to move, and say so kindly."],
            reflection: ["Take three slow breaths before your next reply.", "Name the feeling you’re carrying today."]
        ),
        .intense: interleave(
            communication: ["Pause for one slow breath before replying to anything that stings.", "Keep messages short and kind; long talks can wait a day."],
            technology: ["Save your work often today. Future you says thanks.", "Let non-urgent updates and installs wait a day."],
            planning: ["Lower the stakes: postpone what can wait a day.", "Keep plans simple and leave an extra buffer."],
            reflection: ["Write down what’s in your control right now. Start there.", "Give yourself one quiet minute with nowhere to be."]
        ),
    ]

    private static func interleave(communication: [String], technology: [String], planning: [String], reflection: [String]) -> [DailyInsight.Habit] {
        let columns: [(DailyInsight.HabitTopic, [String])] = [(.communication, communication), (.technology, technology), (.planning, planning), (.reflection, reflection)]
        let rows = columns.map(\.1.count).max() ?? 0
        return (0..<rows).flatMap { i in columns.compactMap { topic, texts in i < texts.count ? DailyInsight.Habit(topic: topic, text: texts[i]) : nil } }
    }

    /// Every user-facing line, for editorial checks.
    static var allText: [String] {
        let s = summaries
        let pools: [[String]] = [s.calm, s.mild, s.mildShadow, s.mildMoon, s.elevated, s.elevatedRetrograde, s.intense, s.intenseTurningDirect, s.intenseTurningRetrograde]
        let summaryText: [String] = pools.flatMap { $0 }
        let kinds: [Influence.Kind] = [
            .mercuryRetrograde(day: 1, totalDays: 21), .mercuryStation(turningDirect: true), .mercuryStation(turningDirect: false),
            .nearMercuryStation, .mercuryShadow(beforeRetrograde: true), .mercuryShadow(beforeRetrograde: false),
            .planetRetrograde(.venus), .planetRetrograde(.mars), .planetStation(.venus, turningDirect: true),
            .planetStation(.saturn, turningDirect: false), .newMoon, .fullMoon, .mercuryIngress(.libra, retrograde: true),
        ]
        let rows: [DailyInsight.Row] = kinds.map { row(Influence(kind: $0, points: 1)) }
        let rowText: [String] = rows.flatMap { [$0.title, $0.text] }
        let habitText: [String] = habits.values.flatMap { $0.map(\.text) }
        return summaryText + rowText + habitText + [quietDayText]
    }
}

extension Planet {
    public var name: String { rawValue.capitalized }
}

extension ZodiacSign {
    public var name: String { rawValue.capitalized }
}

extension CalendarDay {
    /// Days since 2000-01-01; stable across time zones.
    var ordinal: Int { CalendarDay(year: 2000, month: 1, day: 1).days(to: self) }
}
