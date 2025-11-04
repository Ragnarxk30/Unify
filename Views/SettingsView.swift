import SwiftUI
import Supabase

struct SettingsView: View {
    // Speichert die Auswahl persistent
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var isLoading = false
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section("Profil") {
                Label("Angemeldet als: Ich", systemImage: "person.circle")
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
                
                Button {
                    Task { await testSupabaseInsert() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Insert Test")
                    }
                }
                .disabled(isLoading)
                
                // Optional: SignUp Test Button
                Button {
                    Task { await testSignUp() }
                } label: {
                    Text("SignUp Test")
                }
            }

            Section {
                Button(role: .destructive) {
                    // Abmelden Logik hier
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

    // MARK: - Test Methods
    @MainActor
    private func testSignUp() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let authService = AuthService()
            let randomId = Int.random(in: 1...10000)
            let user = try await authService.signUp(
                email: "testuser\(randomId)@gmail.com",
                password: "SecurePassword123!",
                name: "Test User \(randomId)"  // Wird als display_name gespeichert
            )
            
            alertMessage = "✅ SignUp Erfolg!\nDisplay Name: \(user.display_name)\nID: \(user.id)"
        } catch {
            alertMessage = "❌ Fehler: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    private func testSupabaseInsert() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            // ✅ display_name statt name
            let testUser = AppUser(
                id: UUID(),
                display_name: "TestUser \(Int.random(in: 1...1000))"
            )
            
            try await supabase.from("user")
                .insert(testUser)
                .execute()
            alertMessage = "✅ Erfolg! User in Tabelle eingefügt"
        } catch {
            alertMessage = "❌ Fehler: \(error.localizedDescription)"
        }
        isLoading = false
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
}
