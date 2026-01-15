import SwiftUI

public struct EnhancedLogoView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showMenu = false
    public var size: CGFloat = 32
    
    public init(size: CGFloat = 32) {
        self.size = size
    }
    
    public var body: some View {
        Menu {
            Button("Copy Logo Info") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("SYSM Logo - System Maintenance", forType: .string)
            }
            
            Button("About SYSM") {
                // Handle in parent view
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
