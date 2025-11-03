import SwiftUI

struct SettingsView: View {
    // Speichert die Auswahl persistent
    @AppStorage("appAppearance") private var appAppearance: String = "system"

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
                
            }

            Section("App") {
                Toggle(isOn: .constant(true)) { Text("Benachrichtigungen") }
                Toggle(isOn: .constant(false)) { Text("Experimentelle Features") }
            }

            Section {
                Button(role: .destructive) { } label: { Text("Abmelden") }
            }
        }
        .navigationTitle("Einstellungen")
    }

    // MARK: - Helpers

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
