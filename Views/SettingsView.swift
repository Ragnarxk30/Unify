import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Profil") {
                Label("Angemeldet als: Ich", systemImage: "person.circle")
            }
            Section("App") {
                Toggle(isOn: .constant(true)) { Text("Benachrichtigungen") }
                Toggle(isOn: .constant(false)) { Text("Experimentelle Features") }
            }
            Section {
                Button(role: .destructive) { } label: {
                    Text("Abmelden")
                }
            }
        }
        .navigationTitle("Einstellungen")
    }
}
