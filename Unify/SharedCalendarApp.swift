import SwiftUI

@main
struct SharedCalendarApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                if session.isSignedIn {
                    RootTabView()
                } else {
                    // LoginView ruft onSuccess nach erfolgreichem Login
                    LoginView {
                        session.markSignedIn() // optional, Polling würde es sonst selbst merken
                    }
                }
            }
            .environmentObject(session)
        }
    }
}
