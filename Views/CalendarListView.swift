import SwiftUI

enum CalendarMode: String, CaseIterable, Hashable {
    case list = "Liste"
    case calendar = "Kalender"
}

struct CalendarListView: View {
    @State private var events: [Event] = []
    @State private var mode: CalendarMode = .list
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let sideInset: CGFloat = 20

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Lade Termine...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Text("Fehler beim Laden der Termine")
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
                .padding()
            } else {
                calendarContent
            }
        }
        .task {
            await loadEvents()
        }
    }
    
    private var calendarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header mit Seitenrand
                HStack(alignment: .center, spacing: 12) {
                    Text("Mein Kalender")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 220, alignment: .leading)

                    Spacer(minLength: 8)

                    // ✅ Einfache Picker-Lösung statt SegmentedToggle
                    Picker("Ansicht", selection: $mode) {
                        ForEach(CalendarMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .layoutPriority(1)
                }
                .padding(.horizontal, sideInset)
                .padding(.top, 8)

                // Inhalt
                if mode == .list {
                    VStack(spacing: 16) {
                        if events.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(events) { event in
                                EventCard(event: event)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, sideInset)
                } else {
                    calendarPlaceholderView
                }

                Spacer(minLength: 24)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Keine Termine")
                .font(.headline)
            Text("Erstelle deinen ersten Termin in einer Gruppe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    private var calendarPlaceholderView: some View {
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

    // MARK: - Events laden
    @MainActor
    private func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ Später: Echte Events von Supabase laden
            // events = try await CalendarEndpoints.fetchUserEvents()
            
            // ⏳ Temporär: Leere Liste
            events = []
            print("✅ Persönliche Events geladen")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Laden der Events: \(error)")
        }
        
        isLoading = false
    }
}

private struct EventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.title3).bold()
                .foregroundStyle(.primary)
            Text(Self.format(event.start, event.end))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    static func format(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        let sameDay = cal.isDate(start, inSameDayAs: end)

        let dfDateTime = DateFormatter()
        dfDateTime.locale = .current
        dfDateTime.dateFormat = "dd.MM.yy, HH:mm"

        if sameDay {
            let dfDate = DateFormatter()
            dfDate.locale = .current
            dfDate.dateFormat = "dd.MM.yy, HH:mm"

            let dfTime = DateFormatter()
            dfTime.locale = .current
            dfTime.dateFormat = "HH:mm"

            return "\(dfDate.string(from: start)) – \(dfTime.string(from: end))"
        } else {
            return "\(dfDateTime.string(from: start)) – \(dfDateTime.string(from: end))"
        }
    }
}
