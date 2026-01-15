import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var hasFullDiskAccess = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isLoading = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Drive Management
            DriveManagementView()
                .tabItem {
                    Label("Drives", systemImage: "externaldrive")
                }
                .tag(0)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Dark mode aware interactive logo
                            InteractiveLogoView(size: 24, useDarkMode: true)
                            
                            Text("Drive Management")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 2: System Information
            SystemInfoView()
                .tabItem {
                    Label("System", systemImage: "desktopcomputer")
                }
                .tag(1)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Pulsing animated logo
                            AnimatedLogoView(
                                size: 24,
                                animationType: .pulse,
                                duration: 3.0,
                                useDarkMode: true
                            )
                            
                            Text("System Information")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 3: Kexts Manager
            KextsManagerView()
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece")
                }
                .tag(2)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Dark mode logo with text
                            DarkModeLogoView(size: 24, showText: false)
                            
                            Text("Kexts Manager")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 4: Audio Tools
            AudioToolsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .tag(3)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Glowing animated logo for audio
                            AnimatedLogoView(
                                size: 24,
                                animationType: .glow,
                                duration: 2.5,
                                useDarkMode: true
                            )
                            
                            Text("Audio Tools")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 5: SSDT Generator
            SSDTGeneratorView(
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage
            )
                .tabItem {
                    Label("SSDT", systemImage: "gear")
                }
                .tag(4)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Rotating animated logo for generator
                            AnimatedLogoView(
                                size: 24,
                                animationType: .rotate,
                                duration: 4.0,
                                useDarkMode: true
                            )
                            
                            Text("SSDT Generator")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 6: Info/About
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(5)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            // Enhanced interactive logo with menu
                            EnhancedLogoView(size: 26)
                            
                            Text("About SYSM")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showAlert(title: "About System Maintenance",
                                     message: "Version 1.0.0\n\nA comprehensive system maintenance tool for macOS.\n\nPowered by SYSM")
                        }) {
                            Image(systemName: "info.circle")
                        }
                        .help("About SYSM")
                    }
                }
            
            // Tab 7: Logo Animation Gallery (Optional - remove in production)
            LogoAnimationGallery()
                .tabItem {
                    Label("Logo Test", systemImage: "star")
                }
                .tag(6)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .overlay {
            // Global loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        LoadingLogoView(size: 80)
                        
                        Text("Processing...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                }
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        isLoading = true
        
        // Simulate permission check delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let hasAccess = ShellHelper.checkFullDiskAccess()
            hasFullDiskAccess = hasAccess
            
            if !hasAccess {
                showAlert(title: "Permissions Info",
                         message: "Full Disk Access is recommended for full functionality. Grant access in System Settings > Privacy & Security > Full Disk Access.")
            }
            
            isLoading = false
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Dark Mode Logo View
struct DarkModeLogoView: View {
    @Environment(\.colorScheme) var colorScheme
    var size: CGFloat = 30
    var showText: Bool = true
    var text: String = "SYSM"
    var cornerRadius: CGFloat = 8
    var animated: Bool = false
    var animationType: AnimatedLogoView.AnimationType = .pulse
    
    var body: some View {
        HStack(spacing: 10) {
            if animated {
                AnimatedLogoView(
                    size: size,
                    animationType: animationType,
                    duration: 3.0,
                    useDarkMode: true
                )
            } else {
                Image(colorScheme == .dark ? "SYSMLogoDark" : "SYSMLogo")
                    .resizable()
                    .frame(width: size, height: size)
                    .cornerRadius(cornerRadius)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            }
            
            if showText {
                Text(text)
                    .font(.system(size: size * 0.7, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Animated Logo View
struct AnimatedLogoView: View {
    var size: CGFloat = 40
    var animationType: AnimationType = .pulse
    var duration: Double = 2.0
    var animated: Bool = true
    var useDarkMode: Bool = false
    
    enum AnimationType {
        case pulse, rotate, bounce, glow, shake, float
    }
    
    // Animation states
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0
    @State private var shadowRadius: CGFloat = 2
    @Environment(\.colorScheme) var colorScheme
    
    var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
    
    var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            // Apply animations
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(y: offset)
            .shadow(color: .blue.opacity(0.5), radius: shadowRadius + glowIntensity)
            .onAppear {
                if animated {
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        switch animationType {
        case .pulse:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
            
        case .rotate:
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
        case .bounce:
            withAnimation(.easeInOut(duration: duration/2).repeatForever(autoreverses: true)) {
                offset = -8
            }
            
        case .glow:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                glowIntensity = 8
                shadowRadius = 6
            }
            
        case .shake:
            let animation = Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)
            withAnimation(animation) {
                rotation = 8
            }
            
        case .float:
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                offset = -12
                scale = 1.08
            }
        }
    }
}

// MARK: - Loading Logo Animation
struct LoadingLogoView: View {
    var size: CGFloat = 80
    var isLoading: Bool = true
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) var colorScheme
    
    var logoName: String {
        colorScheme == .dark ? "SYSMLogoDark" : "SYSMLogo"
    }
    
    var body: some View {
        ZStack {
            // Animated ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size + 30, height: size + 30)
                .rotationEffect(.degrees(rotation))
            
            // Logo
            Image(logoName)
                .resizable()
                .frame(width: size, height: size)
                .cornerRadius(size * 0.2)
        }
        .onAppear {
            if isLoading {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Interactive Logo with Hover Effects
struct InteractiveLogoView: View {
    var size: CGFloat = 40
    var useDarkMode: Bool = true
    @State private var isHovering = false
    @State private var isClicked = false
    @Environment(\.colorScheme) var colorScheme
    
    var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
    
    var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            .scaleEffect(isClicked ? 0.9 : (isHovering ? 1.1 : 1.0))
            .shadow(
                color: .blue.opacity(isHovering ? 0.5 : 0.2),
                radius: isHovering ? 10 : 4,
                x: 0,
                y: isHovering ? 5 : 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
            .animation(.easeInOut(duration: 0.1), value: isClicked)
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isClicked = true
                    }
                    .onEnded { _ in
                        isClicked = false
                        // Haptic feedback on click
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                    }
            )
    }
}

// MARK: - Enhanced Logo with Menu
struct EnhancedLogoView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showMenu = false
    var size: CGFloat = 32
    
    var body: some View {
        Menu {
            Button("Copy Logo Info") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("SYSM Logo - System Maintenance", forType: .string)
            }
            
            Button("About SYSM") {
                // This would need to be handled by parent view
                // Could use a notification or binding
            }
            
            Divider()
            
            Button("Refresh") {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
        } label: {
            InteractiveLogoView(size: size, useDarkMode: true)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

// MARK: - Logo Animation Gallery
struct LogoAnimationGallery: View {
    @State private var selectedAnimation = 0
    @State private var logoSize: CGFloat = 60
    @State private var animationSpeed: Double = 2.0
    @State private var useDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    
    let animations = [
        ("Pulse", AnimatedLogoView.AnimationType.pulse),
        ("Rotate", AnimatedLogoView.AnimationType.rotate),
        ("Bounce", AnimatedLogoView.AnimationType.bounce),
        ("Glow", AnimatedLogoView.AnimationType.glow),
        ("Shake", AnimatedLogoView.AnimationType.shake),
        ("Float", AnimatedLogoView.AnimationType.float)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("SYSM Logo Animation Gallery")
                    .font(.largeTitle)
                    .padding(.top)
                
                // Controls
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
                
                // Preview
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
                
                // All animations grid
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
                
                // Interactive demo
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
                
                // Loading animation
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.light)
        
        ContentView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        
        LogoAnimationGallery()
            .previewDisplayName("Logo Gallery")
    }
}