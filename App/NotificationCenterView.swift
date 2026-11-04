import DesignSystem
import Notifications
import SwiftUI

/// The bell's destination: notifications Retrograde created for this person, newest first.
/// Only entries whose time has come appear; nothing is invented.
struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationHistory.self) private var history
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            Group {
                if history.visible.isEmpty {
                    EmptyNotifications()
                } else {
                    List {
                        ForEach(history.visible) { record in
                            Button { open(record) } label: { NotificationRow(record: record) }
                                .buttonStyle(.plain)
                                .listRowBackground(record.isRead ? RetroColor.surface : RetroColor.wine)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .retroScreenBackground()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mark all as read") { history.markAllRead() }
                        .disabled(history.unreadCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(RetroColor.pink)
        .preferredColorScheme(.dark)
    }

    private func open(_ record: NotificationRecord) {
        history.markRead(id: record.id)
        if let destination = record.destination {
            router.open(destination)
        }
    }
}

private struct NotificationRow: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RetroColor.pink)
                .frame(width: 34, height: 34)
                .background(RetroColor.chip, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.chip))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(record.title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                    Spacer(minLength: 8)
                    if !record.isRead {
                        Circle().fill(RetroColor.pink).frame(width: 8, height: 8).accessibilityHidden(true)
                    }
                }
                Text(record.body).retroText(.body).foregroundStyle(RetroColor.textMuted)
                Text(record.fireDate.formatted(.relative(presentation: .named)))
                    .retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
            }
            if record.destination != nil {
                Image(systemName: RetroSymbol.chevronRight).font(.footnote).foregroundStyle(RetroColor.textMuted)
                    .padding(.top, 4).accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.isRead ? "" : "Unread. ")\(record.title). \(record.body). \(record.fireDate.formatted(.relative(presentation: .named)))")
        .accessibilityHint(record.destination == nil ? "" : "Opens the related \(record.destination!.spokenName)")
    }
}

private struct EmptyNotifications: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(RetroColor.textMuted)
                .accessibilityHidden(true)
            Text("You’re all caught up.").retroText(.cardTitle).foregroundStyle(RetroColor.text)
            Text("Retrograde alerts — Mercury turning points, new Survival Kits and reminders you choose — will appear here.")
                .retroText(.body).foregroundStyle(RetroColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(RetroMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension NotificationKind {
    var symbol: String {
        switch self {
        case .mercuryTurnsRetrograde, .beforeMercuryRetrograde: "arrow.uturn.backward"
        case .mercuryTurnsDirect, .beforeMercuryDirect: "arrow.forward"
        case .newCycleTasks: RetroSymbol.firstAid
        case .unfinishedTasks: RetroSymbol.checkCircle
        }
    }
}

private extension NotificationDestination {
    var spokenName: String {
        switch self {
        case .calendarDay: "calendar day"
        case .survivalKitSection: "Survival Kit section"
        }
    }
}

#if DEBUG
/// Sample entries for review screenshots (`-sampleNotifications YES`); never shown to real users.
enum SampleNotifications {
    static func records(now: Date = .now) -> [NotificationRecord] {
        let hour: TimeInterval = 3_600
        var read = NotificationRecord(id: "sample.lead-3d", kind: .beforeMercuryRetrograde, title: "Mercury turns retrograde in 3 days",
                                      body: "A good moment to back up and wrap up open loops.", fireDate: now - 4 * 24 * hour,
                                      destination: .calendarDay("2026-10-24"))
        read.readAt = now - 3 * 24 * hour
        return [
            NotificationRecord(id: "sample.direct", kind: .mercuryTurnsDirect, title: "Mercury turns direct today",
                               body: "Its apparent backward motion ends. Revisit what you’ve been putting off.",
                               fireDate: now - 2 * hour, destination: .calendarDay("2026-11-13")),
            NotificationRecord(id: "sample.tasks", kind: .newCycleTasks, title: "Your new Survival Kit is ready",
                               body: "27 small moves for this cycle. Start with one.", fireDate: now - 26 * hour,
                               destination: .survivalKitSection("communication")),
            read,
        ]
    }
}
#endif
