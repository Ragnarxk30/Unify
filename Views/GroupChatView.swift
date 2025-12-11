import SwiftUI
import Supabase

// MARK: - Constants
private enum ChatConstants {
    static let minimumRecordingDuration: TimeInterval = 0.5
    static let maxMessageWidth: CGFloat = UIScreen.main.bounds.width * 0.7
    static let avatarSize: CGFloat = 36
    static let bubbleCornerRadius: CGFloat = 18
    static let autoDismissDelay: UInt64 = 500_000_000
}

// MARK: - GroupChatView
struct GroupChatView: View {
    let group: AppGroup
    
    @State private var draft: String = ""
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?
    
    // Voice Recording
    @StateObject private var speechManager = SpeechToTextManager()
    @StateObject private var audioService = AudioRecorderService()
    @State private var isSendingVoiceMessage = false
    @State private var showSendConfirmation = false
    @State private var pendingVoiceMessage: (url: URL, duration: TimeInterval)?
    
    // Message Selection
    @State private var selectedMessages: Set<UUID> = []
    @State private var isSelectingMessages = false
    
    // Message Editing
    @State private var editingMessage: Message?
    @State private var editText: String = ""
    
    // Delete Confirmation
    @State private var messageToDelete: Message?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSelectedConfirmation = false
    
    // Profile Image Viewer
    @State private var selectedProfileImage: UIImage?
    @State private var selectedUserName: String?
    @State private var showProfileImageViewer = false
    @State private var selectedUserId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            messagesListView
            
            if isSelectingMessages {
                multiSelectToolbar
            }
            
            if audioService.isRecording {
                VoiceRecordingStatusView(
                    elapsedTime: audioService.recordingTime,
                    audioLevel: audioService.getCurrentAudioLevel(),
                    onStop: stopRecordingAndShowConfirmation
                )
            }
            
            if showSendConfirmation, let pending = pendingVoiceMessage {
                SendConfirmationStatusView(
                    duration: pending.duration,
                    onSend: sendPendingVoiceMessage,
                    onCancel: cancelPendingVoiceMessage
                )
            }
            
            composerView
            
            if speechManager.isRecording {
                speechRecognitionStatusView
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { handleOnAppear() }
        .onDisappear { handleOnDisappear() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleAppBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleAppForeground()
        }
        .alert("Berechtigung benötigt", isPresented: speechPermissionBinding) {
            Button("OK") { speechManager.errorMessage = nil }
            Button("Einstellungen") { openSettings() }
        } message: {
            Text(speechManager.errorMessage ?? "")
        }
        .alert("Fehler", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Nachricht löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { messageToDelete = nil }
            Button("Löschen", role: .destructive) {
                if let message = messageToDelete {
                    deleteMessage(message)
                }
            }
        } message: {
            Text("Diese Nachricht wird unwiderruflich gelöscht.")
        }
        .alert("Nachrichten löschen?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen (\(selectedMessages.count))", role: .destructive) {
                deleteSelectedMessages()
            }
        } message: {
            Text("\(selectedMessages.count) Nachrichten werden unwiderruflich gelöscht.")
        }
        .sheet(item: $editingMessage) { message in
            EditMessageSheet(
                message: message,
                editText: $editText,
                onSave: saveEditedMessage,
                onCancel: cancelEditing
            )
        }
        .fullScreenCover(isPresented: $showProfileImageViewer) {
            ProfileImageViewerSheet(
                image: $selectedProfileImage,
                userName: $selectedUserName,
                userId: $selectedUserId,
                onDismiss: {
                    showProfileImageViewer = false
                    selectedProfileImage = nil
                    selectedUserName = nil
                    selectedUserId = nil
                }
            )
        }
        .overlay {
            if isLoading {
                LoadingOverlay(text: "Nachrichten werden geladen...")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubbleView(
                            message: message,
                            isCurrentUser: isCurrentUser(message),
                            isSelected: isMessageSelected(message),
                            currentUserId: currentUserId,
                            audioService: audioService,
                            onProfileImageTap: { image, name in
                                print("🟦 onProfileImageTap CALLED")
                                print("   - image is nil: \(image == nil)")
                                print("   - name: \(name)")
                                
                                // Bestimme die richtige userId basierend auf wessen Bild es ist
                                let userId = isCurrentUser(message) ? currentUserId : message.sent_by
                                print("   - userId: \(userId)")
                                
                                // Setze State SOFORT
                                selectedProfileImage = image
                                selectedUserName = name
                                selectedUserId = userId
                                
                                print("   - State gesetzt - selectedProfileImage is nil: \(selectedProfileImage == nil)")
                                print("   - State gesetzt - selectedUserId: \(selectedUserId)")
                                
                                // Task für State-Update
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 Sekunden
                                    print("🟩 ÖFFNE SHEET")
                                    print("   - selectedProfileImage is nil: \(selectedProfileImage == nil)")
                                    print("   - selectedUserId: \(selectedUserId)")
                                    showProfileImageViewer = true
                                }
                            }
                        )
                        .id(message.id)
                        .onTapGesture {
                            if isSelectingMessages {
                                toggleMessageSelection(message)
                            }
                        }
                        .contextMenu {
                            contextMenuItems(for: message)
                        }
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
    }
    
    @ViewBuilder
    private func contextMenuItems(for message: Message) -> some View {
        if isCurrentUser(message) {
            Button(role: .destructive) {
                messageToDelete = message
                showDeleteConfirmation = true
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            
            Button {
                toggleMessageSelection(message)
            } label: {
                Label(
                    isMessageSelected(message) ? "Auswahl aufheben" : "Auswählen",
                    systemImage: isMessageSelected(message) ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            
            if message.isTextMessage {
                Button {
                    startEditingMessage(message)
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
            }
        } else {
            Button {
                toggleMessageSelection(message)
            } label: {
                Label("Auswählen", systemImage: "checkmark.circle")
            }
        }
    }
    
    private var multiSelectToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(selectedMessages.count) ausgewählt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(role: .destructive) {
                    showDeleteSelectedConfirmation = true
                } label: {
                    Label("Löschen", systemImage: "trash")
                        .font(.subheadline)
                }
                .disabled(selectedMessages.isEmpty)
                
                Button("Fertig") {
                    cancelSelection()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    private var composerView: some View {
        HStack(spacing: 12) {
            // Voice Message Button
            Button {
                handleVoiceButtonTap()
            } label: {
                Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.title2)
                    .foregroundColor(audioService.isRecording ? .red : .purple)
                    .symbolEffect(.bounce, value: audioService.isRecording)
            }
            .disabled(isSendingVoiceMessage)
            
            // Speech-to-Text Button
            Button {
                handleSpeechToTextTap()
            } label: {
                Image(systemName: speechManager.isRecording ? "waveform.circle.fill" : "waveform.circle")
                    .font(.title2)
                    .foregroundColor(speechManager.isRecording ? .red : .blue)
                    .symbolEffect(.bounce, value: speechManager.isRecording)
            }
            .disabled(!speechManager.hasPermission)
            
            // Text Field
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
                sendTextMessageFromDraft()
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
    
    private var speechRecognitionStatusView: some View {
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
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bindings
    
    private var speechPermissionBinding: Binding<Bool> {
        Binding(
            get: { speechManager.errorMessage != nil },
            set: { if !$0 { speechManager.errorMessage = nil } }
        )
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    // MARK: - Lifecycle
    
    private func handleOnAppear() {
        Task {
            await loadCurrentUserId()
            await loadMessages()
            await startRealtimeConnection()
            await markChatAsRead()
        }
    }
    
    private func handleOnDisappear() {
        ChatEndpoints.cleanupAllSubscriptions()
        audioService.cleanup()
        Task {
            await markChatAsRead()
        }
    }
    
    private func handleAppBackground() {
        ChatEndpoints.cleanupAllSubscriptions()
        audioService.cleanup()
    }
    
    private func handleAppForeground() {
        Task {
            await startRealtimeConnection()
        }
    }
    
    // MARK: - Message Actions
    
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
    
    private func cancelSelection() {
        selectedMessages.removeAll()
        isSelectingMessages = false
    }
    
    private func startEditingMessage(_ message: Message) {
        editingMessage = message
        editText = message.content
    }
    
    private func cancelEditing() {
        editingMessage = nil
        editText = ""
    }
    
    private func saveEditedMessage() {
        guard let message = editingMessage else { return }
        let newContent = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let updatedMessage = try await ChatEndpoints.editMessage(message.id, newContent: newContent)
                
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index] = updatedMessage
                    }
                    editingMessage = nil
                    editText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nachricht konnte nicht bearbeitet werden: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteMessage(_ message: Message) {
        Task {
            do {
                try await ChatEndpoints.deleteMessage(message)
                await MainActor.run {
                    messages.removeAll { $0.id == message.id }
                    selectedMessages.remove(message.id)
                    messageToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nachricht konnte nicht gelöscht werden: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteSelectedMessages() {
        let toDelete = messages.filter { selectedMessages.contains($0.id) }
        
        Task {
            var failedCount = 0
            
            for message in toDelete {
                do {
                    try await ChatEndpoints.deleteMessage(message)
                } catch {
                    failedCount += 1
                }
            }
            
            await MainActor.run {
                messages.removeAll { selectedMessages.contains($0.id) }
                selectedMessages.removeAll()
                isSelectingMessages = false
                
                if failedCount > 0 {
                    errorMessage = "\(failedCount) Nachricht(en) konnten nicht gelöscht werden."
                }
            }
        }
    }
    
    // MARK: - Voice Recording
    
    private func handleVoiceButtonTap() {
        if audioService.isRecording {
            stopRecordingAndShowConfirmation()
        } else {
            startVoiceRecording()
        }
    }
    
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
              audioService.recordingTime >= ChatConstants.minimumRecordingDuration else {
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
    
    // MARK: - Speech-to-Text
    
    private func handleSpeechToTextTap() {
        if speechManager.isRecording {
            speechManager.stopRecording()
            draft = speechManager.commitText()
        } else {
            speechManager.startRecording()
        }
    }
    
    // MARK: - Networking
    
    @MainActor
    private func markChatAsRead() async {
        do {
            try await UnreadMessagesService.shared.markAsRead(groupId: group.id)
        } catch {
            print("⚠️ Fehler beim Markieren als gelesen: \(error)")
        }
    }
    
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
    
    private func sendTextMessageFromDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendTextMessage(text)
        draft = ""
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
            let messageId = UUID()
            
            let urlString = try await uploader.uploadVoiceMessage(
                audioURL: localURL,
                groupId: group.id,
                groupName: group.name,
                messageId: messageId
            )
            
            let message = try await ChatEndpoints.sendVoiceMessage(
                groupID: group.id,
                groupName: group.name,
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
    
    // MARK: - Helpers
    
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
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Reusable Components

private struct MessageAvatarView: View {
    let profileImage: UIImage?
    let isLoading: Bool
    let onTap: () -> Void
    var size: CGFloat = ChatConstants.avatarSize
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(width: size, height: size)
                } else if let profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image("Avatar_Default")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingOverlay: View {
    let text: String
    
    var body: some View {
        ProgressView(text)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(10)
    }
}

// MARK: - Edit Message Sheet
private struct EditMessageSheet: View {
    let message: Message
    @Binding var editText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    private var trimmedText: String {
        editText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSave: Bool {
        !trimmedText.isEmpty && trimmedText != message.content
    }
    
    private var hasChanges: Bool {
        trimmedText != message.content
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Original Nachricht
                VStack(alignment: .leading, spacing: 8) {
                    Label("Original", systemImage: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
                
                // Bearbeiten
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Bearbeiten", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if hasChanges {
                            Text("Geändert")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                    }
                    
                    TextField("Nachricht...", text: $editText, axis: .vertical)
                        .lineLimit(1...6)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(hasChanges ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                        .focused($isTextFieldFocused)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { onCancel() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Voice Recording Status View

struct VoiceRecordingStatusView: View {
    let elapsedTime: TimeInterval
    let audioLevel: Float
    let onStop: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
            
            Text("Aufnahme...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            WaveformView(audioLevel: audioLevel)
            
            Spacer()
            
            Text(formatTime(elapsedTime))
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
            
            Button(action: onStop) {
                Text("Abbrechen")
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
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct WaveformView: View {
    let audioLevel: Float
    private let barCount = 6
    private let pattern: [CGFloat] = [6, 10, 14, 18, 16, 12]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 2, height: barHeight(for: index))
            }
        }
        .frame(height: 12)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let safeLevel = audioLevel.isFinite && !audioLevel.isNaN ? audioLevel : 0.5
        let clampedLevel = max(0.3, min(1.0, safeLevel))
        return max(3, pattern[index] * CGFloat(clampedLevel))
    }
}

// MARK: - Send Confirmation Status View
struct SendConfirmationStatusView: View {
    let duration: TimeInterval
    let onSend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
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
                .monospacedDigit()
            
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Image(systemName: "trash.fill")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Chat Bubble View
private struct ChatBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let isSelected: Bool
    let currentUserId: UUID?
    @ObservedObject var audioService: AudioRecorderService
    let onProfileImageTap: (UIImage?, String) -> Void
    
    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                MessageAvatarView(
                    profileImage: profileImage,
                    isLoading: isLoadingImage,
                    onTap: {
                        handleProfileImageTap(userName: message.sender.display_name)
                    }
                )
                
                messageContent
                Spacer()
            } else {
                Spacer()
                messageContent
                
                MessageAvatarView(
                    profileImage: profileImage,
                    isLoading: isLoadingImage,
                    onTap: {
                        // Übergebe den echten Namen des aktuellen Users
                        handleProfileImageTap(userName: message.sender.display_name)
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .task(id: message.id) {
            await loadProfileImage()
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
            
            ZStack(alignment: isCurrentUser ? .bottomLeading : .bottomTrailing) {
                messageBubble
                
                if isSelected {
                    selectionIndicator
                }
            }
            
            HStack(spacing: 4) {
                Text(timeString(from: message.sent_at))
                
                if message.is_edited == true {
                    Text("(bearbeitet)")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .frame(
            maxWidth: ChatConstants.maxMessageWidth,
            alignment: isCurrentUser ? .trailing : .leading
        )
    }
    
    @ViewBuilder
    private var messageBubble: some View {
        if message.isVoiceMessage {
            VoiceMessageBubble(message: message, audioService: audioService)
        } else {
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(ChatConstants.bubbleCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: ChatConstants.bubbleCornerRadius)
                        .stroke(isCurrentUser ? Color.blue : Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private var selectionIndicator: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 16, height: 16)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .offset(x: isCurrentUser ? 4 : -4, y: 4)
    }
    
    private func loadProfileImage() async {
        guard profileImage == nil else { return }
        
        await MainActor.run {
            isLoadingImage = true
        }
        
        let userId = isCurrentUser ? currentUserId : message.sent_by
        guard let userId = userId else {
            await MainActor.run { isLoadingImage = false }
            return
        }
        
        let image = await ProfileImageService.shared.getCachedProfileImage(for: userId)
        
        await MainActor.run {
            profileImage = image
            isLoadingImage = false
        }
    }

    private func handleProfileImageTap(userName: String) {
        guard !isLoadingImage else { return }
        
        if profileImage == nil {
            Task {
                await loadProfileImage()
                await MainActor.run {
                    // Wenn nach dem Laden immer noch kein Bild, übergebe trotzdem den Callback
                    // Der Viewer zeigt dann das Default-Logo
                    onProfileImageTap(profileImage, userName)
                }
            }
        } else {
            onProfileImageTap(profileImage, userName)
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
// MARK: - Voice Message Bubble
struct VoiceMessageBubble: View {
    let message: Message
    @ObservedObject var audioService: AudioRecorderService
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    private var isCurrentMessage: Bool {
        audioService.currentMessageId == message.id
    }
    
    private var isCurrentMessagePlaying: Bool {
        isCurrentMessage && audioService.isPlaying
    }
    
    private var baseDurationSeconds: Double {
        if let d = message.voice_duration {
            return Double(d)
        }
        if isCurrentMessage, audioService.duration > 0 {
            return audioService.duration
        }
        return 0
    }
    
    private var effectiveDurationSeconds: Double {
        if isCurrentMessage, audioService.duration > 0 {
            return audioService.duration
        }
        return baseDurationSeconds
    }
    
    private var displayTimeString: String {
        let displaySeconds: Int
        
        // Während des Draggings: zeige Drag-Position
        if isDragging {
            displaySeconds = Int((dragProgress * effectiveDurationSeconds).rounded())
        } else if isCurrentMessage,
                  audioService.currentTime > 0,
                  effectiveDurationSeconds > 0 {
            let clamped = min(audioService.currentTime, effectiveDurationSeconds)
            displaySeconds = Int(clamped.rounded())
        } else {
            displaySeconds = Int(effectiveDurationSeconds.rounded())
        }
        
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var progressPercentage: Double {
        // Während des Draggings: zeige Drag-Progress
        if isDragging {
            return dragProgress
        }
        
        guard isCurrentMessage,
              audioService.duration > 0 else {
            return 0
        }
        return min(audioService.currentTime / audioService.duration, 1.0)
    }
    
    private func waveformHeights(for width: CGFloat) -> [CGFloat] {
        let barWidth: CGFloat = 2
        let spacing: CGFloat = 2
        let barCount = Int(width / (barWidth + spacing))
        
        let heights: [CGFloat] = [8, 12, 16, 20, 16, 12, 8, 10, 14, 18, 15, 11, 17, 13, 9]
        
        return (0..<barCount).map { index in
            heights[index % heights.count]
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isCurrentMessagePlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .disabled(message.voice_url == nil)
            
            VStack(alignment: .leading, spacing: 4) {
                // Waveform mit Drag Gesture
                GeometryReader { geometry in
                    let heights = waveformHeights(for: geometry.size.width)
                    
                    ZStack(alignment: .leading) {
                        // Hintergrund-Bars
                        HStack(spacing: 2) {
                            ForEach(0..<heights.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.purple.opacity(0.25))
                                    .frame(width: 2, height: heights[index])
                            }
                        }
                        
                        // Vordergrund-Bars mit Progress
                        HStack(spacing: 2) {
                            ForEach(0..<heights.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.purple)
                                    .frame(width: 2, height: heights[index])
                            }
                        }
                        .frame(width: geometry.size.width * progressPercentage, alignment: .leading)
                        .clipped()
                        .animation(isDragging ? nil : .linear(duration: 0.1), value: progressPercentage)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Aktiviere Message, falls nicht aktiv
                                if !isCurrentMessage {
                                    startPlaybackForSeeking()
                                }
                                
                                isDragging = true
                                let progress = max(0, min(value.location.x / geometry.size.width, 1.0))
                                dragProgress = progress
                            }
                            .onEnded { value in
                                let progress = max(0, min(value.location.x / geometry.size.width, 1.0))
                                let seekTime = progress * effectiveDurationSeconds
                                
                                audioService.seek(to: seekTime)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 20)
                
                // Timer
                Text(displayTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            if isCurrentMessagePlaying {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(ChatConstants.bubbleCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ChatConstants.bubbleCornerRadius)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .onChange(of: audioService.errorMessage) { _, newValue in
            if newValue != nil && isCurrentMessage {
                audioService.stopPlayback()
            }
        }
        .onDisappear {
            if isCurrentMessage {
                audioService.stopPlayback()
            }
        }
    }
    
    private func togglePlayback() {
        guard let urlString = message.voice_url,
              let url = URL(string: urlString) else { return }
        
        if isCurrentMessagePlaying {
            audioService.pausePlayback()
        } else if isCurrentMessage {
            audioService.resumePlayback()
        } else {
            Task {
                await audioService.playAudioFromURL(url, for: message.id)
            }
        }
    }
    
    // Starte Playback im Pause-Zustand für Seeking
    private func startPlaybackForSeeking() {
        guard let urlString = message.voice_url,
              let url = URL(string: urlString) else { return }
        
        Task {
            await audioService.playAudioFromURL(url, for: message.id)
            audioService.pausePlayback()
        }
    }
}


// MARK: - AudioUploadService
struct AudioUploadService {
    func uploadVoiceMessage(
        audioURL: URL,
        groupId: UUID,
        groupName: String,
        messageId: UUID
    ) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        
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
