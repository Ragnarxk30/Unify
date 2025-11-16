import Foundation
import Supabase

struct ChatEndpoints {
    
    private static let db = supabase
    private static let messagesTable = "messages"
    private static let auth: AuthRepository = SupabaseAuthRepository()

    // MARK: - Payload Structs
    private struct CreateMessagePayload: Encodable {
        let group_id: UUID
        let content: String
        let sent_by: UUID
    }

    // MARK: - Message Operations
    
    /// Nachrichten für eine Gruppe abrufen
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
        
        return messages
    }
    
    /// Nachricht senden
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
        
        return message
    }
    
    /// Nachricht löschen (nur eigener User)
    static func deleteMessage(messageID: UUID) async throws {
        let userId = try await auth.currentUserId()
        
        // Prüfen ob User der Absender ist
        let message: Message = try await db
            .from(messagesTable)
            .select()
            .eq("id", value: messageID)
            .single()
            .execute()
            .value
        
        guard message.sent_by == userId else {
            throw NSError(domain: "ChatError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nur der Absender kann die Nachricht löschen"])
        }
        
        try await db
            .from(messagesTable)
            .delete()
            .eq("id", value: messageID)
            .execute()
    }
    
    /// Nachrichten eines Users abrufen (über alle Gruppen)
    static func fetchUserMessages(limit: Int = 50, offset: Int = 0) async throws -> [Message] {
        let userId = try await auth.currentUserId()
        
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
            .eq("sent_by", value: userId)
            .order("sent_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return messages
    }
}
