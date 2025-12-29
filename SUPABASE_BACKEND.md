# Supabase Backend-Dokumentation: Unify iOS

## Überblick
Unify ist eine iOS-Gruppen-Chat-App mit Kalender-Integration, die Supabase als vollständiges Backend nutzt.
**Client:** Supabase Swift SDK | **URL:** gtyyrkwfkzzyhsearkgn.supabase.co

---

## 1. Datenbank-Schema (PostgreSQL)

### `user` - Nutzerprofile
- `id` (UUID, PK), `display_name`, `email`, `avatar_url` (nullable)
- Automatische Erstellung bei Sign-Up via Supabase Auth

### `group` - Gruppen
- `id` (UUID, PK), `name`, `owner_id` (FK → user)
- Owner hat volle Kontrolle (Umbenennen, Löschen, Ownership-Transfer)

### `group_members` - Mitgliedschaften (Junction Table)
- `user_id`, `group_id`, `role` (ENUM: owner|admin|user), `joined_at`, `last_read_at`
- **Kern-Feature:** Role-Based Access Control (RBAC) + Unread-Tracking

### `message` - Chat-Nachrichten
- `id` (UUID), `group_id`, `content`, `sent_by`, `sent_at`, `is_edited`
- `message_type` ("text"|"voice"), `voice_duration` (Sekunden), `voice_url` (Storage-Link)
- Unterstützt: Text-Nachrichten, Voice-Messages, Bearbeitung

### `event` - Kalender-Events
- `id`, `title`, `details`, `starts_at`, `ends_at`, `group_id` (nullable), `created_by`
- **Dual-Mode:** `group_id = NULL` → persönlicher Event | `group_id ≠ NULL` → Gruppen-Event

---

## 2. Authentication (Supabase Auth)

**Implementierung:** `Backend/Auth.swift`

### Flows
- **Sign Up:** `auth.signUp(email:, password:)` → User-Profil in `user`-Tabelle erstellen
- **Sign In:** `auth.signIn()` → Session laden + User-Profil abrufen
- **Session Management:** `SessionStore.swift` mit 15-Min-Polling + Auto-Refresh (5 Min vor Ablauf)

### Custom RPC-Funktionen
```swift
change_user_email(new_email)      // Email-Änderung mit Auth-Sync
change_user_password(new_password) // Sichere Passwort-Änderung
delete_user_account()              // Cascading Delete aller User-Daten
```

### Deep Links
- Redirect nach Sign-Up: `unify://auth-callback`
- Race-Condition-Mitigation: 500ms Delay zwischen Auth + DB-Insert

---

## 3. Realtime (PostgreSQL Changes)

### Subscription 1: Chat-Nachrichten
**Channel:** `group_chat_{groupID}` | **Datei:** `ChatEndpoints.swift:262-286`
```swift
channel.postgresChange(InsertAction.self, table: "message",
                        filter: .eq("group_id", value: groupID))
```
- Nur INSERT-Events → neue Nachrichten in Echtzeit
- Auto-Decoding mit Custom Date-Formatter

### Subscription 2: Unread-Counter
**Channel:** `unread_{groupId}` | **Datei:** `UnreadMessagesService.swift:90-118`
```swift
channel.postgresChange(InsertAction.self, table: "message", ...)
```
- Inkrementiert Unread-Count für neue Nachrichten (außer eigene)
- Verhindert Duplikate via Dictionary-Tracking

### Best Practice (befolgt)
✓ Naming: `scope:entity[:id]` → `group_chat_123`
✓ Cleanup: `cleanupAllSubscriptions()` bei App-Beendigung
✓ Keine `postgres_changes` auf massiven Tabellen (nur gefiltert)

---

## 4. Storage (Objekt-Speicher)

### Bucket 1: `profile-pictures`
**Service:** `ProfileImageService.swift`
- **Upload:** JPG/PNG mit Kompression, Naming: `{userId}` (lowercase UUID)
- **Caching:** NSCache (100 Items, 50MB Limit) + Download-Deduplication
- **Cache-Busting:** Timestamp-Parameter in Public URLs
- **Upsert:** Alte Dateien werden vor Upload gelöscht

### Bucket 2: `group-pictures`
**Service:** `GroupImageService.swift`
- **Upload:** JPG/PNG mit Kompression, Naming: `{groupId}` (lowercase UUID)
- **Caching:** NSCache (50 Items, 25MB Limit) + Download-Deduplication
- **Cache-Busting:** Timestamp-Parameter in Public URLs
- **Upsert:** Alte Dateien werden vor Upload gelöscht
- **Permissions:** Nur Owner/Admin können Gruppenbilder ändern (UI-seitig)

### Bucket 3: `voice-messages`
**Service:** `ChatEndpoints.swift:173-205`
- **Upload:** Beim Erstellen von Voice-Messages (`message_type = "voice"`)
- **Cleanup:** Auto-Löschen via `storage.remove()` beim Message-Delete
- **Metadaten:** `voice_duration` (Sekunden), `voice_url` (Public URL)

---

## 5. Row-Level Security (RLS)

**Policies (referenziert im Code):**

### Messages
- `members_can_select_messages` → Nur Nachrichten aus eigenen Gruppen sichtbar
- Filter: `user_id IN (SELECT user_id FROM group_members WHERE group_id = message.group_id)`

### Events
- `members_can_select_events` → Events aus eigenen Gruppen + persönliche Events
- `members_can_insert_events` → Nur Gruppenmitglieder können Events erstellen
- `members_can_update/delete_events_with_role_logic` → Permissions via `group_members.role`

### Groups
- Implizite Policies via `group_members`-Checks in Queries
- Owner kann alles (Update, Delete, Transfer), Members nur Read

---

## 6. API-Patterns (PostgREST)

### Typische Query-Struktur
```swift
try await db
    .from("message")
    .select("*, user:user!sent_by(id, display_name)")  // Foreign-Key-Join
    .eq("group_id", value: groupID)
    .order("sent_at", ascending: true)
    .execute()
    .value  // Type-safe Decoding
```

### CRUD-Operationen
- **SELECT:** `.select()` + Filter (`.eq()`, `.neq()`, `.in()`)
- **INSERT:** `.insert(payload).select().single()` → Return inserted row
- **UPDATE:** `.update(payload).eq("id", value: id)`
- **DELETE:** `.delete().eq("id", value: id)`

---

## 7. Wichtige Features

### Voice Messages
1. Recording → Documents Directory (lokal)
2. Upload → `voice-messages` Bucket
3. Message-Insert mit `voice_url` + `voice_duration`
4. Playback via URL-Download

### Unread-Tracking
- `group_members.last_read_at` speichert letzten Lesezeitpunkt
- `markAsRead(groupId)` → UPDATE `last_read_at = NOW()`
- Count: `WHERE message.sent_at > last_read_at AND sent_by ≠ current_user`

### User-Cache (Actor Pattern)
```swift
private actor UserCache {
    private var storage: [UUID: AppUser] = [:]
}
```
- Thread-safe Caching von User-Profilen in Realtime-Handlern

---

## 8. Sicherheit & Best Practices

### ✓ Implementiert
- **RLS aktiviert** für alle User-Tabellen (user, group, message, event)
- **RBAC** via `group_members.role` (owner|admin|user)
- **Service Role Key** nur in `Secrets.swift` (nie im Client-Code exponiert)
- **Indizierung** auf `group_id`, `user_id`, `sent_at` (impliziert durch Query-Performance)
- **Foreign-Key-Constraints** für Datenintegrität

### ⚠️ Potenzielle Verbesserungen
- **Anon/Authenticated Keys:** Aktuell wird Service Role Key verwendet (sollte nur serverseitig sein)
- **Private Channels:** Realtime-Channels könnten zusätzliche Authorization-Checks haben
- **Storage-Policies:** Explizite RLS auf `storage.objects` für User-Isolation empfohlen

---

## 9. Architektur-Patterns

### Repository Pattern
```swift
protocol AuthRepository { ... }
struct SupabaseAuthRepository: AuthRepository { ... }
```
- Abstraktion für Testbarkeit + Dependency Injection

### Service Layer
- `AuthService` (SessionStore + Auth-Flows)
- `ProfileImageService` (Storage + Caching für Profilbilder)
- `GroupImageService` (Storage + Caching für Gruppenbilder)
- `UnreadMessagesService` (Realtime + Counter)

### Data Models
- Type-safe Swift Structs: `AppUser`, `AppGroup`, `Message`, `Event`, `GroupMember`
- Custom `Codable` mit ISO8601-Decoding (Fallback für Timezone-Varianten)

---

## 10. Fehlerbehandlung

### Custom Error Types
```swift
enum GroupError: Error {
    case unknownAppleIds([String])
    case notGroupOwner
    case cannotLeaveAsOwnerWithoutSuccessor
}
```
- Validierung: Empty Name, Invalid Email, Password < 6 Zeichen
- Async Error Propagation mit `throws`

---

## Zusammenfassung

**Supabase-Komponenten:**
- ✓ **PostgreSQL** (5 Tabellen mit Foreign Keys + RLS)
- ✓ **Auth** (Email/Password + Session Management)
- ✓ **Realtime** (2 Subscriptions pro Gruppe: Chat + Unread)
- ✓ **Storage** (3 Buckets: Profile Pictures + Group Pictures + Voice Messages)
- ✓ **RPC Functions** (3 Custom Functions für Auth-Ops)

**Architektur:** Repository Pattern + Service Layer + Actor-basiertes Caching
**Performance:** NSCache, Download-Deduplication, User-Actor-Cache
**Security:** RLS, RBAC, Foreign-Key-Constraints
