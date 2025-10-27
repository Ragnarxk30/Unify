import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MyCalendarView(viewModel: MyCalendarViewModel())
                .tabItem {
                    Label("Mein Kalender", systemImage: "calendar")
                }

            GroupsListView(viewModel: GroupsViewModel())
                .tabItem {
                    Label("Gruppen", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
}
