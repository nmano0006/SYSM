import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Existing Drive Management Tab
            DriveManagementView
                .tabItem {
                    Label("Drives", systemImage: "externaldrive")
                }
                .tag(0)
            
            // New: System Information Tab
            SystemInfoView()
                .tabItem {
                    Label("System", systemImage: "desktopcomputer")
                }
                .tag(1)
            
            // New: Kexts Manager Tab
            KextsManagerView()
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece")
                }
                .tag(2)
            
            // New: Audio Tools Tab
            AudioToolsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .tag(3)
            
            // New: SSDT Generator Tab
            SSDTGeneratorView()
                .tabItem {
                    Label("SSDT", systemImage: "gear")
                }
                .tag(4)
            
            // New: Info/About Tab
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(5)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
    
    // Keep your existing DriveManagementView implementation
    private var DriveManagementView: some View {
        // ... your existing DriveManagementView code ...
        // (Keep all the code you already have for the drives tab)
        ScrollView {
            VStack(spacing: 20) {
                // Control Panel
                ControlPanelView
                
                // Drives List
                if DriveManager.shared.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    DrivesListView
                }
                
                // Quick Actions
                QuickActionsGrid
            }
            .padding()
        }
    }
    
    // ... rest of your existing DriveManagementView code ...
}