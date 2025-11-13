import SwiftUI

enum GroupDetailTab: String, CaseIterable, Hashable {
    case events = "Termine"
    case chat = "Chat"
}

struct GroupDetailView: View {
    let group: Group
    @State private var selected: GroupDetailTab = .events
    @ObservedObject private var groupsVM: GroupsViewModel

    @State private var showAddEvent = false

    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        VStack(spacing: 0) {
            SegmentedToggle(options: GroupDetailTab.allCases, selection: $selected, title: { $0.rawValue }, systemImage: {
                switch $0 {
                case .events: return "calendar"
                case .chat: return "text.bubble"
                }
            })
            .padding(.horizontal, 20)
            .padding(.top, 12)

            switch selected {
            case .events:
                GroupEventsView(groupID: group.id, groupsVM: groupsVM)
            case .chat:
                GroupChatView(vm: ChatViewModel(group: group, groupsVM: groupsVM))
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neuen Termin anlegen (Demo)")
            }
        }
        .sheet(isPresented: $showAddEvent) {
            // Einfaches Demo-Fenster
            VStack(spacing: 16) {
                Text("Termineingabe kommt")
                    .font(.title3).bold()
                Text("Hier wird später das Formular zum Anlegen eines Termins erscheinen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Schließen") {
                    showAddEvent = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .presentationDetents([.medium])
        }
    }
}


/*
 Code der nachher hinter dem Button Gruppe Umbenennen liegen muss:
 
 Button("Gruppe umbenennen") {
     Task {
         do {
             // rename ausführen
             try await SupabaseGroupRepository()
                 .rename(groupId: group.id, to: newName)

             // Optional: Lokales ViewModel aktualisieren
             if let index = vm.groups.firstIndex(where: { $0.id == group.id }) {
                 vm.groups[index].name = newName
             }

         } catch {
             print("Fehler beim Umbenennen der Gruppe:", error.localizedDescription)
         }
     }
 }
 
 
 //Button für Gruppe löschen noch einbauen dann:
 
 Button("Gruppe löschen") {
     Task {
         do {
             try await SupabaseGroupRepository().delete(groupId: group.id)
         } catch {
             print("Fehler beim Löschen der Gruppe:", error)
         }
     }
 }
 */
