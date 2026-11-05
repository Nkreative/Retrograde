import AstroData
import Foundation
import RetroCore
import Testing
@testable import Notifications

/// Real Mercury periods from the bundled ephemeris; expectations are derived from their instants.
@Suite struct NotificationPlannerTests {
    let mercury: [RetrogradePeriod]

    init() throws {
        mercury = try BundledEphemeris.load().retrogrades.filter { $0.planet == .mercury }
    }

    private func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    /// The Mercury retrograde whose station direct falls in that UTC month (e.g. "2026-11").
    private func period(directIn month: String) -> RetrogradePeriod {
        mercury.first { CalendarDay($0.stationDirect, in: calendar("UTC")).description.hasPrefix(month) }!
    }

    private func plan(_ zone: String, enabled: Set<NotificationKind> = Set(NotificationKind.allCases),
                      remaining: Int = 4, now: Date) -> [PlannedNotification] {
        NotificationPlanner(periods: mercury, calendar: calendar(zone))
            .plan(enabled: enabled, remainingTasks: { _ in remaining }, now: now)
    }

    private func hourMinute(_ date: Date, _ zone: String) -> (Int, Int) {
        let c = calendar(zone).dateComponents([.hour, .minute], from: date)
        return (c.hour!, c.minute!)
    }

    // MARK: Event dates and local times

    @Test func eventAlertsNeverFireBeforeTheEventAndKeepSociableHours() {
        let p = period(directIn: "2026-11")
        let now = p.stationRetrograde - 30 * 86_400
        for zone in ["America/New_York", "America/Los_Angeles", "Asia/Tokyo", "Asia/Kolkata", "Pacific/Auckland", "UTC"] {
            let direct = plan(zone, now: now).first { $0.id == "\(p.id).direct" }!
            #expect(direct.fireDate >= p.stationDirect, "\(zone)")
            let (h, _) = hourMinute(direct.fireDate, zone)
            #expect((9...21).contains(h), "\(zone)")
            // Opens the Calendar on the station's local day.
            #expect(direct.destination == .calendarDay(CalendarDay(p.stationDirect, in: calendar(zone)).description), "\(zone)")
        }
    }

    @Test func eventTimeRules() {
        let p = period(directIn: "2026-11")
        let planner = { (zone: String) in NotificationPlanner(periods: [], calendar: calendar(zone)) }
        for zone in ["America/New_York", "America/Los_Angeles", "Asia/Tokyo", "Asia/Kolkata"] {
            let cal = calendar(zone)
            let local = cal.dateComponents([.hour, .minute], from: p.stationDirect)
            let fire = planner(zone).eventTime(p.stationDirect)!
            let localMinutes = local.hour! * 60 + local.minute!
            if localMinutes < 9 * 60 {
                #expect(hourMinute(fire, zone) == (9, 0) && CalendarDay(fire, in: cal) == CalendarDay(p.stationDirect, in: cal), "\(zone)")
            } else if localMinutes <= 21 * 60 {
                #expect(fire == p.stationDirect, "\(zone)") // the moment itself
            } else {
                #expect(hourMinute(fire, zone) == (9, 0) && CalendarDay(fire, in: cal) == CalendarDay(p.stationDirect, in: cal).adding(days: 1), "\(zone)")
            }
        }
    }

    @Test func leadAlertsAtNineOnTheRightDays() {
        let p = period(directIn: "2026-11")
        let zone = "Europe/London"
        let cal = calendar(zone)
        let alerts = plan(zone, now: p.stationRetrograde - 30 * 86_400)
        let retrogradeDay = CalendarDay(p.stationRetrograde, in: cal)
        for lead in [14, 3] {
            let a = alerts.first { $0.id == "\(p.id).retrograde.lead-\(lead)d" }!
            #expect(CalendarDay(a.fireDate, in: cal) == retrogradeDay.adding(days: -lead))
            #expect(hourMinute(a.fireDate, zone) == (9, 0))
            #expect(a.destination == .calendarDay(retrogradeDay.description))
            #expect(a.kind == .beforeMercuryRetrograde)
        }
        #expect(alerts.first { $0.id == "\(p.id).retrograde.lead-3d" }!.title == "Three days until Mercury acts up.")
        #expect(alerts.first { $0.id == "\(p.id).retrograde.lead-14d" }!.title == "Two weeks until Mercury acts up.")
    }

    // MARK: Time zones and daylight saving

    @Test func daylightSavingKeepsLocalTimes() {
        // The March 2026 station direct comes after US clocks go forward; its 2-week alert before.
        let p = period(directIn: "2026-03")
        let zone = "America/New_York"
        let cal = calendar(zone)
        let alerts = plan(zone, now: p.stationRetrograde - 1)
        let lead = alerts.first { $0.id == "\(p.id).direct.lead-14d" }!
        #expect(hourMinute(lead.fireDate, zone) == (9, 0))
        #expect(!cal.timeZone.isDaylightSavingTime(for: lead.fireDate))
        let direct = alerts.first { $0.id == "\(p.id).direct" }!
        #expect(cal.timeZone.isDaylightSavingTime(for: direct.fireDate))
        #expect(direct.fireDate >= p.stationDirect)
        for reminder in alerts where reminder.kind == .unfinishedTasks {
            #expect(hourMinute(reminder.fireDate, zone) == (18, 0)) // either side of the change
        }
    }

    @Test func aTimeZoneChangeMovesTimesButKeepsIDs() {
        let p = period(directIn: "2026-11")
        let now = p.stationRetrograde - 30 * 86_400
        let newYork = plan("America/New_York", now: now)
        let tokyo = plan("Asia/Tokyo", now: now)
        let lead = "\(p.id).retrograde.lead-3d"
        #expect(newYork.first { $0.id == lead }!.fireDate != tokyo.first { $0.id == lead }!.fireDate)
        #expect(hourMinute(tokyo.first { $0.id == lead }!.fireDate, "Asia/Tokyo") == (9, 0))
        // The same events, so rescheduling after travelling replaces rather than duplicates.
        let inBoth = Set(newYork.map(\.id)).intersection(tokyo.map(\.id))
        #expect(inBoth.count > newYork.count / 2)
    }

    // MARK: Preferences, duplicates, the past, the iOS limit

    @Test func onlyChosenKindsAreScheduled() {
        let p = period(directIn: "2026-11")
        let now = p.stationRetrograde - 30 * 86_400
        let defaults = plan("UTC", enabled: NotificationPreferences.defaults, now: now)
        #expect(Set(defaults.map(\.kind)).isSubset(of: NotificationPreferences.defaults))
        #expect(!defaults.contains { $0.kind == .beforeMercuryDirect || $0.kind == .unfinishedTasks })
        #expect(defaults.contains { $0.id == "\(p.id).retrograde.lead-14d" } && defaults.contains { $0.id == "\(p.id).retrograde.lead-3d" })
        #expect(plan("UTC", enabled: [], now: now).isEmpty)
        let onlyDirect = plan("UTC", enabled: [.mercuryTurnsDirect], now: now)
        #expect(onlyDirect.allSatisfy { $0.kind == .mercuryTurnsDirect } && !onlyDirect.isEmpty)
    }

    @Test func stableIDsAndNoDuplicates() {
        let now = period(directIn: "2026-11").stationRetrograde - 30 * 86_400
        let a = plan("Europe/Paris", now: now), b = plan("Europe/Paris", now: now)
        #expect(a == b)
        #expect(Set(a.map(\.id)).count == a.count)
    }

    @Test func neverInThePastAndSoonestFirstWithinTheLimit() {
        let p = period(directIn: "2026-11")
        let now = p.stationRetrograde + 3_600 // mid-cycle: the lead alerts are already past
        let alerts = plan("UTC", now: now)
        #expect(alerts.allSatisfy { $0.fireDate > now })
        #expect(!alerts.contains { $0.id.hasPrefix("\(p.id).retrograde.lead") }) // both lead alerts already passed
        #expect(alerts.count <= NotificationPlanner.pendingLimit)
        #expect(alerts.count == NotificationPlanner.pendingLimit) // every kind on: more than fit
        #expect(alerts == alerts.sorted { $0.fireDate < $1.fireDate || ($0.fireDate == $1.fireDate && $0.id < $1.id) })
    }

    // MARK: Survival Kit

    @Test func kitReadyAtSixAfterTheRollover() {
        let p = period(directIn: "2026-11")
        let zone = "America/Chicago"
        let ready = plan(zone, now: p.stationRetrograde - 86_400).first { $0.id == "\(p.id).kit.ready" }!
        #expect(ready.fireDate >= p.stationRetrograde)
        #expect(hourMinute(ready.fireDate, zone) == (18, 0))
        #expect(ready.destination == .survivalKit)
        #expect(ready.title == "Your survival kit is ready.")
    }

    @Test func remindersEveryOtherDayOnlyWhileTasksRemain() {
        let p = period(directIn: "2026-11")
        let zone = "UTC"
        let now = p.stationRetrograde + 60
        let reminders = plan(zone, enabled: [.unfinishedTasks], remaining: 3, now: now).filter { $0.id.hasPrefix(p.id) }
        #expect(!reminders.isEmpty)
        let days = reminders.map { CalendarDay($0.fireDate, in: calendar(zone)) }
        #expect(zip(days, days.dropFirst()).allSatisfy { $0.days(to: $1) == 2 })
        #expect(reminders.allSatisfy { $0.fireDate < p.postShadowEnd && hourMinute($0.fireDate, zone) == (18, 0) })
        #expect(reminders.first!.body == "3 small moves left this cycle. Pick one.")
        #expect(plan(zone, enabled: [.unfinishedTasks], remaining: 1, now: now).first!.body == "1 small move left this cycle. You’ve got this.")
        // Everything done: no reminders for this cycle.
        let finished = NotificationPlanner(periods: mercury, calendar: calendar(zone))
            .plan(enabled: [.unfinishedTasks], remainingTasks: { $0.id == p.id ? 0 : 5 }, now: now)
        #expect(!finished.contains { $0.id.hasPrefix(p.id) })
    }

    @Test func copy() {
        #expect(NotificationCopy.turnsRetrograde(.mercury) == .init(title: "Mercury’s officially going backward.", body: "Your cosmic backup plan starts now."))
        #expect(NotificationCopy.turnsDirect(.mercury) == .init(title: "Mercury’s moving forward again.", body: "The universe has stopped buffering. Mostly."))
        #expect(NotificationCopy.beforeRetrograde(.mercury, days: 3).body == "Maybe back up your files. Just saying.")
        #expect(NotificationCopy.spoken(14) == "two weeks" && NotificationCopy.spoken(3) == "three days")
    }

    @Test func destinationsSurviveTheTripThroughIOS() {
        for d in [NotificationDestination.calendarDay("2026-11-13"), .survivalKitSection("journal"), .survivalKit] {
            #expect(NotificationDestination(userInfoValue: d.userInfoValue) == d)
        }
        #expect(NotificationDestination(userInfoValue: "nonsense") == nil)
    }
}
