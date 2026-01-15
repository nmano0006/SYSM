// Views/SystemInfoView.swift
import SwiftUI

struct SystemInfoView: View {
    @State private var systemInfo: [String: String] = [:]
    @State private var bootloaderDetails: [String: String] = [:]
    @State private var isLoading = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await refreshSystemInfo()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            
            Divider()
            
            if isLoading {
                VStack(spacing: 20) {
                    LoadingLogoView(size: 60)
                    Text("Loading system information...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    // Hardware Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            SystemInfoSection(title: "Hardware Information", items: getHardwareInfo())
                            SystemInfoSection(title: "Storage Information", items: getStorageInfo())
                            SystemInfoSection(title: "Network Information", items: getNetworkInfo())
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Hardware", systemImage: "desktopcomputer")
                    }
                    .tag(0)
                    
                    // Software Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            SystemInfoSection(title: "Operating System", items: getOSInfo())
                            SystemInfoSection(title: "Security Status", items: getSecurityInfo())
                            SystemInfoSection(title: "Boot Information", items: getBootInfo())
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Software", systemImage: "gear")
                    }
                    .tag(1)
                    
                    // Bootloader Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            if !bootloaderDetails.isEmpty {
                                SystemInfoSection(title: "Bootloader Details", items: bootloaderDetails)
                            } else {
                                Text("No bootloader information available")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Bootloader", systemImage: "platter.2.filled.ipad")
                    }
                    .tag(2)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            Task {
                await loadSystemInfo()
            }
        }
    }
    
    private func loadSystemInfo() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Load all system information on background thread
        let (systemInfoResult, bootloaderDetailsResult) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let systemInfo = self.gatherSystemInfo()
                let bootloaderDetails = ShellHelper.getBootloaderDetails()
                continuation.resume(returning: (systemInfo, bootloaderDetails))
            }
        }
        
        // Update UI on main thread
        await MainActor.run {
            self.systemInfo = systemInfoResult
            self.bootloaderDetails = bootloaderDetailsResult
            self.isLoading = false
        }
    }
    
    private func refreshSystemInfo() async {
        await loadSystemInfo()
    }
    
    private func gatherSystemInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // Get hardware info
        let hardwareModel = ShellHelper.runCommand("sysctl -n hw.model").output
        info["Model"] = hardwareModel.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cpuInfo = ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output
        info["CPU"] = cpuInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cpuCores = ShellHelper.runCommand("sysctl -n hw.ncpu").output
        info["CPU Cores"] = cpuCores.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let memorySize = ShellHelper.runCommand("sysctl -n hw.memsize").output
        if let bytes = UInt64(memorySize.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let gb = Double(bytes) / 1_073_741_824.0
            info["Memory"] = String(format: "%.1f GB", gb)
        }
        
        // Get OS info
        let osVersion = ShellHelper.runCommand("sw_vers -productVersion").output
        info["macOS Version"] = osVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let buildVersion = ShellHelper.runCommand("sw_vers -buildVersion").output
        info["Build Version"] = buildVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get disk info
        let diskInfo = ShellHelper.runCommand("df -h / | tail -1").output
        let diskComponents = diskInfo.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if diskComponents.count >= 5 {
            info["Disk Size"] = diskComponents[1]
            info["Disk Used"] = diskComponents[2]
            info["Disk Available"] = diskComponents[3]
            info["Disk Usage"] = diskComponents[4]
        }
        
        // Get network info
        let networkInterface = ShellHelper.runCommand("route get default | grep interface | awk '{print $2}'").output
        info["Network Interface"] = networkInterface.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get SIP status
        let sipStatus = ShellHelper.runCommand("csrutil status").output
        info["SIP Status"] = sipStatus.contains("disabled") ? "Disabled" : "Enabled"
        
        return info
    }
    
    private func getHardwareInfo() -> [String: String] {
        return [
            "Model": systemInfo["Model"] ?? "Unknown",
            "CPU": systemInfo["CPU"] ?? "Unknown",
            "CPU Cores": systemInfo["CPU Cores"] ?? "Unknown",
            "Memory": systemInfo["Memory"] ?? "Unknown",
            "Architecture": SystemInfo.isAppleSilicon() ? "Apple Silicon" : "Intel"
        ]
    }
    
    private func getStorageInfo() -> [String: String] {
        return [
            "Disk Size": systemInfo["Disk Size"] ?? "Unknown",
            "Disk Used": systemInfo["Disk Used"] ?? "Unknown",
            "Disk Available": systemInfo["Disk Available"] ?? "Unknown",
            "Disk Usage": systemInfo["Disk Usage"] ?? "Unknown",
            "Filesystem": bootloaderDetails["filesystem"] ?? "APFS"
        ]
    }
    
    private func getNetworkInfo() -> [String: String] {
        return [
            "Network Interface": systemInfo["Network Interface"] ?? "Unknown",
            "Hostname": ShellHelper.runCommand("hostname").output.trimmingCharacters(in: .whitespacesAndNewlines),
            "IP Address": getLocalIPAddress()
        ]
    }
    
    private func getOSInfo() -> [String: String] {
        return [
            "macOS Version": systemInfo["macOS Version"] ?? "Unknown",
            "Build Version": systemInfo["Build Version"] ?? "Unknown",
            "Kernel Version": ShellHelper.runCommand("uname -r").output.trimmingCharacters(in: .whitespacesAndNewlines),
            "Boot Volume": bootloaderDetails["currentBootVolume"] ?? "Unknown"
        ]
    }
    
    private func getSecurityInfo() -> [String: String] {
        return [
            "SIP Status": systemInfo["SIP Status"] ?? "Unknown",
            "Secure Boot": bootloaderDetails["secureBootModel"] ?? "Disabled",
            "Gatekeeper": getGatekeeperStatus(),
            "Full Disk Access": ShellHelper.checkFullDiskAccess() ? "Granted" : "Not Granted"
        ]
    }
    
    private func getBootInfo() -> [String: String] {
        return [
            "Bootloader": bootloaderDetails["bootloaderName"] ?? "Apple (Native)",
            "Bootloader Version": bootloaderDetails["bootloaderVersion"] ?? "Unknown",
            "Bootloader Mode": bootloaderDetails["bootloaderMode"] ?? "Normal",
            "Boot Args": bootloaderDetails["bootArgs"] ?? "None",
            "Boot Volume": bootloaderDetails["currentBootVolume"] ?? "Unknown"
        ]
    }
    
    private func getLocalIPAddress() -> String {
        let command = """
        ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
        """
        return ShellHelper.runCommand(command).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getGatekeeperStatus() -> String {
        let command = "spctl --status"
        let result = ShellHelper.runCommand(command)
        return result.output.contains("enabled") ? "Enabled" : "Disabled"
    }
}

struct SystemInfoSection: View {
    let title: String
    let items: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            
            ForEach(Array(items.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key + ":")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 150, alignment: .leading)
                    
                    Text(items[key] ?? "Unknown")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct LoadingLogoView: View {
    let size: CGFloat
    
    var body: some View {
        Image(systemName: "gear")
            .font(.system(size: size))
            .foregroundColor(.blue)
            .rotationEffect(.degrees(360))
            .animation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: true
            )
    }
}