import SwiftUI

// MARK: - Wrapper-Screen für den Gruppenchat
// Kapselt GroupChatView in einen eigenen Screen, damit wir Navigationstitel
// und Tab-Bar-Verhalten gezielt steuern können, ohne die Chat-View selbst zu „verschmutzen“.
// Vorteile:
// - Eigener Navigationstitel pro Gruppe (z. B. „Familie – Chat“)
// - Tab-Leiste nur im Chat ausblenden (.toolbar(.hidden, for: .tabBar))
// - Klare Trennung: Screen (Navigation/Chrom) vs. Inhalt (GroupChatView)
struct GroupChatScreen: View {
    // Die Gruppe, deren Chat angezeigt wird (wird vom Aufrufer übergeben)
    let group: Group

    // Referenz auf den zentralen Gruppen-Store (für Nachrichten-Senden etc.)
    // Hier als @ObservedObject, weil der Store außerhalb erzeugt wird (z. B. in RootTabView)
    @ObservedObject private var groupsVM: GroupsViewModel

    // Initializer mit Injektion des zentralen Stores.
    // ObservedObject muss über den Property Wrapper-Initializer gesetzt werden.
    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self._groupsVM = ObservedObject(initialValue: groupsVM)
    }

    var body: some View {
        // Inhalt: eigentlicher Chat mit ViewModel (pro Screen erstellt)
        GroupChatView(vm: ChatViewModel(group: group, groupsVM: groupsVM))
            // Navigationstitel: <Gruppenname> – Chat
            // "+ Chat" aus Gruppenname entfehrnt --> LH
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            // Tab-Leiste nur im Chat ausblenden, andere Tabs bleiben unverändert.
            .toolbar(.hidden, for: .tabBar)
    }
}
