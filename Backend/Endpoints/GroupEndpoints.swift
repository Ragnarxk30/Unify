//  group_endpoints.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 04.11.25.

import Foundation
import Supabase

struct SupabaseGroupRepository: GroupRepository {

    private let db = supabase
    private let groupsTable  = "group"
    private let membersTable = "group_members"
    private let usersTable   = "user"
    private let auth: AuthRepository

    init(auth: AuthRepository = SupabaseAuthRepository()) {
        self.auth = auth
    }

    // MARK: - GroupRepository Protocol Implementation

    /// Gruppen des aktuellen Users abrufen (Owner UND Mitglied) - gefiltert durch RLS Policy
    func fetchGroups() async throws -> [AppGroup] {
        _ = try await auth.currentUserId() // Nur um Authentifizierung zu prüfen
        
        // ✅ Einfache Abfrage - RLS Policy filtert automatisch die sichtbaren Gruppen
        let groups: [AppGroup] = try await db
            .from(groupsTable)
            .select("""
                id,
                name,
                owner_id,
                user:user!owner_id(
                    id,
                    display_name,
                    email
                )
            """)
            .execute()
            .value
        
        print("✅ fetchGroups: \(groups.count) Gruppen geladen (via RLS Policy)")
        return groups
    }

    // MARK: - Encodable Payloads
    private struct CreateGroupPayload: Encodable {
        let name: String
        let ownerId: UUID
        // <- Case-Name == Property-Name; Mapping passiert rechts
        enum CodingKeys: String, CodingKey {
            case name
            case ownerId = "owner_id"
        }
    }

    private struct MemberInsert: Encodable {
        let groupId: UUID
        let userId: UUID
        let role: String
        enum CodingKeys: String, CodingKey {
            case groupId = "group_id"
            case userId  = "user_id"
            case role
        }
    }

    /*// MARK: - CRUD (alte Minimal-Variante)
    func create(name: String) async throws {
        let ownerId = try await auth.currentUserId()
        let payload = CreateGroupPayload(name: name, ownerId: ownerId)

        try await db
            .from(groupsTable)
            .insert(payload)
            .execute()
    }
    */
    
    func rename(groupId: UUID, to newName: String) async throws {
        let _ = try await auth.currentUserId()   // nur für „eingeloggt“-Sicherheit

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupError.emptyName
        }

        struct RenamePayload: Encodable {
            let name: String
        }

        try await db
            .from(groupsTable)
            .update(RenamePayload(name: trimmed))
            .eq("id", value: groupId.uuidString)
            .execute()
    }

    // MARK: - Public
    /// Erstellt eine Gruppe und fügt optionale Mitglieder per E-Mail (Apple-ID) hinzu.
    func create(name: String, invitedAppleIds: [String]) async throws {
        let ownerId = try await auth.currentUserId()

        // 1) Gruppe anlegen und ID holen
        struct GroupRow: Decodable { let id: UUID }

        let created: GroupRow = try await db
            .from(groupsTable)
            .insert(CreateGroupPayload(name: name, ownerId: ownerId))
            .select("id")
            .single()
            .execute()
            .value

        let groupId = created.id

        // 2) E-Mails säubern + deduplizieren
        let cleaned = Array(
            Set(invitedAppleIds
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty })
        )

        // 3) E-Mails → user_ids auflösen
        var memberUserIds: [UUID] = []
        var unknownEmails: [String] = []

        if !cleaned.isEmpty {
            struct UserRow: Decodable {
                let id: UUID
                let email: String
            }

            let userRows: [UserRow] = try await db
                .from(usersTable)
                .select("id,email")
                .in("email", values: cleaned)
                .execute()
                .value

            let byEmail = Dictionary(uniqueKeysWithValues: userRows.map { ($0.email.lowercased(), $0.id) })
            for e in cleaned {
                if let uid = byEmail[e] {
                    memberUserIds.append(uid)
                } else {
                    unknownEmails.append(e)
                }
            }
        }

        // 4) Member-Bulk (Owner = admin, Eingeladene = member)
        var inserts: [MemberInsert] = [MemberInsert(groupId: groupId, userId: ownerId, role: "admin")]
        inserts.append(contentsOf: memberUserIds.map { MemberInsert(groupId: groupId, userId: $0, role: "user") })

        if !inserts.isEmpty {
            // Voraussetzung: UNIQUE (group_id, user_id) auf group_members
            _ = try await db
                .from(membersTable)
                .upsert(inserts, onConflict: "group_id,user_id", returning: .minimal)
                .execute()
        }

        // 5) Optional: unbekannte E-Mails protokollieren/handhaben
        if !unknownEmails.isEmpty {
            print("Warnung: Unbekannte E-Mails (kein user): \(unknownEmails)")
            // Oder: throw GroupError.unknownAppleIds(unknownEmails)
        }
    }
    
    /// Löscht eine Gruppe. Darf nur vom Owner ausgeführt werden.
    func delete(groupId: UUID) async throws {
        let ownerId = try await auth.currentUserId()

        try await db
            .from(groupsTable)
            .delete()
            .eq("id", value: groupId.uuidString)
            .eq("owner_id", value: ownerId.uuidString)   // doppelte Absicherung
            .execute()
    }
    
    func addMember(groupId: UUID, userId: UUID, role: String) async throws {
        _ = try await auth.currentUserId()  // nur prüfen, dass jemand eingeloggt ist

        let insert = MemberInsert(
            groupId: groupId,
            userId: userId,
            role: role
        )

        try await db
            .from(membersTable)
            .insert(insert)
            .execute()
    }
    
    /// Entfernt ein Mitglied aus einer Gruppe.
    /// Erlaubt durch RLS nur:
    /// - Owner: jeden entfernen
    func removeMember(groupId: UUID, userId: UUID) async throws {
        _ = try await auth.currentUserId()

        try await db
            .from(membersTable)
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Optionales Domain-Error
enum GroupError: Error {
    case unknownAppleIds([String])
    case emptyName
}
