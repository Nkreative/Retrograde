import DesignSystem
import HomeWidget
import RetroCore
import SwiftUI
import WidgetKit

/// "Keep the countdown close." (Figma "Add to Home Screen — how-to sheet"): the widget as it looks
/// today and the three iOS steps to add it. Opened from the Overview and Settings. iOS doesn't tell
/// apps whether their widget is installed, so this never claims to know.
struct WidgetHowToSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// The content's height, so the sheet is only as tall as it needs to be.
    @State private var height: CGFloat = 540

    private static let steps = [
        "Touch and hold an empty spot on your Home Screen until the apps jiggle.",
        "Tap Edit in the top-left corner, then Add Widget.",
        "Search “Retrograde”, pick Small or Medium, then tap Add Widget.",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 14) {
                    Text("HOME SCREEN WIDGET").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    Text("KEEP THE COUNTDOWN CLOSE.")
                        .retroText(.section)
                        .foregroundStyle(RetroColor.text)
                        .accessibilityAddTraits(.isHeader)
                }
                .multilineTextAlignment(.center)
                preview
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1)).retroText(.mono).foregroundStyle(RetroColor.pink)
                            Text(step).retroText(.body).foregroundStyle(RetroColor.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                PrimaryButton("Got it") { dismiss() }
                    .padding(.top, 2)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 28)
            .padding(.bottom, 16)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(RetroColor.surface.ignoresSafeArea())
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(RetroMetrics.Radius.sheet)
        .preferredColorScheme(.dark)
    }

    /// The real medium widget, at iOS's medium size, with today's countdown.
    private var preview: some View {
        let content = SkyData.calculator?.status(of: .mercury, at: .now).flatMap(WidgetContent.init(status:))
        return MercuryWidgetView(content: content, family: .systemMedium)
            .padding(16)
            .frame(maxWidth: 338)
            .frame(height: 158)
            .background(WidgetBackground())
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(RetroColor.line, lineWidth: 1))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Widget preview. \(content?.accessibilityLabel ?? "")")
    }
}
