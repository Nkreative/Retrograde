#if DEBUG
import DesignSystem
import Persistence
import SwiftUI

/// Settings › Developer › Widget status (debug builds only): what iOS last reported about
/// Retrograde's widgets and what the app saved from it. Read-only, apart from asking iOS again.
struct WidgetStatusView: View {
    @Environment(WidgetPrompt.self) private var prompt
    private let report = WidgetPresenceReport.shared

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
                    row("All widgets iOS listed", "\(total)")
                case let .failed(message):
                    row("Result", "Failed")
                    row("Error", message)
                }
                row("Checked at", report.checkedAt?.formatted(date: .abbreviated, time: .standard) ?? "—")
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
                Button("Refresh widget status") { WidgetPresence.check(into: prompt) }
                    .frame(minHeight: 44)
            } footer: {
                Text("Asks iOS again, exactly as the app does on launch. The saved state follows the answer, as it would anyway.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .navigationTitle("Widget status")
        .navigationBarTitleDisplayMode(.inline)
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
