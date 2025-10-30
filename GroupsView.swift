import SwiftUI

struct GroupsView: View {
    @Bindable var vm: GroupsViewModel
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(vm.groups) { group in
                    NavigationLink {
                        GroupDetailView(group: group, groupsVM: vm)
                    } label: {
                        GroupRow(group: group)
                    }
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
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet { name, _ids in
                vm.createGroup(name: name, invited: _ids)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct GroupRow: View {
    let group: Group
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name).font(.title3).bold()
                Text("Owner: \(group.owner.displayName == "Ich" ? "me" : group.owner.displayName)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "calendar")
                    Image(systemName: "text.bubble")
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
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
                } label: {
                    Text("Gruppe erstellen")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
}
