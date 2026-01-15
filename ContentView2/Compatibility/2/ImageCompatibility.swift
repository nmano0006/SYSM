import SwiftUI

struct CompatibleImage {
    static func system(_ name: String) -> Image {
        // Simple fallback - just use the name directly
        // Older macOS will show a placeholder if symbol doesn't exist
        return Image(systemName: name)
    }
}