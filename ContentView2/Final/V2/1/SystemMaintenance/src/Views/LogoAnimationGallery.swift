import SwiftUI

struct LogoAnimationGallery: View {
    @State private var selectedAnimationIndex = 0
    @State private var animationSpeed = 1.0
    @State private var animationIntensity = 10.0
    @State private var useDarkMode = false
    @State private var showControls = true
    
    private let animationTypes = [
        "Shake", "Rotate", "Pulse", "Earthquake", 
        "Interactive", "Dark Mode", "Enhanced", "Loading"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                headerSection
                
                // Controls
                if showControls {
                    controlsSection
                }
                
                // Animation Gallery
                animationGallerySection
                
                // Information
                informationSection
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 1000, minHeight: 800)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Logo Animation Gallery")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("Preview and test all logo animation types")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Toggle("Show Controls", isOn: $showControls)
                .toggleStyle(.switch)
                .padding(.top, 5)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 15) {
            Text("Animation Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Animation Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Animation Type", selection: $selectedAnimationIndex) {
                        ForEach(0..<animationTypes.count, id: \.self) { index in
                            Text(animationTypes[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speed: \(String(format: "%.1f", animationSpeed))x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $animationSpeed, in: 0.5...3.0, step: 0.1)
                        .frame(width: 200)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Intensity: \(String(format: "%.0f", animationIntensity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $animationIntensity, in: 1...30, step: 1)
                        .frame(width: 200)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Dark Mode", isOn: $useDarkMode)
                        .toggleStyle(.switch)
                        .frame(width: 100)
                }
            }
            
            HStack(spacing: 12) {
                Button("Reset All") {
                    resetAnimations()
                }
                .buttonStyle(.bordered)
                
                Button("Test All Animations") {
                    testAllAnimations()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Export Animation") {
                    exportAnimation()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Animation Gallery Section
    private var animationGallerySection: some View {
        VStack(spacing: 20) {
            Text("Preview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Selected Animation Preview
            VStack(spacing: 15) {
                Text("Current: \(animationTypes[selectedAnimationIndex])")
                    .font(.title2)
                    .fontWeight(.medium)
                
                selectedAnimationView
                    .frame(width: 200, height: 200)
                    .padding(30)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                
                Text(animationDescription(for: selectedAnimationIndex))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(15)
            
            // All Animations Grid
            Text("All Animations")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(0..<animationTypes.count, id: \.self) { index in
                    animationCell(for: index)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Selected Animation View
    private var selectedAnimationView: some View {
        Group {
            switch selectedAnimationIndex {
            case 0: // Shake
                ShakeLogoView(
                    size: 100,
                    intensity: animationIntensity,
                    speed: 2.0 / animationSpeed,
                    useDarkMode: useDarkMode
                )
            case 1: // Rotate
                AnimatedLogoView(
                    size: 100,
                    animationType: .rotate,
                    duration: 4.0 / animationSpeed,
                    useDarkMode: useDarkMode
                )
            case 2: // Pulse
                AnimatedLogoView(
                    size: 100,
                    animationType: .pulse,
                    duration: 2.0 / animationSpeed,
                    useDarkMode: useDarkMode
                )
            case 3: // Earthquake
                EarthquakeLogoView(
                    size: 100,
                    intensity: animationIntensity,
                    useDarkMode: useDarkMode
                )
            case 4: // Interactive
                InteractiveLogoView(
                    size: 100,
                    useDarkMode: useDarkMode
                )
            case 5: // Dark Mode
                DarkModeLogoView(
                    size: 100,
                    showText: false
                )
            case 6: // Enhanced
                EnhancedLogoView(size: 100)
            case 7: // Loading
                LoadingLogoView(size: 100)
            default:
                Image("SYSMLogo")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Animation Cell
    private func animationCell(for index: Int) -> some View {
        VStack(spacing: 8) {
            // Preview
            Group {
                switch index {
                case 0: // Shake
                    ShakeLogoView(
                        size: 60,
                        intensity: 8,
                        speed: 1.0,
                        useDarkMode: useDarkMode
                    )
                case 1: // Rotate
                    AnimatedLogoView(
                        size: 60,
                        animationType: .rotate,
                        duration: 3.0,
                        useDarkMode: useDarkMode
                    )
                case 2: // Pulse
                    AnimatedLogoView(
                        size: 60,
                        animationType: .pulse,
                        duration: 1.5,
                        useDarkMode: useDarkMode
                    )
                case 3: // Earthquake
                    EarthquakeLogoView(
                        size: 60,
                        intensity: 8,
                        useDarkMode: useDarkMode
                    )
                case 4: // Interactive
                    InteractiveLogoView(
                        size: 60,
                        useDarkMode: useDarkMode
                    )
                case 5: // Dark Mode
                    DarkModeLogoView(
                        size: 60,
                        showText: false
                    )
                case 6: // Enhanced
                    EnhancedLogoView(size: 60)
                case 7: // Loading
                    LoadingLogoView(size: 60)
                default:
                    Image("SYSMLogo")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.textBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedAnimationIndex == index ? Color.blue : Color.clear, lineWidth: 3)
            )
            
            // Label
            Text(animationTypes[index])
                .font(.caption)
                .foregroundColor(selectedAnimationIndex == index ? .blue : .primary)
            
            // Select Button
            Button("Select") {
                selectedAnimationIndex = index
            }
            .buttonStyle(.borderless)
            .font(.caption2)
            .foregroundColor(.blue)
        }
        .padding(8)
        .background(selectedAnimationIndex == index ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(10)
    }
    
    // MARK: - Information Section
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Shake:", description: "Random directional shaking effect")
                InfoRow(title: "Rotate:", description: "Continuous 360° rotation")
                InfoRow(title: "Pulse:", description: "Rhythmic scaling animation")
                InfoRow(title: "Earthquake:", description: "Intense random shaking")
                InfoRow(title: "Interactive:", description: "Hover-sensitive scaling")
                InfoRow(title: "Dark Mode:", description: "Theme-adaptive appearance")
                InfoRow(title: "Enhanced:", description: "Combined rotation and scaling")
                InfoRow(title: "Loading:", description: "Continuous rotation for loading states")
            }
            
            Divider()
            
            HStack {
                Text("Usage Tip:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Animations are used throughout the app for visual feedback and branding.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    private func animationDescription(for index: Int) -> String {
        switch index {
        case 0: return "Shaking animation with adjustable intensity. Good for attention-grabbing or error states."
        case 1: return "Continuous 360° rotation. Useful for loading or processing indicators."
        case 2: return "Pulsing scale animation. Creates a breathing effect for subtle animations."
        case 3: return "Random earthquake-like shaking. Great for dramatic effects or troubleshooting."
        case 4: return "Interactive hover animation. Scales up when mouse is over the element."
        case 5: return "Dark mode optimized. Automatically adjusts for light/dark themes."
        case 6: return "Enhanced animation combining rotation and scaling with shadow effects."
        case 7: return "Loading spinner animation. Shows continuous activity."
        default: return "Standard logo display."
        }
    }
    
    private func resetAnimations() {
        animationSpeed = 1.0
        animationIntensity = 10.0
        selectedAnimationIndex = 0
        useDarkMode = false
    }
    
    private func testAllAnimations() {
        // Cycle through all animations
        for i in 0..<animationTypes.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                withAnimation {
                    selectedAnimationIndex = i
                }
            }
        }
        
        // Return to first after cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(animationTypes.count) * 0.5) {
            withAnimation {
                selectedAnimationIndex = 0
            }
        }
    }
    
    private func exportAnimation() {
        // In a real app, this would export the animation settings or capture a video
        let alert = NSAlert()
        alert.messageText = "Export Animation"
        alert.informativeText = "Animation settings have been copied to clipboard.\n\nType: \(animationTypes[selectedAnimationIndex])\nSpeed: \(String(format: "%.1f", animationSpeed))x\nIntensity: \(String(format: "%.0f", animationIntensity))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Copy to clipboard
        let settings = """
        SYSM Logo Animation Settings:
        Type: \(animationTypes[selectedAnimationIndex])
        Speed: \(String(format: "%.1f", animationSpeed))x
        Intensity: \(String(format: "%.0f", animationIntensity))
        Dark Mode: \(useDarkMode ? "Yes" : "No")
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(settings, forType: .string)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview
struct LogoAnimationGallery_Previews: PreviewProvider {
    static var previews: some View {
        LogoAnimationGallery()
            .frame(width: 1000, height: 800)
            .preferredColorScheme(.light)
        
        LogoAnimationGallery()
            .frame(width: 1000, height: 800)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}