import SwiftUI

struct GroupSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let group: AppGroup
    let onUpdated: (AppGroup) -> Void

    @State private var name: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var isOwner = false
    @State private var errorMessage: String?

    private let groupRepo = SupabaseGroupRepository()
    private let authRepo: AuthRepository = SupabaseAuthRepository()

    init(group: AppGroup, onUpdated: @escaping (AppGroup) -> Void) {
        self.group = group
        self.onUpdated = onUpdated
        _name = State(initialValue: group.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Gruppenname", text: $name)
                        .disabled(isSaving)
                }

                // Platzhalter: Mitgliederverwaltung – kann nachgereicht werden
                Section("Mitglieder") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mitgliederverwaltung folgt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                // hier später: Add-Member Sheet
                            } label: {
                                Label("Mitglied hinzufügen", systemImage: "person.badge.plus")
                            }
                            .disabled(true)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isOwner {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Gruppe löschen", systemImage: "trash")
                        }
                        .disabled(isDeleting)
                    } footer: {
                        Text("Nur der Besitzer kann die Gruppe löschen.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Gruppeneinstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isSaving || isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { Task { await save() } }
                        .disabled(isSaving || nameTrimmed.isEmpty || nameTrimmed == group.name)
                }
            }
            .confirmationDialog(
                "Gruppe wirklich löschen?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Gruppe löschen", role: .destructive) {
                    Task { await deleteGroup() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .task {
                await resolveOwnership()
            }
        }
    }

    private var nameTrimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }

    private func resolveOwnership() async {
        do {
            let uid = try await authRepo.currentUserId()
            await MainActor.run {
                isOwner = (uid == group.owner_id)
            }
        } catch {
            await MainActor.run {
                isOwner = false
            }
        }
    }

    private func save() async {
        guard !nameTrimmed.isEmpty, nameTrimmed != group.name else { return }
        await MainActor.run {
            errorMessage = nil
            isSaving = true
        }
        do {
            try await groupRepo.rename(groupId: group.id, to: nameTrimmed)
            // Lokales Objekt mit neuem Namen zurückreichen
            let updated = AppGroup(id: group.id, name: nameTrimmed, owner_id: group.owner_id, user: group.user)
            await MainActor.run {
                onUpdated(updated)
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                setError("Konnte nicht speichern: \(error.localizedDescription)")
            }
        }
    }

    private func deleteGroup() async {
        await MainActor.run {
            errorMessage = nil
            isDeleting = true
        }
        do {
            try await groupRepo.delete(groupId: group.id)
            await MainActor.run {
                isDeleting = false
                // Nach dem Löschen einfach schließen. Aufrufende View sollte Liste aktualisieren. 
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                setError("Löschen fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
}

