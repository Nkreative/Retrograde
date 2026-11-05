import DesignSystem
import Persistence
import SwiftUI

/// Settings › Widgets (Figma "M14.5 · Settings › Widgets page"): what the widget shows, its sizes,
/// and how to add or remove it. iOS manages widgets, so there's no on/off switch, and nothing here
/// claims a widget is or isn't on the Home Screen.
struct WidgetsSettingsView: View {
    @Environment(WidgetPrompt.self) private var widgetPrompt
    @State private var showsHowTo = false

    private static let steps = [
        "Touch and hold an empty spot on your Home Screen until the apps jiggle.",
        "Tap Edit, then Add Widget.",
        "Search “Retrograde”, pick Small or Medium, then tap Add Widget.",
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MERCURY ON YOUR HOME SCREEN").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    Text("Mercury’s phase and countdown at a glance, from the same verified sky data as the app. Free for everyone, works offline and updates by itself.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .accessibilityElement(children: .combine)
            }
            Section {
                size("Small", "Phase and countdown")
                size("Medium", "Mercury, phase, countdown and progress")
            } header: {
                header("Sizes")
            }
            .listRowBackground(RetroColor.surface)
            Section {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                        .padding(.vertical, 4)
                }
                Button { showsHowTo = true } label: {
                    Text("Show me how").retroText(.bodyStrong).foregroundStyle(RetroColor.pink)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityHint("Shows the widget and the steps")
            } header: {
                header("Add a widget")
            }
            .listRowBackground(RetroColor.surface)
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Touch and hold the widget, then tap Remove Widget.").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                    Text("Retrograde keeps working without it. iOS manages widgets; Retrograde can’t switch them on or off.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            } header: {
                header("Remove a widget")
            }
            .listRowBackground(RetroColor.surface)
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .environment(\.defaultMinListRowHeight, 44)
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
        // A widget may have just been added: ask iOS again so the Overview's prompts follow.
        .sheet(isPresented: $showsHowTo, onDismiss: { WidgetPresence.check(into: widgetPrompt) }) { WidgetHowToSheet() }
    }

    private func size(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).retroText(.bodyLarge).foregroundStyle(RetroColor.text)
            Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased()).retroText(.mono).foregroundStyle(RetroColor.textMuted)
    }
}
