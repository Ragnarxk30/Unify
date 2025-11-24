//
//  EventFilterSidePanel.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 23.11.25.
//


import SwiftUI

struct EventFilterSidePanel: View {
    @Binding var scope: CalendarFilterScope
    let allGroups: [AppGroup]
    @Binding var selectedGroupIDs: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Grabber
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

            // Haupt-Scopes
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

            // Gruppenauswahl nur bei "Nur Gruppen"
            if scope == .groupsOnly && !allGroups.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gruppen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(allGroups) { group in
                        Button {
                            toggleGroupSelection(group.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedGroupIDs.contains(group.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                Text(group.name)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 20)
    }

    private func filterRow(
        title: String,
        icon: String,
        targetScope: CalendarFilterScope
    ) -> some View {
        Button {
            scope = targetScope
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

    private func toggleGroupSelection(_ id: UUID) {
        if selectedGroupIDs.contains(id) {
            selectedGroupIDs.remove(id)
        } else {
            selectedGroupIDs.insert(id)
        }
    }
}