import SwiftUI

// MARK: - Wrapper-Screen für den Gruppenchat
struct GroupChatScreen: View {
    let group: Group
    @ObservedObject private var groupsVM: GroupsViewModel

    @State private var showAddEvent = false

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        GroupChatView(vm: ChatViewModel(group: group, groupsVM: groupsVM))
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                // Rechts oben: Plus
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neuen Termin anlegen")
                }
            }
            .sheet(isPresented: $showAddEvent) {
                // Einfaches, vorhandenes Formular wiederverwenden:
                GroupEventsView(groupID: group.id, groupsVM: groupsVM)
                    .presentationDetents([.medium, .large])
            }
    }
}
