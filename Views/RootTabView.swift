import SwiftUI

struct RootTabView: View {
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
    }
}
