import SwiftUI

public struct RetroTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let glyph: RetroGlyph

    public init(id: ID, title: String, glyph: RetroGlyph) {
        self.id = id
        self.title = title
        self.glyph = glyph
    }
}

/// The bottom navigation from Figma: hairline top border, three 110 pt items spread across
/// the screen, 21 pt line icons over Space Mono labels, pink when selected.
public struct RetroTabBar<ID: Hashable>: View {
    let items: [RetroTabItem<ID>]
    @Binding var selection: ID

    public init(items: [RetroTabItem<ID>], selection: Binding<ID>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Spacer(minLength: 0) }
                tab(item)
            }
        }
        // Like system tab bars, labels stop growing at the largest text sizes; people using them
        // can press and hold a tab to see its label enlarged.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(.horizontal, RetroMetrics.screenPadding)
        .padding(.top, 18)
        // Figma leaves ~43 pt between the labels and the home indicator; the safe area supplies ~21 of it.
        .padding(.bottom, 22)
        .background {
            RetroColor.background
                .overlay(alignment: .top) { RetroColor.line.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ item: RetroTabItem<ID>) -> some View {
        let selected = item.id == selection
        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 5) {
                RetroGlyphView(item.glyph).frame(height: 21)
                Text(item.title).retroText(.mono).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? RetroColor.pink : RetroColor.textMuted)
            .frame(width: 110)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer {
            RetroGlyphView(item.glyph)
            Text(item.title)
        }
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
