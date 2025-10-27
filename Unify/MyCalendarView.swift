import SwiftUI

struct MyCalendarView: View {
    @StateObject var viewModel: MyCalendarViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Lade…")
                } else if let error = viewModel.error {
                    Text("Fehler: \(error)")
                } else if viewModel.events.isEmpty {
                    ContentUnavailableView("Keine Termine", systemImage: "calendar.badge.exclamationmark", description: Text("Lege deinen ersten Termin an oder trete einer Gruppe bei."))
                } else {
                    List(viewModel.events) { ev in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ev.title).font(.headline)
                            Text(dateRange(ev.startDate, ev.endDate)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mein Kalender")
            .task { await viewModel.load() }
        }
    }

    private func dateRange(_ start: Date, _ end: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "\(df.string(from: start)) – \(df.string(from: end))"
    }
}

#Preview {
    MyCalendarView(viewModel: MyCalendarViewModel())
}
