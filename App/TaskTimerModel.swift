import DesignSystem
import Observation
import SurvivalKit
import SwiftUI

/// Drives a task countdown: Start, Pause, Resume, Restart, and a single signal when time is up
/// (the view plays a gentle haptic on it).
@MainActor
@Observable
final class TaskTimerModel {
    private(set) var state: CountdownState
    /// Changes once each time the countdown completes.
    private(set) var completions = 0
    private var finishTask: Task<Void, Never>?

    init(seconds: Int) {
        state = CountdownState(duration: TimeInterval(seconds))
    }

    func start() {
        state.start(at: .now)
        scheduleFinish()
    }

    func pause() {
        state.pause(at: .now)
        finishTask?.cancel()
    }

    func restart() {
        finishTask?.cancel()
        state.restart()
    }

    private func scheduleFinish() {
        finishTask?.cancel()
        let delay = state.remaining(at: .now)
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            if self.state.finishIfDue(at: .now) { self.completions += 1 }
        }
    }
}

/// "00:10" style text for a number of seconds, rounding up so it never shows 00:00 while running.
func clockText(_ seconds: TimeInterval) -> String {
    let whole = Int(seconds.rounded(.up))
    return String(format: "%02d:%02d", whole / 60, whole % 60)
}

/// Start / Pause + Restart / Resume + Restart / Restart, as in the approved timer design.
struct TimerControls: View {
    let model: TaskTimerModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.state.phase {
            case .ready:
                pill("Start", RetroSymbol.play, filled: true, action: model.start)
            case .running:
                pill("Pause", RetroSymbol.pause, filled: true, action: model.pause)
                pill("Restart", RetroSymbol.restart, filled: false, action: model.restart)
            case .paused:
                pill("Resume", RetroSymbol.play, filled: true, action: model.start)
                pill("Restart", RetroSymbol.restart, filled: false, action: model.restart)
            case .finished:
                pill("Restart", RetroSymbol.restart, filled: false, action: model.restart)
            }
        }
    }

    private func pill(_ title: String, _ icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).retroText(.bodyStrong)
            }
            .foregroundStyle(RetroColor.text)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(filled ? RetroColor.pink : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(filled ? .clear : RetroColor.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
