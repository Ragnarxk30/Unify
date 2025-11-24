import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    private let authRepo: AuthRepository = SupabaseAuthRepository()
    @Published private(set) var isSignedIn = false
    @Published private(set) var isWaitingForEmailConfirmation = false
    @Published var currentUser: AppUser?  // ✅ Aktueller AppUser für alle Views

    private var pollTask: Task<Void, Never>?
    private var authStateTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60 * 15

    init() {
        // ✅ KEINE State-Änderungen im init! 
        setupAuthStateListener()
        checkInitialSession()
    }

    deinit {
        pollTask?.cancel()
        authStateTask?.cancel()
    }

    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            
            for await (event, session) in await supabase.auth.authStateChanges {
                await self.handleAuthStateChange(event: event, session: session)
            }
        }
    }

    // ✅ Immer mit @MainActor sicherstellen
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
                    self.currentUser = nil
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
                self.currentUser = nil
                self.pollTask?.cancel()
                print("✅ Auth State: Signed Out")
                
            case .userUpdated:
                self.isSignedIn = true
                self.startPolling()
                print("✅ Auth State: User Updated")
                
            default:
                break
            }
        }
        
        // Nach State-Wechsel ggf. aktuellen User laden/aktualisieren
        if isSignedIn {
            await loadCurrentUserFromSession()
        }
    }

    private func checkInitialSession() {
        Task {
            await refreshSession()
            if isSignedIn {
                await loadCurrentUserFromSession()
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isSignedIn {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                await self.refreshSession()
                await self.loadCurrentUserFromSession()
            }
        }
    }
    
    func setWaitingForEmailConfirmation(_ waiting: Bool) {
        isWaitingForEmailConfirmation = waiting
    }

    func refreshSession() async {
        do {
            let session = try await supabase.auth.session
            
            let currentTime = Date().timeIntervalSince1970
            let timeUntilExpiry = session.expiresAt - currentTime
            
            if timeUntilExpiry < 300 {
                _ = try await supabase.auth.refreshSession()
                print("✅ Session refreshed (läuft in \(Int(timeUntilExpiry))s ab)")
            } else {
                print("🔐 Session noch \(Int(timeUntilExpiry))s gültig")
            }
            
            // ✅ State-Änderungen nur im MainActor
            await MainActor.run {
                self.isSignedIn = true
                self.isWaitingForEmailConfirmation = false
            }
            
        } catch {
            // ✅ Auch Fehler im MainActor behandeln
            await MainActor.run {
                self.isSignedIn = false
                self.isWaitingForEmailConfirmation = false
                self.currentUser = nil
            }
            print("❌ Session ungültig: \(error.localizedDescription)")
        }
    }

    func manualRefresh() async {
        print("🔄 Manuelles Session Refresh")
        await refreshSession()
        if isSignedIn {
            await loadCurrentUserFromSession()
        }
    }

    func signOut() async {
        do {
            try await authRepo.signOut()
            print("✅ SignOut erfolgreich")
        } catch {
            print("❌ SignOut Fehler: \(error)")
        }
        
        // ✅ State-Änderungen im MainActor
        await MainActor.run {
            self.isSignedIn = false
            self.isWaitingForEmailConfirmation = false
            self.currentUser = nil
        }
        pollTask?.cancel()
    }

    func markSignedIn() {
        isSignedIn = true
        isWaitingForEmailConfirmation = false
        startPolling()
    }
    
    func markSignedOut() {
        isSignedIn = false
        isWaitingForEmailConfirmation = false
        currentUser = nil
        pollTask?.cancel()
    }
    // MARK: - CurrentUser Handling
    func setCurrentUser(_ user: AppUser) {
        currentUser = user
        markSignedIn()
    }

    private func loadCurrentUserFromSession() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            let user: AppUser = try await supabase
                .from("user")
                .select("id, display_name, email")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            print("❌ Konnte currentUser nicht laden: \(error)")
        }
    }
}

