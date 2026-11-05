import Notifications
import Observation
import RetroCore

/// App-level navigation: the selected tab, the three header destinations (share → invite,
/// bell → Notification Center, gear → Settings), and focus requests from tapped notifications.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab
    var showsNotificationCenter = false
    var showsSettings = false
    var showsShareInvite = false
    /// Set when a notification asks for a Calendar day; the Calendar selects it and clears this.
    var calendarFocus: CalendarDay?
    /// Set when a notification asks for a Survival Kit section; the kit expands it and clears this.
    var kitFocus: String?

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

    private func closeHeaderSheets() {
        showsNotificationCenter = false
        showsSettings = false
        showsShareInvite = false
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
            tab = .calendar
            calendarFocus = day
        case let .survivalKitSection(id):
            tab = .survivalKit
            kitFocus = id
        case .survivalKit:
            tab = .survivalKit
        }
    }
}
