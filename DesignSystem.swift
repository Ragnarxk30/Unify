import SwiftUI

extension Color {
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
    static let cardStroke = Color.gray.opacity(0.25)
    static let brandPrimary = Color.blue
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.cardStroke))
    }
}
extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

struct SegmentedToggle<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String
    let systemImage: (T) -> String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isSel = opt == selection
                HStack(spacing: 6) {
                    if let img = systemImage(opt) {
                        Image(systemName: img)
                    }
                    Text(title(opt))
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSel ? Color.black : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSel ? Color.white : Color.primary)
                .overlay {
                    Capsule().stroke(Color.black.opacity(0.08))
                }
                .onTapGesture { selection = opt }
            }
        }
        .padding(6)
        .background(Color(.systemGray6), in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.08)))
    }
}
