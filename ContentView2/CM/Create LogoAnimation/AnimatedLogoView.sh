cat > AnimatedLogoView.swift << 'EOF'
import SwiftUI

public struct AnimatedLogoView: View {
    public var size: CGFloat = 40
    public var animationType: LogoAnimationType = .pulse
    public var duration: Double = 2.0
    public var animated: Bool = true
    public var useDarkMode: Bool = false
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0
    @State private var shadowRadius: CGFloat = 2
    @Environment(\.colorScheme) var colorScheme
    
    public init(size: CGFloat = 40, animationType: LogoAnimationType = .pulse, duration: Double = 2.0, animated: Bool = true, useDarkMode: Bool = false) {
        self.size = size
        self.animationType = animationType
        self.duration = duration
        self.animated = animated
        self.useDarkMode = useDarkMode
    }
    
    public var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(y: offset)
            .shadow(color: .blue.opacity(0.5), radius: shadowRadius + glowIntensity)
            .onAppear {
                if animated {
                    startAnimation()
                }
            }
    }
    
    private var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
    
    private func startAnimation() {
        switch animationType {
        case .pulse:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
        case .rotate:
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        case .bounce:
            withAnimation(.easeInOut(duration: duration/2).repeatForever(autoreverses: true)) {
                offset = -8
            }
        case .glow:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                glowIntensity = 8
                shadowRadius = 6
            }
        case .shake:
            let animation = Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)
            withAnimation(animation) {
                rotation = 8
            }
        case .float:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                offset = -12
                scale = 1.08
            }
        }
    }
}
EOF