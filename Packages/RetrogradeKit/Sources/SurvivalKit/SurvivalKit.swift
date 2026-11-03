import RetroCore

/// A planet's Survival Kit: sections of practical tasks. Content lives here, apart from
/// access rules and completion, so other planets can bring their own kits later.
public struct SurvivalKit: Sendable {
    public let planet: Planet
    public let sections: [KitSection]

    public var tasks: [KitTask] { sections.flatMap(\.tasks) }

    public static func `for`(_ planet: Planet) -> SurvivalKit? {
        planet == .mercury ? .mercury : nil
    }
}

public struct KitSection: Identifiable, Sendable {
    public enum Topic: Sendable { case communication, techBackup, planning, journal }

    public let id: String
    public let number: Int
    /// "COMMUNICATION" — shown as "01 / COMMUNICATION".
    public let category: String
    public let title: String
    public let guidance: String
    public let topic: Topic
    public let tasks: [KitTask]

    public var label: String { "\(number < 10 ? "0" : "")\(number) / \(category)" }
}

public struct KitTask: Identifiable, Hashable, Sendable {
    /// Stable identifier stored with completions; never reuse or rename.
    public let id: String
    public let title: String
}

extension SurvivalKit {
    static let mercury = SurvivalKit(planet: .mercury, sections: [
        KitSection(
            id: "communication", number: 1, category: "COMMUNICATION", title: "TAKE YOUR TIME TO MESSAGE.",
            guidance: "Your pace. No rush. Breathe and clarify if needed.", topic: .communication,
            tasks: [
                KitTask(id: "mercury.communication.breathe-first", title: "Breathe first before answering."),
                KitTask(id: "mercury.communication.ask-for-clarity", title: "Ask for clarity if you are not sure what they meant."),
                KitTask(id: "mercury.communication.clear-one-message", title: "Clear one message."),
                KitTask(id: "mercury.communication.wait-ten-seconds", title: "Wait 10 seconds before hitting send."),
                KitTask(id: "mercury.communication.read-it-out-loud", title: "Read it out loud before sending."),
                KitTask(id: "mercury.communication.save-the-draft", title: "Save the draft and come back later."),
                KitTask(id: "mercury.communication.check-recipient", title: "Check the recipient and attachment."),
                KitTask(id: "mercury.communication.confirm-next-step", title: "Confirm the next step before closing."),
            ]
        ),
        KitSection(
            id: "tech-backup", number: 2, category: "TECH BACKUP", title: "SAVE YOUR FUTURE SELF.",
            guidance: "A backup beats a dramatic recovery arc.", topic: .techBackup,
            tasks: [
                KitTask(id: "mercury.tech.back-up-files", title: "Back up important files to cloud or drive."),
                KitTask(id: "mercury.tech.open-saved-copy", title: "Open a saved copy to check it worked."),
                KitTask(id: "mercury.tech.update-password", title: "Update one password you’ve been putting off."),
                KitTask(id: "mercury.tech.charge-power-bank", title: "Charge your backup power bank."),
                KitTask(id: "mercury.tech.sync-device", title: "Sync one device you rarely sync."),
                KitTask(id: "mercury.tech.write-down-number", title: "Write down one important phone number."),
            ]
        ),
        KitSection(
            id: "flexible-planning", number: 3, category: "FLEXIBLE PLANNING", title: "LEAVE ROOM FOR PLOT TWISTS.",
            guidance: "Keep the plan. Lose the white-knuckle grip.", topic: .planning,
            tasks: [
                KitTask(id: "mercury.planning.confirm-booking", title: "Confirm the time, place and booking."),
                KitTask(id: "mercury.planning.add-buffer", title: "Add a 15-minute buffer and a plan B."),
                KitTask(id: "mercury.planning.pack-charger", title: "Pack one backup charger."),
                KitTask(id: "mercury.planning.paper-backup", title: "Bring a paper map or printed receipt."),
                KitTask(id: "mercury.planning.postpone-one-plan", title: "Choose one nonessential plan to postpone."),
                KitTask(id: "mercury.planning.extra-hour", title: "Leave one extra hour for travel."),
            ]
        ),
        KitSection(
            id: "journal", number: 4, category: "JOURNAL", title: "WRITE IT DOWN.",
            guidance: "A little reflection. No perfect words required.", topic: .journal,
            tasks: [
                KitTask(id: "mercury.journal.name-the-feeling", title: "Name the feeling you’re carrying today."),
                KitTask(id: "mercury.journal.in-your-control", title: "Write what is in your control right now."),
                KitTask(id: "mercury.journal.notice-a-pattern", title: "Notice one pattern you want to change."),
                KitTask(id: "mercury.journal.grateful-for", title: "Write one thing you’re grateful for."),
                KitTask(id: "mercury.journal.small-win", title: "Describe one small win from today."),
                KitTask(id: "mercury.journal.note-to-future-self", title: "Write a kind note to your future self."),
                KitTask(id: "mercury.journal.gentle-intention", title: "Set one gentle intention for tomorrow."),
            ]
        ),
    ])
}
