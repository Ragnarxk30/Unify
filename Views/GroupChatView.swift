//
//  GroupChatView.swift
//

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
    @StateObject private var audioService = AudioRecorderService()

    @State private var currentUserId: UUID?
    @State private var isSendingVoiceMessage = false

    // ✅ NEUE STATES FÜR TAP-SYSTEM
    @State private var showSendConfirmation = false
    @State private var pendingVoiceMessage: (url: URL, duration: TimeInterval)?

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(
                                message: message,
                                colorManager: colorManager,
                                isCurrentUser: isCurrentUser(message),
                                audioService: audioService
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { oldValue, newValue in
                    if newValue > oldValue {
                        scrollToBottom(proxy)
                    }
                }
                .onAppear {
                    scrollToBottom(proxy)
                }
            }
            .background(Color(.systemGroupedBackground))

            // MARK: - Voice Recording Status (WIE SPEECH-TO-TEXT)
            if audioService.isRecording {
                VoiceRecordingStatusView(
                    elapsedTime: audioService.recordingTime,
                    audioLevel: audioService.getCurrentAudioLevel(),
                    onStop: stopRecordingAndShowConfirmation
                )
            }

            // MARK: - Send Confirmation Status
            if showSendConfirmation, let pending = pendingVoiceMessage {
                SendConfirmationStatusView(
                    duration: pending.duration,
                    onSend: sendPendingVoiceMessage,
                    onCancel: cancelPendingVoiceMessage
                )
            }

            // MARK: - Composer
            HStack(spacing: 12) {
                // ✅ VOICE MESSAGE BUTTON - TAP SYSTEM
                Button {
                    if audioService.isRecording {
                        // Zweiter Tap: Recording stoppen → Bestätigung anzeigen
                        stopRecordingAndShowConfirmation()
                    } else {
                        // Erster Tap: Recording starten
                        startVoiceRecording()
                    }
                } label: {
                    Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.title2)
                        .foregroundColor(audioService.isRecording ? .red : .purple)
                        .symbolEffect(.bounce, value: audioService.isRecording)
                }
                .disabled(isSendingVoiceMessage)

                // Speech-to-Text Button
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

                // Textfeld
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                // Send Button
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    sendTextMessage(text)
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

            // Speech Recognition Status
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
                await startRealtimeConnection()
            }
        }
        .onDisappear {
            ChatEndpoints.cleanupAllSubscriptions()
            audioService.cleanup()
        }
        .alert(
            "Berechtigung benötigt",
            isPresented: Binding(
                get: { speechManager.errorMessage != nil },
                set: { if !$0 { speechManager.errorMessage = nil } }
            )
        ) {
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
        .alert("Fehler", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Voice Recording Handling (TAP SYSTEM)

    private func startVoiceRecording() {
        guard !isSendingVoiceMessage else { return }
        
        audioService.cleanup()
        
        Task {
            await audioService.startRecording()
        }
    }

    private func stopRecordingAndShowConfirmation() {
        audioService.stopRecording()
        
        guard let url = audioService.recordedAudioURL,
              audioService.recordingTime >= 0.5 else {
            audioService.cleanup()
            return
        }
        
        pendingVoiceMessage = (url: url, duration: audioService.recordingTime)
        showSendConfirmation = true
    }

    private func sendPendingVoiceMessage() {
        guard let pending = pendingVoiceMessage else { return }
        
        isSendingVoiceMessage = true
        showSendConfirmation = false
        
        Task {
            await sendVoiceMessage(from: pending.url, duration: pending.duration)
            audioService.cleanup()
            pendingVoiceMessage = nil
            
            await MainActor.run {
                isSendingVoiceMessage = false
            }
        }
    }

    private func cancelPendingVoiceMessage() {
        audioService.cleanup()
        pendingVoiceMessage = nil
        showSendConfirmation = false
    }

    // MARK: - Networking / Chat

    private func loadCurrentUserId() async {
        do {
            let session = try await supabase.auth.session
            await MainActor.run {
                currentUserId = session.user.id
            }
        } catch {
            await MainActor.run {
                errorMessage = "Fehler beim Laden der User-ID: \(error.localizedDescription)"
            }
        }
    }

    private func loadMessages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetched = try await ChatEndpoints.fetchMessages(for: group.id)
            await MainActor.run {
                messages = fetched
            }
        } catch {
            await MainActor.run {
                errorMessage = "Nachrichten konnten nicht geladen werden: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    @MainActor
    private func startRealtimeConnection() async {
        do {
            try await ChatEndpoints.startRealtimeSubscription(
                groupID: group.id,
                onMessage: { newMessage in
                    if !messages.contains(where: { $0.id == newMessage.id }) {
                        messages.append(newMessage)
                    }
                }
            )
        } catch {
            errorMessage = "Echtzeit-Chat nicht verfügbar: \(error.localizedDescription)"
        }
    }

    private func sendTextMessage(_ text: String) {
        Task {
            do {
                let message = try await ChatEndpoints.sendMessage(groupID: group.id, content: text)
                await MainActor.run {
                    if !messages.contains(where: { $0.id == message.id }) {
                        messages.append(message)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nachricht konnte nicht gesendet werden: \(error.localizedDescription)"
                }
            }
        }
    }

    private func sendVoiceMessage(from localURL: URL, duration: TimeInterval) async {
        do {
            let uploader = AudioUploadService()
            let urlString = try await uploader.uploadVoiceMessage(
                audioURL: localURL,
                groupId: group.id,
                userId: currentUserId ?? UUID()
            )

            let message = try await ChatEndpoints.sendVoiceMessage(
                groupID: group.id,
                voiceUrl: urlString,
                duration: Int(duration)
            )

            await MainActor.run {
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Sprachnachricht konnte nicht gesendet werden: \(error.localizedDescription)"
            }
        }
    }

    private func isCurrentUser(_ message: Message) -> Bool {
        guard let currentUserId else { return false }
        return message.sent_by == currentUserId
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Voice Recording Status View (WIE SPEECH-TO-TEXT)

struct VoiceRecordingStatusView: View {
    let elapsedTime: TimeInterval
    let audioLevel: Float
    let onStop: () -> Void
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [6, 10, 14, 18, 16, 12, 8, 10, 14, 16, 12, 8]
        let safeLevel = audioLevel.isFinite && !audioLevel.isNaN ? audioLevel : 0.5
        let clampedLevel = max(0.3, min(1.0, safeLevel))
        return max(3, pattern[index] * CGFloat(clampedLevel))
    }
    
    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
            
            Text("recording...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Waveform in der gleichen Reihe
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 2, height: barHeight(for: index))
                }
            }
            .frame(height: 12)
            
            Spacer()
            
            Text(formatTime(elapsedTime))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .monospacedDigit()
            
            Button(action: onStop) {
                Text("cancel")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
// MARK: - Send Confirmation Status View

struct SendConfirmationStatusView: View {
    let duration: TimeInterval
    let onSend: () -> Void
    let onCancel: () -> Void
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Sprachnachricht bereit")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text("🗑️") // 🗑️ Mülleimer Emoji
                            .font(.title3) // GLEICHE GRÖSSE
                            .padding(.horizontal, 11.1)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.9)) // WENIGER TRANSPARENT
                            .cornerRadius(10)
                    }
                    
                    Button(action: onSend) {
                        Text("↑") // ↑ Pfeil nach oben
                            .font(.title3) // GLEICHE GRÖSSE
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.9)) // WENIGER TRANSPARENT
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - ChatBubbleView & VoiceMessageBubble

private struct ChatBubbleView: View {
    let message: Message
    let colorManager: ColorManager
    let isCurrentUser: Bool
    @ObservedObject var audioService: AudioRecorderService

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Avatar
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
                Spacer()
            } else {
                Spacer()
                messageContent

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
            if !isCurrentUser {
                Text(message.sender.display_name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            if message.isVoiceMessage {
                VoiceMessageBubble(message: message, audioService: audioService)
            } else {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isCurrentUser ? Color.blue : Color(.systemGray4), lineWidth: 1)
                    )
            }

            Text(timeString(from: message.sent_at))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7,
               alignment: isCurrentUser ? .trailing : .leading)
    }

    private func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    private func timeString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}

struct VoiceMessageBubble: View {
    let message: Message
    @ObservedObject var audioService: AudioRecorderService
    @State private var isPlayingLocal = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlayingLocal ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .disabled(message.voice_url == nil)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    let heights: [CGFloat] = [8, 12, 16, 20, 16, 12, 8, 10, 14, 18]
                    ForEach(0..<heights.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.purple.opacity(0.6))
                            .frame(width: 2, height: heights[index])
                    }
                }

                Text(message.formattedDuration ?? "0:00")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isPlayingLocal {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .onChange(of: audioService.isPlaying) { oldValue, newValue in
            // ✅ OPTIMIERT: State Synchronisation
            if !newValue && isPlayingLocal {
                isPlayingLocal = false
            }
        }
        .onChange(of: audioService.errorMessage) { oldValue, newValue in
            // ✅ ERROR HANDLING: Bei Fehler Playback stoppen
            if newValue != nil && isPlayingLocal {
                isPlayingLocal = false
            }
        }
        .onDisappear {
            if isPlayingLocal {
                audioService.stopPlayback()
                isPlayingLocal = false
            }
        }
    }

    private func togglePlayback() {
        guard let urlString = message.voice_url, let url = URL(string: urlString) else { return }

        if isPlayingLocal {
            audioService.stopPlayback()
            isPlayingLocal = false
        } else {
            isPlayingLocal = true
            Task {
                await audioService.playAudioFromURL(url)
                // Fallback: falls Playback nicht startet
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if !audioService.isPlaying && isPlayingLocal {
                        isPlayingLocal = false
                    }
                }
            }
        }
    }
}

// MARK: - AudioUploadService

struct AudioUploadService {
    func uploadVoiceMessage(audioURL: URL, groupId: UUID, userId: UUID) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(userId.uuidString)/\(groupId.uuidString)/voice-\(timestamp).m4a"

        _ = try await supabase.storage
            .from("voice-messages")
            .upload(path, data: audioData)

        let publicURL = try supabase.storage
            .from("voice-messages")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }
}
