import SwiftUI
import Supabase

@main
struct SharedCalendarApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                if session.isSignedIn {
                    RootTabView()
                } else if session.isWaitingForEmailConfirmation {
                    // ✅ Loading Screen während Bestätigung
                    EmailConfirmationLoadingView()
                } else {
                    LoginView {
                        // Beim SignUp: session.setWaitingForEmailConfirmation(true) 
                    }
                }
            }
            .environmentObject(session)
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if url.scheme == "unify" && url.host == "auth-callback" {
            print("Auth callback received: \(url)")
            
            Task {
                do {
                    try await supabase.auth.session(from: url)
                    print("✅ Auth erfolgreich verarbeitet")
                    
                    await session.refreshSession()
                    // ✅ Bestätigung abgeschlossen - Loading beenden
                    session.setWaitingForEmailConfirmation(false)
                    
                } catch {
                    print("❌ Auth Fehler: \(error)")
                    session.setWaitingForEmailConfirmation(false)
                }
            }
        }
    }
}
