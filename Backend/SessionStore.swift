import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    @Published private(set) var isSignedIn = false
    @Published private(set) var isWaitingForEmailConfirmation = false

    private var pollTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    deinit { pollTask?.cancel() }

    /// Startet ein Polling im 10‑Sekunden‑Takt und validiert die Supabase‑Session.
    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshSession()
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            }
        }
    }
    
    func setWaitingForEmailConfirmation(_ waiting: Bool) {
        isWaitingForEmailConfirmation = waiting
    }

    /// Prüft/aktualisiert die Session und setzt die Flag entsprechend.
    func refreshSession() async {
        do {
            // ✅ IMMER versuchen zu refreshen (macht Supabase automatisch wenn nötig)
            _ = try await supabase.auth.refreshSession()
            isSignedIn = true
            print("✅ Session refresh erfolgreich")
        } catch {
            // ❌ Refresh fehlgeschlagen - User ist abgemeldet
            isSignedIn = false
            print("❌ Session refresh fehlgeschlagen: \(error)")
        }
    }

    func signOut() async {
        do {
            try await authRepo.signOut()
            print("✅ SignOut erfolgreich")
        } catch {
            print("❌ SignOut Fehler: \(error)")
        }
        isSignedIn = false
        isWaitingForEmailConfirmation = false
    }

    /// Manuelle Setter (falls du sie für bestimmte Flows brauchst)
    func markSignedIn()  {
        isSignedIn = true
        isWaitingForEmailConfirmation = false
    }
    
    func markSignedOut() {
        isSignedIn = false
        isWaitingForEmailConfirmation = false
    }
}
