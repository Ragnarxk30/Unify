import SwiftUI
import Supabase
import PhotosUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    
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
    
    // Profile Image Service
    @StateObject private var profileImageService = ProfileImageService()
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Profil Section
                Section {
                    if let user = session.currentUser {
                        if isEditingName {
                            EditNameView(
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
                            EditEmailView(
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
                            EditPasswordView(
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
                            ProfileHeaderView(
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
                        ProfilePlaceholderView()
                    }
                }
                
                // MARK: - Erscheinungsbild
                Section("Erscheinungsbild") {
                    AppearancePickerView(
                        appAppearance: $appAppearance,
                        onAppearanceChange: setAppearance
                    )
                }
                
                // MARK: - Abmelden
                Section {
                    Button(role: .destructive) {
                        Task {
                            do {
                                try await SupabaseAuthRepository().signOut()
                                await MainActor.run { session.markSignedOut() }
                                alertMessage = SettingsAlertMessage.signOutSuccess
                            } catch {
                                alertMessage = SettingsAlertMessage.signOutError(error)
                            }
                        }
                    } label: {
                        Text("Abmelden")
                    }
                }
                
                // MARK: - Account löschen
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Account löschen")
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden dauerhaft gelöscht.")
                        .font(.caption)
                }
            }
            .navigationTitle("Einstellungen")
            .alert("Ergebnis", isPresented: .constant(alertMessage != nil)) {
                Button("OK") { alertMessage = nil }
            } message: {
                if let message = alertMessage {
                    Text(message)
                }
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
            .task {
                await checkProfilePictureStatus()
            }
        }
    }
    
    // MARK: - Account sofort löschen
    private func deleteAccount() async {
        await MainActor.run {
            isDeletingAccount = true
        }
        
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
                alertMessage = SettingsAlertMessage.deleteAccountError(error)
            }
            print("❌ Delete account error: \(error)")
        }
    }
    
    // MARK: - Profilbild Funktionen
    private func checkProfilePictureStatus() async {
        do {
            let exists = try await profileImageService.checkProfilePictureExists()
            await MainActor.run {
                hasProfileImage = exists
            }
            
            if exists {
                await loadProfilePicture()
            }
        } catch {
            print("❌ Check profile picture error: \(error)")
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
            print("❌ Load profile picture error: \(error)")
            await MainActor.run {
                hasProfileImage = false
                profileImage = nil
            }
        }
    }
    
    private func uploadProfileImage(_ imageData: Data) async {
        guard let uiImage = UIImage(data: imageData) else {
            await MainActor.run {
                alertMessage = SettingsAlertMessage.imageProcessingError
            }
            return
        }
        
        await MainActor.run {
            isUploadingImage = true
        }
        
        do {
            let avatarURL = try await profileImageService.uploadProfilePicture(uiImage)
            try await updateUserProfileWithAvatar(avatarURL)
            
            await MainActor.run {
                profileImage = uiImage
                hasProfileImage = true
                isUploadingImage = false
                alertMessage = SettingsAlertMessage.profileImageUpdated
            }
            
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = SettingsAlertMessage.profileImageUploadError(error)
            }
        }
    }
    
    private func deleteProfileImage() async {
        await MainActor.run {
            isUploadingImage = true
        }
        
        do {
            try await profileImageService.deleteProfilePicture()
            try await updateUserProfileWithAvatar("")
            
            await MainActor.run {
                profileImage = nil
                hasProfileImage = false
                isUploadingImage = false
                alertMessage = SettingsAlertMessage.profileImageDeleted
            }
            
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = SettingsAlertMessage.profileImageDeleteError(error)
            }
        }
    }
    
    private func updateUserProfileWithAvatar(_ avatarURL: String) async throws {
        guard let userId = session.currentUser?.id else { return }
        
        let updateData = ["avatar_url": avatarURL]
        
        try await supabase
            .from("user")
            .update(updateData)
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
            struct UpdatePayload: Encodable {
                let display_name: String
            }
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
                alertMessage = SettingsAlertMessage.displayNameUpdated
            }
        } catch {
            await MainActor.run {
                isSavingName = false
                alertMessage = SettingsAlertMessage.displayNameError(error)
            }
        }
    }
    
    // MARK: - Email ändern
    private func changeEmail() async {
        let newEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newEmail.isEmpty, newEmail != session.currentUser?.email else { return }
        
        guard EmailValidator.isValid(newEmail) else {
            await MainActor.run {
                alertMessage = SettingsAlertMessage.invalidEmail
            }
            return
        }
        
        await MainActor.run { isSavingEmail = true }
        
        do {
            let authService = AuthService()
            try await authService.changeEmail(newEmail: newEmail)
            
            await MainActor.run {
                isSavingEmail = false
                isEditingEmail = false
                alertMessage = SettingsAlertMessage.emailChanged(newEmail)
            }
        } catch {
            await MainActor.run {
                isSavingEmail = false
                alertMessage = SettingsAlertMessage.emailChangeError(error)
            }
        }
    }
    
    // MARK: - Passwort ändern
    private func changePassword() async {
        guard !newPassword.isEmpty, newPassword == confirmPassword else { return }
        guard newPassword.count >= 6 else { return }
        
        await MainActor.run {
            isChangingPassword = true
        }
        
        do {
            let authService = AuthService()
            try await authService.changePassword(newPassword: newPassword)
            
            await MainActor.run {
                isChangingPassword = false
                isEditingPassword = false
                newPassword = ""
                confirmPassword = ""
                alertMessage = SettingsAlertMessage.passwordChanged
            }
            
        } catch {
            await MainActor.run {
                isChangingPassword = false
                alertMessage = SettingsAlertMessage.passwordChangeError(error)
            }
        }
    }
    
    // MARK: - Appearance
    private func setAppearance(_ style: UIUserInterfaceStyle) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.windows.forEach { window in
            window.overrideUserInterfaceStyle = style
        }
    }
}

// MARK: - Alert Messages
private enum SettingsAlertMessage {
    static let signOutSuccess = "✅ Erfolgreich abgemeldet."
    static func signOutError(_ error: Error) -> String {
        "❌ Abmelden fehlgeschlagen: \(error.localizedDescription)"
    }
    static func deleteAccountError(_ error: Error) -> String {
        "❌ Account-Löschung fehlgeschlagen: \(error.localizedDescription)"
    }
    static let imageProcessingError = "❌ Bild konnte nicht verarbeitet werden"
    static let profileImageUpdated = "✅ Profilbild erfolgreich aktualisiert"
    static func profileImageUploadError(_ error: Error) -> String {
        "❌ Profilbild konnte nicht hochgeladen werden: \(error.localizedDescription)"
    }
    static let profileImageDeleted = "✅ Profilbild erfolgreich gelöscht"
    static func profileImageDeleteError(_ error: Error) -> String {
        "❌ Profilbild konnte nicht gelöscht werden: \(error.localizedDescription)"
    }
    static let displayNameUpdated = "✅ Benutzername aktualisiert."
    static func displayNameError(_ error: Error) -> String {
        "❌ Konnte Benutzername nicht speichern: \(error.localizedDescription)"
    }
    static let invalidEmail = "❌ Bitte gib eine gültige E-Mail-Adresse ein."
    static func emailChanged(_ email: String) -> String {
        "✅ E-Mail wurde zu \(email) geändert"
    }
    static func emailChangeError(_ error: Error) -> String {
        "❌ E-Mail konnte nicht geändert werden: \(error.localizedDescription)"
    }
    static let passwordChanged = "✅ Passwort wurde erfolgreich geändert"
    static func passwordChangeError(_ error: Error) -> String {
        "❌ Passwort konnte nicht geändert werden: \(error.localizedDescription)"
    }
}

// MARK: - Email Validator
private enum EmailValidator {
    static func isValid(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Profile Header View
private struct ProfileHeaderView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ProfileAvatarView(
                    profileImage: profileImage,
                    hasProfileImage: hasProfileImage,
                    isUploadingImage: isUploadingImage,
                    onChangePhoto: onChangePhoto,
                    onDeletePhoto: onDeletePhoto
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.display_name)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ProfileMenuButton(
                    hasProfileImage: hasProfileImage,
                    onEditName: onEditName,
                    onEditEmail: onEditEmail,
                    onChangePassword: onChangePassword,
                    onChangePhoto: onChangePhoto,
                    onDeletePhoto: onDeletePhoto
                )
            }
            
            Divider()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Profile Avatar View
private struct ProfileAvatarView: View {
    let profileImage: UIImage?
    let hasProfileImage: Bool
    let isUploadingImage: Bool
    let onChangePhoto: () -> Void
    let onDeletePhoto: () -> Void
    
    var body: some View {
        Menu {
            Button {
                onChangePhoto()
            } label: {
                Label("Profilbild ändern", systemImage: "photo")
            }
            
            if hasProfileImage {
                Button(role: .destructive) {
                    onDeletePhoto()
                } label: {
                    Label("Profilbild löschen", systemImage: "trash")
                }
            }
        } label: {
            Group {
                if isUploadingImage {
                    ProgressView()
                        .frame(width: 46, height: 46)
                } else if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if hasProfileImage {
                    Image(systemName: "person.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                        .font(.system(size: 40))
                } else {
                    Image("Avatar_Default")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Profile Menu Button
private struct ProfileMenuButton: View {
    let hasProfileImage: Bool
    let onEditName: () -> Void
    let onEditEmail: () -> Void
    let onChangePassword: () -> Void
    let onChangePhoto: () -> Void
    let onDeletePhoto: () -> Void
    
    var body: some View {
        Menu {
            Button {
                onEditName()
            } label: {
                Label("Benutzername bearbeiten", systemImage: "pencil")
            }
            
            Button {
                onChangePassword()
            } label: {
                Label("Passwort ändern", systemImage: "key")
            }
            
            Button {
                onEditEmail()
            } label: {
                Label("E-Mail ändern", systemImage: "envelope")
            }
            
            Button {
                onChangePhoto()
            } label: {
                Label("Profilbild ändern", systemImage: "photo")
            }
            
            if hasProfileImage {
                Button(role: .destructive) {
                    onDeletePhoto()
                } label: {
                    Label("Profilbild löschen", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

// MARK: - Edit Name View
private struct EditNameView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Benutzername bearbeiten")
                .font(.headline)
            
            TextField("Benutzername", text: $editedDisplayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            
            HStack {
                Button("Abbrechen") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(isSavingName)
                
                Spacer()
                
                Button {
                    onSave()
                } label: {
                    if isSavingName {
                        ProgressView().tint(.white)
                    } else {
                        Text("Speichern")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Edit Email View
private struct EditEmailView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("E-Mail ändern")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Aktuelle E-Mail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(currentEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemBackground).opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Neue E-Mail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Neue E-Mail-Adresse", text: $editedEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            
            if !editedEmail.isEmpty && !EmailValidator.isValid(editedEmail) {
                Text("❌ Bitte gib eine gültige E-Mail-Adresse ein")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Abbrechen") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(isSavingEmail)
                
                Spacer()
                
                Button {
                    onSave()
                } label: {
                    if isSavingEmail {
                        ProgressView().tint(.white)
                    } else {
                        Text("Speichern")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Edit Password View
private struct EditPasswordView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Passwort ändern")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            
            Button {
                showPassword.toggle()
            } label: {
                Label(
                    showPassword ? "Passwort verbergen" : "Passwort anzeigen",
                    systemImage: showPassword ? "eye.slash" : "eye"
                )
                .font(.caption)
            }
            
            // Validation Feedback
            VStack(alignment: .leading, spacing: 4) {
                if !newPassword.isEmpty && !isPasswordValid {
                    Text("❌ Passwort muss mindestens 6 Zeichen lang sein")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("❌ Passwörter stimmen nicht überein")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if passwordsMatch && isPasswordValid {
                    Text("✅ Passwörter stimmen überein")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                Button("Abbrechen") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(isChangingPassword)
                
                Spacer()
                
                Button {
                    onSave()
                } label: {
                    if isChangingPassword {
                        ProgressView().tint(.white)
                    } else {
                        Text("Ändern")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Profile Placeholder View
private struct ProfilePlaceholderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle")
                .font(.system(size: 32))
            VStack(alignment: .leading) {
                Text("Angemeldet als")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Lade …")
                    .redacted(reason: .placeholder)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Appearance Picker View
private struct AppearancePickerView: View {
    @Binding var appAppearance: String
    let onAppearanceChange: (UIUserInterfaceStyle) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            appearanceButton(title: "Hell", key: "light", style: .light)
            appearanceButton(title: "Dunkel", key: "dark", style: .dark)
            appearanceButton(title: "System", key: "system", style: .unspecified)
        }
    }
    
    private func appearanceButton(title: String, key: String, style: UIUserInterfaceStyle) -> some View {
        Button {
            appAppearance = key
            onAppearanceChange(style)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(appAppearance == key ? Color.blue : Color(.secondarySystemBackground))
                )
                .foregroundStyle(appAppearance == key ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
