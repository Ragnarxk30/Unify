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
        // 1) Gruppe holen um owner_id zu bekommen
        let group: AppGroup = try await db
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
            .eq("id", value: groupId.uuidString)
            .single()
            .execute()
            .value

        print("🔍 Gruppe geladen - Owner ID: \(group.owner_id), Owner Name: \(group.owner.display_name)")

        // 2) Mitglieder aus group_members holen
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
        
        print("🔍 Mitglieder aus DB: \(members.count)")
        for member in members {
            print("   - \(member.user_id): \(member.role.rawValue) - \(member.memberUser.display_name)")
        }
        
        // 3) Owner immer als erstes in die Liste einfügen
        var allMembers = members
        
        // Owner Member erstellen
        let ownerMember = GroupMember(
            user_id: group.owner_id,
            group_id: groupId,
            role: .owner,
            joined_at: Date(),
            user: group.user
        )
        
        // Owner entfernen falls schon in members (mit falscher Rolle)
        allMembers.removeAll { $0.user_id == group.owner_id }
        
        // Owner immer als erstes einfügen
        allMembers.insert(ownerMember, at: 0)
        
        print("✅ fetchGroupMembers: \(allMembers.count) Mitglieder geladen")
        for member in allMembers {
            print("   📋 \(member.user_id): \(member.role.rawValue) - \(member.memberUser.display_name)")
        }
        
        return allMembers
    }
    
    func create(name: String, invitedUsers: [(email: String, role: role)]) async throws {
        let ownerId = try await auth.currentUserId()

        // 1) E-Mails säubern und PRÜFEN VOR der Gruppenerstellung
        let cleanedUsers = invitedUsers
            .map { (email: $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), role: $0.role) }
            .filter { !$0.email.isEmpty }

        print("🔍 Eingegangene E-Mails: \(cleanedUsers.map { $0.email })")

        var unknownEmails: [String] = []

        // 2) E-Mails → user_ids auflösen VOR der Gruppenerstellung
        var validUserIds: [(UUID, role)] = []
        
        if !cleanedUsers.isEmpty {
            let emails = cleanedUsers.map { $0.email }
            print("🔍 Suche in DB nach: \(emails)")
            
            let userRows: [AppUser] = try await db
                .from(usersTable)
                .select("id,display_name,email")
                .in("email", values: emails)
                .execute()
                .value

            print("🔍 Gefundene User in DB: \(userRows.map { $0.email })")

            let byEmail = Dictionary(uniqueKeysWithValues: userRows.map { ($0.email.lowercased(), $0.id) })
            print("🔍 Email→ID Mapping: \(byEmail)")
            
            for invitedUser in cleanedUsers {
                if let uid = byEmail[invitedUser.email] {
                    print("✅ Gefunden: \(invitedUser.email) → \(uid)")
                    if uid != ownerId {
                        validUserIds.append((uid, invitedUser.role))
                    }
                } else {
                    print("❌ Nicht gefunden: \(invitedUser.email)")
                    unknownEmails.append(invitedUser.email)
                }
            }
        }

        print("🔍 Unbekannte E-Mails: \(unknownEmails)")

        // 3) Unbekannte E-Mails als Fehler werfen VOR der Gruppenerstellung
        if !unknownEmails.isEmpty {
            print("🚨 Werfe GroupError.unknownAppleIds mit: \(unknownEmails)")
            throw GroupError.unknownAppleIds(unknownEmails)
        }

        // 4) ERST JETZT Gruppe anlegen (wenn alle E-Mails gültig sind)
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

        // 5) Mitglieder hinzufügen
        struct MemberRequest: Encodable {
            let group_id: UUID
            let user_id: UUID
            let role: role
        }
        
        var memberRequests: [MemberRequest] = [
            MemberRequest(group_id: groupId, user_id: ownerId, role: .owner)
        ]
        
        // Gültige User hinzufügen
        for (userId, userRole) in validUserIds {
            memberRequests.append(MemberRequest(
                group_id: groupId,
                user_id: userId,
                role: userRole
            ))
        }

        // 6) Member-Bulk
        if !memberRequests.isEmpty {
            _ = try await db
                .from(membersTable)
                .upsert(memberRequests, onConflict: "group_id,user_id", returning: .minimal)
                .execute()
        }
        
        print("✅ Gruppe '\(name)' erstellt mit \(memberRequests.count) Mitgliedern")
        print("📋 Rollen: \(memberRequests.map { "\($0.user_id): \($0.role)" })")
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
    
    
    // Im SupabaseGroupRepository
    func leaveGroup(groupId: UUID) async throws {
        let currentUserId = try await auth.currentUserId()
        
        try await db
            .from(membersTable)
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: currentUserId.uuidString)
            .execute()
            
        print("✅ User \(currentUserId) hat Gruppe \(groupId) verlassen")
    }

    func transferOwnership(groupId: UUID, newOwnerId: UUID) async throws {
        struct UpdateOwnerRequest: Encodable {
            let owner_id: UUID
        }
        
        try await db
            .from(groupsTable)
            .update(UpdateOwnerRequest(owner_id: newOwnerId))
            .eq("id", value: groupId.uuidString)
            .execute()
        
        print("✅ Gruppen-Besitzer geändert zu: \(newOwnerId)")
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
            // 👈 BESSERE FEHLERMELDUNG
            throw NSError(
                domain: "GroupError",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Benutzer mit E-Mail '\(email)' wurde nicht gefunden."]
            )
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
            throw NSError(
                domain: "GroupError",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Benutzer '\(invitedUser.display_name)' ist bereits Gruppenmitglied"]
            )
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
