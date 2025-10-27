import SwiftUI

struct EventEditorView: View {
    var onSave: (String, Date, Date, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var allDay = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Titel", text: $title)
                    Toggle("Ganztägig", isOn: $allDay)
                }
                Section("Zeit") {
                    DatePicker("Beginn", selection: $startDate)
                    DatePicker("Ende", selection: $endDate)
                }
            }
            .navigationTitle("Neuer Termin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(title, startDate, endDate, allDay)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || endDate < startDate)
                }
            }
        }
    }
}

#Preview {
    EventEditorView { _, _, _, _ in }
}
