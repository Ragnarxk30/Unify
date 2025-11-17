import SwiftUI
import Supabase

struct GroupChatView: View {
    let group: AppGroup
    @State private var draft: String = ""
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var colorManager = ColorManager()
    @StateObject private var speechManager = SpeechToTextManager()
    @State private var currentUserId: UUID?
    @State private var showSpeechUI = false

    var body: some View {
        VStack(spacing: 0) {
            // Nachrichtenliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(
                                message: message,
                                colorManager: colorManager,
                                isCurrentUser: isCurrentUser(message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy)
                }
                .onAppear {
                    scrollToBottom(proxy)
                }
            }
            .background(Color(.systemGroupedBackground))

            // Composer mit Sprach-Button
            HStack(spacing: 10) {
                // Sprach-Button
                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                        draft = speechManager.commitText()
                    } else {
                        speechManager.startRecording()
                    }
                } label: {
                    Image(systemName: speechManager.isRecording ? "waveform.circle.fill" : "waveform.circle")
                        .font(.title2)
                        .foregroundColor(speechManager.isRecording ? .red : .blue)
                        .symbolEffect(.bounce, value: speechManager.isRecording)
                }
                .disabled(!speechManager.hasPermission)

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
            
            // Sprach-Erkennungs-Anzeige
            if speechManager.isRecording {
                VStack {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                        Text("Spracherkennung aktiv...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(speechManager.recognizedText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadCurrentUserId()
                await loadMessages()
            }
        }
        .alert("Berechtigung benötigt", isPresented: .constant(speechManager.errorMessage != nil)) {
            Button("OK") { speechManager.errorMessage = nil }
            Button("Einstellungen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(speechManager.errorMessage ?? "")
        }
        .overlay {
            if isLoading {
                ProgressView("Nachrichten werden geladen...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Aktuelle User-ID laden
    private func loadCurrentUserId() async {
        do {
            let session = try await supabase.auth.session
            await MainActor.run {
                currentUserId = session.user.id
                print("✅ Aktuelle User-ID: \(session.user.id)")
            }
        } catch {
            print("❌ Fehler beim Laden der User-ID: \(error)")
        }
    }

    // MARK: - Prüfen ob Nachricht vom aktuellen User (SYNCHRON)
    private func isCurrentUser(_ message: Message) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        return message.sent_by == currentUserId
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
                messages = fetchedMessages
                print("✅ \(messages.count) Nachrichten geladen")
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
                messages.append(newMessage)
                print("📨 Nachricht gesendet: '\(text)' an Gruppe \(group.id)")
            } catch {
                errorMessage = "Nachricht konnte nicht gesendet werden: \(error.localizedDescription)"
                print("❌ Fehler beim Senden der Nachricht: \(error)")
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// ✅ ChatBubbleView für korrekte Ausrichtung
private struct ChatBubbleView: View {
    let message: Message
    let colorManager: ColorManager
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Avatar links für andere User
                Circle()
                    .fill(colorManager.color(for: message.sender, isCurrentUser: isCurrentUser))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(initials(for: message.sender.display_name))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
                
                messageContent
                
                Spacer() // ✅ Pusht fremde Nachrichten nach links
                
            } else {
                Spacer() // ✅ Pusht eigene Nachrichten nach rechts
                
                messageContent
                
                // Avatar rechts für aktiven User
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("DU")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender Name nur bei fremden Nachrichten anzeigen
            if !isCurrentUser {
                Text(message.sender.display_name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isCurrentUser ? Color.blue : Color(.systemGray5)
                )
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isCurrentUser ? Color.blue : Color(.systemGray4), lineWidth: 1)
                )
            
            Text(formatTime(message.sent_at))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isCurrentUser ? .trailing : .leading)
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
