import SwiftUI

struct RootTabView: View {
    @State private var calendarVM = CalendarViewModel()
    @State private var groupsVM = GroupsViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                CalendarListView(vm: calendarVM)
            }
            .tabItem {
                Label("Mein Kalender", systemImage: "calendar")
            }

            NavigationStack {
                GroupsView(vm: groupsVM)
            }
            .tabItem {
                Label("Gruppen", systemImage: "person.3")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape")
            }
        }
    }
}
