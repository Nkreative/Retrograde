import Foundation
import RetroCore
import Testing
@testable import Editorial

@Suite struct DailyInsightCopyTests {
    private func reading(_ day: String, _ influences: [Influence]) -> DailyIntensity {
        DailyIntensity(day: CalendarDay(iso: day)!, influences: influences, methodologyVersion: 1)
    }

    @Test func atLeastEightHabitsPerLevelAcrossAllTopics() {
        for level in IntensityLevel.allCases {
            let pool = DailyInsightCopy.habits[level]!
            #expect(pool.count >= 8, "\(level)")
            #expect(Set(pool.map(\.topic)) == Set(DailyInsight.HabitTopic.allCases), "\(level)")
        }
    }

    @Test func tagsUseTheApprovedNames() {
        let approved: Set = ["RETROGRADE", "TURNING POINT", "NEAR STATION", "SHADOW", "MOON PHASE", "SIGN CHANGE"]
        let kinds: [Influence.Kind] = [
            .mercuryRetrograde(day: 3, totalDays: 21), .mercuryStation(turningDirect: true), .nearMercuryStation,
            .mercuryShadow(beforeRetrograde: false), .planetRetrograde(.venus), .planetStation(.pluto, turningDirect: true),
            .newMoon, .fullMoon, .mercuryIngress(.scorpio, retrograde: false),
        ]
        for kind in kinds {
            #expect(approved.contains(DailyInsightCopy.row(Influence(kind: kind, points: 1)).tag))
        }
    }

    /// Editorial rule: reflection prompts, not predictions.
    @Test func noPredictiveLanguage() {
        let banned = ["will ", "won’t", "expect", "guarantee", "going to", "bad luck", "disaster", "beware", "warning", "doomed", "inevitable", "lag"]
        for line in DailyInsightCopy.allText {
            for word in banned {
                #expect(!line.lowercased().contains(word), "“\(line)” contains “\(word)”")
            }
        }
    }

    @Test func turningDirectUsesTheApprovedWording() {
        let row = DailyInsightCopy.row(Influence(kind: .mercuryStation(turningDirect: true), points: 3))
        #expect(row.text == "Mercury’s apparent backward motion ends today. A good moment to revisit what you’ve been putting off.")
    }

    @Test func summaryFollowsTheStrongestEvent() {
        let station = reading("2026-11-13", [Influence(kind: .mercuryStation(turningDirect: true), points: 3), Influence(kind: .mercuryRetrograde(day: 21, totalDays: 21), points: 2)])
        #expect(DailyInsightCopy.insight(for: station).summary.hasPrefix("Mercury turns direct today."))
        let shadow = reading("2026-11-20", [Influence(kind: .mercuryShadow(beforeRetrograde: false), points: 1)])
        #expect(DailyInsightCopy.summaries.mildShadow.contains(DailyInsightCopy.insight(for: shadow).summary))
        let rx = reading("2026-11-03", [Influence(kind: .mercuryRetrograde(day: 11, totalDays: 21), points: 2), Influence(kind: .planetRetrograde(.venus), points: 1)])
        #expect(DailyInsightCopy.summaries.elevatedRetrograde.contains(DailyInsightCopy.insight(for: rx).summary))
    }

    @Test func deterministicAndRotatesDayToDay() {
        let a = reading("2026-12-02", [])
        #expect(DailyInsightCopy.insight(for: a) == DailyInsightCopy.insight(for: a))
        let b = reading("2026-12-03", [])
        #expect(DailyInsightCopy.insight(for: a).habit != DailyInsightCopy.insight(for: b).habit)
        #expect(DailyInsightCopy.insight(for: a).habit.topic != DailyInsightCopy.insight(for: b).habit.topic)
        #expect(DailyInsightCopy.insight(for: a).summary != DailyInsightCopy.insight(for: b).summary)
    }
}
