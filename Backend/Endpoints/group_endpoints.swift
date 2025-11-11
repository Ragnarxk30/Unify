//  group_endpoints.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 04.11.25.

import Foundation
import Supabase

struct SupabaseGroupRepository: GroupRepository {
    
    
    private let db = supabase
    private let groupsTable = "group"
    private let membersTable = "group-members"
    private let auth: AuthRepository

    init(auth: AuthRepository = SupabaseAuthRepository()) {
        self.auth = auth
    }
    
    // Encodable Payloads
    private struct CreateGroupPayload: Encodable {
        let name: String
        let ownerId: UUID
        // <- Case-Name == Property-Name; Mapping passiert rechts
        enum CodingKeys: String, CodingKey {
            case name
            case ownerId = "owner_id"
        }
    }

    // MARK: - CRUD
    func create(name: String) async throws {
        let ownerId = try await auth.currentUserId()
        
        let payload = CreateGroupPayload(name: name, ownerId: ownerId)

        try await db
            .from(groupsTable)
            .insert(payload)
            .execute()
    }

    func rename(groupId: UUID, to newName: String) async throws {
        
    }
    
    
    func delete(groupId: UUID) async throws {
        
    }
    /*
    func groupsOwnedBy(userId: UUID, limit: Int, offset: Int) async throws -> [Group] {
        
    }
    
    func groupsForMember(userId: UUID, limit: Int, offset: Int) async throws -> [Group] {
        
    }
    */
    func addMember(groupId: UUID, userId: UUID, role: String) async throws {
        
    }
    
    func removeMember(groupId: UUID, userId: UUID) async throws {
        
    }
    
}
