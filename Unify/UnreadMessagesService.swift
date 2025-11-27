import Foundation
import Supabase
import Combine

// MARK: - Service für Unread Messages mit Realtime
@MainActor
class UnreadMessagesService: ObservableObject {
    static let shared = UnreadMessagesService()
    
    private let db = supabase
    private let auth: AuthRepository = SupabaseAuthRepository()
    
    // 👈 Published damit SwiftUI automatisch updated
    @Published var unreadCounts: [UUID: Int] = [:]
    
    // 👈 Realtime Channels pro Gruppe
    private var realtimeChannels: [UUID: RealtimeChannelV2] = [:]
    
    private init() {}
    
    // MARK: - Ungelesene Nachrichten zählen
    func getUnreadCount(for groupId: UUID) async throws -> Int {
        let userId = try await auth.currentUserId()
        
        print("🔍 [UnreadService] Zähle ungelesene für Gruppe: \(groupId)")
        
        // 1) Letzten Besuch holen (last_read_at)
        struct LastRead: Codable {
            let last_read_at: Date?
        }
        
        let lastReadResult: [LastRead] = try await db
            .from("group_members")
            .select("last_read_at")
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        guard let lastReadAt = lastReadResult.first?.last_read_at else {
            let allCount = try await countAllMessages(for: groupId, userId: userId)
            unreadCounts[groupId] = allCount
            return allCount
        }
        
        // 2) Nachrichten seit last_read_at zählen
        let count = try await countMessagesSince(groupId: groupId, since: lastReadAt, userId: userId)
        unreadCounts[groupId] = count
        
        print("🔍 [UnreadService] Ungelesene: \(count)")
        return count
    }
    
    // MARK: - Alle Nachrichten zählen
    private func countAllMessages(for groupId: UUID, userId: UUID) async throws -> Int {
        struct CountResult: Codable {
            let count: Int
        }
        
        let result: [CountResult] = try await db
            .from("message")
            .select("count", head: false, count: .exact)
            .eq("group_id", value: groupId.uuidString)
            .neq("sent_by", value: userId.uuidString)
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    // MARK: - Nachrichten seit Datum zählen
    private func countMessagesSince(groupId: UUID, since: Date, userId: UUID) async throws -> Int {
        struct CountResult: Codable {
            let count: Int
        }
        
        let result: [CountResult] = try await db
            .from("message")
            .select("count", head: false, count: .exact)
            .eq("group_id", value: groupId.uuidString)
            .gt("sent_at", value: since.ISO8601Format())
            .neq("sent_by", value: userId.uuidString)
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    // MARK: - 🔥 REALTIME: Neue Nachrichten live zählen
    func startRealtimeTracking(for groupId: UUID) async throws {
        // 👈 Wenn schon aktiv, nicht nochmal starten (wichtig!)
        guard realtimeChannels[groupId] == nil else {
            print("ℹ️ [UnreadService] Realtime bereits aktiv für Gruppe: \(groupId)")
            return
        }
        
        let userId = try await auth.currentUserId()
        
        let channel = db.realtimeV2.channel("unread_\(groupId)")
        
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "message",
            filter: .eq("group_id", value: groupId)
        )
        
        Task {
            for await action in changes {
                await handleNewMessage(action, groupId: groupId, userId: userId)
            }
        }
        
        try await channel.subscribe()
        realtimeChannels[groupId] = channel
        
        print("✅ [UnreadService] Realtime gestartet für Gruppe: \(groupId)")
    }
    
    // MARK: - Realtime Handler
    private func handleNewMessage(_ action: InsertAction, groupId: UUID, userId: UUID) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(action.record)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            struct MessageInsert: Codable {
                let sent_by: UUID
                let group_id: UUID
            }
            
            let message = try decoder.decode(MessageInsert.self, from: data)
            
            // Nur fremde Nachrichten zählen
            guard message.sent_by != userId else { return }
            guard message.group_id == groupId else { return }
            
            // Counter erhöhen
            let current = unreadCounts[groupId] ?? 0
            unreadCounts[groupId] = current + 1
            
            print("🔥 [UnreadService] Neue Nachricht! Ungelesen: \(current + 1)")
            
        } catch {
            print("❌ [UnreadService] Realtime decode error: \(error)")
        }
    }
    
    // MARK: - Realtime stoppen (nur für eine Gruppe)
    func stopRealtimeTracking(for groupId: UUID) {
        Task {
            if let channel = realtimeChannels[groupId] {
                try? await channel.unsubscribe()
                realtimeChannels[groupId] = nil
                print("🛑 [UnreadService] Realtime gestoppt für Gruppe: \(groupId)")
            }
        }
    }
    
    // MARK: - Als gelesen markieren
    func markAsRead(groupId: UUID) async throws {
        let userId = try await auth.currentUserId()
        
        struct UpdateLastRead: Encodable {
            let last_read_at: String
        }
        
        let now = Date().ISO8601Format()
        
        try await db
            .from("group_members")
            .update(UpdateLastRead(last_read_at: now))
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // Cache auf 0 setzen
        unreadCounts[groupId] = 0
        print("✅ [UnreadService] Als gelesen markiert: Gruppe \(groupId)")
    }
    
    // MARK: - Alle Counts aktualisieren (Smart!)
    func refreshAllUnreadCounts(for groupIds: [UUID]) async throws {
        for groupId in groupIds {
            // Counts aktualisieren
            _ = try? await getUnreadCount(for: groupId)
            
            // 👈 Realtime nur starten wenn noch nicht aktiv!
            if realtimeChannels[groupId] == nil {
                try? await startRealtimeTracking(for: groupId)
            } else {
                print("ℹ️ [UnreadService] Realtime läuft bereits für Gruppe: \(groupId)")
            }
        }
    }
    
    // MARK: - 👈 Prüfen ob Realtime für Gruppe aktiv ist
    func isRealtimeActive(for groupId: UUID) -> Bool {
        return realtimeChannels[groupId] != nil
    }
    
    // MARK: - 👈 Anzahl aktiver Realtime-Connections
    var activeRealtimeCount: Int {
        return realtimeChannels.count
    }
    
    // MARK: - Cleanup (nur bei App-Beendigung oder Logout!)
    func cleanup() {
        print("⚠️ [UnreadService] Cleanup - Stoppe alle \(realtimeChannels.count) Realtime-Connections")
        for (groupId, _) in realtimeChannels {
            stopRealtimeTracking(for: groupId)
        }
    }
    
    // MARK: - 👈 NEU: Cleanup nur für spezifische Gruppe (wenn User Gruppe verlässt)
    func cleanupGroup(_ groupId: UUID) {
        print("🧹 [UnreadService] Cleanup für einzelne Gruppe: \(groupId)")
        stopRealtimeTracking(for: groupId)
        unreadCounts.removeValue(forKey: groupId)
    }
}
