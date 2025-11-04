import Supabase

public class AuthService {
    // ✅ Verwendet die globale supabase Instanz
    private let client: SupabaseClient
    
    public init() {
        self.client = supabase
    }
    
    func signUp(email: String, password: String, name: String) async throws -> User {
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        let authUser = authResponse.user
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
        let user = User(id: authUser.id, display_name: name)
        
        try await client
            .from("user")
            .insert(user)
            .execute()
        
        return user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let authResponse = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        let authUser = authResponse.user
        
        let user: User = try await client
            .from("user")
            .select()
            .eq("id", value: authUser.id)
            .single()
            .execute()
            .value
        
        return user
    }
}
