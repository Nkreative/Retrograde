import Foundation
import Observation
import HomeWidget
import Persistence
import WidgetKit

/// Asks iOS which Retrograde widgets are placed and records the answer for the Overview's prompts.
/// Best effort: iOS has been seen to keep listing a removed widget for a while, so the answer only
/// decides whether to offer the widget, never what Retrograde tells the person. A failed check
/// records nothing.
@MainActor
enum WidgetPresence {
    /// `finished` (debug diagnostic only) runs on the main actor once iOS has answered.
    static func check(into prompt: WidgetPrompt, finished: (@MainActor () -> Void)? = nil) {
        #if DEBUG
        // `-widgetListed YES|NO` fixes the answer for review screenshots; iOS isn't asked.
        if UserDefaults.standard.object(forKey: "widgetListed") != nil { finished?(); return }
        #endif
        WidgetCenter.shared.getCurrentConfigurations { result in
            #if DEBUG
            let reading: WidgetPresenceReport.Reading = switch result {
            case let .success(widgets): .listed(widgets.filter { $0.kind == WidgetKind.mercuryCycle }.map { "\($0.family)" }, total: widgets.count)
            case let .failure(error): .failed(error.localizedDescription)
            }
            Task { @MainActor in
                WidgetPresenceReport.shared.record(reading)
                finished?()
            }
            #endif
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

#if DEBUG
/// Debug builds only: the last answer iOS gave, for Settings › Developer › Widget status. Read-only;
/// it never changes what the Overview shows.
@MainActor
@Observable
final class WidgetPresenceReport {
    enum Reading: Equatable {
        /// Retrograde's widgets (their sizes) and how many widgets iOS listed in all.
        case listed([String], total: Int)
        case failed(String)
    }

    static let shared = WidgetPresenceReport()
    private(set) var last: Reading?
    private(set) var checkedAt: Date?
    /// Answers received this launch, so a repeated identical answer is still visibly new.
    private(set) var checkCount = 0

    func record(_ reading: Reading) {
        last = reading
        checkedAt = .now
        checkCount += 1
    }

    /// iOS didn't call back in time; the last answer (and the saved state) stay as they were.
    func recordTimeout(after seconds: Int) {
        last = .failed("No answer from iOS after \(seconds) seconds.")
        checkedAt = .now
        checkCount += 1
    }
}
#endif
