import SwiftUI

// MARK: - Kalender-Modus
// Diese Enum definiert, ob die Ansicht als "Liste" oder "Kalender" gezeigt wird.
// Jede Variante bekommt einen lesbaren Titel über den rawValue.
enum CalendarMode: String, CaseIterable, Hashable {
    case list = "Liste"
    case calendar = "Kalender"
}

// MARK: - Hauptansicht für den Kalender
// Zeigt eine Liste aller Termine oder (später) eine Kalenderansicht.
// Nutzt ein ViewModel, das die Ereignisse liefert.
struct CalendarListView: View {
    @ObservedObject var vm: CalendarViewModel   // Beobachtet das ViewModel für Änderungen
    @State private var mode: CalendarMode = .list // Steuert, welcher Tab aktiv ist

    // Einheitlicher horizontaler Rand (links/rechts)
    private let sideInset: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // MARK: - Header mit Titel und Modus-Schalter
                HStack(alignment: .center, spacing: 12) {
                    // Überschrift „Mein Kalender“
                    Text("Mein Kalender")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 220, alignment: .leading)

                    Spacer(minLength: 8)

                    // MARK: Umschalter zwischen Liste und Kalender
                    // SegmentedToggle ist vermutlich eine eigene View,
                    // die wie ein Picker aussieht (SegmentedControl-Stil).
                    SegmentedToggle(
                        options: CalendarMode.allCases, // zeigt beide Modi
                        selection: $mode,               // bindet an State-Variable
                        title: { $0.rawValue },         // Beschriftung: „Liste“ oder „Kalender“
                        systemImage: { mode in          // Symbol für jeden Modus
                            switch mode {
                            case .list: return "list.bullet"
                            case .calendar: return "calendar"
                            }
                        }
                    )
                    .layoutPriority(1) // verhindert, dass der Toggle bei Platzmangel verschwindet
                }
                .padding(.horizontal, sideInset)
                .padding(.top, 8)

                // MARK: - Inhalt (abhängig vom Modus)
                if mode == .list {
                    // Wenn der Nutzer „Liste“ gewählt hat:
                    VStack(spacing: 16) {
                        // Alle Events aus dem ViewModel anzeigen
                        ForEach(vm.events) { event in
                            EventCard(event: event)         // einzelne Karte pro Event
                                .frame(maxWidth: .infinity)  // füllt horizontal den verfügbaren Platz
                        }
                    }
                    .padding(.horizontal, sideInset) // gleicher Außenabstand links/rechts

                } else {
                    // MARK: Platzhalter für Kalenderdarstellung
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Kalender-Ansicht kommt später")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.horizontal, sideInset)
                }

                Spacer(minLength: 24)
            }
            .padding(.bottom, 24)
        }
        // MARK: - Hintergrund und Navigationseinstellungen
        .background(Color(.systemGroupedBackground))
        .navigationTitle("") // Leerer Titel, weil oben eigener Header ist
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Einzelne Event-Karte
// Wird für jedes Ereignis in der Liste angezeigt.
// Zeigt Titel und Zeitspanne (Start–Ende) formatiert.
private struct EventCard: View {
    let event: Event // Ein einzelnes Kalender-Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titel des Events
            Text(event.title)
                .font(.title3).bold()
                .foregroundStyle(.primary)

            // Formatierte Zeitangabe
            Text(Self.format(event.start, event.end))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardStyle() // vermutlich ein Custom ViewModifier für Rahmen/Schatten
    }

    // MARK: - Zeitformatierung
    // Gibt je nach Tag-Übereinstimmung eine kompakte Beschreibung aus:
    // Beispiel:
    //  → „02.11.25, 10:00 – 11:30“ (gleicher Tag)
    //  → „02.11.25, 10:00 – 03.11.25, 11:30“ (verschiedene Tage)
    static func format(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        let sameDay = cal.isDate(start, inSameDayAs: end)

        let dfDateTime = DateFormatter()
        dfDateTime.locale = .current
        dfDateTime.dateFormat = "dd.MM.yy, HH:mm"

        if sameDay {
            // Wenn Start und Ende am selben Tag liegen,
            // wird das Datum nur einmal angezeigt, danach nur die Endzeit.
            let dfDate = DateFormatter()
            dfDate.locale = .current
            dfDate.dateFormat = "dd.MM.yy, HH:mm"

            let dfTime = DateFormatter()
            dfTime.locale = .current
            dfTime.dateFormat = "HH:mm"

            return "\(dfDate.string(from: start)) – \(dfTime.string(from: end))"
        } else {
            // Unterschiedliche Tage → beide komplett anzeigen
            return "\(dfDateTime.string(from: start)) – \(dfDateTime.string(from: end))"
        }
    }
}
