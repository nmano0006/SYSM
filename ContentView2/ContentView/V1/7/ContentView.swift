import SwiftUI

struct ContentView: View {
    @State private var selection = 0
    
    var body: some View {
        TabView(selection: $selection) {
            // Tab 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            // Tab 2: System Info
            SystemInfoView()
                .tabItem {
                    Label("System", systemImage: "display")
                }
                .tag(1)
            
            // Tab 3: Drive Management
            DriveManagementView()
                .tabItem {
                    Label("Drive", systemImage: "externaldrive")
                }
                .tag(2)
            
            // Tab 4: Kext Manager
            KextsManagerView()
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece.extension")
                }
                .tag(3)
            
            // Tab 5: Audio Tools
            AudioToolsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.3")
                }
                .tag(4)
            
            // Tab 6: SSDT Generator
            SSDTGeneratorView()
                .tabItem {
                    Label("SSDT", systemImage: "cpu")
                }
                .tag(5)
            
            // Tab 7: Info
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(6)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct DashboardView: View {
    var body: some View {
        VStack {
            Text("System Maintenance Dashboard")
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            // You can add dashboard content here
            Text("Welcome to System Maintenance")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}