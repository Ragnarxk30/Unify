import SwiftUI

// MARK: - Gruppenchat-Hauptansicht
// Zeigt den Nachrichtenverlauf einer Gruppe und unten einen Composer zum Senden.
// Layout orientiert sich am Figma: linke Nachrichten mit Avatar/Name/Zeit,
// eigene Nachrichten rechts in blauer Bubble mit Zeit.
struct GroupChatView: View {
    // ViewModel für diesen Chat (liefert Nachrichten und sendet neue)
    @StateObject var vm: ChatViewModel

    // Eingabetext im Composer
    @State private var draft: String = ""

    // Initializer, um ein bereits erzeugtes ChatViewModel zu injizieren.
    // Wichtig: @StateObject muss im Init via StateObject(wrappedValue:) gesetzt werden.
    init(vm: ChatViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Nachrichtenliste mit Auto-Scroll ans Ende
            ScrollViewReader { proxy in
                ScrollView {
                    // LazyVStack für performantes Rendering langer Listen
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(vm.group.messages) { msg in
                            // Eine Zeile pro Nachricht
                            ChatRow(
                                message: msg,
                                isMe: msg.sender.id == MockData.me.id,
                                colorManager: vm.colorManager
                            )
                            .id(msg.id) // für Scroll-Target
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                // Beim ersten Erscheinen an das Ende scrollen
                .onAppear { scrollToBottom(proxy) }
                // Wenn die Anzahl der Nachrichten sich ändert, erneut ans Ende scrollen
                .onChange(of: vm.group.messages.count) { _ in
                    scrollToBottom(proxy)
                }
            }

            // Composer (Eingabefeld + Senden)
            HStack(spacing: 10) {
                // Mehrzeiliges Textfeld (max. 4 Zeilen), mit abgerundetem Hintergrund
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                // Senden-Button
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    vm.send(text: text) // an ViewModel delegieren
                    draft = ""          // Eingabefeld leeren
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
            .background(.ultraThinMaterial) // leichter „Glas“-Effekt wie im System
        }
        // Beim Erscheinen lokale Gruppendaten mit dem Store synchronisieren
        .onAppear { vm.refreshFromStore() }
    }

    // MARK: - Auto-Scroll Helper
    // Scrollt mit kurzer Animation auf die letzte Nachricht.
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
// Unterscheidet zwischen "ich" (rechte, blaue Bubble) und "andere" (linke, farbige Bubble je Teilnehmer).
private struct ChatRow: View {
    let message: Message
    let isMe: Bool
    let colorManager: ColorManager

    var body: some View {
        if isMe {
            // Rechte Seite (eigene Nachricht) – bleibt blau/weiß
            HStack(alignment: .bottom, spacing: 12) {
                // Platzhalter links, damit die Bubble nicht zu breit wird
                Spacer(minLength: 120)

                VStack(alignment: .trailing, spacing: 6) {
                    // Name „Du“ rechts
                    Text("Du")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Blaue Bubble (eigene Nachricht)
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.blue,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        // maximale Bubble-Breite
                        .frame(maxWidth: 420, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Zeitstempel rechtsbündig
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Avatar rechts (Initialen „DU“)
                InitialsAvatar(initials: "DU")
            }
        } else {
            // Linke Seite (Nachricht anderer) – farbige Bubble je Teilnehmer
            let bubble = colorManager.color(for: message.sender)
            let textColor = preferredTextColor(for: bubble)

            HStack(alignment: .top, spacing: 12) {
                // Avatar mit Initialen aus dem Namen
                InitialsAvatar(initials: initials(for: message.sender.displayName))

                VStack(alignment: .leading, spacing: 6) {
                    // Absendername
                    Text(message.sender.displayName == "Ich" ? "Ich" : message.sender.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Farbige Bubble (empfangene Nachricht)
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

                    // Zeitstempel linksbündig
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Platzhalter rechts
                Spacer(minLength: 80)
            }
        }
    }

    // Initialen aus einem Namen bilden (z. B. „Max Mustermann“ -> „MM“)
    private func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let second = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    // Zeitformatierung „HH:mm“ für den Zeitstempel
    static func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    // Einfache Kontrast-Heuristik für Textfarbe auf bunter Bubble
    private func preferredTextColor(for bubble: Color) -> Color {
        switch bubble {
        case .yellow, .mint, .cyan:
            return .black
        default:
            return .white
        }
    }
}

// MARK: - Avatar mit Initialen
// Runder Kreis mit Initialen, dezente Sekundärfarbe
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
