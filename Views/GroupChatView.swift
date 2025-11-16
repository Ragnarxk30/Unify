import SwiftUI

struct GroupChatView: View {
    let group: AppGroup
    @State private var draft: String = ""
    @State private var message: [Message] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @StateObject private var colorManager = ColorManager()
    @State private var currentUser: AppUser?

    var body: some View {
        VStack(spacing: 0) {
            // Nachrichtenliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        if isLoading {
                            ProgressView("Lade Nachrichten...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                        } else if let errorMessage = errorMessage {
                            VStack {
                                Text("Fehler beim Laden")
                                    .font(.headline)
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Button("Erneut versuchen") {
                                    Task {
                                        await loadMessages()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 100)
                        } else if message.isEmpty {
                            VStack {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Noch keine Nachrichten")
                                    .font(.headline)
                                Text("Starte die Konversation!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(message) { msg in
                                SimpleChatRow(
                                    message: msg,
                                    colorManager: colorManager,
                                    isCurrentUser: isCurrentUser(msg)
                                )
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .onChange(of: message.count) { _ in
                    scrollToBottom(proxy)
                }
            }

            // Composer
            HStack(spacing: 10) {
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    sendMessage(text)
                    draft = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            Task {
                await loadCurrentUser()
                await loadMessages()
            }
        }
    }

    // MARK: - Aktuellen User laden
    private func loadCurrentUser() async {
        await MainActor.run {
            // ⏳ Temporär: Platzhalter
            currentUser = AppUser(
                id: UUID(),
                display_name: "Ich",
                email: "temp@example.com"
            )
        }
    }

    // MARK: - Prüfen ob Nachricht vom aktuellen User
    private func isCurrentUser(_ message: Message) -> Bool {
        guard let currentUser = currentUser else { return false }
        return message.sent_by == currentUser.id
    }

    // MARK: - Nachrichten laden
    private func loadMessages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedMessages = try await ChatEndpoints.fetchMessages(for: group.id)
            
            await MainActor.run {
                message = fetchedMessages
                print("✅ \(message.count) Nachrichten geladen")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                print("❌ Fehler beim Laden der Nachrichten: \(error)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Nachricht senden
    private func sendMessage(_ text: String) {
        Task { @MainActor in
            do {
                let newMessage = try await ChatEndpoints.sendMessage(groupID: group.id, content: text)
                message.append(newMessage)
                print("📨 Nachricht gesendet: '\(text)' an Gruppe \(group.id)")
            } catch {
                errorMessage = "Nachricht konnte nicht gesendet werden: \(error.localizedDescription)"
                print("❌ Fehler beim Senden der Nachricht: \(error)")
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = message.last {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// SimpleChatRow bleibt gleich...

// ✅ SimpleChatRow mit ColorManager anpassen
private struct SimpleChatRow: View {
    let message: Message
    let colorManager: ColorManager
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ✅ Avatar basierend auf User
            if !isCurrentUser {
                Circle()
                    .fill(colorManager.color(for: message.sender, isCurrentUser: isCurrentUser))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials(for: message.sender.display_name))
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.sender.display_name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCurrentUser ? Color.blue : colorManager.color(for: message.sender, isCurrentUser: isCurrentUser).opacity(0.2)
                    )
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(12)
                
                Text(formatTime(message.sent_at))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // ✅ Avatar für eigene Nachrichten rechts
            if isCurrentUser {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("DU")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
