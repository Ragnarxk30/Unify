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
    
    // ❌ DIESE METHODE ENTFERNEN/LÖSCHEN - wird nicht mehr benötigt
    /*
    private func fetchGroupsForUser(userId: UUID) async throws -> [AppGroup] {
        let groups: [AppGroup] = try await supabase
            .from("group")
            .select("""
                id,
                name,
                owner_id,
                user:user!owner_id(
                    id,
                    display_name,
                    email
                )
            """)
            .eq("owner_id", value: userId)  // ← DAS WAR DAS PROBLEM!
            .execute()
            .value
        
        return groups
    }
    */
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
    @State private var invited: String = ""

    let onCreate: (String, [String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Neue Gruppe erstellen").font(.title).bold()
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname").font(.headline)
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Benutzer einladen").font(.headline)
                TextField("E-Mails (durch Komma getrennt)", text: $invited)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                Text("Mehrere E-Mails mit Komma trennen")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button {
                    onCreate(name, invited.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                    dismiss()
                } label: { Text("Gruppe erstellen") }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
}
