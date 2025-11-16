//
//  SupabaseEventRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 16.11.25.
//

import Foundation
import Supabase

struct SupabaseEventRepository: EventRepository {

    private let db = supabase
    private let eventsTable  = "event"
    private let membersTable = "group_members"
    private let auth: AuthRepository

    init(auth: AuthRepository = SupabaseAuthRepository()) {
        self.auth = auth
    }

    // MARK: - DTOs

    private struct EventInsert: Encodable {
        let groupId: UUID
        let title: String
        let details: String?
        let startsAt: Date
        let endsAt: Date?
        let createdBy: UUID

        enum CodingKeys: String, CodingKey {
            case groupId   = "group_id"
            case title
            case details
            case startsAt  = "starts_at"
            case endsAt    = "ends_at"
            case createdBy = "created_by"
        }
    }

    private struct EventUpdatePayload: Encodable {
        let title: String
        let details: String?
        let startsAt: Date
        let endsAt: Date?

        enum CodingKeys: String, CodingKey {
            case title
            case details
            case startsAt = "starts_at"
            case endsAt   = "ends_at"
        }
    }

    private struct EventMeta: Decodable {
        let id: UUID
        let groupId: UUID
        let createdBy: UUID

        enum CodingKeys: String, CodingKey {
            case id
            case groupId   = "group_id"
            case createdBy = "created_by"
        }
    }

    private struct MemberRow: Decodable {
        let role: String
    }

    // 👉 Neu: Row-Typ für SELECT
    private struct EventRow: Decodable {
        let id: UUID
        let title: String
        let details: String?
        let startsAt: Date
        let endsAt: Date
        let groupId: UUID?
        let createdBy: UUID
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case details
            case startsAt  = "starts_at"
            case endsAt    = "ends_at"
            case groupId   = "group_id"
            case createdBy = "created_by"
            case createdAt = "created_at"
        }
    }

    // MARK: - Helpers

    /// Rolle des aktuellen Users in einer Gruppe
    private func roleOfCurrentUser(in groupId: UUID) async throws -> String? {
        let userId = try await auth.currentUserId()

        let rows: [MemberRow] = try await db
            .from(membersTable)
            .select("role")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.role
    }

    /// Event-Metadaten (für Berechtigungen)
    private func fetchEventMeta(_ eventId: UUID) async throws -> EventMeta {
        let result: EventMeta = try await db
            .from(eventsTable)
            .select("id, group_id, created_by")
            .eq("id", value: eventId.uuidString)
            .single()
            .execute()
            .value

        return result
    }

    // MARK: - EventRepository

    // CREATE: alle Gruppenmitglieder dürfen erstellen
    func create(
        groupId: UUID,
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws {
        let userId = try await auth.currentUserId()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EventError.emptyTitle }
        if let end = endsAt, end < startsAt { throw EventError.invalidTimeRange }

        guard let _ = try await roleOfCurrentUser(in: groupId) else {
            throw EventError.notMemberOfGroup
        }

        let payload = EventInsert(
            groupId: groupId,
            title: trimmed,
            details: details,
            startsAt: startsAt,
            endsAt: endsAt,
            createdBy: userId
        )

        try await db
            .from(eventsTable)
            .insert(payload)
            .execute()
    }

    // UPDATE:
    // - user    → nur eigene Events
    // - admin / owner → alle Events der Gruppe
    func update(
        eventId: UUID,
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws {
        let userId = try await auth.currentUserId()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EventError.emptyTitle }
        if let end = endsAt, end < startsAt { throw EventError.invalidTimeRange }

        // 1) Event-Meta laden
        let meta = try await fetchEventMeta(eventId)

        // 2) Rolle in der Gruppe holen
        guard let role = try await roleOfCurrentUser(in: meta.groupId) else {
            throw EventError.notMemberOfGroup
        }

        let isCreator = (meta.createdBy == userId)
        let canEditAll = (role == "admin" || role == "owner")

        guard canEditAll || isCreator else {
            throw EventError.insufficientPermissions
        }

        let payload = EventUpdatePayload(
            title: trimmed,
            details: details,
            startsAt: startsAt,
            endsAt: endsAt
        )

        try await db
            .from(eventsTable)
            .update(payload)
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    // DELETE:
    // - user    → nur eigene Events
    // - admin / owner → alle Events
    func delete(eventId: UUID) async throws {
        let userId = try await auth.currentUserId()

        // 1) Event-Meta
        let meta = try await fetchEventMeta(eventId)

        // 2) Rolle holen
        guard let role = try await roleOfCurrentUser(in: meta.groupId) else {
            throw EventError.notMemberOfGroup
        }

        let isCreator = (meta.createdBy == userId)
        let canDeleteAll = (role == "admin" || role == "owner")

        guard canDeleteAll || isCreator else {
            throw EventError.insufficientPermissions
        }

        try await db
            .from(eventsTable)
            .delete()
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    // LIST: Events für eine Gruppe
    func listForGroup(_ groupId: UUID) async throws -> [Event] {
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("id, title, details, starts_at, ends_at, group_id, created_by, created_at")
            .eq("group_id", value: groupId.uuidString)
            .order("starts_at", ascending: true)
            .execute()
            .value

        // Mapping auf dein Domain-Model `Event`
        return rows.map { row in
            Event(
                id: row.id,
                title: row.title,
                details: row.details,
                start: row.startsAt,
                end: row.endsAt,
                group_id: row.groupId,
                created_by: row.createdBy,
                created_at: row.createdAt
            )
        }
    }
}

enum EventError: Error {
    case emptyTitle
    case invalidTimeRange
    case notMemberOfGroup
    case insufficientPermissions
    case notFound
}
