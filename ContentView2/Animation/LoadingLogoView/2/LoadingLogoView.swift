// Views/LoadingLogoView.swift
import SwiftUI

// Main Loading Logo View
struct LoadingLogoView: View {
    let size: CGFloat
    let color: Color
    let showBackground: Bool
    let animationSpeed: Double
    
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.7
    
    // Simple initializer with default values
    init(size: CGFloat = 60) {
        self.size = size
        self.color = .blue
        self.showBackground = true
        self.animationSpeed = 1.0
    }
    
    // Full initializer
    init(size: CGFloat = 60, color: Color = .blue, showBackground: Bool = true, animationSpeed: Double = 1.0) {
        self.size = size
        self.color = color
        self.showBackground = showBackground
        self.animationSpeed = animationSpeed
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                // Background circle with gradient
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.3),
                                color.opacity(0.1)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size/2
                        )
                    )
                    .frame(width: size, height: size)
            }
            
            // Main gear icon
            Image(systemName: "gear")
                .font(.system(size: size * (showBackground ? 0.7 : 1.0)))
                .foregroundColor(color)
                .rotationEffect(.degrees(rotation))
            
            if showBackground {
                // Outer pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.5),
                                color.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Gear rotation animation
        withAnimation(
            Animation.linear(duration: 2.0 / animationSpeed)
                .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }
        
        // Pulsing animation
        if showBackground {
            withAnimation(
                Animation.easeInOut(duration: 1.0 / animationSpeed)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.2
                pulseOpacity = 0.9
            }
        }
    }
}

// Simple loading view (alternative name)
struct SimpleLoadingView: View {
    let size: CGFloat
    let color: Color
    
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "gear")
            .font(.system(size: size))
            .foregroundColor(color)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

// Loading overlay for modals/dialogs
struct LoadingOverlay: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                // Loading content
                VStack(spacing: 20) {
                    LoadingLogoView(size: 80)
                    
                    if !message.isEmpty {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                )
                .shadow(radius: 10)
            }
            .transition(.opacity)
        }
    }
}

// Progress loading view
struct ProgressLoadingView: View {
    let progress: Double // 0.0 to 1.0
    let size: CGFloat
    let showPercentage: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: size, height: size)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                
                // Gear icon
                Image(systemName: "gear")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(360 * progress))
            }
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
    }
}

// Preview provider
struct LoadingLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            LoadingLogoView(size: 60)
                .frame(width: 100, height: 100)
            
            SimpleLoadingView(size: 30, color: .blue)
            
            ProgressLoadingView(progress: 0.75, size: 80, showPercentage: true)
                .frame(width: 100, height: 100)
            
            LoadingOverlay(message: "Loading...", isVisible: true)
                .frame(width: 300, height: 200)
        }
        .padding()
    }
}