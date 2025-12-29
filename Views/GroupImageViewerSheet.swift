import SwiftUI

// MARK: - Group Image Viewer Sheet
struct GroupImageViewerSheet: View {
    @Binding var image: UIImage?
    @Binding var groupName: String?
    @Binding var groupId: UUID?
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 {
                                onDismiss()
                            }
                        }
                )

            // Zeige ProgressView während des Ladens
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .zIndex(1)
            }

            // Zeige Bild wenn vorhanden (entweder übergeben oder geladen)
            if let displayImage = loadedImage ?? image {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.9, maxHeight: UIScreen.main.bounds.height * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { value in
                                if scale > 1.0 {
                                    lastOffset = offset
                                } else if value.translation.height > 100 {
                                    onDismiss()
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
                    .zIndex(1)
            } else if !isLoading {
                // Fallback: Initialen anzeigen
                if let groupName = groupName {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 300, height: 300)

                        Text(String(groupName.prefix(2)).uppercased())
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .zIndex(1)
                }
            }

            // X-Button
            VStack {
                HStack {
                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }

                Spacer()
            }
            .zIndex(100)
        }
        .task {
            // Wenn kein Bild übergeben wurde, versuche es zu laden
            if image == nil, let groupId = groupId {
                isLoading = true
                loadedImage = await GroupImageService.shared.getCachedGroupImage(for: groupId)
                isLoading = false
            }
        }
    }
}
