import SwiftUI
import UniformTypeIdentifiers

struct SystemInfoView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedDrive: DriveInfo?
    @State private var systemInfo: [String: String] = [:]
    @State private var isLoading = false
    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            refreshSystemInfo()
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        
                        Button(action: {
                            exportSystemInfo()
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                
                // System Overview Cards
                SystemOverviewCards
                
                // Hardware Information
                HardwareInfoSection
                
                // Thunderbolt Information
                ThunderboltInfoSection
                
                // Software Information
                SoftwareInfoSection
                
                // Network Information
                NetworkInfoSection
                
                // Wireless Information
                WirelessInfoSection
            }
            .padding()
        }
        .onAppear {
            refreshSystemInfo()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView(exportText: $exportText, isPresented: $showExportSheet)
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportMessage)
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
                InfoRow(label: "Boot ROM:", value: systemInfo["bootROM"] ?? "Unknown")
                InfoRow(label: "SMC Version:", value: systemInfo["smcVersion"] ?? "Unknown")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var ThunderboltInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Thunderbolt Information", icon: "bolt.fill")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Thunderbolt Ports:", value: systemInfo["thunderboltPorts"] ?? "Unknown")
                InfoRow(label: "Thunderbolt Version:", value: systemInfo["thunderboltVersion"] ?? "Unknown")
                InfoRow(label: "Connected Devices:", value: systemInfo["thunderboltDevices"] ?? "None")
                InfoRow(label: "Firmware Version:", value: systemInfo["thunderboltFirmware"] ?? "Unknown")
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
                InfoRow(label: "Gatekeeper Status:", value: systemInfo["gatekeeperStatus"] ?? "Unknown")
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
                InfoRow(label: "Router IP:", value: systemInfo["routerIP"] ?? "Unknown")
                InfoRow(label: "IPv6 Address:", value: systemInfo["ipv6Address"] ?? "Not Configured")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var WirelessInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Wireless Information", icon: "wifi")
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Wi-Fi SSID:", value: systemInfo["wifiSSID"] ?? "Not Connected")
                InfoRow(label: "Wi-Fi BSSID:", value: systemInfo["wifiBSSID"] ?? "Unknown")
                InfoRow(label: "Wi-Fi Security:", value: systemInfo["wifiSecurity"] ?? "Unknown")
                InfoRow(label: "Wi-Fi Channel:", value: systemInfo["wifiChannel"] ?? "Unknown")
                InfoRow(label: "Wi-Fi RSSI:", value: systemInfo["wifiRSSI"] ?? "Unknown")
                InfoRow(label: "Wi-Fi Noise:", value: systemInfo["wifiNoise"] ?? "Unknown")
                InfoRow(label: "Wi-Fi Tx Rate:", value: systemInfo["wifiTxRate"] ?? "Unknown")
                InfoRow(label: "Bluetooth Status:", value: systemInfo["bluetoothStatus"] ?? "Unknown")
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
                .frame(width: 150, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private func refreshSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
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
            
            // Get SMC version
            let smcVersion = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'SMC' | awk -F': ' '{print $2}'").output
            info["smcVersion"] = smcVersion.isEmpty ? "Unknown" : smcVersion
            
            // Get Boot ROM version
            let bootROM = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Boot ROM' | awk -F': ' '{print $2}'").output
            info["bootROM"] = bootROM.isEmpty ? "Unknown" : bootROM
            
            // Get SIP status
            let sipStatus = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output
            info["sipStatus"] = sipStatus.isEmpty ? "Unknown" : sipStatus
            
            // Get Secure Boot status
            let secureBoot = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Secure Boot' | awk -F': ' '{print $2}'").output
            info["secureBoot"] = secureBoot.isEmpty ? "Unknown" : secureBoot
            
            // Get Gatekeeper status
            let gatekeeperStatus = ShellHelper.runCommand("spctl --status").output
            info["gatekeeperStatus"] = gatekeeperStatus.isEmpty ? "Unknown" : gatekeeperStatus
            
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
            
            // Get router IP
            let routerIP = ShellHelper.runCommand("netstat -rn | grep default | grep en0 | awk '{print $2}' | head -1").output
            info["routerIP"] = routerIP.isEmpty ? "Unknown" : routerIP
            
            // Get IPv6 address
            let ipv6Address = ShellHelper.runCommand("ifconfig en0 | grep inet6 | grep -v fe80 | awk '{print $2}' | head -1").output
            info["ipv6Address"] = ipv6Address.isEmpty ? "Not Configured" : ipv6Address
            
            // Get Thunderbolt info
            let thunderboltInfo = ShellHelper.runCommand("system_profiler SPThunderboltDataType")
            let tbLines = thunderboltInfo.output.components(separatedBy: "\n")
            
            var tbPorts = "Unknown"
            var tbVersion = "Unknown"
            var tbDevices = "None"
            var tbFirmware = "Unknown"
            
            for line in tbLines {
                if line.contains("Port") && line.contains(":") {
                    tbPorts = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
                } else if line.contains("Firmware Version") {
                    tbFirmware = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
                } else if line.contains("Connected") && line.contains("Yes") {
                    tbDevices = "Connected"
                }
            }
            
            // Try to get Thunderbolt version
            let tbVersionCmd = ShellHelper.runCommand("system_profiler SPThunderboltDataType | grep -i 'version' | head -1")
            tbVersion = tbVersionCmd.output.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
            
            info["thunderboltPorts"] = tbPorts
            info["thunderboltVersion"] = tbVersion
            info["thunderboltDevices"] = tbDevices
            info["thunderboltFirmware"] = tbFirmware
            
            // Get Wi-Fi info
            let wifiInfo = ShellHelper.runCommand("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I")
            let wifiLines = wifiInfo.output.components(separatedBy: "\n")
            
            var wifiSSID = "Not Connected"
            var wifiBSSID = "Unknown"
            var wifiSecurity = "Unknown"
            var wifiChannel = "Unknown"
            var wifiRSSI = "Unknown"
            var wifiNoise = "Unknown"
            var wifiTxRate = "Unknown"
            
            for line in wifiLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("SSID:") {
                    wifiSSID = trimmed.replacingOccurrences(of: "SSID:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("BSSID:") {
                    wifiBSSID = trimmed.replacingOccurrences(of: "BSSID:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("security:") {
                    wifiSecurity = trimmed.replacingOccurrences(of: "security:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("channel:") {
                    wifiChannel = trimmed.replacingOccurrences(of: "channel:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("agrCtlRSSI:") {
                    wifiRSSI = "\(trimmed.replacingOccurrences(of: "agrCtlRSSI:", with: "").trimmingCharacters(in: .whitespaces)) dBm"
                } else if trimmed.hasPrefix("agrCtlNoise:") {
                    wifiNoise = "\(trimmed.replacingOccurrences(of: "agrCtlNoise:", with: "").trimmingCharacters(in: .whitespaces)) dBm"
                } else if trimmed.hasPrefix("lastTxRate:") {
                    wifiTxRate = "\(trimmed.replacingOccurrences(of: "lastTxRate:", with: "").trimmingCharacters(in: .whitespaces)) Mbps"
                }
            }
            
            info["wifiSSID"] = wifiSSID
            info["wifiBSSID"] = wifiBSSID
            info["wifiSecurity"] = wifiSecurity
            info["wifiChannel"] = wifiChannel
            info["wifiRSSI"] = wifiRSSI
            info["wifiNoise"] = wifiNoise
            info["wifiTxRate"] = wifiTxRate
            
            // Get Bluetooth status
            let bluetoothStatus = ShellHelper.runCommand("system_profiler SPBluetoothDataType | grep 'State' | head -1 | awk -F': ' '{print $2}'").output
            info["bluetoothStatus"] = bluetoothStatus.isEmpty ? "Unknown" : bluetoothStatus
            
            DispatchQueue.main.async {
                self.systemInfo = info
                self.isLoading = false
            }
        }
    }
    
    private func exportSystemInfo() {
        // Prepare export content
        var exportContent = "=== System Information Report ===\n"
        exportContent += "Generated: \(Date().formatted(date: .long, time: .standard))\n"
        exportContent += "==================================\n\n"
        
        // Hardware Information
        exportContent += "HARDWARE INFORMATION:\n"
        exportContent += "=====================\n"
        exportContent += "Computer Name: \(systemInfo["computerName"] ?? "Unknown")\n"
        exportContent += "Model Identifier: \(systemInfo["modelIdentifier"] ?? "Unknown")\n"
        exportContent += "Serial Number: \(systemInfo["serialNumber"] ?? "Unknown")\n"
        exportContent += "Processor: \(systemInfo["processor"] ?? "Unknown")\n"
        exportContent += "Processor Cores: \(systemInfo["processorCores"] ?? "Unknown")\n"
        exportContent += "Memory: \(systemInfo["memory"] ?? "Unknown")\n"
        exportContent += "Graphics: \(systemInfo["graphics"] ?? "Unknown")\n"
        exportContent += "Storage: \(systemInfo["storage"] ?? "Unknown")\n"
        exportContent += "Boot ROM: \(systemInfo["bootROM"] ?? "Unknown")\n"
        exportContent += "SMC Version: \(systemInfo["smcVersion"] ?? "Unknown")\n\n"
        
        // Thunderbolt Information
        exportContent += "THUNDERBOLT INFORMATION:\n"
        exportContent += "=========================\n"
        exportContent += "Thunderbolt Ports: \(systemInfo["thunderboltPorts"] ?? "Unknown")\n"
        exportContent += "Thunderbolt Version: \(systemInfo["thunderboltVersion"] ?? "Unknown")\n"
        exportContent += "Connected Devices: \(systemInfo["thunderboltDevices"] ?? "None")\n"
        exportContent += "Firmware Version: \(systemInfo["thunderboltFirmware"] ?? "Unknown")\n\n"
        
        // Software Information
        exportContent += "SOFTWARE INFORMATION:\n"
        exportContent += "=====================\n"
        exportContent += "macOS Version: \(systemInfo["macosVersion"] ?? "Unknown")\n"
        exportContent += "Build Number: \(systemInfo["buildNumber"] ?? "Unknown")\n"
        exportContent += "Kernel Version: \(systemInfo["kernelVersion"] ?? "Unknown")\n"
        exportContent += "Boot Volume: \(systemInfo["bootVolume"] ?? "Unknown")\n"
        exportContent += "Secure Boot: \(systemInfo["secureBoot"] ?? "Unknown")\n"
        exportContent += "SIP Status: \(systemInfo["sipStatus"] ?? "Unknown")\n"
        exportContent += "Gatekeeper Status: \(systemInfo["gatekeeperStatus"] ?? "Unknown")\n"
        exportContent += "System Uptime: \(systemInfo["uptime"] ?? "Unknown")\n\n"
        
        // Network Information
        exportContent += "NETWORK INFORMATION:\n"
        exportContent += "====================\n"
        exportContent += "Hostname: \(systemInfo["hostname"] ?? "Unknown")\n"
        exportContent += "Ethernet IP: \(systemInfo["ethernetIP"] ?? "Not Connected")\n"
        exportContent += "Wi-Fi IP: \(systemInfo["wifiIP"] ?? "Not Connected")\n"
        exportContent += "MAC Address: \(systemInfo["macAddress"] ?? "Unknown")\n"
        exportContent += "DNS Servers: \(systemInfo["dnsServers"] ?? "Unknown")\n"
        exportContent += "Router IP: \(systemInfo["routerIP"] ?? "Unknown")\n"
        exportContent += "IPv6 Address: \(systemInfo["ipv6Address"] ?? "Not Configured")\n\n"
        
        // Wireless Information
        exportContent += "WIRELESS INFORMATION:\n"
        exportContent += "=====================\n"
        exportContent += "Wi-Fi SSID: \(systemInfo["wifiSSID"] ?? "Not Connected")\n"
        exportContent += "Wi-Fi BSSID: \(systemInfo["wifiBSSID"] ?? "Unknown")\n"
        exportContent += "Wi-Fi Security: \(systemInfo["wifiSecurity"] ?? "Unknown")\n"
        exportContent += "Wi-Fi Channel: \(systemInfo["wifiChannel"] ?? "Unknown")\n"
        exportContent += "Wi-Fi RSSI: \(systemInfo["wifiRSSI"] ?? "Unknown")\n"
        exportContent += "Wi-Fi Noise: \(systemInfo["wifiNoise"] ?? "Unknown")\n"
        exportContent += "Wi-Fi Tx Rate: \(systemInfo["wifiTxRate"] ?? "Unknown")\n"
        exportContent += "Bluetooth Status: \(systemInfo["bluetoothStatus"] ?? "Unknown")\n"
        
        exportText = exportContent
        
        // Try to automatically save to Desktop first
        autoSaveToDesktop()
    }
    
    private func autoSaveToDesktop() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "System_Info_\(dateString).txt"
        
        if let desktopURL = desktopURL {
            let fileURL = desktopURL.appendingPathComponent(fileName)
            
            do {
                try exportText.write(to: fileURL, atomically: true, encoding: .utf8)
                exportMessage = "System information saved to Desktop: \(fileName)"
                showExportSuccess = true
                print("✅ File saved to: \(fileURL.path)")
            } catch {
                print("❌ Error saving to Desktop: \(error)")
                // If automatic save fails, show the export sheet
                exportMessage = "Could not save automatically. Please use the export dialog."
                showExportSheet = true
            }
        } else {
            print("❌ Could not get Desktop directory")
            exportMessage = "Could not access Desktop directory. Please use the export dialog."
            showExportSheet = true
        }
    }
}

// Export Sheet View
struct ExportSheetView: View {
    @Binding var exportText: String
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $exportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.gray.opacity(0.3), width: 1)
                    .padding()
                
                HStack {
                    Button("Copy to Clipboard") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(exportText, forType: .string)
                        saveAlertMessage = "System information copied to clipboard!"
                        showSaveAlert = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save to Desktop") {
                        saveToDesktop()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Save As...") {
                        saveToFile()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Share") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Export System Information")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .alert("Export Complete", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveAlertMessage)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportText])
        }
    }
    
    private func saveToDesktop() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "System_Info_\(dateString).txt"
        
        if let desktopURL = desktopURL {
            let fileURL = desktopURL.appendingPathComponent(fileName)
            
            do {
                try exportText.write(to: fileURL, atomically: true, encoding: .utf8)
                saveAlertMessage = "System information saved to Desktop:\n\(fileName)"
                showSaveAlert = true
                print("✅ File saved to Desktop: \(fileURL.path)")
            } catch {
                saveAlertMessage = "Error saving to Desktop: \(error.localizedDescription)"
                showSaveAlert = true
                print("❌ Error saving to Desktop: \(error)")
            }
        } else {
            saveAlertMessage = "Could not access Desktop directory"
            showSaveAlert = true
        }
    }
    
    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save System Information"
        savePanel.nameFieldStringValue = "System_Info_\(formatDateForFileName()).txt"
        
        // Set default directory to Desktop
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = desktopURL
        }
        
        // Use allowedContentTypes instead of deprecated allowedFileTypes
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            // Fallback for older macOS versions
            savePanel.allowedFileTypes = ["txt", "text"]
        }
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try exportText.write(to: url, atomically: true, encoding: .utf8)
                    self.saveAlertMessage = "System information saved to:\n\(url.lastPathComponent)"
                    self.showSaveAlert = true
                    print("✅ File saved to: \(url.path)")
                } catch {
                    self.saveAlertMessage = "Error saving file: \(error.localizedDescription)"
                    self.showSaveAlert = true
                    print("❌ Error saving file: \(error)")
                }
            }
        }
    }
    
    private func formatDateForFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

// Share Sheet
struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
    }
}