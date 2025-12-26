import SwiftUI

// MARK: - Group Tab Enum
enum GroupTab: String, CaseIterable {
    case chat = "Chat"
    case calendar = "Kalender"
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .calendar: return "calendar"
        }
    }
}

struct GroupChatScreen: View {
    @Environment(\.dismiss) private var dismiss

    let group: AppGroup
    @State private var showSettings = false
    @State private var showEventsList = false
    @State private var currentGroup: AppGroup
    @State private var hasMarkedAsRead = false
    @State private var selectedTab: GroupTab = .chat

    init(group: AppGroup) {
        self.group = group
        _currentGroup = State(initialValue: group)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Content: Chat | Kalender
                Group {
                    switch selectedTab {
                    case .chat:
                        GroupChatView(group: currentGroup)
                    case .calendar:
                        GroupMonthlyCalendarView(groupID: currentGroup.id)
                    }
                }

                // Invisible edge swipe area (right edge, vertically centered)
                VStack {
                    Spacer()
                        .frame(height: 120) // Platz für Toolbar/Navigation oben

                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: 40)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        if value.translation.width < -30 {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                showEventsList = true
                                            }
                                        }
                                    }
                            )
                    }
                    .frame(height: geometry.size.height - 240) // Mitte des Bildschirms

                    Spacer()
                        .frame(height: 120) // Platz für Input-Bereich unten
                }

                // Events List Page Overlay (slides in from right)
                if showEventsList {
                    NavigationStack {
                        GroupEventsList(groupID: currentGroup.id, groupName: currentGroup.name)
                            .navigationTitle("Termine")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarBackButtonHidden(true)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showEventsList = false
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.left")
                                                .font(.body.weight(.semibold))
                                            Text("Zurück")
                                                .font(.body)
                                        }
                                    }
                                }
                            }
                    }
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
                }
            }
        }
        .navigationTitle(showEventsList ? "Termine" : currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if !showEventsList {
                // Tab Switcher mit Settings (Rechts)
                ToolbarItem(placement: .topBarTrailing) {
                    GroupTabSwitcher(
                        selectedTab: $selectedTab,
                        isSettingsOpen: showSettings,
                        onSettingsTap: { showSettings = true }
                    )
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            GroupSettingsView(
                group: currentGroup,
                onUpdated: { updated in
                    currentGroup = updated
                },
                onGroupDeleted: {
                    dismiss()
                }
            )
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
        } catch {
            print("⚠️ [GroupChatScreen] Fehler beim Markieren: \(error)")
        }
    }
}

// MARK: - Custom Tab Switcher
private struct GroupTabSwitcher: View {
    @Binding var selectedTab: GroupTab
    var isSettingsOpen: Bool
    var onSettingsTap: () -> Void
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 4) {
            // Settings Button (links, öffnet Sheet)
            Button {
                onSettingsTap()
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSettingsOpen ? .white : .secondary)
                    .frame(width: 36, height: 32)
                    .background {
                        if isSettingsOpen {
                            Capsule()
                                .fill(Color.accentColor)
                        }
                    }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSettingsOpen)

            // Chat & Kalender Tabs
            ForEach(GroupTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        .frame(width: 36, height: 32)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "TAB_BG", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }
}
