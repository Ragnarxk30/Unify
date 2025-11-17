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
    @State private var editingEvent: Event? = nil

    private let sideInset: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Picker oben wie in deinem Screenshot
            Picker("Ansicht", selection: $mode) {
                ForEach(CalendarMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, sideInset)
            .padding(.top, 15)

            // MARK: Inhalt unter dem Picker
            Group {
                if isLoading {
                    ProgressView("Lade Termine...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Text("Fehler beim Laden der Termine")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Erneut versuchen") {
                            Task { await loadEvents() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    if mode == .list {
                        listContent
                    } else {
                        calendarPlaceholderView
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEvents()
        }
        .sheet(item: $editingEvent) { event in
            EditEventView(event: event) {
                Task { await loadEvents() }
            }
        }
    }

    // MARK: - List-Ansicht mit Swipe Actions

    private var listContent: some View {
        List {
            if events.isEmpty {
                Section {
                    emptyStateView
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(events) { event in
                        EventCard(event: event)
                            .listRowInsets(
                                EdgeInsets(top: 8,
                                           leading: sideInset,
                                           bottom: 8,
                                           trailing: sideInset)
                            )
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteEvent(event) }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }

                                Button {
                                    editingEvent = event
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden) // kein grauer Listenhintergrund
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty / Placeholder

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
        .padding(.vertical, 40)
    }

    private var calendarPlaceholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Kalender-Ansicht kommt später")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.horizontal, sideInset)
    }

    // MARK: - Laden & Löschen

    @MainActor
    private func loadEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let repo = SupabaseEventRepository()
            events = try await repo.listUserEvents()
            print("✅ Persönliche Events geladen")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Laden der Events:", error)
        }

        isLoading = false
    }

    @MainActor
    private func deleteEvent(_ event: Event) async {
        do {
            let repo = SupabaseEventRepository()
            try await repo.delete(eventId: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fehler beim Löschen des Events:", error)
        }
    }
}

// MARK: - Card

private struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.title3).bold()
                .foregroundStyle(.primary)

            Text(Self.format(event.starts_at, event.ends_at))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let details = event.details,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
        .cardStyle() // deine bestehende Card-Optik, passt sich Light/Dark an
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
