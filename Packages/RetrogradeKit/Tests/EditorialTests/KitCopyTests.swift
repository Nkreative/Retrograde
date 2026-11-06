import RetroCore
import Testing
@testable import Editorial

@Suite struct KitCopyTests {
    @Test func introductionCountsTheTasks() {
        #expect(KitCopy.introduction(taskCount: 27) == "27 ways to outsmart the chaos. One task at a time.")
    }
}
