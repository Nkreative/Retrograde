import DesignSystem
import SurvivalKit
import SwiftUI

/// The practice card for a task, chosen by its type. Each type is one reusable view;
/// the words come from the task's guide.
struct PracticeCard: View {
    let guide: TaskGuide
    let onCopy: (String) -> Void

    var body: some View {
        switch guide.practice {
        case let .steps(label, steps):
            card(label, reminder: guide.reminder) { NumberedSteps(steps: steps) }
        case let .checklist(label, items):
            card(label, reminder: guide.reminder) { TickList(items: items) }
        case let .pauseTimer(label, seconds, caption, steps):
            card(label, reminder: guide.reminder) {
                PauseTimer(seconds: seconds, caption: caption)
                NumberedSteps(steps: steps)
            }
        case let .breathing(inhale, exhale, rounds):
            card(nil, reminder: guide.reminder) { BreathingGuide(inhale: inhale, exhale: exhale, rounds: rounds) }
        case let .message(label, text):
            card(label, reminder: guide.reminder) {
                Text("“\(text)”").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                CopyLink(title: "Copy message") { onCopy(text) }
            }
        case let .template(text):
            VStack(alignment: .leading, spacing: 9) {
                Text("“\(text)”").retroText(.body).foregroundStyle(RetroColor.text)
                CopyLink(title: "Copy message") { onCopy(text) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RetroColor.chip, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.chip))
            .retroCard()
        case let .reflection(label, prompt, example):
            card(label, reminder: guide.reminder) {
                Text(prompt).retroText(.prompt).foregroundStyle(RetroColor.text)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOR EXAMPLE").retroText(.monoTiny).foregroundStyle(RetroColor.textMuted)
                    Text("“\(example)”").retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
            }
        }
    }

    /// Figma's practice card: pink label, content, divider, muted reminder.
    private func card<Content: View>(_ label: String?, reminder: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let label {
                Text(label).retroText(.mono).foregroundStyle(RetroColor.pink)
            }
            content()
            if !reminder.isEmpty {
                RetroColor.line.frame(height: 1)
                Text(reminder).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
        .retroCard(padding: 18)
    }
}

// MARK: - Practice types

private struct NumberedSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1)).retroText(.monoLarge).foregroundStyle(RetroColor.pink)
                    Text(step).retroText(.body).foregroundStyle(RetroColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Items to tick while doing them. Ticks are just for the moment; "Mark as done" records the task.
private struct TickList: View {
    let items: [String]
    @State private var ticked: Set<Int> = []
    @ScaledMetric(relativeTo: .footnote) private var firstLineCentre: CGFloat = 4.4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isTicked = ticked.contains(index)
                Button {
                    if isTicked { ticked.remove(index) } else { ticked.insert(index) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        TaskCheckbox(isTicked ? .done : .open)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + firstLineCentre }
                        Text(item).retroText(.body)
                            .foregroundStyle(isTicked ? RetroColor.textMuted : RetroColor.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .padding(.vertical, -7)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isTicked ? [.isButton, .isSelected] : .isButton)
            }
        }
        .sensoryFeedback(.selection, trigger: ticked)
    }
}

/// "00:10" countdown with Start / Pause / Restart (Wait 10 seconds).
private struct PauseTimer: View {
    let caption: String
    @State private var model: TaskTimerModel

    init(seconds: Int, caption: String) {
        self.caption = caption
        _model = State(initialValue: TaskTimerModel(seconds: seconds))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let state = model.state
            VStack(spacing: 6) {
                Text(clockText(state.remaining(at: context.date)))
                    .retroText(.timer)
                    .monospacedDigit()
                    .foregroundStyle(RetroColor.text)
                    .accessibilityLabel("\(Int(state.remaining(at: context.date).rounded(.up))) seconds left")
                Text(state.phase == .finished ? "PAUSE COMPLETE" : caption)
                    .retroText(.monoTiny)
                    .foregroundStyle(RetroColor.textMuted)
                if state.phase != .ready {
                    CycleProgressBar(progress: state.progress(at: context.date), marker: RetroColor.pink, markerSize: 7)
                        .frame(maxWidth: 200)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                }
                TimerControls(model: model).padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.completions)
        .autostartForReview(model)
    }
}

/// One-minute paced breathing: ring countdown, in/out counts, Start / Pause / Restart.
/// With Reduce Motion the breathing circle stays still; the highlighted count still guides.
private struct BreathingGuide: View {
    let inhale: Int
    let exhale: Int
    let rounds: Int
    @State private var model: TaskTimerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Figma's 124 pt ring, growing with the text inside it.
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 124

    init(inhale: Int, exhale: Int, rounds: Int) {
        self.inhale = inhale
        self.exhale = exhale
        self.rounds = rounds
        _model = State(initialValue: TaskTimerModel(seconds: (inhale + exhale) * rounds))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let state = model.state
            let elapsed = state.elapsed(at: context.date)
            let breath = BreathPosition(elapsed: elapsed, inhale: inhale, exhale: exhale)
            let active = state.isRunning || { if case .paused = state.phase { true } else { false } }()
            VStack(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { ring(state, elapsed: elapsed, breath: breath, active: active, now: context.date); counts(breath, active: active) }
                    VStack(spacing: 16) { ring(state, elapsed: elapsed, breath: breath, active: active, now: context.date); counts(breath, active: active) }
                }
                TimerControls(model: model)
            }
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.completions)
        .autostartForReview(model)
    }

    private func ring(_ state: CountdownState, elapsed: TimeInterval, breath: BreathPosition, active: Bool, now: Date) -> some View {
        // The soft disc grows on the in-breath and shrinks on the out-breath.
        let breathScale: Double = {
            guard active, !reduceMotion else { return 0.78 }
            let eased = (1 - cos(.pi * breath.fraction)) / 2
            return breath.direction == .inhale ? 0.6 + 0.35 * eased : 0.95 - 0.35 * eased
        }()
        let caption: String = switch state.phase {
        case .ready: "SUGGESTED TIME"
        case .finished: "NICELY DONE"
        default: "ROUND \(min(Int(elapsed) / (inhale + exhale) + 1, rounds)) OF \(rounds)"
        }
        return ZStack {
            Circle().strokeBorder(RetroColor.line, lineWidth: 1)
            Circle()
                .fill(RetroColor.pink.opacity(0.14))
                .padding(14)
                .scaleEffect(breathScale)
            Circle()
                .trim(from: 0, to: state.phase == .ready ? 1 : 1 - state.progress(at: now))
                .stroke(RetroColor.pink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(7)
            VStack(spacing: 4) {
                Text(clockText(state.remaining(at: now))).retroText(.timerCompact).monospacedDigit().foregroundStyle(RetroColor.text)
                Text(caption).retroText(.monoTiny).foregroundStyle(RetroColor.textMuted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, ringSize * 0.14)
            .accessibilityElement(children: .combine)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func counts(_ breath: BreathPosition, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            count("BREATHE IN", inhale, highlighted: !active || breath.direction == .inhale, live: active && breath.direction == .inhale ? breath.secondsLeft : nil)
            count("BREATHE OUT", exhale, highlighted: !active || breath.direction == .exhale, live: active && breath.direction == .exhale ? breath.secondsLeft : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func count(_ title: String, _ seconds: Int, highlighted: Bool, live: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(live.map { "\(title) · \($0)" } ?? title).retroText(.mono).foregroundStyle(RetroColor.pink)
            Text("\(seconds) seconds").retroText(.breathCount).foregroundStyle(RetroColor.text)
        }
        .opacity(highlighted ? 1 : 0.4)
        .accessibilityElement(children: .combine)
    }
}

/// Small pink "Copy message" link.
private struct CopyLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: RetroSymbol.copy).font(.system(size: 11, weight: .semibold))
                Text(title).font(RetroTextStyle.bodyStrong.font)
            }
            .foregroundStyle(RetroColor.pink)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// Debug-only: `-autostartTimer YES` starts timers on open, for review screenshots.
    func autostartForReview(_ model: TaskTimerModel) -> some View {
        #if DEBUG
        onAppear { if UserDefaults.standard.bool(forKey: "autostartTimer"), model.state.phase == .ready { model.start() } }
        #else
        self
        #endif
    }
}
