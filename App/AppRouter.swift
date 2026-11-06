import Notifications
import Observation
import RetroCore
import SurvivalKit

/// App-level navigation: the selected tab, the three header destinations (share → invite,
/// bell → Notification Center, gear → Settings), the widget how-to, and focus requests from
/// tapped notifications and the Overview.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab
    var showsNotificationCenter = false
    var showsSettings = false
    var showsShareInvite = false
    var showsWidgetHowTo = false
    /// Set when a notification asks for a Calendar day; the Calendar selects it and clears this.
    var calendarFocus: CalendarDay?
    /// Set when a notification asks for a Survival Kit section; the kit expands it and clears this.
    var kitFocus: String?
    /// Set when the Overview opens a task; the kit shows it and clears this.
    var kitTask: KitTask?

    init(tab: AppTab = .overview) {
        self.tab = tab
    }

    func openNotificationCenter() {
        closeHeaderSheets()
        showsNotificationCenter = true
    }

    func openSettings() {
        closeHeaderSheets()
        showsSettings = true
    }

    func openShareInvite() {
        closeHeaderSheets()
        showsShareInvite = true
    }

    func openWidgetHowTo() {
        closeHeaderSheets()
        showsWidgetHowTo = true
    }

    private func closeHeaderSheets() {
        showsNotificationCenter = false
        showsSettings = false
        showsShareInvite = false
        showsWidgetHowTo = false
    }

    /// Where the Overview dashboard's tappable areas lead.
    func open(overview destination: OverviewDestination) {
        switch destination {
        case .survivalKit: openKit()
        case let .today(day): openCalendar(on: day)
        case .shareInvite: openShareInvite()
        case .widgetHowTo: openWidgetHowTo()
        }
    }

    /// The Survival Kit tab, opened at a task.
    func openKit(at task: KitTask? = nil) {
        tab = .survivalKit
        kitTask = task
    }

    /// The Calendar tab with a day selected.
    func openCalendar(on day: CalendarDay) {
        tab = .calendar
        calendarFocus = day
    }

    /// The Home Screen widget was tapped: close what's on top and show the Overview.
    func openOverview() {
        closeHeaderSheets()
        tab = .overview
    }

    /// Closes the Notification Center (and Settings) and shows where the notification points.
    func open(_ destination: NotificationDestination) {
        closeHeaderSheets()
        switch destination {
        case let .calendarDay(iso):
            guard let day = CalendarDay(iso: iso) else { return }
            openCalendar(on: day)
        case let .survivalKitSection(id):
            tab = .survivalKit
            kitFocus = id
        case .survivalKit:
            tab = .survivalKit
        }
    }
}

/// The Overview dashboard's tappable areas (M13.1): the countdown and bars, today's intensity card,
/// the sharing card and the Add Widget pill.
enum OverviewDestination: Equatable {
    case survivalKit
    /// The Calendar with this day (today) selected.
    case today(CalendarDay)
    case shareInvite
    case widgetHowTo
}
