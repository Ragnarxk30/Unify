import SwiftUI
import Supabase

struct GroupsView: View {
    @State private var groups: [AppGroup] = []
    @State private var showCreate = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    
    // 👈 StateObject für automatische UI-Updates
    @StateObject private var unreadService = UnreadMessagesService.shared
    
    private let groupRepo: GroupRepository = SupabaseGroupRepository()

    var body: some View {
        Group {
            // 👈 Nur beim ersten Laden (wenn keine Gruppen) Fullscreen Loader
            if isLoading && groups.isEmpty {
                ProgressView("Lade Gruppen...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Text("Fehler beim Laden der Gruppen")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("Erneut versuchen") {
                        Task {
                            await loadGroups()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if groups.isEmpty && !isLoading {
                VStack {
                    Image(systemName: "person.3")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("Noch keine Gruppen")
                        .font(.headline)
                        .padding(.top, 8)
                    Text("Erstelle deine erste Gruppe um zu beginnen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                // 👈 Gruppen werden SOFORT angezeigt, auch beim Refresh
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(groups) { group in
                                GroupRow(
                                    group: group,
                                    unreadCount: unreadService.unreadCounts[group.id] ?? 0
                                )
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, isRefreshing ? 32 : 16) // Platz für Indicator
                    }
                    
                    // 👈 Kleiner Refresh-Indicator oben (wie Instagram)
                    if isRefreshing {
                        ProgressView()
                            .tint(.blue)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gruppen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet(onGroupCreated: {
                await loadGroups()
            })
            .presentationDetents([.medium])
        }
        // 👈 NUR beim ersten Öffnen laden
        .task {
            if groups.isEmpty {
                await loadGroups()
            }
        }
        // 👈 KEIN cleanup mehr - Realtime läuft weiter!
    }

    // MARK: - Gruppen laden (nur beim Start)
    @MainActor
    private func loadGroups() async {
        // Verhindere doppeltes Laden
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            groups = try await groupRepo.fetchGroups()
            print("✅ \(groups.count) Gruppen geladen")
            
            // Ungelesene Nachrichten laden
            await refreshUnreadCounts()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Laden der Gruppen: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Nur Unread Counts aktualisieren (schnell!)
    @MainActor
    private func refreshUnreadCounts() async {
        guard !groups.isEmpty else { return }
        
        isRefreshing = true
        
        let groupIds = groups.map { $0.id }
        
        do {
            // 👈 Startet automatisch Realtime für alle Gruppen
            try await unreadService.refreshAllUnreadCounts(for: groupIds)
            print("✅ Ungelesene Nachrichten aktualisiert + Realtime gestartet")
        } catch {
            print("⚠️ Fehler beim Laden der ungelesenen Nachrichten: \(error)")
        }
        
        isRefreshing = false
    }
}

private struct GroupRow: View {
    let group: AppGroup
    let unreadCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name).font(.title3).bold()
                    Text("Owner: \(group.owner.display_name)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                NavigationLink {
                    GroupCalendarScreen(groupID: group.id)
                } label: {
                    Label("Kalender", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // 👈 Badge für ungelesene Nachrichten
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        GroupChatScreen(group: group)
                    } label: {
                        Label("Chat", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var shouldAutoDismiss = false

    private struct InviteRow: Identifiable {
        let id = UUID()
        var email: String = ""
        var role: role = .user
        
        static var availableRoles: [role] {
            [.user, .admin]
        }
    }

    @State private var invites: [InviteRow] = [InviteRow()]
    
    private let groupRepo: GroupRepository = SupabaseGroupRepository()
    
    let onGroupCreated: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Neue Gruppe erstellen")
                    .font(.title).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname").font(.headline)
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Benutzer einladen").font(.headline)

                ForEach($invites) { $invite in
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
                    }
                }

                Button {
                    invites.append(InviteRow())
                } label: {
                    Label("Weitere Person hinzufügen", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            if let successMessage = successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundColor(.green)
                    .padding(.top, 8)
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                    .disabled(isCreating)
                
                Spacer()
                
                if isCreating {
                    ProgressView()
                }
                
                Button {
                    Task {
                        await createGroup()
                    }
                } label: {
                    Text("Gruppe erstellen")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .onChange(of: shouldAutoDismiss) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }

    private func createGroup() async {
        let invitedUsers = invites
            .map { (email: $0.email.trimmingCharacters(in: .whitespacesAndNewlines), role: $0.role) }
            .filter { !$0.email.isEmpty }

        isCreating = true
        errorMessage = nil
        successMessage = nil
        shouldAutoDismiss = false

        do {
            try await groupRepo.create(name: name, invitedUsers: invitedUsers)
            
            await MainActor.run {
                successMessage = "✅ Gruppe '\(name)' wurde erfolgreich erstellt!"
                isCreating = false
                shouldAutoDismiss = true
            }
            
            await onGroupCreated()
            
        } catch {
            await MainActor.run {
                if let groupError = error as? GroupError {
                    switch groupError {
                    case .unknownAppleIds(let emails):
                        errorMessage = "❌ Folgende E-Mail-Adressen wurden nicht gefunden: \(emails.joined(separator: ", "))"
                    default:
                        errorMessage = "❌ \(groupError.localizedDescription)"
                    }
                } else {
                    errorMessage = "❌ \(error.localizedDescription)"
                }
                isCreating = false
                shouldAutoDismiss = false
            }
        }
    }
}
