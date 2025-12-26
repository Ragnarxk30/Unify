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
    
    var memberCountText: String {
        memberCount == 1 ? "1 Mitglied" : "\(memberCount) Mitglieder"
    }
    
    var body: some View {
        NavigationLink(destination: GroupChatScreen(group: group)) {
            HStack(spacing: 14) {
                // Gruppen-Avatar mit Initialen
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Text(String(group.name.prefix(2)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                // Gruppen-Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption2)
                        Text(memberCountText)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Unread Badge (nur wenn > 0)
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
    @FocusState private var isNameFocused: Bool
    
    private let groupRepo: GroupRepository = SupabaseGroupRepository()
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Gruppen-Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        if name.isEmpty {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        } else {
                            Text(String(name.prefix(2)).uppercased())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gruppenname")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("z.B. Familie, Arbeit, Freunde", text: $name)
                            .font(.body)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .focused($isNameFocused)
                    }
                    
                    // Einladungen
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Mitglieder einladen")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Optional")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        VStack(spacing: 10) {
                            ForEach($invites) { $invite in
                                InviteRowView(invite: $invite)
                            }
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                invites.append(InviteRow())
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Weitere Person einladen")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Fehler/Erfolg Nachrichten
                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if let successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(successMessage)
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neue Gruppe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createGroup() }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.85)
                        } else {
                            Text("Erstellen")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .onAppear {
            isNameFocused = true
        }
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
                successMessage = "Gruppe wurde erstellt!"
                isCreating = false
            }
            
            await onGroupCreated()
            
            try? await Task.sleep(nanoseconds: 400_000_000)
            dismiss()
            
        } catch {
            await MainActor.run {
                if let groupError = error as? GroupError {
                    switch groupError {
                    case .unknownAppleIds(let emails):
                        errorMessage = "E-Mails nicht gefunden: \(emails.joined(separator: ", "))"
                    default:
                        errorMessage = groupError.localizedDescription
                    }
                } else {
                    errorMessage = error.localizedDescription
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
        HStack(spacing: 10) {
            TextField("E-Mail-Adresse", text: $invite.email)
                .font(.body)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Menu {
                Button {
                    invite.role = .user
                } label: {
                    Label("Mitglied", systemImage: invite.role == .user ? "checkmark" : "")
                }
                
                Button {
                    invite.role = .admin
                } label: {
                    Label("Admin", systemImage: invite.role == .admin ? "checkmark" : "")
                }
            } label: {
                Text(invite.role == .admin ? "Admin" : "Mitglied")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
