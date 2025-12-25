import SwiftUI
import Supabase

// MARK: - GroupsView
struct GroupsView: View {
    @State private var groups: [AppGroup] = []
    @State private var showCreate = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var memberCounts: [UUID: Int] = [:]
    
    @StateObject private var unreadService = UnreadMessagesService.shared
    
    private let groupRepo: GroupRepository = SupabaseGroupRepository()
    
    var body: some View {
        Group {
            if isLoading && groups.isEmpty {
                loadingView
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else if groups.isEmpty {
                emptyView
            } else {
                groupsListView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gruppen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet {
                await loadGroups()
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            if groups.isEmpty {
                await loadGroups()
            }
        }
        .onAppear {
            Task {
                await loadGroups()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        ProgressView("Lade Gruppen...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Fehler beim Laden")
                .font(.headline)
            
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Erneut versuchen") {
                Task { await loadGroups() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Noch keine Gruppen")
                .font(.headline)
            
            Text("Erstelle deine erste Gruppe um zu beginnen")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var groupsListView: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(groups) { group in
                        GroupRow(
                            group: group,
                            unreadCount: unreadService.unreadCounts[group.id] ?? 0,
                            memberCount: memberCounts[group.id] ?? 0
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, isRefreshing ? 32 : 16)
            }
            
            if isRefreshing {
                ProgressView()
                    .tint(.blue)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Data Loading

    @MainActor
    private func loadGroups() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            groups = try await groupRepo.fetchGroups()
            await refreshUnreadCounts()
            await loadMemberCounts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func removeGroup(withId groupId: UUID) {
        groups.removeAll { $0.id == groupId }
    }
    
    @MainActor
    private func refreshUnreadCounts() async {
        guard !groups.isEmpty else { return }
        
        isRefreshing = true
        
        do {
            try await unreadService.refreshAllUnreadCounts(for: groups.map(\.id))
        } catch {
            print("⚠️ Fehler beim Laden der ungelesenen Nachrichten: \(error)")
        }
        
        isRefreshing = false
    }
    
    @MainActor
    private func loadMemberCounts() async {
        for group in groups {
            do {
                let count = try await groupRepo.fetchMemberCount(groupId: group.id)
                memberCounts[group.id] = count
            } catch {
                print("⚠️ Fehler beim Laden der Mitgliederzahl für Gruppe \(group.id): \(error)")
                memberCounts[group.id] = 0
            }
        }
    }
}

// MARK: - Group Row
private struct GroupRow: View {
    let group: AppGroup
    let unreadCount: Int
    let memberCount: Int
    
    @State private var isPressedCalendar = false
    @State private var isPressedChat = false
    
    var memberCountText: String {
        if memberCount == 1 {
            return "1 Mitglied"
        } else {
            return "\(memberCount) Mitglieder"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Linke Seite: Gruppeninformationen
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(memberCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Rechte Seite: Action Buttons
            HStack(spacing: 16) {
                // Kalender Button
                NavigationLink(destination: GroupCalendarScreen(groupID: group.id)) {
                    VStack(spacing: 4) {
                        CircularActionButton(
                            icon: "calendar",
                            color: .blue,
                            isPressed: isPressedCalendar
                        )
                        
                        Text("Kalender")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressedCalendar = true }
                        .onEnded { _ in isPressedCalendar = false }
                )
                
                // Chat Button mit Badge
                NavigationLink(destination: GroupChatScreen(group: group)) {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            CircularActionButton(
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .green,
                                isPressed: isPressedChat
                            )
                            
                            if unreadCount > 0 {
                                UnreadBadge(count: unreadCount)
                                    .offset(x: 6, y: -6)
                            }
                        }
                        
                        Text(unreadCount > 0 ? "\(unreadCount) neu" : "Chat")
                            .font(.caption2)
                            .fontWeight(unreadCount > 0 ? .semibold : .regular)
                            .foregroundStyle(unreadCount > 0 ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressedChat = true }
                        .onEnded { _ in isPressedChat = false }
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Circular Action Button
private struct CircularActionButton: View {
    let icon: String
    let color: Color
    var isPressed: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(isPressed ? 0.25 : 0.15))
                .frame(width: 50, height: 50)
            
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Unread Badge
private struct UnreadBadge: View {
    let count: Int
    
    var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }
    
    var body: some View {
        Text(displayText)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 5 : 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.red.opacity(0.3), radius: 3, x: 0, y: 1)
            .overlay(
                Capsule()
                    .strokeBorder(Color.white, lineWidth: 1.5)
            )
    }
}

// MARK: - Create Group Sheet
private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onGroupCreated: () async -> Void
    
    @State private var name = ""
    @State private var invites: [InviteRow] = [InviteRow()]
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let groupRepo: GroupRepository = SupabaseGroupRepository()
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Neue Gruppe erstellen")
                    .font(.title2)
                    .bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname")
                    .font(.headline)
                
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Invites
            VStack(alignment: .leading, spacing: 12) {
                Text("Benutzer einladen")
                    .font(.headline)
                
                ForEach($invites) { $invite in
                    InviteRowView(invite: $invite)
                }
                
                Button {
                    invites.append(InviteRow())
                } label: {
                    Label("Weitere Person", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
            
            // Messages
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            
            if let successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Abbrechen") { dismiss() }
                    .disabled(isCreating)
                
                Spacer()
                
                if isCreating {
                    ProgressView()
                        .padding(.trailing, 8)
                }
                
                Button("Erstellen") {
                    Task { await createGroup() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(20)
    }
    
    private func createGroup() async {
        let validInvites = invites
            .map { (email: $0.email.trimmingCharacters(in: .whitespacesAndNewlines), role: $0.role) }
            .filter { !$0.email.isEmpty }
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await groupRepo.create(name: name, invitedUsers: validInvites)
            
            await MainActor.run {
                successMessage = "✅ Gruppe '\(name)' wurde erstellt!"
                isCreating = false
            }
            
            await onGroupCreated()
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
            
        } catch {
            await MainActor.run {
                if let groupError = error as? GroupError {
                    switch groupError {
                    case .unknownAppleIds(let emails):
                        errorMessage = "❌ E-Mails nicht gefunden: \(emails.joined(separator: ", "))"
                    default:
                        errorMessage = "❌ \(groupError.localizedDescription)"
                    }
                } else {
                    errorMessage = "❌ \(error.localizedDescription)"
                }
                isCreating = false
            }
        }
    }
}

// MARK: - Invite Row
private struct InviteRow: Identifiable {
    let id = UUID()
    var email = ""
    var role: role = .user
}

private struct InviteRowView: View {
    @Binding var invite: InviteRow
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("E-Mail", text: $invite.email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            Picker("Rolle", selection: $invite.role) {
                Text("Mitglied").tag(role.user)
                Text("Admin").tag(role.admin)
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }
}
