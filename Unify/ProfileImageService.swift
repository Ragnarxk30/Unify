import Foundation
import Supabase
import UIKit
import Combine

@MainActor
final class ProfileImageService: ObservableObject {
    
    // MARK: - Published Properties (für ObservableObject)
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let storage = supabase.storage
    private let bucketName = "profile-pictures"
    private let auth: AuthRepository
    
    init(auth: AuthRepository = SupabaseAuthRepository()) {
        self.auth = auth
    }
    
    // MARK: - Upload/Replace Profilbild (immer gleicher Name)
    func uploadProfilePicture(_ image: UIImage, fileExtension: String = "jpg") async throws -> String {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let userId = try await auth.currentUserId()
            let format = fileExtension.lowercased()
            let contentType = format == "png" ? "image/png" : "image/jpeg"
            
            guard let imageData = format == "png" ? image.pngData() : image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bild konnte nicht konvertiert werden"])
            }
            
            // 👈 IMMER GLEICHER NAME: Nur die User-ID
            let fileName = userId.uuidString.lowercased() // 👈 lowercase für Konsistenz
            
            print("📤 Upload Profilbild: \(fileName) als \(contentType)")
            
            // Prüfen ob bereits ein Profilbild existiert
            let existingFiles = try await storage
                .from(bucketName)
                .list()
            
            let userFiles = existingFiles.filter {
                $0.name.lowercased() == fileName.lowercased()
            }
            
            // Falls existiert, löschen
            if !userFiles.isEmpty {
                print("🗑️ Lösche vorhandenes Profilbild: \(userFiles.map { $0.name })")
                try await storage
                    .from(bucketName)
                    .remove(paths: [fileName])
            }
            
            // Neues Bild hochladen
            _ = try await storage
                .from(bucketName)
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: true // 👈 Überschreibt falls vorhanden
                    )
                )
            
            // Public URL holen
            let publicURL = try storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            // Cache-Busting URL mit Timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            let cacheBustedURL = "\(publicURL.absoluteString)?t=\(timestamp)"
            
            print("✅ Profilbild erfolgreich hochgeladen: \(cacheBustedURL)")
            
            return cacheBustedURL
            
        } catch {
            await MainActor.run {
                errorMessage = "Upload fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Profilbild Upload Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Download Profile Picture (für aktuellen User - SettingsView)
    func downloadProfilePicture() async throws -> Data {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let userId = try await auth.currentUserId()
            let fileName = userId.uuidString.lowercased()
            
            print("📥 Download Profilbild: \(fileName)")
            
            let data = try await storage
                .from(bucketName)
                .download(path: fileName)
            
            print("✅ Profilbild erfolgreich geladen (\(data.count) bytes)")
            
            return data
            
        } catch {
            await MainActor.run {
                errorMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Profilbild Download Error: \(error)")
            throw error
        }
    }

    // MARK: - Download Profile Picture for ANY user (für Chats)
    func downloadProfilePicture(for userId: UUID) async throws -> Data {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let fileName = userId.uuidString.lowercased()
            
            print("📥 Download Profilbild für User \(userId): \(fileName)")
            
            let data = try await storage
                .from(bucketName)
                .download(path: fileName)
            
            print("✅ Profilbild für User \(userId) erfolgreich geladen (\(data.count) bytes)")
            
            return data
            
        } catch {
            await MainActor.run {
                errorMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Profilbild Download für User \(userId) Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete Profilbild (exakter Name)
    func deleteProfilePicture() async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let userId = try await auth.currentUserId()
            let fileName = userId.uuidString.lowercased() // 👈 Exakt der User-ID
            
            print("🗑️ Lösche Profilbild: \(fileName)")
            
            try await storage
                .from(bucketName)
                .remove(paths: [fileName])
            
            print("✅ Profilbild erfolgreich gelöscht")
            
        } catch {
            await MainActor.run {
                errorMessage = "Löschen fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Profilbild Delete Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Check if Profile Picture exists (exakter Name)
    func checkProfilePictureExists() async throws -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let userId = try await auth.currentUserId()
            let fileName = userId.uuidString.lowercased() // 👈 Exakt der User-ID
            
            let existingFiles = try await storage
                .from(bucketName)
                .list()
            
            let userFiles = existingFiles.filter {
                $0.name.lowercased() == fileName.lowercased()
            }
            
            return !userFiles.isEmpty
            
        } catch {
            await MainActor.run {
                errorMessage = "Check fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Check Profile Picture Error: \(error)")
            return false
        }
    }
    
    // MARK: - Get Profile Picture URL
    func getProfilePictureURL() async -> String {
        do {
            let userId = try await auth.currentUserId()
            let fileName = userId.uuidString
            
            let publicURL = try storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            return publicURL.absoluteString
            
        } catch {
            print("⚠️ Konnte Profilbild URL nicht generieren: \(error)")
            return ""
        }
    }
}
