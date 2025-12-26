import SwiftUI

// MARK: - Group Tab Enum
enum GroupTab: String, CaseIterable {
    case chat = "Chat"
    case calendar = "Gruppenkalender"
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
                // Main Content: Chat | Gruppenkalender
                Group {
                    switch selectedTab {
                    case .chat:
                        GroupChatView(group: currentGroup)
                    case .calendar:
                        GroupMonthlyCalendarView(groupID: currentGroup.id)
                    }
                }

                // Invisible edge swipe area (right edge)
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 40)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    print("🔄 Edge Drag: \(value.translation.width)")
                                }
                                .onEnded { value in
                                    print("✅ Edge Drag ended: \(value.translation.width)")
                                    // Swipe LEFT from right edge → Show Events List
                                    if value.translation.width < -30 {
                                        print("🎉 Opening Events List!")
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showEventsList = true
                                        }
                                    }
                                }
                        )
                }

                // Events List Page Overlay (slides in from right)
                if showEventsList {
                    NavigationStack {
                        GroupEventsList(groupID: currentGroup.id)
                            .navigationTitle("Termine")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarBackButtonHidden(true)
                            .toolbar {
                                // Custom Back Button (Links)
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showEventsList = false
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.left")
                                                .font(.body.weight(.semibold))
                                            Text(selectedTab == .chat ? "Chat" : "Gruppenkalender")
                                                .font(.body)
                                        }
                                    }
                                }

                                // Plus Button (Rechts)
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        // Show create event sheet
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.body)
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
        .navigationTitle(selectedTab == .chat ? currentGroup.name : "Gruppenkalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Nur anzeigen wenn NICHT im EventsList Sheet
            if !showEventsList {
                // Settings Icon (Links) - person.2
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.body)
                    }
                    .accessibilityLabel("Gruppeneinstellungen")
                }

                // Segmented Picker (Mitte)
                ToolbarItem(placement: .principal) {
                    Picker("Ansicht", selection: $selectedTab) {
                        ForEach(GroupTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
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
            print("✅ [GroupChatScreen] Chat als gelesen markiert")
        } catch {
            print("⚠️ [GroupChatScreen] Fehler beim Markieren: \(error)")
        }
    }
}
