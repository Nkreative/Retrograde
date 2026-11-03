import DesignSystem
import SwiftUI

/// Temporary tab content until each screen's milestone; uses the real type and spacing.
struct PlaceholderScreen: View {
    let title: String
    let detail: String
    let milestone: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).retroText(.section).foregroundStyle(RetroColor.text)
                    Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                Text(milestone)
                    .retroText(.mono)
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: RetroMetrics.Radius.card)
                            .strokeBorder(RetroColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 16)
        }
    }
}
