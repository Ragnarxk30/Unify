import SwiftUI

// MARK: - Circle Image Cropper
struct CircleImageCropper: View {
    let image: UIImage
    let onCrop: (UIImage, UIImage) -> Void  // (fullImage, croppedCircle)
    let onCancel: () -> Void

    @State private var circleSize: CGFloat = 280
    @State private var circleOffset: CGSize = .zero
    @State private var lastCircleOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var imageFrame: CGRect = .zero

    private let minCircleSize: CGFloat = 150
    private let maxCircleSize: CGFloat = 350

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // 1cm Abstand von oben (~37pt)
                    Spacer()
                        .frame(height: 100)

                    // Image mit Circle Overlay (edge-to-edge)
                    ZStack {
                        // Festes Bild (edge-to-edge, kein Abstand)
                        GeometryReader { imageGeo in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: screenWidth, height: screenHeight * 0.7)
                                .clipped()
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.onAppear {
                                            imageFrame = proxy.frame(in: .local)
                                        }
                                    }
                                )
                        }
                        .frame(width: screenWidth, height: screenHeight * 0.7)

                        // Dimmed Overlay mit Circle Cutout
                        Rectangle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: screenWidth, height: screenHeight * 0.7)
                            .reverseMask {
                                Circle()
                                    .frame(width: circleSize, height: circleSize)
                                    .offset(circleOffset)
                            }

                        // Bewegbarer & Resizeable Circle Border
                        ZStack {
                            // Unsichtbare größere Hitbox
                            Circle()
                                .fill(Color.clear)
                                .frame(width: circleSize + 60, height: circleSize + 60)
                                .contentShape(Circle())

                            // Sichtbarer Circle Border
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: circleSize, height: circleSize)
                        }
                        .offset(circleOffset)
                        .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newOffsetX = lastCircleOffset.width + value.translation.width
                                        let newOffsetY = lastCircleOffset.height + value.translation.height

                                        // Begrenze Kreis im Foto-Bereich (nicht Screen)
                                        let imageWidth = screenWidth
                                        let imageHeight = screenHeight * 0.7
                                        let maxX = (imageWidth / 2) - (circleSize / 2)
                                        let maxY = (imageHeight / 2) - (circleSize / 2)

                                        circleOffset = CGSize(
                                            width: max(-maxX, min(maxX, newOffsetX)),
                                            height: max(-maxY, min(maxY, newOffsetY))
                                        )
                                    }
                                    .onEnded { _ in
                                        lastCircleOffset = circleOffset
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newSize = circleSize * delta

                                        // Begrenze Größe
                                        let imageWidth = screenWidth
                                        let imageHeight = screenHeight * 0.7
                                        let maxSize = min(imageWidth, imageHeight)
                                        circleSize = max(minCircleSize, min(maxSize, newSize))

                                        // Korrigiere Offset, damit Kreis im Foto bleibt
                                        let maxX = (imageWidth / 2) - (circleSize / 2)
                                        let maxY = (imageHeight / 2) - (circleSize / 2)
                                        circleOffset = CGSize(
                                            width: max(-maxX, min(maxX, circleOffset.width)),
                                            height: max(-maxY, min(maxY, circleOffset.height))
                                        )
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                    }
                    .frame(width: screenWidth, height: screenHeight * 0.7)
                    .clipped()

                    Spacer()

                    // Instructions
                    VStack(spacing: 8) {
                        Text("Bewege und zoome den Kreis")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text("um den gewünschten Ausschnitt auszuwählen")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 40)
                }

                // Header mit SafeArea (1cm = ~37pt nach unten)
                VStack {
                    HStack {
                        Button("Abbrechen") {
                            onCancel()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                        Spacer()

                        Text("Bild zuschneiden")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Button("Fertig") {
                            cropImage(screenWidth: screenWidth, screenHeight: screenHeight)
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 60)  // +60pt = ~1.5cm nach unten
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.black.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func cropImage(screenWidth: CGFloat, screenHeight: CGFloat) {
        let imageSize = image.size
        let displayWidth = screenWidth
        let displayHeight = screenHeight * 0.7

        print("📊 Crop-Berechnung:")
        print("   Image Size: \(imageSize)")
        print("   Display Size: \(displayWidth) x \(displayHeight)")
        print("   Circle: size=\(circleSize), offset=\(circleOffset)")

        // Berechne wie das Bild angezeigt wird (aspect fill)
        let imageAspect = imageSize.width / imageSize.height
        let displayAspect = displayWidth / displayHeight

        var displayedImageSize = CGSize.zero
        var displayedImageOrigin = CGPoint.zero

        if imageAspect > displayAspect {
            // Bild ist breiter - Höhe ausfüllen, Seiten abschneiden
            displayedImageSize.height = displayHeight
            displayedImageSize.width = displayHeight * imageAspect
            displayedImageOrigin.x = (displayWidth - displayedImageSize.width) / 2
            displayedImageOrigin.y = 0
        } else {
            // Bild ist höher - Breite ausfüllen, oben/unten abschneiden
            displayedImageSize.width = displayWidth
            displayedImageSize.height = displayWidth / imageAspect
            displayedImageOrigin.x = 0
            displayedImageOrigin.y = (displayHeight - displayedImageSize.height) / 2
        }

        print("   Displayed Image: size=\(displayedImageSize), origin=\(displayedImageOrigin)")

        // Circle-Center in Display-Koordinaten (relativ zum Container-Center)
        let containerCenterX = displayWidth / 2
        let containerCenterY = displayHeight / 2
        let circleCenterX = containerCenterX + circleOffset.width
        let circleCenterY = containerCenterY + circleOffset.height

        // Circle-Position im angezeigten Bild
        let circleInDisplayedImageX = circleCenterX - displayedImageOrigin.x
        let circleInDisplayedImageY = circleCenterY - displayedImageOrigin.y

        print("   Circle in Image: x=\(circleInDisplayedImageX), y=\(circleInDisplayedImageY)")

        // Skalierungsfaktor: Displayed → Original
        let scaleX = imageSize.width / displayedImageSize.width
        let scaleY = imageSize.height / displayedImageSize.height

        // Crop-Bereich im Original-Bild
        let cropCenterX = circleInDisplayedImageX * scaleX
        let cropCenterY = circleInDisplayedImageY * scaleY
        let cropSize = circleSize * scaleX // Verwende scaleX (sollte gleich sein wie scaleY)

        let cropX = cropCenterX - (cropSize / 2)
        let cropY = cropCenterY - (cropSize / 2)

        var cropRect = CGRect(
            x: cropX,
            y: cropY,
            width: cropSize,
            height: cropSize
        )

        // Sicherstellen, dass Crop-Bereich im Bild bleibt
        cropRect.origin.x = max(0, min(cropRect.origin.x, imageSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imageSize.height - cropRect.height))
        cropRect.size.width = min(cropRect.size.width, imageSize.width - cropRect.origin.x)
        cropRect.size.height = min(cropRect.size.height, imageSize.height - cropRect.origin.y)

        print("   Crop Rect: \(cropRect)")

        // Erstelle zugeschnittenes Bild
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            print("❌ CGImage cropping fehlgeschlagen")
            onCrop(image, image)
            return
        }

        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Erstelle kreisförmiges Bild
        let circleImage = makeCircularImage(from: croppedImage)

        print("✅ Crop erfolgreich: \(circleImage.size)")
        onCrop(image, circleImage)
    }

    private func makeCircularImage(from image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Kreisförmiger Clip-Pfad
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.addClip()

            // Zeichne Bild
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Reverse Mask Modifier
extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
