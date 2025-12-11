import Foundation
import Supabase
import UIKit
import Combine

@MainActor
final class ProfileImageService: ObservableObject {
    
    // MARK: - Singleton für globalen Cache
    static let shared = ProfileImageService()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Cache Properties
    private let imageCache = NSCache<NSString, UIImage>()
    private var loadingTasks: [UUID: Task<UIImage?, Error>] = [:]
    
    // MARK: - Private Properties
    private let storage = supabase.storage
    private let bucketName = "profile-pictures"
    private let auth: AuthRepository
    
    init(auth: AuthRepository = SupabaseAuthRepository()) {
        self.auth = auth
        // Cache konfigurieren
        imageCache.countLimit = 100 // Max 100 Bilder im Cache
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB Speicherlimit
    }
    
    // MARK: - Cached Image Loading
    func getCachedProfileImage(for userId: UUID) async -> UIImage? {
        // Prüfe Cache zuerst
        let cacheKey = userId.uuidString as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("✅ Profilbild aus Cache geladen für User: \(userId)")
            return cachedImage
        }
        
        // Vermeide doppelte Downloads - prüfe ob bereits lädt
        if let existingTask = loadingTasks[userId] {
            print("⏳ Warte auf bereits laufenden Download für User: \(userId)")
            return try? await existingTask.value
        }
        
        // Starte Download-Task mit @MainActor
        print("📥 Starte neuen Download für User: \(userId)")
        let task = Task<UIImage?, Error> { @MainActor in
            defer {
                loadingTasks.removeValue(forKey: userId)
                print("🏁 Download-Task beendet für User: \(userId)")
            }
            
            do {
                let imageData = try await downloadProfilePicture(for: userId)
                guard let image = UIImage(data: imageData) else {
                    print("❌ Konnte Bilddaten nicht in UIImage konvertieren für User: \(userId)")
                    return nil
                }
                
                // In Cache speichern
                imageCache.setObject(image, forKey: cacheKey)
                print("✅ Profilbild heruntergeladen und gecached für User: \(userId)")
                return image
                
            } catch {
                print("❌ Fehler beim Laden des Profilbilds für \(userId): \(error)")
                return nil
            }
        }
        
        loadingTasks[userId] = task
        let result = try? await task.value
        print("📦 Returning result: \(result != nil) für User: \(userId)")
        return result
    }
    // MARK: - Cache Management
    func clearCache() {
        imageCache.removeAllObjects()
        loadingTasks.removeAll()
        print("🗑️ Profilbild-Cache komplett geleert")
    }
    
    func clearCache(for userId: UUID) {
        let cacheKey = userId.uuidString as NSString
        imageCache.removeObject(forKey: cacheKey)
        loadingTasks.removeValue(forKey: userId)
        print("🗑️ Profilbild-Cache geleert für User: \(userId)")
    }
    
    // MARK: - Upload/Replace Profilbild
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
            
            let fileName = userId.uuidString.lowercased()
            
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
                
                // Cache ebenfalls löschen
                clearCache(for: userId)
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
                        upsert: true
                    )
                )
            
            // Neues Bild in Cache speichern
            imageCache.setObject(image, forKey: fileName as NSString)
            
            let publicURL = try storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            let timestamp = Int(Date().timeIntervalSince1970)
            let cacheBustedURL = "\(publicURL.absoluteString)?t=\(timestamp)"
            
            print("✅ Profilbild erfolgreich hochgeladen und gecached: \(cacheBustedURL)")
            
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
