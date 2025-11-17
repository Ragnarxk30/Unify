//  GroupRepository.swift
//  Unify
// 
//  Created by Jonas Dunkenberger on 04.11.25.
//

import Foundation

//Blueprint für die Group-Endpoints
protocol GroupRepository {
    // ✅ fetchGroups Methode hinzufügen
    func fetchGroups() async throws -> [AppGroup]
    
    //func create(name: String) async throws
    func create(name: String, invitedAppleIds: [String]) async throws
    func rename(groupId: UUID, to newName: String) async throws
    func delete(groupId: UUID) async throws

    //func groupsOwnedBy(userId: UUID, limit: Int, offset: Int) async throws -> [Group]
    //func groupsForMember(userId: UUID, limit: Int, offset: Int) async throws -> [Group]

    func addMember(groupId: UUID, userId: UUID, role: String) async throws
    func removeMember(groupId: UUID, userId: UUID) async throws
}

extension GroupRepository {
    /// Komfort: vararg-Aufruf
    func create(name: String, invitedAppleIds: String...) async throws {
        try await create(name: name, invitedAppleIds: invitedAppleIds)
    }
    
    func addMember(groupId: UUID, userId: UUID) async throws {
        try await addMember(groupId: groupId, userId: userId, role: "user")
    }
}
