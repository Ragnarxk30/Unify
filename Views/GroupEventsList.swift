import SwiftUI

struct GroupEventsList: View {
    let groupID: UUID

    @State private var events: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Swipe State
    @State private var swipedEventId: UUID?
    @State private var cardOffsets: [UUID: CGFloat] = [:]

    // Edit/Delete State
    @State private var editingEvent: Event?
    @State private var showEditSheet = false
    @State private var eventToDelete: Event?
    @State private var showDeleteConfirmation = false

    // Group Info
    @State private var currentGroup: AppGroup?

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if events.isEmpty {
                emptyState
            } else {
                eventsList
            }
        }
        .task {
            await loadGroupEvents()
            await loadGroupInfo()
        }
        .refreshable {
            await loadGroupEvents()
        }
        .sheet(isPresented: $showEditSheet) {
            if let event = editingEvent {
                EditEventView(event: event) {
                    Task { await loadGroupEvents() }
                }
                .presentationDetents([.medium])
            }
        }
        .alert("Termin löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {
                eventToDelete = nil
            }
            Button("Löschen", role: .destructive) {
                if let event = eventToDelete {
                    Task { await deleteEvent(event) }
                }
            }
        } message: {
            if let event = eventToDelete {
                Text("Möchtest du \"\(event.title)\" wirklich löschen?")
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Lade Termine...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Keine Gruppentermine")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Erstelle den ersten Termin für diese Gruppe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Events List
    private var eventsList: some View {
        List {
            Section {
                ForEach(groupedEvents.keys.sorted(by: <), id: \.self) { date in
                    Section {
                        ForEach(groupedEvents[date] ?? []) { event in
                            eventRow(event)
                        }
                    } header: {
                        Text(formatDateHeader(date))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Event Row with Swipe
    private func eventRow(_ event: Event) -> some View {
        ZStack(alignment: .trailing) {
            EventCard(
                event: event,
                group: currentGroup,
                onTap: { _ in
                    // Optional: Show event details
                }
            )
            .offset(x: cardOffsets[event.id] ?? 0)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        if gesture.translation.width < -50 {
                            // Swipe Left → Delete
                            swipedEventId = event.id

                            withAnimation(.easeOut(duration: 0.1)) {
                                cardOffsets[event.id] = -12
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    cardOffsets[event.id] = 0
                                }
                            }

                            // Auto-dismiss after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if swipedEventId == event.id {
                                        swipedEventId = nil
                                    }
                                }
                            }

                        } else if gesture.translation.width > 20 {
                            // Swipe Right → Edit
                            swipedEventId = nil

                            withAnimation(.easeOut(duration: 0.1)) {
                                cardOffsets[event.id] = 8
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    cardOffsets[event.id] = 0
                                }
                            }
                        }
                    }
            )

            // Action Button (Delete or Edit)
            Button {
                if swipedEventId == event.id {
                    // Delete action
                    eventToDelete = event
                    showDeleteConfirmation = true
                    swipedEventId = nil
                } else {
                    // Edit action
                    editingEvent = event
                    showEditSheet = true
                }
            } label: {
                Image(systemName: swipedEventId == event.id ? "trash.fill" : "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(swipedEventId == event.id ? Color.red : Color.blue)
                            .shadow(
                                color: (swipedEventId == event.id ? Color.red : Color.blue).opacity(0.25),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(12)
            .zIndex(1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: swipedEventId)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowBackground(Color.clear)
    }

    // MARK: - Grouped Events
    private var groupedEvents: [Date: [Event]] {
        Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.starts_at)
        }
    }

    // MARK: - Date Formatting
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Heute"
        } else if calendar.isDateInTomorrow(date) {
            return "Morgen"
        } else if calendar.isDate(date, equalTo: now.addingTimeInterval(-86400), toGranularity: .day) {
            return "Gestern"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "EEEE, dd. MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Data Loading
    private func loadGroupEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            let repo = SupabaseEventRepository()
            let allEvents = try await repo.listUserEvents()

            await MainActor.run {
                events = allEvents
                    .filter { $0.group_id == groupID }
                    .sorted { $0.starts_at < $1.starts_at }
                isLoading = false
            }

            print("✅ Gruppentermine geladen: \(events.count) Events")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            print("❌ Fehler beim Laden der Gruppentermine: \(error)")
        }
    }

    private func loadGroupInfo() async {
        do {
            let groupRepo = SupabaseGroupRepository()
            let groups = try await groupRepo.fetchGroups()
            await MainActor.run {
                currentGroup = groups.first { $0.id == groupID }
            }
        } catch {
            print("❌ Fehler beim Laden der Gruppeninfo: \(error)")
        }
    }

    // MARK: - Delete Event
    private func deleteEvent(_ event: Event) async {
        do {
            let repo = SupabaseEventRepository()
            try await repo.delete(eventId: event.id)

            await MainActor.run {
                withAnimation(.easeInOut) {
                    events.removeAll { $0.id == event.id }
                }
                eventToDelete = nil
            }

            print("✅ Termin gelöscht: \(event.title)")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("❌ Fehler beim Löschen: \(error)")
        }
    }
}
