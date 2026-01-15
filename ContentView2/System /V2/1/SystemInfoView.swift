import SwiftUI

struct SystemInfoView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedDrive: DriveInfo?
    @State private var systemInfo: [String: String] = [:]
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        refreshSystemInfo()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                
                // System Overview Cards
                SystemOverviewCards
                
                // Hardware Information
                HardwareInfoSection
                
                // Software Information
                SoftwareInfoSection
                
                // Network Information
                NetworkInfoSection
            }
            .padding()
        }
        .onAppear {
            refreshSystemInfo()
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive, driveManager: driveManager)
        }
    }
    
    private var SystemOverviewCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            InfoCard(
                title: "Computer Name",
                value: systemInfo["computerName"] ?? "Unknown",
                icon: "desktopcomputer",
                color: .blue
            )
            
            InfoCard(
                title: "Model",
                value: systemInfo["modelIdentifier"] ?? "Unknown",
                icon: "macbook",
                color: .purple
            )
            
            InfoCard(
                title: "Processor",
                value: systemInfo["processor"] ?? "Unknown",
                icon: "cpu",
                color: .orange
            )
            
            InfoCard(
                title: "Memory",
                value: systemInfo["memory"] ?? "Unknown",
                icon: "memorychip",
                color: .green
            )
            
            InfoCard(
                title: "macOS Version",
                value: systemInfo["macosVersion"] ?? "Unknown",
                icon: "apple.logo",
                color: .red
            )
            
            InfoCard(
                title: "Uptime",
                value: systemInfo["uptime"] ?? "Unknown",
                icon: "clock",
                color: .teal
            )
        }
        .padding(.horizontal)
    }
    
    private var HardwareInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Hardware Information", icon: "desktopcomputer")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Model Identifier:", value: systemInfo["modelIdentifier"] ?? "Unknown")
                InfoRow(label: "Serial Number:", value: systemInfo["serialNumber"] ?? "Unknown")
                InfoRow(label: "Processor:", value: systemInfo["processor"] ?? "Unknown")
                InfoRow(label: "Processor Cores:", value: systemInfo["processorCores"] ?? "Unknown")
                InfoRow(label: "Memory:", value: systemInfo["memory"] ?? "Unknown")
                InfoRow(label: "Graphics:", value: systemInfo["graphics"] ?? "Unknown")
                InfoRow(label: "Storage:", value: systemInfo["storage"] ?? "Unknown")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var SoftwareInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Software Information", icon: "apple.logo")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "macOS Version:", value: systemInfo["macosVersion"] ?? "Unknown")
                InfoRow(label: "Build Number:", value: systemInfo["buildNumber"] ?? "Unknown")
                InfoRow(label: "Kernel Version:", value: systemInfo["kernelVersion"] ?? "Unknown")
                InfoRow(label: "Boot Volume:", value: systemInfo["bootVolume"] ?? "Unknown")
                InfoRow(label: "Secure Boot:", value: systemInfo["secureBoot"] ?? "Unknown")
                InfoRow(label: "SIP Status:", value: systemInfo["sipStatus"] ?? "Unknown")
                InfoRow(label: "System Uptime:", value: systemInfo["uptime"] ?? "Unknown")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var NetworkInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Network Information", icon: "network")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Hostname:", value: systemInfo["hostname"] ?? "Unknown")
                InfoRow(label: "Ethernet IP:", value: systemInfo["ethernetIP"] ?? "Not Connected")
                InfoRow(label: "Wi-Fi IP:", value: systemInfo["wifiIP"] ?? "Not Connected")
                InfoRow(label: "MAC Address:", value: systemInfo["macAddress"] ?? "Unknown")
                InfoRow(label: "DNS Servers:", value: systemInfo["dnsServers"] ?? "Unknown")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func InfoCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func SectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private func refreshSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Removed ShellHelper.shared instance, using static methods directly
            var info: [String: String] = [:]
            
            // Get computer name
            let hostname = ShellHelper.runCommand("scutil --get ComputerName").output
            info["computerName"] = hostname.isEmpty ? "Unknown" : hostname
            
            // Get model identifier
            let model = ShellHelper.runCommand("sysctl -n hw.model").output
            info["modelIdentifier"] = model.isEmpty ? "Unknown" : model
            
            // Get processor info
            let processor = ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output
            info["processor"] = processor.isEmpty ? "Unknown" : processor
            
            let cores = ShellHelper.runCommand("sysctl -n hw.ncpu").output
            info["processorCores"] = cores.isEmpty ? "Unknown" : "\(cores) cores"
            
            // Get memory info
            let memory = ShellHelper.runCommand("sysctl -n hw.memsize").output
            if let memBytes = UInt64(memory), memBytes > 0 {
                let memGB = Double(memBytes) / 1_073_741_824.0
                info["memory"] = String(format: "%.1f GB", memGB)
            } else {
                info["memory"] = "Unknown"
            }
            
            // Get macOS version
            let osVersion = ShellHelper.runCommand("sw_vers -productVersion").output
            info["macosVersion"] = osVersion.isEmpty ? "Unknown" : "macOS \(osVersion)"
            
            let buildNumber = ShellHelper.runCommand("sw_vers -buildVersion").output
            info["buildNumber"] = buildNumber.isEmpty ? "Unknown" : buildNumber
            
            // Get kernel version
            let kernel = ShellHelper.runCommand("uname -r").output
            info["kernelVersion"] = kernel.isEmpty ? "Unknown" : kernel
            
            // Get serial number
            let serial = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Serial Number' | awk '{print $NF}'").output
            info["serialNumber"] = serial.isEmpty ? "Unknown" : serial
            
            // Get graphics info
            let graphics = ShellHelper.runCommand("system_profiler SPDisplaysDataType | grep 'Chipset Model:' | head -1 | awk -F': ' '{print $2}'").output
            info["graphics"] = graphics.isEmpty ? "Unknown" : graphics
            
            // Get storage info
            let storage = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $2}'").output
            info["storage"] = storage.isEmpty ? "Unknown" : storage
            
            // Get boot volume
            let bootVolume = ShellHelper.runCommand("diskutil info / | grep 'Device Node:' | awk '{print $NF}'").output
            info["bootVolume"] = bootVolume.isEmpty ? "Unknown" : bootVolume
            
            // Get SIP status
            let sipStatus = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output
            info["sipStatus"] = sipStatus.isEmpty ? "Unknown" : sipStatus
            
            // Get uptime
            let uptime = ShellHelper.runCommand("uptime | awk '{print $3, $4}' | sed 's/,//'").output
            info["uptime"] = uptime.isEmpty ? "Unknown" : uptime
            
            // Get network info
            info["hostname"] = ShellHelper.runCommand("hostname").output
            
            let ethernetIP = ShellHelper.runCommand("ipconfig getifaddr en0").output
            info["ethernetIP"] = ethernetIP.isEmpty ? "Not Connected" : ethernetIP
            
            let wifiIP = ShellHelper.runCommand("ipconfig getifaddr en1").output
            info["wifiIP"] = wifiIP.isEmpty ? "Not Connected" : wifiIP
            
            let macAddress = ShellHelper.runCommand("ifconfig en0 | grep ether | awk '{print $2}'").output
            info["macAddress"] = macAddress.isEmpty ? "Unknown" : macAddress
            
            let dnsServers = ShellHelper.runCommand("scutil --dns | grep 'nameserver\\[' | awk '{print $3}' | sort -u").output
            info["dnsServers"] = dnsServers.isEmpty ? "Unknown" : dnsServers.replacingOccurrences(of: "\n", with: ", ")
            
            DispatchQueue.main.async {
                self.systemInfo = info
                self.isLoading = false
            }
        }
    }
}