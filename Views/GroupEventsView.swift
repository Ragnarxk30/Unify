import SwiftUI

struct GroupEventsView: View {
    let groupID: UUID
    @State private var title: String = ""
    @State private var start: Date = Date().addingTimeInterval(3600)
    @State private var end: Date = Date().addingTimeInterval(7200)
    @ObservedObject private var groupsVM: GroupsViewModel

    init(groupID: UUID, groupsVM: GroupsViewModel) {
        self.groupID = groupID
        // WICHTIG: ObservableObject-Initialisierung, kein @Bindable!
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let group = groupsVM.groups.first(where: { $0.id == groupID }) {
                    // Normale Array-Variante (kein $group.events!)
                    ForEach(group.events) { ev in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ev.title)
                                .font(.title3).bold()
                            Text(Self.format(ev.start, ev.end))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .cardStyle()
                    }
                }

                // Eingabebereich für neuen Termin
                VStack(alignment: .leading, spacing: 12) {
                    Text("Neuen Gruppentermin hinzufügen")
                        .font(.headline)

                    TextField("Titel", text: $title)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Start", selection: $start)
                    DatePicker("Ende", selection: $end)

                    Button {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        groupsVM.addEvent(title: trimmed, start: start, end: end, to: groupID)
                        title = ""
                        start = Date().addingTimeInterval(3600)
                        end = Date().addingTimeInterval(7200)
                    } label: {
                        Label("Termin hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cardStroke))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // Lokale Formatierung, um Cross-File-Overloads zu vermeiden
    private static func format(_ start: Date, _ end: Date) -> String {
        let sameDay = Calendar.current.isDate(start, inSameDayAs: end)
        let d = DateFormatter()
        d.locale = .current
        d.dateFormat = "dd.MM.yy, HH:mm"
        if sameDay {
            let t = DateFormatter()
            t.locale = .current
            t.dateFormat = "HH:mm"
            return "\(d.string(from: start)) – \(t.string(from: end))"
        } else {
            return "\(d.string(from: start)) – \(d.string(from: end))"
        }
    }
}
