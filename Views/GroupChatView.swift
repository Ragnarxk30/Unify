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

    // ✅ NEUE STATES FÜR CONTEXT MENU
    @State private var selectedMessages: Set<UUID> = []
    @State private var isSelectingMessages = false
    @State private var editingMessage: Message?
    @State private var editText: String = ""

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
                                audioService: audioService,
                                isSelected: isMessageSelected(message)
                            )
                            .id(message.id)
                            // ✅ TAP GESTURE FÜR SELECTION 
                            .onTapGesture {
                                if isSelectingMessages {
                                    toggleMessageSelection(message)
                                }
                            }
                            .contextMenu {
                                // MARK: - Context Menu für Nachrichten
                                if isCurrentUser(message) {
                                    // Löschen Button (immer verfügbar für eigenen User)
                                    Button(role: .destructive) {
                                        deleteMessage(message)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    
                                    // Markieren Button
                                    Button {
                                        toggleMessageSelection(message)
                                    } label: {
                                        Label(
                                            isMessageSelected(message) ? "Nicht markieren" : "Markieren",
                                            systemImage: isMessageSelected(message) ? "checkmark.circle.fill" : "checkmark.circle"
                                        )
                                    }
                                    
                                    // Bearbeiten Button (nur für Textnachrichten)
                                    if message.isTextMessage {
                                        Button {
                                            startEditingMessage(message)
                                        } label: {
                                            Label("Bearbeiten", systemImage: "pencil")
                                        }
                                    }
                                } else {
                                    // Nur Markieren für fremde Nachrichten
                                    Button {
                                        toggleMessageSelection(message)
                                    } label: {
                                        Label("Markieren", systemImage: "checkmark.circle")
                                    }
                                }
                            }
                            // ✅ KEIN .disabled MEHR - alles wird über Tap Gesture geregelt
                            .contentShape(Rectangle())
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

            // MARK: - Multi-Select Toolbar (✅ AUSSERHALB DES SCROLLVIEW)
            if isSelectingMessages {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Text("\(selectedMessages.count) ausgewählt")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            deleteSelectedMessages()
                        } label: {
                            Label("Löschen", systemImage: "trash")
                                .font(.subheadline)
                        }
                        
                        Button("Fertig") {
                            selectedMessages.removeAll()
                            isSelectingMessages = false
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }

            // MARK: - Voice Recording Status
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
                await markChatAsRead()
            }
        }
        .onDisappear {
            ChatEndpoints.cleanupAllSubscriptions()
            audioService.cleanup()
            Task {
                        await markChatAsRead()
                    }
        }
        // ✅ CLEANUP BEI APP-HINTERGRUND HINZUFÜGEN
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            ChatEndpoints.cleanupAllSubscriptions()
            audioService.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await startRealtimeConnection()
            }
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
        .sheet(item: $editingMessage) { message in
            NavigationView {
                VStack {
                    TextField("Nachricht bearbeiten...", text: $editText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("Nachricht bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            editingMessage = nil
                            editText = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            saveEditedMessage()
                        }
                        .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Context Menu Actions
    @MainActor
        private func markChatAsRead() async {
            do {
                try await UnreadMessagesService.shared.markAsRead(groupId: group.id)
                print("✅ Chat als gelesen markiert")
            } catch {
                print("⚠️ Fehler beim Markieren als gelesen: \(error)")
            }
        }

    private func deleteMessage(_ message: Message) {
        Task {
            do {
                try await ChatEndpoints.deleteMessage(message)
                await MainActor.run {
                    messages.removeAll { $0.id == message.id }
                    selectedMessages.remove(message.id)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nachricht konnte nicht gelöscht werden: \(error.localizedDescription)"
                }
            }
        }
    }

    private func toggleMessageSelection(_ message: Message) {
        if selectedMessages.contains(message.id) {
            selectedMessages.remove(message.id)
        } else {
            selectedMessages.insert(message.id)
        }
        isSelectingMessages = !selectedMessages.isEmpty
    }

    private func isMessageSelected(_ message: Message) -> Bool {
        selectedMessages.contains(message.id)
    }

    private func startEditingMessage(_ message: Message) {
        editingMessage = message
        editText = message.content
    }

    private func saveEditedMessage() {
        guard let editingMessage = editingMessage else { return }
        
        Task {
            do {
                let updatedMessage = try await ChatEndpoints.editMessage(
                    editingMessage.id,
                    newContent: editText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == editingMessage.id }) {
                        messages[index] = updatedMessage
                    }
                    self.editingMessage = nil
                    self.editText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nachricht konnte nicht bearbeitet werden: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteSelectedMessages() {
        let toDelete = messages.filter { selectedMessages.contains($0.id) }
        
        Task {
            for message in toDelete {
                try? await ChatEndpoints.deleteMessage(message)
            }
            
            await MainActor.run {
                messages.removeAll { selectedMessages.contains($0.id) }
                selectedMessages.removeAll()
                isSelectingMessages = false
            }
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
            
            // ✅ MESSAGE ID VORHER GENERIEREN
            let messageId = UUID()
            
            let urlString = try await uploader.uploadVoiceMessage(
                audioURL: localURL,
                groupId: group.id,
                groupName: group.name, // ✅ GROUP NAME WIEDER ÜBERGEBEN
                messageId: messageId    // ✅ MESSAGE ID ÜBERGEBEN
            )

            let message = try await ChatEndpoints.sendVoiceMessage(
                groupID: group.id,
                groupName: group.name,  // ✅ GROUP NAME ÜBERGEBEN
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
                        Text("🗑️")
                            .font(.title3)
                            .padding(.horizontal, 11.1)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onSend) {
                        Text("↑")
                            .font(.title3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.9))
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

private struct ChatBubbleView: View {
    let message: Message
    let colorManager: ColorManager
    let isCurrentUser: Bool
    @ObservedObject var audioService: AudioRecorderService
    let isSelected: Bool
    
    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Profilbild OHNE Checkmark
                Group {
                    if isLoadingImage {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image("Avatar_Default")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onAppear {
                    if !isCurrentUser {
                        Task {
                            await loadProfileImage(for: message.sent_by)
                        }
                    }
                }

                messageContent
                Spacer()
            } else {
                Spacer()
                messageContent

                // Profilbild OHNE Checkmark
                Group {
                    if isLoadingImage {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image("Avatar_Default")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onAppear {
                    if isCurrentUser {
                        Task {
                            await loadOwnProfileImage()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .cornerRadius(8)
    }
    
    private func loadProfileImage(for userId: UUID) async {
        await MainActor.run {
            isLoadingImage = true
        }
        
        let image = await ProfileImageService.shared.getCachedProfileImage(for: userId)
        
        await MainActor.run {
            profileImage = image
            isLoadingImage = false
        }
    }
    
    private func loadOwnProfileImage() async {
        await MainActor.run {
            isLoadingImage = true
        }
        
        do {
            let userId = try await SupabaseAuthRepository().currentUserId()
            let image = await ProfileImageService.shared.getCachedProfileImage(for: userId)
            
            await MainActor.run {
                profileImage = image
                isLoadingImage = false
            }
        } catch {
            await MainActor.run {
                isLoadingImage = false
                profileImage = nil
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isCurrentUser {
                Text(message.sender.display_name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            // 👈 ZStack mit Checkmark auf der Nachricht
            ZStack(alignment: isCurrentUser ? .bottomLeading : .bottomTrailing) {
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
                
                // 👈 CHECKMARK UNTEN AUF DER NACHRICHT (wie vorher)
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(
                            x: isCurrentUser ? 4 : -4,
                            y: 4
                        )
                }
            }

            Text(timeString(from: message.sent_at))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7,
               alignment: isCurrentUser ? .trailing : .leading)
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
            if !newValue && isPlayingLocal {
                isPlayingLocal = false
            }
        }
        .onChange(of: audioService.errorMessage) { oldValue, newValue in
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
    func uploadVoiceMessage(audioURL: URL, groupId: UUID, groupName: String, messageId: UUID) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        // ✅ ZURÜCK ZUR GRUPPEN-STRUKTUR: "gruppenname/message-id.m4a"
        let safeGroupName = groupName.replacingOccurrences(of: "/", with: "-")
        let path = "\(safeGroupName)/\(messageId).m4a"

        _ = try await supabase.storage
            .from("voice-messages")
            .upload(path, data: audioData)

        let publicURL = try supabase.storage
            .from("voice-messages")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }
}
