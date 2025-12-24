//
//  ChatEndpoints.swift
//

import Foundation
import Supabase

struct ChatEndpoints {

    private static let db = supabase
    private static let messagesTable = "message"
    private static let auth: AuthRepository = SupabaseAuthRepository()

    // MARK: - Gemeinsamer SELECT Block
    private static let messageSelect = """
        id,
        group_id,
        content,
        sent_by,
        sent_at,
        is_edited,
        message_type,
        voice_duration,
        voice_url,
        user:user!sent_by(
            id,
            display_name,
            email
        )
    """

    // MARK: - Realtime Storage
    private static var subscriptions: [UUID: RealtimeChannelV2] = [:]

    // MARK: - User Cache Actor
    private actor UserCache {
        private var storage: [UUID: AppUser] = [:]

        func get(_ id: UUID) -> AppUser? { storage[id] }

        func set(_ user: AppUser) { storage[user.id] = user }

        func insertFrom(messages: [Message]) {
            for msg in messages {
                if let u = msg.user { storage[u.id] = u }
            }
        }
    }
    private static let userCache = UserCache()

    // MARK: - Date Decoder (einmalig)
    private static let dateDecoder: (Decoder) throws -> Date = { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        if let d = df.date(from: raw) { return d }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = df.date(from: raw) { return d }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: raw) { return d }

        if let ts = TimeInterval(raw) {
            return Date(timeIntervalSince1970: ts)
        }

        print("⚠️ Konnte Datum nicht parsen: \(raw)")
        return Date()
    }

    // MARK: - Hochwertige Builder Funktion
    private static func buildMessage(from raw: Message, with user: AppUser?) -> Message {
        Message(
            id: raw.id,
            group_id: raw.group_id,
            content: raw.content,
            sent_by: raw.sent_by,
            sent_at: raw.sent_at,
            user: user,
            message_type: raw.message_type,
            voice_duration: raw.voice_duration,
            voice_url: raw.voice_url
        )
    }

    // MARK: - Fetch Messages
    static func fetchMessages(for groupID: UUID) async throws -> [Message] {
        let msgs: [Message] = try await db
            .from(messagesTable)
            .select(messageSelect)
            .eq("group_id", value: groupID)
            .order("sent_at", ascending: true)
            .execute()
            .value

        await userCache.insertFrom(messages: msgs)
        return msgs
    }
    
    // MARK: - Send Text
    static func sendMessage(groupID: UUID, content: String) async throws -> Message {
        let userId = try await auth.currentUserId()

        let payload = [
            "group_id": groupID.uuidString,
            "content": content,
            "sent_by": userId.uuidString,
            "message_type": "text"
        ]

        let raw: Message = try await db
            .from(messagesTable)
            .insert(payload)
            .select(messageSelect)
            .single()
            .execute()
            .value

        if let user = raw.user { await userCache.set(user) }
        return raw
    }

    // MARK: - Send Voice Message (TYPSICHER)
    static func sendVoiceMessage(groupID: UUID, groupName: String, voiceUrl: String, duration: Int) async throws -> Message {
        let userId = try await auth.currentUserId()

        // STRUCT STATT DICTIONARY
        struct VoicePayload: Encodable {
            let group_id: UUID
            let content: String
            let sent_by: UUID
            let message_type: String
            let voice_duration: Int
            let voice_url: String
        }
        
        let payload = VoicePayload(
            group_id: groupID,
            content: "🎤 Sprachnachricht (\(duration)s)",
            sent_by: userId,
            message_type: "voice",
            voice_duration: duration,
            voice_url: voiceUrl
        )

        let raw: Message = try await db
            .from(messagesTable)
            .insert(payload)
            .select(messageSelect)
            .single()
            .execute()
            .value

        if let user = raw.user { await userCache.set(user) }
        return raw
    }

    // MARK: - Storage Cleanup für Voice Messages
    private static func deleteVoiceFromStorage(voiceUrl: String) async {
        do {
            // ✅ KORREKTER PFAD: Aus der URL den richtigen Pfad extrahieren
            guard let url = URL(string: voiceUrl) else {
                print("⚠️ Invalid voice URL: \(voiceUrl)")
                return
            }
            
            // Der Pfad ist alles nach "/object/public/voice-messages/" 
            let fullPath = url.path
            print("🔍 Full path from URL: \(fullPath)")
            
            // Extrahiere den Pfad nach "voice-messages/"
            if let range = fullPath.range(of: "/voice-messages/") {
                let relativePath = String(fullPath[range.upperBound...])
                print("🔍 Relative path to delete: \(relativePath)")
                
                try await supabase.storage
                    .from("voice-messages")
                    .remove(paths: [relativePath])
                
                print("🗑️ Voice message deleted from storage: \(relativePath)")
            } else {
                print("⚠️ Could not extract path from voice URL: \(voiceUrl)")
            }
            
        } catch {
            print("⚠️ Could not delete voice from storage: \(error)")
            if let supabaseError = error as? StorageError {
                print("🔍 Storage Error: \(supabaseError)")
            }
        }
    }

    // MARK: - Delete Message (mit Storage Cleanup) - ✅ KORRIGIERT
    static func deleteMessage(_ message: Message) async throws {
        // Zuerst aus Datenbank löschen
        try await db
            .from(messagesTable)
            .delete()
            .eq("id", value: message.id)
            .execute()
        
        // Dann aus Storage löschen (falls Voice Message)
        if message.isVoiceMessage, let voiceUrl = message.voice_url {
            await deleteVoiceFromStorage(voiceUrl: voiceUrl)
        }
    }
    
    // MARK: - Edit Message
    static func editMessage(_ messageId: UUID, newContent: String) async throws -> Message {
        struct EditPayload: Encodable {
            let content: String
            let is_edited: Bool
        }
        
        let payload = EditPayload(content: newContent, is_edited: true)
        
        let updated: Message = try await db
            .from(messagesTable)
            .update(payload)
            .eq("id", value: messageId)
            .select(messageSelect)
            .single()
            .execute()
            .value
        
        // User Cache aktualisieren
        if let user = updated.user { await userCache.set(user) }
        return updated
    }

    // MARK: - Fetch User (mit Cache)
    static func fetchUser(_ id: UUID) async throws -> AppUser {
        if let cached = await userCache.get(id) { return cached }

        let user: AppUser = try await db
            .from("user")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        await userCache.set(user)
        return user
    }

    // MARK: - Real-Time
    static func startRealtimeSubscription(
        groupID: UUID,
        onMessage: @escaping (Message) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onUpdate: @escaping (Message) -> Void
    ) async throws {

        stopRealtimeSubscription(for: groupID)

        let channel = db.realtimeV2.channel("group_chat_\(groupID)")

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: messagesTable,
            filter: .eq("group_id", value: groupID)
        )
        
        let deletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: messagesTable,
            filter: .eq("group_id", value: groupID)
        )
        
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: messagesTable,
            filter: .eq("group_id", value: groupID)
        )

        Task {
            for await action in inserts {
                await handleRealtimeInsert(action, groupID: groupID, onMessage: onMessage)
            }
        }
        
        Task {
            for await action in deletes {
                await handleRealtimeDelete(action, onDelete: onDelete)
            }
        }
        
        Task {
            for await action in updates {
                await handleRealtimeUpdate(action, groupID: groupID, onUpdate: onUpdate)
            }
        }

        try await channel.subscribe()
        subscriptions[groupID] = channel
    }

    static func stopRealtimeSubscription(for groupID: UUID) {
        Task {
            if let channel = subscriptions[groupID] {
                try? await channel.unsubscribe()
                subscriptions[groupID] = nil
            }
        }
    }

    private static func handleRealtimeInsert(
        _ action: InsertAction,
        groupID: UUID,
        onMessage: @escaping (Message) -> Void
    ) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(action.record)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(dateDecoder)

            let raw = try decoder.decode(Message.self, from: data)

            // falsche Gruppe ignorieren
            guard raw.group_id == groupID else { return }

            if let cached = await userCache.get(raw.sent_by) {
                let msg = buildMessage(from: raw, with: cached)
                DispatchQueue.main.async { onMessage(msg) }
            } else {
                DispatchQueue.main.async { onMessage(raw) }

                Task {
                    let user = try? await fetchUser(raw.sent_by)
                    if let u = user {
                        await userCache.set(u)
                    }
                }
            }

        } catch {
            print("❌ Real-Time insert decode error: \(error)")
            print("🔍 Raw data: \(action.record)")
            if let decodingError = error as? DecodingError {
                print("🔍 Decoding details: \(decodingError)")
            }
        }
    }
    
    private static func handleRealtimeDelete(
        _ action: DeleteAction,
        onDelete: @escaping (UUID) -> Void
    ) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(action.oldRecord)
            
            let decoder = JSONDecoder()
            struct DeletedMessage: Decodable {
                let id: UUID
            }
            
            let deleted = try decoder.decode(DeletedMessage.self, from: data)
            DispatchQueue.main.async { onDelete(deleted.id) }
            
        } catch {
            print("❌ Real-Time delete decode error: \(error)")
            print("🔍 Raw data: \(action.oldRecord)")
        }
    }
    
    private static func handleRealtimeUpdate(
        _ action: UpdateAction,
        groupID: UUID,
        onUpdate: @escaping (Message) -> Void
    ) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(action.record)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(dateDecoder)
            
            let raw = try decoder.decode(Message.self, from: data)
            
            guard raw.group_id == groupID else { return }
            
            if let cached = await userCache.get(raw.sent_by) {
                let msg = buildMessage(from: raw, with: cached)
                DispatchQueue.main.async { onUpdate(msg) }
            } else {
                DispatchQueue.main.async { onUpdate(raw) }
                
                Task {
                    let user = try? await fetchUser(raw.sent_by)
                    if let u = user {
                        await userCache.set(u)
                    }
                }
            }
            
        } catch {
            print("❌ Real-Time update decode error: \(error)")
            print("🔍 Raw data: \(action.record)")
        }
    }
    
    static func cleanupAllSubscriptions() {
        for (id, _) in subscriptions {
            stopRealtimeSubscription(for: id)
        }
    }
}
