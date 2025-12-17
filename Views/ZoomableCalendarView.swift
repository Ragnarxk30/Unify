import SwiftUI

// MARK: - Zoomable Calendar View (iPhone-Style)
struct ZoomableCalendarView: View {
    let events: [Event]
    let calendar: Calendar
    let onAdd: () -> Void

    @State private var zoomLevel: CalendarZoomLevel = .year
    @State private var selectedYear: Date = Date()
    @State private var selectedMonth: Date = Date()
    @State private var selectedDay: Date = Date()
    @State private var slideDirection: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header mit Navigation
            header

            // Content basierend auf Zoom Level
            ZStack {
                currentView
                    .id(viewID)
                    .transition(slideTransition)
            }
            .animation(.easeInOut(duration: 0.3), value: viewID)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Zurück-Button (nur wenn nicht in Jahr-Ansicht)
            if zoomLevel != .year {
                Button {
                    zoomOut()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.title3.weight(.semibold))
                Text(subtitleText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Heute-Button
            Button {
                jumpToToday()
            } label: {
                Text("Heute")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Navigation Buttons
            Button {
                slideDirection = -1
                navigateBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Button {
                slideDirection = +1
                navigateForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Views für verschiedene Zoom Levels

    @ViewBuilder
    private var currentView: some View {
        switch zoomLevel {
        case .year:
            YearGridView(
                calendar: calendar,
                year: selectedYear,
                eventsProvider: eventsIn(month:),
                onSelectMonth: { month in
                    selectedMonth = month
                    zoomLevel = .month
                }
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    selectedYear = calendar.date(byAdding: .year, value: 1, to: selectedYear) ?? selectedYear
                },
                onSwipeRight: {
                    slideDirection = -1
                    selectedYear = calendar.date(byAdding: .year, value: -1, to: selectedYear) ?? selectedYear
                }
            )

        case .month:
            MonthGridView(
                calendar: calendar,
                month: selectedMonth,
                today: Date(),
                eventsProvider: eventsOn(day:),
                onSelectDay: { day in
                    selectedDay = day
                    zoomLevel = .day
                }
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                },
                onSwipeRight: {
                    slideDirection = -1
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            )

        case .day:
            DayScheduleViewZoomable(
                calendar: calendar,
                day: selectedDay,
                events: eventsOn(day: selectedDay),
                onAdd: onAdd
            )
            .swipeToNavigate(
                onSwipeLeft: {
                    slideDirection = +1
                    selectedDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                },
                onSwipeRight: {
                    slideDirection = -1
                    selectedDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                }
            )
        }
    }

    // MARK: - Helper Functions

    private var viewID: String {
        switch zoomLevel {
        case .year:
            return "year-\(calendar.component(.year, from: selectedYear))"
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: selectedMonth)
            return "month-\(comps.year ?? 0)-\(comps.month ?? 0)"
        case .day:
            let comps = calendar.dateComponents([.year, .month, .day], from: selectedDay)
            return "day-\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        }
    }

    private var slideTransition: AnyTransition {
        let moveIn = slideDirection >= 0 ? AnyTransition.move(edge: .trailing) : AnyTransition.move(edge: .leading)
        let moveOut = slideDirection >= 0 ? AnyTransition.move(edge: .leading) : AnyTransition.move(edge: .trailing)
        return .asymmetric(insertion: moveIn.combined(with: .opacity), removal: moveOut.combined(with: .opacity))
    }

    private var titleText: String {
        switch zoomLevel {
        case .year:
            return "\(calendar.component(.year, from: selectedYear))"
        case .month:
            let df = DateFormatter()
            df.locale = calendar.locale
            df.dateFormat = "LLLL yyyy"
            return df.string(from: selectedMonth).capitalized
        case .day:
            let df = DateFormatter()
            df.locale = calendar.locale
            df.dateStyle = .full
            return df.string(from: selectedDay)
        }
    }

    private var subtitleText: String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateStyle = .medium
        return "Heute: \(df.string(from: Date()))"
    }

    private func zoomOut() {
        slideDirection = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            switch zoomLevel {
            case .day:
                zoomLevel = .month
            case .month:
                zoomLevel = .year
            case .year:
                break
            }
        }
    }

    private func jumpToToday() {
        slideDirection = 0
        let today = Date()
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedYear = today
            selectedMonth = today
            selectedDay = today

            if zoomLevel == .year {
                // Bleibe in Jahr-Ansicht
            } else {
                // Gehe zu Tag-Ansicht
                zoomLevel = .day
            }
        }
    }

    private func navigateBackward() {
        switch zoomLevel {
        case .year:
            selectedYear = calendar.date(byAdding: .year, value: -1, to: selectedYear) ?? selectedYear
        case .month:
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        case .day:
            selectedDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        }
    }

    private func navigateForward() {
        switch zoomLevel {
        case .year:
            selectedYear = calendar.date(byAdding: .year, value: 1, to: selectedYear) ?? selectedYear
        case .month:
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        case .day:
            selectedDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        }
    }

    // MARK: - Event Helpers

    private func eventsOn(day: Date) -> [Event] {
        let dayStart = calendar.startOfDay(for: day)
        return events
            .filter { calendar.startOfDay(for: $0.starts_at) == dayStart }
            .sorted { $0.starts_at < $1.starts_at }
    }

    private func eventsIn(month: Date) -> Int {
        let monthStart = calendar.startOfMonth(for: month)
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }

        return events.filter { event in
            let eventDay = calendar.startOfDay(for: event.starts_at)
            return eventDay >= calendar.startOfDay(for: monthStart) &&
                   eventDay <= calendar.startOfDay(for: monthEnd)
        }.count
    }
}

// MARK: - Year Grid View
private struct YearGridView: View {
    let calendar: Calendar
    let year: Date
    let eventsProvider: (Date) -> Int
    let onSelectMonth: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<12, id: \.self) { monthIndex in
                    if let monthDate = monthDate(for: monthIndex) {
                        YearMonthCell(
                            calendar: calendar,
                            month: monthDate,
                            eventCount: eventsProvider(monthDate),
                            isCurrentMonth: calendar.isDate(monthDate, equalTo: Date(), toGranularity: .month)
                        )
                        .onTapGesture {
                            onSelectMonth(monthDate)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func monthDate(for index: Int) -> Date? {
        var components = calendar.dateComponents([.year], from: year)
        components.month = index + 1
        components.day = 1
        return calendar.date(from: components)
    }
}

// MARK: - Year Month Cell
private struct YearMonthCell: View {
    let calendar: Calendar
    let month: Date
    let eventCount: Int
    let isCurrentMonth: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(monthName)
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? .blue : .primary)

            MiniMonthGrid(calendar: calendar, month: month)

            if eventCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                    Text("\(eventCount) Termine")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentMonth ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var monthName: String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.dateFormat = "LLLL"
        return df.string(from: month).capitalized
    }
}

// MARK: - Mini Month Grid (für Jahr-Ansicht)
private struct MiniMonthGrid: View {
    let calendar: Calendar
    let month: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(calendar.datesForMonthGrid(containing: month).prefix(28), id: \.self) { date in
                let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                let isToday = calendar.isDate(date, inSameDayAs: Date())

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 8))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(inMonth ? .primary : .secondary)
                    .background(
                        Circle()
                            .fill(isToday ? Color.blue.opacity(0.3) : Color.clear)
                    )
                    .opacity(inMonth ? 1.0 : 0.3)
            }
        }
    }
}

// MARK: - Month Grid View (für Monats-Zoom)
private struct MonthGridView: View {
    let calendar: Calendar
    let month: Date
    let today: Date
    let eventsProvider: (Date) -> [Event]
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(calendar.datesForMonthGrid(containing: month), id: \.self) { date in
                        let dayEvents = eventsProvider(date)
                        MonthDayCell(
                            calendar: calendar,
                            date: date,
                            month: month,
                            today: today,
                            eventsCount: dayEvents.count,
                            eventColors: compactColors(from: dayEvents)
                        )
                        .onTapGesture {
                            onSelectDay(date)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var weekdayHeader: some View {
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

    private func compactColors(from events: [Event]) -> [Color] {
        var set: [Color] = []
        for e in events {
            let c = colorForEvent(e)
            if !set.contains(where: { $0.description == c.description }) { set.append(c) }
            if set.count == 3 { break }
        }
        return set
    }

    private func colorForEvent(_ e: Event) -> Color {
        if let gid = e.group_id {
            let hash = gid.uuidString.hashValue
            let palette: [Color] = [.blue, .green, .red, .orange, .pink, .purple, .teal, .indigo]
            let idx = abs(hash) % palette.count
            return palette[idx]
        }
        return .blue
    }
}

// MARK: - Month Day Cell
private struct MonthDayCell: View {
    let calendar: Calendar
    let date: Date
    let month: Date
    let today: Date
    let eventsCount: Int
    let eventColors: [Color]

    var body: some View {
        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout.weight(isToday ? .bold : .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(inMonth ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isToday ? Color.blue.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .opacity(inMonth ? 1.0 : 0.5)
    }
}

// MARK: - Day Schedule View (für Tages-Zoom)
private struct DayScheduleViewZoomable: View {
    let calendar: Calendar
    let day: Date
    let events: [Event]
    let onAdd: () -> Void

    private let hourHeight: CGFloat = 54
    private let leftRailWidth: CGFloat = 52
    private let eventSpacing: CGFloat = 4
    private let contentInset: CGFloat = 8

    var body: some View {
        let layout = DayEventLayoutZoomable(events: events, calendar: calendar)

        ScrollViewReader { proxy in
            ScrollView {
                GeometryReader { geo in
                    let fullHeight = hourHeight * 24
                    let startX = contentInset + leftRailWidth
                    let endX = geo.size.width - contentInset
                    let totalWidth = endX - startX

                    ZStack(alignment: .topLeading) {
                        // Hour grid lines
                        Path { p in
                            for h in 0...24 {
                                let y = CGFloat(h) * hourHeight
                                p.move(to: CGPoint(x: startX, y: y))
                                p.addLine(to: CGPoint(x: endX, y: y))
                            }
                        }
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)

                        // Half-hour dashed lines
                        Path { p in
                            for h in 0..<24 {
                                let y = CGFloat(h) * hourHeight + hourHeight * 0.5
                                p.move(to: CGPoint(x: startX, y: y))
                                p.addLine(to: CGPoint(x: endX, y: y))
                            }
                        }
                        .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                        // Hour labels
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

                        // Event blocks
                        ForEach(layout.items) { item in
                            let columnWidth = (totalWidth - CGFloat(item.columns - 1) * eventSpacing) / CGFloat(item.columns)
                            let x = startX + CGFloat(item.column) * (columnWidth + eventSpacing)
                            let y = layout.yOffset(for: item.event, hourHeight: hourHeight)
                            let h = layout.height(for: item.event, hourHeight: hourHeight)

                            EventBlockZoomable(
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
                if let first = events.first {
                    let hour = calendar.component(.hour, from: first.starts_at)
                    withAnimation { proxy.scrollTo(hour, anchor: .top) }
                } else if calendar.isDate(day, inSameDayAs: Date()) {
                    let currentHour = calendar.component(.hour, from: Date())
                    withAnimation { proxy.scrollTo(currentHour, anchor: .top) }
                }
            }
        }
    }
}

// MARK: - Day Event Layout (Zoomable)
private struct DayEventLayoutItemZoomable: Identifiable {
    let id = UUID()
    let event: Event
    let column: Int
    let columns: Int
}

private struct DayEventLayoutZoomable {
    let events: [Event]
    let calendar: Calendar
    let items: [DayEventLayoutItemZoomable]

    init(events: [Event], calendar: Calendar) {
        self.events = events
        self.calendar = calendar
        self.items = DayEventLayoutZoomable.computeItems(events: events, calendar: calendar)
    }

    static func overlaps(_ a: Event, _ b: Event) -> Bool {
        return a.starts_at < b.ends_at && a.ends_at > b.starts_at
    }

    static func computeItems(events: [Event], calendar: Calendar) -> [DayEventLayoutItemZoomable] {
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

        var result: [DayEventLayoutItemZoomable] = []

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

// MARK: - Event Block (Zoomable)
private struct EventBlockZoomable: View {
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
            let palette: [Color] = [.blue, .green, .red, .orange, .pink, .purple, .teal, .indigo]
            let idx = abs(hash) % palette.count
            return palette[idx]
        }
        return .blue
    }

    private func timeRangeString(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = calendar.locale
        df.timeStyle = .short
        df.dateStyle = .none
        return "\(df.string(from: start))–\(df.string(from: end))"
    }
}

// MARK: - Swipe Modifier
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

// MARK: - Calendar Extensions
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
}
