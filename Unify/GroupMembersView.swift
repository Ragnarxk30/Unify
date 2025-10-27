import SwiftUI

struct GroupMembersView: View {
    let group: CKGroup
    @State private var members: [CKMembership] = []
    @State private var usersByID: [String: CKUser] = [:]
    @State private var isLoading = true
    @State private var error: String?

    private let repo: CloudKitRepository = InMemoryCloudKitRepository()

    var body: some View {
        List {
            if isLoading {
                ProgressView("Lade Mitglieder…")
            } else if let error = error {
                Text("Fehler: \(error)")
            } else if members.isEmpty {
                ContentUnavailableView("Keine Mitglieder", systemImage: "person.2.slash", description: Text("Füge Mitglieder zu dieser Gruppe hinzu."))
            } else {
                ForEach(members) { m in
                    HStack {
                        Text(usersByID[m.userID]?.displayName ?? "Unbekannt")
                        Spacer()
                        Text(roleLabel(m.role))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }
                }
            }
        }
        .navigationTitle("Mitglieder")
        .task { await load() }
    }

    private func roleLabel(_ role: MembershipRole) -> String {
        switch role {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // InMemory: wir bauen Dummy-Mitglieder basierend auf repo.fetchMemberships("me") und filtern nach group
            let all = try await repo.fetchMemberships(for: "me")
            let groupMembers = all.filter { $0.groupID == group.id }
            // plus Owner der Gruppe sicherstellen
            var result = groupMembers
            if result.contains(where: { $0.role == .owner && $0.userID == group.ownerUserID }) == false {
                result.append(.init(id: UUID().uuidString, userID: group.ownerUserID, groupID: group.id, role: .owner))
            }
            members = result

            // Nutzer auflösen – in InMemory haben wir nur "me". Wir legen Dummy-Namen an:
            var dict: [String: CKUser] = ["me": .init(id: "me", displayName: "Ich")]
            dict[group.ownerUserID] = dict[group.ownerUserID] ?? .init(id: group.ownerUserID, displayName: "Owner")
            usersByID = dict
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        GroupMembersView(group: .init(id: "g1", name: "Familie", ownerUserID: "me"))
    }
}
