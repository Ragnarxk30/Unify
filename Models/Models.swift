import Foundation

struct UserProfile: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var initials: String {
        let comps = displayName.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

struct Event: Identifiable, Hashable {
    let id: UUID
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool = false
    var groupID: UUID? = nil
}

struct Message: Identifiable, Hashable {
    let id: UUID
    var sender: UserProfile
    var text: String
    var sentAt: Date
}

struct Group: Identifiable, Hashable {
    let id: UUID
    var name: String
    var owner: UserProfile
    var members: [UserProfile]
    var events: [Event]
    var messages: [Message]
}
