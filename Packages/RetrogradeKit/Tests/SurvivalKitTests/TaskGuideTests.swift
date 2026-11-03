import Foundation
import Testing
@testable import SurvivalKit

@Suite struct TaskGuideTests {
    let kit = SurvivalKit.for(.mercury)!

    @Test func everyTaskHasItsOwnGuide() {
        let guides = kit.tasks.compactMap { kit.guide(for: $0) }
        #expect(guides.count == 27)
        #expect(Set(guides.map(\.title)).count == 27)
        #expect(SurvivalKit.mercuryGuides.count == 27) // no guides for tasks that don't exist
    }

    @Test func journalTasksAreFillInPrompts() throws {
        let journal = try #require(kit.sections.first { $0.topic == .journal })
        for task in journal.tasks {
            guard case let .reflection(_, prompt, example) = kit.guide(for: task)?.practice else {
                Issue.record("\(task.id) is not a reflection"); continue
            }
            #expect(prompt.contains("___"))
            #expect(!example.isEmpty)
        }
    }

    @Test func experienceMixMatchesFigma() {
        var counts: [String: Int] = [:]
        for task in kit.tasks {
            let key = switch kit.guide(for: task)!.practice {
            case .steps: "steps"
            case .checklist: "checklist"
            case .pauseTimer: "pause"
            case .breathing: "breathing"
            case .message, .template: "message"
            case .reflection: "reflection"
            }
            counts[key, default: 0] += 1
        }
        #expect(counts == ["steps": 10, "checklist": 5, "pause": 1, "breathing": 1, "message": 3, "reflection": 7] as [String: Int])
    }

    @Test func timedPracticesKnowTheirLength() {
        #expect(TaskGuide.Practice.breathing(inhale: 4, exhale: 6, rounds: 6).timerSeconds == 60)
        #expect(TaskGuide.Practice.pauseTimer(label: "", seconds: 10, caption: "", steps: []).timerSeconds == 10)
        #expect(TaskGuide.Practice.template(text: "").timerSeconds == nil)
    }
}

@Suite struct CountdownTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 0)

    @Test func startPauseResumeKeepsElapsedTime() {
        var c = CountdownState(duration: 10)
        #expect(c.remaining(at: t0) == 10)
        c.start(at: t0)
        #expect(c.remaining(at: t0 + 3) == 7)
        c.pause(at: t0 + 3)
        #expect(c.remaining(at: t0 + 100) == 7) // time doesn't pass while paused
        c.start(at: t0 + 100)
        #expect(c.remaining(at: t0 + 102) == 5)
    }

    @Test func finishesOnceAtZero() {
        var c = CountdownState(duration: 10)
        c.start(at: t0)
        let early = c.finishIfDue(at: t0 + 9.9)
        let onTime = c.finishIfDue(at: t0 + 10)
        let again = c.finishIfDue(at: t0 + 11)
        #expect(!early)
        #expect(onTime)
        #expect(!again) // the haptic fires once
        #expect(c.phase == .finished)
        #expect(c.remaining(at: t0 + 50) == 0)
    }

    @Test func restartReturnsToTheFullTime() {
        var c = CountdownState(duration: 60)
        c.start(at: t0)
        c.restart()
        #expect(c.phase == .ready)
        #expect(c.remaining(at: t0 + 30) == 60)
    }

    @Test func breathingAlternatesFourInSixOut() {
        #expect(BreathPosition(elapsed: 0, inhale: 4, exhale: 6).direction == .inhale)
        #expect(BreathPosition(elapsed: 0, inhale: 4, exhale: 6).secondsLeft == 4)
        #expect(BreathPosition(elapsed: 3.5, inhale: 4, exhale: 6).secondsLeft == 1)
        #expect(BreathPosition(elapsed: 4, inhale: 4, exhale: 6).direction == .exhale)
        #expect(BreathPosition(elapsed: 4, inhale: 4, exhale: 6).secondsLeft == 6)
        #expect(BreathPosition(elapsed: 10, inhale: 4, exhale: 6).direction == .inhale) // next round
    }
}
