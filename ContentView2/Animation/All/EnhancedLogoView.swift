import SwiftUI

// MARK: - Main Enhanced Logo View
struct EnhancedLogoView: View {
    enum LogoType {
        case standard
        case interactive
        case animated(AnimationType)
        case shake(intensity: Double = 10, speed: Double = 0.1)
        case earthquake(intensity: Double = 15)
        case loading
        case darkMode
    }
    
    enum AnimationType {
        case rotate
        case pulse
        case bounce
        case shake
    }
    
    let size: CGFloat
    let type: LogoType
    let useDarkMode: Bool
    let showText: Bool
    
    init(size: CGFloat = 64, 
         type: LogoType = .standard,
         useDarkMode: Bool = false,
         showText: Bool = true) {
        self.size = size
        self.type = type
        self.useDarkMode = useDarkMode
        self.showText = showText
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Logo Image
            logoImage
            
            // Optional Text
            if showText {
                Text("SYSM")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(useDarkMode ? .white : .primary)
                    .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 2)
            }
        }
        .frame(width: size, height: size)
    }
    
    @ViewBuilder
    private var logoImage: some View {
        Group {
            switch type {
            case .standard:
                standardLogo
            case .interactive:
                InteractiveLogoView(size: size, useDarkMode: useDarkMode)
            case .animated(let animationType):
                AnimatedLogoView(size: size, animationType: animationType, duration: 2.0, useDarkMode: useDarkMode)
            case .shake(let intensity, let speed):
                ShakeLogoView(size: size, intensity: intensity, speed: speed, useDarkMode: useDarkMode)
            case .earthquake(let intensity):
                EarthquakeLogoView(size: size, intensity: intensity, useDarkMode: useDarkMode)
            case .loading:
                LoadingLogoView(size: size)
            case .darkMode:
                DarkModeLogoView(size: size, showText: false)
            }
        }
    }
    
    private var standardLogo: some View {
        Image("SYSMLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }
}

// MARK: - Interactive Logo View
struct InteractiveLogoView: View {
    let size: CGFloat
    let useDarkMode: Bool
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Image("SYSMLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .shadow(color: isHovered ? .blue.opacity(0.5) : .blue.opacity(0.3), 
                   radius: isHovered ? 8 : 5, 
                   x: 0, y: isHovered ? 5 : 3)
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .rotationEffect(.degrees(isHovered ? rotationAngle : 0))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .stroke(
                        LinearGradient(
                            colors: isHovered ? 
                                [.blue, .purple] : 
                                [.blue.opacity(0.5), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 3 : 2
                    )
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isHovered = hovering
                }
                if hovering {
                    startRotation()
                } else {
                    rotationAngle = 0
                }
            }
            .pressEvents {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = true
                }
            } onRelease: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
    }
    
    private func startRotation() {
        let baseSpeed: Double = 0.5
        withAnimation(.linear(duration: 1.0 / baseSpeed).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

// MARK: - Animated Logo View
struct AnimatedLogoView: View {
    enum AnimationType {
        case rotate
        case pulse
        case bounce
        case shake
    }
    
    let size: CGFloat
    let animationType: AnimationType
    let duration: Double
    let useDarkMode: Bool
    @State private var isAnimating = false
    
    var body: some View {
        Image("SYSMLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            .modifier(AnimationModifier(
                type: animationType,
                isAnimating: isAnimating,
                duration: duration
            ))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isAnimating = true
                }
            }
    }
}

struct AnimationModifier: ViewModifier {
    let type: AnimatedLogoView.AnimationType
    let isAnimating: Bool
    let duration: Double
    
    func body(content: Content) -> some View {
        switch type {
        case .rotate:
            content
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(isAnimating ? 
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false) : .default,
                    value: isAnimating)
        case .pulse:
            content
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(isAnimating ? 
                    Animation.easeInOut(duration: duration)
                        .repeatForever(autoreverses: true) : .default,
                    value: isAnimating)
        case .bounce:
            content
                .offset(y: isAnimating ? -10 : 0)
                .animation(isAnimating ? 
                    Animation.easeInOut(duration: duration)
                        .repeatForever(autoreverses: true) : .default,
                    value: isAnimating)
        case .shake:
            content
                .offset(x: isAnimating ? 5 : -5)
                .animation(isAnimating ? 
                    Animation.easeInOut(duration: duration / 2)
                        .repeatForever(autoreverses: true) : .default,
                    value: isAnimating)
        }
    }
}

// MARK: - Shake Logo View
struct ShakeLogoView: View {
    let size: CGFloat
    let intensity: Double
    let speed: Double
    let useDarkMode: Bool
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        Image("SYSMLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .shadow(color: .orange.opacity(0.4), radius: 5, x: 0, y: 3)
            .offset(x: shakeOffset)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .onAppear {
                startShaking()
            }
    }
    
    private func startShaking() {
        let timer = Timer.publish(every: speed, on: .main, in: .common).autoconnect()
        
        DispatchQueue.main.async {
            var currentOffset: CGFloat = 0
            var direction: CGFloat = 1
            
            _ = timer.sink { _ in
                withAnimation(.linear(duration: speed)) {
                    currentOffset += intensity * direction
                    shakeOffset = currentOffset
                    
                    if abs(currentOffset) > intensity * 2 {
                        direction *= -1
                    }
                }
            }
        }
    }
}

// MARK: - Earthquake Logo View
struct EarthquakeLogoView: View {
    let size: CGFloat
    let intensity: Double
    let useDarkMode: Bool
    @State private var quakeOffset = CGSize.zero
    
    var body: some View {
        Image("SYSMLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.2)
            .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
            .offset(quakeOffset)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .stroke(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            .onAppear {
                startEarthquake()
            }
    }
    
    private func startEarthquake() {
        let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
        
        DispatchQueue.main.async {
            _ = timer.sink { _ in
                withAnimation(.linear(duration: 0.05)) {
                    let randomX = CGFloat.random(in: -intensity...intensity)
                    let randomY = CGFloat.random(in: -intensity...intensity)
                    quakeOffset = CGSize(width: randomX, height: randomY)
                }
            }
        }
    }
}

// MARK: - Loading Logo View
struct LoadingLogoView: View {
    let size: CGFloat
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
            
            // Outer rotating ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .blue]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size * 1.1, height: size * 1.1)
                .rotationEffect(.degrees(rotationAngle))
            
            // Logo in center
            Image("SYSMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
                .cornerRadius(size * 0.14)
                .scaleEffect(scale)
                .shadow(color: .blue.opacity(0.5), radius: 5, x: 0, y: 3)
        }
        .onAppear {
            // Start rotation animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            // Start pulsing animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}

// MARK: - Dark Mode Logo View
struct DarkModeLogoView: View {
    let size: CGFloat
    let showText: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image("SYSMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .cornerRadius(size * 0.2)
                .shadow(color: colorScheme == .dark ? .blue.opacity(0.5) : .gray.opacity(0.5),
                       radius: colorScheme == .dark ? 8 : 5,
                       x: 0, y: colorScheme == .dark ? 4 : 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(
                            colorScheme == .dark ? 
                                LinearGradient(
                                    colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: 2
                        )
                )
                .brightness(colorScheme == .dark ? 0.1 : 0)
                .saturation(colorScheme == .dark ? 1.2 : 1.0)
            
            if showText {
                Text("SYSM")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .shadow(color: colorScheme == .dark ? .blue.opacity(0.5) : .clear,
                           radius: 2, x: 0, y: 2)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Press Events Modifier (for interactive logo)
struct PressEvents: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Previews
struct EnhancedLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // All logo variations
            EnhancedLogoView(size: 60, type: .standard)
            
            EnhancedLogoView(size: 60, type: .interactive)
            
            EnhancedLogoView(size: 60, type: .animated(.rotate))
            
            EnhancedLogoView(size: 60, type: .shake(intensity: 10, speed: 0.1))
            
            EnhancedLogoView(size: 60, type: .earthquake(intensity: 15))
            
            EnhancedLogoView(size: 60, type: .loading)
            
            EnhancedLogoView(size: 60, type: .darkMode)
        }
        .padding()
        .previewLayout(.sizeThatFits)
        
        // Dark mode preview
        VStack(spacing: 20) {
            EnhancedLogoView(size: 60, type: .standard, useDarkMode: true)
            EnhancedLogoView(size: 60, type: .animated(.pulse), useDarkMode: true)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}