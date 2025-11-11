import Supabase
import Foundation

public class AuthService {
    // ✅ Verwendet die globale supabase Instanz
    private let client: SupabaseClient
    
    public init() {
        self.client = supabase
    }
    
    func signUp(email: String, password: String, name: String) async throws -> AppUser {
            let redirect = URL(string: "https://gtyyrkwfkzzyhsearkgn.supabase.co/functions/v1/confirm")!

            // ⬇️ Redirect an Supabase übergeben
            let resp = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirect
            )
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde

            // public.user anlegen (FK = auth.users.id)
            let appUser = AppUser(id: resp.user.id, display_name: name)
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
                .select("id, display_name")
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            print("✅ [AuthService] User gefunden: \(user.display_name)")
            return user
        }
    }
