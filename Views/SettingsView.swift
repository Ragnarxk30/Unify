import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    // Speichert die Auswahl persistent 
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var isLoading = false
    @State private var alertMessage: String?
    
    // Editing state
    @State private var isEditingName = false
    @State private var editedDisplayName: String = ""
    @State private var isSavingName = false

    var body: some View {
        Form {
            // MARK: - Profil
            Section {
                if let user = session.currentUser {
                    if isEditingName {
                        // Bearbeiten
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
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.display_name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            Divider()

                            Button {
                                editedDisplayName = user.display_name
                                isEditingName = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Anzeigename ändern")
                                    Spacer()
                                }
                                .font(.subheadline)
                            }
                            .disabled(isSavingName)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
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
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Profil")
            }
            
            // Darstellungsmodus
            Section("Darstellung") {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        appearanceButton(title: "System", key: "system", style: .unspecified)
                        appearanceButton(title: "Hell",   key: "light",  style: .light)
                        appearanceButton(title: "Dunkel", key: "dark",   style: .dark)
                    }
                }
                .onAppear {
                    applySavedAppearance()
                }
            }
            
            // Hintergünde
            Section("Hintergrund") {
                // Deine Hintergrund-Einstellungen hier
            }

            Section("App") {
                Toggle(isOn: .constant(true)) {
                    Text("Benachrichtigungen")
                }
            }
            
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
    }

    // MARK: - Anzeigename speichern
    private func saveDisplayName() async {
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

    // MARK: - Appearance Methods

    private func appearanceButton(title: String, key: String, style: UIUserInterfaceStyle) -> some View {
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

    private func applySavedAppearance() {
        switch appAppearance {
        case "light": setAppearance(.light)
        case "dark":  setAppearance(.dark)
        default:      setAppearance(.unspecified)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
}
