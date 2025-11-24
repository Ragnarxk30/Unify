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
                        calendarPlaceholderView
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            }
        }
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
