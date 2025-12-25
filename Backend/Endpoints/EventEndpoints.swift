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
    
    private struct PersonalEventInsert: Encodable {
        let title: String
        let details: String?
        let startsAt: Date
        let endsAt: Date?
        let createdBy: UUID

        enum CodingKeys: String, CodingKey {
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

    // 👇 AKTUALISIERT: Jetzt mit user relation
    private struct EventRow: Decodable {
        let id: UUID
        let title: String
        let details: String?
        let startsAt: Date
        let endsAt: Date
        let groupId: UUID?
        let createdBy: UUID
        let createdAt: Date
        let user: AppUser?  // 👈 NEU

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case details
            case startsAt  = "starts_at"
            case endsAt    = "ends_at"
            case groupId   = "group_id"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case user
        }
    }

    // MARK: - Mapping

    private func mapRow(_ row: EventRow) -> Event {
        Event(
            id: row.id,
            title: row.title,
            details: row.details,
            starts_at: row.startsAt,
            ends_at: row.endsAt,
            group_id: row.groupId,
            created_by: row.createdBy,
            created_at: row.createdAt,
            user: row.user  // 👈 NEU
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
        if startsAt < Date() { throw EventError.startInPast }
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
    }

    func delete(eventId: UUID) async throws {
        try await db
            .from(eventsTable)
            .delete()
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    func listForGroup(_ groupId: UUID) async throws -> [Event] {
        await cleanupPastEvents()
        
        // 👇 WICHTIG: Jetzt mit user relation
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("""
                id,
                title,
                details,
                starts_at,
                ends_at,
                group_id,
                created_by,
                created_at,
                user:user!created_by(
                    id,
                    display_name,
                    email
                )
            """)
            .eq("group_id", value: groupId.uuidString)
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(mapRow)
    }

    func listUserEvents() async throws -> [Event] {
        await cleanupPastEvents()
        
        // 👇 WICHTIG: Jetzt mit user relation
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("""
                id,
                title,
                details,
                starts_at,
                ends_at,
                group_id,
                created_by,
                created_at,
                user:user!created_by(
                    id,
                    display_name,
                    email
                )
            """)
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(mapRow)
    }
    
    func createPersonal(
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws {
        let userId = try await auth.currentUserId()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EventError.emptyTitle }
        if startsAt < Date() { throw EventError.startInPast }
        if let end = endsAt, end < startsAt { throw EventError.invalidTimeRange }

        let payload = PersonalEventInsert(
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

    func listPersonalEvents() async throws -> [Event] {
        await cleanupPastEvents()
        
        // 👇 WICHTIG: Jetzt mit user relation
        let rows: [EventRow] = try await db
            .from(eventsTable)
            .select("""
                id,
                title,
                details,
                starts_at,
                ends_at,
                group_id,
                created_by,
                created_at,
                user:user!created_by(
                    id,
                    display_name,
                    email
                )
            """)
            .is("group_id", value: nil)
            .order("starts_at", ascending: true)
            .execute()
            .value

        return rows.map(mapRow)
    }
    
    private func cleanupPastEvents() async {
        let now = Date()
        do {
            try await db
                .from(eventsTable)
                .delete()
                .lt("ends_at", value: now)
                .execute()
            
            try await db
                .from(eventsTable)
                .delete()
                .is("ends_at", value: nil)
                .lt("starts_at", value: now)
                .execute()
        } catch {
            print("⚠️ Konnte abgelaufene Termine nicht bereinigen:", error)
        }
    }
}

enum EventError: LocalizedError {
    case emptyTitle
    case invalidTimeRange
    case startInPast

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Der Titel darf nicht leer sein."
        case .invalidTimeRange:
            return "Das Enddatum muss nach dem Startdatum liegen."
        case .startInPast:
            return "Der Startzeitpunkt darf nicht in der Vergangenheit liegen."
        }
    }
}
