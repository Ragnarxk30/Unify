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
            """)
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        
        print("✅ fetchGroupMembers: \(members.count) Mitglieder geladen")
        return members
    }
    
    // ✅ HAUPT-Funktion mit Rollen-Unterstützung
    func create(name: String, invitedUsers: [(email: String, role: role)]) async throws {
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

        // 2) E-Mails säubern
        let cleanedUsers = invitedUsers
            .map { (email: $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), role: $0.role) }
            .filter { !$0.email.isEmpty }

        // 3) E-Mails → user_ids auflösen
        struct MemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role
        }
        
        var memberRequests: [MemberRequest] = [
            MemberRequest(group_id: groupId, user_id: ownerId, role: .admin)
        ]
        
        var unknownEmails: [String] = []

        if !cleanedUsers.isEmpty {
            let emails = cleanedUsers.map { $0.email }
            let userRows: [AppUser] = try await db
                .from(usersTable)
                .select("id,display_name,email")
                .in("email", values: emails)
                .execute()
                .value

            let byEmail = Dictionary(uniqueKeysWithValues: userRows.map { ($0.email.lowercased(), $0.id) })
            
            for invitedUser in cleanedUsers {
                if let uid = byEmail[invitedUser.email] {
                    memberRequests.append(MemberRequest(
                        group_id: groupId,
                        user_id: uid,
                        role: invitedUser.role
                    ))
                } else {
                    unknownEmails.append(invitedUser.email)
                }
            }
        }

        // 4) Member-Bulk
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
        
        print("✅ Gruppe '\(name)' erstellt mit \(memberRequests.count) Mitgliedern")
    }
    
    // ✅ Abwärtskompatibilität - INTERNE Implementierung
    func create(name: String, invitedAppleIds: [String]) async throws {
        // Explizite Typangabe um den Überladungskonflikt zu vermeiden
        let userRole: role = .user
        let invitedUsers = invitedAppleIds.map { (email: $0, role: userRole) }
        try await create(name: name, invitedUsers: invitedUsers)
    }
    
    func addMember(groupId: UUID, userId: UUID, role: role) async throws {
        _ = try await auth.currentUserId()

        struct AddMemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role
        }
        
        let request = AddMemberRequest(group_id: groupId, user_id: userId, role: role)

        try await db
            .from(membersTable)
            .insert(request, returning: .minimal)
            .execute()
            
        print("✅ Mitglied \(userId) zu Gruppe \(groupId) hinzugefügt mit Rolle: \(role.rawValue)")
    }
    
    func removeMember(groupId: UUID, userId: UUID) async throws {
        _ = try await auth.currentUserId()

        try await db
            .from(membersTable)
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            
        print("✅ Mitglied \(userId) aus Gruppe \(groupId) entfernt")
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
        try await db
            .from(groupsTable)
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ Gruppe \(groupId) gelöscht")
    }
    
    // MARK: - Member einladen
    func inviteMember(groupId: UUID, email: String, role: role = .user) async throws {
        // 1) User anhand der E-Mail finden
        let users: [AppUser] = try await db
            .from(usersTable)
            .select("id, display_name, email")
            .eq("email", value: email.lowercased())
            .execute()
            .value
        
        guard let invitedUser = users.first else {
            throw GroupError.userNotFound
        }
        
        // 2) Prüfen ob User bereits Mitglied ist
        let existingMembers: [GroupMember] = try await db
            .from(membersTable)
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: invitedUser.id.uuidString)
            .execute()
            .value
        
        guard existingMembers.isEmpty else {
            throw NSError(domain: "GroupError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Benutzer ist bereits Gruppenmitglied"])
        }
        
        // 3) Mitglied hinzufügen
        struct InviteMemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role
        }
        
        let request = InviteMemberRequest(
            group_id: groupId,
            user_id: invitedUser.id,
            role: role
        )
        
        try await db
            .from(membersTable)
            .insert(request, returning: .minimal)
            .execute()
        
        print("✅ Benutzer \(email) zu Gruppe \(groupId) eingeladen mit Rolle: \(role.rawValue)")
    }
}
