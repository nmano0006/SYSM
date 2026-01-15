import SwiftUI
import Combine

struct SystemMaintenanceView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let tabs = [
        ("externaldrive.fill", "Drive Manager"),
        ("cpu", "OpenCore"),
        ("info.circle.fill", "System Info"),
        ("wrench.fill", "Tools"),
        ("gear", "Settings")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBarView
            
            Divider()
                .frame(height: 1)
                .background(Color.gray.opacity(0.3))
            
            // Content Area
            contentView
        }
        .frame(minWidth: 1200, minHeight: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("System Maintenance", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Maintenance")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("macOS Maintenance & Diagnostics Tool")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // System Status Indicators
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("System Normal")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: {
                    DriveManager.shared.refreshDrives()
                    alertMessage = "System refreshed successfully"
                    showAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Refresh All")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Tab Bar
    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabButton(
                    icon: tabs[index].0,
                    title: tabs[index].1,
                    isSelected: selectedTab == index,
                    action: { selectedTab = index }
                )
            }
        }
        .frame(height: 50)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            switch selectedTab {
            case 0:
                DriveManagerContentView()
            case 1:
                OpenCoreConfigEditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case 2:
                SystemInfoContentView()
            case 3:
                ToolsContentView()
            case 4:
                SettingsContentView()
            default:
                DriveManagerContentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}

// MARK: - Drive Manager Content
struct DriveManagerContentView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var showOperationAlert = false
    @State private var operationMessage = ""
    @State private var showConfirmDialog = false
    @State private var pendingAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Left side controls
                HStack(spacing: 12) {
                    Button(action: {
                        driveManager.refreshDrives()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Refresh")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Select All for Unmount") {
                        driveManager.selectAllForUnmount()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(driveManager.allDrives.filter { $0.isMounted }.isEmpty)
                    
                    Button("Clear All Selections") {
                        driveManager.clearAllSelections()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button("Mount All External") {
                        pendingAction = {
                            let result = driveManager.mountAllExternal()
                            operationMessage = result.message
                            showOperationAlert = true
                        }
                        showConfirmDialog = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Unmount All External") {
                        pendingAction = {
                            let result = driveManager.unmountAllExternal()
                            operationMessage = result.message
                            showOperationAlert = true
                        }
                        showConfirmDialog = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                // Right side controls
                HStack(spacing: 12) {
                    Text("\(driveManager.allDrives.filter { $0.isSelectedForMount }.count) selected for mount")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("\(driveManager.allDrives.filter { $0.isSelectedForUnmount }.count) selected for unmount")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: {
                        pendingAction = {
                            let result = driveManager.mountSelectedDrives()
                            operationMessage = result.message
                            showOperationAlert = true
                        }
                        showConfirmDialog = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.fill.badge.plus")
                                .font(.system(size: 12))
                            Text("Mount Selected")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(driveManager.mountSelection.isEmpty)
                    
                    Button(action: {
                        pendingAction = {
                            let result = driveManager.unmountSelectedDrives()
                            operationMessage = result.message
                            showOperationAlert = true
                        }
                        showConfirmDialog = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.fill.badge.minus")
                                .font(.system(size: 12))
                            Text("Unmount Selected")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(driveManager.unmountSelection.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
                .frame(height: 1)
                .background(Color.gray.opacity(0.3))
            
            // Drive List
            if driveManager.isLoading {
                loadingView
            } else if driveManager.allDrives.isEmpty {
                emptyStateView
            } else {
                driveListView
            }
        }
        .alert("Operation Result", isPresented: $showOperationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(operationMessage)
        }
        .confirmationDialog("Confirm Action", isPresented: $showConfirmDialog) {
            Button("Confirm") {
                pendingAction?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to proceed with this operation?")
        }
        .onAppear {
            driveManager.refreshDrives()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
            Text("Scanning for drives...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("This may take a moment")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Drives Found")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("No storage devices were detected on your system.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh Scan") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var driveListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(driveManager.allDrives) { drive in
                    DriveRowView(drive: drive)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Drive Row View
struct DriveRowView: View {
    let drive: DriveInfo
    @StateObject private var driveManager = DriveManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Drive Icon
            Image(systemName: getDriveIcon())
                .font(.system(size: 20))
                .foregroundColor(getDriveColor())
                .frame(width: 30)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(drive.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Text(drive.size)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    // Status Badge
                    statusBadge
                    
                    // Type Badge
                    typeBadge
                    
                    // Mount Point
                    if drive.isMounted {
                        Text(drive.mountPoint)
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Identifier
                    Text(drive.identifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action Button
            actionButton
                .frame(width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var statusBadge: some View {
        Group {
            if drive.isMounted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Mounted")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("Unmounted")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    private var typeBadge: some View {
        Group {
            if drive.isEFI {
                Text("EFI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            } else if drive.isInternal {
                Text("Internal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            } else {
                Text("External")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
    
    private var actionButton: some View {
        Group {
            if drive.isMounted {
                Button(action: {
                    if drive.mountPoint.contains("/System/Volumes/") ||
                       drive.mountPoint == "/" ||
                       drive.mountPoint.contains("home") ||
                       drive.mountPoint.contains("private/var") ||
                       drive.mountPoint.contains("Library/Developer") {
                        // System volume, show warning
                        print("⚠️ Cannot unmount system volume: \(drive.mountPoint)")
                    } else {
                        driveManager.toggleUnmountSelection(for: drive)
                    }
                }) {
                    Image(systemName: drive.isSelectedForUnmount ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(drive.isSelectedForUnmount ? .red : .gray)
                }
                .buttonStyle(.plain)
                .help("Select for unmount")
            } else {
                Button(action: {
                    driveManager.toggleMountSelection(for: drive)
                }) {
                    Image(systemName: drive.isSelectedForMount ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(drive.isSelectedForMount ? .green : .gray)
                }
                .buttonStyle(.plain)
                .help("Select for mount")
            }
        }
    }
    
    private func getDriveIcon() -> String {
        if drive.isEFI {
            return "cpu"
        } else if drive.isInternal {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
        }
    }
    
    private func getDriveColor() -> Color {
        if drive.isEFI {
            return .orange
        } else if drive.isInternal {
            return .blue
        } else {
            return .green
        }
    }
}

// MARK: - System Info Content
struct SystemInfoContentView: View {
    @State private var systemInfo: [String: String] = [:]
    @State private var hardwareInfo: [String: String] = [:]
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick Stats
                quickStatsView
                
                // Hardware Info
                InfoCard(title: "Hardware Information", icon: "desktopcomputer", color: .blue) {
                    ForEach(hardwareInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        SystemInfoRow(title: key, value: value)
                    }
                }
                
                // System Info
                InfoCard(title: "System Information", icon: "gear", color: .purple) {
                    ForEach(systemInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        SystemInfoRow(title: key, value: value)
                    }
                }
                
                // Security Info
                InfoCard(title: "Security Status", icon: "lock.shield", color: .green) {
                    SystemInfoRow(title: "SIP Status", value: getSIPStatus())
                    SystemInfoRow(title: "Gatekeeper", value: getGatekeeperStatus())
                    SystemInfoRow(title: "Firewall", value: getFirewallStatus())
                    SystemInfoRow(title: "FileVault", value: getFileVaultStatus())
                }
                
                // Storage Info
                InfoCard(title: "Storage Status", icon: "internaldrive", color: .orange) {
                    SystemInfoRow(title: "Boot Volume", value: getBootVolume())
                    SystemInfoRow(title: "Total Space", value: getTotalStorage())
                    SystemInfoRow(title: "Used Space", value: getUsedStorage())
                    SystemInfoRow(title: "Free Space", value: getFreeStorage())
                }
                
                // Network Info
                InfoCard(title: "Network Information", icon: "network", color: .indigo) {
                    SystemInfoRow(title: "Hostname", value: getHostname())
                    SystemInfoRow(title: "IP Address", value: getIPAddress())
                    SystemInfoRow(title: "MAC Address", value: getMACAddress())
                    SystemInfoRow(title: "Network Services", value: getNetworkServicesCount())
                }
            }
            .padding()
        }
        .onAppear {
            loadSystemInfo()
        }
    }
    
    private var quickStatsView: some View {
        HStack(spacing: 16) {
            QuickStatCard(
                title: "CPU Usage",
                value: getCPUUsage(),
                icon: "cpu",
                color: .blue,
                isLoading: isLoading
            )
            
            QuickStatCard(
                title: "Memory",
                value: getMemoryUsage(),
                icon: "memorychip",
                color: .green,
                isLoading: isLoading
            )
            
            QuickStatCard(
                title: "Storage",
                value: getStorageUsage(),
                icon: "internaldrive",
                color: .orange,
                isLoading: isLoading
            )
            
            QuickStatCard(
                title: "Uptime",
                value: getUptime(),
                icon: "clock",
                color: .purple,
                isLoading: isLoading
            )
        }
        .padding(.horizontal)
    }
    
    private func loadSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let hardware = collectHardwareInfo()
            let system = collectSystemInfo()
            
            DispatchQueue.main.async {
                hardwareInfo = hardware
                systemInfo = system
                isLoading = false
            }
        }
    }
    
    private func collectHardwareInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // CPU Info
        let cpuBrand = ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string")
        let cpuCores = ShellHelper.runCommand("sysctl -n hw.physicalcpu")
        let cpuThreads = ShellHelper.runCommand("sysctl -n hw.logicalcpu")
        
        info["Processor"] = cpuBrand.output.trimmingCharacters(in: .whitespacesAndNewlines)
        info["Cores"] = cpuCores.output.trimmingCharacters(in: .whitespacesAndNewlines)
        info["Threads"] = cpuThreads.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // GPU Info
        let gpuInfo = ShellHelper.runCommand("system_profiler SPDisplaysDataType | grep 'Chipset Model' | head -1")
        info["Graphics"] = gpuInfo.output.replacingOccurrences(of: "Chipset Model:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Model Info
        let modelInfo = ShellHelper.runCommand("sysctl -n hw.model")
        info["Model"] = modelInfo.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Serial Number
        let serialInfo = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Serial Number'")
        info["Serial"] = serialInfo.output.replacingOccurrences(of: "Serial Number:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Memory
        let memoryInfo = ShellHelper.runCommand("sysctl -n hw.memsize")
        if let bytes = UInt64(memoryInfo.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let gb = Double(bytes) / 1_073_741_824.0
            info["Memory"] = String(format: "%.1f GB", gb)
        }
        
        return info
    }
    
    private func collectSystemInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // macOS Version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        info["macOS Version"] = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        // Build Version
        let buildInfo = ShellHelper.runCommand("sw_vers -buildVersion")
        info["Build"] = buildInfo.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Kernel Version
        let kernelInfo = ShellHelper.runCommand("uname -r")
        info["Kernel"] = kernelInfo.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Boot Arguments
        let bootArgs = ShellHelper.runCommand("nvram boot-args 2>/dev/null || echo 'None'")
        info["Boot Args"] = bootArgs.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Uptime
        info["Uptime"] = getUptime()
        
        return info
    }
    
    private func getSIPStatus() -> String {
        let result = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'")
        let status = result.output.lowercased()
        if status.contains("enabled") {
            return "Enabled"
        } else if status.contains("disabled") {
            return "Disabled"
        }
        return "Unknown"
    }
    
    private func getGatekeeperStatus() -> String {
        let result = ShellHelper.runCommand("spctl --status 2>/dev/null")
        let status = result.output.lowercased()
        if status.contains("enabled") {
            return "Enabled"
        } else if status.contains("disabled") {
            return "Disabled"
        }
        return "Unknown"
    }
    
    private func getFirewallStatus() -> String {
        let result = ShellHelper.runCommand("defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo '0'")
        let status = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case "0": return "Disabled"
        case "1": return "Enabled"
        case "2": return "Enabled (Block All)"
        default: return "Unknown"
        }
    }
    
    private func getFileVaultStatus() -> String {
        let result = ShellHelper.runCommand("fdesetup status 2>/dev/null")
        let status = result.output.lowercased()
        if status.contains("on") {
            return "Enabled"
        } else if status.contains("off") {
            return "Disabled"
        }
        return "Unknown"
    }
    
    private func getBootVolume() -> String {
        let result = ShellHelper.runCommand("diskutil info / | grep 'Device Node:' | awk '{print $3}'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getTotalStorage() -> String {
        let result = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $2}'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getUsedStorage() -> String {
        let result = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $3}'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getFreeStorage() -> String {
        let result = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $4}'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getHostname() -> String {
        let result = ShellHelper.runCommand("hostname")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getIPAddress() -> String {
        let result = ShellHelper.runCommand("ipconfig getifaddr en0 2>/dev/null || echo 'Not Connected'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getMACAddress() -> String {
        let result = ShellHelper.runCommand("ifconfig en0 | grep ether | awk '{print $2}'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getNetworkServicesCount() -> String {
        let result = ShellHelper.runCommand("networksetup -listallnetworkservices | wc -l | awk '{print $1-1}'")
        return "\(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) services"
    }
    
    private func getCPUUsage() -> String {
        let result = ShellHelper.runCommand("top -l 1 | grep 'CPU usage' | awk '{print $3}' | sed 's/%//'")
        let usage = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(usage)%"
    }
    
    private func getMemoryUsage() -> String {
        let result = ShellHelper.runCommand("memory_pressure | grep 'System-wide memory free percentage:' | awk '{print $5}' | sed 's/%//'")
        let freePercent = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let percent = Double(freePercent) {
            let usedPercent = 100 - percent
            return "\(String(format: "%.1f", usedPercent))%"
        }
        return "Calculating..."
    }
    
    private func getStorageUsage() -> String {
        let used = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $5}'")
        return used.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getUptime() -> String {
        let result = ShellHelper.runCommand("uptime | awk '{print $3 $4}' | sed 's/,//'")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Info Components
struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SystemInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(width: 140, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200, alignment: .trailing)
        }
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Tools Content
struct ToolsContentView: View {
    @State private var selectedTool: String?
    @State private var showToolResult = false
    @State private var toolResult = ""
    @State private var isRunningTool = false
    
    let tools = [
        ("Clear Cache", "trash", "Clear system and user caches", clearCache),
        ("Repair Permissions", "wrench", "Repair disk permissions", repairPermissions),
        ("Verify Disk", "checkmark.shield", "Verify disk integrity", verifyDisk),
        ("Rebuild Spotlight", "magnifyingglass", "Rebuild Spotlight index", rebuildSpotlight),
        ("Flush DNS", "network", "Flush DNS cache", flushDNS),
        ("Reset SMC", "power", "Reset System Management Controller", resetSMC),
        ("Reset NVRAM", "memorychip", "Reset NVRAM/PRAM", resetNVRAM)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("System Maintenance Tools")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                Text("Use these tools to perform common system maintenance tasks. Some actions may require administrator privileges.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(tools, id: \.0) { tool in
                        ToolCard(
                            title: tool.0,
                            icon: tool.1,
                            description: tool.2,
                            isSelected: selectedTool == tool.0,
                            isRunning: isRunningTool && selectedTool == tool.0,
                            action: {
                                selectedTool = tool.0
                                runTool(action: tool.3)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                if !toolResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tool Output")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            Text(toolResult)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(height: 150)
                    }
                    .padding()
                }
            }
            .padding(.bottom)
        }
        .alert("Tool Result", isPresented: $showToolResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(toolResult)
        }
    }
    
    private func runTool(action: @Sendable @escaping () async -> (output: String, success: Bool)) {
        isRunningTool = true
        
        Task {
            let result = await action()
            
            await MainActor.run {
                toolResult = result.output
                showToolResult = true
                isRunningTool = false
            }
        }
    }
    
    private static func clearCache() async -> (output: String, success: Bool) {
        print("🔧 Clearing system caches...")
        
        var output = ""
        var success = false
        
        // Clear user cache
        let userCache = ShellHelper.runCommand("rm -rf ~/Library/Caches/* 2>/dev/null")
        output += "User Cache: \(userCache.success ? "Cleared" : "Failed")\n"
        
        // Clear system cache (requires sudo)
        let systemCache = ShellHelper.runSudoCommand("rm -rf /Library/Caches/* 2>/dev/null")
        output += "System Cache: \(systemCache.success ? "Cleared" : "Failed")\n"
        
        // Clear DNS cache
        let dnsCache = ShellHelper.runSudoCommand("dscacheutil -flushcache; killall -HUP mDNSResponder")
        output += "DNS Cache: \(dnsCache.success ? "Cleared" : "Failed")\n"
        
        success = userCache.success || systemCache.success || dnsCache.success
        
        if success {
            output += "\n✅ Caches cleared successfully!"
        } else {
            output += "\n⚠️ Some cache clearing operations failed"
        }
        
        return (output, success)
    }
    
    private static func repairPermissions() async -> (output: String, success: Bool) {
        print("🔧 Repairing disk permissions...")
        
        var output = "Repairing Disk Permissions...\n"
        
        // For macOS 10.11 and later, diskutil is used
        let result = ShellHelper.runSudoCommand("diskutil verifyVolume / 2>/dev/null")
        
        if result.success {
            output += "✅ Disk verification completed\n"
            
            // Try repair if needed
            let repairResult = ShellHelper.runSudoCommand("diskutil repairVolume / 2>/dev/null")
            if repairResult.success {
                output += "✅ Disk repair completed\n"
            } else {
                output += "ℹ️ No repair needed or repair not supported\n"
            }
        } else {
            output += "⚠️ Disk verification failed\n"
        }
        
        // Check for disk errors
        let diskErrors = ShellHelper.runCommand("diskutil list | grep -i 'failed' || echo 'No disk errors found'")
        output += "\nDisk Status: \(diskErrors.output)"
        
        return (output, result.success)
    }
    
    private static func verifyDisk() async -> (output: String, success: Bool) {
        print("🔧 Verifying disk integrity...")
        
        let result = ShellHelper.runSudoCommand("diskutil verifyVolume / 2>/dev/null")
        
        if result.success {
            return ("✅ Disk verification completed successfully\n\(result.output)", true)
        } else {
            return ("⚠️ Disk verification failed\n\(result.output)", false)
        }
    }
    
    private static func rebuildSpotlight() async -> (output: String, success: Bool) {
        print("🔧 Rebuilding Spotlight index...")
        
        // Stop Spotlight
        let stopResult = ShellHelper.runSudoCommand("mdutil -E / 2>/dev/null")
        
        var output = "Rebuilding Spotlight index...\n"
        
        if stopResult.success {
            output += "✅ Spotlight indexing stopped\n"
            
            // Delete Spotlight index
            let deleteResult = ShellHelper.runSudoCommand("rm -rf /.Spotlight-V100/* 2>/dev/null")
            if deleteResult.success {
                output += "✅ Old index deleted\n"
            }
            
            // Start Spotlight
            let startResult = ShellHelper.runSudoCommand("mdutil -i on / 2>/dev/null")
            if startResult.success {
                output += "✅ Spotlight indexing restarted\n"
                output += "\nℹ️ Spotlight will reindex in the background. This may take some time."
            }
        } else {
            output += "⚠️ Failed to stop Spotlight\n"
        }
        
        return (output, stopResult.success)
    }
    
    private static func flushDNS() async -> (output: String, success: Bool) {
        print("🔧 Flushing DNS cache...")
        
        var commands = [
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder"
        ]
        
        // macOS version specific commands
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        if osVersion.majorVersion >= 11 {
            commands.append("killall -HUP mDNSResponderHelper")
        }
        
        var output = "Flushing DNS cache...\n"
        var success = false
        
        for cmd in commands {
            let result = ShellHelper.runSudoCommand(cmd)
            output += "\(cmd): \(result.success ? "Success" : "Failed")\n"
            if result.success {
                success = true
            }
        }
        
        if success {
            output += "\n✅ DNS cache flushed successfully!"
        } else {
            output += "\n⚠️ DNS cache flush may have failed"
        }
        
        return (output, success)
    }
    
    private static func resetSMC() async -> (output: String, success: Bool) {
        print("🔧 Resetting SMC...")
        
        let output = """
        ℹ️ System Management Controller Reset Instructions:
        
        For Macs with Apple Silicon (M1, M2, M3):
        1. Shut down your Mac
        2. Wait 10 seconds
        3. Press and hold the power button for 10 seconds
        4. Release the power button
        5. Wait a few seconds, then press the power button to turn on your Mac
        
        For Macs with T2 chip:
        1. Shut down your Mac
        2. Press and hold Control-Option-Shift for 7 seconds
        3. While holding those keys, press and hold the power button for 7 seconds
        4. Release all keys, wait a few seconds
        5. Press the power button to turn on your Mac
        
        For other Intel Macs:
        1. Shut down your Mac
        2. Press Shift-Control-Option on the left side of the keyboard
        3. While holding those keys, press the power button
        4. Hold all keys for 10 seconds
        5. Release all keys
        6. Press the power button to turn on your Mac
        
        Note: This cannot be performed programmatically. Please follow the manual steps above.
        """
        
        return (output, true)
    }
    
    private static func resetNVRAM() async -> (output: String, success: Bool) {
        print("🔧 Resetting NVRAM...")
        
        let output = """
        ℹ️ NVRAM/PRAM Reset Instructions:
        
        1. Shut down your Mac
        2. Press the power button
        3. Immediately press and hold Command-Option-P-R
        4. Hold the keys for about 20 seconds
        5. Release the keys during startup
        
        Your Mac will restart with NVRAM reset.
        This will reset settings like:
        • Speaker volume
        • Screen resolution
        • Startup disk selection
        • Recent kernel panic information
        
        Note: This cannot be performed programmatically. Please follow the manual steps above.
        """
        
        return (output, true)
    }
}

struct ToolCard: View {
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? .blue : .primary)
                    }
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}

// MARK: - Settings Content
struct SettingsContentView: View {
    @AppStorage("autoRefreshDrives") private var autoRefreshDrives = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("showSystemVolumes") private var showSystemVolumes = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("theme") private var theme = "system"
    
    let refreshIntervals = [15, 30, 60, 120, 300]
    let themes = ["system", "light", "dark"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Application Settings
                settingsSection(title: "Application Settings", icon: "app.badge") {
                    Toggle("Auto-refresh drives", isOn: $autoRefreshDrives)
                        .toggleStyle(.switch)
                    
                    if autoRefreshDrives {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Refresh Interval")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $refreshInterval) {
                                ForEach(refreshIntervals, id: \.self) { interval in
                                    Text("\(interval) seconds").tag(interval)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    Toggle("Show system volumes", isOn: $showSystemVolumes)
                        .toggleStyle(.switch)
                    
                    Toggle("Enable notifications", isOn: $enableNotifications)
                        .toggleStyle(.switch)
                }
                
                // Display Settings
                settingsSection(title: "Display Settings", icon: "display") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $theme) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // About Section
                settingsSection(title: "About", icon: "info.circle") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Version")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2.7.8.1.0")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Build")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2025.12.29")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        Divider()
                        
                        Button("Check for Updates") {
                            checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("View Documentation") {
                            // Open documentation
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Danger Zone
                settingsSection(title: "Advanced", icon: "exclamationmark.triangle", color: .red) {
                    VStack(spacing: 12) {
                        Text("These actions are irreversible and may affect system stability.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Reset All Settings") {
                            resetSettings()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Button("Clear All Data") {
                            clearAllData()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding()
        }
    }
    
    private func settingsSection<Content: View>(title: String, icon: String, color: Color = .blue, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 16, content: content)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private func checkForUpdates() {
        print("Checking for updates...")
        // Implement update checking logic
    }
    
    private func resetSettings() {
        print("Resetting settings...")
        // Implement settings reset logic
    }
    
    private func clearAllData() {
        print("Clearing all data...")
        // Implement data clearing logic
    }
}

// MARK: - Preview
struct SystemMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        SystemMaintenanceView()
            .frame(width: 1200, height: 800)
    }
}