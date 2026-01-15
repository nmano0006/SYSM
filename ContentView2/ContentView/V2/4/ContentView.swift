// MARK: - ContentView.swift (simplified without OpenCore code)
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
            
            // Tab 5: Hex/Base64 Calculator
            HexBase64CalculatorView()
                .tabItem { 
                    Label("Calculator", systemImage: "number.square")
                }
                .tag(4)
            
            // Tab 6: SSDT Generator
            SSDTGeneratorView(showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                .tabItem { 
                    Label("SSDT", systemImage: "gear")
                }
                .tag(5)
            
            // Tab 7: OpenCore Config Editor
            OpenCoreConfigEditorView()  // Now in separate file
                .tabItem { 
                    Label("OpenCore", systemImage: "platter.2.filled.ipad")
                }
                .tag(6)
            
            // Tab 8: Info/About
            InfoView()
                .tabItem { 
                    Label("Info", systemImage: "info.circle")
                }
                .tag(7)
            
            // Tab 9: Troubleshooter
            TroubleshooterView(hasIssues: $hasIssues)
                .tabItem { 
                    Label("Troubleshoot", systemImage: "wrench.and.screwdriver")
                }
                .tag(8)
        }
        .frame(minWidth: 900, minHeight: 600)
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