//
//  GroupRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 04.11.25.
//


import Foundation

//Blueprint für die Group-Endpoints
protocol GroupRepository {
    func create(name: String) async throws
    //func rename(groupId: UUID, to newName: String) async throws
    //func delete(groupId: UUID) async throws

    //func groupsOwnedBy(userId: UUID, limit: Int, offset: Int) async throws -> [Group]
    //func groupsForMember(userId: UUID, limit: Int, offset: Int) async throws -> [Group]

    //func addMember(groupId: UUID, userId: UUID, role: String) async throws
    //func removeMember(groupId: UUID, userId: UUID) async throws
}
