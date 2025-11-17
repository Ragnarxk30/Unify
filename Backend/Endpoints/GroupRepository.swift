//  GroupRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 04.11.25.
//

import Foundation

//Blueprint für die Group-Endpoints
protocol GroupRepository {
    func fetchGroups() async throws -> [AppGroup]
    func create(name: String, invitedAppleIds: [String]) async throws
    func rename(groupId: UUID, to newName: String) async throws
    func delete(groupId: UUID) async throws
    func addMember(groupId: UUID, userId: UUID, role: role) async throws // ✅ role: role
    func removeMember(groupId: UUID, userId: UUID) async throws
    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMember]
}

extension GroupRepository {
    func addMember(groupId: UUID, userId: UUID) async throws {
        try await addMember(groupId: groupId, userId: userId, role: .user) // ✅ .user
    }
}

