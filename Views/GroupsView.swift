import SwiftUI

struct GroupsView: View {
    @ObservedObject var vm: GroupsViewModel
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(vm.groups) { group in
                    GroupRow(group: group, groupsVM: vm)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gruppen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet { name, _ids in
                // vm.createGroup(name: name, invited: _ids)
                // V1: nur Gruppe erstellen (Einladungen folgen später)
                Task {
                    do {
                        try await SupabaseGroupRepository().create(name: name, invitedAppleIds: _ids)
                    } catch {
                        print("Fehler beim Erstellen der Gruppe:", error.localizedDescription)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct GroupRow: View {
    let group: Group
    @ObservedObject var groupsVM: GroupsViewModel

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name).font(.title3).bold()
                    Text("Owner: \(group.owner.displayName == "Ich" ? "me" : group.owner.displayName)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                NavigationLink {
                    GroupCalendarScreen(groupID: group.id, groupsVM: groupsVM)
                } label: {
                    Label("Kalender", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    GroupChatScreen(group: group, groupsVM: groupsVM)
                } label: {
                    Label("Chat", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }
}

private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var invited: String = ""

    let onCreate: (String, [String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Neue Gruppe erstellen").font(.title).bold()
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname").font(.headline)
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Benutzer einladen").font(.headline)
                TextField("Apple IDs (durch Komma getrennt)", text: $invited)
                    .textFieldStyle(.roundedBorder)
                Text("Mehrere Apple IDs mit Komma trennen")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button {
                    onCreate(name, invited.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                    dismiss()
                } label: { Text("Gruppe erstellen") }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
}
