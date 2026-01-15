import SwiftUI

struct LogoAnimationGallery: View {
    @State private var selectedAnimation: AnimationType = .pulse
    @State private var isAnimating = false
    @State private var animationSpeed = 1.0
    
    // Animation type enum for this view only
    enum AnimationType: Int, CaseIterable {
        case pulse = 0
        case rotate = 1
        case bounce = 2
        case fade = 3
        case scale = 4
        
        var title: String {
            switch self {
            case .pulse: return "Pulse"
            case .rotate: return "Rotate"
            case .bounce: return "Bounce"
            case .fade: return "Fade"
            case .scale: return "Scale"
            }
        }
        
        var description: String {
            switch self {
            case .pulse:
                return "Pulse animation: The logo gently pulses in and out, creating a breathing effect."
            case .rotate:
                return "Rotate animation: The logo continuously rotates 360 degrees."
            case .bounce:
                return "Bounce animation: The logo bounces up and down with spring physics."
            case .fade:
                return "Fade animation: The logo fades in and out smoothly."
            case .scale:
                return "Scale animation: The logo scales up and down rhythmically."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Logo Animation Gallery")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            Picker("Animation Type", selection: $selectedAnimation) {
                ForEach(AnimationType.allCases, id: \.self) { animationType in
                    Text(animationType.title).tag(animationType)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Animation Preview
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 200)
                
                // Animated Logo using the LogoView from LogoViews.swift
                LogoView(
                    animation: convertToLogoViewAnimation(selectedAnimation),
                    isAnimating: isAnimating,
                    size: 100,
                    color: .blue
                )
            }
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 15) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5 / animationSpeed)) {
                        isAnimating.toggle()
                    }
                }) {
                    Text(isAnimating ? "Stop Animation" : "Start Animation")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAnimating ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Animation Speed: \(String(format: "%.1f", animationSpeed))x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $animationSpeed, in: 0.5...3.0, step: 0.1)
                        .accentColor(.blue)
                }
                .padding(.horizontal)
            }
            
            // Animation Descriptions
            VStack(alignment: .leading, spacing: 10) {
                Text("Animation Details")
                    .font(.headline)
                
                Text(selectedAnimation.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Additional Animation Options
            VStack(spacing: 15) {
                Text("Animation Presets")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AnimationType.allCases, id: \.self) { animationType in
                            Button(action: {
                                withAnimation {
                                    selectedAnimation = animationType
                                }
                            }) {
                                Text(animationType.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(selectedAnimation == animationType ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAnimation == animationType ? .white : .primary)
                                    .cornerRadius(15)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .navigationTitle("Logo Animations")
        .onDisappear {
            // Stop animation when view disappears
            isAnimating = false
        }
    }
    
    // Helper function to convert AnimationType to LogoView.AnimationType
    private func convertToLogoViewAnimation(_ type: AnimationType) -> LogoView.AnimationType {
        switch type {
        case .pulse: return .pulse
        case .rotate: return .rotate
        case .bounce: return .bounce
        case .fade: return .fade
        case .scale: return .scale
        }
    }
}

struct LogoAnimationGallery_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogoAnimationGallery()
        }
    }
}