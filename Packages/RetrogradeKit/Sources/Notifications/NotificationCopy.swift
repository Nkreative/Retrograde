import RetroCore

/// What each alert says: short, useful, a little sarcastic, and only ever about a real event.
public enum NotificationCopy {
    public struct Content: Equatable, Sendable {
        public let title: String
        public let body: String
    }

    public static func turnsRetrograde(_ planet: Planet) -> Content {
        Content(title: "\(name(planet))’s officially going backward.", body: "Your cosmic backup plan starts now.")
    }

    public static func turnsDirect(_ planet: Planet) -> Content {
        Content(title: "\(name(planet))’s moving forward again.", body: "The universe has stopped buffering. Mostly.")
    }

    /// `days` before the planet turns retrograde (14 or 3).
    public static func beforeRetrograde(_ planet: Planet, days: Int) -> Content {
        days >= 7
            ? Content(title: "\(spoken(days).capitalizedFirst) until \(name(planet)) acts up.", body: "Plenty of time to get ahead of the chaos.")
            : Content(title: "\(spoken(days).capitalizedFirst) until \(name(planet)) acts up.", body: "Maybe back up your files. Just saying.")
    }

    /// `days` before the planet turns direct (14 or 3).
    public static func beforeDirect(_ planet: Planet, days: Int) -> Content {
        days >= 7
            ? Content(title: "\(spoken(days).capitalizedFirst) until \(name(planet)) turns direct.", body: "Still backward. Still survivable.")
            : Content(title: "\(spoken(days).capitalizedFirst) until \(name(planet)) turns direct.", body: "The finish line is in sight. Hang in there.")
    }

    public static let kitReady = Content(title: "Your survival kit is ready.", body: "A little preparation never hurt anyone.")

    /// `remaining` = tasks the person can open and hasn't finished this cycle (always ≥ 1 here).
    public static func unfinishedTasks(remaining: Int) -> Content {
        Content(
            title: "Your survival kit misses you.",
            body: remaining == 1 ? "1 small move left this cycle. You’ve got this." : "\(remaining) small moves left this cycle. Pick one."
        )
    }

    private static func name(_ planet: Planet) -> String { planet.rawValue.capitalized }

    /// "two weeks", "three days", "10 days".
    static func spoken(_ days: Int) -> String {
        if days % 7 == 0 {
            let weeks = days / 7
            return weeks == 1 ? "one week" : "\(number(weeks)) weeks"
        }
        return days == 1 ? "one day" : "\(number(days)) days"
    }

    private static func number(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        return n < words.count ? words[n] : "\(n)"
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
