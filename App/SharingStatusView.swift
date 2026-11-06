#if DEBUG
import DesignSystem
import Sharing
import SwiftUI

/// Settings › Developer › Sharing history (debug builds only): the finished shares saved on this
/// iPhone, which the Overview counts, and iOS's answer for each share sheet closed this launch.
/// Read-only.
struct SharingStatusView: View {
    @Environment(SharingActivity.self) private var sharing
    @State private var results = ShareSheetResults.shared

    var body: some View {
        List {
            Section {
                row("Saved finished shares", "\(sharing.records.count)")
                row("Overview shows", SharingSummary(finishedShares: sharing.records.count).spoken)
                ForEach(Array(sharing.recent(10).enumerated()), id: \.offset) { _, record in
                    row(record.item.insightDay.map { "Day card · \($0.description)" } ?? "App invitation",
                        record.sharedAt.formatted(date: .abbreviated, time: .standard))
                }
            } header: {
                Text("SAVED ON THIS IPHONE").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
            Section {
                if results.results.isEmpty {
                    row("Share sheets closed", "None yet this launch")
                }
                ForEach(Array(results.results.enumerated()), id: \.offset) { _, result in
                    row(result.at.formatted(date: .omitted, time: .standard), result.completed ? "Completed (counted)" : "Not completed (not counted)")
                }
            } header: {
                Text("THIS LAUNCH: WHAT iOS REPORTED").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            } footer: {
                Text("A share counts only when iOS reports it completed: sent, posted, copied or saved. Cancelling, or closing the share sheet, doesn’t count.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .navigationTitle("Sharing history")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).retroText(.body).foregroundStyle(RetroColor.text).multilineTextAlignment(.trailing)
        } label: {
            Text(title).retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .frame(minHeight: 44)
    }
}
#endif
