import Foundation

enum MockData {
    static let me = UserProfile(id: UUID(), displayName: "Ich")
    static let lisa = UserProfile(id: UUID(), displayName: "Lisa Müller")
    static let tom = UserProfile(id: UUID(), displayName: "Tom Becker")

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

        let g1Events = [
            Event(id: UUID(), title: "Familienbrunch", start: Date().addingTimeInterval(60*60*24*3), end: Date().addingTimeInterval(60*60*24*3 + 60*60), groupID: g1ID),
            Event(id: UUID(), title: "Omas Geburtstag", start: Date().addingTimeInterval(60*60*24*10), end: Date().addingTimeInterval(60*60*24*10 + 60*60*2), groupID: g1ID)
        ]
        let g2Events = [
            Event(id: UUID(), title: "Kinoabend", start: Date().addingTimeInterval(60*60*24*2 + 60*60*19), end: Date().addingTimeInterval(60*60*24*2 + 60*60*20), groupID: g2ID)
        ]

        let baseMessages = [
            Message(id: UUID(), sender: lisa, text: "Habt ihr Lust auf Kino?", sentAt: Date().addingTimeInterval(-60*60))
        ]

        let g1 = Group(id: g1ID, name: "Familie", owner: me, members: [me, lisa, tom], events: g1Events, messages: baseMessages)
        let g2 = Group(id: g2ID, name: "Freunde", owner: me, members: [me, lisa, tom], events: g2Events, messages: baseMessages)

        return [g1, g2]
    }()
}
