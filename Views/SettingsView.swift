import SwiftUI
import Supabase
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore

    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var isLoading = false
    @State private var alertMessage: String?
    
    // Status für Platzhalteranzeige, aber künftig an Bilddaten gekoppelt
    @State private var hasProfileImage = true

    // Editing state
    @State private var isEditingName = false
    @State private var editedDisplayName: String = ""
    @State private var isSavingName = false

    @State private var isEditingEmail = false
    @State private var editedEmail: String = ""
    @State private var isSavingEmail = false

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedProfileImageData: Data?

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
                        } else if isEditingEmail {
                            // Bearbeiten E-Mail
                            VStack(alignment: .leading, spacing: 12) {
                                Text("E-Mail bearbeiten")
                                    .font(.headline)

                                TextField("E-Mail", text: $editedEmail)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled(true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )

                                HStack {
                                    Button("Abbrechen") {
                                        isEditingEmail = false
                                        editedEmail = user.email
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSavingEmail)

                                    Spacer()

                                    Button {
                                        Task { await saveEmail() }
                                    } label: {
                                        if isSavingEmail {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Speichern")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(
                                        isSavingEmail ||
                                        editedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                        editedEmail == user.email
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
                                    // Immer als Menu anzeigen, egal ob Bild vorhanden
                                    Menu {
                                        Button {
                                            showPhotoPicker = true
                                        } label: {
                                            Label("Profilbild ändern", systemImage: "photo")
                                        }
                                        
                                        if selectedProfileImageData != nil || hasProfileImage {
                                            Button(role: .destructive) {
                                                removeProfileImage()
                                            } label: {
                                                Label("Profilbild löschen", systemImage: "trash")
                                            }
                                        }
                                    } label: {
                                        Group {
                                            if let data = selectedProfileImageData, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else {
                                                Image(systemName: hasProfileImage ? "person.circle.fill" : "person.crop.circle.badge.xmark")
                                                    .symbolRenderingMode(.hierarchical)
                                                    .foregroundStyle(hasProfileImage ? .blue : .red)
                                                    .font(.system(size: 40))
                                            }
                                        }
                                        .frame(width: 46, height: 46)
                                        .clipShape(Circle())
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

                                        Button {
                                            editedEmail = user.email
                                            isEditingEmail = true
                                        } label: {
                                            Label("E-Mail aktualisieren", systemImage: "envelope")
                                        }

                                        Button {
                                            showPhotoPicker = true
                                        } label: {
                                            Label("Profilbild ändern", systemImage: "photo")
                                        }
                                        
                                        if selectedProfileImageData != nil || hasProfileImage {
                                            Button(role: .destructive) {
                                                removeProfileImage()
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
            }
            .navigationTitle("Einstellungen")
            .alert("Ergebnis", isPresented: .constant(alertMessage != nil)) {
                Button("OK") { alertMessage = nil }
            } message: {
                if let message = alertMessage {
                    Text(message)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedProfileImageData = data
                            hasProfileImage = data.isEmpty == false
                        }
                    }
                }
            }
        }
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

    // MARK: - E-Mail speichern
    func saveEmail() async {
        guard let current = session.currentUser else { return }
        let trimmed = editedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != current.email else { return }

        await MainActor.run { isSavingEmail = true }
        do {
            struct UpdatePayload: Encodable { let email: String }
            _ = try await supabase
                .from("user")
                .update(UpdatePayload(email: trimmed))
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
                isSavingEmail = false
                isEditingEmail = false
                alertMessage = "✅ E-Mail aktualisiert."
            }
        } catch {
            await MainActor.run {
                isSavingEmail = false
                alertMessage = "❌ Konnte E-Mail nicht speichern: \(error.localizedDescription)"
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
    
    private func removeProfileImage() {
        selectedProfileImageData = nil
        hasProfileImage = false
        alertMessage = "✅ Profilbild gelöscht."
    }
}
