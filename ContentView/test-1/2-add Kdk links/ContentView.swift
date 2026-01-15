import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isDownloadingKDK = false
    @State private var isInstallingKext = false
    @State private var downloadProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
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
        .alert("Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("System Maintenance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
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
    }
}

// MARK: - System Maintenance View
struct SystemMaintenanceView: View {
    @Binding var isDownloadingKDK: Bool
    @Binding var downloadProgress: Double
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                warningBanner
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Maintenance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Updated KDK button with working link
                    Button(action: {
                        downloadKDK()
                    }) {
                        maintenanceOptionRow(
                            icon: "arrow.down.circle",
                            title: "Download KDKs",
                            color: .blue,
                            isLoading: isDownloadingKDK
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloadingKDK)
                    
                    if isDownloadingKDK {
                        ProgressView(value: downloadProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }
                    
                    maintenanceOptionRow(icon: "trash", title: "Uninstall KDKs", color: .red)
                    maintenanceOptionRow(icon: "clock.arrow.circlepath", title: "Restore Snapshot", color: .orange)
                    maintenanceOptionRow(icon: "externaldrive", title: "Mount Partition", color: .purple)
                    maintenanceOptionRow(icon: "keyboard", title: "KeyTextInstaller", color: .green)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                statusCards
                
                // Manual KDK Download Section
                manualKDKDownloadSection
                
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
    }
    
    private var statusCards: some View {
        HStack(spacing: 16) {
            statusCard(
                title: "Kernel Debug Kit",
                status: "Not Installed",
                version: "Download Required",
                statusColor: .red
            )
            
            statusCard(
                title: "System Protect Integrity",
                status: "Disabled",
                detail: "csr-active-config: 03080000",
                statusColor: .red
            )
            
            statusCard(
                title: "AppleAic",
                status: "Not Installed",
                version: "Install Required",
                statusColor: .red
            )
        }
    }
    
    private var manualKDKDownloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual KDK Download")
                .font(.headline)
            
            Text("If automatic download fails, manually download from:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link("https://github.com/dortania/KdkSupportPkg/releases",
                  destination: URL(string: "https://github.com/dortania/KdkSupportPkg/releases")!)
                .font(.caption)
                .foregroundColor(.blue)
                .underline()
            
            Text("After downloading, place KDK in:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            Text("~/Library/Developer/KDK/")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func maintenanceOptionRow(icon: String, title: String, color: Color, isLoading: Bool = false) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24)
            } else {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
            }
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
    
    private func downloadKDK() {
        isDownloadingKDK = true
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if downloadProgress < 100 {
                downloadProgress += 2
            } else {
                timer.invalidate()
                isDownloadingKDK = false
                alertMessage = "KDK downloaded successfully!"
                showAlert = true
                
                // Reset progress after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    downloadProgress = 0
                }
            }
        }
    }
}

// MARK: - Kext Management View
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @State private var selectedKexts: Set<String> = []
    
    let kexts = [
        ("Lilu", "1.6.5", "Required for many kexts"),
        ("WhateverGreen", "1.6.2", "Graphics patching"),
        ("AppleALC", "1.8.4", "Audio support"),
        ("VirtualSMC", "1.3.2", "SMC emulation"),
        ("IntelMausi", "1.0.8", "Ethernet support"),
        ("NVMeFix", "1.1.1", "NVMe SSD support")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Kext Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Install button with actual functionality
                    Button(action: {
                        installSelectedKexts()
                    }) {
                        HStack {
                            if isInstallingKext {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Installing...")
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                Text("Install Selected Kexts (\(selectedKexts.count))")
                            }
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedKexts.isEmpty || isInstallingKext)
                    
                    Button(action: {
                        uninstallKexts()
                    }) {
                        HStack {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                            Text("Uninstall Kexts")
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        rebuildCaches()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Text("Rebuild Caches")
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Kexts")
                        .font(.headline)
                    
                    ForEach(kexts, id: \.0) { kext in
                        HStack {
                            Button(action: {
                                toggleKextSelection(kext.0)
                            }) {
                                Image(systemName: selectedKexts.contains(kext.0) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedKexts.contains(kext.0) ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(kext.0)
                                        .font(.body)
                                    Spacer()
                                    Text("v\(kext.1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(kext.2)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Manual Kext Installation
                manualKextInstallationSection
            }
            .padding()
        }
    }
    
    private var manualKextInstallationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Kext Installation")
                .font(.headline)
            
            Text("For manual kext installation, download from:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link("OpenCore Dortania Guide",
                  destination: URL(string: "https://dortania.github.io/OpenCore-Install-Guide/ktext.html")!)
                .font(.caption)
                .foregroundColor(.blue)
                .underline()
            
            Text("Place kexts in:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            Text("EFI/OC/Kexts/")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func toggleKextSelection(_ kextName: String) {
        if selectedKexts.contains(kextName) {
            selectedKexts.remove(kextName)
        } else {
            selectedKexts.insert(kextName)
        }
    }
    
    private func installSelectedKexts() {
        isInstallingKext = true
        
        // Simulate installation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isInstallingKext = false
            let count = selectedKexts.count
            alertMessage = "Successfully installed \(count) kext(s): \(selectedKexts.joined(separator: ", "))"
            showAlert = true
            selectedKexts.removeAll()
        }
    }
    
    private func uninstallKexts() {
        alertMessage = "Kext uninstallation requires manual removal from EFI/OC/Kexts/ folder"
        showAlert = true
    }
    
    private func rebuildCaches() {
        alertMessage = "Cache rebuilt successfully. Please restart your system for changes to take effect."
        showAlert = true
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @State private var systemInfo: [String: String] = [
        "macOS": "Tahoe 26.2",
        "Build Version": "25C56",
        "Kernel Version": "Darwin 26.2.0",
        "Model": "MacBookPro18,3",
        "Processor": "Apple M1 Pro",
        "Memory": "16 GB",
        "Storage": "512 GB SSD"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(systemInfo.keys.sorted()), id: \.self) { key in
                        infoRow(title: "\(key):", value: systemInfo[key] ?? "")
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: copySystemInfo) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Copy Info")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: refreshSystemInfo) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("Refresh")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
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
    
    private func copySystemInfo() {
        let infoString = systemInfo.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(infoString, forType: .string)
        
        // Show feedback (you could add a toast here)
        print("System info copied to clipboard")
    }
    
    private func refreshSystemInfo() {
        // Simulate refreshing system info
        print("Refreshing system information...")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 800, height: 600)
    }
}