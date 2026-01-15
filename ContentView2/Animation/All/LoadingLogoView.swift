// Views/LoadingLogoView.swift
import SwiftUI

struct LoadingLogoView: View {
    let size: CGFloat
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .blue]),
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: rotation
                )
            
            Image(systemName: "gear")
                .resizable()
                .frame(width: size * 0.6, height: size * 0.6)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(-rotation))
        }
        .onAppear {
            rotation = 360
        }
    }
}