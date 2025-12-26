import SwiftUI
import Supabase

@main
struct SharedCalendarApp: App {
    @StateObject private var session = SessionStore()
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App wurde geöffnet/reaktiviert
            session.isAppActive = true
            session.recordActivity()
            print("📱 App aktiv - Aktivität aufgezeichnet")
            
            // Prüfe ob Session noch gültig ist nach Hintergrund
            Task {
                await session.checkInactivityOnResume()
            }
            
        case .inactive:
            // App geht in den Hintergrund (kurz)
            session.recordActivity()
            print("📱 App inaktiv")
            
        case .background:
            // App ist im Hintergrund
            session.isAppActive = false
            session.recordActivity()
            print("📱 App im Hintergrund - letzte Aktivität gespeichert")
            
        @unknown default:
            break
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
