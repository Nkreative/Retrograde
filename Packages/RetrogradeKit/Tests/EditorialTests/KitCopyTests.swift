import RetroCore
import Testing
@testable import Editorial

@Suite struct KitCopyTests {
    @Test func introductionNamesThePlanetAndCountsTheTasks() {
        #expect(KitCopy.introduction(planet: .mercury, taskCount: 27) == "Mercury’s doing its thing. You’ve got 27 ways to beat the chaos. Complete each task, build your progress, and make it through this retrograde on your terms.")
    }
}
