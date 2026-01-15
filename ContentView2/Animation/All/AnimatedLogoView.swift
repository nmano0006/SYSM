// Views/AnimatedLogoView.swift
import SwiftUI

struct AnimatedLogoView: View {
    let size: CGFloat
    let animationType: AnimationType
    let duration: Double
    
    enum AnimationType {
        case rotate, pulse, shake
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "desktopcomputer")
            .resizable()
            .frame(width: size, height: size)
            .foregroundColor(.blue)
            .applyAnimation(type: animationType, isAnimating: isAnimating, duration: duration)
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    @ViewBuilder
    func applyAnimation(type: AnimatedLogoView.AnimationType, isAnimating: Bool, duration: Double) -> some View {
        switch type {
        case .rotate:
            self.rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        case .pulse:
            self.scaleEffect(isAnimating ? 1.1 : 1.0)
                .opacity(isAnimating ? 0.8 : 1.0)
                .animation(
                    Animation.easeInOut(duration: duration)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        case .shake:
            self.offset(x: isAnimating ? 5 : -5)
                .animation(
                    Animation.easeInOut(duration: duration/2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
    }
}