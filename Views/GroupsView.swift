import SwiftUI
import Supabase

// MARK: - GroupsView
struct GroupsView: View {
    @State private var groups: [AppGroup] = []
    @State private var showCreate = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    
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
                            unreadCount: unreadService.unreadCounts[group.id] ?? 0
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
}

// MARK: - Group Row
private struct GroupRow: View {
    let group: AppGroup
    let unreadCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.title3)
                    .bold()
                
                Text("Owner: \(group.owner.display_name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                NavigationLink {
                    GroupCalendarScreen(groupID: group.id)
                } label: {
                    Label("Kalender", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Chat mit Badge
                NavigationLink {
                    GroupChatScreen(group: group)
                } label: {
                    Label("Chat", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        UnreadBadge(count: unreadCount)
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Unread Badge
private struct UnreadBadge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .bold()
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
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
