cat > LogoAnimationGallery.swift << 'EOF'
import SwiftUI

public struct LogoAnimationGallery: View {
    @State private var selectedAnimation = 0
    @State private var logoSize: CGFloat = 60
    @State private var animationSpeed: Double = 2.0
    @State private var useDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    
    let animations = [
        ("Pulse", LogoAnimationType.pulse),
        ("Rotate", LogoAnimationType.rotate),
        ("Bounce", LogoAnimationType.bounce),
        ("Glow", LogoAnimationType.glow),
        ("Shake", LogoAnimationType.shake),
        ("Float", LogoAnimationType.float)
    ]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("SYSM Logo Animation Gallery")
                    .font(.largeTitle)
                    .padding(.top)
                
                GroupBox("Settings") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Size: \(Int(logoSize))px")
                            Slider(value: $logoSize, in: 20...120)
                        }
                        
                        HStack {
                            Text("Speed: \(String(format: "%.1f", animationSpeed))s")
                            Slider(value: $animationSpeed, in: 0.5...5.0)
                        }
                        
                        Toggle("Use Dark Mode Variant", isOn: $useDarkMode)
                        
                        Picker("Animation Type", selection: $selectedAnimation) {
                            ForEach(0..<animations.count, id: \.self) { index in
                                Text(animations[index].0).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                }
                .frame(width: 500)
                
                GroupBox("Preview") {
                    VStack {
                        AnimatedLogoView(
                            size: logoSize,
                            animationType: animations[selectedAnimation].1,
                            duration: animationSpeed,
                            useDarkMode: useDarkMode
                        )
                        
                        Text(animations[selectedAnimation].0)
                            .font(.title2)
                            .padding(.top, 10)
                        
                        Text("Using: \(useDarkMode && colorScheme == .dark ? "Dark Logo" : "Light Logo")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                }
                
                GroupBox("All Animations") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(0..<animations.count, id: \.self) { index in
                            VStack {
                                AnimatedLogoView(
                                    size: 50,
                                    animationType: animations[index].1,
                                    duration: 2.0,
                                    useDarkMode: useDarkMode
                                )
                                
                                Text(animations[index].0)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                GroupBox("Interactive Demo") {
                    VStack {
                        InteractiveLogoView(size: 80, useDarkMode: useDarkMode)
                        Text("Hover or click me!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                    .padding(30)
                }
                
                GroupBox("Loading Animation") {
                    VStack {
                        LoadingLogoView(size: 70)
                        Text("Loading state")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                    .padding(30)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 800)
    }
}
EOF