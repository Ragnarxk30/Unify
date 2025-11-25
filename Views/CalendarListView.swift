import SwiftUI

struct CalendarListView: View {
    @State private var events: [Event] = []
    @State private var mode: CalendarMode = .list
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var editingEvent: Event? = nil
    @State private var showAddEvent = false

    // Filter-State
    @State private var showFilterPanel = false
    @State private var filterScope: CalendarFilterScope = .all
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var allGroups: [AppGroup] = []   // später aus Repo laden

    // Frame des Filter-Buttons (global)
    @State private var filterButtonFrame: CGRect = .zero
    // Kalender-State
        @State private var selectedDate = Date()
        @State private var displayMonth: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

        private let calendar = Calendar.current


    private let sideInset: CGFloat = 20

    // MARK: - Gefilterte Events
    private var filteredEvents: [Event] {
        events.filter { ev in
            switch filterScope {
            case .all:
                return true
            case .personalOnly:
                return ev.group_id == nil
            case .groupsOnly:
                guard let gid = ev.group_id else { return false }
                if selectedGroupIDs.isEmpty { return true }
                return selectedGroupIDs.contains(gid)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            mainContent
                .blur(radius: showFilterPanel ? 2 : 0)
                .overlay {
                    if showFilterPanel {
                        ZStack(alignment: .topLeading) {
                            // Abdunkelung
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showFilterPanel = false
                                    }
                                }

                            // Popup – an Button gehängt
                            EventFilterSidePanel(
                                scope: $filterScope,
                                allGroups: allGroups,
                                selectedGroupIDs: $selectedGroupIDs
                            )
                            .frame(maxWidth: 280, alignment: .leading)
                            .offset(
                                x: filterButtonFrame.minX,
                                y: filterButtonFrame.maxY + 8
                            )
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
        }
        .animation(.easeInOut(duration: 0.25), value: showFilterPanel)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showFilterPanel = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter öffnen")
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ButtonFramePreferenceKey.self,
                                value: geo.frame(in: .global)
                            )
                    }
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neuen Termin anlegen")
            }
        }
        .onPreferenceChange(ButtonFramePreferenceKey.self) { newValue in
            filterButtonFrame = newValue
        }
        .task {
            await loadEvents()
            await loadGroups()
        }
        .sheet(item: $editingEvent) { event in
            EditEventView(event: event) {
                Task { await loadEvents() }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            CreatePersonalEventView {
                Task { await loadEvents() }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Hauptinhalt
    private var mainContent: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $mode) {
                ForEach(CalendarMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, sideInset)
            .padding(.top, 15)
            
            Group {
                if isLoading {
                    ProgressView("Lade Termine...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if let errorMessage {
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
                        calendarContent
                    }
                }
            }
        }
    }

private var calendarContent: some View {
ScrollView {
    VStack(spacing: 16) {
        calendarHeader
        weekdayHeader
        monthGrid

        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text(dateHeadline(for: selectedDate))
                .font(.headline)
                .foregroundStyle(.primary)

            if selectedDateEvents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("Keine Termine an diesem Tag")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(selectedDateEvents) { event in
                        EventCard(event: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, sideInset)
    .padding(.vertical, 12)
}
.background(Color(.systemGroupedBackground))
}

private var calendarHeader: some View {
HStack {
    Button {
        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
    } label: {
        Image(systemName: "chevron.left")
            .padding(8)
            .background(Circle().fill(Color(.systemGray6)))
    }

    Spacer()

    Text(monthYearString(from: displayMonth))
        .font(.headline)

    Spacer()

    Button {
        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
    } label: {
        Image(systemName: "chevron.right")
            .padding(8)
            .background(Circle().fill(Color(.systemGray6)))
    }
}
}

private var weekdayHeader: some View {
let symbols = calendar.shortStandaloneWeekdaySymbols
return HStack {
    ForEach(symbols, id: \.self) { symbol in
        Text(symbol)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }
}
}

private var monthGrid: some View {
let days = makeMonthDays()
return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
    ForEach(days, id: \.self) { day in
        if let day = day {
            dayCell(for: day)
        } else {
            Color.clear.frame(height: 36)
        }
    }
}
.padding(.vertical, 8)
}

private func dayCell(for date: Date) -> some View {
let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
let isToday = calendar.isDateInToday(date)
let count = eventCount(for: date)

return Button {
    selectedDate = date
} label: {
    VStack(spacing: 4) {
        Text("\(calendar.component(.day, from: date))")
            .font(.body)
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(
                ZStack {
                    if isSelected {
                        Circle().fill(Color.accentColor.opacity(0.9))
                    } else if isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 2)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .primary)

        if count > 0 {
            HStack(spacing: 3) {
                ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.9) : Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
        } else {
            Color.clear.frame(height: 6)
        }
    }
}
.buttonStyle(.plain)
}

private func monthYearString(from date: Date) -> String {
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "de_DE")
formatter.dateFormat = "LLLL yyyy"
return formatter.string(from: date).capitalized
}

private func dateHeadline(for date: Date) -> String {
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "de_DE")
formatter.dateFormat = "EEEE, d. MMMM"
return formatter.string(from: date).capitalized
}

    private func makeMonthDays() -> [Date?] {
        // Monat & erster Wochentag bestimmen
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayMonth),
              let firstWeekday = calendar.dateComponents([(.weekday)], from: monthInterval.start).weekday,
              let days = calendar.range(of: .day, in: .month, for: displayMonth)
        else {
            return []
        }

        // Wie viele leere Kästchen vor dem 1. des Monats?
        let prefixCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let prefix = Array(repeating: nil as Date?, count: prefixCount)

        // Alle Tage des Monats als Date
        let monthDays: [Date?] = days.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        return prefix + monthDays
    }

private func eventCount(for date: Date) -> Int {
eventsByDay[calendar.startOfDay(for: date)]?.count ?? 0
}

private var eventsByDay: [Date: [Event]] {
Dictionary(grouping: filteredEvents) { event in
    calendar.startOfDay(for: event.starts_at)
}
}

    private var selectedDateEvents: [Event] {
        (eventsByDay[calendar.startOfDay(for: selectedDate)] ?? [])
            .sorted { $0.starts_at < $1.starts_at }
    }
        private var listContent: some View {
            List {
                if filteredEvents.isEmpty {
                    Section {
                        emptyStateView
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredEvents) { event in
                            EventCard(event: event)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: 8,
                                        leading: sideInset,
                                        bottom: 8,
                                        trailing: sideInset
                                    )
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
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
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
        .padding(.vertical, 40)
    }

    

    // MARK: - Laden & Löschen

    @MainActor
    private func loadEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let repo = SupabaseEventRepository()
            events = try await repo.listUserEvents()
        } catch {
            errorMessage = error.localizedDescription
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
        }
    }
    
    @MainActor
    private func loadGroups() async {
        do {
            let groupRepo = SupabaseGroupRepository()
            let groups = try await groupRepo.fetchGroups()
            allGroups = groups
            print("✅ CalendarListView: \(groups.count) Gruppen in allGroups geladen")
            for g in groups {
                print("   • \(g.name) – \(g.id)")
            }
        } catch {
            print("❌ Fehler beim Laden der Gruppen:", error)
        }
    }
}

struct ButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
