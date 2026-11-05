import SwiftUI

/// Review sheet of the design system, one page per screenful.
/// The app shows it in debug builds when launched with `-catalog <page>`.
public struct DesignSystemCatalog: View {
    public static let pageCount = 3
    let page: Int

    public init(page: Int) {
        self.page = min(max(page, 1), Self.pageCount)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DESIGN SYSTEM · \(page) / \(Self.pageCount)").retroText(.mono).foregroundStyle(RetroColor.pink)
                    Text(["COLOURS & TYPE", "COMPONENTS", "ICONS"][page - 1]).retroText(.section).foregroundStyle(RetroColor.text)
                }
                switch page {
                case 1: ColoursAndType()
                case 2: ComponentsPage()
                default: IconsPage()
                }
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.vertical, 12)
        }
        .retroScreenBackground()
    }
}

private struct ColoursAndType: View {
    let swatches: [(String, Color, String)] = [
        ("background", RetroColor.background, "130D25"), ("surface", RetroColor.surface, "1D1331"),
        ("surfaceRaised", RetroColor.surfaceRaised, "201431"), ("chip", RetroColor.chip, "2B1B43"),
        ("cell", RetroColor.cell, "2B1E3C"), ("line", RetroColor.line, "49305F"),
        ("text", RetroColor.text, "F5F0FF"), ("textMuted", RetroColor.textMuted, "B8A9CD"),
        ("pink", RetroColor.pink, "FF2D87"), ("pinkSoft", RetroColor.pinkSoft, "EC82B1"),
        ("mauve", RetroColor.mauve, "C997C6"), ("yellow", RetroColor.yellow, "FFD23D"), ("green", RetroColor.green, "52E3A4"),
        ("wine", RetroColor.wine, "461736"), ("dim", RetroColor.dim, "49334F"), ("calm", RetroColor.calm, "A89CBE"),
    ]
    let samples: [(RetroTextStyle, String, String)] = [
        (.display, "10", "Archivo Black 32"), (.hero, "A LITTLE CHAOS.", "Archivo Black 30"),
        (.title, "RETROGRADE", "Archivo Black 20"), (.section, "SO, WHAT DOES IT MEAN?", "Archivo Black 19"),
        (.cardTitle, "TAKE YOUR TIME TO MESSAGE.", "Archivo Black 16"), (.button, "Go to my survival kit", "Inter Bold 14"),
        (.bodyStrong, "Texts get lost in translation.", "Inter SemiBold 13"),
        (.bodyLarge, "The message can wait ten seconds.", "Inter Regular 13"),
        (.body, "Reread before you hit send. Yes, even that one.", "Inter Regular 12"),
        (.monoBody, "days to exhale", "Space Mono 13"), (.monoLabel, "RETROGRADE", "Space Mono Bold 12"),
        (.monoLarge, "days to exhale", "Space Mono 11"), (.mono, "01 / COMMUNICATION", "Space Mono 10"),
        (.monoBold, "ADD TO HOME SCREEN", "Space Mono Bold 10"), (.monoSmall, "YOUR COSMIC REALITY CHECK", "Space Mono 9"),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(swatches, id: \.0) { name, color, hex in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6).fill(color).frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(RetroColor.line, lineWidth: 1))
                    Text(name).font(.custom("SpaceMono-Regular", size: 7)).foregroundStyle(RetroColor.text).lineLimit(1).minimumScaleFactor(0.7)
                    Text(hex).font(.custom("SpaceMono-Regular", size: 7)).foregroundStyle(RetroColor.textMuted)
                }
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(samples, id: \.2) { style, text, spec in
                VStack(alignment: .leading, spacing: 1) {
                    Text(text).retroText(style).foregroundStyle(style == .display ? RetroColor.yellow : RetroColor.text).lineLimit(1)
                    Text(spec).font(.custom("SpaceMono-Regular", size: 8)).foregroundStyle(RetroColor.textMuted)
                }
            }
        }
    }
}

private struct ComponentsPage: View {
    var body: some View {
        AppHeader(onShare: {}, onNotifications: {}, onSettings: {})
            .padding(.horizontal, -RetroMetrics.screenPadding)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("10").retroText(.display).foregroundStyle(RetroColor.yellow)
                    Text("days to exhale").retroText(.monoLarge).foregroundStyle(RetroColor.text)
                }
                Spacer()
                Text("DAY 12 / 22").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            LabeledProgress(progress: 0.55, start: "RETROGRADE", current: "YOU ARE HERE", end: "DIRECT")
            HStack {
                Spacer()
                PillButton("ADD TO HOME SCREEN", systemImage: RetroSymbol.add) {}
            }
        }

        VStack(alignment: .leading, spacing: 13) {
            tip(RetroSymbol.communication, "Texts get lost in translation.", "Reread before you hit send. Yes, even that one.")
            tip(RetroSymbol.techBackup, "Tech picks a dramatic moment.", "Save your work. Back up the important stuff.")
        }

        PrimaryButton("Go to my survival kit", systemImage: RetroSymbol.firstAid, layout: .leading, showsArrow: true) {}
        PrimaryButton("Mark as done", systemImage: RetroSymbol.checkCircle) {}
        HStack(spacing: 10) {
            SecondaryButton("Copy prompt", systemImage: RetroSymbol.copy) {}
            SecondaryButton("Open in…", systemImage: RetroSymbol.share) {}
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconChip(systemImage: RetroSymbol.communication)
                VStack(alignment: .leading, spacing: 3) {
                    Text("01 / COMMUNICATION").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    Text("TAKE YOUR TIME TO MESSAGE.").retroText(.cardTitle).foregroundStyle(RetroColor.text)
                }
            }
            row(.done, "Breathe first before answering.")
            row(.open, "Ask for clarity if you are not sure what they meant.")
            row(.locked, "Clear one message.")
            HStack { Spacer(); Badge("BEST VALUE") }
        }
        .retroCard()
    }

    private func tip(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            IconChip(systemImage: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
    }

    private func row(_ state: TaskCheckbox.State, _ text: String) -> some View {
        HStack(spacing: 10) {
            TaskCheckbox(state)
            Text(text).retroText(.body)
                .foregroundStyle(state == .done ? RetroColor.textMuted : RetroColor.text)
                .opacity(state == .locked ? 0.4 : 1)
        }
    }
}

private struct IconsPage: View {
    let symbols: [(String, String)] = [
        ("share", RetroSymbol.share), ("notifications", RetroSymbol.notifications), ("settings", RetroSymbol.settings),
        ("close", RetroSymbol.close), ("back", RetroSymbol.back), ("forward", RetroSymbol.forward),
        ("chevronRight", RetroSymbol.chevronRight), ("add", RetroSymbol.add), ("check", RetroSymbol.check),
        ("checkCircle", RetroSymbol.checkCircle), ("lock", RetroSymbol.lock), ("unlock", RetroSymbol.unlock),
        ("star", RetroSymbol.star), ("copy", RetroSymbol.copy), ("externalLink", RetroSymbol.externalLink),
        ("play", RetroSymbol.play), ("pause", RetroSymbol.pause), ("restart", RetroSymbol.restart),
        ("communication", RetroSymbol.communication), ("techBackup", RetroSymbol.techBackup),
        ("planning", RetroSymbol.planning), ("journal", RetroSymbol.journal), ("firstAid", RetroSymbol.firstAid),
        ("moon", RetroSymbol.moon), ("heart", RetroSymbol.heart), ("notificationsOff", RetroSymbol.notificationsOff),
    ]

    var body: some View {
        Text("CUSTOM — FROM FIGMA VECTORS").retroText(.mono).foregroundStyle(RetroColor.textMuted)
        HStack(alignment: .bottom, spacing: 28) {
            BrandMark()
            BrandMark(size: 56)
            ForEach(RetroGlyph.allCases, id: \.self) { glyph in
                VStack(spacing: 8) {
                    RetroGlyphView(glyph).frame(height: 21).foregroundStyle(RetroColor.pink)
                    RetroGlyphView(glyph).frame(height: 21).foregroundStyle(RetroColor.textMuted)
                }
            }
        }
        Text("SF SYMBOLS — STANDARD INTERFACE").retroText(.mono).foregroundStyle(RetroColor.textMuted)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 14) {
            ForEach(symbols, id: \.0) { name, symbol in
                VStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(RetroColor.text).frame(height: 22)
                    Text(name).font(.custom("SpaceMono-Regular", size: 8)).foregroundStyle(RetroColor.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }
}

#Preview("Colours & type") { DesignSystemCatalog(page: 1).onAppear(perform: RetroFonts.register) }
#Preview("Components") { DesignSystemCatalog(page: 2).onAppear(perform: RetroFonts.register) }
#Preview("Icons") { DesignSystemCatalog(page: 3).onAppear(perform: RetroFonts.register) }
