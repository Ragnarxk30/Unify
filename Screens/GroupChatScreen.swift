import SwiftUI
//
struct GroupChatScreen: View {
    let group: AppGroup
    @State private var showAddEvent = false
    @State private var showSettings = false
    @State private var currentGroup: AppGroup

    init(group: AppGroup) {
        self.group = group
        _currentGroup = State(initialValue: group)
    }

    var body: some View {
        GroupChatView(group: currentGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                // Antippbarer Titel in der Mitte
                ToolbarItem(placement: .principal) {
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentGroup.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gruppeneinstellungen Ã¶ffnen")
                }

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
                GroupEventsView(groupID: currentGroup.id)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) {
                GroupSettingsView(group: currentGroup) { updated in
                    // Titel aktualisieren, damit der Button/Chat-Header den neuen Namen zeigt
                    currentGroup = updated
                }
                .presentationDetents([.medium, .large])
            }
    }
}
