import SwiftUI

struct AnimatedLogoView: View {
    let size: CGFloat
    let animationType: AnimationType
    let duration: Double
    let useDarkMode: Bool
    
    enum AnimationType {
        case shake, rotate, pulse
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        Image("SYSMLogo")
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .modifier(AnimationModifier(
                animationType: animationType,
                isAnimating: isAnimating,
                duration: duration
            ))
            .onAppear {
                withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct AnimationModifier: ViewModifier {
    let animationType: AnimatedLogoView.AnimationType
    let isAnimating: Bool
    let duration: Double
    
    func body(content: Content) -> some View {
        switch animationType {
        case .shake:
            content
                .rotationEffect(.degrees(isAnimating ? -5 : 5))
        case .rotate:
            content
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        case .pulse:
            content
                .scaleEffect(isAnimating ? 1.1 : 0.9)
        }
    }
}