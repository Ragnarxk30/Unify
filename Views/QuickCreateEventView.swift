import SwiftUI

struct QuickCreateEventView: View {
    @Environment(\.dismiss) private var dismiss

    let preselectedStart: Date
    let allGroups: [AppGroup]
    let onCreated: () -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var targetScope: EventTargetScope = .personal
    @State private var selectedGroupId: UUID? = nil
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var endTime: Date

    init(preselectedStart: Date, allGroups: [AppGroup], onCreated: @escaping () -> Void) {
        self.preselectedStart = preselectedStart
        self.allGroups = allGroups
        self.onCreated = onCreated
        _endTime = State(initialValue: preselectedStart.addingTimeInterval(3600))
    }

    private var canCreate: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        if targetScope == .group {
            return selectedGroupId != nil
        }

        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header mit mehr Platz
            HStack {
                Button("Abbrechen") {
                    dismiss()
                }
                .disabled(isCreating)

                Spacer()

                Text("Neuer Termin")
                    .font(.headline)

                Spacer()

                Button {
                    Task { await createEvent() }
                } label: {
                    if isCreating {
                        ProgressView()
                    } else {
                        Text("Erstellen")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!canCreate || isCreating)
            }
            .padding(.horizontal)
            .padding(.top, 23)
            .padding(.bottom, 17)
            .background(Color(.systemBackground))

            Divider()

            // Content
            Form {
                Section {
                    TextField("Titel", text: $title)

                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...4)

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(formattedDate)
                            .font(.subheadline)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Start: \(formattedTime(preselectedStart))")
                            .font(.subheadline)
                    }

                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Picker("Ziel", selection: $targetScope) {
                        ForEach(EventTargetScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if targetScope == .group {
                        Picker("Gruppe", selection: $selectedGroupId) {
                            Text("Bitte wählen")
                                .tag(nil as UUID?)
                            ForEach(allGroups) { group in
                                Text(group.name)
                                    .tag(group.id as UUID?)
                            }
                        }
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
        }
    }

    private var formattedDate: String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: preselectedStart)
    }

    private func formattedTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }

    private func createEvent() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else { return }

        await MainActor.run {
            isCreating = true
            errorMessage = nil
        }

        do {
            let repo = SupabaseEventRepository()

            switch targetScope {
            case .personal:
                try await repo.createPersonal(
                    title: trimmedTitle,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                    startsAt: preselectedStart,
                    endsAt: endTime
                )

            case .group:
                guard let gid = selectedGroupId else { return }
                try await repo.create(
                    groupId: gid,
                    title: trimmedTitle,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                    startsAt: preselectedStart,
                    endsAt: endTime
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
                errorMessage = error.localizedDescription
            }
        }
    }
}
