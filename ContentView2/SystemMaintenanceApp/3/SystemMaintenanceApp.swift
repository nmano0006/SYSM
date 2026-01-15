// SystemMaintenanceApp.swift
import SwiftUI

@main
struct SystemMaintenanceApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("System Maintenance Help") {
                    if let url = URL(string: "https://github.com/your-repo/SystemMaintenance/wiki") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var hasFullDiskAccess = false
    @Published var isLoading = false
    @Published var selectedTab = 0
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasFullDiskAccess = ShellHelper.checkFullDiskAccess()
            self.isLoading = false
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("developerMode") private var developerMode = false
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Automatically check for updates", isOn: $autoCheckUpdates)
                Toggle("Enable animations", isOn: $enableAnimations)
                Toggle("Developer mode", isOn: $developerMode)
            }
            
            Section("Advanced") {
                Button("Reset Application") {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}