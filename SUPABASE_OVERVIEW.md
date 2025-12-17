# Supabase in Unify – Projektspezifische Übersicht

## Was macht Supabase für Unify?

Supabase ist die **Backend-Infrastruktur** von Unify und verwaltet alles, was nicht auf dem iPhone läuft:
- **Benutzerkonten & Authentifizierung** (Wer bist du?)
- **Gruppen & Mitgliedschaften** (Wer gehört zu welcher Gruppe?)
- **Chat-Nachrichten & Voice-Messages** (Was wird geschrieben & gesprochen?)
- **Kalender-Events** (Wann finden Treffen statt?)
- **Dateispeicher** (Wo landen Profilbilder & Sprachnachrichten?)

---

## 1. Datenbank (PostgreSQL) – Die Quelle der Wahrheit

Unify speichert alles in **5 Tabellen**:

| Tabelle | Zweck | Beispiel |
|---------|-------|---------|
| `user` | Benutzerprofile | Alice (ID: abc-123), Email: alice@unify.de, Avatar: alice.png |
| `group` | Gruppen | "iOS Dev Team" (Owner: Alice), "Projekt X" (Owner: Bob) |
| `group_members` | Wer ist wo Mitglied? | Alice = Owner in "iOS Dev Team", Bob = User in "iOS Dev Team" |
| `message` | Chat-Nachrichten | "Hallo Leute!" (von Alice, in "iOS Dev Team", 15:30 Uhr) |
| `event` | Kalender-Einträge | "Meeting" (16:00 Uhr, in "iOS Dev Team"), "Zahnarzt" (persönlich) |

**Spezialfall:** Messages können **Text** ODER **Voice** sein (mit Dauer & Audio-Link).
**Spezialfall:** Events können **persönlich** (nur für einen User) oder **in der Gruppe** sein.

---

## 2. Authentication (Supabase Auth) – Der Türsteher

Supabase kümmert sich um:
- **Registrierung:** "Neue Nutzerin" → Email bestätigen → Profil erstellen
- **Login:** Email + Passwort → Sitzung (Session) wird erstellt
- **Sitzungsverwaltung:** Alle 15 Min prüft Unify, ob die Session noch gültig ist (Auto-Refresh 5 Min vor Ablauf)
- **Spezialoperationen:**
  - Email ändern (mit Auth-Sync)
  - Passwort ändern (sicher)
  - Account löschen (mit Cascading Delete aller Daten)

**Token-System:** Nach Login erhält jeder Nutzer einen **JWT-Token** (digitalen Ausweis), der in jeder Anfrage beweist: "Ich bin Alice, vertraut mir."

---

## 3. Realtime (Echtzeit-Benachrichtigungen) – Die Live-Connection

Unify nutzt **2 Echtzeit-Kanäle** pro Gruppe:

### Kanal 1: Neue Chat-Nachrichten
- **Wer hört zu?** Alle Mitglieder der Gruppe
- **Was passiert?** Wenn jemand eine neue Nachricht schreibt → alle anderen sehen sie sofort (keine Sekunden-Verzögerung)
- **Beispiel:** Alice schreibt "Guten Morgen!" → Bob, Charlie und Diana sehen es in **Echtzeit**

### Kanal 2: Unread-Counter
- **Wer hört zu?** Jeder Nutzer (privat)
- **Was passiert?** Der rote Punkt mit der Unread-Zahl wird aktualisiert
- **Beispiel:** Alice bekommt 3 neue Nachrichten von Bob → Unread-Counter für diese Gruppe springt auf 3

**Best Practice (Unify nutzt das):**
- Kanalnamen folgen Muster: `group_chat_123` (Scope + Entity + ID)
- Bei App-Schließung werden alle Subscriptions aufgeräumt
- Nur **Änderungen** (Inserts) werden überwacht, nicht massive Datenmengen

---

## 4. Row-Level Security (RLS) – Der Datenschutz

**Problem ohne RLS:** Wenn Alice eine API-Anfrage macht, könnte sie theoretisch Bobs private Nachrichten lesen.

**Lösung (RLS):** Supabase prüft automatisch:
- **Messages:** "Darf Alice Nachrichten aus dieser Gruppe sehen?" → Nur wenn sie Mitglied ist
- **Events:** "Darf Alice diesen Event sehen?" → Persönliche Events nur von Alice, Gruppen-Events nur von Mitgliedern
- **Groups:** "Darf Alice diese Gruppe sehen?" → Nur wenn sie Mitglied ist

**RLS-Pattern in Unify:**
```
Nachricht X anschauen? → Check: user_id in (Mitglieder der Gruppe)?
Event Y ändern? → Check: Bin ich Owner/Admin ODER Ersteller?
```

---

## 5. Storage (Dateispeicher) – Wo landen Bilder & Audio?

Unify nutzt **2 Buckets** (Ordner im Cloud-Speicher):

### Bucket 1: Profile Pictures
- **Wer?** Jeder Nutzer hat max. 1 Profilbild
- **Format:** JPG/PNG (automatisch komprimiert)
- **Naming:** Einfach die User-ID verwenden (z.B. `abc-123.jpg`)
- **Caching:** Bilder werden auf dem iPhone gecacht (schneller Zugriff)
- **Cache-Busting:** Mit Timestamp verknüpft, damit neue Bilder sofort geladen werden

### Bucket 2: Voice Messages
- **Wer?** Speicher für Sprachnachrichten
- **Wie?** Wenn Alice eine Voice-Message sendet:
  1. Audio wird aufgenommen (lokal auf iPhone)
  2. Upload zu Supabase
  3. Message erhält Link zur Audio-Datei + Dauer (z.B. 15 Sekunden)
  4. Bob kann die Audio herunterladen & abspielen
- **Cleanup:** Wenn eine Nachricht gelöscht wird, wird die Audio-Datei auch gelöscht

---

## 6. API (Auto-generierte REST-Schnittstelle) – Die Kommunikation

Supabase generiert automatisch eine **REST-API** aus den Tabellen. Unify kommuniziert so:

### Beispiel 1: Neue Nachricht senden
```
POST /rest/v1/message
{
  "group_id": "group-xyz",
  "content": "Hallo zusammen!",
  "sent_by": "alice-123",
  "message_type": "text"
}
```
→ **Resultat:** Nachricht ist in der Datenbank, alle anderen sehen sie in Echtzeit (über Realtime).

### Beispiel 2: Alle Nachrichten einer Gruppe abrufen
```
GET /rest/v1/message?group_id=group-xyz&order=sent_at.asc
```
→ **Resultat:** Liste aller Nachrichten (mit RLS: Nur wenn Alice Mitglied ist).

### Beispiel 3: Profil aktualisieren
```
UPDATE /rest/v1/user
{
  "display_name": "Alice Meyer"
}
```
→ **Resultat:** Alices Name wird geändert.

**Typen von Operationen:**
- **SELECT** = Daten abrufen (mit Filtern)
- **INSERT** = Neue Daten hinzufügen
- **UPDATE** = Bestehende Daten ändern
- **DELETE** = Daten löschen

---

## 7. Sicherheitsebenen in Unify

### Level 1: Authentication
- "Nur eingeloggte Nutzer dürfen Anfragen machen" (JWT-Token)

### Level 2: Row-Level Security (RLS)
- "Du darfst nur Daten sehen, die dir gehören oder in deinen Gruppen sind"

### Level 3: Role-Based Access Control (RBAC)
- "Als Gruppen-Owner kannst du die Gruppe umbenennen, als User nicht"
- Rollen: `owner` (volle Kontrolle), `admin` (fast alles), `user` (eingeschränkt)

### Level 4: Secret Keys
- Der "Master Key" (service_role) ist nur auf Apples-Servern sicher, nicht im App-Code

---

## 8. Typischer Flow: Alice sendet eine Nachricht

1. **Alice tippt "Hallo Bob!" und drückt Send**
   - Unify (iOS App) hat ihren JWT-Token (von Login)

2. **Unify sendet eine REST-API-Anfrage an Supabase:**
   ```
   POST /rest/v1/message
   Header: Authorization: Bearer [Alices-JWT-Token]
   Body: { group_id: "team-123", content: "Hallo Bob!", sent_by: "alice-123" }
   ```

3. **Supabase prüft:** 
   - ✓ Ist der Token gültig? (Authentication)
   - ✓ Ist Alice Mitglied in "team-123"? (RLS)
   - ✓ OK, Nachricht speichern

4. **Supabase speichert die Nachricht** in PostgreSQL

5. **Supabase benachrichtigt Realtime-Subscriber:**
   - "Neue Nachricht in Kanal `group_chat_team-123`!"

6. **Bob, Charlie & Diana erhalten sofort die Nachricht** (Echtzeit-Update auf ihren iPhones)

7. **Bob sieht auch:** 
   - Alices Profilbild (aus Storage: profile-pictures)
   - Alices Name (aus Tabelle: user)
   - Zeitstempel (15:30 Uhr)

---

## Zusammenfassung für eine Präsentation

| Komponente | Rolle in Unify |
|-----------|-----------------|
| **PostgreSQL** | Speichert Users, Groups, Messages, Events (5 Tabellen) |
| **Supabase Auth** | Verwaltet Login, Registrierung, Sessions |
| **Realtime** | Push von neuen Nachrichten & Unread-Counts in Echtzeit |
| **Storage** | Profilbilder & Voice-Messages in der Cloud |
| **RLS** | Datenschutz: Alice sieht nur ihre Gruppen & persönliche Events |
| **REST-API** | Kommunikation zwischen iPhone-App & Backend |
| **RBAC** | Owner > Admin > User (Berechtigungen pro Gruppe) |

**Kern-Idee:** Supabase ist das "Gehirn" von Unify – es verwaltet alles Daten & Sicherheit, während die iOS-App nur die "Augen & Hände" ist.

---

## Wo findet man das im Code?

- **Auth:** `Backend/Auth.swift`, `SessionStore.swift`
- **Realtime:** `Backend/Endpoints/ChatEndpoints.swift`, `UnreadMessagesService.swift`
- **Storage:** `Backend/Endpoints/ProfileImageService.swift` (Profilbilder), `ChatEndpoints.swift` (Voice)
- **Datenmodelle:** `Backend/Model.swift`
- **API-Verbindung:** `Supabase.swift`, `Backend/Endpoints/`
