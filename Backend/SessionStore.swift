import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    @Published private(set) var isSignedIn = false
    @Published private(set) var isWaitingForEmailConfirmation = false

    private var pollTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60 * 15 // 15 Minuten

    init() {
        checkInitialSession()
    }

    deinit {
        pollTask?.cancel()
    }

    /// Prüft die Session beim App-Start
    private func checkInitialSession() {
        Task {
            await refreshSession()
            startPolling() // Starte Polling nur nach initialer Prüfung
        }
    }

    /// Startet Polling mit längerem Intervall
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                await self.refreshSession()
            }
        }
    }
    
    func setWaitingForEmailConfirmation(_ waiting: Bool) {
        isWaitingForEmailConfirmation = waiting
    }

    /// Prüft/aktualisiert die Session nur wenn nötig
    func refreshSession() async {
        do {
            let session = try await supabase.auth.session
            
            // ✅ Korrekte Prüfung: expiresAt ist bereits ein TimeInterval (Timestamp)
            let currentTime = Date().timeIntervalSince1970
            let timeUntilExpiry = session.expiresAt - currentTime
            
            if timeUntilExpiry < 300 { // 5 Minuten
                _ = try await supabase.auth.refreshSession()
                print("✅ Session refreshed (läuft in \(Int(timeUntilExpiry))s ab)")
            } else {
                print("🔐 Session noch \(Int(timeUntilExpiry))s gültig")
            }
            isSignedIn = true
        } catch {
            // ❌ Session ungültig oder abgelaufen
            isSignedIn = false
            print("❌ Session ungültig: \(error.localizedDescription)")
        }
    }

    /// Manuelles Refresh (z.B. beim App-Wechsel zurück)
    func manualRefresh() async {
        print("🔄 Manuelles Session Refresh")
        await refreshSession()
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
        pollTask?.cancel() // ❌ Polling nach SignOut stoppen
    }

    /// Manuelle Setter
    func markSignedIn()  {
        isSignedIn = true
        isWaitingForEmailConfirmation = false
        startPolling() // ✅ Polling nach Login starten
    }
    
    func markSignedOut() {
        isSignedIn = false
        isWaitingForEmailConfirmation = false
        pollTask?.cancel() // ✅ Polling stoppen
    }
}
