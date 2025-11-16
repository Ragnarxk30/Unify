import SwiftUI

enum GroupDetailTab: String, CaseIterable, Hashable {
    case events = "Termine"
    case chat = "Chat"
}

struct GroupDetailView: View {
    let group: AppGroup // ✅ AppGroup statt Group
    @State private var selected: GroupDetailTab = .events
    @State private var showAddEvent = false

    var body: some View {
        VStack(spacing: 0) {
            // ✅ Einfache Picker-Lösung statt SegmentedToggle
            Picker("Ansicht", selection: $selected) {
                ForEach(GroupDetailTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: systemImage(for: tab))
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            switch selected {
            case .events:
                GroupEventsView(groupID: group.id) // ✅ Ohne GroupsViewModel
            case .chat:
                GroupChatView(group: group) // ✅ Ohne ChatViewModel
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
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
            // ✅ GroupEventsView für Event-Erstellung verwenden
            GroupEventsView(groupID: group.id)
                .presentationDetents([.medium, .large])
        }
    }

    // ✅ Helper für System-Icons
    private func systemImage(for tab: GroupDetailTab) -> String {
        switch tab {
        case .events: return "calendar"
        case .chat: return "text.bubble"
        }
    }
}
