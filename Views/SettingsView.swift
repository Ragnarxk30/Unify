import SwiftUI
import Supabase
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore

    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var isLoading = false
    @State private var alertMessage: String?
    
    // Profilbild State
    @State private var hasProfileImage = false
    @State private var profileImageURL: String = ""
    @State private var profileImage: UIImage?

    // Editing state
    @State private var isEditingName = false
    @State private var editedDisplayName: String = ""
    @State private var isSavingName = false
    
    // NEU: Email ändern
    @State private var isEditingEmail = false
    @State private var editedEmail: String = ""
    @State private var isSavingEmail = false

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedProfileImageData: Data?
    @State private var isUploadingImage = false
    
    // NEU: Account Löschen
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false

    // Passwort ändern States
    @State private var isChangingPassword = false
    @State private var showChangePasswordSheet = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    
    // Profile Image Service
    @StateObject private var profileImageService = ProfileImageService()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Profil
                Section {
                    if let user = session.currentUser {
                        if isEditingName {
                            // Bearbeiten Anzeigename
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Anzeigename bearbeiten")
                                    .font(.headline)

                                TextField("Anzeigename", text: $editedDisplayName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(false)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )

                                HStack {
                                    Button("Abbrechen") {
                                        isEditingName = false
                                        editedDisplayName = user.display_name
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSavingName)

                                    Spacer()

                                    Button {
                                        Task { await saveDisplayName() }
                                    } label: {
                                        if isSavingName {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Speichern")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(
                                        isSavingName ||
                                        editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                        editedDisplayName == user.display_name
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            // Anzeige
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center, spacing: 12) {
                                    // Avatar mit Asset-Fallback und Upload-Funktionalität
                                    Menu {
                                        Button {
                                            showPhotoPicker = true
                                        } label: {
                                            Label("Profilbild ändern", systemImage: "photo")
                                        }
                                        
                                        if hasProfileImage {
                                            Button(role: .destructive) {
                                                Task { await deleteProfileImage() }
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
                                                // Hochgeladenes Bild
                                                Image(uiImage: profileImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else if hasProfileImage {
                                                // Fallback: System Icon wenn Bild existiert aber nicht geladen
                                                Image(systemName: "person.circle.fill")
                                                    .symbolRenderingMode(.hierarchical)
                                                    .foregroundStyle(.blue)
                                                    .font(.system(size: 40))
                                            } else {
                                                // Asset "Avatar_Default" als Fallback
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

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.display_name)
                                            .font(.headline)
                                        Text(user.email)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Menu {
                                        Button {
                                            editedDisplayName = user.display_name
                                            isEditingName = true
                                        } label: {
                                            Label("Anzeigename bearbeiten", systemImage: "pencil")
                                        }
                                        
                                        // Passwort ändern Button
                                        Button {
                                            showChangePasswordSheet = true
                                        } label: {
                                            Label("Passwort ändern", systemImage: "key")
                                        }
                                        
                                        // NEU: Email ändern
                                        Button {
                                            editedEmail = user.email
                                            isEditingEmail = true
                                        } label: {
                                            Label("E-Mail ändern", systemImage: "envelope")
                                        }

                                        Button {
                                            showPhotoPicker = true
                                        } label: {
                                            Label("Profilbild hochladen", systemImage: "photo")
                                        }
                                        
                                        if hasProfileImage {
                                            Button(role: .destructive) {
                                                Task { await deleteProfileImage() }
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

                                Divider()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        // Placeholder wenn kein currentUser (lädt)
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

                // MARK: - Erscheinungsbild
                Section("Erscheinungsbild") {
                    HStack(spacing: 8) {
                        appearanceButton(title: "Hell", key: "light", style: .light)
                        appearanceButton(title: "Dunkel", key: "dark", style: .dark)
                        appearanceButton(title: "System", key: "system", style: .unspecified)
                    }
                }

                // MARK: - Abmelden
                Section {
                    Button(role: .destructive) {
                        Task {
                            do {
                                try await SupabaseAuthRepository().signOut()
                                await MainActor.run { session.markSignedOut() }
                                alertMessage = "✅ Erfolgreich abgemeldet."
                            } catch {
                                alertMessage = "❌ Abmelden fehlgeschlagen: \(error.localizedDescription)"
                            }
                        }
                    } label: {
                        Text("Abmelden")
                    }
                }
                
                // NEU: Account löschen
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
                    Text("Du erhältst eine Bestätigungsmail bevor dein Account gelöscht wird. Alle deine Daten werden dauerhaft entfernt.")
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
            // NEU: Account Löschen Bestätigung
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
                Text("Du erhältst eine E-Mail zur Bestätigung. Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Gruppen, Nachrichten und Daten werden dauerhaft gelöscht.")
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
            // NEU: Email ändern Sheet
            .sheet(isPresented: $isEditingEmail) {
                ChangeEmailSheet(
                    currentEmail: session.currentUser?.email ?? "",
                    editedEmail: $editedEmail,
                    isSaving: $isSavingEmail,
                    onSave: {
                        await changeEmail()
                    },
                    onCancel: {
                        isEditingEmail = false
                        editedEmail = session.currentUser?.email ?? ""
                    }
                )
                .presentationDetents([.medium])
            }
            // NEU: Passwort ändern Sheet
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet(
                    newPassword: $newPassword,
                    confirmPassword: $confirmPassword,
                    isChanging: $isChangingPassword,
                    onChangePassword: {
                        await changePassword()
                    },
                    onCancel: {
                        showChangePasswordSheet = false
                        newPassword = ""
                        confirmPassword = ""
                    }
                )
                .presentationDetents([.medium])
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
            
            // Sofort löschen ohne Email
            try await authService.deleteAccountImmediately()
            
            await MainActor.run {
                isDeletingAccount = false
                session.markSignedOut()
            }
            
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                alertMessage = "❌ Account-Löschung fehlgeschlagen: \(error.localizedDescription)"
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
                alertMessage = "❌ Bild konnte nicht verarbeitet werden"
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
                alertMessage = "✅ Profilbild erfolgreich aktualisiert"
            }
            
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = "❌ Profilbild konnte nicht hochgeladen werden: \(error.localizedDescription)"
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
                alertMessage = "✅ Profilbild erfolgreich gelöscht"
            }
            
        } catch {
            await MainActor.run {
                isUploadingImage = false
                alertMessage = "❌ Profilbild konnte nicht gelöscht werden: \(error.localizedDescription)"
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
                alertMessage = "✅ Anzeigename aktualisiert."
            }
        } catch {
            await MainActor.run {
                isSavingName = false
                alertMessage = "❌ Konnte Anzeigenamen nicht speichern: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Email ändern (mit deiner SQL Function)
    private func changeEmail() async {
        let newEmail = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newEmail.isEmpty, newEmail != session.currentUser?.email else { return }
        
        // Email-Validierung
        guard newEmail.contains("@"), newEmail.contains(".") else {
            await MainActor.run {
                alertMessage = "❌ Bitte gib eine gültige E-Mail-Adresse ein."
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
                alertMessage = "✅ [AuthService] E-Mail wurde zu \(newEmail) geändert"
            }
        } catch {
            await MainActor.run {
                isSavingEmail = false
                alertMessage = "❌ E-Mail konnte nicht geändert werden: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Passwort ändern (über SQL Function)
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
                showChangePasswordSheet = false
                newPassword = ""
                confirmPassword = ""
                alertMessage = "✅ Passwort wurde erfolgreich geändert"
            }
            
        } catch {
            await MainActor.run {
                isChangingPassword = false
                alertMessage = "❌ Passwort konnte nicht geändert werden: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Appearance Methods
    func appearanceButton(title: String, key: String, style: UIUserInterfaceStyle) -> some View {
        Button {
            appAppearance = key
            setAppearance(style)
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

    private func setAppearance(_ style: UIUserInterfaceStyle) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.windows.forEach { window in
            window.overrideUserInterfaceStyle = style
        }
    }
}

// MARK: - Email ändern Sheet
private struct ChangeEmailSheet: View {
    let currentEmail: String
    @Binding var editedEmail: String
    @Binding var isSaving: Bool
    let onSave: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(currentEmail)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Aktuelle E-Mail")
                }
                
                Section {
                    TextField("Neue E-Mail", text: $editedEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isSaving)
                } header: {
                    Text("Neue E-Mail-Adresse")
                } footer: {
                    Text("email wird sofort geändert und Du erhältst eine Bestätigungsmail.")
                }
            }
            .navigationTitle("E-Mail ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onSave()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Speichern")
                        }
                    }
                    .disabled(
                        isSaving ||
                        editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        editedEmail == currentEmail
                    )
                }
            }
        }
    }
}

// MARK: - Passwort ändern Sheet
private struct ChangePasswordSheet: View {
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    @Binding var isChanging: Bool
    let onChangePassword: () async -> Void
    let onCancel: () -> Void
    
    @State private var showPassword = false
    
    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }
    
    private var isPasswordValid: Bool {
        newPassword.count >= 6
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if showPassword {
                            TextField("Neues Passwort", text: $newPassword)
                            TextField("Passwort bestätigen", text: $confirmPassword)
                        } else {
                            SecureField("Neues Passwort", text: $newPassword)
                            SecureField("Passwort bestätigen", text: $confirmPassword)
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
                    }
                } header: {
                    Text("Neues Passwort")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if !newPassword.isEmpty && !isPasswordValid {
                            Text("❌ Passwort muss mindestens 6 Zeichen lang sein")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("❌ Passwörter stimmen nicht überein")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if passwordsMatch && isPasswordValid {
                            Text("✅ Passwörter stimmen überein")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Passwort ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                    .disabled(isChanging)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onChangePassword()
                        }
                    } label: {
                        if isChanging {
                            ProgressView()
                        } else {
                            Text("Ändern")
                        }
                    }
                    .disabled(isChanging || !passwordsMatch || !isPasswordValid)
                }
            }
        }
    }
}
