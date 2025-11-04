import SwiftUI

struct RootTabView: View {
    @StateObject private var calendarVM = CalendarViewModel()
    @StateObject private var groupsVM = GroupsViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                CalendarListView(vm: calendarVM)
            }
            .tabItem { Label("Mein Kalender", systemImage: "calendar") }

            NavigationStack {
                GroupsView(vm: groupsVM)
            }
            .tabItem { Label("Gruppen", systemImage: "person.3") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
    }
}
