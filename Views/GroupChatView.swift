import SwiftUI

// MARK: - Gruppenchat-Hauptansicht
// Zeigt den Nachrichtenverlauf einer Gruppe und unten ein Eingabefeld (Composer).
// Enthält Auto-Scroll, Chatblasen für eigene und fremde Nachrichten.
struct GroupChatView: View {
    // ViewModel für den Chat (enthält Nachrichten und Logik)
    @StateObject var vm: ChatViewModel

    // Aktuell eingegebener Nachrichtentext (im Composer unten)
    @State private var draft: String = ""

    // Initializer: erlaubt das Injizieren eines bestehenden ChatViewModel-Objekts
    // Wichtig: Bei @StateObject muss der wrappedValue explizit gesetzt werden.
    init(vm: ChatViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Nachrichtenliste mit Auto-Scroll
            ScrollViewReader { proxy in
                ScrollView {
                    // LazyVStack = performant bei langen Listen
                    LazyVStack(alignment: .leading, spacing: 28) {
                        // Iteration über alle Nachrichten der Gruppe
                        ForEach(vm.group.messages) { msg in
                            ChatRow(
                                message: msg,
                                // 🔹 MockData wird hier verwendet:
                                // Vergleich mit MockData.me.id, um festzustellen, ob die Nachricht "von mir" ist.
                                isMe: msg.sender.id == MockData.me.id,
                                colorManager: vm.colorManager
                            )
                            .id(msg.id) // für Scroll-Target
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                // Beim ersten Erscheinen ans Ende scrollen
                .onAppear { scrollToBottom(proxy) }
                // Bei neuen Nachrichten ebenfalls nach unten scrollen
                .onChange(of: vm.group.messages.count) { _ in
                    scrollToBottom(proxy)
                }
            }

            // MARK: Composer unten (Eingabefeld + Senden)
            HStack(spacing: 10) {
                // Mehrzeiliges Textfeld mit runden Ecken
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                // MARK: Senden-Button
                Button {
                    // Entfernt überflüssige Leerzeichen
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    // Nachricht wird an das ViewModel weitergegeben
                    vm.send(text: text)
                    // Eingabefeld leeren
                    draft = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.blue, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial) // halbtransparenter Glas-Effekt
        }
        // MARK: Synchronisiert beim Anzeigen die Daten mit dem zentralen Store
        .onAppear { vm.refreshFromStore() }
    }

    // MARK: - Scroll-Helfer
    // Scrollt animiert auf die letzte Nachricht (z. B. nach Senden oder Laden)
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = vm.group.messages.last {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Einzelne Nachrichtenzeile
// Zeigt eine Chat-Bubble je nach Absenderseite (links = andere, rechts = ich)
private struct ChatRow: View {
    let message: Message
    let isMe: Bool
    let colorManager: ColorManager

    var body: some View {
        if isMe {
            // MARK: Rechte Seite (eigene Nachricht)
            HStack(alignment: .bottom, spacing: 12) {
                // Platzhalter links für Abstand
                Spacer(minLength: 120)

                VStack(alignment: .trailing, spacing: 6) {
                    // Name "Du" wird rechts angezeigt
                    Text("Du")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Blaue Sprechblase
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.blue,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .frame(maxWidth: 420, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Zeitstempel unten rechts
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Avatar rechts mit „DU“-Initialen
                InitialsAvatar(initials: "DU")
            }
        } else {
            // MARK: Linke Seite (Nachrichten anderer Teilnehmer)
            let bubble = colorManager.color(for: message.sender)
            let textColor = preferredTextColor(for: bubble)

            HStack(alignment: .top, spacing: 12) {
                // Avatar mit Initialen des Senders
                InitialsAvatar(initials: initials(for: message.sender.displayName))

                VStack(alignment: .leading, spacing: 6) {
                    // Absendername
                    Text(message.sender.displayName == "Ich" ? "Ich" : message.sender.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Farbige Bubble (jede Person andere Farbe)
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            bubble,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .frame(maxWidth: 460, alignment: .leading)

                    // Zeitstempel unten links
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 80) // rechter Abstand
            }
        }
    }

    // MARK: - Hilfsfunktionen

    // Initialen aus einem Namen erzeugen, z. B. „Max Mustermann“ → „MM“
    private func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let second = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    // Zeitformatierung für Uhrzeit (z. B. "14:32")
    static func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    // Textfarbe je nach Bubble-Hintergrundfarbe (für Lesbarkeit)
    private func preferredTextColor(for bubble: Color) -> Color {
        switch bubble {
        case .yellow, .mint, .cyan:
            return .black
        default:
            return .white
        }
    }
}

// MARK: - Avatar-Komponente
// Zeigt runden Kreis mit Initialen, dezente Hintergrundfarbe
private struct InitialsAvatar: View {
    let initials: String
    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .background(
                Circle().fill(Color(.secondarySystemBackground))
            )
    }
}
