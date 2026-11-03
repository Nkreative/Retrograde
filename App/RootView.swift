import AstroData
import RetroCore
import SwiftUI

/// Foundation-milestone placeholder: proves the bundled sky data loads and the
/// cycle maths runs on device. Replaced by the tab shell and Overview in M3–M4.
struct RootView: View {
    private let calculator = (try? BundledEphemeris.load()).map { CycleCalculator(ephemeris: $0) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 12) {
                Text("RETROGRADE")
                    .font(.largeTitle.weight(.black))
                Text(summary(at: context.date))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0x13 / 255, green: 0x0D / 255, blue: 0x25 / 255))
        }
    }

    private func summary(at date: Date) -> String {
        guard let status = calculator?.status(of: .mercury, at: date) else {
            return "Sky data unavailable for this date."
        }
        switch status.phase {
        case .retrograde:
            return "Mercury retrograde\nDay \(status.day) of \(status.totalDays) · \(status.daysRemaining) days to go"
        case .direct:
            return "Mercury direct\n\(status.daysRemaining) days until the next retrograde"
        }
    }
}

#Preview {
    RootView()
}
