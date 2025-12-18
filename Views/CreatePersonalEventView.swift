import SwiftUI

struct CreatePersonalEventView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onCreated: () -> Void
    
    @State private var title = ""
    @State private var details = ""
    @State private var start = Date().addingTimeInterval(3600)
    @State private var end   = Date().addingTimeInterval(7200)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Eingabebereich für neuen persönlichen Termin
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Neuen Termin hinzufügen")
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
                        
                        DatePicker("Start", selection: $start)
                        DatePicker("Ende", selection: $end)
                        
                        Button {
                            Task { await save() }
                        } label: {
                            Label("Termin hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || start < Date())
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
        // ⬇️ Start/Ende wie in GroupEventsView koppeln
        .onChange(of: start) { oldStart, newStart in
            let duration = end.timeIntervalSince(oldStart)
            end = newStart.addingTimeInterval(max(duration, 0))
        }
    }
    
    // MARK: - Speichern
    private func save() async {
        let trimmedTitle   = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard start >= Date() else { return }
        
        do {
            let repo = SupabaseEventRepository()
            try await repo.createPersonal(
                title: trimmedTitle,
                details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                startsAt: start,
                endsAt: end
            )
            
            await MainActor.run {
                onCreated()
                dismiss()
            }
        } catch {
            print("❌ Fehler beim Erstellen des Events:", error)
        }
    }
}
