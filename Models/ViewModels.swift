import Foundation
import Combine

final class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = MockData.myEvents.sorted(by: { $0.start < $1.start })
}

final class GroupsViewModel: ObservableObject {
    @Published var groups: [Group] = MockData.groups

    func createGroup(name: String, invited: [String]) {
        let newID = UUID()
        let new = Group(
            id: newID,
            name: name.isEmpty ? "Neue Gruppe" : name,
            owner: MockData.me,
            members: [MockData.me],
            events: [],
            messages: []
        )
        groups.append(new)
    }

    func addMessage(_ text: String, to groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let msg = Message(id: UUID(), sender: MockData.me, text: text, sentAt: Date())
        groups[idx].messages.append(msg)
    }

    func addEvent(title: String, start: Date, end: Date, to groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let ev = Event(id: UUID(), title: title, start: start, end: end, groupID: groupID)
        groups[idx].events.append(ev)
        groups[idx].events.sort { $0.start < $1.start }
    }
}

final class ChatViewModel: ObservableObject {
    @Published var group: Group
    private var groupsVM: GroupsViewModel

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self.groupsVM = groupsVM
    }

    func refreshFromStore() {
        if let updated = groupsVM.groups.first(where: { $0.id == group.id }) {
            group = updated
        }
    }

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        groupsVM.addMessage(text, to: group.id)
        refreshFromStore()
    }
}
