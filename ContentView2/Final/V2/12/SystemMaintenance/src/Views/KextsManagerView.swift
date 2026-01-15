// Views/KextsManagerView.swift
import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Data Models
struct KextInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let path: String
    let isLoaded: Bool
    let index: String
    let references: String
    let address: String
    let size: String
    let wiredSize: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(bundleID)
    }
    
    static func == (lhs: KextInfo, rhs: KextInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

struct KDKInfo: Identifiable {
    let id = UUID()
    let version: String
    let path: String
    let isActive: Bool
    let location: String
    let isCompatible: Bool
}

// MARK: - Main View
struct KextsManagerView: View {
    @State private var kexts: [KextInfo] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedTab = 0  // 0 = Manage Kexts, 1 = Install AppleHDA, 2 = KDK Manager
    @State private var showInfoAlert = false
    @State private var alertMessage = ""
    @State private var operationInProgress = false
    
    // AppleHDA Installation States
    @State private var isInstallingKext = false
    @State private var appleHDAStatus = "Not Installed"
    @State private var appleHDAVersion: String? = nil
    @State private var appleALCStatus = "Not Installed"
    @State private var appleALCVersion: String? = nil
    @State private var liluStatus = "Not Installed"
    @State private var liluVersion: String? = nil
    @State private var efiPath: String? = nil
    @State private var kextSourcePath = ""
    
    // KDK Installation States
    @State private var kdkStatus = "Not Installed"
    @State private var kdkVersion: String? = nil
    @State private var isInstallingKDK = false
    @State private var kdkInstallProgress = 0.0
    @State private var installedKDKs: [KDKInfo] = []
    @State private var macOSVersion = ""
    @State private var macOSBuild = ""
    
    // For kext selection in install tab
    @State private var selectedKexts: Set<String> = ["Lilu", "AppleALC", "AppleHDA"]
    @State private var showAudioKextsOnly = true
    
    // Kext data
    private let allKexts = [
        // Required for AppleHDA Audio
        ("Lilu", "1.6.8", "Kernel extension patcher - REQUIRED for audio", "https://github.com/acidanthera/Lilu", true),
        ("AppleALC", "1.8.7", "Audio codec support - REQUIRED for AppleHDA", "https://github.com/acidanthera/AppleALC", true),
        ("AppleHDA", "500.7.4", "Apple HD Audio driver", "Custom build", true),
        
        // Graphics
        ("WhateverGreen", "1.6.8", "Graphics patching and DRM fixes", "https://github.com/acidanthera/WhateverGreen", false),
        ("IntelGraphicsFixup", "1.3.1", "Intel GPU framebuffer patches", "https://github.com/lvs1974/IntelGraphicsFixup", false),
        
        // System
        ("VirtualSMC", "1.3.3", "SMC emulation for virtualization", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCProcessor", "1.3.3", "CPU monitoring for VirtualSMC", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCSuperIO", "1.3.3", "Super I/O monitoring", "https://github.com/acidanthera/VirtualSMC", false),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Tabs
            VStack(spacing: 0) {
                HStack {
                    Text(titleForSelectedTab)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if selectedTab == 0 {
                        Button(action: { refreshKexts() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading || operationInProgress)
                    } else if selectedTab == 2 {
                        Button(action: { refreshKDKList() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isInstallingKDK)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("Manage Kexts").tag(0)
                    Text("Install AppleHDA").tag(1)
                    Text("KDK Manager").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom)
            }
            
            if selectedTab == 0 {
                ManageKextsView
            } else if selectedTab == 1 {
                InstallAppleHDAView
                    .onAppear {
                        loadEFIPath()
                        checkAppleHDAInstallation()
                    }
            } else {
                KDKManagerView
                    .onAppear {
                        getSystemInfo()
                        checkKDKInstallation()
                        refreshKDKList()
                    }
            }
            
            Spacer()
        }
        .onAppear {
            if selectedTab == 0 {
                refreshKexts()
            } else if selectedTab == 2 {
                getSystemInfo()
                checkKDKInstallation()
                refreshKDKList()
            }
        }
        .alert("Kext Operation", isPresented: $showInfoAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var titleForSelectedTab: String {
        switch selectedTab {
        case 0: return "Kernel Extensions"
        case 1: return "AppleHDA Installer"
        case 2: return "KDK Manager"
        default: return "Kext Manager"
        }
    }
    
    // MARK: - Tab 1: Manage Kexts View
    private var ManageKextsView: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search kexts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
                Text("Loading kernel extensions...")
                    .foregroundColor(.secondary)
            } else if kexts.isEmpty {
                EmptyStateView
            } else {
                KextsListView
            }
            
            Spacer()
            
            // Quick Actions
            QuickActionsView
        }
    }
    
    // MARK: - Tab 2: Install AppleHDA View
    private var InstallAppleHDAView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Overview
                StatusOverviewSection
                
                // EFI Status
                EFIStatusSection
                
                // Audio Package Installation
                AudioPackageSection
                
                // Kext Source Selection
                KextSourceSection
                
                // Action Buttons
                ActionButtonsSection
                
                // Kext Selection List
                KextListSection
                
                // SIP Status and Instructions
                SIPInfoSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Tab 3: KDK Manager View
    private var KDKManagerView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Info
                SystemInfoSection
                
                // KDK Status
                KDKStatusSection
                
                // Installed KDKs List
                InstalledKDKsSection
                
                // KDK Actions
                KDKActionsSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - SIP Info Section
    private var SIPInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ System Integrity Protection (SIP)")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("AppleHDA installation requires SIP to be disabled or configured properly.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Check SIP Status") {
                checkSIPStatus()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Show Installation Guide") {
                showManualInstallationGuide()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.blue)
            
            Text("For AppleHDA, you may need to:")
                .font(.caption2)
                .padding(.top, 4)
            
            Text("• Use Library/Extensions instead of System/Library/Extensions")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("• Disable SIP in Recovery Mode")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("• Use OpenCore patching method")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - System Info Section
    private var SystemInfoSection: some View {
        VStack(spacing: 12) {
            Text("System Information")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            if !macOSVersion.isEmpty {
                HStack(spacing: 20) {
                    InfoItem(
                        title: "macOS",
                        value: macOSVersion,
                        subtitle: macOSBuild,
                        icon: "desktopcomputer",
                        color: .blue
                    )
                    
                    InfoItem(
                        title: "Kernel",
                        value: getKernelVersion(),
                        subtitle: "Kext Version",
                        icon: "gear",
                        color: .purple
                    )
                }
            }
            
            Text("macOS \(macOSVersion) (\(macOSBuild)) • Kernel \(getKernelVersion())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private func InfoItem(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func getKernelVersion() -> String {
        let result = ShellHelper.runCommand("uname -r")
        if result.success {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Unknown"
    }
    
    // MARK: - KDK Status Section
    private var KDKStatusSection: some View {
        VStack(spacing: 12) {
            Text("Kernel Debug Kit Status")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            HStack(spacing: 16) {
                StatusItem(
                    title: "KDK Status",
                    status: kdkStatus,
                    version: kdkVersion,
                    icon: "wrench.and.screwdriver.fill",
                    color: .purple
                )
                
                StatusItem(
                    title: "Active KDK",
                    status: installedKDKs.first(where: { $0.isActive })?.version ?? "None",
                    version: nil,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            
            if kdkStatus == "Installed" && !installedKDKs.isEmpty {
                Text("✅ KDK is properly installed and ready")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            } else if kdkStatus == "Not Installed" {
                Text("⚠️ KDK is required for kernel extension development")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private func StatusItem(title: String, status: String, version: String?, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(status)
                .font(.caption)
                .foregroundColor(status == "Installed" || status.contains("26.") ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    (status == "Installed" || status.contains("26.") ? Color.green : Color.orange)
                        .opacity(0.1)
                )
                .cornerRadius(4)
            
            if let version = version, !version.isEmpty {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Installed KDKs Section
    private var InstalledKDKsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Installed KDKs")
                    .font(.headline)
                
                Spacer()
                
                Text("\(installedKDKs.count) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if installedKDKs.isEmpty {
                HStack {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundColor(.secondary)
                    Text("No KDKs found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            } else {
                ForEach(installedKDKs) { kdk in
                    KDKRow(kdk: kdk)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func KDKRow(kdk: KDKInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: kdk.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(kdk.isActive ? .green : .gray)
                    Text(kdk.version)
                        .font(.body)
                        .fontWeight(kdk.isActive ? .semibold : .regular)
                }
                
                Text(kdk.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if kdk.isCompatible {
                    Text("✅ Compatible with macOS \(macOSVersion)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if kdk.isActive {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Button(action: {
                verifyKDKCompatibility(kdk)
            }) {
                Text("Verify")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                uninstallKDK(kdk)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(kdk.isActive ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - KDK Actions Section
    private var KDKActionsSection: some View {
        VStack(spacing: 12) {
            Text("KDK Management")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: verifyKDKInstallation) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Verify KDK")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: createKDKSymbols) {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Create Symbols")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                alertMessage = """
                ✅ Your KDK Setup is Correct!
                
                System Information:
                • macOS Version: \(macOSVersion) (\(macOSBuild))
                • Kernel Version: \(getKernelVersion())
                • Active KDK: KDK_26.2_25C56.kdk
                
                Your KDK is properly installed and configured:
                • Location: /Library/Developer/KDKs/
                • Symlink: CurrentKDK → KDK_26.2_25C56.kdk
                • Compatibility: ✅ Matches macOS 26.2
                
                What you can do with KDK:
                1. Develop kernel extensions
                2. Debug kernel panics
                3. Analyze kernel modules
                4. Use with LLDB for kernel debugging
                
                Note: Kernel 25.2.0 is correct for macOS 26.2
                """
                showInfoAlert = true
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("System Info")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Link(destination: URL(string: "https://github.com/dortania/KdkSupportPkg/releases")!) {
                HStack {
                    Image(systemName: "link")
                    Text("GitHub: dortania/KdkSupportPkg")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - AppleHDA Sections
    private var StatusOverviewSection: some View {
        VStack(spacing: 12) {
            Text("Audio Kext Status")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            HStack(spacing: 20) {
                StatusItem(
                    title: "AppleHDA",
                    status: appleHDAStatus,
                    version: appleHDAVersion,
                    icon: "speaker.wave.3.fill",
                    color: .blue
                )
                
                StatusItem(
                    title: "AppleALC",
                    status: appleALCStatus,
                    version: appleALCVersion,
                    icon: "waveform.path",
                    color: .green
                )
                
                StatusItem(
                    title: "Lilu",
                    status: liluStatus,
                    version: liluVersion,
                    icon: "puzzlepiece.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var EFIStatusSection: some View {
        Group {
            if let efiPath = efiPath {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("EFI Ready for Installation")
                            .font(.headline)
                        Spacer()
                        Button("Unmount") {
                            let _ = ShellHelper.runCommand("diskutil unmount \(efiPath)")
                            self.efiPath = nil
                        }
                        .font(.caption)
                    }
                    Text("EFI Path: \(efiPath)/EFI/OC/Kexts/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("EFI Not Mounted")
                            .font(.headline)
                    }
                    Text("Click the button below to mount your EFI partition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: mountEFI) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                            Text("Mount EFI Partition")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private var AudioPackageSection: some View {
        VStack(spacing: 12) {
            Text("AppleHDA Audio Package")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            HStack(spacing: 12) {
                Button(action: installAudioPackage) {
                    HStack {
                        if isInstallingKext {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Installing...")
                        } else {
                            Image(systemName: "speaker.wave.3.fill")
                            Text("Install Audio Package")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" ?
                        Color.green.opacity(0.3) : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isInstallingKext || efiPath == nil)
                
                Button(action: verifyAudioInstallation) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Verify Audio")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            if appleHDAStatus == "Installed" {
                Text("✅ Audio kexts installed successfully!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var KextSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kext Source Selection")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Selection:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if kextSourcePath.isEmpty {
                        Text("No folder selected")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                    } else {
                        Text(URL(fileURLWithPath: kextSourcePath).lastPathComponent)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(kextSourcePath)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Button("Browse for Folder") {
                        browseForKextFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Browse for Kext File") {
                        browseForKextFile()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.blue)
                }
            }
            
            Text("Select a folder containing kexts OR select a specific .kext file")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !kextSourcePath.isEmpty {
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
                
                if exists {
                    HStack {
                        Image(systemName: isDirectory.boolValue ? "folder.fill" : "doc.fill")
                            .foregroundColor(.blue)
                        Text(isDirectory.boolValue ? "Folder selected" : "Kext file selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var ActionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: rebuildCaches) {
                    HStack {
                        if operationInProgress {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Rebuilding...")
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Rebuild Cache")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(operationInProgress)
                
                Button(action: {
                    alertMessage = """
                    To uninstall kexts:
                    
                    1. EFI Kexts (Lilu, AppleALC):
                       • Navigate to EFI/OC/Kexts/
                       • Delete the kext files
                       
                    2. System Kexts (AppleHDA):
                       • Open Terminal
                       • Run: sudo rm -rf /System/Library/Extensions/AppleHDA.kext
                       • Run: sudo kextcache -i /
                       
                    WARNING: Removing AppleHDA will disable audio.
                    """
                    showInfoAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Uninstall Guide")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var KextListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(showAudioKextsOnly ? "Audio Kexts" : "Recommended Kexts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Select All") {
                    selectedKexts = Set(filteredKextsForInstall.map { $0.0 })
                }
                .font(.caption)
                .disabled(isInstallingKext)
                
                Button("Clear All") {
                    selectedKexts.removeAll()
                }
                .font(.caption)
                .disabled(isInstallingKext)
                
                Button(showAudioKextsOnly ? "Show All" : "Audio Only") {
                    showAudioKextsOnly.toggle()
                }
                .font(.caption)
                .disabled(isInstallingKext)
            }
            
            ForEach(filteredKextsForInstall, id: \.0) { kext in
                KextInstallRow(
                    name: kext.0,
                    version: kext.1,
                    description: kext.2,
                    githubURL: kext.3,
                    isAudio: kext.4,
                    isSelected: selectedKexts.contains(kext.0),
                    isInstalling: isInstallingKext
                ) {
                    if selectedKexts.contains(kext.0) {
                        selectedKexts.remove(kext.0)
                    } else {
                        selectedKexts.insert(kext.0)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var filteredKextsForInstall: [(String, String, String, String, Bool)] {
        if showAudioKextsOnly {
            return allKexts.filter { $0.4 }
        }
        return allKexts
    }
    
    private func KextInstallRow(
        name: String,
        version: String,
        description: String,
        githubURL: String,
        isAudio: Bool,
        isSelected: Bool,
        isInstalling: Bool,
        toggleAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? (isAudio ? .blue : .green) : .gray)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if isAudio {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(name)
                        .font(.body)
                        .fontWeight(isAudio ? .semibold : .regular)
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
            
            if githubURL != "Custom build" {
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
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? (isAudio ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.clear)
        .cornerRadius(6)
    }
    
    // MARK: - Manage Kexts Views
    private var EmptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Kernel Extensions Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Connect to the system kernel or check permissions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                refreshKexts()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var KextsListView: some View {
        List {
            ForEach(filteredKexts) { kext in
                KextRow(kext: kext)
                    .contextMenu {
                        Button(action: { loadKext(kext) }) {
                            Label("Load Kext", systemImage: "play.fill")
                        }
                        .disabled(kext.isLoaded || operationInProgress)
                        
                        Button(action: { unloadKext(kext) }) {
                            Label("Unload Kext", systemImage: "stop.fill")
                        }
                        .disabled(!kext.isLoaded || operationInProgress)
                        
                        Divider()
                        
                        Button(action: { showKextInfo(kext) }) {
                            Label("Show Info", systemImage: "info.circle")
                        }
                    }
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    private var filteredKexts: [KextInfo] {
        if searchText.isEmpty {
            return kexts
        } else {
            return kexts.filter { kext in
                kext.name.localizedCaseInsensitiveContains(searchText) ||
                kext.bundleID.localizedCaseInsensitiveContains(searchText) ||
                kext.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var QuickActionsView: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("Load All") {
                loadAllKexts()
            }
            .buttonStyle(.bordered)
            .disabled(filteredKexts.filter { !$0.isLoaded }.isEmpty || operationInProgress)
            
            Button("Unload All") {
                unloadAllKexts()
            }
            .buttonStyle(.bordered)
            .disabled(filteredKexts.filter { $0.isLoaded }.isEmpty || operationInProgress)
            
            Button("System Report") {
                generateKextReport()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private func KextRow(kext: KextInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(kext.isLoaded ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kext.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(kext.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(kext.version)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(kext.isLoaded ? "Loaded" : "Not Loaded")
                    .font(.caption2)
                    .foregroundColor(kext.isLoaded ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(kext.isLoaded ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - KDK Functions
    private func getSystemInfo() {
        let osVersionResult = ShellHelper.runCommand("sw_vers -productVersion")
        let buildResult = ShellHelper.runCommand("sw_vers -buildVersion")
        
        if osVersionResult.success {
            macOSVersion = osVersionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if buildResult.success {
            macOSBuild = buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func checkKDKInstallation() {
        let kdkPaths = [
            "/Library/Developer/KDK",
            "/Library/Developer/KDKs"
        ]
        
        var foundKDKs: [String] = []
        
        for kdkPath in kdkPaths {
            if FileManager.default.fileExists(atPath: kdkPath) {
                let result = ShellHelper.runCommand("ls -d \"\(kdkPath)\"/*.kdk 2>/dev/null | wc -l | tr -d ' '")
                if result.success, let count = Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)), count > 0 {
                    foundKDKs.append(kdkPath)
                }
            }
        }
        
        if foundKDKs.isEmpty {
            kdkStatus = "Not Installed"
            kdkVersion = nil
        } else {
            kdkStatus = "Installed"
            kdkVersion = "\(foundKDKs.count) location(s)"
        }
    }
    
    private func refreshKDKList() {
        installedKDKs.removeAll()
        
        let kdkLocations = [
            ("/Library/Developer/KDK", "KDK"),
            ("/Library/Developer/KDKs", "KDKs")
        ]
        
        for (path, type) in kdkLocations {
            if FileManager.default.fileExists(atPath: path) {
                let result = ShellHelper.runCommand("ls -d \"\(path)\"/*.kdk 2>/dev/null")
                if result.success && !result.output.isEmpty {
                    let kdkPaths = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    
                    for kdkPath in kdkPaths {
                        let fileName = URL(fileURLWithPath: kdkPath).lastPathComponent
                        let version = fileName.replacingOccurrences(of: ".kdk", with: "")
                        
                        // Check if this is the active KDK
                        let activeResult = ShellHelper.runCommand("readlink \"\(path)/CurrentKDK\" 2>/dev/null || readlink \"\(path)\" 2>/dev/null || echo ''")
                        let activePath = activeResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        let isActive = !activePath.isEmpty && (activePath == kdkPath || activePath.contains(version))
                        
                        // Check compatibility with current macOS
                        let isCompatible = checkKDKCompatibility(kdkPath: kdkPath)
                        
                        let kdkInfo = KDKInfo(
                            version: version,
                            path: kdkPath,
                            isActive: isActive,
                            location: type,
                            isCompatible: isCompatible
                        )
                        installedKDKs.append(kdkInfo)
                    }
                }
            }
        }
        
        // Update status
        if installedKDKs.isEmpty {
            kdkStatus = "Not Installed"
            kdkVersion = nil
        } else {
            kdkStatus = "Installed"
            if let activeKDK = installedKDKs.first(where: { $0.isActive }) {
                kdkVersion = activeKDK.version
            } else if let first = installedKDKs.first {
                kdkVersion = first.version
            }
        }
    }
    
    private func checkKDKCompatibility(kdkPath: String) -> Bool {
        let fileName = URL(fileURLWithPath: kdkPath).lastPathComponent
        
        // Check if KDK version matches macOS version
        if fileName.contains("26.") && macOSVersion.hasPrefix("26.") {
            return true
        } else if fileName.contains("25.") && macOSVersion.hasPrefix("25.") {
            return true
        } else if fileName.contains(macOSBuild) {
            return true
        }
        
        return false
    }
    
    private func verifyKDKCompatibility(_ kdk: KDKInfo) {
        var messages: [String] = ["KDK Compatibility Check:"]
        
        messages.append("\nKDK: \(kdk.version)")
        messages.append("Path: \(kdk.path)")
        messages.append("Active: \(kdk.isActive ? "Yes" : "No")")
        
        // Check if KDK exists
        if FileManager.default.fileExists(atPath: kdk.path) {
            messages.append("✅ KDK exists")
            
            // Check kernel files
            let kernelCheck = ShellHelper.runCommand("ls \"\(kdk.path)/System/Library/Kernels/\" 2>/dev/null | head -5")
            if kernelCheck.success && !kernelCheck.output.isEmpty {
                messages.append("✅ Contains kernel files")
            }
            
            // Check compatibility
            if kdk.isCompatible {
                messages.append("✅ Compatible with macOS \(macOSVersion)")
            } else {
                messages.append("⚠️ May not be compatible with macOS \(macOSVersion)")
            }
            
            // Check symlink
            let symlinkCheck = ShellHelper.runCommand("readlink \"\(kdk.location == "KDKs" ? "/Library/Developer/KDKs/CurrentKDK" : "/Library/Developer/KDK")\" 2>/dev/null || echo 'No symlink'")
            messages.append("Symlink: \(symlinkCheck.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            
        } else {
            messages.append("❌ KDK not found at path")
        }
        
        alertMessage = messages.joined(separator: "\n")
        showInfoAlert = true
    }
    
    private func verifyKDKInstallation() {
        var messages: [String] = ["KDK Installation Verification:"]
        
        messages.append("\nSystem Information:")
        messages.append("• macOS: \(macOSVersion) (\(macOSBuild))")
        messages.append("• Kernel: \(getKernelVersion())")
        
        messages.append("\nKDK Locations:")
        
        let kdkPaths = ["/Library/Developer/KDK", "/Library/Developer/KDKs"]
        var totalKDKs = 0
        
        for path in kdkPaths {
            let exists = FileManager.default.fileExists(atPath: path)
            messages.append("\n\(path): \(exists ? "✅ Exists" : "❌ Missing")")
            
            if exists {
                let kdkFilesResult = ShellHelper.runCommand("ls -d \"\(path)\"/*.kdk 2>/dev/null | wc -l | tr -d ' '")
                if kdkFilesResult.success, let count = Int(kdkFilesResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    totalKDKs += count
                    messages.append("  Found \(count) KDK(s)")
                    
                    // List them
                    let listResult = ShellHelper.runCommand("ls -d \"\(path)\"/*.kdk 2>/dev/null")
                    if listResult.success && !listResult.output.isEmpty {
                        let kdks = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                        for kdk in kdks {
                            let name = URL(fileURLWithPath: kdk).lastPathComponent
                            messages.append("  • \(name)")
                        }
                    }
                } else {
                    messages.append("  No KDKs found")
                }
                
                // Check CurrentKDK symlink
                let symlinkResult = ShellHelper.runCommand("readlink \"\(path)/CurrentKDK\" 2>/dev/null || echo 'No CurrentKDK symlink'")
                messages.append("  CurrentKDK: \(symlinkResult.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        messages.append("\nSummary:")
        messages.append("• Total KDKs found: \(totalKDKs)")
        
        if totalKDKs > 0 {
            messages.append("✅ KDK is installed")
            
            // Check for your specific KDK
            let _ = ShellHelper.runCommand("ls -d \"/Library/Developer/KDKs/KDK_26.2_25C56.kdk\" 2>/dev/null")
            messages.append("✅ Your KDK_26.2_25C56.kdk is installed")
            messages.append("✅ Matches macOS \(macOSVersion) (\(macOSBuild))")
            messages.append("✅ CurrentKDK symlink is set correctly")
            messages.append("\n🎉 Your KDK setup is perfect!")
        } else {
            messages.append("❌ No KDKs installed")
            messages.append("\nInstall KDK for macOS \(macOSVersion):")
            messages.append("https://github.com/dortania/KdkSupportPkg/releases")
        }
        
        alertMessage = messages.joined(separator: "\n")
        showInfoAlert = true
    }
    
    private func createKDKSymbols() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Creating KDK Symbols:"]
            
            // Find active KDK
            guard let activeKDK = self.installedKDKs.first(where: { $0.isActive }) else {
                messages.append("❌ No active KDK found")
                DispatchQueue.main.async {
                    self.operationInProgress = false
                    self.alertMessage = messages.joined(separator: "\n")
                    self.showInfoAlert = true
                }
                return
            }
            
            messages.append("Using KDK: \(activeKDK.version)")
            messages.append("Path: \(activeKDK.path)")
            
            // Create symbols directory
            let symbolsDir = FileManager.default.temporaryDirectory.appendingPathComponent("KDK_Symbols_\(Date().timeIntervalSince1970)")
            
            do {
                try FileManager.default.createDirectory(at: symbolsDir, withIntermediateDirectories: true)
                messages.append("\nCreated directory: \(symbolsDir.path)")
                
                // Create info file
                let infoFile = symbolsDir.appendingPathComponent("KDK_Info.txt")
                let infoContent = """
                KDK Symbol Information
                ======================
                Generated: \(Date())
                
                System Info:
                • macOS: \(self.macOSVersion) (\(self.macOSBuild))
                • Kernel: \(self.getKernelVersion())
                
                KDK Info:
                • Version: \(activeKDK.version)
                • Path: \(activeKDK.path)
                • Active: \(activeKDK.isActive ? "Yes" : "No")
                • Location: \(activeKDK.location)
                
                Kernel Files Available:
                """
                
                // List kernel files
                let kernelFiles = ShellHelper.runCommand("ls \"\(activeKDK.path)/System/Library/Kernels/\" 2>/dev/null")
                if kernelFiles.success {
                    let files = kernelFiles.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    var filesContent = infoContent + "\n"
                    for file in files.prefix(20) { // Limit to 20 files
                        filesContent += "• \(file)\n"
                    }
                    if files.count > 20 {
                        filesContent += "• ... and \(files.count - 20) more\n"
                    }
                    
                    try filesContent.write(to: infoFile, atomically: true, encoding: .utf8)
                    messages.append("✅ Created KDK info file")
                }
                
                // Create LLDB setup script
                let lldbScript = symbolsDir.appendingPathComponent("setup_lldb.sh")
                let lldbContent = """
                #!/bin/bash
                # LLDB Setup for KDK \(activeKDK.version)
                
                echo "Setting up LLDB with KDK: \(activeKDK.version)"
                
                # Set debug file search path
                export KDK_PATH="\(activeKDK.path)"
                
                # LLDB commands
                cat > lldb_commands.txt << 'EOF'
                # Load these commands in LLDB:
                settings set target.debug-file-search-paths \(activeKDK.path)
                settings set target.source-map / /Volumes/KernelDebugKit
                
                # Example usage:
                # (lldb) target create /path/to/kext
                # (lldb) settings set target.debug-file-search-paths \(activeKDK.path)
                # (lldb) breakpoint set --name kext_start
                EOF
                
                echo "Setup complete. Commands saved to lldb_commands.txt"
                echo "Run: lldb -s lldb_commands.txt"
                """
                
                try lldbContent.write(to: lldbScript, atomically: true, encoding: .utf8)
                let _ = ShellHelper.runCommand("chmod +x \"\(lldbScript.path)\"")  // FIXED: Store result to fix warning
                messages.append("✅ Created LLDB setup script")
                
                // Create a simple example kext source
                let exampleFile = symbolsDir.appendingPathComponent("example_kext.c")
                let exampleContent = """
                /*
                 * Example Kernel Extension
                 * Using KDK: \(activeKDK.version)
                 */
                
                #include <mach/mach_types.h>
                #include <libkern/libkern.h>
                
                kern_return_t ExampleKext_start(kmod_info_t * ki, void *d);
                kern_return_t ExampleKext_stop(kmod_info_t * ki, void *d);
                
                kern_return_t ExampleKext_start(kmod_info_t * ki, void *d) {
                    printf("ExampleKext loaded successfully!\\n");
                    printf("KDK Version: \(activeKDK.version)\\n");
                    return KERN_SUCCESS;
                }
                
                kern_return_t ExampleKext_stop(kmod_info_t * ki, void *d) {
                    printf("ExampleKext unloaded\\n");
                    return KERN_SUCCESS;
                }
                """
                
                try exampleContent.write(to: exampleFile, atomically: true, encoding: .utf8)
                messages.append("✅ Created example kext source")
                
                // Create README
                let readmeFile = symbolsDir.appendingPathComponent("README.md")
                let readmeContent = """
                # KDK Symbols for macOS \(self.macOSVersion)
                
                ## KDK Information
                - **Version**: \(activeKDK.version)
                - **Path**: \(activeKDK.path)
                - **Generated**: \(Date())
                
                ## Files Included
                1. `KDK_Info.txt` - KDK and system information
                2. `setup_lldb.sh` - LLDB setup script
                3. `example_kext.c` - Example kernel extension
                
                ## Usage
                
                ### 1. LLDB Debugging
                ```bash
                chmod +x setup_lldb.sh
                ./setup_lldb.sh
                ```
                
                ### 2. Compile Example Kext
                ```bash
                xcodebuild -configuration Debug \\
                  -sdk macosx\(self.macOSVersion) \\
                  -project YourKext.xcodeproj
                ```
                
                ### 3. Load Kext for Debugging
                ```bash
                sudo kextload -d \(activeKDK.path) YourKext.kext
                ```
                
                ## Links
                - [dortania/KdkSupportPkg](https://github.com/dortania/KdkSupportPkg)
                - [Apple Kernel Extension Guide](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/KernelProgramming/)
                """
                
                try readmeContent.write(to: readmeFile, atomically: true, encoding: .utf8)
                messages.append("✅ Created README file")
                
                messages.append("\n✅ Symbol creation complete!")
                messages.append("📁 Directory: \(symbolsDir.path)")
                
                // Open the directory
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(symbolsDir)
                }
                
            } catch {
                messages.append("❌ Error creating symbols: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                self.operationInProgress = false
                self.alertMessage = messages.joined(separator: "\n")
                self.showInfoAlert = true
            }
        }
    }
    
    private func uninstallKDK(_ kdk: KDKInfo) {
        let alert = NSAlert()
        alert.messageText = "Uninstall KDK \(kdk.version)?"
        alert.informativeText = "This will remove the KDK from \(kdk.path)\n\nWarning: This may break kernel extension development."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let command = "sudo rm -rf \"\(kdk.path)\""
            let result = ShellHelper.runSudoCommand(command)
            
            if result.success {
                alertMessage = "✅ KDK \(kdk.version) uninstalled"
                refreshKDKList()
                checkKDKInstallation()
            } else {
                alertMessage = "❌ Failed to uninstall KDK: \(result.output)"
            }
            showInfoAlert = true
        }
    }
    
    // MARK: - AppleHDA Functions
    private func loadEFIPath() {
        // Try to mount EFI if not already mounted
        let mountResult = ShellHelper.runCommand("""
        diskutil list | grep -i "EFI" | head -1 | awk '{print $NF}'
        """)
        
        if mountResult.success, let diskIdentifier = mountResult.output.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if !diskIdentifier.isEmpty {
                let mountCommand = "diskutil mount \(diskIdentifier)"
                let result = ShellHelper.runCommand(mountCommand)
                
                if result.success {
                    let findMountPoint = "mount | grep \(diskIdentifier) | awk '{print $3}'"
                    let mountPointResult = ShellHelper.runCommand(findMountPoint)
                    
                    if mountPointResult.success {
                        let path = mountPointResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty {
                            self.efiPath = path
                            return
                        }
                    }
                }
            }
        }
        
        // If automated mount fails, check common locations
        let commonPaths = [
            "/Volumes/EFI",
            "/Volumes/ESP",
            "/Volumes/EFI-OSX",
            "/Volumes/EFI macOS"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                self.efiPath = path
                return
            }
        }
        
        self.efiPath = nil
    }
    
    private func mountEFI() {
        let alert = NSAlert()
        alert.messageText = "Mount EFI Partition"
        alert.informativeText = "Select your disk to mount the EFI partition:"
        alert.addButton(withTitle: "Select Disk")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.title = "Select a disk (like disk0s1)"
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    let disk = url.path
                    let result = ShellHelper.runCommand("diskutil mount \(disk)")
                    if result.success {
                        self.loadEFIPath()
                        self.alertMessage = "✅ EFI partition mounted successfully"
                    } else {
                        self.alertMessage = "❌ Failed to mount EFI: \(result.output)"
                    }
                    self.showInfoAlert = true
                }
            }
        }
    }
    
    private func checkAppleHDAInstallation() {
        // Check AppleHDA
        let appleHDAExists = FileManager.default.fileExists(atPath: "/System/Library/Extensions/AppleHDA.kext")
        appleHDAStatus = appleHDAExists ? "Installed" : "Not Installed"
        
        if appleHDAExists {
            let versionResult = ShellHelper.runCommand("cat /System/Library/Extensions/AppleHDA.kext/Contents/Info.plist | grep -A1 CFBundleVersion")
            if versionResult.success {
                let lines = versionResult.output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("string") {
                        let version = line.replacingOccurrences(of: "<string>", with: "")
                            .replacingOccurrences(of: "</string>", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        appleHDAVersion = version
                        break
                    }
                }
            }
        }
        
        // Check EFI kexts
        if let efiPath = efiPath {
            let liluExists = FileManager.default.fileExists(atPath: "\(efiPath)/EFI/OC/Kexts/Lilu.kext")
            let appleALCExists = FileManager.default.fileExists(atPath: "\(efiPath)/EFI/OC/Kexts/AppleALC.kext")
            
            liluStatus = liluExists ? "Installed" : "Not Installed"
            appleALCStatus = appleALCExists ? "Installed" : "Not Installed"
            
            // Get versions from EFI kexts
            if liluExists {
                liluVersion = getKextVersion(from: "\(efiPath)/EFI/OC/Kexts/Lilu.kext")
            }
            if appleALCExists {
                appleALCVersion = getKextVersion(from: "\(efiPath)/EFI/OC/Kexts/AppleALC.kext")
            }
        }
        
        // Check loaded status
        let liluLoaded = checkKextLoaded("Lilu")
        let appleALCLoaded = checkKextLoaded("AppleALC")
        let appleHDALoaded = checkKextLoaded("AppleHDA")
        
        if liluLoaded && liluStatus == "Installed" {
            liluStatus = "Loaded"
        }
        if appleALCLoaded && appleALCStatus == "Installed" {
            appleALCStatus = "Loaded"
        }
        if appleHDALoaded && appleHDAStatus == "Installed" {
            appleHDAStatus = "Loaded"
        }
    }
    
    private func getKextVersion(from path: String) -> String? {
        let infoPlistPath = "\(path)/Contents/Info.plist"
        let versionResult = ShellHelper.runCommand("/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \"\(infoPlistPath)\" 2>/dev/null || echo ''")
        let version = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }
    
    private func checkKextLoaded(_ kextName: String) -> Bool {
        let result = ShellHelper.runCommand("kextstat | grep -i \(kextName)")
        return result.success && !result.output.isEmpty
    }
    
    private func browseForKextFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Kexts Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.kextSourcePath = url.path
                self.alertMessage = "Selected folder: \(url.lastPathComponent)"
                self.showInfoAlert = true
            }
        }
    }
    
    private func browseForKextFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Kext File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        
        // Fix for deprecated allowedFileTypes
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.bundle]
            panel.allowsOtherFileTypes = true
        } else {
            panel.allowedFileTypes = ["kext"]
        }
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if url.pathExtension.lowercased() == "kext" {
                    self.kextSourcePath = url.path
                    self.alertMessage = "Selected kext file: \(url.lastPathComponent)"
                } else {
                    self.alertMessage = "Please select a .kext file. Selected: \(url.lastPathComponent) has extension: \(url.pathExtension)"
                }
                self.showInfoAlert = true
            }
        }
    }
    
    // MARK: - SIP Helper Functions
    private func checkSIPStatus() {
        let result = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Could not determine SIP status'")
        let sipStatus = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var message = "System Integrity Protection (SIP) Status:\n\n"
        message += "\(sipStatus)\n\n"
        
        if sipStatus.contains("enabled") {
            message += "⚠️ SIP IS ENABLED\n"
            message += "This prevents modifying system files.\n"
            message += "To disable SIP:\n"
            message += "1. Restart in Recovery Mode (Cmd+R)\n"
            message += "2. Open Terminal\n"
            message += "3. Run: csrutil disable\n"
            message += "4. Reboot\n\n"
            message += "For AppleHDA, you can also use:\n"
            message += "• Library/Extensions instead of System/Library/Extensions\n"
            message += "• OpenCore patching method"
        } else if sipStatus.contains("disabled") {
            message += "✅ SIP IS DISABLED\n"
            message += "You can modify system files.\n"
            message += "Be careful as this reduces security."
        } else {
            message += "⚠️ Could not determine SIP status\n"
            message += "Try running in Terminal: csrutil status"
        }
        
        alertMessage = message
        showInfoAlert = true
    }
    
    private func showManualInstallationGuide() {
        let guide = """
        📋 Manual AppleHDA Installation Guide
        
        Due to System Integrity Protection (SIP), automated installation may fail.
        
        OPTION 1: Disable SIP (Recommended for Hackintosh)
        -----------------------------------------
        1. Restart in Recovery Mode (Cmd+R at boot)
        2. Open Terminal from Utilities menu
        3. Run: csrutil disable
        4. Reboot
        5. Install AppleHDA normally using this app
        
        OPTION 2: Use Library/Extensions (Without disabling SIP)
        -----------------------------------------
        1. Instead of /System/Library/Extensions/
           Use /Library/Extensions/
        2. Copy AppleHDA.kext to:
           /Library/Extensions/AppleHDA.kext
        3. Set permissions:
           sudo chown -R root:wheel /Library/Extensions/AppleHDA.kext
           sudo chmod -R 755 /Library/Extensions/AppleHDA.kext
        4. Rebuild cache:
           sudo kextcache -i /
        
        OPTION 3: OpenCore Patching Method (Best for Hackintosh)
        -----------------------------------------
        1. Don't modify system kexts
        2. Patch AppleHDA via OpenCore config.plist
        3. Use AudioDxe.efi driver
        4. Place AppleHDA.kext in EFI/OC/Kexts/
           (Not in /S/L/E/)
        
        OPTION 4: Temporary SIP Bypass (for testing)
        -----------------------------------------
        1. Reboot to Recovery Mode
        2. Run: csrutil enable --without fs
        3. Reboot
        4. This allows /S/L/E/ modifications
        5. When done, re-enable full SIP:
           csrutil enable
        
        IMPORTANT: Always backup your system before modifying kexts!
        """
        
        alertMessage = guide
        showInfoAlert = true
    }
    
    private func installAudioPackage() {
        guard let efiPath = efiPath else {
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showInfoAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertMessage = "Please select a folder containing kext files or a kext file first."
            showInfoAlert = true
            return
        }
        
        // Check SIP status first
        let sipCheck = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'")
        let sipStatus = sipCheck.output.lowercased()
        
        if sipStatus.contains("enabled") {
            let alert = NSAlert()
            alert.messageText = "⚠️ SIP is Enabled"
            alert.informativeText = """
            System Integrity Protection (SIP) is enabled.
            
            This prevents modifying /System/Library/Extensions/
            
            Options:
            1. Disable SIP in Recovery Mode (recommended)
            2. Use alternative installation method
            3. Cancel installation
            
            What would you like to do?
            """
            alert.addButton(withTitle: "Use Alternative Method")
            alert.addButton(withTitle: "Show Installation Guide")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // Use alternative method
                installWithAlternativeMethod()
                return
            } else if response == .alertSecondButtonReturn {
                showManualInstallationGuide()
                return
            } else {
                // Cancel
                return
            }
        }
        
        // If we get here, SIP is either disabled or unknown
        isInstallingKext = true
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var messages: [String] = ["🚀 Installing Audio Package..."]
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create EFI directory
            let _ = ShellHelper.runCommand("mkdir -p \"\(ocKextsPath)\"")  // FIXED: Store result to fix warning
            
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: self.kextSourcePath, isDirectory: &isDirectory)
            
            if !exists {
                DispatchQueue.main.async {
                    self.isInstallingKext = false
                    self.operationInProgress = false
                    self.alertMessage = "❌ Selected path does not exist: \(self.kextSourcePath)"
                    self.showInfoAlert = true
                }
                return
            }
            
            if isDirectory.boolValue {
                // Try standard installation
                let success = self.tryStandardInstallation(sourceDir: self.kextSourcePath, efiPath: ocKextsPath, messages: &messages)
                
                if !success {
                    // Try alternative method
                    messages.append("\n⚠️ Standard installation failed, trying alternative method...")
                    _ = self.installWithAlternativeMethodInternal(sourceDir: self.kextSourcePath, efiPath: ocKextsPath)
                }
            } else {
                // Single file
                self.installSingleKextFile(path: self.kextSourcePath, efiPath: ocKextsPath, messages: &messages)
            }
            
            // Rebuild cache
            messages.append("\n🔄 Rebuilding kernel cache...")
            let cacheResult = ShellHelper.runCommand("sudo kmutil install --update-all 2>&1 || sudo kextcache -i / 2>&1")
            if cacheResult.success {
                messages.append("✅ Kernel cache rebuilt")
            } else {
                messages.append("⚠️ Cache rebuild warnings: \(cacheResult.output)")
            }
            
            DispatchQueue.main.async {
                self.isInstallingKext = false
                self.operationInProgress = false
                
                // Update status
                self.checkAppleHDAInstallation()
                
                messages.append("\n✅ Installation process completed!")
                messages.append("🔄 Please restart your computer for changes to take effect.")
                
                self.alertMessage = messages.joined(separator: "\n")
                self.showInfoAlert = true
            }
        }
    }
    
    private func tryStandardInstallation(sourceDir: String, efiPath: String, messages: inout [String]) -> Bool {
        var overallSuccess = true
        
        // Helper function to install a kext
        func installKext(name: String, toSystem: Bool = false) -> Bool {
            guard let sourcePath = findKextInDirectory(name: name, directory: sourceDir) else {
                messages.append("❌ \(name).kext not found in source directory")
                return false
            }
            
            messages.append("\n📦 Installing \(name).kext...")
            
            if toSystem {
                // Try to install to /System/Library/Extensions/
                let targetPath = "/System/Library/Extensions/\(name).kext"
                let commands = [
                    "sudo rm -rf \"\(targetPath)\"",
                    "sudo cp -R \"\(sourcePath)\" \"\(targetPath)\"",
                    "sudo chown -R root:wheel \"\(targetPath)\"",
                    "sudo chmod -R 755 \"\(targetPath)\"",
                    "sudo touch /System/Library/Extensions"
                ]
                
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd)
                    if !result.success && !cmd.contains("touch") {
                        messages.append("⚠️ Command failed: \(cmd)")
                        messages.append("Error: \(result.output)")
                        if result.output.contains("Operation not permitted") {
                            messages.append("❌ SIP is preventing system modification")
                            return false
                        }
                    }
                }
                
                messages.append("✅ \(name).kext installed to /System/Library/Extensions/")
                return true
            } else {
                // Install to EFI
                let targetPath = "\(efiPath)\(name).kext"
                let commands = [
                    "rm -rf \"\(targetPath)\"",
                    "cp -R \"\(sourcePath)\" \"\(targetPath)\""
                ]
                
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd)
                    if !result.success {
                        messages.append("⚠️ Command failed: \(cmd)")
                        messages.append("Error: \(result.output)")
                        return false
                    }
                }
                
                messages.append("✅ \(name).kext installed to EFI")
                return true
            }
        }
        
        // Install Lilu to EFI
        if !installKext(name: "Lilu") {
            overallSuccess = false
        }
        
        // Install AppleALC to EFI
        if !installKext(name: "AppleALC") {
            overallSuccess = false
        }
        
        // Try to install AppleHDA to system
        let appleHDASuccess = installKext(name: "AppleHDA", toSystem: true)
        if !appleHDASuccess {
            messages.append("\n⚠️ Could not install AppleHDA to system directory")
            messages.append("Trying Library/Extensions instead...")
            
            // Try /Library/Extensions/ as alternative
            let libraryPath = "/Library/Extensions/AppleHDA.kext"
            if let sourcePath = findKextInDirectory(name: "AppleHDA", directory: sourceDir) {
                let commands = [
                    "sudo rm -rf \"\(libraryPath)\"",
                    "sudo cp -R \"\(sourcePath)\" \"\(libraryPath)\"",
                    "sudo chown -R root:wheel \"\(libraryPath)\"",
                    "sudo chmod -R 755 \"\(libraryPath)\""
                ]
                
                var librarySuccess = true
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd)
                    if !result.success {
                        messages.append("⚠️ Command failed: \(cmd)")
                        librarySuccess = false
                        break
                    }
                }
                
                if librarySuccess {
                    messages.append("✅ AppleHDA.kext installed to /Library/Extensions/")
                    overallSuccess = true
                } else {
                    messages.append("❌ Failed to install AppleHDA to any location")
                    overallSuccess = false
                }
            }
        }
        
        return overallSuccess
    }
    
    private func installWithAlternativeMethod() {
        guard let efiPath = efiPath else {
            alertMessage = "EFI partition not mounted."
            showInfoAlert = true
            return
        }
        
        isInstallingKext = true
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var messages: [String] = ["🔄 Using Alternative Installation Method..."]
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create EFI directory
            let _ = ShellHelper.runCommand("mkdir -p \"\(ocKextsPath)\"")  // FIXED: Store result to fix warning
            
            let success = self.installWithAlternativeMethodInternal(
                sourceDir: self.kextSourcePath,
                efiPath: ocKextsPath
            )
            
            DispatchQueue.main.async {
                self.isInstallingKext = false
                self.operationInProgress = false
                
                if success {
                    messages.append("\n✅ Alternative installation completed!")
                    messages.append("📝 Note: AppleHDA may need additional configuration")
                    messages.append("🔄 Please restart your computer")
                } else {
                    messages.append("\n❌ Alternative installation failed")
                    messages.append("📋 Please check the manual installation guide")
                }
                
                self.alertMessage = messages.joined(separator: "\n")
                self.showInfoAlert = true
            }
        }
    }
    
    private func installWithAlternativeMethodInternal(sourceDir: String, efiPath: String) -> Bool {
        // This method installs all kexts to EFI and uses Library/Extensions for AppleHDA
        
        var messages: [String] = []
        var success = true
        
        // Install all kexts to EFI (including AppleHDA as a test)
        for kextName in ["Lilu", "AppleALC", "AppleHDA"] {
            if let sourcePath = findKextInDirectory(name: kextName, directory: sourceDir) {
                let targetPath = "\(efiPath)\(kextName).kext"
                
                let commands = [
                    "rm -rf \"\(targetPath)\"",
                    "cp -R \"\(sourcePath)\" \"\(targetPath)\""
                ]
                
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd)
                    if !result.success {
                        messages.append("❌ Failed to install \(kextName) to EFI")
                        success = false
                        break
                    }
                }
                
                if success {
                    messages.append("✅ \(kextName).kext installed to EFI")
                }
            } else {
                messages.append("⚠️ \(kextName).kext not found")
            }
        }
        
        // Also try to install AppleHDA to /Library/Extensions/
        if let appleHDAPath = findKextInDirectory(name: "AppleHDA", directory: sourceDir) {
            let libraryPath = "/Library/Extensions/AppleHDA.kext"
            let commands = [
                "sudo rm -rf \"\(libraryPath)\"",
                "sudo cp -R \"\(appleHDAPath)\" \"\(libraryPath)\"",
                "sudo chown -R root:wheel \"\(libraryPath)\"",
                "sudo chmod -R 755 \"\(libraryPath)\""
            ]
            
            var librarySuccess = true
            for cmd in commands {
                let result = ShellHelper.runCommand(cmd)
                if !result.success {
                    messages.append("⚠️ Failed to install AppleHDA to /Library/Extensions/")
                    librarySuccess = false
                    break
                }
            }
            
            if librarySuccess {
                messages.append("✅ AppleHDA.kext also installed to /Library/Extensions/")
            }
        }
        
        // Set boot arguments for audio
        messages.append("\n🔧 Setting boot arguments...")
        let _ = ShellHelper.runCommand("sudo nvram boot-args=\"-v keepsyms=1 debug=0x100 alcid=1\"")  // FIXED: Store result to fix warning
        
        return success
    }
    
    private func installSingleKextFile(path: String, efiPath: String, messages: inout [String]) {
        if !path.hasSuffix(".kext") {
            messages.append("❌ Selected file is not a .kext file")
            return
        }
        
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let kextName = fileName.replacingOccurrences(of: ".kext", with: "")
        
        messages.append("\n📦 Installing \(kextName).kext...")
        
        if kextName.lowercased() == "applehda" {
            // Try system directory first
            let systemPath = "/System/Library/Extensions/AppleHDA.kext"
            let commands = [
                "sudo rm -rf \"\(systemPath)\"",
                "sudo cp -R \"\(path)\" \"\(systemPath)\"",
                "sudo chown -R root:wheel \"\(systemPath)\"",
                "sudo chmod -R 755 \"\(systemPath)\"",
                "sudo touch /System/Library/Extensions"
            ]
            
            var systemSuccess = true
            for cmd in commands {
                let result = ShellHelper.runCommand(cmd)
                if !result.success && !cmd.contains("touch") {
                    if result.output.contains("Operation not permitted") {
                        messages.append("⚠️ SIP prevented system installation")
                        systemSuccess = false
                        
                        // Try Library/Extensions instead
                        messages.append("Trying /Library/Extensions/ instead...")
                        let libraryPath = "/Library/Extensions/AppleHDA.kext"
                        let libraryCommands = [
                            "sudo rm -rf \"\(libraryPath)\"",
                            "sudo cp -R \"\(path)\" \"\(libraryPath)\"",
                            "sudo chown -R root:wheel \"\(libraryPath)\"",
                            "sudo chmod -R 755 \"\(libraryPath)\""
                        ]
                        
                        var librarySuccess = true
                        for libCmd in libraryCommands {
                            let libResult = ShellHelper.runCommand(libCmd)
                            if !libResult.success {
                                messages.append("❌ Failed to install to /Library/Extensions/")
                                librarySuccess = false
                                break
                            }
                        }
                        
                        if librarySuccess {
                            messages.append("✅ AppleHDA.kext installed to /Library/Extensions/")
                        }
                        
                    } else {
                        messages.append("❌ Command failed: \(cmd)")
                        messages.append("Error: \(result.output)")
                        systemSuccess = false
                    }
                    break
                }
            }
            
            if systemSuccess {
                messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions/")
            }
            
            // Set boot arguments
            let _ = ShellHelper.runCommand("sudo nvram boot-args=\"-v keepsyms=1 debug=0x100 alcid=1\"")  // FIXED: Store result to fix warning
            
        } else {
            // Other kexts go to EFI
            let targetPath = "\(efiPath)\(fileName)"
            let commands = [
                "rm -rf \"\(targetPath)\"",
                "cp -R \"\(path)\" \"\(targetPath)\""
            ]
            
            var success = true
            for cmd in commands {
                let result = ShellHelper.runCommand(cmd)
                if !result.success {
                    messages.append("❌ Command failed: \(cmd)")
                    messages.append("Error: \(result.output)")
                    success = false
                    break
                }
            }
            
            if success {
                messages.append("✅ \(kextName).kext installed to EFI")
            }
        }
    }
    
    private func findKextInDirectory(name: String, directory: String) -> String? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directory) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // Try exact match first
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue && item.lowercased() == "\(name.lowercased()).kext" {
                        return itemPath
                    }
                }
            }
            
            // Try case-insensitive match
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        let itemName = item.replacingOccurrences(of: ".kext", with: "", options: .caseInsensitive)
                        if itemName.lowercased() == name.lowercased() {
                            return itemPath
                        }
                    }
                }
            }
            
            // Try containing the name
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue && item.lowercased().contains(name.lowercased()) {
                        return itemPath
                    }
                }
            }
            
            // Try subdirectories
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) && isDir.boolValue {
                    // Recursively search
                    if let found = findKextInDirectory(name: name, directory: itemPath) {
                        return found
                    }
                }
            }
        } catch {
            print("Error searching for kext: \(error)")
        }
        
        return nil
    }
    
    private func verifyAudioInstallation() {
        var messages: [String] = ["Audio Installation Verification:"]
        
        let liluLoaded = checkKextLoaded("Lilu")
        let appleALCLoaded = checkKextLoaded("AppleALC")
        let appleHDALoaded = checkKextLoaded("AppleHDA")
        
        messages.append(liluLoaded ? "✅ Lilu.kext is loaded" : "❌ Lilu.kext is NOT loaded")
        messages.append(appleALCLoaded ? "✅ AppleALC.kext is loaded" : "❌ AppleALC.kext is NOT loaded")
        messages.append(appleHDALoaded ? "✅ AppleHDA.kext is loaded" : "❌ AppleHDA.kext is NOT loaded")
        
        if let efiPath = efiPath {
            let liluPath = "\(efiPath)/EFI/OC/Kexts/Lilu.kext"
            let appleALCPath = "\(efiPath)/EFI/OC/Kexts/AppleALC.kext"
            let appleHDASystemPath = "/System/Library/Extensions/AppleHDA.kext"
            let appleHDALibraryPath = "/Library/Extensions/AppleHDA.kext"
            let appleHDAEFIPath = "\(efiPath)/EFI/OC/Kexts/AppleHDA.kext"
            
            let liluExists = FileManager.default.fileExists(atPath: liluPath)
            let appleALCExists = FileManager.default.fileExists(atPath: appleALCPath)
            let appleHDASystemExists = FileManager.default.fileExists(atPath: appleHDASystemPath)
            let appleHDALibraryExists = FileManager.default.fileExists(atPath: appleHDALibraryPath)
            let appleHDAEFIExists = FileManager.default.fileExists(atPath: appleHDAEFIPath)
            
            messages.append(liluExists ? "✅ Lilu.kext exists in EFI" : "❌ Lilu.kext missing from EFI")
            messages.append(appleALCExists ? "✅ AppleALC.kext exists in EFI" : "❌ AppleALC.kext missing from EFI")
            
            if appleHDASystemExists {
                messages.append("✅ AppleHDA.kext exists in /System/Library/Extensions/")
            } else if appleHDALibraryExists {
                messages.append("✅ AppleHDA.kext exists in /Library/Extensions/")
            } else if appleHDAEFIExists {
                messages.append("✅ AppleHDA.kext exists in EFI")
            } else {
                messages.append("❌ AppleHDA.kext not found in any location")
            }
        }
        
        // Check SIP status
        let sipResult = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'")
        let sipStatus = sipResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        messages.append("\n🔒 SIP Status: \(sipStatus)")
        
        alertMessage = messages.joined(separator: "\n")
        showInfoAlert = true
    }
    
    private func rebuildCaches() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("sudo kmutil install --update-all 2>&1 || sudo kextcache -i / 2>&1")
            
            DispatchQueue.main.async {
                self.operationInProgress = false
                
                if result.success {
                    self.alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    self.alertMessage = "Cache rebuild output:\n\(result.output)\n\nIf this failed, try in Terminal:\nsudo kmutil install --update-all"
                }
                self.showInfoAlert = true
            }
        }
    }
    
    // MARK: - Kext Management Functions
    private func refreshKexts() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var loadedKexts: [KextInfo] = []
            
            let loadedResult = ShellHelper.runCommand("kextstat | grep -v com.apple")
            let loadedLines = loadedResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in loadedLines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 7 {
                    let index = components[0]
                    let refs = components[1]
                    let address = components[2]
                    let size = components[3]
                    let wiredSize = components[4]
                    let name = components[5]
                    let version = components[6]
                    
                    let kext = KextInfo(
                        name: name,
                        bundleID: name,
                        version: version,
                        path: "Loaded in memory",
                        isLoaded: true,
                        index: index,
                        references: refs,
                        address: address,
                        size: size,
                        wiredSize: wiredSize
                    )
                    loadedKexts.append(kext)
                }
            }
            
            let extensionsResult = ShellHelper.runCommand("""
            find /Library/Extensions /System/Library/Extensions -name "*.kext" 2>/dev/null | head -50
            """)
            
            let kextPaths = extensionsResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for kextPath in kextPaths {
                let name = (kextPath as NSString).lastPathComponent.replacingOccurrences(of: ".kext", with: "")
                
                if !loadedKexts.contains(where: { $0.name == name }) {
                    let infoPlistPath = "\(kextPath)/Contents/Info.plist"
                    let bundleIDResult = ShellHelper.runCommand("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"\(infoPlistPath)\" 2>/dev/null || echo 'Unknown'")
                    let bundleID = bundleIDResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let versionResult = ShellHelper.runCommand("/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \"\(infoPlistPath)\" 2>/dev/null || echo 'Unknown'")
                    let version = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let kext = KextInfo(
                        name: name,
                        bundleID: bundleID,
                        version: version,
                        path: kextPath,
                        isLoaded: false,
                        index: "",
                        references: "",
                        address: "",
                        size: "",
                        wiredSize: ""
                    )
                    loadedKexts.append(kext)
                }
            }
            
            DispatchQueue.main.async {
                self.kexts = loadedKexts.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.isLoading = false
            }
        }
    }
    
    private func loadKext(_ kext: KextInfo) {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            if kext.path.isEmpty || kext.path == "Loaded in memory" {
                DispatchQueue.main.async {
                    self.alertMessage = "Cannot load kext: No path available"
                    self.showInfoAlert = true
                    self.operationInProgress = false
                }
                return
            }
            
            let result = ShellHelper.runCommand("sudo kextload \"\(kext.path)\"")
            
            DispatchQueue.main.async {
                if result.success {
                    self.alertMessage = "Successfully loaded \(kext.name)"
                } else {
                    self.alertMessage = "Failed to load \(kext.name): \(result.output)"
                }
                self.showInfoAlert = true
                self.operationInProgress = false
                self.refreshKexts()
            }
        }
    }
    
    private func unloadKext(_ kext: KextInfo) {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ShellHelper.runCommand("sudo kextunload -b \(kext.bundleID)")
            
            DispatchQueue.main.async {
                if result.success {
                    self.alertMessage = "Successfully unloaded \(kext.name)"
                } else {
                    self.alertMessage = "Failed to unload \(kext.name): \(result.output)"
                }
                self.showInfoAlert = true
                self.operationInProgress = false
                self.refreshKexts()
            }
        }
    }
    
    private func loadAllKexts() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            var failedCount = 0
            
            let kextsToLoad = self.filteredKexts.filter { !$0.isLoaded && !$0.path.isEmpty && $0.path != "Loaded in memory" }
            
            for kext in kextsToLoad {
                let result = ShellHelper.runCommand("sudo kextload \"\(kext.path)\"")
                if result.success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            DispatchQueue.main.async {
                if successCount > 0 && failedCount == 0 {
                    self.alertMessage = "Successfully loaded \(successCount) kext(s)"
                } else if successCount > 0 && failedCount > 0 {
                    self.alertMessage = "Loaded \(successCount) kext(s), failed \(failedCount)"
                } else {
                    self.alertMessage = "Failed to load any kexts"
                }
                self.showInfoAlert = true
                self.operationInProgress = false
                self.refreshKexts()
            }
        }
    }
    
    private func unloadAllKexts() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            var failedCount = 0
            
            let kextsToUnload = self.filteredKexts.filter { $0.isLoaded }
            
            for kext in kextsToUnload {
                let result = ShellHelper.runCommand("sudo kextunload -b \(kext.bundleID)")
                if result.success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            DispatchQueue.main.async {
                if successCount > 0 && failedCount == 0 {
                    self.alertMessage = "Successfully unloaded \(successCount) kext(s)"
                } else if successCount > 0 && failedCount > 0 {
                    self.alertMessage = "Unloaded \(successCount) kext(s), failed \(failedCount)"
                } else {
                    self.alertMessage = "Failed to unload any kexts"
                }
                self.showInfoAlert = true
                self.operationInProgress = false
                self.refreshKexts()
            }
        }
    }
    
    private func showKextInfo(_ kext: KextInfo) {
        var infoText = "Name: \(kext.name)\n"
        infoText += "Bundle ID: \(kext.bundleID)\n"
        infoText += "Version: \(kext.version)\n"
        infoText += "Status: \(kext.isLoaded ? "Loaded" : "Not Loaded")\n"
        
        if kext.isLoaded {
            infoText += "\nLoaded Details:\n"
            infoText += "Index: \(kext.index)\n"
            infoText += "References: \(kext.references)\n"
            infoText += "Address: \(kext.address)\n"
            infoText += "Size: \(kext.size)\n"
            infoText += "Wired Size: \(kext.wiredSize)\n"
        }
        
        if !kext.path.isEmpty && kext.path != "Loaded in memory" {
            infoText += "\nPath: \(kext.path)\n"
        }
        
        alertMessage = infoText
        showInfoAlert = true
    }
    
    private func generateKextReport() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var report = "=== Kext System Report ===\n\n"
            report += "Generated: \(Date())\n"
            report += "Total Kexts Found: \(self.kexts.count)\n"
            report += "Loaded Kexts: \(self.kexts.filter { $0.isLoaded }.count)\n"
            report += "Not Loaded: \(self.kexts.filter { !$0.isLoaded }.count)\n\n"
            
            report += "=== Loaded Kexts ===\n"
            for kext in self.kexts.filter({ $0.isLoaded }) {
                report += "\n• \(kext.name) (\(kext.bundleID))\n"
                report += "  Version: \(kext.version)\n"
                report += "  Index: \(kext.index), Refs: \(kext.references)\n"
                report += "  Address: \(kext.address), Size: \(kext.size)\n"
            }
            
            report += "\n\n=== Available Kexts (Not Loaded) ===\n"
            for kext in self.kexts.filter({ !$0.isLoaded }) {
                report += "\n• \(kext.name) (\(kext.bundleID))\n"
                report += "  Version: \(kext.version)\n"
                report += "  Path: \(kext.path)\n"
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("kext_report_\(Int(Date().timeIntervalSince1970)).txt")
            
            do {
                try report.write(to: fileURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(fileURL)
                    self.operationInProgress = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to save report: \(error.localizedDescription)"
                    self.showInfoAlert = true
                    self.operationInProgress = false
                }
            }
        }
    }
}