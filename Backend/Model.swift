// Models/User.swift
import Foundation

struct AppUser: Codable {
    let id: UUID
    let display_name: String
    let email: String
}

// Models/AuthError.swift
enum AuthError: Error {
    case userCreationFailed
    case userNotFound
    case invalidCredentials
    case networkError
    case unknownError
}
