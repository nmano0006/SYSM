import SwiftUI

public struct LoadingLogoView: View {
    public var size: CGFloat = 80
    public var isLoading: Bool = true
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) var colorScheme
    
    public init(size: CGFloat = 80, isLoading: Bool = true) {
        self.size = size
        self.isLoading = isLoading
    }
    
    public var body: some View {
        ZStack {
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
    
    private var logoName: String {
        colorScheme == .dark ? "SYSMLogoDark" : "SYSMLogo"
    }
}
