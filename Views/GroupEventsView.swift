import SwiftUI

struct GroupEventsView: View {
    let groupID: UUID
    @State private var title: String = ""
    @State private var start: Date = Date().addingTimeInterval(3600)
    @State private var end: Date = Date().addingTimeInterval(7200)
    @State private var events: [Event] = [] // ✅ Eigene State-Verwaltung
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Lade Termine...")
                        .frame(maxWidth: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Fehler beim Laden")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("Erneut versuchen") {
                            Task {
                                await loadEvents()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if events.isEmpty {
                    VStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Noch keine Termine")
                            .font(.headline)
                        Text("Erstelle den ersten Termin für diese Gruppe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    // Events anzeigen
                    ForEach(events) { ev in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ev.title)
                                .font(.title3).bold()
                            Text(Self.format(ev.start, ev.end))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .cardStyle()
                    }
                }

                // Eingabebereich für neuen Termin
                VStack(alignment: .leading, spacing: 12) {
                    Text("Neuen Gruppentermin hinzufügen")
                        .font(.headline)

                    TextField("Titel", text: $title)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Start", selection: $start)
                    DatePicker("Ende", selection: $end)

                    Button {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        createEvent(title: trimmed, start: start, end: end)
                        title = ""
                        start = Date().addingTimeInterval(3600)
                        end = Date().addingTimeInterval(7200)
                    } label: {
                        Label("Termin hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cardStroke))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            Task {
                await loadEvents()
            }
        }
    }

    // MARK: - Events laden
    @MainActor
    private func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ Später: Echte Events von Supabase laden
            // events = try await CalendarEndpoints.fetchEvents(for: groupID)
            
            // ⏳ Temporär: Leere Liste
            events = []
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Laden der Events: \(error)")
        }
        
        isLoading = false
    }

    // MARK: - Event erstellen
    @MainActor
    private func createEvent(title: String, start: Date, end: Date) {
        Task {
            do {
                // ✅ Später: Event in Supabase erstellen
                // let newEvent = try await CalendarEndpoints.createEvent(
                //     title: title,
                //     start: start,
                //     end: end,
                //     groupID: groupID
                // )
                // events.append(newEvent)
                
                // ⏳ Temporär: Lokal hinzufügen
                let newEvent = Event(
                    id: UUID(),
                    title: title,
                    description: nil,
                    start: start,
                    end: end,
                    group_id: groupID,
                    created_by: UUID(), // Später echte User ID
                    created_at: Date()
                )
                events.append(newEvent)
                
                print("📅 Event erstellt: '\(title)' für Gruppe \(groupID)")
            } catch {
                print("❌ Fehler beim Erstellen des Events: \(error)")
                errorMessage = "Event konnte nicht erstellt werden: \(error.localizedDescription)"
            }
        }
    }

    // Formatierung
    private static func format(_ start: Date, _ end: Date) -> String {
        let sameDay = Calendar.current.isDate(start, inSameDayAs: end)
        let d = DateFormatter()
        d.locale = .current
        d.dateFormat = "dd.MM.yy, HH:mm"
        if sameDay {
            let t = DateFormatter()
            t.locale = .current
            t.dateFormat = "HH:mm"
            return "\(d.string(from: start)) – \(t.string(from: end))"
        } else {
            return "\(d.string(from: start)) – \(d.string(from: end))"
        }
    }
}
