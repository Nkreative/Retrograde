import DesignSystem
import LinkPresentation
import Observation
import RetroCore
import Sharing
import SwiftUI
import UIKit

// MARK: - Share sheet

/// Opens the iOS share sheet over whatever is on screen. `completion` gets iOS's answer to "did the
/// person finish the action" (sent, posted, copied, saved); a cancel or a failure is `false`.
@MainActor
enum ShareSheet {
    static func present(_ items: [Any], completion: @escaping @MainActor @Sendable (_ completed: Bool) -> Void) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in
                #if DEBUG
                ShareSheetResults.shared.record(completed: completed)
                #endif
                completion(completed)
            }
        }
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY, width: 0, height: 0)
        top.present(controller, animated: true)
        #if DEBUG
        ShareSheetDebug.didPresent(controller)
        #endif
    }

    /// "Share Retrograde": the invitation, plus the App Store link once it's configured.
    static func shareApp(recordingIn activity: SharingActivity) {
        let invitation = AppInvitation(appStoreURL: AppLinks.appStore)
        let items: [Any] = [AppInvitation.message] + (invitation.appStoreURL.map { [$0] } ?? [])
        present(items) { activity.shareSheetFinished(.app, completed: $0) }
    }

    /// A day's card as an image, with the same words as text for places that take text.
    static func shareInsight(_ card: InsightShareCard, image: UIImage, recordingIn activity: SharingActivity) {
        let items: [Any] = [InsightImageItem(image: image, title: "Retrograde · \(card.dateTitle())"),
                            card.text(appStoreURL: AppLinks.appStore)]
        present(items) { activity.shareSheetFinished(.dailyInsight(card.day), completed: $0) }
    }
}

/// The card image, titled in the share sheet's header ("Retrograde · Wednesday, Nov 4, 2026").
private final class InsightImageItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { image }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

// MARK: - Share Retrograde (Figma "Share")

/// The header's share button: "Invite someone who needs this", the synthwave artwork and the
/// invitation line, then the iOS share sheet.
struct ShareInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingActivity.self) private var activity
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The sheet's visible size: the artwork's height follows its width, and spare height goes
    /// around the artwork rather than under the button.
    @State private var viewport: CGSize = .zero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle("Invite someone who needs this", onClose: { dismiss() })
                    .padding(.horizontal, RetroMetrics.screenPadding)
                // Spare height is shared between title → artwork, artwork → button and the bottom
                // (each up to a limit), so the artwork sits balanced and the button lands lower on
                // taller sheets. Short sheets and large text keep the minimums and scroll.
                Spacer(minLength: 20).frame(maxHeight: 36)
                // At accessibility sizes the line sits under the artwork rather than over it.
                if typeSize.isAccessibilitySize {
                    artwork
                    line.padding(.horizontal, RetroMetrics.screenPadding).padding(.top, 16)
                } else {
                    artwork.overlay(alignment: .bottomLeading) {
                        line.padding(.horizontal, 35).padding(.bottom, 40)
                    }
                }
                Spacer(minLength: 22).frame(maxHeight: 56)
                VStack(spacing: 14) {
                    PrimaryButton("Share Retrograde", systemImage: RetroSymbol.share) {
                        ShareSheet.shareApp(recordingIn: activity)
                    }
                    Text("Just the app. Your entries stay yours.")
                        .retroText(.finePrint)
                        .foregroundStyle(RetroColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, RetroMetrics.screenPadding * 2)
                Spacer(minLength: 24)
            }
            .padding(.top, 20)
            .frame(minHeight: viewport.height, alignment: .top)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
        .retroScreenBackground()
        .preferredColorScheme(.dark)
        #if DEBUG
        .onAppear { ShareSheetDebug.autoPresent { ShareSheet.shareApp(recordingIn: activity) } }
        #endif
    }

    /// Figma's 382 × 530 pt artwork at the content width, never taller than 530 pt (wider sheets crop
    /// its sides). A fixed height, so the spacing around it can't stretch or squash it.
    private var artwork: some View {
        let width = viewport.width > 0 ? viewport.width - 2 * RetroMetrics.screenPadding : 342
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: min(530, width * 530 / 382))
            .overlay { Image("ShareHero").resizable().aspectRatio(contentMode: .fill) }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [RetroColor.background.opacity(0), RetroColor.background.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .accessibilityHidden(true)
    }

    private var line: some View {
        Text("The same cosmic vibes, minus the awkward small talk.")
            .retroText(.section)
            .foregroundStyle(RetroColor.text)
            .lineSpacing(5)
    }
}

/// Uppercase Archivo title with a close button, as on Figma's sheets.
private struct SheetTitle: View {
    let title: String
    let onClose: () -> Void

    init(_ title: String, onClose: @escaping () -> Void) {
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title.uppercased())
                .retroText(.section)
                .foregroundStyle(RetroColor.text)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                Image(systemName: RetroSymbol.close)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RetroColor.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(.top, -10)
            .padding(.trailing, -12)
        }
    }
}

// MARK: - Share a day

/// The day's insight as a 4:5 portrait image (1080 × 1350 px): date, level, summary and the good
/// habit, in the Calendar's words, on the app's night sky. Fixed text sizes, so it reads the same
/// wherever it's posted.
struct InsightShareCardView: View {
    let card: InsightShareCard

    static let size = CGSize(width: 384, height: 480)
    static let renderScale: CGFloat = 1080 / 384

    private static let stepColors = [RetroColor.calm, RetroColor.mauve, RetroColor.pinkSoft, RetroColor.pink]

    var body: some View {
        content
            .padding(24)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background { CardSky() }
            .dynamicTypeSize(.large)
            .environment(\.colorScheme, .dark)
    }

    /// The layout without the fixed frame, so tests can check its natural height.
    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BrandMark(size: 24)
                Text("RETROGRADE").retroText(.cardTitle).foregroundStyle(RetroColor.text)
            }
            Spacer(minLength: 18)
            Text(card.dateTitle().uppercased())
                .retroText(.monoLabel)
                .foregroundStyle(RetroColor.pink)
            HStack(alignment: .firstTextBaseline) {
                Text(card.levelName).retroText(.display).foregroundStyle(RetroColor.text)
                Spacer(minLength: 8)
                Text(card.levelPosition).retroText(.monoLarge).foregroundStyle(RetroColor.pink)
            }
            .padding(.top, 6)
            HStack(spacing: 5) {
                ForEach(IntensityLevel.allCases, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= card.level ? Self.stepColors[step.rawValue - 1] : RetroColor.dim)
                        .frame(height: 8)
                }
            }
            .padding(.top, 10)
            Text(card.summary)
                .retroText(.bodyLarge)
                .foregroundStyle(RetroColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
            Spacer(minLength: 18)
            VStack(alignment: .leading, spacing: 6) {
                Text("Good habit for this day").retroText(.cardTitle).foregroundStyle(RetroColor.text)
                Text(card.habit).retroText(.prompt).foregroundStyle(RetroColor.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RetroColor.wine, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroColor.line, lineWidth: 1))
            Text("Intensity is an astrology-inspired reflection score built from verified sky events, not a prediction.")
                .retroText(.finePrint)
                .foregroundStyle(RetroColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = Self.renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// The card's background: the app's night sky with a soft pink and mauve glow.
private struct CardSky: View {
    var body: some View {
        ZStack {
            RetroColor.background
            RadialGradient(colors: [RetroColor.pink.opacity(0.32), .clear], center: .topTrailing, startRadius: 0, endRadius: 300)
            RadialGradient(colors: [RetroColor.mauve.opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 320)
        }
    }
}

/// The preview before sharing a day: the card as it will be sent, then the share sheet.
struct InsightSharePreview: View {
    let card: InsightShareCard
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingActivity.self) private var activity
    @State private var image: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetTitle("Share this day", onClose: { dismiss() })
                Group {
                    if let image {
                        Image(uiImage: image).resizable()
                    } else {
                        RetroColor.surface
                    }
                }
                .aspectRatio(InsightShareCardView.size.width / InsightShareCardView.size.height, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card).strokeBorder(RetroColor.line, lineWidth: 1))
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("Share card. \(card.text())")
                VStack(spacing: 14) {
                    PrimaryButton("Share image", systemImage: RetroSymbol.share, action: share)
                        .disabled(image == nil)
                    Text("Sends this card as an image, with the same words as text where the app allows.")
                        .retroText(.finePrint)
                        .foregroundStyle(RetroColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, RetroMetrics.screenPadding)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .retroScreenBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            image = InsightShareCardView(card: card).render()
            #if DEBUG
            ShareSheetDebug.export(image)
            ShareSheetDebug.autoPresent(share)
            #endif
        }
    }

    private func share() {
        guard let image else { return }
        ShareSheet.shareInsight(card, image: image, recordingIn: activity)
    }
}

#if DEBUG
/// Debug builds only: iOS's answer for each share sheet closed this launch (completed or not), for
/// Settings › Developer › Sharing history. In memory; nothing about the destination is kept.
@MainActor
@Observable
final class ShareSheetResults {
    static let shared = ShareSheetResults()
    private(set) var results: [(at: Date, completed: Bool)] = []

    func record(completed: Bool) { results.append((.now, completed)) }
}

/// Review aids: `-presentShareSheet YES` opens the share sheet as soon as a share screen appears;
/// `-cancelShareSheet YES` then closes it after 6 seconds, as a cancel (events go to `tmp/share-sheet.log`). `-exportShareCard YES`
/// writes the rendered card to `tmp/share-card.png` in the app's container.
@MainActor
enum ShareSheetDebug {
    static func autoPresent(_ share: @escaping @MainActor () -> Void) {
        guard UserDefaults.standard.bool(forKey: "presentShareSheet") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            share()
        }
    }

    static func export(_ image: UIImage?) {
        guard UserDefaults.standard.bool(forKey: "exportShareCard"), let data = image?.pngData() else { return }
        try? data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("share-card.png"))
    }

    static func didPresent(_ controller: UIActivityViewController) {
        log("presented")
        let completion = controller.completionWithItemsHandler
        controller.completionWithItemsHandler = { type, completed, items, error in
            Task { @MainActor in log("finished completed=\(completed)") }
            completion?(type, completed, items, error)
        }
        guard UserDefaults.standard.bool(forKey: "cancelShareSheet") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            controller.dismiss(animated: true)
            log("dismissed by debug cancel")
        }
    }

    /// Appends to `tmp/share-sheet.log` in the app's container, for checking from the Mac.
    private static func log(_ event: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("share-sheet.log")
        let line = Data("\(event)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
#endif
