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
    let description: String?
    let start: Date
    let end: Date
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


