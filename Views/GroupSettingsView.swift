import SwiftUI
import PhotosUI

// MARK: - GroupSettingsView
struct GroupSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let group: AppGroup
    let onUpdated: (AppGroup) -> Void
    let onGroupDeleted: (() -> Void)?
    
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
    
    @State private var memberProfileImages: [UUID: UIImage] = [:]
    
    // ⭐ NUR DIESE 4 ZEILEN NEU ⭐
    @State private var selectedProfileImage: UIImage?
    @State private var selectedUserName: String?
    @State private var showProfileImageViewer = false
    @State private var selectedUserId: UUID?

    // Gruppenbild State
    @State private var groupImage: UIImage?
    @State private var groupImageCircle: UIImage?  // Zugeschnittener Circle-Ausschnitt
    @State private var hasGroupImage = false
    @State private var isUploadingGroupImage = false
    @State private var showGroupPhotoPicker = false
    @State private var groupPhotoPickerItem: PhotosPickerItem?

    // Gruppenbild Viewer State
    @State private var showGroupImageViewer = false

    // Image Cropper State
    @State private var showImageCropper = false
    @State private var imageToCrop: UIImage?
    
    private let groupRepo = SupabaseGroupRepository()
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    
    private var nameTrimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canEditGroup: Bool {
        isOwner || isAdmin
    }
    
    init(group: AppGroup, onUpdated: @escaping (AppGroup) -> Void, onGroupDeleted: (() -> Void)? = nil) {
        self.group = group
        self.onUpdated = onUpdated
        self.onGroupDeleted = onGroupDeleted
        _name = State(initialValue: group.name)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                groupImageSection
                groupNameSection
                membersSection
                leaveGroupSection
                
                if isOwner {
                    deleteGroupSection
                }
                
                errorSection
            }
            .navigationTitle("Gruppeneinstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isSaving || isDeleting)
                }
                
                if canEditGroup {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { Task { await save() } }
                            .disabled(isSaving || nameTrimmed.isEmpty || nameTrimmed == group.name)
                    }
                }
            }
            .alert("Gruppe wirklich löschen?", isPresented: $showDeleteConfirm) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    Task { await deleteGroup() }
                }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .alert("Mitglied entfernen?", isPresented: $showRemoveMemberConfirm) {
                Button("Abbrechen", role: .cancel) {
                    memberToRemove = nil
                }
                Button("Entfernen", role: .destructive) {
                    if let member = memberToRemove {
                        Task { await removeMember(member) }
                    }
                }
            } message: {
                if let member = memberToRemove {
                    Text("Möchtest du \(member.memberUser.display_name) wirklich aus der Gruppe entfernen?")
                }
            }
            .alert("Gruppe wirklich verlassen?", isPresented: $showLeaveConfirm) {
                Button("Abbrechen", role: .cancel) { }
                Button("Verlassen", role: .destructive) {
                    Task { await leaveGroup() }
                }
            } message: {
                Text("Du wirst aus der Gruppe entfernt und kannst nur durch Einladung wieder beitreten.")
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView(groupId: group.id) {
                    Task { await loadMembers() }
                }
            }
            .sheet(isPresented: $showOwnerTransferSheet) {
                TransferOwnershipView(
                    group: group,
                    members: members,
                    onOwnershipTransferred: {
                        onGroupDeleted?()
                        dismiss()
                    }
                )
            }
            // ⭐ NUR DIESE ZEILEN NEU ⭐
            .fullScreenCover(isPresented: $showProfileImageViewer) {
                ProfileImageViewerSheet(
                    image: $selectedProfileImage,
                    userName: $selectedUserName,
                    userId: $selectedUserId,
                    onDismiss: {
                        showProfileImageViewer = false
                        selectedProfileImage = nil
                        selectedUserName = nil
                        selectedUserId = nil
                    }
                )
            }
            .fullScreenCover(isPresented: $showGroupImageViewer) {
                GroupImageViewerSheet(
                    image: $groupImage,
                    groupName: .constant(name),
                    groupId: .constant(group.id),
                    onDismiss: {
                        showGroupImageViewer = false
                    }
                )
            }
            .photosPicker(isPresented: $showGroupPhotoPicker, selection: $groupPhotoPickerItem, matching: .images)
            .onChange(of: groupPhotoPickerItem) { oldItem, newItem in
                guard let newItem else { return }

                Task {
                    defer {
                        // Picker Item zurücksetzen für nächstes Mal
                        Task { @MainActor in
                            groupPhotoPickerItem = nil
                        }
                    }

                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        print("📸 Neues Foto geladen: \(image.size)")

                        // Cache leeren BEVOR neues Bild gesetzt wird
                        await MainActor.run {
                            GroupImageService.shared.clearCache(for: group.id)
                        }

                        await MainActor.run {
                            imageToCrop = image
                            // Kurze Verzögerung für State-Update
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                                showImageCropper = true
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showImageCropper, content: imageCropperView)
            .task {
                await loadMembersAndResolveRole()
                await checkGroupPictureStatus()
            }
        }
    }
    
    // MARK: - Image Cropper View

    @ViewBuilder
    private func imageCropperView() -> some View {
        if let image = imageToCrop {
            CircleImageCropper(
                image: image,
                onCrop: { [self] fullImage, croppedCircle in
                    showImageCropper = false
                    self.imageToCrop = nil
                    Task {
                        await uploadGroupImages(full: fullImage, circle: croppedCircle)
                    }
                },
                onCancel: { [self] in
                    showImageCropper = false
                    self.imageToCrop = nil
                }
            )
        }
    }

    // MARK: - Sections

    private var groupImageSection: some View {
        Section {
            HStack {
                Spacer()

                GroupAvatarView(
                    groupName: name,
                    groupImage: groupImageCircle ?? groupImage,  // Circle-Ausschnitt für Avatar
                    hasGroupImage: hasGroupImage,
                    isUploadingImage: isUploadingGroupImage,
                    canEdit: canEditGroup,
                    onTap: { showGroupImageViewer = true },
                    onChangePhoto: { showGroupPhotoPicker = true },
                    onDeletePhoto: { Task { await deleteGroupImage() } }
                )

                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }
    
    private var groupNameSection: some View {
        Section("Gruppenname") {
            if canEditGroup {
                TextField("Gruppenname", text: $name)
                    .disabled(isSaving)
            } else {
                Text(group.name)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var membersSection: some View {
        Section("Mitglieder") {
            if isLoadingMembers {
                LoadingRow(text: "Lade Mitglieder...")
            } else if members.isEmpty {
                Text("Noch keine Mitglieder")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(members) { member in
                    // ⭐ NUR onAvatarTap NEU ⭐
                    MemberRowView(
                        member: member,
                        profileImage: memberProfileImages[member.user_id],
                        showRemoveButton: canRemoveMember(member),
                        onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        },
                        onAvatarTap: {
                            selectedProfileImage = memberProfileImages[member.user_id]
                            selectedUserName = member.memberUser.display_name
                            selectedUserId = member.user_id
                            
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                showProfileImageViewer = true
                            }
                        }
                    )
                }
            }
            
            if canEditGroup {
                Button {
                    showAddMember = true
                } label: {
                    Label("Mitglied hinzufügen", systemImage: "person.badge.plus")
                }
            }
        }
    }
    
    private var leaveGroupSection: some View {
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
            Text(isOwner
                 ? "Als Besitzer musst du einen neuen Besitzer auswählen, bevor du die Gruppe verlassen kannst."
                 : "Du kannst diese Gruppe jederzeit verlassen.")
        }
    }
    
    private var deleteGroupSection: some View {
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
    
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Section {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Helper
    
    private func canRemoveMember(_ member: GroupMember) -> Bool {
        canEditGroup &&
        member.user_id != group.owner_id &&
        member.user_id != currentUserId
    }
    
    // MARK: - Data Loading
    
    private func loadMembersAndResolveRole() async {
        await MainActor.run {
            isLoadingMembers = true
            errorMessage = nil
        }
        
        do {
            let uid = try await authRepo.currentUserId()
            let fetchedMembers = try await groupRepo.fetchGroupMembers(groupId: group.id)
            
            let isUserOwner = (uid == group.owner_id)
            let currentUserMember = fetchedMembers.first { $0.user_id == uid }
            let isUserAdmin = currentUserMember?.role == .admin
            
            await MainActor.run {
                currentUserId = uid
                isOwner = isUserOwner
                isAdmin = isUserAdmin
                members = fetchedMembers
                isLoadingMembers = false
            }
            
            await loadMemberProfileImages()
            
        } catch {
            await MainActor.run {
                isLoadingMembers = false
                currentUserId = nil
                isOwner = false
                isAdmin = false
                errorMessage = GroupSettingsError.loadMembersFailed(error).message
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
            
            await loadMemberProfileImages()
            
        } catch {
            await MainActor.run {
                isLoadingMembers = false
                errorMessage = GroupSettingsError.loadMembersFailed(error).message
            }
        }
    }
    
    private func loadMemberProfileImages() async {
        for member in members {
            if let image = await ProfileImageService.shared.getCachedProfileImage(for: member.user_id) {
                await MainActor.run {
                    memberProfileImages[member.user_id] = image
                }
            }
        }
    }
    
    // MARK: - Group Image Functions
    
    private func checkGroupPictureStatus() async {
        do {
            let exists = try await GroupImageService.shared.checkGroupPictureExists(for: group.id)
            await MainActor.run { hasGroupImage = exists }
            if exists { await loadGroupPicture() }
        } catch {
            print("❌ Check group picture error: \(error)")
        }
    }
    
    private func loadGroupPicture() async {
        async let fullImage = GroupImageService.shared.getCachedGroupImage(for: group.id)
        async let circleImage = GroupImageService.shared.getCachedGroupImageCircle(for: group.id)

        let (full, circle) = await (fullImage, circleImage)

        await MainActor.run {
            if let full {
                groupImage = full
                groupImageCircle = circle ?? full  // Fallback zu full wenn kein Circle
                hasGroupImage = true
            }
        }
    }
    
    private func uploadGroupImages(full: UIImage, circle: UIImage) async {
        await MainActor.run { isUploadingGroupImage = true }

        do {
            // 1. ALTE Bilder ZUERST löschen (full + circle)
            print("🗑️ Lösche alte Gruppenbilder...")
            try? await GroupImageService.shared.deleteGroupPicture(for: group.id)
            try? await GroupImageService.shared.deleteGroupPictureCircle(for: group.id)

            // 2. Cache leeren
            GroupImageService.shared.clearCache(for: group.id)

            // 3. NEUE Bilder hochladen
            print("📤 Lade neue Gruppenbilder hoch...")
            _ = try await GroupImageService.shared.uploadGroupPicture(full, for: group.id)
            _ = try await GroupImageService.shared.uploadGroupPictureCircle(circle, for: group.id)

            await MainActor.run {
                // NEUE Bilder direkt setzen (NICHT aus Cache)
                groupImage = full
                groupImageCircle = circle
                hasGroupImage = true
                isUploadingGroupImage = false
            }

            print("✅ Upload erfolgreich - Full: \(full.size), Circle: \(circle.size)")
        } catch {
            await MainActor.run {
                isUploadingGroupImage = false
                errorMessage = "Gruppenbild konnte nicht hochgeladen werden: \(error.localizedDescription)"
            }
            print("❌ Upload fehlgeschlagen: \(error)")
        }
    }
    
    private func deleteGroupImage() async {
        await MainActor.run { isUploadingGroupImage = true }

        do {
            try await GroupImageService.shared.deleteGroupPicture(for: group.id)
            try await GroupImageService.shared.deleteGroupPictureCircle(for: group.id)
            await MainActor.run {
                groupImage = nil
                groupImageCircle = nil
                hasGroupImage = false
                isUploadingGroupImage = false
            }
        } catch {
            await MainActor.run {
                isUploadingGroupImage = false
                errorMessage = "Gruppenbild konnte nicht gelöscht werden: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Actions
    
    private func removeMember(_ member: GroupMember) async {
        do {
            try await groupRepo.removeMember(groupId: group.id, userId: member.user_id)
            await MainActor.run {
                members.removeAll { $0.user_id == member.user_id }
                memberProfileImages.removeValue(forKey: member.user_id)
                memberToRemove = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = GroupSettingsError.removeMemberFailed(error).message
                memberToRemove = nil
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
                errorMessage = GroupSettingsError.saveFailed(error).message
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
                onGroupDeleted?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                errorMessage = GroupSettingsError.deleteFailed(error).message
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
                onGroupDeleted?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                errorMessage = GroupSettingsError.leaveFailed(error).message
            }
        }
    }
}

// MARK: - Error Messages
private enum GroupSettingsError {
    case loadMembersFailed(Error)
    case removeMemberFailed(Error)
    case saveFailed(Error)
    case deleteFailed(Error)
    case leaveFailed(Error)
    case transferFailed(Error)
    case inviteFailed(Error)
    
    var message: String {
        switch self {
        case .loadMembersFailed(let error):
            return "Mitglieder konnten nicht geladen werden: \(error.localizedDescription)"
        case .removeMemberFailed(let error):
            return "Mitglied konnte nicht entfernt werden: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Konnte nicht speichern: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Löschen fehlgeschlagen: \(error.localizedDescription)"
        case .leaveFailed(let error):
            return "Gruppe verlassen fehlgeschlagen: \(error.localizedDescription)"
        case .transferFailed(let error):
            return "Transfer fehlgeschlagen: \(error.localizedDescription)"
        case .inviteFailed(let error):
            return "Fehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - Reusable Components

// MARK: - Group Avatar View
private struct GroupAvatarView: View {
    let groupName: String
    let groupImage: UIImage?
    let hasGroupImage: Bool
    let isUploadingImage: Bool
    let canEdit: Bool
    let onTap: () -> Void
    let onChangePhoto: () -> Void
    let onDeletePhoto: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if canEdit {
                avatarContent
                    .onTapGesture {
                        onTap()
                    }
                    .onLongPressGesture {
                        // Long Press wird über contextMenu gehandhabt
                    }
                    .contextMenu {
                        Button {
                            onChangePhoto()
                        } label: {
                            Label("Gruppenbild ändern", systemImage: "photo")
                        }

                        if hasGroupImage {
                            Button(role: .destructive) {
                                onDeletePhoto()
                            } label: {
                                Label("Gruppenbild löschen", systemImage: "trash")
                            }
                        }
                    }
            } else {
                avatarContent
                    .onTapGesture {
                        onTap()
                    }
            }

            Text(canEdit ? "Tippen zum Ansehen, Lange drücken zum Ändern" : "Tippen zum Ansehen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    private var avatarContent: some View {
        Group {
            if isUploadingImage {
                ProgressView()
                    .frame(width: 80, height: 80)
            } else if let groupImage {
                Image(uiImage: groupImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(String(groupName.prefix(2)).uppercased())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// ⭐ NUR onTap PARAMETER NEU ⭐
private struct MemberAvatarView: View {
    let image: UIImage?
    let onTap: () -> Void
    var size: CGFloat = 36
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image("Avatar_Default")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// ⭐ NUR onAvatarTap PARAMETER NEU ⭐
private struct MemberRowView: View {
    let member: GroupMember
    let profileImage: UIImage?
    let showRemoveButton: Bool
    let onRemove: () -> Void
    let onAvatarTap: () -> Void
    
    var body: some View {
        HStack {
            MemberAvatarView(image: profileImage, onTap: onAvatarTap)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.memberUser.display_name)
                    .font(.body)
                Text(member.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if showRemoveButton {
                Button(role: .destructive) {
                    onRemove()
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

private struct LoadingRow: View {
    let text: String
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - TransferOwnershipView
struct TransferOwnershipView: View {
    @Environment(\.dismiss) private var dismiss
    
    let group: AppGroup
    let members: [GroupMember]
    let onOwnershipTransferred: () -> Void
    
    @State private var selectedNewOwner: UUID?
    @State private var isTransferring = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var memberProfileImages: [UUID: UIImage] = [:]
    
    private let groupRepo = SupabaseGroupRepository()
    
    private var availableMembers: [GroupMember] {
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
                                MemberAvatarView(
                                    image: memberProfileImages[member.user_id],
                                    onTap: { }
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
                
                if let successMessage {
                    Section {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
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
                    Button {
                        Task { await transferOwnership() }
                    } label: {
                        if isTransferring {
                            ProgressView()
                        } else {
                            Text("Transferieren")
                        }
                    }
                    .disabled(selectedNewOwner == nil || isTransferring)
                }
            }
            .task {
                await loadMemberProfileImages()
            }
        }
    }
    
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
            successMessage = nil
            isTransferring = true
        }
        
        do {
            try await groupRepo.transferOwnership(groupId: group.id, newOwnerId: newOwnerId)
            try await groupRepo.leaveGroup(groupId: group.id)
            
            await MainActor.run {
                isTransferring = false
                successMessage = "✅ Besitzer erfolgreich transferiert!"
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                onOwnershipTransferred()
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isTransferring = false
                errorMessage = "❌ Transfer fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - AddMemberView
struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    
    let groupId: UUID
    let onMemberAdded: () -> Void
    
    @State private var email = ""
    @State private var selectedRole: role = .user
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let groupRepo = SupabaseGroupRepository()
    
    private var emailTrimmed: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private var canInvite: Bool {
        !emailTrimmed.isEmpty && !isAdding
    }
    
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
                        LoadingRow(text: "Lade ein...")
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text("❌ \(errorMessage)")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                
                if let successMessage {
                    Section {
                        Text("✅ \(successMessage)")
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
                        .disabled(!canInvite)
                }
            }
        }
    }
    
    private func inviteMember() async {
        await MainActor.run {
            errorMessage = nil
            successMessage = nil
            isAdding = true
        }
        
        do {
            try await groupRepo.inviteMember(groupId: groupId, email: emailTrimmed, role: selectedRole)
            
            await MainActor.run {
                successMessage = "\(emailTrimmed) wurde als \(selectedRole.displayName) eingeladen!"
                isAdding = false
                onMemberAdded()
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = GroupSettingsError.inviteFailed(error).message
                isAdding = false
            }
        }
    }
}
