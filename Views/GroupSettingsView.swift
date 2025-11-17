import SwiftUI

struct GroupSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let group: AppGroup
    let onUpdated: (AppGroup) -> Void

    @State private var name: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var isOwner = false
    @State private var errorMessage: String?
    @State private var members: [GroupMember] = []
    @State private var isLoadingMembers = false
    @State private var showAddMember = false

    private let groupRepo = SupabaseGroupRepository()
    private let authRepo: AuthRepository = SupabaseAuthRepository()

    // ✅ Computed Property an der richtigen Stelle
    private var nameTrimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(group: AppGroup, onUpdated: @escaping (AppGroup) -> Void) {
        self.group = group
        self.onUpdated = onUpdated
        _name = State(initialValue: group.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Gruppenname", text: $name)
                        .disabled(isSaving)
                }

                // ✅ Mitgliederverwaltung
                Section("Mitglieder") {
                    if isLoadingMembers {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade Mitglieder...")
                                .foregroundStyle(.secondary)
                        }
                    } else if members.isEmpty {
                        Text("Noch keine Mitglieder")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(members) { member in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(member.memberUser.initials)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.memberUser.display_name)
                                        .font(.body)
                                    Text(member.role.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // ✅ Owner kann Mitglieder entfernen (außer sich selbst)
                                if isOwner && member.user_id != group.owner_id {
                                    Button(role: .destructive) {
                                        removeMember(member)
                                    } label: {
                                        Image(systemName: "person.fill.xmark")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if isOwner {
                        Button {
                            showAddMember = true
                        } label: {
                            Label("Mitglied hinzufügen", systemImage: "person.badge.plus")
                        }
                    }
                }

                if isOwner {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Gruppe löschen", systemImage: "trash")
                        }
                        .disabled(isDeleting)
                    } footer: {
                        Text("Nur der Besitzer kann die Gruppe löschen.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Gruppeneinstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isSaving || isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { Task { await save() } }
                        .disabled(isSaving || nameTrimmed.isEmpty || nameTrimmed == group.name)
                }
            }
            .confirmationDialog(
                "Gruppe wirklich löschen?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Gruppe löschen", role: .destructive) {
                    Task { await deleteGroup() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView(groupId: group.id) { newMember in
                    // Mitglied wurde hinzugefügt - Liste aktualisieren
                    Task {
                        await loadMembers()
                    }
                }
            }
            .onAppear {
                Task {
                    await resolveOwnership()
                    await loadMembers()
                }
            }
        }
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }

    private func resolveOwnership() async {
        do {
            let uid = try await authRepo.currentUserId()
            await MainActor.run {
                isOwner = (uid == group.owner_id)
            }
        } catch {
            await MainActor.run {
                isOwner = false
            }
        }
    }
    
    // MARK: - Mitglieder laden
    private func loadMembers() async {
        await MainActor.run {
            isLoadingMembers = true
            errorMessage = nil
            print("🔄 Starte loadMembers für Gruppe \(group.id)")
        }
        
        do {
            print("🔍 Rufe fetchGroupMembers auf...")
            let fetchedMembers = try await groupRepo.fetchGroupMembers(groupId: group.id)
            
            await MainActor.run {
                members = fetchedMembers
                isLoadingMembers = false
                print("✅ \(members.count) Mitglieder geladen")
                
                // Debug: Zeige alle geladenen Mitglieder
                for member in members {
                    print("   👤 \(member.memberUser.display_name) - \(member.role.rawValue)")
                }
            }
        } catch {
            await MainActor.run {
                isLoadingMembers = false
                let errorMsg = "Mitglieder konnten nicht geladen werden: \(error.localizedDescription)"
                setError(errorMsg)
                print("❌ \(errorMsg)")
                print("🔍 Full Error: \(error)")
            }
        }
    }

    // MARK: - Mitglied entfernen
    private func removeMember(_ member: GroupMember) {
        Task {
            do {
                try await groupRepo.removeMember(groupId: group.id, userId: member.user_id)
                await MainActor.run {
                    members.removeAll { $0.user_id == member.user_id }
                }
            } catch {
                await MainActor.run {
                    setError("Mitglied konnte nicht entfernt werden: \(error.localizedDescription)")
                }
            }
        }
    }

    private func save() async {
        guard !nameTrimmed.isEmpty, nameTrimmed != group.name else { return }
        await MainActor.run {
            errorMessage = nil
            isSaving = true
        }
        do {
            try await groupRepo.rename(groupId: group.id, to: nameTrimmed)
            let updated = AppGroup(id: group.id, name: nameTrimmed, owner_id: group.owner_id, user: group.user)
            await MainActor.run {
                onUpdated(updated)
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                setError("Konnte nicht speichern: \(error.localizedDescription)")
            }
        }
    }

    private func deleteGroup() async {
        await MainActor.run {
            errorMessage = nil
            isDeleting = true
        }
        do {
            try await groupRepo.delete(groupId: group.id)
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                setError("Löschen fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
}

// ✅ Extension für Initials
extension AppUser {
    var initials: String {
        let comps = display_name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// ✅ AddMemberView (vereinfacht)
struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: UUID
    let onMemberAdded: (GroupMember) -> Void
    
    @State private var email = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private let groupRepo = SupabaseGroupRepository()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("E-Mail Adresse", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Text("Mitglied einladen")
                } footer: {
                    Text("Die Person muss bereits einen Account haben.")
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Mitglied hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { Task { await addMember() } }
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                }
            }
        }
    }
    
    private func addMember() async {
        // Hier müsstest du die Logik implementieren um User per E-Mail zu finden und hinzuzufügen
        // Das ist komplexer und erfordert zusätzliche Endpoints
    }
}
