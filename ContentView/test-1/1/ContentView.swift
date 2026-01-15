import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main Content
            TabView(selection: $selectedTab) {
                SystemMaintenanceView()
                    .tabItem {
                        Label("System", systemImage: "gear")
                    }
                    .tag(0)
                
                KextManagementView()
                    .tabItem {
                        Label("Kexts", systemImage: "puzzlepiece.extension")
                    }
                    .tag(1)
                
                SystemInfoView()
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("System Maintenance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - System Maintenance View
struct SystemMaintenanceView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Warning Banner
                warningBanner
                
                // Maintenance Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Maintenance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    maintenanceOptionRow(icon: "arrow.down.circle", title: "Download KDKs", color: .blue)
                    maintenanceOptionRow(icon: "trash", title: "Uninstall KDKs", color: .red)
                    maintenanceOptionRow(icon: "clock.arrow.circlepath", title: "Restore Snapshot", color: .orange)
                    maintenanceOptionRow(icon: "externaldrive", title: "Mount Partition", color: .purple)
                    maintenanceOptionRow(icon: "keyboard", title: "KeyTextInstaller", color: .green)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Status Cards
                statusCards
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Minimum Required Conditions", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("To ensure the audio restoration works correctly, please make sure that all the information and settings displayed on this screen are accurate and meet the minimum requirements. If any item is incorrect or not properly configured, the installation may fail or have no effect.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusCards: some View {
        HStack(spacing: 16) {
            statusCard(
                title: "Kernel Debug Kit",
                status: "Installed",
                version: "26.2_25C56",
                statusColor: .green
            )
            
            statusCard(
                title: "System Protect Integrity",
                status: "Disabled",
                detail: "csr-active-config: 03080000",
                statusColor: .red
            )
            
            statusCard(
                title: "AppleAic",
                status: "Installed",
                version: "Release 1.9.5",
                statusColor: .green
            )
        }
    }
    
    private func maintenanceOptionRow(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle option selection
            print("Selected: \(title)")
        }
    }
    
    private func statusCard(title: String, status: String, version: String? = nil, detail: String? = nil, statusColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let version = version {
                Text(version)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Kext Management View
struct KextManagementView: View {
    @State private var isInstalling = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Kext Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    kextActionRow(title: "Install Kexts", description: "Install kernel extensions", icon: "plus.circle", color: .blue) {
                        installKexts()
                    }
                    
                    kextActionRow(title: "Uninstall Kexts", description: "Remove kernel extensions", icon: "minus.circle", color: .red) {
                        uninstallKexts()
                    }
                    
                    kextActionRow(title: "Rebuild Caches", description: "Rebuild kernel extension cache", icon: "arrow.triangle.2.circlepath", color: .orange) {
                        rebuildCaches()
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Kext Status List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed Kexts")
                        .font(.headline)
                    
                    kextStatusRow(name: "AppleAic", version: "1.9.5", status: "Active")
                    kextStatusRow(name: "Lilu", version: "1.6.5", status: "Active")
                    kextStatusRow(name: "WhateverGreen", version: "1.6.2", status: "Active")
                    kextStatusRow(name: "VirtualSMC", version: "1.3.2", status: "Active")
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func kextActionRow(title: String, description: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func kextStatusRow(name: String, version: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text("v\(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status == "Active" ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }
    
    private func installKexts() {
        print("Installing kexts...")
    }
    
    private func uninstallKexts() {
        print("Uninstalling kexts...")
    }
    
    private func rebuildCaches() {
        print("Rebuilding caches...")
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    infoRow(title: "macOS:", value: "Tahoe 26.2")
                    infoRow(title: "Build Version:", value: "25C56")
                    infoRow(title: "Kernel Version:", value: "Darwin 26.2.0")
                    infoRow(title: "Model Identifier:", value: "MacBookPro18,3")
                    infoRow(title: "Processor:", value: "Apple M1 Pro")
                    infoRow(title: "Memory:", value: "16 GB")
                    infoRow(title: "Serial Number:", value: "C02XXXXXXXH6")
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        quickActionButton(title: "Save Report", icon: "square.and.arrow.down", color: .blue)
                        quickActionButton(title: "Copy Info", icon: "doc.on.doc", color: .green)
                        quickActionButton(title: "Refresh", icon: "arrow.clockwise", color: .orange)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func quickActionButton(title: String, icon: String, color: Color) -> some View {
        Button(action: {
            print("\(title) tapped")
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 800, height: 600)
    }
}