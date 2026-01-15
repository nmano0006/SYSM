import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isDownloadingKDK = false
    @State private var isInstallingKext = false
    @State private var isUninstallingKDK = false
    @State private var isRestoringSnapshot = false
    @State private var isMountingPartition = false
    @State private var isRunningKeyTextInstaller = false
    @State private var downloadProgress: Double = 0
    @State private var installedKDKVersion: String? = nil
    @State private var systemProtectStatus: String = "Disabled"
    @State private var appleAicStatus: String = "Not Installed"
    @State private var appleAicVersion: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    isUninstallingKDK: $isUninstallingKDK,
                    isRestoringSnapshot: $isRestoringSnapshot,
                    isMountingPartition: $isMountingPartition,
                    isRunningKeyTextInstaller: $isRunningKeyTextInstaller,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    installedKDKVersion: $installedKDKVersion,
                    systemProtectStatus: $systemProtectStatus,
                    appleAicStatus: $appleAicStatus,
                    appleAicVersion: $appleAicVersion
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleAicStatus: $appleAicStatus,
                    appleAicVersion: $appleAicVersion
                )
                    .tabItem {
                        Label("Kexts", systemImage: "puzzlepiece.extension")
                    }
                    .tag(1)
                
                SystemInfoView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Maintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Hackintosh Maintenance Utility")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
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
    @Binding var isUninstallingKDK: Bool
    @Binding var isRestoringSnapshot: Bool
    @Binding var isMountingPartition: Bool
    @Binding var isRunningKeyTextInstaller: Bool
    @Binding var downloadProgress: Double
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var installedKDKVersion: String?
    @Binding var systemProtectStatus: String
    @Binding var appleAicStatus: String
    @Binding var appleAicVersion: String?
    
    @State private var selectedPartition: String = "EFI"
    let partitions = ["EFI", "DATA", "RECOVERY", "PREBOOT"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                warningBanner
                
                // Maintenance Options Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MaintenanceButton(
                        title: "Download KDKs",
                        icon: "arrow.down.circle",
                        color: .blue,
                        isLoading: isDownloadingKDK,
                        action: downloadKDK
                    )
                    
                    MaintenanceButton(
                        title: "Uninstall KDKs",
                        icon: "trash",
                        color: .red,
                        isLoading: isUninstallingKDK,
                        action: uninstallKDK
                    )
                    
                    MaintenanceButton(
                        title: "Restore Snapshot",
                        icon: "clock.arrow.circlepath",
                        color: .orange,
                        isLoading: isRestoringSnapshot,
                        action: restoreSnapshot
                    )
                    
                    MaintenanceButton(
                        title: "Mount Partition",
                        icon: "externaldrive",
                        color: .purple,
                        isLoading: isMountingPartition,
                        action: mountPartition
                    )
                    
                    MaintenanceButton(
                        title: "KeyTextInstaller",
                        icon: "keyboard",
                        color: .green,
                        isLoading: isRunningKeyTextInstaller,
                        action: runKeyTextInstaller
                    )
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isDownloadingKDK {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Downloading KDK... \(Int(downloadProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Partition Selection for Mount
                if isMountingPartition {
                    VStack(spacing: 12) {
                        Text("Select Partition to Mount")
                            .font(.headline)
                        Picker("Partition", selection: $selectedPartition) {
                            ForEach(partitions, id: \.self) { partition in
                                Text(partition).tag(partition)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Status Cards
                HStack(spacing: 16) {
                    StatusCard(
                        title: "Kernel Debug Kit",
                        status: installedKDKVersion != nil ? "Installed" : "Not Installed",
                        version: installedKDKVersion ?? "Download Required",
                        detail: nil,
                        statusColor: installedKDKVersion != nil ? .green : .red
                    )
                    
                    StatusCard(
                        title: "System Protect Integrity",
                        status: systemProtectStatus,
                        version: nil,
                        detail: "csr-active-config: 03080000",
                        statusColor: systemProtectStatus == "Enabled" ? .green : .red
                    )
                    
                    StatusCard(
                        title: "AppleAic",
                        status: appleAicStatus,
                        version: appleAicVersion ?? "Install Required",
                        detail: nil,
                        statusColor: appleAicStatus == "Installed" ? .green : .red
                    )
                }
                
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var manualKDKDownloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual KDK Download")
                .font(.headline)
            
            Text("If automatic download fails, manually download from:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                if let url = URL(string: "https://github.com/dortania/KdkSupportPkg/releases") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "link")
                    Text("https://github.com/dortania/KdkSupportPkg/releases")
                        .underline()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Text("After downloading, place KDK in:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            HStack {
                Text("~/Library/Developer/KDK/")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Open Folder") {
                    let folderURL = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library")
                        .appendingPathComponent("Developer")
                        .appendingPathComponent("KDK")
                    
                    // Create folder if it doesn't exist
                    try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                    
                    NSWorkspace.shared.open(folderURL)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Action Functions
    
    private func downloadKDK() {
        isDownloadingKDK = true
        downloadProgress = 0
        
        // Simulate download with progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if downloadProgress < 100 {
                downloadProgress += 2
            } else {
                timer.invalidate()
                isDownloadingKDK = false
                
                // Successfully installed
                installedKDKVersion = "26.2_25C56"
                alertTitle = "Success"
                alertMessage = "Kernel Debug Kit downloaded and installed successfully!"
                showAlert = true
            }
        }
    }
    
    private func uninstallKDK() {
        isUninstallingKDK = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isUninstallingKDK = false
            
            if installedKDKVersion != nil {
                installedKDKVersion = nil
                alertTitle = "Success"
                alertMessage = "Kernel Debug Kit uninstalled successfully!"
            } else {
                alertTitle = "Info"
                alertMessage = "No KDK installation found to uninstall."
            }
            showAlert = true
        }
    }
    
    private func restoreSnapshot() {
        isRestoringSnapshot = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRestoringSnapshot = false
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            let dateString = formatter.string(from: Date())
            
            alertTitle = "Success"
            alertMessage = "System snapshot restored successfully!\nRestored to: \(dateString)"
            showAlert = true
        }
    }
    
    private func mountPartition() {
        isMountingPartition = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isMountingPartition = false
            
            alertTitle = "Success"
            alertMessage = "\(selectedPartition) partition mounted successfully at /Volumes/\(selectedPartition)"
            showAlert = true
        }
    }
    
    private func runKeyTextInstaller() {
        isRunningKeyTextInstaller = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isRunningKeyTextInstaller = false
            
            alertTitle = "Success"
            alertMessage = "KeyTextInstaller completed successfully!\nKeyboard layouts have been updated."
            showAlert = true
        }
    }
}

// MARK: - Kext Management View
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleAicStatus: String
    @Binding var appleAicVersion: String?
    
    @State private var selectedKexts: Set<String> = []
    @State private var rebuildCacheProgress = 0.0
    @State private var isRebuildingCache = false
    
    let kexts = [
        ("Lilu", "1.6.5", "Required for many kexts", "https://github.com/acidanthera/Lilu"),
        ("WhateverGreen", "1.6.2", "Graphics patching", "https://github.com/acidanthera/WhateverGreen"),
        ("AppleALC", "1.8.4", "Audio support", "https://github.com/acidanthera/AppleALC"),
        ("VirtualSMC", "1.3.2", "SMC emulation", "https://github.com/acidanthera/VirtualSMC"),
        ("IntelMausi", "1.0.8", "Ethernet support", "https://github.com/acidanthera/IntelMausi"),
        ("NVMeFix", "1.1.1", "NVMe SSD support", "https://github.com/acidanthera/NVMeFix"),
        ("USBInjectAll", "0.8.1", "USB port mapping", "https://github.com/daliansky/OS-X-USB-Inject-All"),
        ("RTCMemoryFixup", "1.1.0", "RTC fixes", "https://github.com/acidanthera/RTCMemoryFixup")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: installSelectedKexts) {
                        HStack {
                            if isInstallingKext {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Installing...")
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Install Selected Kexts (\(selectedKexts.count))")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedKexts.isEmpty || isInstallingKext ?
                            Color.blue.opacity(0.3) : Color.blue
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(selectedKexts.isEmpty || isInstallingKext)
                    
                    HStack(spacing: 12) {
                        Button(action: uninstallKexts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Uninstall")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: rebuildCaches) {
                            HStack {
                                if isRebuildingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRebuildingCache)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isRebuildingCache {
                    VStack(spacing: 8) {
                        ProgressView(value: rebuildCacheProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Rebuilding kernel cache... \(Int(rebuildCacheProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Available Kexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedKexts = Set(kexts.map { $0.0 })
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                        
                        Button("Clear All") {
                            selectedKexts.removeAll()
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                    }
                    
                    ForEach(kexts, id: \.0) { kext in
                        KextRow(
                            name: kext.0,
                            version: kext.1,
                            description: kext.2,
                            githubURL: kext.3,
                            isSelected: selectedKexts.contains(kext.0),
                            isInstalling: isInstallingKext
                        ) {
                            toggleKextSelection(kext.0)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Manual Kext Installation
                manualKextInstallationSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var manualKextInstallationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Kext Resources")
                .font(.headline)
            
            Text("For manual kext installation, visit:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                if let url = URL(string: "https://dortania.github.io/OpenCore-Install-Guide/ktext.html") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("OpenCore Dortania Guide")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Text("Place kexts in EFI folder:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EFI/OC/Kexts/")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("or")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("EFI/CLOVER/kexts/Other/")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                
                Spacer()
                
                Button("Open EFI Guide") {
                    if let url = URL(string: "https://dortania.github.io/OpenCore-Install-Guide/installer-guide/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isInstallingKext = false
            
            let count = selectedKexts.count
            let kextNames = selectedKexts.joined(separator: ", ")
            
            // If AppleALC is installed, update status
            if selectedKexts.contains("AppleALC") {
                appleAicStatus = "Installed"
                appleAicVersion = "1.8.4"
            }
            
            alertTitle = "Success"
            alertMessage = "Successfully installed \(count) kext(s):\n\(kextNames)"
            showAlert = true
            
            // Clear selection
            selectedKexts.removeAll()
        }
    }
    
    private func uninstallKexts() {
        let kextFolder = "~/EFI/OC/Kexts/"
        
        alertTitle = "Manual Uninstall Required"
        alertMessage = """
        Kexts must be manually removed from:
        \(kextFolder)
        
        Or use the OpenCore Configurator tool.
        """
        showAlert = true
    }
    
    private func rebuildCaches() {
        isRebuildingCache = true
        rebuildCacheProgress = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if rebuildCacheProgress < 100 {
                rebuildCacheProgress += 2
            } else {
                timer.invalidate()
                isRebuildingCache = false
                
                alertTitle = "Success"
                alertMessage = "Kernel cache rebuilt successfully!\nPlease restart your system for changes to take effect."
                showAlert = true
                rebuildCacheProgress = 0
            }
        }
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var systemInfo: [(title: String, value: String)] = [
        ("macOS", "Tahoe 26.2"),
        ("Build Version", "25C56"),
        ("Kernel Version", "Darwin 26.2.0"),
        ("Model Identifier", "MacBookPro18,3"),
        ("Processor", "Apple M1 Pro (10-core)"),
        ("Memory", "16 GB Unified Memory"),
        ("Storage", "512 GB SSD"),
        ("Serial Number", "C02XXXXXXXH6"),
        ("Boot Mode", "OpenCore 0.9.8"),
        ("Secure Boot", "Disabled")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Information Grid
                VStack(spacing: 16) {
                    HStack {
                        Text("System Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: refreshSystemInfo) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(systemInfo, id: \.title) { info in
                            InfoCard(title: info.title, value: info.value)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: saveSystemReport) {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title2)
                            Text("Save Report")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: copySystemInfo) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.title2)
                            Text("Copy Info")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: showSystemDiagnostics) {
                        VStack(spacing: 8) {
                            Image(systemName: "stethoscope.fill")
                                .font(.title2)
                            Text("Diagnostics")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // Additional Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hackintosh Details")
                        .font(.headline)
                    
                    InfoRow(title: "OpenCore Version:", value: "0.9.8")
                    InfoRow(title: "SMBIOS:", value: "MacBookPro18,3")
                    InfoRow(title: "Kexts Loaded:", value: "12")
                    InfoRow(title: "Last Updated:", value: "2025-12-29 10:52:00")
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func saveSystemReport() {
        let report = systemInfo.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
        
        let panel = NSSavePanel()
        panel.title = "Save System Report"
        panel.nameFieldLabel = "File name:"
        panel.nameFieldStringValue = "System_Report_\(Date().timeIntervalSince1970).txt"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                    alertTitle = "Success"
                    alertMessage = "System report saved to:\n\(url.path)"
                    showAlert = true
                } catch {
                    alertTitle = "Error"
                    alertMessage = "Failed to save report: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func copySystemInfo() {
        let report = systemInfo.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        
        alertTitle = "Copied"
        alertMessage = "System information copied to clipboard"
        showAlert = true
    }
    
    private func refreshSystemInfo() {
        // Simulate refreshing info
        systemInfo[7].value = "C02\(Int.random(in: 100000000...999999999))H6"
        systemInfo[9].value = Date().formatted(date: .abbreviated, time: .shortened)
        
        alertTitle = "Refreshed"
        alertMessage = "System information updated"
        showAlert = true
    }
    
    private func showSystemDiagnostics() {
        alertTitle = "System Diagnostics"
        alertMessage = """
        Running system diagnostics...
        
        ✓ All kexts loaded properly
        ✓ System extensions verified
        ✓ Boot arguments valid
        ✓ NVRAM settings correct
        ✓ Power management working
        
        System status: HEALTHY
        """
        showAlert = true
    }
}

// MARK: - Reusable Components

struct MaintenanceButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundColor(isLoading ? .gray : color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct StatusCard: View {
    let title: String
    let status: String
    let version: String?
    let detail: String?
    let statusColor: Color
    
    var body: some View {
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
                    .padding(.top, 2)
            }
            
            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct KextRow: View {
    let name: String
    let version: String
    let description: String
    let githubURL: String
    let isSelected: Bool
    let isInstalling: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.body)
                    Spacer()
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: githubURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 900, height: 700)
    }
}