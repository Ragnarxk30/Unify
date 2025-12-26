import SwiftUI

struct EventsListOverlay: View {
    let groupID: UUID
    let groupName: String
    @Binding var isPresented: Bool
    let previousTab: GroupTab

    @State private var showAddEvent = false

    var body: some View {
        NavigationStack {
            GroupEventsList(groupID: groupID, groupName: groupName)
                .navigationTitle("Termine")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Back Button (Links)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                Text(groupName)
                                    .font(.body)
                            }
                        }
                        .accessibilityLabel("Zurück zu \(groupName)")
                    }
                }
        }
        .background(Color(.systemGroupedBackground))
    }
}
