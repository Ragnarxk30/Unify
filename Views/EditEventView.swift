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

    init(event: Event, onUpdated: @escaping () -> Void) {
        self.event = event
        self.onUpdated = onUpdated
        _title = State(initialValue: event.title)
        _details = State(initialValue: event.details ?? "")
        _start = State(initialValue: event.starts_at)
        _end = State(initialValue: event.ends_at)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("Titel", text: $title)
                }

                Section("Details") {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                }

                Section("Zeit") {
                    DatePicker("Start", selection: $start)
                    DatePicker("Ende", selection: $end)
                }
            }
            .navigationTitle("Termin bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task { await saveChanges() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else { return }

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
                onUpdated()
                dismiss()
            }
        } catch {
            print("❌ Fehler beim Aktualisieren des Events:", error)
        }
    }
}
