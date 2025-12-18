//
//  EditEventView.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 16.11.25.
//

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

    init(event: Event, onUpdated: @escaping () -> Void) {
        self.event = event
        self.onUpdated = onUpdated
        _title   = State(initialValue: event.title)
        _details = State(initialValue: event.details ?? "")
        _start   = State(initialValue: event.starts_at)
        _end     = State(initialValue: event.ends_at)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Card mit Eingaben
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Termin bearbeiten")
                            .font(.headline)

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

                        Text("Zeit")
                            .font(.subheadline).bold()
                            .padding(.top, 4)

                        DatePicker("Start", selection: $start)
                        DatePicker("Ende", selection: $end)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }

                        Button {
                            Task { await saveChanges() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Label("Änderungen speichern", systemImage: "checkmark")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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
            .navigationTitle("Termin bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                // Optional: zusätzlich oben „Speichern“-Button lassen
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task { await saveChanges() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        // Start/Ende mitziehen wie in den anderen Views
        .onChange(of: start) { oldStart, newStart in
            let duration = end.timeIntervalSince(oldStart)
            end = newStart.addingTimeInterval(max(duration, 0))
        }
    }

    // MARK: - Speichern

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
                errorMessage = "Fehler beim Speichern: \(error.localizedDescription)"
            }
        }
    }
}
