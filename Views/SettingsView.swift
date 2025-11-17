import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    // Speichert die Auswahl persistent 
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var currentUser: AppUser? // ✅ Für den echten Usernamen

    var body: some View {
        Form {
            Section("Profil") {
                if let user = currentUser {
                    // ✅ Echten Usernamen anzeigen
                    Label("Angemeldet als: \(user.display_name)", systemImage: "person.circle")
                } else {
                    Label("Angemeldet als: Lade...", systemImage: "person.circle")
                }
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
                Toggle(isOn: .constant(false)) {
                    Text("Experimentelle Features")
                }
                // ✅ Test-Buttons entfernt
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
        .task {
            // ✅ Beim Erscheinen den aktuellen User laden
            await loadCurrentUser()
        }
    }

    // MARK: - User laden
    @MainActor
    private func loadCurrentUser() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // ✅ User aus der Datenbank laden
            currentUser = try await supabase
                .from("user")
                .select("id, display_name, email")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
        } catch {
            print("❌ Fehler beim Laden des Users: \(error)")
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
