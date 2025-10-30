import SwiftUI

struct GroupChatView: View {
    @State var vm: ChatViewModel
    @State private var draft: String = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.group.messages) { msg in
                            ChatBubble(message: msg, isMe: msg.sender.id == MockData.me.id)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(proxy)
                }
                .onChange(of: vm.group.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            HStack(spacing: 8) {
                TextField("Nachricht eingeben...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    vm.send(text: text)
                    draft = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.brandPrimary, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear { vm.refreshFromStore() }
    }

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

private struct ChatBubble: View {
    let message: Message
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isMe { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                if !isMe {
                    Text(message.sender.displayName == "Ich" ? "Ich" : message.sender.displayName)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Text(message.text)
                    .padding(10)
                    .background(isMe ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if !isMe { Spacer(minLength: 40) }
        }
    }
}
