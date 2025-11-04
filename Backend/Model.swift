// Models/User.swift
import Foundation

struct User: Codable {
    let id: UUID
    let display_name: String
}

// Models/AuthError.swift
enum AuthError: Error {
    case userCreationFailed
    case userNotFound
    case invalidCredentials
    case networkError
    case unknownError
}
