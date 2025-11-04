import SwiftUI

// MARK: - Übersicht aller Gruppen
struct GroupsView: View {
    @ObservedObject var vm: GroupsViewModel       // ViewModel mit allen Gruppen
    @State private var showCreate = false         // Steuerung Sheet "Neue Gruppe"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Jede Gruppe als eigene Zeile
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
        // Sheet für Gruppenerstellung
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet { name, _ids in
                vm.createGroup(name: name, invited: _ids)  // erstellt neue Gruppe im ViewModel
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Einzelne Gruppenzeile
private struct GroupRow: View {
    let group: Group
    @ObservedObject var groupsVM: GroupsViewModel  // Zugriff auf Gruppen

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name).font(.title3).bold()
                    // Zeigt Owner der Gruppe
                    // Wenn Owner == "Ich", wird "me" angezeigt (MockData-/Demo-Logik)
                    Text("Owner: \(group.owner.displayName == "Ich" ? "me" : group.owner.displayName)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Navigation zu Kalender und Chat
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
        .cardStyle()  // eigene Kartenoptik
    }
}

// MARK: - Sheet für Gruppenerstellung
private struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""         // Gruppenname
    @State private var invited: String = ""      // Eingeladene Benutzer (Textfeld)

    let onCreate: (String, [String]) -> Void     // Callback bei Erstellung

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Neue Gruppe erstellen").font(.title).bold()
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }

            // Gruppenname
            VStack(alignment: .leading, spacing: 8) {
                Text("Gruppenname").font(.headline)
                TextField("z.B. Familiengruppe", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Eingeladene Benutzer
            VStack(alignment: .leading, spacing: 8) {
                Text("Benutzer einladen").font(.headline)
                TextField("Apple IDs (durch Komma getrennt)", text: $invited)
                    .textFieldStyle(.roundedBorder)
                Text("Mehrere Apple IDs mit Komma trennen")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            // Buttons: Abbrechen oder Erstellen
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button {
                    // Aufteilung der Eingaben in Array und Callback
                    onCreate(
                        name,
                        invited.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                    )
                    dismiss()
                } label: { Text("Gruppe erstellen") }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
}
