import SwiftUI

struct GroupChatScreen: View {
    let group: AppGroup
    @State private var showAddEvent = false
    @State private var showSettings = false
    @State private var currentGroup: AppGroup
    @State private var hasMarkedAsRead = false

    init(group: AppGroup) {
        self.group = group
        _currentGroup = State(initialValue: group)
    }

    var body: some View {
        GroupChatView(group: currentGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
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
                    .accessibilityLabel("Gruppeneinstellungen öffnen")
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
                    currentGroup = updated
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                await markChatAsRead()
            }
    }
    
    @MainActor
    private func markChatAsRead() async {
        guard !hasMarkedAsRead else { return }
        
        do {
            try await UnreadMessagesService.shared.markAsRead(groupId: group.id)
            hasMarkedAsRead = true
            print("✅ [GroupChatScreen] Chat als gelesen markiert")
        } catch {
            print("⚠️ [GroupChatScreen] Fehler beim Markieren: \(error)")
        }
    }
}
