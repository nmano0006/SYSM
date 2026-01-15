import SwiftUI

struct ContentView: View {
    @State private var showMenu = false
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Content
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                showMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Text("SystemMaintenance")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding()
                        }
                    }
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    
                    // Main Tab Content
                    TabView(selection: $selectedTab) {
                        DashboardView()
                            .tabItem {
                                Label("Dashboard", systemImage: "house.fill")
                            }
                            .tag(0)
                        
                        MaintenanceView(showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                            .tabItem {
                                Label("Maintenance", systemImage: "wrench.fill")
                            }
                            .tag(1)
                        
                        DiagnosticsView()
                            .tabItem {
                                Label("Diagnostics", systemImage: "stethoscope")
                            }
                            .tag(2)
                        
                        SSDTGeneratorView(showAlert: $showAlert, alertTitle: $alertTitle, alertMessage: $alertMessage)
                            .tabItem {
                                Label("SSDT", systemImage: "cpu.fill")
                            }
                            .tag(3)
                    }
                    .accentColor(.blue)
                }
                
                // Side Menu
                if showMenu {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showMenu = false
                            }
                        }
                    
                    SideMenuView(selectedTab: $selectedTab, showMenu: $showMenu)
                        .frame(width: 280)
                        .transition(.move(edge: .leading))
                }
            }
            // Remove navigationBarHidden for macOS - it's not needed
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        // For macOS, you might want to use a different navigation style
        .navigationViewStyle(DefaultNavigationViewStyle())
    }
}

// Supporting Views
struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("System Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Dashboard content here
                VStack(spacing: 15) {
                    StatusCard(title: "System Status", value: "Normal", icon: "checkmark.circle.fill", color: .green)
                    StatusCard(title: "CPU Usage", value: "42%", icon: "cpu.fill", color: .blue)
                    StatusCard(title: "Memory", value: "65%", icon: "memorychip.fill", color: .orange)
                    StatusCard(title: "Storage", value: "78%", icon: "externaldrive.fill", color: .purple)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct MaintenanceView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("System Maintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Maintenance tools here
                VStack(spacing: 15) {
                    MaintenanceButton(title: "Clean System Cache", icon: "trash.fill") {
                        alertTitle = "Cache Cleaned"
                        alertMessage = "System cache has been successfully cleaned."
                        showAlert = true
                    }
                    
                    MaintenanceButton(title: "Update Drivers", icon: "arrow.triangle.2.circlepath") {
                        alertTitle = "Drivers Updated"
                        alertMessage = "System drivers have been checked and updated."
                        showAlert = true
                    }
                    
                    MaintenanceButton(title: "Optimize Storage", icon: "archivebox.fill") {
                        alertTitle = "Storage Optimized"
                        alertMessage = "Storage has been optimized and cleaned up."
                        showAlert = true
                    }
                    
                    MaintenanceButton(title: "Run Diagnostics", icon: "stethoscope") {
                        alertTitle = "Diagnostics Complete"
                        alertMessage = "System diagnostics completed successfully."
                        showAlert = true
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct MaintenanceButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DiagnosticsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("System Diagnostics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Diagnostics tools here
                VStack(spacing: 15) {
                    DiagnosticCard(title: "Hardware Test", description: "Check hardware components", progress: 0.8)
                    DiagnosticCard(title: "Network Test", description: "Test network connectivity", progress: 0.6)
                    DiagnosticCard(title: "Performance Test", description: "Measure system performance", progress: 0.9)
                    DiagnosticCard(title: "Security Scan", description: "Scan for security issues", progress: 0.4)
                }
                .padding(.horizontal)
                
                Button(action: {
                    // Run all diagnostics
                }) {
                    Text("Run All Diagnostics")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct DiagnosticCard: View {
    let title: String
    let description: String
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct SideMenuView: View {
    @Binding var selectedTab: Int
    @Binding var showMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("SystemMaintenance")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal)
            .padding(.top, 50)
            .padding(.bottom, 30)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MenuButton(icon: "house.fill", title: "Dashboard") {
                        selectedTab = 0
                        showMenu = false
                    }
                    
                    MenuButton(icon: "wrench.fill", title: "Maintenance") {
                        selectedTab = 1
                        showMenu = false
                    }
                    
                    MenuButton(icon: "stethoscope", title: "Diagnostics") {
                        selectedTab = 2
                        showMenu = false
                    }
                    
                    MenuButton(icon: "cpu.fill", title: "SSDT Generator") {
                        selectedTab = 3
                        showMenu = false
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 20)
                        .padding(.horizontal)
                    
                    MenuButton(icon: "gear", title: "Settings") {
                        // Settings action
                        showMenu = false
                    }
                    
                    MenuButton(icon: "questionmark.circle", title: "Help") {
                        // Help action
                        showMenu = false
                    }
                    
                    MenuButton(icon: "info.circle", title: "About") {
                        // About action
                        showMenu = false
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("© 2024 SystemMaintenance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 20)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue)
        .edgesIgnoringSafeArea(.vertical)
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.blue)
        .contentShape(Rectangle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}