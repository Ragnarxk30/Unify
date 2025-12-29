import Foundation
import Supabase
import UIKit
import Combine

@MainActor
final class GroupImageService: ObservableObject {
    
    // MARK: - Singleton für globalen Cache
    static let shared = GroupImageService()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Cache Properties
    private let imageCache = NSCache<NSString, UIImage>()
    private var loadingTasks: [UUID: Task<UIImage?, Error>] = [:]
    
    // MARK: - Private Properties
    private let storage = supabase.storage
    private let bucketName = "group-pictures"
    
    init() {
        // Cache konfigurieren
        imageCache.countLimit = 50 // Max 50 Gruppenbilder im Cache
        imageCache.totalCostLimit = 25 * 1024 * 1024 // 25MB Speicherlimit
    }
    
    // MARK: - Cached Circle Image Loading
    func getCachedGroupImageCircle(for groupId: UUID) async -> UIImage? {
        // Prüfe Cache zuerst
        let fileName = "\(groupId.uuidString.lowercased())_circle"
        let cacheKey = fileName as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("✅ Circle-Bild aus Cache geladen für Gruppe: \(groupId)")
            return cachedImage
        }

        // Vermeide doppelte Downloads
        let circleId = UUID() // Dummy ID für Circle
        if let existingTask = loadingTasks[circleId] {
            print("⏳ Warte auf bereits laufenden Circle-Download für Gruppe: \(groupId)")
            return try? await existingTask.value
        }

        // Starte Download-Task
        print("📥 Starte neuen Circle-Download für Gruppe: \(groupId)")
        let task = Task<UIImage?, Error> { @MainActor in
            defer {
                loadingTasks.removeValue(forKey: circleId)
                print("🏁 Circle-Download-Task beendet für Gruppe: \(groupId)")
            }

            do {
                let imageData = try await downloadGroupPictureCircle(for: groupId)
                guard let image = UIImage(data: imageData) else {
                    print("❌ Konnte Circle-Bilddaten nicht in UIImage konvertieren für Gruppe: \(groupId)")
                    return nil
                }

                // In Cache speichern
                imageCache.setObject(image, forKey: cacheKey)
                print("✅ Circle-Bild heruntergeladen und gecached für Gruppe: \(groupId)")
                return image

            } catch {
                print("❌ Fehler beim Laden des Circle-Bilds für \(groupId): \(error)")
                return nil
            }
        }

        loadingTasks[circleId] = task
        let result = try? await task.value
        print("📦 Returning circle result: \(result != nil) für Gruppe: \(groupId)")
        return result
    }

    // MARK: - Cached Image Loading
    func getCachedGroupImage(for groupId: UUID) async -> UIImage? {
        // Prüfe Cache zuerst
        let cacheKey = groupId.uuidString.lowercased() as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("✅ Gruppenbild aus Cache geladen für Gruppe: \(groupId)")
            return cachedImage
        }
        
        // Vermeide doppelte Downloads - prüfe ob bereits lädt
        if let existingTask = loadingTasks[groupId] {
            print("⏳ Warte auf bereits laufenden Download für Gruppe: \(groupId)")
            return try? await existingTask.value
        }
        
        // Starte Download-Task mit @MainActor
        print("📥 Starte neuen Download für Gruppe: \(groupId)")
        let task = Task<UIImage?, Error> { @MainActor in
            defer {
                loadingTasks.removeValue(forKey: groupId)
                print("🏁 Download-Task beendet für Gruppe: \(groupId)")
            }
            
            do {
                let imageData = try await downloadGroupPicture(for: groupId)
                guard let image = UIImage(data: imageData) else {
                    print("❌ Konnte Bilddaten nicht in UIImage konvertieren für Gruppe: \(groupId)")
                    return nil
                }
                
                // In Cache speichern
                imageCache.setObject(image, forKey: cacheKey)
                print("✅ Gruppenbild heruntergeladen und gecached für Gruppe: \(groupId)")
                return image
                
            } catch {
                print("❌ Fehler beim Laden des Gruppenbilds für \(groupId): \(error)")
                return nil
            }
        }
        
        loadingTasks[groupId] = task
        let result = try? await task.value
        print("📦 Returning result: \(result != nil) für Gruppe: \(groupId)")
        return result
    }
    
    // MARK: - Cache Management
    func clearCache() {
        imageCache.removeAllObjects()
        loadingTasks.removeAll()
        print("🗑️ Gruppenbild-Cache komplett geleert")
    }
    
    func clearCache(for groupId: UUID) {
        let cacheKey = groupId.uuidString.lowercased() as NSString
        imageCache.removeObject(forKey: cacheKey)
        loadingTasks.removeValue(forKey: groupId)
        print("🗑️ Gruppenbild-Cache geleert für Gruppe: \(groupId)")
    }
    
    // MARK: - Upload Circle-Ausschnitt
    func uploadGroupPictureCircle(_ image: UIImage, for groupId: UUID, fileExtension: String = "jpg") async throws -> String {
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
            let format = fileExtension.lowercased()
            let contentType = format == "png" ? "image/png" : "image/jpeg"

            guard let imageData = format == "png" ? image.pngData() : image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bild konnte nicht konvertiert werden"])
            }

            let fileName = "\(groupId.uuidString.lowercased())_circle"

            print("📤 Upload Gruppenbild Circle: \(fileName) als \(contentType)")

            // Prüfen ob bereits ein Circle-Bild existiert
            let existingFiles = try await storage
                .from(bucketName)
                .list()

            let circleFiles = existingFiles.filter {
                $0.name.lowercased() == fileName.lowercased()
            }

            // Falls existiert, löschen
            if !circleFiles.isEmpty {
                print("🗑️ Lösche vorhandenes Circle-Bild: \(circleFiles.map { $0.name })")
                try await storage
                    .from(bucketName)
                    .remove(paths: [fileName])

                // Cache ebenfalls löschen
                let cacheKey = fileName as NSString
                imageCache.removeObject(forKey: cacheKey)
            }

            // Neues Circle-Bild hochladen
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

            // Neues Circle-Bild in Cache speichern
            imageCache.setObject(image, forKey: fileName as NSString)

            let publicURL = try storage
                .from(bucketName)
                .getPublicURL(path: fileName)

            let timestamp = Int(Date().timeIntervalSince1970)
            let cacheBustedURL = "\(publicURL.absoluteString)?t=\(timestamp)"

            print("✅ Circle-Bild erfolgreich hochgeladen und gecached: \(cacheBustedURL)")

            return cacheBustedURL

        } catch {
            await MainActor.run {
                errorMessage = "Circle Upload fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Circle-Bild Upload Error: \(error)")
            throw error
        }
    }

    // MARK: - Upload/Replace Gruppenbild
    func uploadGroupPicture(_ image: UIImage, for groupId: UUID, fileExtension: String = "jpg") async throws -> String {
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
            let format = fileExtension.lowercased()
            let contentType = format == "png" ? "image/png" : "image/jpeg"
            
            guard let imageData = format == "png" ? image.pngData() : image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bild konnte nicht konvertiert werden"])
            }
            
            let fileName = groupId.uuidString.lowercased()
            
            print("📤 Upload Gruppenbild: \(fileName) als \(contentType)")
            
            // Prüfen ob bereits ein Gruppenbild existiert
            let existingFiles = try await storage
                .from(bucketName)
                .list()
            
            let groupFiles = existingFiles.filter {
                $0.name.lowercased() == fileName.lowercased()
            }
            
            // Falls existiert, löschen
            if !groupFiles.isEmpty {
                print("🗑️ Lösche vorhandenes Gruppenbild: \(groupFiles.map { $0.name })")
                try await storage
                    .from(bucketName)
                    .remove(paths: [fileName])
                
                // Cache ebenfalls löschen
                clearCache(for: groupId)
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
            
            print("✅ Gruppenbild erfolgreich hochgeladen und gecached: \(cacheBustedURL)")
            
            return cacheBustedURL
            
        } catch {
            await MainActor.run {
                errorMessage = "Upload fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Gruppenbild Upload Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Download Circle Picture
    func downloadGroupPictureCircle(for groupId: UUID) async throws -> Data {
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
            let fileName = "\(groupId.uuidString.lowercased())_circle"

            print("📥 Download Circle-Bild für Gruppe \(groupId): \(fileName)")

            let data = try await storage
                .from(bucketName)
                .download(path: fileName)

            print("✅ Circle-Bild für Gruppe \(groupId) erfolgreich geladen (\(data.count) bytes)")

            return data

        } catch {
            await MainActor.run {
                errorMessage = "Circle-Download fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Circle-Bild Download für Gruppe \(groupId) Error: \(error)")
            throw error
        }
    }

    // MARK: - Download Group Picture
    func downloadGroupPicture(for groupId: UUID) async throws -> Data {
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
            let fileName = groupId.uuidString.lowercased()
            
            print("📥 Download Gruppenbild für Gruppe \(groupId): \(fileName)")
            
            let data = try await storage
                .from(bucketName)
                .download(path: fileName)
            
            print("✅ Gruppenbild für Gruppe \(groupId) erfolgreich geladen (\(data.count) bytes)")
            
            return data
            
        } catch {
            await MainActor.run {
                errorMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Gruppenbild Download für Gruppe \(groupId) Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete Circle Picture
    func deleteGroupPictureCircle(for groupId: UUID) async throws {
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
            let fileName = "\(groupId.uuidString.lowercased())_circle"

            print("🗑️ Lösche Circle-Bild: \(fileName)")

            try await storage
                .from(bucketName)
                .remove(paths: [fileName])

            // Cache löschen
            let cacheKey = fileName as NSString
            imageCache.removeObject(forKey: cacheKey)

            print("✅ Circle-Bild erfolgreich gelöscht")

        } catch {
            await MainActor.run {
                errorMessage = "Circle-Löschen fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Circle-Bild Delete Error: \(error)")
            throw error
        }
    }

    // MARK: - Delete Gruppenbild
    func deleteGroupPicture(for groupId: UUID) async throws {
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
            let fileName = groupId.uuidString.lowercased()
            
            print("🗑️ Lösche Gruppenbild: \(fileName)")
            
            try await storage
                .from(bucketName)
                .remove(paths: [fileName])
            
            // Cache löschen
            clearCache(for: groupId)
            
            print("✅ Gruppenbild erfolgreich gelöscht")
            
        } catch {
            await MainActor.run {
                errorMessage = "Löschen fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Gruppenbild Delete Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Check if Group Picture exists
    func checkGroupPictureExists(for groupId: UUID) async throws -> Bool {
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
            let fileName = groupId.uuidString.lowercased()
            
            let existingFiles = try await storage
                .from(bucketName)
                .list()
            
            let groupFiles = existingFiles.filter {
                $0.name.lowercased() == fileName.lowercased()
            }
            
            return !groupFiles.isEmpty
            
        } catch {
            await MainActor.run {
                errorMessage = "Check fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Check Group Picture Error: \(error)")
            return false
        }
    }
    
    // MARK: - Get Group Picture URL
    func getGroupPictureURL(for groupId: UUID) -> String {
        do {
            let fileName = groupId.uuidString.lowercased()
            
            let publicURL = try storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            return publicURL.absoluteString
            
        } catch {
            print("⚠️ Konnte Gruppenbild URL nicht generieren: \(error)")
            return ""
        }
    }
}
