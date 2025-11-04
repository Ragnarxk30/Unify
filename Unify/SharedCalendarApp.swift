import SwiftUI

@main
struct SharedCalendarApp: App {
    @State private var isLoggedIn: Bool = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                RootTabView()
            } else {
                LoginView {
                    // Wird aufgerufen, wenn der Demo-Login erfolgreich war
                    isLoggedIn = true
                }
            }
        }
    }
}
