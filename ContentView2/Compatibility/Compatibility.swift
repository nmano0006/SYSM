//
//  Compatibility.swift
//  System Maintenance Tool
//
//  Created by compatibility layer for macOS 14+ support
//

import SwiftUI

// MARK: - Cross-platform compatibility helpers

@available(macOS, deprecated: 14.0, message: "Use Color.accentColor instead")
extension Color {
    static var compatibleAccentColor: Color {
        if #available(macOS 14.0, *) {
            return .accentColor
        } else {
            return .blue
        }
    }
}

// Safe image loading with fallbacks
struct CompatibleImage {
    static func system(_ name: String) -> Image {
        // Map newer SF Symbols to older ones for compatibility
        let fallbackMap: [String: String] = [
            "externaldrive": "opticaldiscdrive",
            "desktopcomputer": "desktopcomputer",
            "puzzlepiece": "square.grid.3x3.fill",
            "speaker.wave.2": "speaker.2.fill",
            "number.square": "number.circle.fill",
            "wrench.and.screwdriver": "wrench.fill",
            "function": "f.cursive",
            "gearshape.fill": "gear",
            "hammer.fill": "hammer",
            "exclamationmark.triangle.fill": "exclamationmark.triangle",
            "checkmark.circle.fill": "checkmark.circle",
            "xmark.circle.fill": "xmark.circle",
            "memorychip": "memorychip",
            "thermometer": "thermometer",
            "network": "network",
            "info.circle": "info.circle.fill"
        ]
        
        let actualName: String
        if #available(macOS 14.0, *) {
            actualName = name
        } else {
            actualName = fallbackMap[name] ?? "gear"
        }
        
        return Image(systemName: actualName)
    }
}

// MARK: - DriveInfo Model (Enhanced)
struct DriveInfo: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var identifier: String
    var size: String
    var type: String
    var mountPoint: String
    var isInternal: Bool
    var isEFI: Bool
    var partitions: [String]
    var isMounted: Bool
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

// MARK: - Fallback Logo Views
struct FallbackLogoView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
            
            CompatibleImage.system("gearshape.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(.white)
        }
    }
}

struct InteractiveLogoView: View {
    let size: CGFloat
    let useDarkMode: Bool
    
    var body: some View {
        FallbackLogoView(size: size)
    }
}

struct AnimatedLogoView: View {
    let size: CGFloat
    let animationType: AnimationType
    let duration: Double
    let useDarkMode: Bool
    
    enum AnimationType {
        case shake, rotate, none
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        FallbackLogoView(size: size)
            .rotationEffect(.degrees(animationType == .rotate ? (isAnimating ? 360 : 0) : 0))
            .animation(animationType == .rotate ? 
                Animation.linear(duration: duration).repeatForever(autoreverses: false) : 
                .default, value: isAnimating)
            .onAppear {
                if animationType == .rotate {
                    isAnimating = true
                }
            }
    }
}

struct DarkModeLogoView: View {
    let size: CGFloat
    let showText: Bool
    
    var body: some View {
        FallbackLogoView(size: size)
    }
}

struct ShakeLogoView: View {
    let size: CGFloat
    let intensity: CGFloat
    let speed: Double
    let useDarkMode: Bool
    
    var body: some View {
        FallbackLogoView(size: size)
    }
}

struct EarthquakeLogoView: View {
    let size: CGFloat
    let intensity: CGFloat
    let useDarkMode: Bool
    
    var body: some View {
        FallbackLogoView(size: size)
    }
}

struct LoadingLogoView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            FallbackLogoView(size: size)
            
            ProgressView()
                .scaleEffect(1.5)
                .frame(width: size, height: size)
        }
    }
}

struct EnhancedLogoView: View {
    let size: CGFloat
    
    var body: some View {
        FallbackLogoView(size: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(radius: 5)
    }
}