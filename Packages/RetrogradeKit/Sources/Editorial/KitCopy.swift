import RetroCore

/// The Survival Kit tab's wording.
public enum KitCopy {
    /// The introduction under "SMALL MOVES. YOU’LL GET IT DONE."
    public static func introduction(planet: Planet, taskCount: Int) -> String {
        "\(planet.name)’s doing its thing. You’ve got \(taskCount) ways to beat the chaos. Complete each task, build your progress, and make it through this retrograde on your terms."
    }
}
