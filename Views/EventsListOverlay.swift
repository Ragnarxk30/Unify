import SwiftUI

struct EventsListOverlay: View {
    let groupID: UUID
    @Binding var isPresented: Bool
    let previousTab: GroupTab

    @State private var showAddEvent = false

    var body: some View {
        NavigationStack {
            GroupEventsList(groupID: groupID)
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
                                Text(previousTab.rawValue)
                                    .font(.body)
                            }
                        }
                        .accessibilityLabel("Zurück zu \(previousTab.rawValue)")
                    }

                    // Plus Button (Rechts)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddEvent = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body)
                        }
                        .accessibilityLabel("Neuen Termin anlegen")
                    }
                }
                .sheet(isPresented: $showAddEvent) {
                    GroupEventsView(groupID: groupID)
                        .presentationDetents([.medium, .large])
                }
        }
        .background(Color(.systemGroupedBackground))
    }
}
