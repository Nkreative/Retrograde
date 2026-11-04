import DesignSystem
import Notifications
import SwiftUI
import UIKit
import UserNotifications

/// Settings › Notifications, following the approved mockup: Mercury alerts and Survival Kit
/// reminders, edited as a draft and saved with Save Preferences. Opening it never asks for
/// permission and nothing is scheduled yet (M11).
struct NotificationPreferencesView: View {
    @Environment(NotificationPreferences.self) private var preferences
    @State private var draft: Set<NotificationKind> = []
    @State private var loaded = false
    @State private var authorization: NotificationAuthorization?
    @State private var savedAt: Date?

    var body: some View {
        List {
            Section {
                Text("Choose which alerts and reminders you’d like. Alerts start once notification delivery arrives in an upcoming update — your choices are saved and ready.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
                    .listRowBackground(Color.clear)
            }
            if let authorization {
                PermissionStatus(authorization: authorization)
            }
            Section {
                toggle(.mercuryTurnsRetrograde, "When Mercury turns retrograde")
                toggle(.mercuryTurnsDirect, "When Mercury turns direct")
                toggle(.beforeMercuryRetrograde, "2 weeks and 3 days before it turns retrograde")
                toggle(.beforeMercuryDirect, "2 weeks and 3 days before it turns direct")
            } header: {
                header("Mercury notifications")
            }
            .listRowBackground(RetroColor.surface)
            Section {
                toggle(.newCycleTasks, "When a new cycle’s tasks are ready")
                toggle(.unfinishedTasks, "Every other day, if tasks are unfinished")
            } header: {
                header("Survival Kit reminders")
            }
            .listRowBackground(RetroColor.surface)
            Section {
                PrimaryButton(savedAt != nil && draft == preferences.enabled ? "Saved" : "Save preferences",
                              systemImage: savedAt != nil && draft == preferences.enabled ? RetroSymbol.check : nil) {
                    preferences.save(draft)
                    savedAt = .now
                    AccessibilityNotification.Announcement("Preferences saved").post()
                }
                .disabled(draft == preferences.enabled)
                .opacity(draft == preferences.enabled ? 0.55 : 1)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                if draft != preferences.enabled {
                    Text("You have unsaved changes.").retroText(.body).foregroundStyle(RetroColor.yellow)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded { draft = preferences.enabled; loaded = true }
        }
        .task { authorization = await NotificationPermission.current() }
    }

    private func toggle(_ kind: NotificationKind, _ title: String) -> some View {
        Toggle(isOn: Binding(get: { draft.contains(kind) }, set: { on in
            if on { draft.insert(kind) } else { draft.remove(kind) }
        })) {
            Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.text)
        }
        .frame(minHeight: 44)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased()).retroText(.mono).foregroundStyle(RetroColor.textMuted)
    }
}

/// iOS permission, read without prompting.
private struct PermissionStatus: View {
    let authorization: NotificationAuthorization
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(color).font(.system(size: 16, weight: .semibold)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                    Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            if authorization == .denied, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Button { openURL(url) } label: {
                    Label("Open iOS Settings", systemImage: RetroSymbol.externalLink).retroText(.bodyStrong)
                }
                .frame(minHeight: 44)
            }
        }
        .listRowBackground(authorization == .denied ? RetroColor.wine : RetroColor.surface)
    }

    private var title: String {
        switch authorization {
        case .allowed: "Notifications are allowed"
        case .provisional: "Delivered quietly"
        case .denied: "Notifications are off for Retrograde"
        case .notDetermined: "Permission not requested yet"
        }
    }

    private var detail: String {
        switch authorization {
        case .allowed: "Retrograde can show alerts once they’re available."
        case .provisional: "Retrograde alerts go straight to Notification Center, without sounds or banners. You can change this in iOS Settings."
        case .denied: "Your choices are saved, but iOS won’t show Retrograde alerts until you turn notifications on."
        case .notDetermined: "We’ll ask once alerts are ready — and only if you’ve turned some on."
        }
    }

    private var icon: String {
        switch authorization {
        case .allowed: "checkmark.circle.fill"
        case .provisional: "bell"
        case .denied: RetroSymbol.notificationsOff
        case .notDetermined: "bell.badge"
        }
    }

    private var color: Color { authorization == .denied ? RetroColor.pink : RetroColor.textMuted }
}

/// Reads the current permission without asking for it.
enum NotificationPermission {
    static func current() async -> NotificationAuthorization {
        #if DEBUG
        // `-notificationAuth denied|allowed|provisional|notDetermined` for review screenshots.
        switch UserDefaults.standard.string(forKey: "notificationAuth") {
        case "denied": return .denied
        case "allowed": return .allowed
        case "provisional": return .provisional
        case "notDetermined": return .notDetermined
        default: break
        }
        #endif
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAuthorization(settings.authorizationStatus)
    }
}
