#if DEBUG
import DesignSystem
import Persistence
import SwiftUI

/// Settings › Developer › Widget status (debug builds only): what iOS last reported about
/// Retrograde's widgets and what the app saved from it. Read-only, apart from asking iOS again.
struct WidgetStatusView: View {
    @Environment(WidgetPrompt.self) private var prompt
    @State private var report = WidgetPresenceReport.shared
    @State private var isRefreshing = false
    /// Bumped on each refresh so a late answer from an earlier one can't end the current one.
    @State private var refreshID = 0

    var body: some View {
        List {
            Section {
                switch report.last {
                case nil:
                    row("Result", "No check yet this launch")
                case let .listed(sizes, total):
                    row("Result", "Succeeded")
                    row("Retrograde widgets", "\(sizes.count)")
                    row("Sizes", sizes.isEmpty ? "—" : sizes.joined(separator: ", "))
                    row("All configurations returned", "\(total)")
                case let .failed(message):
                    row("Result", "Failed").foregroundStyle(RetroColor.pink)
                    row("Error", message)
                }
                row("Checked at", report.checkedAt?.formatted(date: .abbreviated, time: .standard) ?? "—")
                row("Answers this launch", "\(report.checkCount)")
                if UserDefaults.standard.object(forKey: "widgetListed") != nil {
                    row("Note", "-widgetListed is set: iOS isn't asked")
                }
            } header: {
                Text("LAST WIDGETCENTER RESULT").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
            Section {
                row("Widget listed", prompt.widgetListed ? "Yes" : "No")
                row("Dashboard tip dismissed", prompt.tipDismissed ? "Yes" : "No")
            } header: {
                Text("SAVED STATE").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
            Section {
                Button(action: refresh) {
                    HStack(spacing: 10) {
                        Text(isRefreshing ? "Asking iOS…" : "Refresh widget status")
                        if isRefreshing { ProgressView() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .disabled(isRefreshing)
            } footer: {
                Text("Asks iOS again, exactly as the app does on launch. The saved state follows the answer, as it would anyway.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        // `-autoRefreshWidgetStatus YES` presses Refresh on open, for review screenshots.
        .onAppear { if UserDefaults.standard.bool(forKey: "autoRefreshWidgetStatus") { refresh() } }
        .navigationTitle("Widget status")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Asks iOS again. Gives up after 10 seconds if iOS never answers, and says so.
    private func refresh() {
        refreshID += 1
        let id = refreshID
        isRefreshing = true
        WidgetPresence.check(into: prompt) { if refreshID == id { isRefreshing = false } }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard isRefreshing, refreshID == id else { return }
            report.recordTimeout(after: 10)
            isRefreshing = false
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).retroText(.body).foregroundStyle(RetroColor.text).multilineTextAlignment(.trailing).textSelection(.enabled)
        } label: {
            Text(title).retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .frame(minHeight: 44)
    }
}
#endif
