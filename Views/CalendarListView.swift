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

    // Kalender-State (bestehende einfache Kalenderansicht)
    @State private var selectedDate = Date()
    @State private var displayMonth: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    private let calendar = Calendar.current

    // Neue erweiterte Kalender-Modi (Monat/Woche/Tag)
    @State private var calendarViewMode: CalendarViewMode = .month
    @State private var anchorDate: Date = Date()
    @State private var selectedDateAdvanced: Date? = nil
    @State private var slideDirection: Int = 0

    // Event Detail/Action Sheets
    @State private var selectedEventForDetails: Event? = nil
    @State private var pendingAction: PendingEventAction? = nil

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
            CreateEventView(allGroups: allGroups) {
                Task { await loadEvents() }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedEventForDetails) { event in
            EventDetailsSheet(event: event)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                        // iPhone-Style Zoomable Kalender
                        ZoomableCalendarView(
                            events: filteredEvents,
                            calendar: calendar,
                            allGroups: allGroups,
                            onAdd: { showAddEvent = true },
                            onEdit: { event in
                                editingEvent = event
                            },
                            onDelete: { event in
                                await deleteEvent(event)
                            },
                            onRefresh: {
                                await loadEvents()
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Neue erweiterte Kalenderansicht (Month/Week/Day)
    private var advancedCalendarContent: some View {
        VStack(spacing: 14) {
            // Header mit Navigation
            HStack(spacing: 12) {
                Button {
                    slideDirection = -1
                    shiftAnchor(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleForAnchor())
                        .font(.title3.weight(.semibold))
                    Text("Heute: \(formattedDay(Date()))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    slideDirection = 0
                    anchorDate = Date()
                } label: {
                    Text("Heute")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    slideDirection = +1
                    shiftAnchor(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, sideInset)
            .padding(.top, 6)

            // Modus Picker (Monat/Woche/Tag)
            Picker("", selection: $calendarViewMode) {
                ForEach(CalendarViewMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, sideInset)

            ZStack {
                currentModeView
                    .id(modeID)
                    .transition(slideTransition)
            }
            .animation(.easeInOut(duration: 0.28), value: modeID)

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var modeID: String {
        let key: String
        switch calendarViewMode {
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: anchorDate)
            key = "M:\(comps.year ?? 0)-\(comps.month ?? 0)"
        case .week:
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate)
            key = "W:\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        case .day:
            let comps = calendar.dateComponents([.year, .month, .day], from: anchorDate)
            key = "D:\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        }
        return "\(calendarViewMode.rawValue)-\(key)"
    }

    private var slideTransition: AnyTransition {
        let moveIn = slideDirection >= 0 ? AnyTransition.move(edge: .trailing) : AnyTransition.move(edge: .leading)
        let moveOut = slideDirection >= 0 ? AnyTransition.move(edge: .leading) : AnyTransition.move(edge: .trailing)
        let insertion = moveIn.combined(with: .opacity)
        let removal = moveOut.combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    @ViewBuilder
    private var currentModeView: some View {
        switch calendarViewMode {
        case .month:
            MonthGridView(
                calendar: calendar,
                anchorDate: $anchorDate,
                selectedDate: $selectedDateAdvanced,
                today: Date(),
                eventsProvider: { date in events(on: date) },
                colorsProvider: { dayEvents in compactColors(from: dayEvents) },
                onSelect: { date in
                    selectedDateAdvanced = date
                    anchorDate = date
                    calendarViewMode = .day
                }
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    anchorDate = calendar.date(byAdding: .month, value: 1, to: anchorDate) ?? anchorDate
                },
                onSwipeRight: {
                    slideDirection = -1
                    anchorDate = calendar.date(byAdding: .month, value: -1, to: anchorDate) ?? anchorDate
                }
            )

        case .week:
            WeekGridView(
                calendar: calendar,
                anchorDate: $anchorDate,
                selectedDate: $selectedDateAdvanced,
                today: Date(),
                eventsProvider: { date in events(on: date) },
                colorsProvider: { dayEvents in compactColors(from: dayEvents) },
                onSelect: { date in
                    selectedDateAdvanced = date
                    anchorDate = date
                    calendarViewMode = .day
                }
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    anchorDate = calendar.date(byAdding: .weekOfYear, value: 1, to: anchorDate) ?? anchorDate
                },
                onSwipeRight: {
                    slideDirection = -1
                    anchorDate = calendar.date(byAdding: .weekOfYear, value: -1, to: anchorDate) ?? anchorDate
                }
            )

        case .day:
            DayScheduleView(
                calendar: calendar,
                anchorDate: $anchorDate,
                eventsForDay: { events(on: $0) },
                onAdd: {
                    selectedDateAdvanced = anchorDate
                    showAddEvent = true
                }
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    anchorDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate
                },
                onSwipeRight: {
                    slideDirection = -1
                    anchorDate = calendar.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate
                }
            )
        }
    }

    private func shiftAnchor(by step: Int) {
        withAnimation(.easeInOut(duration: 0.28)) {
            switch calendarViewMode {
            case .month:
                anchorDate = calendar.date(byAdding: .month, value: step, to: anchorDate) ?? anchorDate
            case .week:
                anchorDate = calendar.date(byAdding: .weekOfYear, value: step, to: anchorDate) ?? anchorDate
            case .day:
                anchorDate = calendar.date(byAdding: .day, value: step, to: anchorDate) ?? anchorDate
            }
        }
    }

    private func titleForAnchor() -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        switch calendarViewMode {
        case .month:
            df.dateFormat = "LLLL yyyy"
            return df.string(from: anchorDate).capitalized
        case .week:
            df.dateFormat = "'Woche' w, yyyy"
            return df.string(from: anchorDate)
        case .day:
            df.dateStyle = .full
            df.timeStyle = .none
            return df.string(from: anchorDate)
        }
    }

    private func formattedDay(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateStyle = .medium
        return df.string(from: d)
    }

    // MARK: - Bestehende einfache Kalenderansicht (nicht mehr genutzt, aber belassen)
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
                                EventCard(
                                    event: event,
                                    onTap: { event in
                                        selectedEventForDetails = event
                                    }
                                )
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button {
                                        pendingAction = .edit(event)
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        pendingAction = .delete(event)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                                .confirmationDialog(
                                    pendingAction?.title ?? "",
                                    isPresented: Binding(
                                        get: { pendingAction?.eventId == event.id },
                                        set: { if !$0 { pendingAction = nil } }
                                    ),
                                    titleVisibility: .visible
                                ) {
                                    Button("Bestätigen") {
                                        guard let action = pendingAction else { return }
                                        switch action {
                                        case .delete(let e):
                                            Task { await deleteEvent(e) }
                                        case .edit(let e):
                                            editingEvent = e
                                        }
                                        pendingAction = nil
                                    }
                                    Button("Abbrechen", role: .cancel) { 
                                        pendingAction = nil 
                                    }
                                }
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
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayMonth),
              let firstWeekday = calendar.dateComponents([(.weekday)], from: monthInterval.start).weekday,
              let days = calendar.range(of: .day, in: .month, for: displayMonth)
        else {
            return []
        }

        let prefixCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let prefix = Array(repeating: nil as Date?, count: prefixCount)

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
                        listEventRow(event)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .alert(
            "Termin löschen?",
            isPresented: Binding(
                get: {
                    if case .delete = pendingAction {
                        return true
                    }
                    return false
                },
                set: { if !$0 { pendingAction = nil } }
            )
        ) {
            Button("Löschen", role: .destructive) {
                if case .delete(let e) = pendingAction {
                    Task { await deleteEvent(e) }
                }
                pendingAction = nil
            }
            Button("Abbrechen", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            if case .delete(let e) = pendingAction {
                Text("Möchtest du \"\(e.title)\" wirklich löschen?")
            }
        }
    }
    
    @ViewBuilder
    private func listEventRow(_ event: Event) -> some View {
        EventCard(
            event: event,
            onTap: { event in
                selectedEventForDetails = event
            }
        )
        .listRowInsets(
            EdgeInsets(
                top: 8,
                leading: sideInset,
                bottom: 8,
                trailing: sideInset
            )
        )
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingAction = .delete(event)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                editingEvent = event
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
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

    // MARK: - Advanced calendar helpers (arbeiten direkt mit Event)

    private func events(on day: Date) -> [Event] {
        let key = calendar.startOfDay(for: day)
        return filteredEvents
            .filter { calendar.startOfDay(for: $0.starts_at) == key }
            .sorted { $0.starts_at < $1.starts_at }
    }

    private func compactColors(from events: [Event]) -> [Color] {
        var set: [Color] = []
        for e in events {
            let c = color(for: e)
            if !set.contains(where: { $0.description == c.description }) { set.append(c) }
            if set.count == 3 { break }
        }
        return set
    }

    private func color(for event: Event) -> Color {
        if let gid = event.group_id {
            // deterministische Farbe aus UUID
            let hash = gid.uuidString.hashValue
            let idx = abs(hash) % Self.palette.count
            return Self.palette[idx]
        } else {
            return .blue // persönliche Events
        }
    }

    private static let palette: [Color] = [.blue, .green, .red, .orange, .pink, .purple, .teal, .indigo]
}

// MARK: - Preference Key
struct ButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - CalendarViewMode
enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month = "Monat"
    case week = "Woche"
    case day = "Tag"
    var id: String { rawValue }
}

// MARK: - Swipe Modifier used by Month/Week/Day views
private struct SwipeToNavigate: ViewModifier {
    let threshold: CGFloat
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > threshold else { return }
                        if dx < 0 { onSwipeLeft() } else { onSwipeRight() }
                    }
            )
    }
}

private extension View {
    func swipeToNavigate(threshold: CGFloat = 60,
                         onSwipeLeft: @escaping () -> Void,
                         onSwipeRight: @escaping () -> Void) -> some View {
        modifier(SwipeToNavigate(threshold: threshold, onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}

// MARK: - Advanced Month View (Events-basiert)
private struct MonthGridView: View {
    let calendar: Calendar
    @Binding var anchorDate: Date
    @Binding var selectedDate: Date?
    let today: Date

    let eventsProvider: (Date) -> [Event]
    let colorsProvider: ([Event]) -> [Color]
    var onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            weekdayRow
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(calendar.datesForMonthGrid(containing: anchorDate), id: \.self) { date in
                    let dayEvents = eventsProvider(date)
                    MonthDayCell(
                        calendar: calendar,
                        date: date,
                        anchorMonth: anchorDate,
                        today: today,
                        eventsCount: dayEvents.count,
                        eventColors: colorsProvider(dayEvents),
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    )
                    .onTapGesture {
                        selectedDate = date
                        onSelect(date)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }

    private var weekdayRow: some View {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateFormat = "EE"

        let base = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: base) }
        let rotated = rotateToFirstWeekday(week)

        return HStack {
            ForEach(rotated, id: \.self) { d in
                let isTodayWeekday = calendar.component(.weekday, from: d) == calendar.component(.weekday, from: today)
                Text(df.string(from: d))
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(.blue)
                    .background(isTodayWeekday ? AnyView(Capsule().fill(.ultraThinMaterial)) : AnyView(EmptyView()))
            }
        }
    }

    private func rotateToFirstWeekday(_ days: [Date]) -> [Date] {
        if let idx = days.firstIndex(where: { calendar.component(.weekday, from: $0) == calendar.firstWeekday }) {
            return Array(days[idx...]) + Array(days[..<idx])
        }
        return days
    }
}

// MARK: - Advanced Week View (Events-basiert)
private struct WeekGridView: View {
    let calendar: Calendar
    @Binding var anchorDate: Date
    @Binding var selectedDate: Date?
    let today: Date

    let eventsProvider: (Date) -> [Event]
    let colorsProvider: ([Event]) -> [Color]
    var onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Diese Woche").font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(calendar.weekDates(containing: anchorDate), id: \.self) { date in
                    let dayEvents = eventsProvider(date)
                    VStack(spacing: 8) {
                        Text(shortWeekday(date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(isTodayWeekday(date) ? AnyView(Capsule().fill(.ultraThinMaterial)) : AnyView(EmptyView()))

                        WeekDayPill(
                            calendar: calendar,
                            date: date,
                            today: today,
                            eventsCount: dayEvents.count,
                            eventColors: colorsProvider(dayEvents),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        )
                    }
                    .onTapGesture {
                        selectedDate = date
                        onSelect(date)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 6)
    }

    private func shortWeekday(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateFormat = "EE"
        return df.string(from: d)
    }

    private func isTodayWeekday(_ d: Date) -> Bool {
        calendar.component(.weekday, from: d) == calendar.component(.weekday, from: today)
    }
}

// MARK: - Advanced Day View (Events-basiert)
private struct DayScheduleView: View {
    let calendar: Calendar
    @Binding var anchorDate: Date
    let eventsForDay: (Date) -> [Event]
    var onAdd: () -> Void

    private let hourHeight: CGFloat = 54
    private let leftRailWidth: CGFloat = 52
    private let eventSpacing: CGFloat = 4
    private let contentInset: CGFloat = 8

    var body: some View {
        let events = eventsForDay(anchorDate)
        let layout = DayEventLayout(events: events, calendar: calendar)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(anchorDate)).font(.title3.weight(.semibold))
                    Text("Heute: \(dayTitle(Date()))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Termin hinzufügen")
            }
            .padding(.horizontal)

            ScrollViewReader { proxy in
                ScrollView {
                    GeometryReader { geo in
                        let fullHeight = hourHeight * 24
                        let startX = contentInset + leftRailWidth
                        let endX = geo.size.width - contentInset
                        let totalWidth = endX - startX

                        ZStack(alignment: .topLeading) {

                            Path { p in
                                for h in 0...24 {
                                    let y = CGFloat(h) * hourHeight
                                    p.move(to: CGPoint(x: startX, y: y))
                                    p.addLine(to: CGPoint(x: endX, y: y))
                                }
                            }
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)

                            Path { p in
                                for h in 0..<24 {
                                    let y = CGFloat(h) * hourHeight + hourHeight * 0.5
                                    p.move(to: CGPoint(x: startX, y: y))
                                    p.addLine(to: CGPoint(x: endX, y: y))
                                }
                            }
                            .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            ForEach(0..<24, id: \.self) { hour in
                                let y = CGFloat(hour) * hourHeight

                                Text(String(format: "%02d:00", hour))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: leftRailWidth - 8, alignment: .trailing)
                                    .position(x: contentInset + (leftRailWidth - 8) / 2, y: y + 8)

                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .position(x: 1, y: y)
                                    .id(hour)
                            }

                            ForEach(layout.items) { item in
                                let columnWidth = (totalWidth - CGFloat(item.columns - 1) * eventSpacing) / CGFloat(item.columns)
                                let x = startX + CGFloat(item.column) * (columnWidth + eventSpacing)

                                let y = layout.yOffset(for: item.event, hourHeight: hourHeight)
                                let h = layout.height(for: item.event, hourHeight: hourHeight)

                                EventBlock(
                                    event: item.event,
                                    calendar: calendar,
                                    width: columnWidth,
                                    height: max(h, 22)
                                )
                                .offset(x: x, y: y)
                            }
                        }
                        .frame(height: fullHeight)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .onAppear {
                    let todaysEvents = eventsForDay(anchorDate)
                    if let first = todaysEvents.first {
                        let hour = calendar.component(.hour, from: first.starts_at)
                        withAnimation { proxy.scrollTo(hour, anchor: .top) }
                    } else if calendar.isDate(anchorDate, inSameDayAs: Date()) {
                        let currentHour = calendar.component(.hour, from: Date())
                        withAnimation { proxy.scrollTo(currentHour, anchor: .top) }
                    }
                }
            }
        }
    }

    private func dayTitle(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateStyle = .full
        return df.string(from: d)
    }
}

// MARK: - Day Layout Helpers (Events)
private struct DayEventLayoutItem: Identifiable {
    let id = UUID()
    let event: Event
    let column: Int
    let columns: Int
}

private struct DayEventLayout {
    let events: [Event]
    let calendar: Calendar
    let items: [DayEventLayoutItem]

    init(events: [Event], calendar: Calendar) {
        self.events = events
        self.calendar = calendar
        self.items = DayEventLayout.computeItems(events: events, calendar: calendar)
    }

    static func overlaps(_ a: Event, _ b: Event) -> Bool {
        return a.starts_at < b.ends_at && a.ends_at > b.starts_at
    }

    static func computeItems(events: [Event], calendar: Calendar) -> [DayEventLayoutItem] {
        let sorted = events.sorted { $0.starts_at < $1.starts_at }
        var clusters: [[Event]] = []

        for e in sorted {
            if var last = clusters.last, last.contains(where: { overlaps($0, e) }) {
                last.append(e)
                clusters[clusters.count - 1] = last
            } else {
                clusters.append([e])
            }
        }

        var result: [DayEventLayoutItem] = []

        for cluster in clusters {
            var columns: [[Event]] = []
            for e in cluster {
                var placed = false
                for colIndex in 0..<columns.count {
                    if !columns[colIndex].contains(where: { overlaps($0, e) }) {
                        columns[colIndex].append(e)
                        result.append(.init(event: e, column: colIndex, columns: 0))
                        placed = true
                        break
                    }
                }
                if !placed {
                    columns.append([e])
                    result.append(.init(event: e, column: columns.count - 1, columns: 0))
                }
            }
            let totalCols = max(columns.count, 1)
            result = result.map { item in
                if cluster.contains(where: { $0.id == item.event.id }) {
                    return .init(event: item.event, column: item.column, columns: totalCols)
                } else {
                    return item
                }
            }
        }

        return result
    }

    func minutesSinceDayStart(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        return max(0, Int(date.timeIntervalSince(start) / 60))
    }

    func yOffset(for event: Event, hourHeight: CGFloat) -> CGFloat {
        let minutes = minutesSinceDayStart(event.starts_at)
        return CGFloat(minutes) / 60.0 * hourHeight
    }

    func height(for event: Event, hourHeight: CGFloat) -> CGFloat {
        let startMin = minutesSinceDayStart(event.starts_at)
        let endMin = minutesSinceDayStart(event.ends_at)
        let duration = max(endMin - startMin, 1)
        return max(CGFloat(duration) / 60.0 * hourHeight - 2, 1)
    }
}

// MARK: - Event Block (Events)
private struct EventBlock: View {
    let event: Event
    let calendar: Calendar
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let color = colorForEvent(event)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(timeRangeString(start: event.starts_at, end: event.ends_at))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private func colorForEvent(_ e: Event) -> Color {
        if let gid = e.group_id {
            let hash = gid.uuidString.hashValue
            let idx = abs(hash) % palette.count
            return palette[idx]
        } else {
            return .blue
        }
    }

    private var palette: [Color] { [.blue, .green, .red, .orange, .pink, .purple, .teal, .indigo] }

    private func timeRangeString(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.timeStyle = .short
        df.dateStyle = .none
        return "\(df.string(from: start))–\(df.string(from: end))"
    }
}

// MARK: - Cells (Month/Week)
private struct MonthDayCell: View {
    let calendar: Calendar
    let date: Date
    let anchorMonth: Date
    let today: Date
    let eventsCount: Int
    let eventColors: [Color]
    let isSelected: Bool

    var body: some View {
        let inCurrentMonth = calendar.isDate(date, equalTo: anchorMonth, toGranularity: .month)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout.weight(isToday ? .bold : .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(inCurrentMonth ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday ? Color.primary.opacity(0.35) : Color.clear, lineWidth: 1)
                )

            if eventsCount > 0 {
                HStack(spacing: 4) {
                    ForEach(Array(eventColors.prefix(3)).indices, id: \.self) { idx in
                        Circle()
                            .fill(eventColors[idx])
                            .frame(width: 6, height: 6)
                    }
                    if eventsCount > eventColors.count {
                        Text("+\(eventsCount - eventColors.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)
            } else {
                Spacer(minLength: 10)
            }
        }
        .padding(8)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .opacity(inCurrentMonth ? 1.0 : 0.55)
    }
}

private struct WeekDayPill: View {
    let calendar: Calendar
    let date: Date
    let today: Date
    let eventsCount: Int
    let eventColors: [Color]
    let isSelected: Bool

    var body: some View {
        let isToday = calendar.isDate(date, inSameDayAs: today)

        VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.headline.weight(isToday ? .bold : .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isToday ? Color.primary.opacity(0.35) : Color.clear, lineWidth: 1)
                )

            if eventsCount > 0 {
                HStack(spacing: 4) {
                    ForEach(Array(eventColors.prefix(3)).indices, id: \.self) { idx in
                        Circle()
                            .fill(eventColors[idx])
                            .frame(width: 6, height: 6)
                    }
                    if eventsCount > eventColors.count {
                        Text("+\(eventsCount - eventColors.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(" ").font(.caption2)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Calendar helpers (datesForMonthGrid/weekDates)
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: self.dateComponents([.year, .month], from: date))!
    }

    func daysInMonth(for date: Date) -> Int {
        self.range(of: .day, in: .month, for: date)!.count
    }

    func firstWeekdayOffset(for monthDate: Date) -> Int {
        let firstDay = startOfMonth(for: monthDate)
        let weekday = self.component(.weekday, from: firstDay)
        return (weekday - self.firstWeekday + 7) % 7
    }

    func datesForMonthGrid(containing date: Date) -> [Date] {
        let monthStart = startOfMonth(for: date)
        let offset = firstWeekdayOffset(for: monthStart)
        let days = daysInMonth(for: monthStart)

        var result: [Date] = []
        result.reserveCapacity(42)

        if offset > 0 {
            for i in stride(from: offset, to: 0, by: -1) {
                if let d = self.date(byAdding: .day, value: -i, to: monthStart) {
                    result.append(d)
                }
            }
        }

        for i in 0..<days {
            if let d = self.date(byAdding: .day, value: i, to: monthStart) {
                result.append(d)
            }
        }

        while result.count < 42 {
            if let last = result.last, let next = self.date(byAdding: .day, value: 1, to: last) {
                result.append(next)
            } else {
                break
            }
        }

        return result
    }

    func weekDates(containing date: Date) -> [Date] {
        let start = self.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: start) }
    }
}

// MARK: - Event Action Sheet
private struct EventActionSheet: View {
    let event: Event
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Event Info
            Text(event.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button {
                    onEdit()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Bearbeiten")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))

                Divider()
                    .padding(.leading, 56)

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Text("Löschen")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Event Details Sheet
private struct EventDetailsSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header mit Dismiss Button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 20) {
                    // Event Titel
                    Text(event.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    // Zeit Info Card
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Zeitraum")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formattedTimeRange)
                                .font(.body.weight(.medium))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Details
                    if let details = event.details, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundStyle(.blue)
                                Text("Details")
                                    .font(.headline)
                            }
                            
                            Text(details)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(Color(.systemBackground))
    }

    private var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current

        let start = formatter.string(from: event.starts_at)

        formatter.dateStyle = .none
        let end = formatter.string(from: event.ends_at)

        return "\(start) - \(end)"
    }
}

// MARK: - PendingEventAction
private enum PendingEventAction: Identifiable, Equatable {
    case delete(Event)
    case edit(Event)

    var id: String {
        switch self {
        case .delete(let e): return "delete-\(e.id)"
        case .edit(let e):   return "edit-\(e.id)"
        }
    }

    var eventId: Event.ID {
        switch self {
        case .delete(let e), .edit(let e): return e.id
        }
    }

    var title: String {
        switch self {
        case .delete(let e): return "\"\(e.title)\" löschen?"
        case .edit(let e):   return "\"\(e.title)\" bearbeiten?"
        }
    }
    
    static func == (lhs: PendingEventAction, rhs: PendingEventAction) -> Bool {
        lhs.id == rhs.id
    }
}
