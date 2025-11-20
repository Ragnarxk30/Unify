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

// Backend/Models/Message.swift
struct Message: Identifiable, Codable {
    let id: UUID
    let group_id: UUID
    let content: String
    let sent_by: UUID
    let sent_at: Date
    let user: AppUser?
    
    // 👈 NEUE FELDER FÜR SPRACHNACHRICHTEN
    let message_type: String?  // "text" oder "voice"
    let voice_duration: Int?   // Dauer in Sekunden
    let voice_url: String?     // URL zur Audio-Datei
    
    enum CodingKeys: String, CodingKey {
        case id
        case group_id
        case content
        case sent_by
        case sent_at
        case user
        case message_type
        case voice_duration
        case voice_url
    }
    
    // 👈 COMPUTED PROPERTIES FÜR BEQUEMLICHKEIT
    var isVoiceMessage: Bool {
        message_type == "voice"
    }
    
    var isTextMessage: Bool {
        message_type == "text" || message_type == nil
    }
    
    var sender: AppUser {
        user ?? AppUser(id: sent_by, display_name: "Unbekannt", email: "")
    }
    
    // 👈 Formatierte Dauer für Voice Messages
    var formattedDuration: String? {
        guard let duration = voice_duration else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

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
    // ✅ Synthetische ID für SwiftUI
    var id: String { "\(user_id)-\(group_id)" }
    
    let user_id: UUID
    let group_id: UUID
    let role: role
    let joined_at: Date
    let user: AppUser?
    
    // ✅ FEHLT: memberUser computed property
    var memberUser: AppUser {
        user ?? AppUser(id: user_id, display_name: "Unbekannt", email: "")
    }
    
    // ✅ CodingKeys um 'id' zu ignorieren
    enum CodingKeys: String, CodingKey {
        case user_id, group_id, role, joined_at, user
    }
}

// MARK: - role Enum (kleingeschrieben wie dein PostgreSQL ENUM)
enum role: String, Codable, CaseIterable {
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
