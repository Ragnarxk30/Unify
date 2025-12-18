import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss

    let onCreated: () -> Void

    // Gruppen-Quelle (wird mit initialen Gruppen befüllt)
    @State private var groups: [AppGroup]

    // Auswahl: Personal / Gruppe
    @State private var targetScope: EventTargetScope = .personal
    @State private var selectedGroupId: UUID? = nil

    // Felder
    @State private var title = ""
    @State private var details = ""
    @State private var start  = Date().addingTimeInterval(3600)
    @State private var end    = Date().addingTimeInterval(7200)

    // Custom init, damit wir initiale Gruppen übergeben können
    init(allGroups: [AppGroup], onCreated: @escaping () -> Void) {
        self._groups = State(initialValue: allGroups)
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Neuen Termin hinzufügen")
                            .font(.headline)

                        // 1) Ziel-Auswahl (Ich / Gruppe)
                        Picker("Ziel", selection: $targetScope) {
                            ForEach(EventTargetScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)

                        // 2) Gruppen-Picker (nur wenn Gruppe gewählt)
                        if targetScope == .group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gruppe")
                                    .font(.subheadline)

                                Picker("Gruppe", selection: $selectedGroupId) {
                                    Text(groups.isEmpty ? "Lade Gruppen..." : "Bitte wählen")
                                        .tag(nil as UUID?)
                                    ForEach(groups) { group in
                                        Text(group.name)
                                            .tag(group.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        // 3) Titel + Details + Zeiten
                        TextField("Titel", text: $title)
                            .textFieldStyle(.roundedBorder)

                        Text("Details (optional)")
                            .font(.subheadline)
                        TextEditor(text: $details)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3))
                            )

                        DatePicker("Start", selection: $start)
                        DatePicker("Ende", selection: $end)

                        // 4) Speichern-Button
                        Button {
                            Task { await save() }
                        } label: {
                            Label("Termin hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                    .padding()
                    .background(
                        Color.cardBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cardStroke)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neuer Termin")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: start) { oldStart, newStart in
            let duration = end.timeIntervalSince(oldStart)
            end = newStart.addingTimeInterval(max(duration, 0))
        }
        .task {
            if groups.isEmpty {
                await loadGroups()
            }
        }
    }

    // MARK: - Helper

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard start >= Date() else { return false }

        if targetScope == .group {
            return selectedGroupId != nil && !groups.isEmpty
        }

        return true
    }

    @MainActor
    private func updateGroups(_ new: [AppGroup]) {
        self.groups = new
    }

    private func loadGroups() async {
        do {
            let repo = SupabaseGroupRepository()
            let loaded = try await repo.fetchGroups()
            await updateGroups(loaded)
        } catch {
            print("❌ Fehler beim Laden der Gruppen im CreateEventView:", error)
        }
    }

    private func save() async {
        let trimmedTitle   = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard start >= Date() else { return }

        do {
            let repo = SupabaseEventRepository()

            switch targetScope {
            case .personal:
                try await repo.createPersonal(
                    title: trimmedTitle,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                    startsAt: start,
                    endsAt: end
                )

            case .group:
                guard let gid = selectedGroupId else { return }
                try await repo.create(
                    groupId: gid,
                    title: trimmedTitle,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                    startsAt: start,
                    endsAt: end
                )
            }

            await MainActor.run {
                onCreated()
                dismiss()
            }
        } catch {
            print("❌ Fehler beim Erstellen des Events:", error)
        }
    }
}
