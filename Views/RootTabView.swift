import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                CalendarListView() // ✅ Ohne ViewModel
            }
            .tabItem { Label("Mein Kalender", systemImage: "calendar") }

            NavigationStack {
                GroupsView() // ✅ Ohne ViewModel
            }
            .tabItem { Label("Gruppen", systemImage: "person.3") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("🔄 Scene Phase Wechsel: \(String(describing: oldPhase)) → \(String(describing: newPhase))")

            // ✅ Einfach: App offen = aktiv, App zu = inaktiv
            switch newPhase {
            case .active:
                sessionStore.isAppActive = true
                print("✅ ✅ ✅ APP AKTIV - KEIN TIMEOUT ✅ ✅ ✅")
            case .background:
                sessionStore.isAppActive = false
                sessionStore.recordActivity() // Timestamp wenn App in Hintergrund geht
                print("⏸️ ⏸️ ⏸️ APP IM HINTERGRUND - TIMEOUT LÄUFT ⏸️ ⏸️ ⏸️")
            case .inactive:
                print("⚠️ App inactive (z.B. Control Center geöffnet)")
            @unknown default:
                break
            }
        }
    }
}
