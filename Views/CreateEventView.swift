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
    
    // UI State
    @State private var isCreating = false
    @State private var showDetails = false
    @FocusState private var isTitleFocused: Bool

    // Custom init, damit wir initiale Gruppen übergeben können
    init(allGroups: [AppGroup], onCreated: @escaping () -> Void) {
        self._groups = State(initialValue: allGroups)
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)
                    
                    // Ziel-Auswahl
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Termin für")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Picker("Ziel", selection: $targetScope) {
                            Text("Mich").tag(EventTargetScope.personal)
                            Text("Gruppe").tag(EventTargetScope.group)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Gruppen-Picker
                    if targetScope == .group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gruppe auswählen")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Menu {
                                ForEach(groups) { group in
                                    Button {
                                        selectedGroupId = group.id
                                    } label: {
                                        HStack {
                                            Text(group.name)
                                            if selectedGroupId == group.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedGroupName)
                                        .foregroundStyle(selectedGroupId == nil ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Titel
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Titel")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Was steht an?", text: $title)
                            .font(.body)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isTitleFocused)
                    }
                    
                    // Zeit
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zeitraum")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 0) {
                            DatePicker("Start", selection: $start)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            
                            Divider()
                                .padding(.leading, 14)
                            
                            DatePicker("Ende", selection: $end)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Details (optional, ausklappbar)
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showDetails.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Details hinzufügen")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        if showDetails {
                            TextEditor(text: $details)
                                .font(.body)
                                .frame(minHeight: 80)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neuer Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.85)
                        } else {
                            Text("Speichern")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isCreating)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: targetScope)
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
        .onAppear {
            isTitleFocused = true
        }
    }

    // MARK: - Helper
    
    private var selectedGroupName: String {
        if let id = selectedGroupId,
           let group = groups.first(where: { $0.id == id }) {
            return group.name
        }
        return "Gruppe auswählen..."
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

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
        
        isCreating = true

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
                isCreating = false
                onCreated()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isCreating = false
            }
            print("❌ Fehler beim Erstellen des Events:", error)
        }
    }
}
