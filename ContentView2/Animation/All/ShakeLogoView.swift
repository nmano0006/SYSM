// Views/ShakeLogoView.swift
import SwiftUI

struct ShakeLogoView: View {
    let size: CGFloat
    let intensity: CGFloat
    let speed: Double
    
    @State private var isShaking = false
    
    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .resizable()
            .frame(width: size, height: size)
            .foregroundColor(.orange)
            .rotationEffect(.degrees(isShaking ? intensity : -intensity))
            .animation(
                Animation.easeInOut(duration: speed)
                    .repeatForever(autoreverses: true),
                value: isShaking
            )
            .onAppear {
                isShaking = true
            }
    }
}