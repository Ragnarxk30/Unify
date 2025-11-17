//
//  SupabaseEventRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 16.11.25.
//

import Foundation
import Supabase

struct SupabaseEventRepository: EventRepository {

    private let db   = supabase
    private let eventsTable = "event"
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

    // MARK: - Mapping

    private func mapRow(_ row: EventRow) -> Event {
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

    // MARK: - EventRepository

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
        // Berechtigung: komplett über RLS (members_can_insert_events)
    }

    func update(
        eventId: UUID,
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EventError.emptyTitle }
        if let end = endsAt, end < startsAt { throw EventError.invalidTimeRange }

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
        // Berechtigung: RLS-Policy members_can_update_events_with_role_logic
    }

    func delete(eventId: UUID) async throws {
        try await db
            .from(eventsTable)
            .delete()
            .eq("id", value: eventId.uuidString)
            .execute()
        // Berechtigung: RLS-Policy members_can_delete_events_with_role_logic
    }

    func listForGroup(_ groupId: UUID) async throws -> [Event] {
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("id, title, details, starts_at, ends_at, group_id, created_by, created_at")
            .eq("group_id", value: groupId.uuidString)
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(mapRow)
        // Sichtbarkeit: members_can_select_events / user_can_view_group_events
    }

    func listUserEvents() async throws -> [Event] {
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("id, title, details, starts_at, ends_at, group_id, created_by, created_at")
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(mapRow)
        // RLS sorgt dafür, dass nur Events aus Gruppen zurückkommen,
        // in denen auth.uid() Mitglied ist.
    }
}

enum EventError: Error {
    case emptyTitle
    case invalidTimeRange
}
