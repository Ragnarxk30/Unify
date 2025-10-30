import SwiftUI

struct GroupChatScreen: View {
    let group: Group
    @ObservedObject private var groupsVM: GroupsViewModel

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        GroupChatView(vm: ChatViewModel(group: group, groupsVM: groupsVM))
            .navigationTitle(group.name + " – Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar) // nur hier verstecken
    }
}
