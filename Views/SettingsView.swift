import SwiftUI
import Supabase
import PhotosUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.scenePhase) var scenePhase

    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var alertMessage: String?

    // Profilbild State
    @State private var hasProfileImage = false
    @State private var profileImage: UIImage?

    // Editing state
    @State private var isEditingName = false
    @State private var editedDisplayName: String = ""
    @State private var isSavingName = false

    // Email ändern
    @State private var isEditingEmail = false
    @State private var editedEmail: String = ""
    @State private var isSavingEmail = false

    // Passwort ändern
    @State private var isEditingPassword = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedProfileImageData: Data?
    @State private var isUploadingImage = false

    // Account Löschen
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false

    // Abmelden
    @State private var showSignOutConfirm = false

    // Profile Image Service
    @StateObject private var profileImageService = ProfileImageService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Profil Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profil")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        if let user = session.currentUser {
                            if isEditingName {
                                EditNameCard(
                                    editedDisplayName: $editedDisplayName,
                                    isSavingName: isSavingName,
                                    currentName: user.display_name,
                                    onCancel: {
                                        isEditingName = false
                                        editedDisplayName = user.display_name
                                    },
                                    onSave: { Task { await saveDisplayName() } }
                                )
                            } else if isEditingEmail {
                                EditEmailCard(
                                    editedEmail: $editedEmail,
                                    isSavingEmail: isSavingEmail,
                                    currentEmail: user.email,
                                    onCancel: {
                                        isEditingEmail = false
                                        editedEmail = user.email
                                    },
                                    onSave: { Task { await changeEmail() } }
                                )
                            } else if isEditingPassword {
                                EditPasswordCard(
                                    newPassword: $newPassword,
                                    confirmPassword: $confirmPassword,
                                    isChangingPassword: isChangingPassword,
                                    onCancel: {
                                        isEditingPassword = false
                                        newPassword = ""
                                        confirmPassword = ""
                                    },
                                    onSave: { Task { await changePassword() } }
                                )
                            } else {
                                ProfileRow(
                                    user: user,
                                    profileImage: profileImage,
                                    hasProfileImage: hasProfileImage,
                                    isUploadingImage: isUploadingImage,
                                    onEditName: {
                                        editedDisplayName = user.display_name
                                        isEditingName = true
                                    },
                                    onEditEmail: {
                                        editedEmail = user.email
                                        isEditingEmail = true
                                    },
                                    onChangePassword: {
                                        newPassword = ""
                                        confirmPassword = ""
                                        isEditingPassword = true
                                    },
                                    onChangePhoto: {
                                        showPhotoPicker = true
                                    },
                                    onDeletePhoto: {
                                        Task { await deleteProfileImage() }
                                    }
                                )
                            }
                        } else {
                            ProfilePlaceholderRow()
                        }
                    }

                    // MARK: - Erscheinungsbild
                    AppearanceRow(
                        appAppearance: $appAppearance,
                        onAppearanceChange: setAppearance
                    )

                    // MARK: - Abmelden
                    ActionRow(
                        title: "Abmelden",
                        icon: "rectangle.portrait.and.arrow.right",
                        color: .red
                    ) {
                        showSignOutConfirm = true
                    }

                    // MARK: - Account löschen
                    VStack(alignment: .leading, spacing: 8) {
                        ActionRow(
                            title: "Account löschen",
                            icon: "trash",
                            color: .red,
                            isLoading: isDeletingAccount
                        ) {
                            showDeleteAccountConfirm = true
                        }
                        .disabled(isDeletingAccount)

                        Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden dauerhaft gelöscht.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Einstellungen")
            .alert("Hinweis", isPresented: .constant(alertMessage != nil)) {
                Button("OK") { alertMessage = nil }
            } message: {
                if let message = alertMessage {
                    Text(message)
                }
            }
            .confirmationDialog(
                "Wirklich abmelden?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Abmelden", role: .destructive) {
                    Task {
                        do {
                            try await SupabaseAuthRepository().signOut()
                            await MainActor.run { session.markSignedOut() }
                        } catch {
                            alertMessage = "Abmelden fehlgeschlagen: \(error.localizedDescription)"
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Du wirst von deinem Account abgemeldet.")
            }
            .confirmationDialog(
                "Account wirklich löschen?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Account löschen", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Gruppen, Nachrichten und Daten werden dauerhaft gelöscht.")
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedProfileImageData = data
                        }
                        await uploadProfileImage(data)
                    }
                }
            }
            .task(id: scenePhase) {
                if scenePhase == .active {
                    await checkProfilePictureStatus()
                }
            }
        }
    }

    // MARK: - Account löschen
    private func deleteAccount() async {
        await MainActor.run { isDeletingAccount = true }

        do {
            let authService = AuthService()
            try await authService.deleteAccountImmediately()
            await MainActor.run {
                isDeletingAccount = false
                session.markSignedOut()
            }
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                alertMessage = "Account-Löschung fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Profilbild Funktionen
    private func checkProfilePictureStatus() async {
        guard !Task.isCancelled else { return }

        do {
            let exists = try await profileImageService.checkProfilePictureExists()
            guard !Task.isCancelled else { return }
            await MainActor.run { hasProfileImage = exists }
            if exists { await loadProfilePicture() }
        } catch {
            if (error as NSError).code != NSURLErrorCancelled {
                print("❌ Check profile picture error: \(error)")
            }
        }
    }

    private func loadProfilePicture() async {
        do {
            let imageData = try await profileImageService.downloadProfilePicture()
            await MainActor.run {
                profileImage = UIImage(data: imageData)
                hasProfileImage = true
            }
        } catch {
            await MainActor.run {
                hasProfileImage = false
                profileImage = nil
            }
        }
    }

    private func uploadProfileImage(_ imageData: Data) async {
        guard let uiImage = UIImage(data: imageData) else {
            await MainActor.run { alertMessage = "Bild konnte nicht verarbeitet werden" }
            return
        }

        await MainActor.run { isUploadingImage = true }

        do {
            let avatarURL = try await profileImageService.uploadProfilePicture(uiImage)
            try await updateUserProfileWithAvatar(avatarURL)
            await MainActor.run {
                profileImage = uiImage
                hasProfileImage = true
                isUploadingImage = false
            }
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = "Profilbild konnte nicht hochgeladen werden"
            }
        }
    }

    private func deleteProfileImage() async {
        await MainActor.run { isUploadingImage = true }

        do {
            try await profileImageService.deleteProfilePicture()
            try await updateUserProfileWithAvatar("")
            await MainActor.run {
                profileImage = nil
                hasProfileImage = false
                isUploadingImage = false
            }
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = "Profilbild konnte nicht gelöscht werden"
            }
        }
    }

    private func updateUserProfileWithAvatar(_ avatarURL: String) async throws {
        guard let userId = session.currentUser?.id else { return }
        try await supabase
            .from("user")
            .update(["avatar_url": avatarURL])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Anzeigename speichern
    func saveDisplayName() async {
        guard let current = session.currentUser else { return }
        let newName = editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != current.display_name else { return }

        await MainActor.run { isSavingName = true }
        do {
            struct UpdatePayload: Encodable { let display_name: String }
            _ = try await supabase
                .from("user")
                .update(UpdatePayload(display_name: newName))
                .eq("id", value: current.id.uuidString)
                .select("id, display_name, email")
                .single()
                .execute() as PostgrestResponse<AppUser>

            let refreshed: AppUser = try await supabase
                .from("user")
                .select("id, display_name, email")
                .eq("id", value: current.id.uuidString)
                .single()
                .execute()
                .value

            await MainActor.run {
                session.setCurrentUser(refreshed)
                isSavingName = false
                isEditingName = false
            }
        } catch {
            await MainActor.run {
                isSavingName = false
                alertMessage = "Konnte Benutzername nicht speichern"
            }
        }
    }

    // MARK: - Email ändern
    private func changeEmail() async {
        let newEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newEmail.isEmpty, newEmail != session.currentUser?.email else { return }
        guard EmailValidator.isValid(newEmail) else {
            await MainActor.run { alertMessage = "Bitte gib eine gültige E-Mail-Adresse ein" }
            return
        }

        await MainActor.run { isSavingEmail = true }

        do {
            try await AuthService().changeEmail(newEmail: newEmail)
            await MainActor.run {
                isSavingEmail = false
                isEditingEmail = false
                alertMessage = "E-Mail wurde zu \(newEmail) geändert"
            }
        } catch {
            await MainActor.run {
                isSavingEmail = false
                alertMessage = "E-Mail konnte nicht geändert werden"
            }
        }
    }

    // MARK: - Passwort ändern
    private func changePassword() async {
        guard !newPassword.isEmpty, newPassword == confirmPassword, newPassword.count >= 6 else { return }

        await MainActor.run { isChangingPassword = true }

        do {
            try await AuthService().changePassword(newPassword: newPassword)
            await MainActor.run {
                isChangingPassword = false
                isEditingPassword = false
                newPassword = ""
                confirmPassword = ""
                alertMessage = "Passwort wurde erfolgreich geändert"
            }
        } catch {
            await MainActor.run {
                isChangingPassword = false
                alertMessage = "Passwort konnte nicht geändert werden"
            }
        }
    }

    // MARK: - Appearance
    private func setAppearance(_ style: UIUserInterfaceStyle) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.windows.forEach { $0.overrideUserInterfaceStyle = style }
    }
}

// MARK: - Email Validator
private enum EmailValidator {
    static func isValid(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Profile Row
private struct ProfileRow: View {
    let user: AppUser
    let profileImage: UIImage?
    let hasProfileImage: Bool
    let isUploadingImage: Bool
    let onEditName: () -> Void
    let onEditEmail: () -> Void
    let onChangePassword: () -> Void
    let onChangePhoto: () -> Void
    let onDeletePhoto: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Menu {
                Button { onChangePhoto() } label: {
                    Label("Profilbild ändern", systemImage: "photo")
                }
                if hasProfileImage {
                    Button(role: .destructive) { onDeletePhoto() } label: {
                        Label("Profilbild löschen", systemImage: "trash")
                    }
                }
            } label: {
                Group {
                    if isUploadingImage {
                        ProgressView()
                            .frame(width: 52, height: 52)
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
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
                            Text(String(user.display_name.prefix(2)).uppercased())
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.display_name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Settings Menu
            Menu {
                Button { onEditName() } label: {
                    Label("Benutzername bearbeiten", systemImage: "pencil")
                }
                Button { onChangePassword() } label: {
                    Label("Passwort ändern", systemImage: "key")
                }
                Button { onEditEmail() } label: {
                    Label("E-Mail ändern", systemImage: "envelope")
                }
                Divider()
                Button { onChangePhoto() } label: {
                    Label("Profilbild ändern", systemImage: "photo")
                }
                if hasProfileImage {
                    Button(role: .destructive) { onDeletePhoto() } label: {
                        Label("Profilbild löschen", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Profile Placeholder Row
private struct ProfilePlaceholderRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 150, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .redacted(reason: .placeholder)
    }
}

// MARK: - Appearance Row
private struct AppearanceRow: View {
    @Binding var appAppearance: String
    let onAppearanceChange: (UIUserInterfaceStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erscheinungsbild")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                AppearanceButton(
                    icon: "sun.max.fill",
                    title: "Hell",
                    isSelected: appAppearance == "light"
                ) {
                    appAppearance = "light"
                    onAppearanceChange(.light)
                }

                AppearanceButton(
                    icon: "moon.fill",
                    title: "Dunkel",
                    isSelected: appAppearance == "dark"
                ) {
                    appAppearance = "dark"
                    onAppearanceChange(.dark)
                }

                AppearanceButton(
                    icon: "gear",
                    title: "System",
                    isSelected: appAppearance == "system"
                ) {
                    appAppearance = "system"
                    onAppearanceChange(.unspecified)
                }
            }
        }
    }
}

// MARK: - Appearance Button
private struct AppearanceButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.primary : Color(.tertiarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Row
private struct ActionRow: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Name Card
private struct EditNameCard: View {
    @Binding var editedDisplayName: String
    let isSavingName: Bool
    let currentName: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isSavingName &&
        !editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editedDisplayName != currentName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Benutzername bearbeiten")
                .font(.subheadline.weight(.semibold))

            TextField("Benutzername", text: $editedDisplayName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                Button("Abbrechen") { onCancel() }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(isSavingName)

                Button { onSave() } label: {
                    Group {
                        if isSavingName {
                            ProgressView().tint(.white)
                        } else {
                            Text("Speichern")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canSave ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canSave)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Edit Email Card
private struct EditEmailCard: View {
    @Binding var editedEmail: String
    let isSavingEmail: Bool
    let currentEmail: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isSavingEmail &&
        !editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editedEmail.lowercased() != currentEmail.lowercased() &&
        EmailValidator.isValid(editedEmail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("E-Mail ändern")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Aktuelle E-Mail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Neue E-Mail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Neue E-Mail-Adresse", text: $editedEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !editedEmail.isEmpty && !EmailValidator.isValid(editedEmail) {
                Text("Bitte gib eine gültige E-Mail-Adresse ein")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 10) {
                Button("Abbrechen") { onCancel() }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(isSavingEmail)

                Button { onSave() } label: {
                    Group {
                        if isSavingEmail {
                            ProgressView().tint(.white)
                        } else {
                            Text("Speichern")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canSave ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canSave)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Edit Password Card
private struct EditPasswordCard: View {
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    let isChangingPassword: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var showPassword = false

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var isPasswordValid: Bool {
        newPassword.count >= 6
    }

    private var canSave: Bool {
        !isChangingPassword && passwordsMatch && isPasswordValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Passwort ändern")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Neues Passwort")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Group {
                    if showPassword {
                        TextField("Neues Passwort", text: $newPassword)
                    } else {
                        SecureField("Neues Passwort", text: $newPassword)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort bestätigen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Group {
                    if showPassword {
                        TextField("Passwort bestätigen", text: $confirmPassword)
                    } else {
                        SecureField("Passwort bestätigen", text: $confirmPassword)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button {
                showPassword.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                    Text(showPassword ? "Verbergen" : "Anzeigen")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }

            // Validation
            if !newPassword.isEmpty && !isPasswordValid {
                Text("Mindestens 6 Zeichen erforderlich")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwörter stimmen nicht überein")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if passwordsMatch && isPasswordValid {
                Text("Passwörter stimmen überein")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            HStack(spacing: 10) {
                Button("Abbrechen") { onCancel() }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(isChangingPassword)

                Button { onSave() } label: {
                    Group {
                        if isChangingPassword {
                            ProgressView().tint(.white)
                        } else {
                            Text("Ändern")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canSave ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canSave)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
