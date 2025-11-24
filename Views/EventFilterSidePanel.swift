import SwiftUI

struct EventFilterSidePanel: View {
    @Binding var scope: CalendarFilterScope
    let allGroups: [AppGroup]
    @Binding var selectedGroupIDs: Set<UUID>

    private var currentGroupTitle: String {
        if let id = selectedGroupIDs.first,
           let group = allGroups.first(where: { $0.id == id }) {
            return group.name
        } else {
            return "Alle Gruppen"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Spacer()
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 8)

            Text("Filter")
                .font(.headline)
                .padding(.horizontal)

            filterRow(
                title: "Alle",
                icon: "circle.grid.3x3.fill",
                targetScope: .all
            )

            filterRow(
                title: "Nur persönliche",
                icon: "person.fill",
                targetScope: .personalOnly
            )

            filterRow(
                title: "Nur Gruppen",
                icon: "person.3.fill",
                targetScope: .groupsOnly
            )

            if scope == .groupsOnly && !allGroups.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gruppe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Menu {
                        Button("Alle Gruppen") {
                            print("🔧 Auswahl: Alle Gruppen")
                            selectedGroupIDs.removeAll()
                        }

                        ForEach(allGroups) { group in
                            Button(group.name) {
                                print("🔧 Auswahl Gruppe:", group.name)
                                selectedGroupIDs = [group.id]
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentGroupTitle)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 20)
        .onAppear {
            print("🔍 EventFilterSidePanel.onAppear")
            print("   scope =", scope)
            print("   allGroups count =", allGroups.count)
            print("   selectedGroupIDs =", selectedGroupIDs)
        }
    }

    private func filterRow(
        title: String,
        icon: String,
        targetScope: CalendarFilterScope
    ) -> some View {
        Button {
            print("🔧 Filter scope geändert →", targetScope)
            scope = targetScope
            if targetScope != .groupsOnly {
                selectedGroupIDs.removeAll()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .opacity(scope == targetScope ? 1 : 0)
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
