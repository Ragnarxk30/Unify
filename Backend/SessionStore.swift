import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    @Published private(set) var isSignedIn = false
    @Published private(set) var isWaitingForEmailConfirmation = false

    private var pollTask: Task<Void, Never>?
    private var authStateTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60 * 15 // 15 Minuten

    init() {
        setupAuthStateListener()
        checkInitialSession()
    }

    deinit {
        pollTask?.cancel()
        authStateTask?.cancel()
    }

    /// Setzt Listener für Auth-State Changes mit AsyncStream
    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            
            for await (event, session) in await supabase.auth.authStateChanges {
                await self.handleAuthStateChange(event: event, session: session)
            }
        }
    }

    /// Behandelt Auth-State Changes
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        await MainActor.run {
            switch event {
            case .initialSession:
                if session != nil {
                    self.isSignedIn = true
                    self.isWaitingForEmailConfirmation = false
                    self.startPolling()
                    print("✅ Initial Session: Signed In")
                } else {
                    self.isSignedIn = false
                    self.isWaitingForEmailConfirmation = false
                    print("✅ Initial Session: Signed Out")
                }
                
            case .signedIn:
                self.isSignedIn = true
                self.isWaitingForEmailConfirmation = false
                self.startPolling()
                print("✅ Auth State: Signed In")
                
            case .signedOut:
                self.isSignedIn = false
                self.isWaitingForEmailConfirmation = false
                self.pollTask?.cancel()
                print("✅ Auth State: Signed Out")
                
            case .userUpdated:
                self.isSignedIn = true
                self.startPolling()
                print("✅ Auth State: User Updated")
                
            case .passwordRecovery, .tokenRefreshed:
                // Weitere Events falls benötigt
                break
            @unknown default:
                break
            }
        }
    }

    /// Prüft die Session beim App-Start
    private func checkInitialSession() {
        Task {
            await refreshSession()
        }
    }

    /// Startet Polling mit längerem Intervall
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isSignedIn {
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
            
            // ✅ State wird durch Auth-State Listener geupdated
            
        } catch {
            // ❌ Session ungültig oder abgelaufen
            await MainActor.run {
                self.isSignedIn = false
                self.isWaitingForEmailConfirmation = false
            }
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
            // Trotz Fehler State zurücksetzen
            await MainActor.run {
                self.isSignedIn = false
                self.isWaitingForEmailConfirmation = false
            }
        }
    }

    /// Manuelle Setter (für spezielle Fälle)
    func markSignedIn()  {
        isSignedIn = true
        isWaitingForEmailConfirmation = false
        startPolling()
    }
    
    func markSignedOut() {
        isSignedIn = false
        isWaitingForEmailConfirmation = false
        pollTask?.cancel()
    }
}
