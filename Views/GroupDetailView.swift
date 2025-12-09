import SwiftUI

enum GroupDetailTab: String, CaseIterable, Hashable {
    case events = "Termine"
    case chat = "Chat"
    
    var icon: String {
        switch self {
        case .events: return "calendar"
        case .chat: return "text.bubble"
        }
    }
}

struct GroupDetailView: View {
    let group: AppGroup
    
    @State private var selectedTab: GroupDetailTab = .events
    @State private var showAddEvent = false
    
    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            tabContent
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
            GroupEventsView(groupID: group.id)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Subviews
    
    private var tabPicker: some View {
        Picker("Ansicht", selection: $selectedTab) {
            ForEach(GroupDetailTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .events:
            GroupEventsView(groupID: group.id)
        case .chat:
            GroupChatView(group: group)
        }
    }
}
