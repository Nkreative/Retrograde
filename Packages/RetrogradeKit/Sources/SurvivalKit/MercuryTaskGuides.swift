// Task screen content for the Mercury kit, transcribed from the Figma task screens.

extension SurvivalKit {
    /// Guide for a task, or nil if the task has none.
    public func guide(for task: KitTask) -> TaskGuide? {
        planet == .mercury ? Self.mercuryGuides[task.id] : nil
    }

    static let mercuryGuides: [String: TaskGuide] = [
        // MARK: 01 Communication
        "mercury.communication.breathe-first": TaskGuide(
            title: "BREATHE FIRST",
            instruction: "Feet on the floor. Let your shoulders drop. Unclench your jaw. Yes, that one.",
            practice: .breathing(inhale: 4, exhale: 6, rounds: 6),
            reminder: "Repeat 6 times. Keep it gentle; breathe normally if counting feels uncomfortable."
        ),
        "mercury.communication.ask-for-clarity": TaskGuide(
            title: "ASK FOR CLARITY",
            instruction: "Reread for tone. Unsure what they meant? Ask, don’t assume. Borrow this:",
            practice: .template(text: "Quick check: did you mean today or tomorrow? Just want us on the same page."),
            reminder: ""
        ),
        "mercury.communication.clear-one-message": TaskGuide(
            title: "CLEAR ONE MESSAGE",
            instruction: "Pick one message waiting for a reply. Not the whole inbox. We’re going for one less loose end.",
            practice: .steps(label: "ONE MESSAGE. ONE NEXT MOVE.", steps: [
                "Open a message you can deal with today.",
                "Reply with a clear answer, or say when you’ll follow up.",
                "Archive it once it’s handled. Leave the rest for later.",
            ]),
            reminder: "If it needs more time, a brief acknowledgment counts. Inbox zero is not the assignment."
        ),
        "mercury.communication.wait-ten-seconds": TaskGuide(
            title: "WAIT 10 SECONDS BEFORE HITTING SEND",
            instruction: "The message can wait ten seconds. Give your words a tiny layover before takeoff.",
            practice: .pauseTimer(label: "PAUSE BEFORE YOU SEND", seconds: 10, caption: "A LITTLE SPACE BEFORE SEND", steps: [
                "Take your thumb off send. Let one slow breath pass.",
                "Ask: is this clear, kind and going to the right person?",
            ]),
            reminder: "When the pause is over, edit anything that feels rushed. Then send when you’re ready."
        ),
        "mercury.communication.read-it-out-loud": TaskGuide(
            title: "READ IT OUT LOUD BEFORE SENDING",
            instruction: "Let your ears proofread. They sometimes catch what your very busy eyes politely missed.",
            practice: .steps(label: "A QUICK SOUND CHECK", steps: [
                "Read the whole message slowly, exactly as written.",
                "Listen for a sharp tone, missing words or an unclear request.",
                "Rewrite the awkward bit. Read that sentence once more.",
            ]),
            reminder: "Not somewhere you can speak? Mouth the words quietly. The point is to slow the scroll."
        ),
        "mercury.communication.save-the-draft": TaskGuide(
            title: "SAVE THE DRAFT AND COME BACK LATER",
            instruction: "If the words feel hot, let them cool. A draft is a perfectly respectable place to park them.",
            practice: .steps(label: "PARK IT. DON’T LOSE IT.", steps: [
                "Save the message as a draft, without sending.",
                "Set a reminder to return in 20 minutes, or at a calmer time.",
                "When you return, reread for tone and keep only what helps.",
            ]),
            reminder: "Check that the draft actually saved before closing. Future you deserves the words, not the retyping."
        ),
        "mercury.communication.check-recipient": TaskGuide(
            title: "CHECK THE RECIPIENT AND ATTACHMENT",
            instruction: "One last look before launch. Autocomplete is helpful, but not a trusted chaperone.",
            practice: .checklist(label: "THE BEFORE-SEND CHECK", items: [
                "Read the full recipient address. Check CC and reply-all too.",
                "Open the attachment: correct file, latest version, no private extras.",
                "If sharing a link, check the right person has access.",
            ]),
            reminder: "Mentioned an attachment? Make sure it’s actually attached. We’ve all sent the sequel email."
        ),
        "mercury.communication.confirm-next-step": TaskGuide(
            title: "CONFIRM THE NEXT STEP BEFORE CLOSING",
            instruction: "Before the chat ends, agree on who does what and when. A tiny recap beats a mystery sequel.",
            practice: .message(label: "BORROW THIS SIGN-OFF", text: "Just to confirm: I’ll send the revised file by 3 pm today, and you’ll review it tomorrow morning. Does that work?"),
            reminder: "Swap in the real action, owner and deadline. Wait for agreement before treating it as settled."
        ),

        // MARK: 02 Tech backup
        "mercury.tech.back-up-files": TaskGuide(
            title: "BACK UP IMPORTANT FILES TO CLOUD OR DRIVE",
            instruction: "Start with the files you’d miss most. A second copy is less dramatic than a recovery arc.",
            practice: .steps(label: "GIVE YOUR FILES A SECOND HOME", steps: [
                "Choose one important folder: documents, photos or current work.",
                "Copy it to a trusted cloud backup or an external drive.",
                "Wait for the transfer to finish. Check for any failed files.",
            ]),
            reminder: "Keep the originals. If using a drive, safely eject it and store it separately from your device."
        ),
        "mercury.tech.open-saved-copy": TaskGuide(
            title: "OPEN A SAVED COPY TO CHECK IT WORKED",
            instruction: "A reassuring filename is nice. A file that actually opens is even nicer.",
            practice: .checklist(label: "TEST THE COPY, NOT THE ORIGINAL", items: [
                "Go to the cloud folder or drive where you saved the backup.",
                "Open one important file from that location.",
                "Check the contents and latest changes are there.",
            ]),
            reminder: "If it won’t open or looks out of date, copy it again and retest. Don’t delete your original."
        ),
        "mercury.tech.update-password": TaskGuide(
            title: "UPDATE ONE PASSWORD YOU’VE BEEN PUTTING OFF",
            instruction: "Choose one account with an old or reused password. One stronger lock is a good start.",
            practice: .steps(label: "A SMALL SECURITY RESET", steps: [
                "Open the official app or website directly. Go to security settings.",
                "Generate a long, unique password with a password manager.",
                "Save the new password securely and enable two-factor authentication if available.",
            ]),
            reminder: "Never put passwords in a journal or message. Keep recovery codes somewhere secure, too."
        ),
        "mercury.tech.charge-power-bank": TaskGuide(
            title: "CHARGE YOUR BACKUP POWER BANK",
            instruction: "A power bank at 2% is mostly a paperweight. Give your backup a little backup.",
            practice: .checklist(label: "PLUG IN YOUR PLAN B", items: [
                "Find the power bank and a compatible charging cable.",
                "Plug it into a suitable charger on a clear, dry surface.",
                "Check the charging light. Set a reminder to unplug when full.",
            ]),
            reminder: "Skip damaged or swollen batteries. Once charged, keep it with the cable you’ll need on the go."
        ),
        "mercury.tech.sync-device": TaskGuide(
            title: "SYNC ONE DEVICE YOU RARELY SYNC",
            instruction: "That neglected tablet or spare laptop would like to catch up. No reunion speech needed.",
            practice: .steps(label: "BRING ONE DEVICE UP TO DATE", steps: [
                "Connect it to power and trusted Wi-Fi.",
                "Open its sync settings and check you’re in the right account.",
                "Run sync. Wait for completion and check one recent item appears.",
            ]),
            reminder: "Review any conflict or deletion notices before confirming. Sync keeps devices aligned; it isn’t a separate backup."
        ),
        "mercury.tech.write-down-number": TaskGuide(
            title: "WRITE DOWN ONE IMPORTANT PHONE NUMBER",
            instruction: "Pick someone you’d need if your phone went quiet. Paper has excellent battery life.",
            practice: .steps(label: "AN OFFLINE LIFELINE", steps: [
                "Choose a trusted contact or an essential service.",
                "Write their name and full number, including the country code.",
                "Double-check every digit and put the note in your wallet.",
            ]),
            reminder: "Store it somewhere private but reachable. A note saved only on your phone won’t help if the phone is gone."
        ),

        // MARK: 03 Flexible planning
        "mercury.planning.confirm-booking": TaskGuide(
            title: "CONFIRM THE TIME, PLACE AND BOOKING",
            instruction: "Check the details before you head out. Same city is good. Same address is better.",
            practice: .checklist(label: "CHECK THE ACTUAL CONFIRMATION", items: [
                "Verify the date, start time and time zone.",
                "Check the full address, entrance and travel route.",
                "Find the booking reference and confirm it’s still valid.",
            ]),
            reminder: "Details don’t match? Contact the venue or host now, and update your calendar once it’s confirmed."
        ),
        "mercury.planning.add-buffer": TaskGuide(
            title: "ADD A 15-MINUTE BUFFER AND A PLAN B",
            instruction: "Give one plan a little wiggle room. Plot twists are easier when they have somewhere to land.",
            practice: .steps(label: "MAKE A LITTLE ROOM", steps: [
                "Move your leave-by reminder 15 minutes earlier.",
                "Choose one fallback: another route, venue or way to join.",
                "Decide when you’ll switch to it, and save the details.",
            ]),
            reminder: "For example: if the bus is more than 10 minutes late, take the train. One simple backup is enough."
        ),
        "mercury.planning.pack-charger": TaskGuide(
            title: "PACK ONE BACKUP CHARGER",
            instruction: "Put the spare in the bag you’re actually taking. Beside the bag is a different location.",
            practice: .checklist(label: "PACK IT, DON’T JUST PLAN IT", items: [
                "Choose a charger or charged power bank for your device.",
                "Add the correct cable and a plug adapter if you’ll need one.",
                "Place the set in an easy-to-reach pocket of your bag.",
            ]),
            reminder: "Check the connector fits before leaving. A very prepared cable for the wrong phone is still the wrong cable."
        ),
        "mercury.planning.paper-backup": TaskGuide(
            title: "BRING A PAPER MAP OR PRINTED RECEIPT",
            instruction: "Give your plan an offline version. No signal should not mean no idea where you’re going.",
            practice: .steps(label: "THE NO-WI-FI EDITION", steps: [
                "Print the route map or the booking receipt you’ll need.",
                "Check the address, date and reference number are readable.",
                "Fold it into your bag or wallet, somewhere dry and reachable.",
            ]),
            reminder: "For a map, mark your destination. For a booking, check whether the original ticket or ID is also required."
        ),
        "mercury.planning.postpone-one-plan": TaskGuide(
            title: "CHOOSE ONE NONESSENTIAL PLAN TO POSTPONE",
            instruction: "Find one thing that can wait without causing harm. Making room is a plan, too.",
            practice: .message(label: "A GENTLE RESCHEDULE", text: "I’ve got a little too much on today. Could we move our catch-up to next week? Tuesday or Thursday would work for me."),
            reminder: "Pick a genuinely flexible plan, tell anyone affected, and move it in your calendar. No vanishing act required."
        ),
        "mercury.planning.extra-hour": TaskGuide(
            title: "LEAVE ONE EXTRA HOUR FOR TRAVEL",
            instruction: "Give the journey an extra hour, not an extra reason to panic. Arriving calmly is a lovely bonus.",
            practice: .steps(label: "WORK BACKWARD FROM ARRIVAL", steps: [
                "Check the route and your usual door-to-door travel time.",
                "Add 60 minutes, then work backward to a new departure time.",
                "Set a leave-by alarm and check live travel updates before going.",
            ]),
            reminder: "For flights or long-distance trips, keep the operator’s recommended check-in time as well. The buffer is extra."
        ),

        // MARK: 04 Journal
        "mercury.journal.name-the-feeling": TaskGuide(
            title: "NAME THE FEELING YOU’RE CARRYING TODAY",
            instruction: "Check in without trying to fix anything. A feeling can have a name without becoming the whole story.",
            practice: .reflection(label: "ONE HONEST SENTENCE", prompt: "Today I’m feeling ___. I notice it in ___. What I need most is ___.", example: "I’m feeling tense. My shoulders are tight. I need a little space before I reply."),
            reminder: "Write in your notebook or notes app. More than one feeling is allowed; so is ‘I’m not sure yet.’"
        ),
        "mercury.journal.in-your-control": TaskGuide(
            title: "WRITE WHAT IS IN YOUR CONTROL RIGHT NOW",
            instruction: "Separate your next move from everyone else’s reactions. You only need to steer your bit.",
            practice: .reflection(label: "YOUR SIDE OF THE ORBIT", prompt: "I can’t control ___. I can choose ___. My next small action is ___.", example: "I can’t control when they reply. I can choose to stop refreshing. I’ll put my phone away for 15 minutes."),
            reminder: "Write one action you can actually take today. Other people’s moods don’t belong on your to-do list."
        ),
        "mercury.journal.notice-a-pattern": TaskGuide(
            title: "NOTICE ONE PATTERN YOU WANT TO CHANGE",
            instruction: "Look for a repeat, not a reason to judge yourself. Curiosity is more useful than a courtroom.",
            practice: .reflection(label: "NOTICE. THEN TRY ONE SMALL SHIFT.", prompt: "When ___ happens, I tend to ___. Next time, I could try ___ instead.", example: "When I feel rushed, I send short replies that sound sharp. Next time, I’ll reread before sending."),
            reminder: "Jot down one pattern and one realistic alternative. You’re testing a new response, not rewriting your personality."
        ),
        "mercury.journal.grateful-for": TaskGuide(
            title: "WRITE ONE THING YOU’RE GRATEFUL FOR",
            instruction: "Find one real thing that helped today. It can be small. Especially small.",
            practice: .reflection(label: "NOTICE WHAT HELD YOU UP", prompt: "I’m grateful for ___ because it gave me ___.", example: "I’m grateful for the friend who checked in. It made a difficult afternoon feel less lonely."),
            reminder: "Write a line in your notebook or notes app. Gratitude doesn’t cancel the hard stuff; both can be true."
        ),
        "mercury.journal.small-win": TaskGuide(
            title: "DESCRIBE ONE SMALL WIN FROM TODAY",
            instruction: "Give yourself credit for something you did, not just what’s left. Quiet progress still counts.",
            practice: .reflection(label: "COLLECT A LITTLE EVIDENCE", prompt: "Today I ___. It took ___. I’m giving myself credit for ___.", example: "I made the call I’d been avoiding. It took courage. I’m proud I started, even though I was nervous."),
            reminder: "Write a few words. Getting out of bed, asking for help or taking a needed break can be a win, too."
        ),
        "mercury.journal.note-to-future-self": TaskGuide(
            title: "WRITE A KIND NOTE TO YOUR FUTURE SELF",
            instruction: "Write like you’re talking to someone you love. Future you doesn’t need another performance review.",
            practice: .reflection(label: "A NOTE FOR LATER", prompt: "Dear future me, I hope you remember ___. You don’t have to ___. You can ___.", example: "You don’t have to solve everything in one day. You’ve found your way through uncertainty before. Start with one thing."),
            reminder: "Save your own two or three sentences somewhere you’ll find them on a harder day. Kindness, not a deadline."
        ),
        "mercury.journal.gentle-intention": TaskGuide(
            title: "SET ONE GENTLE INTENTION FOR TOMORROW",
            instruction: "Choose how you’d like to meet the day, not a whole new personality by breakfast.",
            practice: .reflection(label: "A DIRECTION, NOT A DEMAND", prompt: "Tomorrow, I want to make room for ___. One small way I’ll do that is ___.", example: "I want to make room for calm. I’ll take one quiet minute before opening my messages."),
            reminder: "Write it down and keep it kind, specific and doable. If tomorrow changes shape, your intention can bend."
        ),
    ]
}
