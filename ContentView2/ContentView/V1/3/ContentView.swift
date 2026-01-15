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
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                            
                            Text("Drive Management")
                                .font(.headline)
                        }
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
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                            
                            Text("System Information")
                                .font(.headline)
                        }
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
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                            
                            Text("Kexts Manager")
                                .font(.headline)
                        }
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
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                            
                            Text("Audio Tools")
                                .font(.headline)
                        }
                    }
                }
            
            // Tab 5: SSDT Generator
            SSDTGeneratorView(
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage
            )
                .tabItem {
                    Label("SSDT", systemImage: "gear")
                }
                .tag(4)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                            
                            Text("SSDT Generator")
                                .font(.headline)
                        }
                    }
                }
            
            // Tab 6: Info/About
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(5)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 10) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .cornerRadius(5)
                                .shadow(color: .blue.opacity(0.3), radius: 1)
                            
                            Text("About SYSM")
                                .font(.headline)
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showAlert(title: "About",
                                     message: "System Maintenance v1.0\nPowered by SYSM")
                        }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
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
        let hasAccess = ShellHelper.checkFullDiskAccess()
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

// MARK: - Reusable Logo Component for macOS
struct SYSMLogoView: View {
    var size: CGFloat = 20
    var showText: Bool = true
    var text: String = "SYSM"
    var cornerRadius: CGFloat = 5
    
    var body: some View {
        HStack(spacing: 8) {
            Image("SYSMLogo")
                .resizable()
                .frame(width: size, height: size)
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            if showText {
                Text(text)
                    .font(.system(size: size * 0.8, weight: .medium))
            }
        }
    }
}

// MARK: - macOS Window Header (Alternative: Fixed Header)
struct MacAppHeaderView: View {
    @Binding var selectedTab: Int
    let tabs = [
        ("Drives", "externaldrive"),
        ("System", "desktopcomputer"),
        ("Kexts", "puzzlepiece"),
        ("Audio", "speaker.wave.2"),
        ("SSDT", "gear"),
        ("Info", "info.circle")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top header with logo
            HStack {
                Image("SYSMLogo")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(6)
                    .padding(.leading, 16)
                
                Text("System Maintenance")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    // Show about dialog
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .help("About SYSM")
            }
            .padding(.vertical, 10)
            .background(.bar)
            
            // Tab selection
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tabs[index].1)
                                .font(.system(size: 14))
                            Text(tabs[index].0)
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == index ? Color.blue.opacity(0.1) : Color.clear)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedTab == index ? .blue : .clear),
                            alignment: .bottom
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.bar.opacity(0.5))
            .overlay(Divider(), alignment: .bottom)
        }
    }
}

// MARK: - Alternative ContentView with Fixed Header
struct ContentViewWithHeader: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            MacAppHeaderView(selectedTab: $selectedTab)
            
            // Tab content
            TabView(selection: $selectedTab) {
                DriveManagementView()
                    .tag(0)
                
                SystemInfoView()
                    .tag(1)
                
                KextsManagerView()
                    .tag(2)
                
                AudioToolsView()
                    .tag(3)
                
                SSDTGeneratorView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                .tag(4)
                
                InfoView()
                    .tag(5)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
        
        ContentViewWithHeader()
            .frame(width: 1200, height: 800)
            .previewDisplayName("With Fixed Header")
    }
}