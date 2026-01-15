// Views/LogoAnimationGallery.swift
import SwiftUI

struct LogoAnimationGallery: View {
    @State private var selectedAnimation = 0
    @State private var animationSpeed = 0.5
    @State private var isAnimating = false
    @State private var showInfo = false
    
    let animations = [
        LogoAnimationInfo(
            name: "Spinning Gear",
            description: "Classic loading spinner with gear icon",
            type: .spinning
        ),
        LogoAnimationInfo(
            name: "Pulsing Circle",
            description: "Pulsating circle with gradient effect",
            type: .pulsing
        ),
        LogoAnimationInfo(
            name: "Wave Animation",
            description: "Wave-like animation for loading states",
            type: .wave
        ),
        LogoAnimationInfo(
            name: "Bounce Effect",
            description: "Bouncing animation with shadow",
            type: .bounce
        )
    ]
    
    struct LogoAnimationInfo {
        let name: String
        let description: String
        let type: AnimationType
        
        enum AnimationType {
            case spinning, pulsing, wave, bounce
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Logo Animations")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo, arrowEdge: .top) {
                    AnimationInfoView()
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Animation Preview
            VStack(spacing: 30) {
                // Animation display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 300)
                    
                    switch animations[selectedAnimation].type {
                    case .spinning:
                        SpinningGearView(size: 120, isAnimating: isAnimating, speed: animationSpeed)
                    case .pulsing:
                        PulsingCircleView(size: 120, isAnimating: isAnimating, speed: animationSpeed)
                    case .wave:
                        WaveAnimationView(size: 120, isAnimating: isAnimating, speed: animationSpeed)
                    case .bounce:
                        BounceAnimationView(size: 120, isAnimating: isAnimating, speed: animationSpeed)
                    }
                }
                .padding(.horizontal)
                
                // Controls
                VStack(spacing: 20) {
                    // Animation selection
                    HStack {
                        Text("Animation:")
                            .font(.headline)
                        
                        Picker("Animation", selection: $selectedAnimation) {
                            ForEach(0..<animations.count, id: \.self) { index in
                                Text(animations[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Speed control
                    HStack {
                        Text("Speed:")
                            .font(.headline)
                        
                        Slider(value: $animationSpeed, in: 0.1...2.0)
                        
                        Text(String(format: "%.1fx", animationSpeed))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 40)
                    }
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            isAnimating.toggle()
                        }) {
                            HStack {
                                Image(systemName: isAnimating ? "pause.circle" : "play.circle")
                                Text(isAnimating ? "Pause" : "Play")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Reset") {
                            isAnimating = false
                            animationSpeed = 0.5
                        }
                        .frame(width: 120)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 40)
                
                // Animation info
                VStack(alignment: .leading, spacing: 10) {
                    DetailRow(title: "Name:", value: animations[selectedAnimation].name)
                    DetailRow(title: "Description:", value: animations[selectedAnimation].description)
                    DetailRow(title: "Status:", value: isAnimating ? "Playing" : "Paused")
                    DetailRow(title: "Speed:", value: String(format: "%.1fx", animationSpeed))
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .frame(minWidth: 600, minHeight: 600)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Detail Row (replaces InfoRow)
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Animation Info View
struct AnimationInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Animation Gallery Info")
                .font(.headline)
            
            Text("This gallery showcases different loading animations that can be used throughout the app. Each animation has unique characteristics:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Spinning Gear:", value: "Traditional loading indicator")
                DetailRow(title: "Pulsing Circle:", value: "Modern pulsing effect")
                DetailRow(title: "Wave Animation:", value: "Smooth wave-like motion")
                DetailRow(title: "Bounce Effect:", value: "Playful bouncing animation")
            }
            
            Text("Adjust speed and play/pause to preview animations.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Animation Views
struct SpinningGearView: View {
    let size: CGFloat
    let isAnimating: Bool
    let speed: Double
    
    var body: some View {
        Image(systemName: "gear")
            .font(.system(size: size))
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                isAnimating ?
                    Animation.linear(duration: 2.0 / speed)
                        .repeatForever(autoreverses: false) :
                    .default,
                value: isAnimating
            )
    }
}

struct PulsingCircleView: View {
    let size: CGFloat
    let isAnimating: Bool
    let speed: Double
    
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [.blue, .blue.opacity(0.3)]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size/2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .onChange(of: isAnimating) {
                if isAnimating {
                    withAnimation(
                        Animation.easeInOut(duration: 1.0 / speed)
                            .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.2
                    }
                } else {
                    scale = 0.8
                }
            }
    }
}

struct WaveAnimationView: View {
    let size: CGFloat
    let isAnimating: Bool
    let speed: Double
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: 12, height: size)
                    .scaleEffect(y: isAnimating ? 0.3 : 1.0)
                    .animation(
                        isAnimating ?
                            Animation.easeInOut(duration: 0.6 / speed)
                                .repeatForever()
                                .delay(Double(index) * 0.2) :
                            .default,
                        value: isAnimating
                    )
            }
        }
    }
}

struct BounceAnimationView: View {
    let size: CGFloat
    let isAnimating: Bool
    let speed: Double
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: size, height: size)
            .shadow(color: .blue.opacity(0.5), radius: 10, y: 5)
            .offset(y: isAnimating ? -20 : 0)
            .animation(
                isAnimating ?
                    Animation.easeInOut(duration: 0.8 / speed)
                        .repeatForever(autoreverses: true) :
                    .default,
                value: isAnimating
            )
    }
}

struct LogoAnimationGallery_Previews: PreviewProvider {
    static var previews: some View {
        LogoAnimationGallery()
    }
}