import Supabase
import SwiftUI
//

protocol AuthRepository {
    func currentUserId() async throws -> UUID
    func currentUser() async throws -> User
    func signOut() async throws
}

struct SupabaseAuthRepository: AuthRepository {
    func currentUserId() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }

    func currentUser() async throws -> User {
        let session = try await supabase.auth.session
        return session.user
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
