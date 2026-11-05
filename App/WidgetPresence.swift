import Foundation
import HomeWidget
import Persistence
import WidgetKit

/// Asks iOS which Retrograde widgets are placed and records the answer for the Overview's prompts.
/// Best effort: iOS has been seen to keep listing a removed widget for a while, so the answer only
/// decides whether to offer the widget, never what Retrograde tells the person. A failed check
/// records nothing.
@MainActor
enum WidgetPresence {
    static func check(into prompt: WidgetPrompt) {
        #if DEBUG
        // `-widgetListed YES|NO` fixes the answer for review screenshots; iOS isn't asked.
        if UserDefaults.standard.object(forKey: "widgetListed") != nil { return }
        #endif
        WidgetCenter.shared.getCurrentConfigurations { result in
            guard case let .success(widgets) = result else { return }
            let count = widgets.filter { $0.kind == WidgetKind.mercuryCycle }.count
            #if DEBUG
            // `-logWidgetPresence YES`: what iOS listed, for checking add and remove on a device.
            if UserDefaults.standard.bool(forKey: "logWidgetPresence") {
                let line = "\(Date.now.ISO8601Format()) listed \(widgets.count), Retrograde \(count): \(widgets.map { "\($0.kind)/\($0.family)" })\n"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("widget-presence.log")
                if let handle = try? FileHandle(forWritingTo: url) { handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close() }
                else { try? line.write(to: url, atomically: true, encoding: .utf8) }
            }
            #endif
            Task { @MainActor in prompt.record(widgetCount: count) }
        }
    }
}
