import SwiftUI

public struct InteractiveLogoView: View {
    public var size: CGFloat = 40
    public var useDarkMode: Bool = true
    @State private var isHovering = false
    @State private var isClicked = false
    @Environment(\.colorScheme) var colorScheme
    
    public init(size: CGFloat = 40, useDarkMode: Bool = true) {
        self.size = size
        self.useDarkMode = useDarkMode
    }
    
    public var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            .scaleEffect(isClicked ? 0.9 : (isHovering ? 1.1 : 1.0))
            .shadow(
                color: .blue.opacity(isHovering ? 0.5 : 0.2),
                radius: isHovering ? 10 : 4,
                x: 0,
                y: isHovering ? 5 : 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
            .animation(.easeInOut(duration: 0.1), value: isClicked)
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isClicked = true
                    }
                    .onEnded { _ in
                        isClicked = false
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                    }
            )
    }
    
    private var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
}
