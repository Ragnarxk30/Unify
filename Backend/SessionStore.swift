import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published var isSignedIn = false

    init() {
        Task { await refreshSession() } // einmal beim Start prüfen
    }

    /// Prüft einmalig, ob aktuell eine Session vorhanden ist.
    func refreshSession() async {
        isSignedIn = (try? await supabase.auth.session) != nil
    }

    /// Optional: manuelle Setter für UI-Flows
    func markSignedIn()  { isSignedIn = true  }
    func markSignedOut() { isSignedIn = false }
}
