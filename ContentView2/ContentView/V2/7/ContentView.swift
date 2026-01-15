import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var hasFullDiskAccess = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isLoading = false
    @State private var hasIssues = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Drive Management
            DriveManagementView()
                .tabItem { 
                    Label("Drives", systemImage: "externaldrive")
                }
                .tag(0)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            InteractiveLogoView(size: 24, useDarkMode: true)
                            Text("Drive Management").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 2: System Information
            SystemInfoView()
                .tabItem { 
                    Label("System", systemImage: "desktopcomputer")
                }
                .tag(1)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            AnimatedLogoView(size: 24, animationType: .shake, duration: 2.0, useDarkMode: true)
                            Text("System Information").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 3: Kexts Manager
            KextsManagerView()
                .tabItem { 
                    Label("Kexts", systemImage: "puzzlepiece")
                }
                .tag(2)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            DarkModeLogoView(size: 24, showText: false)
                            Text("Kexts Manager").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 4: Audio Tools
            AudioToolsView()
                .tabItem { 
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .tag(3)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            ShakeLogoView(size: 24, intensity: 12, speed: 0.15, useDarkMode: true)
                            Text("Audio Tools").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 5: Hex/Base64 Calculator
            HexBase64CalculatorView()
                .tabItem { 
                    Label("Calculator", systemImage: "number.square")
                }
                .tag(4)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            Image(systemName: "function")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Hex/Base64 Calculator").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 6: SSDT Generator
            SSDTGeneratorView(showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                .tabItem { 
                    Label("SSDT", systemImage: "gear")
                }
                .tag(5)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            AnimatedLogoView(size: 24, animationType: .rotate, duration: 4.0, useDarkMode: true)
                            Text("SSDT Generator").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 7: OpenCore Config Editor
            OpenCoreConfigEditorView()
                .tabItem { 
                    Label("OpenCore", systemImage: "opticaldiscdrive")
                }
                .tag(6)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            Text("OpenCore Config").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
            
            // Tab 8: Info/About
            InfoView()
                .tabItem { 
                    Label("Info", systemImage: "info.circle")
                }
                .tag(7)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            EnhancedLogoView(size: 26)
                            Text("About SYSM").font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showAlert(title: "About System Maintenance",
                                     message: "Version 1.0.0\n\nA comprehensive system maintenance tool for macOS.\n\nPowered by SYSM")
                        }) {
                            Image(systemName: "info.circle")
                        }
                        .help("About SYSM")
                    }
                }
            
            // Tab 9: Troubleshooter
            TroubleshooterView(hasIssues: $hasIssues)
                .tabItem { 
                    Label("Troubleshoot", systemImage: "wrench.and.screwdriver")
                }
                .tag(8)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            if hasIssues {
                                EarthquakeLogoView(size: 24, intensity: 15, useDarkMode: true)
                            } else {
                                Image("SYSMLogo")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .cornerRadius(6)
                            }
                            
                            Text("Troubleshooter")
                                .font(.headline)
                        }
                        .padding(.leading, 8)
                    }
                }
        }
        // Use compatible frame size
        .frame(minWidth: 900, minHeight: 600)
        // Compatible alert for all macOS versions
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            LoadingLogoView(size: 80)
                            
                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                }
            }
        )
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        isLoading = true
        
        // Simulate permission check delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let hasAccess = ShellHelper.checkFullDiskAccess()
            hasFullDiskAccess = hasAccess
            
            if !hasAccess {
                showAlert(title: "Permissions Info",
                         message: "Full Disk Access is recommended for full functionality. Grant access in System Settings > Privacy & Security > Full Disk Access.")
            }
            
            isLoading = false
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Compatible View Modifiers
extension View {
    // Helper for conditional modifiers (compatible with all macOS versions)
    @ViewBuilder
    func conditionalModifier<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview Providers
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .frame(width: 900, height: 600)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            ContentView()
                .frame(width: 900, height: 600)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Preview for older macOS compatibility
            ContentView()
                .frame(width: 800, height: 500)
                .previewDisplayName("Compact Size")
        }
    }
}