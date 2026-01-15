// Views/EarthquakeLogoView.swift
import SwiftUI

struct EarthquakeLogoView: View {
    let size: CGFloat
    let intensity: CGFloat
    
    @State private var isShaking = false
    
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .resizable()
            .frame(width: size, height: size)
            .foregroundColor(.red)
            .rotationEffect(.degrees(isShaking ? intensity : -intensity))
            .animation(
                Animation.easeInOut(duration: 0.1)
                    .repeatForever(autoreverses: true),
                value: isShaking
            )
            .onAppear {
                isShaking = true
            }
    }
}