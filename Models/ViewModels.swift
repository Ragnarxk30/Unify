import Foundation
import Combine
import SwiftUI

// MARK: - CalendarViewModel
// Hält die persönlichen (nicht gruppenbezogenen) Termine für den "Mein Kalender"-Tab.
// Die Daten kommen hier aus MockData und werden beim Start sortiert.
final class CalendarViewModel: ObservableObject {
    // Published, damit die UI automatisch aktualisiert, wenn sich die Liste ändert.
    @Published var events: [Event] = MockData.myEvents.sorted(by: { $0.start < $1.start })
}

// MARK: - GroupsViewModel
// Zentrale Quelle für Gruppen, inklusive deren Events und Chat-Nachrichten.
// Alle Mutationen (Gruppe erstellen, Event hinzufügen, Nachricht senden) laufen hier zusammen,
// damit Views (Gruppenliste, Gruppenkalender, Gruppenchat) synchron bleiben.
final class GroupsViewModel: ObservableObject {
    // Alle Gruppen, initial mit Mock-Daten befüllt.
    @Published var groups: [Group] = MockData.groups

    // Central color manager for consistent bubble colors across the app.
    let colorManager = ColorManager()

    // Erstellt eine neue Gruppe mit optionalem Namen und (später) eingeladenen Nutzern.
    // Aktuell werden die eingeladenen Apple IDs noch nicht verwendet (nur Demo). ::::(
    func createGroup(name: String, invited: [String]) {
        let newID = UUID()
        let new = Group(
            id: newID,
            name: name.isEmpty ? "Neue Gruppe" : name,
            owner: MockData.me,
            members: [MockData.me],
            events: [],
            messages: []
        )
        groups.append(new)
    }

    // Fügt einer Gruppe (identifiziert über groupID) eine Chat-Nachricht hinzu.
    // Sender ist in den Mock-Daten "Ich". ¡¡¡¡¡¡:(
    func addMessage(_ text: String, to groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let msg = Message(id: UUID(), sender: MockData.me, text: text, sentAt: Date())
        groups[idx].messages.append(msg)
    }

    // Fügt einer Gruppe einen neuen Termin hinzu und sortiert die Terminliste anschließend.
    func addEvent(title: String, start: Date, end: Date, to groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let ev = Event(id: UUID(), title: title, start: start, end: end, groupID: groupID)
        groups[idx].events.append(ev)
        groups[idx].events.sort { $0.start < $1.start }
    }
}

// MARK: - ChatViewModel
// ViewModel für einen einzelnen Gruppenchat-Screen.
// Kapselt Zugriff auf eine konkrete Gruppe und delegiert Mutationen an GroupsViewModel,
// damit alle anderen Views (z. B. Gruppenliste) konsistent bleiben.
final class ChatViewModel: ObservableObject {
    // Lokale Kopie der Gruppe, die angezeigt wird (inkl. Nachrichten).
    // Wird über refreshFromStore() mit dem zentralen Store synchronisiert.
    @Published var group: Group

    // Referenz auf den zentralen Store (GroupsViewModel), um Nachrichten hinzuzufügen usw.
    private var groupsVM: GroupsViewModel

    // Expose color manager for views
    var colorManager: ColorManager { groupsVM.colorManager }

    // Initialisiert den Chat mit einer bestehenden Gruppe und dem zentralen Store.
    init(group: Group, groupsVM: GroupsViewModel) {
        self.group = group
        self.groupsVM = groupsVM
    }

    // Holt die aktuelle Version der Gruppe aus dem zentralen Store.
    // Aufrufen, wenn sich der Store geändert haben könnte (z. B. nach dem Senden).
    func refreshFromStore() {
        if let updated = groupsVM.groups.first(where: { $0.id == group.id }) {
            group = updated
        }
    }

    // Sendet eine Chat-Nachricht (wenn nicht leer) und synchronisiert anschließend die Anzeige.
    func send(text: String) {
        // Leere oder nur aus Leerzeichen bestehende Nachrichten ignorieren.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Nachricht im zentralen Store hinzufügen (damit alle Views dieselbe Quelle haben).
        groupsVM.addMessage(text, to: group.id)
        // Lokale Gruppe aktualisieren, damit die UI die neue Nachricht sieht.
        refreshFromStore()
    }
}
