import SwiftUI

struct GroupMonthlyCalendarView: View {
    let groupID: UUID
    @ObservedObject private var groupsVM: GroupsViewModel

    // Kalenderstatus
    @State private var monthAnchor: Date = Date() // aktueller Monat
    @State private var selectedDay: Date? = nil
    @State private var showDaySheet: Bool = false

    init(groupID: UUID, groupsVM: GroupsViewModel) {
        self.groupID = groupID
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    private var cal: Calendar { Calendar.current }
    private var monthInterval: DateInterval {
        cal.dateInterval(of: .month, for: monthAnchor)!
    }
    private var daysInMonth: [Date] {
        var days: [Date] = []
        var d = monthInterval.start
        while d < monthInterval.end {
            days.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return days
    }
    private var firstWeekdayOffset: Int {
        // Offset von Wochenanfang (abhängig von locale)
        let weekday = cal.component(.weekday, from: monthInterval.start)
        let first = cal.firstWeekday
        // Normalisieren auf 0..6
        return (weekday - first + 7) % 7
    }

    private func events(on day: Date) -> [Event] {
        guard let group = groupsVM.groups.first(where: { $0.id == groupID }) else { return [] }
        return group.events.filter {
            cal.isDate($0.start, inSameDayAs: day) || cal.isDate($0.end, inSameDayAs: day) ||
            ( $0.start < day && day < $0.end && cal.isDate($0.start, equalTo: day, toGranularity: .month))
        }
        .sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Monatstitel + Navigation
            HStack {
                Button {
                    withAnimation { monthAnchor = cal.date(byAdding: .month, value: -1, to: monthAnchor)! }
                } label: { Image(systemName: "chevron.left") }

                Spacer()

                Text(monthTitle(monthAnchor))
                    .font(.title3).bold()

                Spacer()

                Button {
                    withAnimation { monthAnchor = cal.date(byAdding: .month, value: 1, to: monthAnchor)! }
                } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal, 16)

            // Wochentage-Kopf
            let weekdaySymbols = shortWeekdaySymbols()
            HStack {
                ForEach(weekdaySymbols, id: \.self) { wd in
                    Text(wd)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // Grid
            VStack(spacing: 8) {
                // Erste Reihe: leere Offsets
                HStack(spacing: 8) {
                    ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                        Color.clear
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<min(7-firstWeekdayOffset, daysInMonth.count), id: \.self) { i in
                        let day = daysInMonth[i]
                        DayCell(day: day, events: events(on: day)) {
                            selectedDay = day
                            showDaySheet = !events(on: day).isEmpty
                        }
                    }
                }
                // Weitere Reihen
                let remaining = Array(daysInMonth.dropFirst(7-firstWeekdayOffset))
                ForEach(0..<Int(ceil(Double(remaining.count)/7.0)), id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row*7 + col
                            if idx < remaining.count {
                                let day = remaining[idx]
                                DayCell(day: day, events: events(on: day)) {
                                    selectedDay = day
                                    showDaySheet = !events(on: day).isEmpty
                                }
                            } else {
                                Color.clear
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showDaySheet) {
            if let selectedDay {
                DayEventsSheet(date: selectedDay, events: events(on: selectedDay))
                    .presentationDetents([.medium])
            }
        }
    }

    // Helpers
    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date).capitalized
    }

    private func shortWeekdaySymbols() -> [String] {
        // Liefert symbolreihenfolge abhängig von firstWeekday
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? ["Mo","Di","Mi","Do","Fr","Sa","So"]
        // DateFormatter beginnt mit Sonntag; wir drehen entsprechend firstWeekday
        var idx = cal.firstWeekday - 1 // 0..6
        var result: [String] = []
        for _ in 0..<7 {
            result.append(symbols[idx])
            idx = (idx + 1) % 7
        }
        return result
    }
}

private struct DayCell: View {
    let day: Date
    let events: [Event]
    let onTap: () -> Void

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(cal.component(.day, from: day))")
                .font(.subheadline)
                .foregroundStyle(isToday ? .blue : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Marker für Termine
            if !events.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<min(events.count, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                }
            } else {
                Spacer(minLength: 6)
            }
        }
        .padding(8)
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.cardStroke)
        )
        .onTapGesture { onTap() }
    }

    private var isToday: Bool {
        cal.isDateInToday(day)
    }
}

private struct DayEventsSheet: View {
    let date: Date
    let events: [Event]

    var body: some View {
        NavigationStack {
            List {
                ForEach(events) { ev in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ev.title).font(.headline)
                        Text(Self.format(ev.start, ev.end))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(Self.dateTitle(date))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static func dateTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEE, dd.MM.yyyy"
        return df.string(from: date).capitalized
    }

    private static func format(_ start: Date, _ end: Date) -> String {
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
