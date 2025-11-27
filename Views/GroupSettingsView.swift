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
    
    @State private var currentUserId: UUID?
    @State private var showLeaveConfirm = false
    @State private var showOwnerTransferSheet = false
    
    // 👈 NEU: Profilbilder Cache
    @State private var memberProfileImages: [UUID: UIImage] = [:]

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
                Section("Gruppenname") {
                    if isOwner || isAdmin {
                        TextField("Gruppenname", text: $name)
                            .disabled(isSaving)
                    } else {
                        HStack {
                            Text(group.name)
                                .foregroundColor(.secondary)
                        }
                    }
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
                                // 👈 NEU: Profilbild mit Fallback
                                Group {
                                    if let profileImage = memberProfileImages[member.user_id] {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Image("Avatar_Default")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.memberUser.display_name)
                                        .font(.body)
                                    Text(member.role.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
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
                    
                    if isOwner || isAdmin {
                        Button {
                            showAddMember = true
                        } label: {
                            Label("Mitglied hinzufügen", systemImage: "person.badge.plus")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if isOwner {
                            showOwnerTransferSheet = true
                        } else {
                            showLeaveConfirm = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(isOwner ? "Gruppe verlassen & Besitzer transferieren" : "Gruppe verlassen")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    if isOwner {
                        Text("Als Besitzer musst du einen neuen Besitzer auswählen, bevor du die Gruppe verlassen kannst.")
                    } else {
                        Text("Du kannst diese Gruppe jederzeit verlassen.")
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
                
                if isOwner || isAdmin {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { Task { await save() } }
                            .disabled(isSaving || nameTrimmed.isEmpty || nameTrimmed == group.name)
                    }
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
            .confirmationDialog(
                "Gruppe wirklich verlassen?",
                isPresented: $showLeaveConfirm,
                titleVisibility: .visible
            ) {
                Button("Gruppe verlassen", role: .destructive) {
                    Task { await leaveGroup() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Du wirst aus der Gruppe entfernt und kannst nur durch Einladung wieder beitreten.")
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView(groupId: group.id) { newMember in
                    Task {
                        await loadMembers()
                    }
                }
            }
            .sheet(isPresented: $showOwnerTransferSheet) {
                TransferOwnershipView(
                    group: group,
                    members: members,
                    onOwnershipTransferred: {
                        dismiss()
                    }
                )
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

    private func resolveUserRole() async {
        do {
            let uid = try await authRepo.currentUserId()
            
            let isUserOwner = (uid == group.owner_id)
            
            let groupMembers = try await groupRepo.fetchGroupMembers(groupId: group.id)
            let currentUserMember = groupMembers.first { $0.user_id == uid }
            let isUserAdmin = currentUserMember?.role == .admin
            
            await MainActor.run {
                currentUserId = uid
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
            }
            
            // 👈 NEU: Profilbilder für alle Mitglieder laden
            await loadMemberProfileImages()
            
        } catch {
            await MainActor.run {
                isLoadingMembers = false
                setError("Mitglieder konnten nicht geladen werden: \(error.localizedDescription)")
            }
        }
    }
    
    // 👈 NEU: Profilbilder laden
    private func loadMemberProfileImages() async {
        for member in members {
            if let image = await ProfileImageService.shared.getCachedProfileImage(for: member.user_id) {
                await MainActor.run {
                    memberProfileImages[member.user_id] = image
                }
            }
        }
    }

    private func removeMember(_ member: GroupMember) {
        Task {
            do {
                try await groupRepo.removeMember(groupId: group.id, userId: member.user_id)
                await MainActor.run {
                    members.removeAll { $0.user_id == member.user_id }
                    memberProfileImages.removeValue(forKey: member.user_id)
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
    
    private func leaveGroup() async {
        await MainActor.run {
            errorMessage = nil
            isDeleting = true
        }
        
        do {
            try await groupRepo.leaveGroup(groupId: group.id)
            
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                setError("Gruppe verlassen fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
}

extension AppUser {
    var initials: String {
        let comps = display_name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

struct TransferOwnershipView: View {
    @Environment(\.dismiss) private var dismiss
    let group: AppGroup
    let members: [GroupMember]
    let onOwnershipTransferred: () -> Void
    
    @State private var selectedNewOwner: UUID?
    @State private var isTransferring = false
    @State private var errorMessage: String?
    
    // 👈 NEU: Profilbilder
    @State private var memberProfileImages: [UUID: UIImage] = [:]
    
    private let groupRepo = SupabaseGroupRepository()
    
    var availableMembers: [GroupMember] {
        members.filter { $0.user_id != group.owner_id }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if availableMembers.isEmpty {
                        Text("Keine anderen Mitglieder verfügbar")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableMembers) { member in
                            HStack {
                                // 👈 NEU: Profilbild
                                Group {
                                    if let profileImage = memberProfileImages[member.user_id] {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Image("Avatar_Default")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.memberUser.display_name)
                                        .font(.body)
                                    Text(member.role.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedNewOwner == member.user_id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNewOwner = member.user_id
                            }
                        }
                    }
                } header: {
                    Text("Neuen Besitzer auswählen")
                } footer: {
                    Text("Wähle ein Mitglied aus, das die Gruppenverwaltung übernehmen soll.")
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Besitzer transferieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isTransferring)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transferieren") {
                        Task { await transferOwnership() }
                    }
                    .disabled(selectedNewOwner == nil || isTransferring)
                }
            }
            // 👈 NEU: Profilbilder laden
            .task {
                await loadMemberProfileImages()
            }
        }
    }
    
    // 👈 NEU: Profilbilder laden
    private func loadMemberProfileImages() async {
        for member in availableMembers {
            if let image = await ProfileImageService.shared.getCachedProfileImage(for: member.user_id) {
                await MainActor.run {
                    memberProfileImages[member.user_id] = image
                }
            }
        }
    }
    
    private func transferOwnership() async {
        guard let newOwnerId = selectedNewOwner else { return }
        
        await MainActor.run {
            errorMessage = nil
            isTransferring = true
        }
        
        do {
            try await groupRepo.transferOwnership(groupId: group.id, newOwnerId: newOwnerId)
            try await groupRepo.leaveGroup(groupId: group.id)
            
            await MainActor.run {
                isTransferring = false
                onOwnershipTransferred()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isTransferring = false
                errorMessage = "Transfer fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }
}

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: UUID
    let onMemberAdded: (GroupMember) -> Void
    
    @State private var email = ""
    @State private var selectedRole: role = .user
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var shouldAutoDismiss = false
    
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
            .onChange(of: shouldAutoDismiss) { oldValue, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func inviteMember() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        await MainActor.run {
            errorMessage = nil
            successMessage = nil
            shouldAutoDismiss = false
            isAdding = true
        }
        
        do {
            try await groupRepo.inviteMember(groupId: groupId, email: trimmedEmail, role: selectedRole)
            
            await MainActor.run {
                successMessage = "✅ \(trimmedEmail) wurde als \(selectedRole.displayName) eingeladen!"
                isAdding = false
                shouldAutoDismiss = true
                
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
            
        } catch {
            await MainActor.run {
                errorMessage = "❌ Fehler: \(error.localizedDescription)"
                isAdding = false
                shouldAutoDismiss = false
            }
        }
    }
}
