import Combine
import SwiftUI

final class ColorManager: ObservableObject {
    // Persistent assignments of userID -> Color
    @Published private(set) var assignments: [UUID: Color] = [:]

    // Full palette (can be customized)
    private let palette: [Color] = [
        Color(hex: 0xFF0000),  // Rot
        Color(hex: 0x00AA00),  // Grün
        Color(hex: 0xFFD300),  // Gelb
        Color(hex: 0xFF7F00),  // Orange
        Color(hex: 0x8B00FF),  // Violett
        Color(hex: 0x00CED1),  // Türkis
        Color(hex: 0xFF66B2),  // Rosa
        Color(hue: 0.58, saturation: 0.6, brightness: 0.7),
        Color(hue: 0.08, saturation: 0.7, brightness: 0.9),
        Color(hue: 0.33, saturation: 0.6, brightness: 0.7),
        Color(hue: 0.76, saturation: 0.5, brightness: 0.7)
    ]

    // Pool of colors that are still available to be assigned
    @Published private var available: [Color] = []

    init() {
        resetAvailable()
    }

    private func resetAvailable() {
        available = palette
    }

    // ✅ Korrigierte API: Eigene Nachrichten sind immer blau 
    func color(for user: AppUser, isCurrentUser: Bool = false) -> Color {
            if isCurrentUser {
                return .blue
            }
            if let assigned = assignments[user.id] {
                return assigned
            }
            let newColor = takeRandomAvailableColor()
            assignments[user.id] = newColor
            return newColor
        }

    // ✅ Alternative Methode für temporäre UserProfile (falls noch benötigt)
    func color(for userProfile: UserProfile, isCurrentUser: Bool = false) -> Color {
        if isCurrentUser {
            return .blue
        }
        if let assigned = assignments[userProfile.id] {
            return assigned
        }
        let newColor = takeRandomAvailableColor()
        assignments[userProfile.id] = newColor
        return newColor
    }

    private func takeRandomAvailableColor() -> Color {
        if available.isEmpty {
            // All colors used: allow reuse by resetting the available pool.
            resetAvailable()
            // Note: we keep existing assignments; reset only affects future new users.
        }
        let idx = Int.random(in: 0..<available.count)
        let chosen = available[idx]
        available.remove(at: idx)
        return chosen
    }

    // ✅ Reset-Funktion für Logout/Login
    func reset() {
        assignments.removeAll()
        resetAvailable()
    }
}

extension Color {
    // Hex initializer used by ColorManager palette
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
