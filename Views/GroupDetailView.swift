import SwiftUI

// MARK: - Tabs für Gruppendetails
// Diese Enum legt fest, welche Unteransichten es gibt: Termine oder Chat.
enum GroupDetailTab: String, CaseIterable, Hashable {
    case events = "Termine"
    case chat = "Chat"
}

// MARK: - Detailansicht einer Gruppe
// Zeigt innerhalb einer Gruppe entweder die Terminliste oder den Chat.
struct GroupDetailView: View {
    let group: Group                              // 👉 Das aktuelle Gruppenobjekt
    @State private var selected: GroupDetailTab = .events  // 👉 Aktuell ausgewählter Tab
    @ObservedObject private var groupsVM: GroupsViewModel  // 👉 Zentrales ViewModel für alle Gruppen

    // Steuert, ob das Sheet zum Hinzufügen eines Termins gezeigt wird
    @State private var showAddEvent = false

    // MARK: - Initialisierung
    // Übergibt das Gruppenobjekt und das Gruppen-ViewModel von außen.
    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Umschalter zwischen Tabs
            // Zeigt eine Segmentsteuerung mit "Termine" und "Chat".
            SegmentedToggle(
                options: GroupDetailTab.allCases,  // beide Tabs
                selection: $selected,              // aktuell gewählter Tab
                title: { $0.rawValue },            // Titeltext des Tabs
                systemImage: { tab in              // Icon des Tabs
                    switch tab {
                    case .events: return "calendar"
                    case .chat: return "text.bubble"
                    }
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // MARK: - Inhaltsbereich je nach ausgewähltem Tab
            switch selected {
            case .events:
                // 👉 Zeigt Terminliste der Gruppe
                GroupEventsView(groupID: group.id, groupsVM: groupsVM)

            case .chat:
                // 👉 Zeigt den Chat der Gruppe
                // Hier wird ein neues ChatViewModel erzeugt und an GroupChatView übergeben.
                // ⚠️ WICHTIG:
                // Das ChatViewModel selbst nutzt intern wahrscheinlich MockData,
                // um z. B. Nachrichten oder den aktuellen Benutzer zu füllen.
                GroupChatView(vm: ChatViewModel(group: group, groupsVM: groupsVM)) // 👉 INDIRECT MockData-ZUGRIFF
            }
        }
        // MARK: - Navigation & Layout
        .navigationTitle(group.name)                   // Gruppenname im Titel
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))    // Hintergrundfarbe wie iOS-Listen

        // MARK: - Toolbar (Plus-Button oben rechts)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddEvent = true                 // Sheet anzeigen
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neuen Termin anlegen (Demo)")
            }
        }

        // MARK: - Sheet (Modal zur Termin-Erstellung)
        .sheet(isPresented: $showAddEvent) {
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
            .presentationDetents([.medium]) // mittlere Sheet-Höhe
        }
    }
}
