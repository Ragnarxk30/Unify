import SwiftUI

@main
struct AppRoot: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}

struct RootTabView: View {
    @State private var groupsVM = GroupsOverviewViewModel(groups: SampleData.groups)
    @State private var myCalendarVM = MyCalendarViewModel(events: SampleData.myEvents)

    @State private var path = NavigationPath()

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                GroupsOverviewView(
                    viewModel: groupsVM,
                    onNavigateToChat: { group in
                        let vm = ChatViewModel(group: group, messages: SampleData.messages(for: group))
                        path.append(Route.chat(vm))
                    },
                    onNavigateToCalendar: { group in
                        let vm = GroupCalendarViewModel(group: group, events: SampleData.events(for: group))
                        path.append(Route.calendar(vm))
                    }
                )
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chat(let vm):
                        ChatView(viewModel: vm)
                    case .calendar(let vm):
                        GroupCalendarView(viewModel: vm, onBack: {
                            path.removeLast()
                        })
                    }
                }
            }
            .tabItem {
                Label("Gruppen", systemImage: "person.3")
            }

            MyCalendarView(viewModel: myCalendarVM)
                .tabItem {
                    Label("Mein Kalender", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
        }
    }

    enum Route: Hashable {
        case chat(ChatViewModel)
        case calendar(GroupCalendarViewModel)
    }
}

// MARK: - Sample Data

enum SampleData {
    static let groups: [Group] = [
        Group(name: "Familie", lastMessage: "Bis später!", unreadCount: 2, owner: "Anna"),
        Group(name: "Freunde", lastMessage: "Kino heute?", unreadCount: 0, owner: "Max"),
        Group(name: "Verein", lastMessage: "Training um 18:00", unreadCount: 5, owner: "Julia")
    ]

    static func messages(for group: Group) -> [Message] {
        [
            Message(userId: "1", userName: "Anna", content: "Hallo zusammen!", timestamp: Date().addingTimeInterval(-3600), isCurrentUser: false),
            Message(userId: "current", userName: "Ich", content: "Hi!", timestamp: Date().addingTimeInterval(-3500), isCurrentUser: true),
            Message(userId: "2", userName: "Max", content: "Wie geht's?", timestamp: Date().addingTimeInterval(-3400), isCurrentUser: false)
        ]
    }

    static func events(for group: Group) -> [CalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            CalendarEvent(groupId: group.id, groupName: group.name, title: "Meeting", description: "Planung", date: today, startTime: "09:00", endTime: "10:00"),
            CalendarEvent(groupId: group.id, groupName: group.name, title: "Abendessen", description: nil, date: today.addingTimeInterval(86400), startTime: "19:00", endTime: "21:00")
        ]
    }

    static let myEvents: [CalendarEvent] = {
        let today = Calendar.current.startOfDay(for: Date())
        let g1 = groups[0]
        return [
            CalendarEvent(groupId: g1.id, groupName: g1.name, title: "Familienrunde", description: "Wichtig", date: today, startTime: "18:00", endTime: "19:00"),
            CalendarEvent(groupId: g1.id, groupName: g1.name, title: "Sport", description: nil, date: today.addingTimeInterval(2*86400), startTime: "08:00", endTime: "09:00")
        ]
    }()
}
