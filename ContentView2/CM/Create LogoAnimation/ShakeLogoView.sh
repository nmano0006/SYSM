cat > ShakeLogoView.swift << 'EOF'
import SwiftUI

public struct ShakeLogoView: View {
    public var size: CGFloat = 40
    public var intensity: Double = 8.0
    public var speed: Double = 0.15
    public var useDarkMode: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    @State private var shakeOffset: CGFloat = 0
    @State private var isShaking = true
    
    public init(size: CGFloat = 40, intensity: Double = 8.0, speed: Double = 0.15, useDarkMode: Bool = true) {
        self.size = size
        self.intensity = intensity
        self.speed = speed
        self.useDarkMode = useDarkMode
    }
    
    public var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            .rotationEffect(.degrees(isShaking ? intensity : 0))
            .offset(x: shakeOffset)
            .onAppear {
                if isShaking {
                    startShakeAnimation()
                }
            }
    }
    
    private var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
    
    private func startShakeAnimation() {
        withAnimation(Animation.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            shakeOffset = size * 0.05
        }
    }
}

public struct EarthquakeLogoView: View {
    public var size: CGFloat = 40
    public var intensity: Double = 15.0
    public var useDarkMode: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    @State private var shakeRotation: Double = 0
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0
    
    public init(size: CGFloat = 40, intensity: Double = 15.0, useDarkMode: Bool = true) {
        self.size = size
        self.intensity = intensity
        self.useDarkMode = useDarkMode
    }
    
    public var body: some View {
        Image(logoName)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(size * 0.15)
            .rotationEffect(.degrees(shakeRotation))
            .offset(x: shakeX, y: shakeY)
            .shadow(color: .red.opacity(0.5), radius: 5)
            .onAppear {
                startEarthquake()
            }
    }
    
    private var logoName: String {
        if useDarkMode && colorScheme == .dark {
            return "SYSMLogoDark"
        }
        return "SYSMLogo"
    }
    
    private func startEarthquake() {
        let animation = Animation.easeInOut(duration: 0.1).repeatForever(autoreverses: true)
        withAnimation(animation) {
            shakeRotation = intensity
            shakeX = size * 0.1
            shakeY = size * 0.05
        }
    }
}
EOF