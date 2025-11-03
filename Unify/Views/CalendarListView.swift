import SwiftUI

enum CalendarMode: String, CaseIterable, Hashable {
    case list = "Liste"
    case calendar = "Kalender"
}

struct CalendarListView: View {
    @ObservedObject var vm: CalendarViewModel
    @State private var mode: CalendarMode = .list

    // Einheitlicher Seitenrand für alle Geräte
    private let sideInset: CGFloat = 20

    var body: some View {
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

                    SegmentedToggle(
                        options: CalendarMode.allCases,
                        selection: $mode,
                        title: { $0.rawValue },
                        systemImage: {
                            switch $0 {
                            case .list: return "list.bullet"
                            case .calendar: return "calendar"
                            }
                        }
                    )
                    .layoutPriority(1)
                }
                .padding(.horizontal, sideInset)
                .padding(.top, 8)

                // Inhalt
                if mode == .list {
                    VStack(spacing: 16) {
                        ForEach(vm.events) { event in
                            EventCard(event: event)
                                .frame(maxWidth: .infinity) // füllt den verfügbaren Bereich
                        }
                    }
                    .padding(.horizontal, sideInset) // EINMALIGER Außenabstand links/rechts
                } else {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
