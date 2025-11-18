import Foundation
import Supabase

struct ChatEndpoints {
    
    private static let db = supabase
    private static let messagesTable = "message"
    private static let auth: AuthRepository = SupabaseAuthRepository()
    
    // ✅ Real-Time Subscriptions
    private static var subscriptions: [UUID: RealtimeChannelV2] = [:]
    
    // ✅ Thread-sicherer Cache mit Actor
    private actor UserCache {
        private var cache: [UUID: AppUser] = [:]
        
        func get(userId: UUID) -> AppUser? {
            return cache[userId]
        }
        
        func set(user: AppUser) {
            cache[user.id] = user
        }
        
        func setMultiple(from messages: [Message]) {
            for message in messages {
                if let user = message.user {
                    cache[user.id] = user
                }
            }
        }
    }
    
    private static let userCache = UserCache()
    
    // MARK: - Message Operations
    
    static func fetchMessages(for groupID: UUID) async throws -> [Message] {
        let messages: [Message] = try await db
            .from(messagesTable)
            .select("""
                id,
                group_id,
                content,
                sent_by,
                sent_at,
                user:user!sent_by(
                    id,
                    display_name,
                    email
                )
            """)
            .eq("group_id", value: groupID)
            .order("sent_at", ascending: true)
            .execute()
            .value
        
        // ✅ Cache mit allen Usern füllen
        await userCache.setMultiple(from: messages)
        
        return messages
    }
    
    static func sendMessage(groupID: UUID, content: String) async throws -> Message {
        let userId = try await auth.currentUserId()
        
        let payload = CreateMessagePayload(
            group_id: groupID,
            content: content,
            sent_by: userId
        )
        
        let message: Message = try await db
            .from(messagesTable)
            .insert(payload)
            .select("""
                id,
                group_id,
                content,
                sent_by,
                sent_at,
                user:user!sent_by(
                    id,
                    display_name,
                    email
                )
            """)
            .single()
            .execute()
            .value
        
        // ✅ Sender zum Cache hinzufügen
        if let user = message.user {
            await userCache.set(user: user)
        }
        
        return message
    }
    
    // MARK: - Real-Time Implementation
    
    static func startRealtimeSubscription(
        for groupID: UUID,
        onNewMessage: @escaping (Message) -> Void
    ) async throws {
        
        stopRealtimeSubscription(for: groupID)
        
        let channel = db.realtimeV2.channel("group_chat_\(groupID)")
        
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "message",
            filter: .eq("group_id", value: groupID)
        )
        
        Task {
            for await action in changes {
                await handleNewMessage(action, groupID: groupID, onNewMessage: onNewMessage)
            }
        }
        
        try await channel.subscribe()
        subscriptions[groupID] = channel
        
        print("✅ Real-Time Subscription gestartet für Gruppe: \(groupID)")
    }
    
    static func stopRealtimeSubscription(for groupID: UUID) {
        Task {
            if let channel = subscriptions[groupID] {
                try? await channel.unsubscribe()
                subscriptions.removeValue(forKey: groupID)
                print("🔕 Real-Time Subscription gestoppt für Gruppe: \(groupID)")
            }
        }
    }
    
    // ✅ WhatsApp-Style Real-Time Handling mit Cache
    private static func handleNewMessage(
        _ action: InsertAction,
        groupID: UUID,
        onNewMessage: @escaping (Message) -> Void
    ) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let jsonData = try JSONEncoder().encode(action.record)
            let rawMessage = try decoder.decode(Message.self, from: jsonData)
            
            guard rawMessage.group_id == groupID else { return }
            
            // ✅ SCHRITT 1: Prüfe Cache zuerst
            if let cachedUser = await userCache.get(userId: rawMessage.sent_by) {
                let messageWithUser = Message(
                    id: rawMessage.id,
                    group_id: rawMessage.group_id,
                    content: rawMessage.content,
                    sent_by: rawMessage.sent_by,
                    sent_at: rawMessage.sent_at,
                    user: cachedUser
                )
                
                DispatchQueue.main.async {
                    onNewMessage(messageWithUser)
                }
                print("📨 [CACHE] Nachricht von \(cachedUser.display_name): '\(rawMessage.content)'")
                
            } else {
                // ✅ SCHRITT 2: Fallback - Ohne User anzeigen
                DispatchQueue.main.async {
                    onNewMessage(rawMessage)
                }
                print("📨 [NO-CACHE] Nachricht von \(rawMessage.sent_by): '\(rawMessage.content)'")
                
                // ✅ SCHRITT 3: Im Hintergrund User laden und Cache füllen
                Task {
                    await loadAndCacheUser(for: rawMessage.sent_by)
                }
            }
            
        } catch {
            print("❌ Fehler beim Verarbeiten der Real-Time Nachricht: \(error)")
        }
    }
    
    // MARK: - User Loading
    
    private static func loadAndCacheUser(for userId: UUID) async {
        do {
            let user: AppUser = try await db
                .from("user")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await userCache.set(user: user)
            print("✅ User zu Cache hinzugefügt: \(user.display_name)")
            
        } catch {
            print("❌ Fehler beim Laden des Users \(userId): \(error)")
        }
    }
    
    // In ChatEndpoints.swift - NEUE FUNKTION
    static func fetchUser(for userId: UUID) async throws -> AppUser {
        let user: AppUser = try await db
            .from("user")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return user
    }
    
    // MARK: - Payload Struct
    private struct CreateMessagePayload: Encodable {
        let group_id: UUID
        let content: String
        let sent_by: UUID
    }
}
