import Foundation

enum MockData {
    // 8 Teilnehmer insgesamt (Ich + 7 weitere)
    static let me   = UserProfile(id: UUID(), displayName: "Ich")
    static let lisa = UserProfile(id: UUID(), displayName: "Lisa Müller")
    static let tom  = UserProfile(id: UUID(), displayName: "Tom Becker")
    static let max  = UserProfile(id: UUID(), displayName: "Max Mustermann")
    static let anna = UserProfile(id: UUID(), displayName: "Anna Schmidt")
    static let ben  = UserProfile(id: UUID(), displayName: "Ben Wagner")
    static let eva  = UserProfile(id: UUID(), displayName: "Eva König")
    static let paul = UserProfile(id: UUID(), displayName: "Paul Neumann")

    static var myEvents: [Event] = {
        let cal = Calendar.current
        let now = Date()
        let p1s = cal.date(byAdding: .minute, value: -120, to: now)!
        let p1e = cal.date(byAdding: .minute, value: -30, to: now)!
        let p2s = cal.date(byAdding: .day, value: 0, to: now)!.addingTimeInterval(60*60*2)
        let p2e = cal.date(byAdding: .hour, value: 3, to: p2s)!
        let p3s = cal.date(byAdding: .day, value: 2, to: now)!.addingTimeInterval(60*60*19)
        let p3e = cal.date(byAdding: .hour, value: 1, to: p3s)!
        return [
            Event(id: UUID(), title: "Privater Termin", start: p1s, end: p1e),
            Event(id: UUID(), title: "Familientreffen", start: p2s, end: p2e),
            Event(id: UUID(), title: "Kinobesuch", start: p3s, end: p3e)
        ]
    }()

    static var groups: [Group] = {
        let g1ID = UUID()
        let g2ID = UUID()

        let allMembers: [UserProfile] = [me, lisa, tom, max, anna, ben, eva, paul]

        let g1Events = [
            Event(id: UUID(), title: "Familienbrunch", start: Date().addingTimeInterval(60*60*24*3), end: Date().addingTimeInterval(60*60*24*3 + 60*60), groupID: g1ID),
            Event(id: UUID(), title: "Omas Geburtstag", start: Date().addingTimeInterval(60*60*24*10), end: Date().addingTimeInterval(60*60*24*10 + 60*60*2), groupID: g1ID)
        ]
        let g2Events = [
            Event(id: UUID(), title: "Kinoabend", start: Date().addingTimeInterval(60*60*24*2 + 60*60*19), end: Date().addingTimeInterval(60*60*24*2 + 60*60*20), groupID: g2ID)
        ]

        // Startnachrichten von verschiedenen Teilnehmern, zeitlich gestaffelt
        let now = Date()
        let baseMessagesG1: [Message] = [
            Message(id: UUID(), sender: lisa, text: "Hallo zusammen! Wer hat am Wochenende Zeit?", sentAt: now.addingTimeInterval(-60*60*5)),
            Message(id: UUID(), sender: tom,  text: "Ich wäre Samstag dabei.", sentAt: now.addingTimeInterval(-60*60*4.5)),
            Message(id: UUID(), sender: max,  text: "Sonntag passt mir besser.", sentAt: now.addingTimeInterval(-60*60*4)),
            Message(id: UUID(), sender: anna, text: "Wie wäre es mit Brunch am Sonntag?", sentAt: now.addingTimeInterval(-60*60*3.5)),
            Message(id: UUID(), sender: ben,  text: "Klingt gut! Wo treffen wir uns?", sentAt: now.addingTimeInterval(-60*60*3)),
            Message(id: UUID(), sender: eva,  text: "Ich bringe Croissants mit.", sentAt: now.addingTimeInterval(-60*60*2.5)),
            Message(id: UUID(), sender: paul, text: "Ich kümmere mich um Kaffee.", sentAt: now.addingTimeInterval(-60*60*2)),
            Message(id: UUID(), sender: me,   text: "Perfekt, ich mache Rührei. Freu mich!", sentAt: now.addingTimeInterval(-60*60*1.5))
        ]

        let baseMessagesG2: [Message] = [
            Message(id: UUID(), sender: max,  text: "Habt ihr Lust auf Kino diese Woche?", sentAt: now.addingTimeInterval(-60*60*6)),
            Message(id: UUID(), sender: eva,  text: "Ja! Welcher Film?", sentAt: now.addingTimeInterval(-60*60*5.5)),
            Message(id: UUID(), sender: paul, text: "Ich wäre für eine Komödie.", sentAt: now.addingTimeInterval(-60*60*5)),
            Message(id: UUID(), sender: lisa, text: "Es läuft eine neue RomCom, gute Bewertungen.", sentAt: now.addingTimeInterval(-60*60*4.5)),
            Message(id: UUID(), sender: tom,  text: "Passt mir am Freitag Abend.", sentAt: now.addingTimeInterval(-60*60*4)),
            Message(id: UUID(), sender: anna, text: "Mir auch. Uhrzeit?", sentAt: now.addingTimeInterval(-60*60*3.5)),
            Message(id: UUID(), sender: ben,  text: "Wie wäre es mit 19:30?", sentAt: now.addingTimeInterval(-60*60*3)),
            Message(id: UUID(), sender: me,   text: "Bin dabei. 19:30 passt!", sentAt: now.addingTimeInterval(-60*60*2.5))
        ]

        let g1 = Group(id: g1ID, name: "Familie", owner: me, members: allMembers, events: g1Events, messages: baseMessagesG1)
        let g2 = Group(id: g2ID, name: "Freunde", owner: me, members: allMembers, events: g2Events, messages: baseMessagesG2)

        return [g1, g2]
    }()
}
