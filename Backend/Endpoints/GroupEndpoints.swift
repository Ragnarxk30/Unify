// group_endpoints.swift 
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

    func fetchGroups() async throws -> [AppGroup] {
        _ = try await auth.currentUserId()
        
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
        
        print("✅ fetchGroups: \(groups.count) Gruppen geladen")
        return groups
    }
    
    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMember] {
        let members: [GroupMember] = try await db
            .from("group_members")
            .select("""
                user_id,
                group_id, 
                role,
                joined_at,
                user:user!user_id(
                    id,
                    display_name,
                    email
                )
            """)  // ✅ KEINE KOMMENTARE IN DER QUERY!
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        
        print("✅ fetchGroupMembers: \(members.count) Mitglieder geladen")
        return members
    }
    

    func create(name: String, invitedAppleIds: [String]) async throws {
        let ownerId = try await auth.currentUserId()

        // 1) Gruppe anlegen
        struct CreateGroupRequest: Encodable {
            let name: String
            let owner_id: UUID
        }
        
        let request = CreateGroupRequest(name: name, owner_id: ownerId)
        
        let created: AppGroup = try await db
            .from(groupsTable)
            .insert(request)
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
            let userRows: [AppUser] = try await db
                .from(usersTable)
                .select("id,display_name,email")
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

        // 4) Member-Bulk - ✅ ENUM VALUES direkt verwenden!
        struct MemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role
        }
        
        var memberRequests: [MemberRequest] = [
            MemberRequest(group_id: groupId, user_id: ownerId, role: .admin) // ✅ .admin nicht "admin"
        ]
        
        memberRequests.append(contentsOf: memberUserIds.map { userId in
            MemberRequest(group_id: groupId, user_id: userId, role: .user) // ✅ .user nicht "user"
        })

        if !memberRequests.isEmpty {
            _ = try await db
                .from(membersTable)
                .upsert(memberRequests, onConflict: "group_id,user_id", returning: .minimal)
                .execute()
        }

        // 5) Unbekannte E-Mails als Fehler werfen
        if !unknownEmails.isEmpty {
            throw GroupError.unknownAppleIds(unknownEmails)
        }
    }
    
    func addMember(groupId: UUID, userId: UUID, role: role) async throws { // ✅ role: role nicht role: String
        _ = try await auth.currentUserId()

        struct AddMemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role // ✅ ENUM type
        }
        
        let request = AddMemberRequest(group_id: groupId, user_id: userId, role: role)

        try await db
            .from(membersTable)
            .insert(request)
            .execute()
    }
    
    func removeMember(groupId: UUID, userId: UUID) async throws {
        _ = try await auth.currentUserId()

        try await db
            .from(membersTable)
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
    
    func rename(groupId: UUID, to newName: String) async throws {
        let _ = try await auth.currentUserId()

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupError.emptyName
        }

        struct RenameRequest: Encodable {
            let name: String
        }
        
        try await db
            .from(groupsTable)
            .update(RenameRequest(name: trimmed))
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ Gruppe \(groupId) umbenannt zu '\(trimmed)'")
    }

    func delete(groupId: UUID) async throws {
        let ownerId = try await auth.currentUserId()

        try await db
            .from(groupsTable)
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ Gruppe \(groupId) gelöscht")
    }
}
