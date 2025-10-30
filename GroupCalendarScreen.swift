import SwiftUI

struct GroupCalendarScreen: View {
    let groupID: UUID
    @ObservedObject private var groupsVM: GroupsViewModel

    init(groupID: UUID, groupsVM: GroupsViewModel) {
        self.groupID = groupID
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        GroupEventsView(groupID: groupID, groupsVM: groupsVM)
            .navigationTitle("Gruppenkalender")
            .navigationBarTitleDisplayMode(.inline)
    }
}
