import SwiftUI

extension Color {
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
    static let cardStroke = Color.gray.opacity(0.25)
    static let brandPrimary = Color.blue
}

/**
 Globale Kartenoptik: volle Breite, links ausgerichtet.
 **/
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading) // Inhalt links ausrichten
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cardStroke)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - SegmentedToggle im kompakten Box-Stil

struct SegmentedToggle<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String
    let systemImage: (T) -> String?

    // Box-Design-Parameter (kompakter)
    private let containerCorner: CGFloat = 12
    private let itemCorner: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { opt in
                let isSel = opt == selection
                HStack(spacing: 6) {
                    if let img = systemImage(opt) {
                        Image(systemName: img)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(title(opt))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: itemCorner, style: .continuous)
                        .fill(isSel ? Color.black : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSel ? Color.white : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: itemCorner, style: .continuous)
                        .stroke(Color.black.opacity(0.08))
                )
                .onTapGesture { selection = opt }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: containerCorner, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: containerCorner, style: .continuous)
                .stroke(Color.black.opacity(0.08))
        )
    }
}
