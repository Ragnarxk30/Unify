# Anmerkungen (Kurzüberblick)

Dieses Dokument fasst die wichtigsten Klassen/Views zusammen: Zweck, wo man was anpasst, und Hinweise zu Abhängigkeiten.

## App-Struktur

- SharedCalendarApp (App)
  - Einstiegspunkt. Setzt RootTabView als Root-View.
  - Wenn ein globaler Darstellungsmodus (Hell/Dunkel/System) via Environment genutzt werden soll, hier .environmentObject(...) und .preferredColorScheme(...) setzen.

- RootTabView (View)
  - TabView mit drei Stacks: Kalender, Gruppen, Einstellungen.
  - Enthält die StateObject-Instanzen von CalendarViewModel und GroupsViewModel.
  - Icons/Titel der Tabs lassen sich hier ändern.

## DesignSystem.swift

- CardModifier
  - cardStyle() für Karten (volle Breite, linksbündig, abgerundete Ecken, dezenter Stroke).
  - Anpassen: CornerRadius, Padding, Stroke-Farbe/-Stärke, Hintergrundfarbe (Color.cardBackground).
- SegmentedToggle<T>
  - Wiederverwendbarer Box-Segmentschalter (z. B. „Liste | Kalender“).
  - Anpassen: Innen-Padding, CornerRadius (containerCorner/itemCorner), Farben (aktiv/inaktiv), Schrift (.subheadline etc.).
- Color-Extension
  - cardBackground, cardStroke, brandPrimary. Hier Farbwerte zentral ändern.

## Modelle (Models.swift)

- UserProfile, Event, Message, Group
  - Einfache Datenstrukturen (Identifiable/Hashable).
  - Event enthält start/end und optional groupID.
  - Anpassungen an Datenfeldern hier vornehmen (z. B. weitere Eigenschaften).

## Mock-Daten (MockData.swift)

- Startdaten für „Mein Kalender“, Gruppen, Gruppentermine, Chat.
  - Zum schnellen Testen. Inhalte/Zeiten hier ändern.

## ViewModels (ViewModels-Models.swift)

- CalendarViewModel
  - Published events: persönliche Termine (nicht gruppenbezogen).
  - Sortierung/Filterung hier anpassen.

- GroupsViewModel
  - Published groups: zentrale Quelle für Gruppen inkl. Events/Messages.
  - createGroup(name:invited:): Gruppe anlegen (Einladungen derzeit nur Platzhalter).
  - addMessage(_:to:): Nachricht in Gruppe hinzufügen.
  - addEvent(title:start:end:to:): Gruppentermin hinzufügen (inkl. Sortierung).
  - Wichtig: Alle Mutationen hier bündeln, damit alle Views synchron bleiben.

- ChatViewModel
  - Hält eine konkrete Gruppe (group) für den Chat-Screen.
  - refreshFromStore(): synchronisiert lokale Kopie mit GroupsViewModel.
  - send(text:): leere Texte filtern, Nachricht senden, danach refresh.
  - Anpassungen am Sendeverhalten (z. B. Zeitstempel, Sender) hier.

## Kalender – eigener Tab (CalendarListView-Views.swift)

- CalendarListView
  - Header: „Mein Kalender“ + SegmentedToggle (Liste/Kalender).
  - Inhalt: Listenansicht (EventCard) oder Platzhalter für Kalender.
  - Wichtige Stellen:
    - Seitenrand (sideInset) steuert linken/rechten Außenabstand.
    - Titelgröße/Breite im Header anpassen (font, frame(maxWidth:)).
    - Toggle-Layout via SegmentedToggle im DesignSystem.

- EventCard (privater View)
  - Titel + Datumsformatierung.
  - Optik über .cardStyle(); linksbündig, volle Breite.
  - Datumsformat in format(_:_: ) ändern.

## Gruppen – Liste und Screens (GroupsView.swift, GroupChatScreen, GroupCalendarScreen)

- GroupsView
  - Zeigt alle Gruppen als Karten.
  - Jede Karte: Buttons für „Kalender“ und „Chat“ (NavigationLinks).
  - Plus-Button öffnet CreateGroupSheet (Name/Einladungen).
  - Anpassen: Kartenlayout (GroupRow), Toolbar, Sheet-Inhalte.

- GroupChatScreen
  - Wrapper für den Chat. Setzt Navigationstitel („<Name> – Chat“). --> ohne -Chat
  - Blendet Tab-Bar nur im Chat aus (.toolbar(.hidden, for: .tabBar)).
  - Anpassbar: Titeltext, Tab-Bar-Verhalten.

- GroupCalendarScreen
  - Wrapper für den Gruppenkalender (nur Monatsansicht).
  - Setzt Navigationstitel „Gruppenkalender“.
  - Optional Tab-Bar ausblendbar (Modifier ergänzen).

## Chat (GroupChatView.swift)

- GroupChatView
  - Nachrichtenliste (ScrollView + LazyVStack) mit Auto-Scroll ans Ende.
  - Composer unten (TextField + Senden-Button).
  - Anpassen:
    - Bubble-Farben (eigene: Color.blue; empfangene: secondarySystemBackground).
    - Eckenradius (RoundedRectangle cornerRadius).
    - Abstände (Padding/Spacing).
    - Max-Bubble-Breite (420/460) für bessere Lesbarkeit.
    - Auto-Scroll-Verhalten in scrollToBottom(_:) (Animation/Dauer).

- ChatRow (privater View)
  - Unterscheidet „ich“ vs. „andere“: Ausrichtung, Name, Zeitstempel.
  - Avatar „InitialsAvatar“ links/rechts.
  - Anpassen: Typografie (Fonts), Zeitformat (HH:mm), Avatargröße.

- InitialsAvatar
  - Runder Kreis mit Initialen.
  - Farben/Größe hier anpassen.

## Gruppenkalender (GroupMonthlyCalendarView.swift)

- GroupMonthlyCalendarView
  - Einfache Monatsansicht (lokale Kalenderlogik).
  - Monatspager (Chevron links/rechts), Wochentage, Grid.
  - Tage mit Terminen zeigen blaue Punkte (max. 3).
  - Tap auf Tag mit Terminen öffnet Sheet (DayEventsSheet).
  - Anpassen:
    - Monatsnavigation (Animation/Schaltflächen).
    - Marker-Design (Farbe/Anzahl).
    - Tageszelle (DayCell) – Hintergrund, Radius, Höhe.
    - Date- und Zeitformat im Sheet.
    - firstWeekday/Locale-bezogenes Verhalten.

- DayCell
  - Einzelne Tageskachel im Grid.
  - Anpassen: Höhe (52), CornerRadius (10), Markerfarbe/-größe (6pt).

- DayEventsSheet
  - Listet die Events des gewählten Tages mit Titel/Zeit.
  - Anpassen: Darstellung (List -> VStack/Karten), Detents (.medium etc.).

## Einstellungen (SettingsView-Views.swift)

- SettingsView
  - Form mit Abschnitten: Darstellung (System/Hell/Dunkel per Button), Profil, App-Toggles, Abmelden.
  - Der Darstellungsmodus wird per @AppStorage("appAppearance") gespeichert.
  - Die aktuelle Lösung setzt den iOS-Stil via window.overrideUserInterfaceStyle.
  - Alternativ (empfohlen): AppAppearanceState + .preferredColorScheme(...) im App-Einstieg verwenden.
  - Anpassen:
    - Buttons (AppearanceButton) Design/Farben/Texte.
    - Weitere App-Optionen als Toggles/NavigationLinks.

## Wichtige Design-/Layout-Schalter

- Seitenränder: sideInset (in CalendarListView) für Listenbreite.
- Kartenbreite: cardStyle() setzt maxWidth: .infinity (volle Breite im verfügbaren Bereich).
- Tab-Bar im Chat ausblenden: nur im GroupChatScreen via .toolbar(.hidden, for: .tabBar).
- SegmentedToggle-Optik: in DesignSystem.swift (Padding, CornerRadius, Farben).
- Systemfarben bevorzugen (z. B. .secondarySystemBackground, .label), damit Hell/Dunkel sauber funktionieren.

## Typische Erweiterungspunkte

- Datenhaltung: GroupsViewModel als zentrale Quelle – hier echte Persistenz/Netzwerk (CloudKit/Core Data/Backend) integrieren.
- Berechtigungen/Rollen: In Group/Message zusätzliche Felder (z. B. isOwner, readReceipts).
- Kalender: Wochen-/Monatswechsel per Swipe, Event-Erstellung per Tap & Hold, Event-Details als Popover.
- Chat: Datumsseparatoren, Lesebestätigungen, Anhänge, Eingabe-Toolbar mit +.

