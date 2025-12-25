import SwiftUI

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss

    let event: Event
    let onUpdated: () -> Void

    @State private var title: String
    @State private var details: String
    @State private var start: Date
    @State private var end: Date
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showDetails: Bool
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isDetailsFocused: Bool

    init(event: Event, onUpdated: @escaping () -> Void) {
        self.event = event
        self.onUpdated = onUpdated
        _title   = State(initialValue: event.title)
        _details = State(initialValue: event.details ?? "")
        _start   = State(initialValue: event.starts_at)
        _end     = State(initialValue: event.ends_at)
        _showDetails = State(initialValue: !(event.details?.isEmpty ?? true))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - nur Label
            VStack(spacing: 12) {
                Text("Bearbeiten")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Divider()
            }
            .padding(.top, 20)
            .background(.regularMaterial)

            // Content
            ScrollView {
                VStack(spacing: 12) {
                    // Titel
                    HStack(spacing: 12) {
                        Image(systemName: "textformat")
                            .foregroundStyle(.blue)
                            .frame(width: 20)

                        TextField("Titel", text: $title)
                            .font(.subheadline)
                            .focused($isTitleFocused)
                    }

                    // Start Zeit
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.green)
                            .frame(width: 20)

                        Text("Start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        DatePicker("", selection: $start, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .fixedSize()
                    }

                    // Ende Zeit
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)

                        Text("Ende")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        DatePicker("", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .fixedSize()
                    }

                    // Dauer
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text(duration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    // Typ
                    HStack(spacing: 12) {
                        Image(systemName: event.group_id != nil ? "person.2.fill" : "person.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)

                        Text(event.group_id != nil ? "Gruppen-Termin" : "Persönlicher Termin")
                            .font(.subheadline)

                        Spacer()
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Details
                    if showDetails {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .padding(.top, 4)

                            TextField("Details (optional)", text: $details, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(1...5)
                                .focused($isDetailsFocused)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDetails = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isDetailsFocused = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                Text("Details hinzufügen")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                Spacer()
                            }
                        }
                    }

                    // Error
                    if let errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .frame(width: 20)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 20)

                    // Action Buttons - ganz unten
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Abbrechen")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isSaving)

                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Speichern")
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(canSave ? Color.blue : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!canSave || isSaving)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .onChange(of: start) { oldStart, newStart in
            let duration = end.timeIntervalSince(oldStart)
            end = newStart.addingTimeInterval(max(duration, 0))
        }
    }

    private var duration: String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes) Minuten"
        }
    }

    private func saveChanges() async {
        let trimmedTitle   = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else { return }

        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        do {
            let repo = SupabaseEventRepository()
            try await repo.update(
                eventId: event.id,
                title: trimmedTitle,
                details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                startsAt: start,
                endsAt: end
            )

            await MainActor.run {
                isSaving = false
                onUpdated()
                dismiss()
            }
        } catch {
            print("❌ Fehler beim Aktualisieren des Events:", error)
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
