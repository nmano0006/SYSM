// Views/DarkModeLogoView.swift
import SwiftUI

struct DarkModeLogoView: View {
    let size: CGFloat
    let showText: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "puzzlepiece.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(.blue)
            
            if showText {
                Text("SYSM")
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
    }
}