/// What a task screen shows and how the person interacts with it.
public struct TaskGuide: Equatable, Sendable {
    /// Screen title, e.g. "WAIT 10 SECONDS BEFORE HITTING SEND".
    public let title: String
    /// The short line under the title.
    public let instruction: String
    public let practice: Practice
    /// Closing note under the practice (or the breathing repetition guidance).
    public let reminder: String

    public enum Practice: Equatable, Sendable {
        /// Numbered guidance ("01", "02", "03").
        case steps(label: String, steps: [String])
        /// Items the person can tick off while they do them (not saved; "Mark as done" is what counts).
        case checklist(label: String, items: [String])
        /// A short countdown with steps underneath.
        case pauseTimer(label: String, seconds: Int, caption: String, steps: [String])
        /// Paced breathing: in for `inhale`, out for `exhale`, repeated `rounds` times.
        case breathing(inhale: Int, exhale: Int, rounds: Int)
        /// A ready-made message to borrow, with a label above it.
        case message(label: String, text: String)
        /// A ready-made message in a highlighted box (no label).
        case template(text: String)
        /// A fill-in-the-blank journal prompt with an example. Nothing written is stored in the app.
        case reflection(label: String, prompt: String, example: String)
    }
}

extension TaskGuide.Practice {
    /// The countdown length, for practices that have one.
    public var timerSeconds: Int? {
        switch self {
        case let .pauseTimer(_, seconds, _, _): seconds
        case let .breathing(inhale, exhale, rounds): (inhale + exhale) * rounds
        default: nil
        }
    }
}
