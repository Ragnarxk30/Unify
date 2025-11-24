import SwiftUI
import Supabase

struct GroupsView: View {
    @State private var groups: [AppGroup] = []
    @State private var showCreate = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // ✅ Dein GroupRepository verwenden
    private let groupRepo: GroupRepository = SupabaseGroupRepository()

    var body: some View {
        Group {
            if isLoading {
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
            } else if groups.isEmpty {
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
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(groups) { group in
                            GroupRow(group: group)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
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
                // 👈 NEU: Callback wenn Gruppe erstellt wurde
                await loadGroups()
            })
            .presentationDetents([.medium])
        }
        .task {
            await loadGroups()
        }
    }

    // MARK: - Gruppen laden
    @MainActor
    private func loadGroups() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ JETZT: fetchGroups verwenden der alle Mitgliedsgruppen lädt
            groups = try await groupRepo.fetchGroups()
            print("✅ \(groups.count) Gruppen geladen")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Laden der Gruppen: \(error)")
        }
        
        isLoading = false
    }
}

private struct GroupRow: View {
    let group: AppGroup

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

                NavigationLink {
                    GroupChatScreen(group: group)
                } label: {
                    Label("Chat", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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

    // Eine Zeile pro Einladung (E-Mail + Rolle)
    private struct InviteRow: Identifiable {
        let id = UUID()
        var email: String = ""
        var role: role = .user
        
        static var availableRoles: [role] {
            [.user, .admin]
        }
    }

    @State private var invites: [InviteRow] = [InviteRow()]
    
    // 👈 NEU: Direkter Zugriff auf Repository
    private let groupRepo: GroupRepository = SupabaseGroupRepository()
    
    // 👈 NEU: Callback für erfolgreiche Erstellung
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

            // Gruppenname
            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname").font(.headline)
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Einzuladende Benutzer
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

            // 👈 FEHLER ODER ERFOLG ANZEIGEN
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
        // 👈 AUTO-DISMISS BEI ERFOLG
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
            print("🔴 DIREKTER AUFRUF VOR groupRepo.create")
            // 👈 NEU: Direkter Aufruf statt über Closure
            try await groupRepo.create(name: name, invitedUsers: invitedUsers)
            print("🔴 DIREKTER AUFRUF NACH groupRepo.create")
            
            await MainActor.run {
                successMessage = "✅ Gruppe '\(name)' wurde erfolgreich erstellt!"
                isCreating = false
                shouldAutoDismiss = true
            }
            
            // 👈 NEU: Gruppen im Hintergrund neu laden
            await onGroupCreated()
            
        } catch {
            print("🔴 DIREKTER AUFRUF IM CATCH: \(error)")
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
