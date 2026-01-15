import SwiftUI

public struct DarkModeLogoView: View {
    @Environment(\.colorScheme) var colorScheme
    public var size: CGFloat = 30
    public var showText: Bool = true
    public var text: String = "SYSM"
    public var cornerRadius: CGFloat = 8
    
    public init(size: CGFloat = 30, showText: Bool = true, text: String = "SYSM", cornerRadius: CGFloat = 8) {
        self.size = size
        self.showText = showText
        self.text = text
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(colorScheme == .dark ? "SYSMLogoDark" : "SYSMLogo")
                .resizable()
                .frame(width: size, height: size)
                .cornerRadius(cornerRadius)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 2,
                    x: 0,
                    y: 1
                )
            
            if showText {
                Text(text)
                    .font(.system(size: size * 0.7, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}
