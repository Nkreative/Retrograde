import Foundation

/// A pausable countdown, driven by timestamps so it stays correct if the screen redraws late
/// or the app is briefly backgrounded.
public struct CountdownState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready
        case running(startedAt: Date, elapsedBefore: TimeInterval)
        case paused(elapsed: TimeInterval)
        case finished
    }

    public let duration: TimeInterval
    public private(set) var phase: Phase = .ready

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func elapsed(at now: Date) -> TimeInterval {
        switch phase {
        case .ready: 0
        case let .running(startedAt, before): min(before + now.timeIntervalSince(startedAt), duration)
        case let .paused(elapsed): elapsed
        case .finished: duration
        }
    }

    public func remaining(at now: Date) -> TimeInterval { duration - elapsed(at: now) }

    public func progress(at now: Date) -> Double { duration == 0 ? 1 : elapsed(at: now) / duration }

    public var isRunning: Bool {
        if case .running = phase { true } else { false }
    }

    /// Start from ready, or resume from paused.
    public mutating func start(at now: Date) {
        switch phase {
        case .ready: phase = .running(startedAt: now, elapsedBefore: 0)
        case let .paused(elapsed): phase = .running(startedAt: now, elapsedBefore: elapsed)
        case .running, .finished: break
        }
    }

    public mutating func pause(at now: Date) {
        guard isRunning else { return }
        phase = .paused(elapsed: elapsed(at: now))
    }

    /// Back to the full time, not running.
    public mutating func restart() {
        phase = .ready
    }

    /// Marks the countdown finished once its time is up. Returns true the moment it finishes.
    public mutating func finishIfDue(at now: Date) -> Bool {
        guard isRunning, remaining(at: now) <= 0 else { return false }
        phase = .finished
        return true
    }
}

/// Where paced breathing is at a given moment.
public struct BreathPosition: Equatable, Sendable {
    public enum Direction: Sendable { case inhale, exhale }

    public let direction: Direction
    /// Whole seconds left in this breath, counting down from the breath's length.
    public let secondsLeft: Int
    /// 0...1 through this breath.
    public let fraction: Double

    public init(elapsed: TimeInterval, inhale: Int, exhale: Int) {
        let cycle = Double(inhale + exhale)
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        if t < Double(inhale) {
            direction = .inhale
            secondsLeft = Int((Double(inhale) - t).rounded(.up))
            fraction = t / Double(inhale)
        } else {
            direction = .exhale
            secondsLeft = Int((cycle - t).rounded(.up))
            fraction = (t - Double(inhale)) / Double(exhale)
        }
    }
}
