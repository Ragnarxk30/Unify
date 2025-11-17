import Foundation

// Backend/Models/AppUser.swift
struct AppUser: Codable {
    let id: UUID
    let display_name: String
    let email: String
}

// Backend/Models/AuthError.swift
enum AuthError: Error {
    case userCreationFailed
    case userNotFound
    case invalidCredentials
    case networkError
    case unknownError
}

// Gruppen Model
struct AppGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let owner_id: UUID
    let user: AppUser?
    
    var owner: AppUser {
        user ?? AppUser(id: owner_id, display_name: "Unbekannt", email: "")
    }
}

// Event Model
struct Event: Identifiable, Codable {
    let id: UUID
    let title: String
    let details: String?
    let starts_at: Date
    let ends_at: Date
    let group_id: UUID?
    let created_by: UUID
    let created_at: Date
}

// In Backend/model.swift - Message Model anpassen 
struct Message: Identifiable, Codable {
    let id: UUID
    let group_id: UUID
    let content: String  // ✅ content statt text
    let sent_by: UUID    // ✅ sent_by statt sender_id
    let sent_at: Date
    let user: AppUser?   // Für Join mit user Tabelle
    
    var sender: AppUser {
        user ?? AppUser(id: sent_by, display_name: "Unbekannt", email: "")
    }
}
//hallo
struct UserProfile: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var initials: String {
        let comps = displayName.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - GroupMember Model
struct GroupMember: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let group_id: UUID
    let role: MemberRole
    let joined_at: Date
    let user: AppUser? // Für Join mit user Tabelle
    
    // Computed property für einfacheren Zugriff
    var memberUser: AppUser {
        user ?? AppUser(id: user_id, display_name: "Unbekannt", email: "")
    }
}

// MARK: - MemberRole Enum (nur Werte, keine Logik)
enum MemberRole: String, Codable, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case user = "user"
    
    var displayName: String {
        switch self {
        case .owner: return "Besitzer"
        case .admin: return "Administrator"
        case .user: return "Mitglied"
        }
    }
}

// MARK: - Error Enum
enum GroupError: Error {
    case unknownAppleIds([String])
    case emptyName
    case notGroupOwner
    case userNotFound
}
