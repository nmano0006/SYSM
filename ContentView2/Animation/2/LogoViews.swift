import SwiftUI

// Main LogoView
struct LogoView: View {
    enum AnimationType {
        case pulse, rotate, bounce, fade, scale, none
    }
    
    let animation: AnimationType
    let isAnimating: Bool
    let size: CGFloat
    let color: Color
    let symbol: String
    
    init(animation: AnimationType = .none, 
         isAnimating: Bool = false,
         size: CGFloat = 100,
         color: Color = .blue,
         symbol: String = "cpu.fill") {
        self.animation = animation
        self.isAnimating = isAnimating
        self.size = size
        self.color = color
        self.symbol = symbol
    }
    
    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
            .modifier(LogoAnimationModifier(
                animation: animation,
                isAnimating: isAnimating
            ))
    }
}

// Animation Modifier for LogoView
struct LogoAnimationModifier: ViewModifier {
    let animation: LogoView.AnimationType
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        Group {
            switch animation {
            case .pulse:
                content
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        isAnimating ?
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                        .default,
                        value: isAnimating
                    )
            case .rotate:
                content
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        isAnimating ?
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false) :
                        .default,
                        value: isAnimating
                    )
            case .bounce:
                content
                    .offset(y: isAnimating ? -15 : 0)
                    .animation(
                        isAnimating ?
                        Animation.spring(response: 0.5, dampingFraction: 0.3).repeatForever(autoreverses: true) :
                        .default,
                        value: isAnimating
                    )
            case .fade:
                content
                    .opacity(isAnimating ? 0.3 : 1.0)
                    .animation(
                        isAnimating ?
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        .default,
                        value: isAnimating
                    )
            case .scale:
                content
                    .scaleEffect(isAnimating ? 0.7 : 1.3)
                    .animation(
                        isAnimating ?
                        Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                        .default,
                        value: isAnimating
                    )
            case .none:
                content
            }
        }
    }
}

// Different Logo Styles
struct ModernLogoView: View {
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
            
            Image(systemName: "cpu.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.6, height: size * 0.6)
                .foregroundColor(color)
        }
    }
}

struct MinimalLogoView: View {
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Image(systemName: "cpu")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

struct GradientLogoView: View {
    let size: CGFloat
    let colors: [Color]
    
    var body: some View {
        Image(systemName: "cpu.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
    }
}

// Logo Gallery View
struct LogoGalleryView: View {
    @State private var selectedLogo = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Logo Gallery")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Standard Logo
                VStack(spacing: 10) {
                    Text("Standard Logo")
                        .font(.headline)
                    
                    LogoView(
                        animation: .pulse,
                        isAnimating: true,
                        size: 120,
                        color: .blue
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(15)
                
                // Modern Logo
                VStack(spacing: 10) {
                    Text("Modern Logo")
                        .font(.headline)
                    
                    ModernLogoView(size: 120, color: .purple)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(15)
                
                // Minimal Logo
                VStack(spacing: 10) {
                    Text("Minimal Logo")
                        .font(.headline)
                    
                    MinimalLogoView(size: 120, color: .green)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(15)
                
                // Gradient Logo
                VStack(spacing: 10) {
                    Text("Gradient Logo")
                        .font(.headline)
                    
                    GradientLogoView(
                        size: 120,
                        colors: [.blue, .purple, .pink]
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(15)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Logo Gallery")
    }
}

// Preview Provider
struct LogoViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LogoView(animation: .pulse, isAnimating: true)
            LogoView(animation: .rotate, isAnimating: true)
            LogoView(animation: .bounce, isAnimating: true)
        }
        .padding()
    }
}