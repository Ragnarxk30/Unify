import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    @Published private(set) var isSignedIn = false

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

    /// Prüft/aktualisiert die Session und setzt die Flag entsprechend.
    func refreshSession() async {
        do {
            _ = try await supabase.auth.refreshSession() // ✅ Fragt Supabase-Server an
            isSignedIn = true
        } catch {
            isSignedIn = false
        }
    }

    func signOut() async {
            do {
                try await authRepo.signOut()
            } catch {
                // optional logging
            }
            isSignedIn = false
        }

    /// Manuelle Setter (falls du sie für bestimmte Flows brauchst)
    func markSignedIn()  { isSignedIn = true }
    func markSignedOut() { isSignedIn = false }
}
