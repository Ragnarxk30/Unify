import SwiftUI

// MARK: - Ansicht für Gruppen-Termine
// Zeigt alle Termine einer bestimmten Gruppe an und ermöglicht das Hinzufügen neuer Termine.
struct GroupEventsView: View {
    let groupID: UUID                    // ID der angezeigten Gruppe

    // Lokale State-Variablen für neue Termine
    @State private var title: String = ""                      // Titel für neuen Termin
    @State private var start: Date = Date().addingTimeInterval(3600) // Startzeit (1h ab jetzt)
    @State private var end: Date = Date().addingTimeInterval(7200)   // Endzeit (2h ab jetzt)

    @ObservedObject private var groupsVM: GroupsViewModel      // Globale Gruppen-Daten (ViewModel)

    // MARK: - Initialisierung
    init(groupID: UUID, groupsVM: GroupsViewModel) {
        self.groupID = groupID
        // ObservableObject muss mit ObservedObject(initialValue:) initialisiert werden
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Bestehende Termine anzeigen
                if let group = groupsVM.groups.first(where: { $0.id == groupID }) {
                    // Iteration über alle Events der Gruppe
                    ForEach(group.events) { ev in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ev.title)
                                .font(.title3).bold()
                            Text(Self.format(ev.start, ev.end))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .cardStyle() // vermutlich Custom Modifier für Karten-Look
                    }
                }

                // MARK: - Eingabebereich für neuen Termin
                VStack(alignment: .leading, spacing: 12) {
                    Text("Neuen Gruppentermin hinzufügen")
                        .font(.headline)

                    // Titel-Feld
                    TextField("Titel", text: $title)
                        .textFieldStyle(.roundedBorder)

                    // Start- und End-Datum
                    DatePicker("Start", selection: $start)
                    DatePicker("Ende", selection: $end)

                    // Button zum Hinzufügen
                    Button {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        // Füge das Event über das ViewModel hinzu
                        groupsVM.addEvent(title: trimmed, start: start, end: end, to: groupID)

                        // Felder zurücksetzen
                        title = ""
                        start = Date().addingTimeInterval(3600)
                        end = Date().addingTimeInterval(7200)
                    } label: {
                        Label("Termin hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cardStroke))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Zeitformatierung für Events
    // Zeigt entweder "Start – Ende" (gleicher Tag) oder "Start – Ende" (verschiedene Tage)
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
