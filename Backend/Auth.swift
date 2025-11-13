import Supabase
import Foundation

public class AuthService {
    private let client: SupabaseClient
    
    public init() {
        self.client = supabase
    }
    
    func signUp(email: String, password: String, name: String) async throws -> AppUser {
        let redirect = URL(string: "unify://auth-callback")!

        let resp = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: redirect
        )
        
        // Kurze Pause beibehalten um Race Condition zu vermeiden
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden
        
        // Prüfen ob User in auth.users vorhanden ist
        do {
            let session = try await client.auth.session
            print("Auth user erfolgreich erstellt: \(session.user.id)")
        } catch {
            print("Auth user noch nicht ready, warte weiter...")
            try await Task.sleep(nanoseconds: 500_000_000) // Nochmal 0.5s
        }

        let appUser = AppUser(
            id: resp.user.id,
            display_name: name,
            email: email
        )
        try await client.from("user").insert(appUser).execute()

        return appUser
    }
    
    // MARK: - Sign In (Login)
        func signIn(email: String, password: String) async throws -> AppUser {
            print("🔵 [AuthService] Login für \(email)…")

            // → Supabase-Auth Login
            _ = try await client.auth.signIn(email: email, password: password)

            // → Session prüfen
            let session = try await client.auth.session
            let uid = session.user.id
            print("✅ [AuthService] Session aktiv. uid=\(uid)")

            // → User-Row laden
            let user: AppUser = try await client
                .from("user")
                .select("id, display_name, email")
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            print("✅ [AuthService] User gefunden: \(user.display_name)")
            return user
        }
    }
