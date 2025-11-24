import UIKit

extension UIImage {
    func heicData(compressionQuality: CGFloat) -> Data? {
        // Da HEIC nicht direkt einfach unterstützt wird,
        // Fallback zu JPEG mit hoher Qualität
        return self.jpegData(compressionQuality: compressionQuality)
    }
    
    // Optional: Hilfsfunktion um das beste Format zu wählen
    func optimizedData(for format: String, quality: CGFloat = 0.8) -> Data? {
        switch format.lowercased() {
        case "png":
            return self.pngData()
        case "jpeg", "jpg":
            return self.jpegData(compressionQuality: quality)
        case "heic":
            return self.heicData(compressionQuality: quality)
        default:
            return self.jpegData(compressionQuality: quality)
        }
    }
}
