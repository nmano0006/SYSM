import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var hasFullDiskAccess = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Drive Management
            DriveManagementView()
                .tabItem {
                    Label("Drives", systemImage: "externaldrive")
                }
                .tag(0)
            
            // Tab 2: System Information
            SystemInfoView()
                .tabItem {
                    Label("System", systemImage: "desktopcomputer")
                }
                .tag(1)
            
            // Tab 3: Kexts Manager
            KextsManagerView()
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece")
                }
                .tag(2)
            
            // Tab 4: Audio Tools
            AudioToolsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .tag(3)
            
            // Tab 5: SSDT Generator
            SSDTGeneratorView()
                .tabItem {
                    Label("SSDT", systemImage: "gear")
                }
                .tag(4)
            
            // Tab 6: Info/About
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(5)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        let shellHelper = ShellHelper.shared
        let hasAccess = shellHelper.checkFullDiskAccess()
        hasFullDiskAccess = hasAccess
        if !hasAccess {
            showAlert(title: "Permissions Info",
                     message: "Full Disk Access is recommended for full functionality. Grant access in System Settings > Privacy & Security > Full Disk Access.")
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}