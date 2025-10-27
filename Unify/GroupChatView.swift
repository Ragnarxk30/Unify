import SwiftUI

struct GroupChatView: View {
    @StateObject private var viewModel: GroupChatViewModel
    @State private var composing: String = ""
    @State private var showEventEditor = false

    init(group: CKGroup) {
        _viewModel = StateObject(wrappedValue: GroupChatViewModel(group: group))
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.messages) { msg in
                    ChatMessageRow(message: msg)
                }
            }
            .listStyle(.plain)

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Nachricht schreiben…", text: $composing, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    showEventEditor = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                }
                .padding(.horizontal, 4)

                Button {
                    let text = composing
                    composing = ""
                    Task { await viewModel.send(text: text) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                }
                .disabled(composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.all, 10)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GroupCalendarView(group: viewModel.group)
                } label: {
                    Label("Kalender", systemImage: "calendar")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showEventEditor) {
            EventEditorView { title, start, end, allDay in
                Task {
                    // Termin im Gruppen-Kalender anlegen (InMemory-Repo)
                    let repo = InMemoryCloudKitRepository()
                    let cal = try? await repo.fetchCalendar(for: viewModel.group.id)
                    if let cal {
                        let ev = CKEvent(id: UUID().uuidString,
                                         calendarID: cal.id,
                                         title: title,
                                         notes: nil,
                                         startDate: start,
                                         endDate: end,
                                         allDay: allDay,
                                         createdByUserID: "me")
                        try? await repo.createEvent(ev)
                    }
                    await viewModel.load()
                }
            }
        }
    }
}

private struct ChatMessageRow: View {
    let message: CKChatMessage

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(senderName(message.senderUserID))
                        .font(.subheadline).bold()
                    Spacer()
                    Text(Self.timeString(message.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
            }
        }
        .padding(.vertical, 4)
    }

    private func senderName(_ id: String) -> String {
        id == "me" ? "Ich" : "User \(id.prefix(4))"
    }

    private static func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }
}

#Preview {
    NavigationStack {
        GroupChatView(group: .init(id: "g1", name: "Familie", ownerUserID: "me"))
    }
}
