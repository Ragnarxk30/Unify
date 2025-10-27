import SwiftUI

struct EditProfileView: View {
    var user: CKUser
    var onSave: (CKUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String

    init(user: CKUser, onSave: @escaping (CKUser) -> Void) {
        self.user = user
        self.onSave = onSave
        _displayName = State(initialValue: user.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Anzeigename") {
                    TextField("Name", text: $displayName)
                }
            }
            .navigationTitle("Profil bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(.init(id: user.id, displayName: displayName))
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    EditProfileView(user: .init(id: "me", displayName: "Ich")) { _ in }
}
