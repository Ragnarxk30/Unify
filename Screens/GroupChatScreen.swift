import SwiftUI

struct GroupChatScreen: View {
    let group: AppGroup
    @State private var showAddEvent = false

    var body: some View {
        GroupChatView(group: group)
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
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
                GroupEventsView(groupID: group.id) // ✅ Jetzt GroupEventsView statt SimpleEventCreationView
                    .presentationDetents([.medium, .large])
            }
    }
}
