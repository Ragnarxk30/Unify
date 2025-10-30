import SwiftUI

struct GroupChatView: View {
    @StateObject var vm: ChatViewModel
    @State private var draft: String = ""

    init(vm: ChatViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(vm.group.messages) { msg in
                            ChatRow(message: msg, isMe: msg.sender.id == MockData.me.id)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .onAppear { scrollToBottom(proxy) }
                .onChange(of: vm.group.messages.count) { _ in
                    scrollToBottom(proxy)
                }
            }

            // Composer
            HStack(spacing: 10) {
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    vm.send(text: text)
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
            .background(.ultraThinMaterial)
        }
        .onAppear { vm.refreshFromStore() }
    }

    // MARK: - Helpers

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

// MARK: - Row + Subviews

private struct ChatRow: View {
    let message: Message
    let isMe: Bool

    var body: some View {
        if isMe {
            // Rechte Seite (eigene Nachricht)
            HStack(alignment: .bottom, spacing: 12) {
                Spacer(minLength: 120)

                VStack(alignment: .trailing, spacing: 6) {
                    // Name "Du" rechts
                    Text("Du")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Blaue Bubble rechtsbündig
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: 420, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // Zeitstempel rechts
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Avatar rechts klein gedimmt (wie im Screenshot angedeutet)
                InitialsAvatar(initials: "DU")
            }
        } else {
            // Linke Seite (andere)
            HStack(alignment: .top, spacing: 12) {
                InitialsAvatar(initials: initials(for: message.sender.displayName))

                VStack(alignment: .leading, spacing: 6) {
                    // Name
                    Text(message.sender.displayName == "Ich" ? "Ich" : message.sender.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Helle Bubble
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: 460, alignment: .leading)

                    // Zeitstempel links
                    Text(Self.timeString(message.sentAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 80)
            }
        }
    }

    private func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let second = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    static func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}

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
