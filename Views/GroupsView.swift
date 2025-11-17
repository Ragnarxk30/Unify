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
            CreateGroupSheet { name, invitedAppleIds in
                Task {
                    do {
                        // ✅ Deine create Methode mit invitedAppleIds verwenden
                        try await groupRepo.create(name: name, invitedAppleIds: invitedAppleIds)
                        await loadGroups()
                    } catch {
                        print("Fehler beim Erstellen der Gruppe:", error.localizedDescription)
                    }
                }
            }
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

    // Eine Zeile pro Einladung (E-Mail + Rolle)
    private struct InviteRow: Identifiable {
        enum Role: String, CaseIterable, Identifiable {
            case member   // <- entspricht deinem Enum-Wert in Supabase
            case admin
            case owner

            var id: String { rawValue }

            var label: String {
                switch self {
                case .member: return "Mitglied"
                case .admin:  return "Admin"
                case .owner:  return "Owner"
                }
            }
        }

        let id = UUID()
        var email: String = ""
        var role: Role = .member    // Default: member
    }

    @State private var invites: [InviteRow] = [InviteRow()]

    /// Aktuell nur Name + E-Mails.
    /// Rollen sind schon im State und können später leicht ergänzt werden.
    let onCreate: (String, [String]) -> Void

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
                            ForEach(InviteRow.Role.allCases) { role in
                                Text(role.label).tag(role)
                            }
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

                Text("Standardrolle ist „Mitglied“.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button {
                    // Nur Mails, Rollen kommen später dazu
                    let cleanedEmails = invites
                        .map { $0.email.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    onCreate(name, cleanedEmails)
                    dismiss()
                } label: {
                    Text("Gruppe erstellen")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
}
