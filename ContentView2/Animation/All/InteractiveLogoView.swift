// Views/InteractiveLogoView.swift
import SwiftUI

struct InteractiveLogoView: View {
    let size: CGFloat
    
    @State private var isHovering = false
    
    var body: some View {
        Image(systemName: "externaldrive.fill")
            .resizable()
            .frame(width: size, height: size)
            .foregroundColor(isHovering ? .blue : .gray)
            .scaleEffect(isHovering ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}