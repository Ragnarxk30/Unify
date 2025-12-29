//  GroupRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 04.11.25.
//

import Foundation

//Blueprint für die Group-Endpoints
protocol GroupRepository {
    func fetchGroups() async throws -> [AppGroup]
    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMember]
    func fetchMemberCount(groupId: UUID) async throws -> Int  // 👈 DIESE ZEILE HINZUFÜGEN
    func create(name: String, invitedUsers: [(email: String, role: role)]) async throws
    func create(name: String, invitedAppleIds: [String]) async throws
    func addMember(groupId: UUID, userId: UUID, role: role) async throws
    func removeMember(groupId: UUID, userId: UUID) async throws
    func leaveGroup(groupId: UUID) async throws
    func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws
    func rename(groupId: UUID, to newName: String) async throws
    func delete(groupId: UUID) async throws
    func inviteMember(groupId: UUID, email: String, role: role) async throws
}

extension GroupRepository {
    func addMember(groupId: UUID, userId: UUID) async throws {
        try await addMember(groupId: groupId, userId: userId, role: .user)
    }
    
    // Convenience Method für inviteMember mit default role
    func inviteMember(groupId: UUID, email: String) async throws {
        try await inviteMember(groupId: groupId, email: email, role: .user)
    }
}
