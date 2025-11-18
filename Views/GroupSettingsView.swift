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
    @State private var isAdmin = false
    @State private var errorMessage: String?
    @State private var members: [GroupMember] = []
    @State private var isLoadingMembers = false
    @State private var showAddMember = false
    
    @State private var memberToRemove: GroupMember?
    @State private var showRemoveMemberConfirm = false
    
    // ✅ NEU: Aktuelle User ID speichern
    @State private var currentUserId: UUID?

    private let groupRepo = SupabaseGroupRepository()
    private let authRepo: AuthRepository = SupabaseAuthRepository()

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
                                
                                // ✅ Owner ODER Admin kann Mitglieder entfernen (außer sich selbst und Owner)
                                if (isOwner || isAdmin) && member.user_id != group.owner_id && member.user_id != currentUserId {
                                    Button(role: .destructive) {
                                        memberToRemove = member
                                        showRemoveMemberConfirm = true
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
                    
                    // ✅ Owner ODER Admin kann Mitglieder hinzufügen
                    if isOwner || isAdmin {
                        Button {
                            showAddMember = true
                        } label: {
                            Label("Mitglied hinzufügen", systemImage: "person.badge.plus")
                        }
                    }
                }

                // ✅ NUR Owner kann Gruppe löschen
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
            .confirmationDialog(
                "Mitglied entfernen?",
                isPresented: $showRemoveMemberConfirm,
                titleVisibility: .visible
            ) {
                Button("Mitglied entfernen", role: .destructive) {
                    if let member = memberToRemove {
                        removeMember(member)
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    memberToRemove = nil
                }
            } message: {
                if let member = memberToRemove {
                    Text("Möchtest du \(member.memberUser.display_name) wirklich aus der Gruppe entfernen?")
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView(groupId: group.id) { newMember in
                    Task {
                        await loadMembers()
                    }
                }
            }
            .onAppear {
                Task {
                    await resolveUserRole()
                    await loadMembers()
                }
            }
        }
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }

    // ✅ KORREKTUR: currentUserId wird hier gesetzt
    private func resolveUserRole() async {
        do {
            let uid = try await authRepo.currentUserId()
            
            // Owner-Status prüfen
            let isUserOwner = (uid == group.owner_id)
            
            // Admin-Status prüfen - lade Gruppenmitglieder um Rolle zu checken
            let groupMembers = try await groupRepo.fetchGroupMembers(groupId: group.id)
            let currentUserMember = groupMembers.first { $0.user_id == uid }
            let isUserAdmin = currentUserMember?.role == .admin
            
            await MainActor.run {
                currentUserId = uid // ✅ Hier setzen
                isOwner = isUserOwner
                isAdmin = isUserAdmin
                print("✅ User Rolle: Owner=\(isOwner), Admin=\(isAdmin), UserID=\(uid)")
            }
        } catch {
            await MainActor.run {
                currentUserId = nil
                isOwner = false
                isAdmin = false
            }
        }
    }
    
    // MARK: - Mitglieder laden
    private func loadMembers() async {
        await MainActor.run {
            isLoadingMembers = true
            errorMessage = nil
        }
        
        do {
            let fetchedMembers = try await groupRepo.fetchGroupMembers(groupId: group.id)
            
            await MainActor.run {
                members = fetchedMembers
                isLoadingMembers = false
                print("✅ \(members.count) Mitglieder geladen")
            }
        } catch {
            await MainActor.run {
                isLoadingMembers = false
                setError("Mitglieder konnten nicht geladen werden: \(error.localizedDescription)")
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
                    memberToRemove = nil
                }
            } catch {
                await MainActor.run {
                    setError("Mitglied konnte nicht entfernt werden: \(error.localizedDescription)")
                    memberToRemove = nil
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

// ✅ AddMemberView (bleibt gleich)
struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: UUID
    let onMemberAdded: (GroupMember) -> Void
    
    @State private var email = ""
    @State private var selectedRole: role = .user
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let groupRepo = SupabaseGroupRepository()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("E-Mail Adresse", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isAdding)
                    
                    Picker("Rolle", selection: $selectedRole) {
                        Text("Mitglied").tag(role.user)
                        Text("Admin").tag(role.admin)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isAdding)
                    
                } header: {
                    Text("Mitglied einladen")
                } footer: {
                    Text("Die Person muss bereits einen Account haben.")
                }
                
                if isAdding {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade ein...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                
                if let successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Mitglied hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Einladen") { Task { await inviteMember() } }
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                }
            }
        }
    }
    
    private func inviteMember() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        await MainActor.run {
            errorMessage = nil
            successMessage = nil
            isAdding = true
        }
        
        do {
            try await groupRepo.inviteMember(groupId: groupId, email: trimmedEmail, role: selectedRole)
            
            await MainActor.run {
                successMessage = "✅ \(trimmedEmail) wurde als \(selectedRole.displayName) eingeladen!"
                isAdding = false
                
                let tempMember = GroupMember(
                    user_id: UUID(),
                    group_id: groupId,
                    role: selectedRole,
                    joined_at: Date(),
                    user: AppUser(
                        id: UUID(),
                        display_name: trimmedEmail,
                        email: trimmedEmail
                    )
                )
                onMemberAdded(tempMember)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "❌ Fehler: \(error.localizedDescription)"
                isAdding = false
            }
        }
    }
}
