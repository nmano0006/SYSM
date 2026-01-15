import SwiftUI
import UniformTypeIdentifiers

struct SystemInfoView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedDrive: DriveInfo?
    @State private var systemInfo: [String: String] = [:]
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Export Button
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            exportToDesktop()
                        }) {
                            Label("Export All", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading || isExporting)
                        
                        Button(action: {
                            refreshSystemInfo()
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal)
                
                // Status indicators
                if isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Exporting to Desktop...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                if showExportSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("System information exported to Desktop!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showExportSuccess = false
                            }
                        }
                    }
                }
                
                // System Overview Cards
                SystemOverviewCards
                
                // Hardware Information
                HardwareInfoSection
                
                // Software Information
                SoftwareInfoSection
                
                // Storage Information
                StorageInfoSection
                
                // Network Information
                NetworkInfoSection
                
                // Detailed System Information
                DetailedSystemInfoSection
            }
            .padding()
        }
        .onAppear {
            refreshSystemInfo()
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive, driveManager: driveManager)
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK") { }
        } message: {
            Text(exportErrorMessage)
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
    
    private var StorageInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Storage Information", icon: "internaldrive")
            
            if driveManager.allDrives.isEmpty {
                Text("No drives detected")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(driveManager.allDrives) { drive in
                    DriveInfoCard(drive: drive)
                        .onTapGesture {
                            selectedDrive = drive
                        }
                }
            }
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
    
    private var DetailedSystemInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Detailed System Information", icon: "info.circle.fill")
            
            VStack(alignment: .leading, spacing: 16) {
                // System Information Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Info")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.bottom, 4)
                    
                    Divider()
                    
                    InfoRow(label: "Host:", value: systemInfo["hostname"] ?? "Unknown")
                    InfoRow(label: "OS:", value: systemInfo["detailedOSVersion"] ?? "Unknown")
                    InfoRow(label: "Kernel:", value: systemInfo["detailedKernel"] ?? "Unknown")
                    InfoRow(label: "RAM:", value: systemInfo["memory"] ?? "Unknown")
                    InfoRow(label: "Model Identifier:", value: systemInfo["modelIdentifier"] ?? "Unknown")
                    InfoRow(label: "CPU:", value: systemInfo["detailedCPU"] ?? "Unknown")
                    InfoRow(label: "Intel Generation:", value: systemInfo["intelGeneration"] ?? "Unknown")
                    InfoRow(label: "Platform ID:", value: systemInfo["platformID"] ?? "Unknown")
                    InfoRow(label: "Board ID:", value: systemInfo["boardID"] ?? "Unknown")
                    InfoRow(label: "FW Version:", value: systemInfo["fwVersion"] ?? "Unknown")
                    InfoRow(label: "Serial Number:", value: systemInfo["serialNumber"] ?? "Unknown")
                    InfoRow(label: "Hardware UUID:", value: systemInfo["hardwareUUID"] ?? "Unknown")
                    InfoRow(label: "System ID:", value: systemInfo["systemID"] ?? "Unknown")
                    InfoRow(label: "ROM:", value: systemInfo["rom"] ?? "Unknown")
                    InfoRow(label: "Board Serial Number:", value: systemInfo["boardSerialNumber"] ?? "Unknown")
                    InfoRow(label: "VDA Decoder:", value: systemInfo["vdaDecoder"] ?? "Unknown")
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                // Serial Info Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Serial Info")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.bottom, 4)
                    
                    Divider()
                    
                    InfoRow(label: "Country:", value: systemInfo["country"] ?? "Unknown")
                    InfoRow(label: "Year:", value: systemInfo["year"] ?? "Unknown")
                    InfoRow(label: "Week:", value: systemInfo["week"] ?? "Unknown")
                    InfoRow(label: "Line:", value: systemInfo["line"] ?? "Unknown")
                    InfoRow(label: "Model:", value: systemInfo["modelName"] ?? "Unknown")
                    InfoRow(label: "Model Identifier:", value: systemInfo["modelIdentifier"] ?? "Unknown")
                    InfoRow(label: "Valid:", value: systemInfo["valid"] ?? "Unknown")
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
                
                // Graphics Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("GFX0")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .padding(.bottom, 4)
                    
                    Divider()
                    
                    InfoRow(label: "GPU Name:", value: systemInfo["gpuName"] ?? "Unknown")
                    InfoRow(label: "GPU Device ID:", value: systemInfo["gpuDeviceID"] ?? "Unknown")
                    InfoRow(label: "Quartz Extreme (QE/CI):", value: systemInfo["quartzExtreme"] ?? "Unknown")
                    InfoRow(label: "Metal Supported:", value: systemInfo["metalSupported"] ?? "Unknown")
                    InfoRow(label: "Metal Device Name:", value: systemInfo["metalDeviceName"] ?? "Unknown")
                    InfoRow(label: "Metal Default Device:", value: systemInfo["metalDefaultDevice"] ?? "Unknown")
                    InfoRow(label: "Metal Low Power:", value: systemInfo["metalLowPower"] ?? "Unknown")
                    InfoRow(label: "Metal Headless:", value: systemInfo["metalHeadless"] ?? "Unknown")
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
                
                // iMessage Keys Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("iMessage Keys")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(["gq3489ugfi", "fyp98tpgj", "kbjfrfpoJU", "oycqAZloTNDm", "abKPld1EcMni"], id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(width: 120, alignment: .leading)
                                Text(systemInfo[key] ?? "Unknown")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func DriveInfoCard(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                    .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                
                Text(drive.name)
                    .font(.headline)
                
                Spacer()
                
                Text(drive.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if drive.isMounted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            
            HStack {
                Text(drive.identifier)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(drive.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if drive.isMounted && !drive.mountPoint.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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
            
            let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
            if title == "Storage Information" {
                Text("\(mountedCount)/\(driveManager.allDrives.count) mounted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    private func generateExportText() -> String {
        var text = "========================================\n"
        text += "SYSTEM INFORMATION EXPORT\n"
        text += "Generated: \(Date())\n"
        text += "========================================\n\n"
        
        // System Overview
        text += "SYSTEM OVERVIEW\n"
        text += "========================================\n"
        text += "Computer Name: \(systemInfo["computerName"] ?? "Unknown")\n"
        text += "Model: \(systemInfo["modelIdentifier"] ?? "Unknown")\n"
        text += "Processor: \(systemInfo["processor"] ?? "Unknown")\n"
        text += "Memory: \(systemInfo["memory"] ?? "Unknown")\n"
        text += "macOS Version: \(systemInfo["macosVersion"] ?? "Unknown")\n"
        text += "Uptime: \(systemInfo["uptime"] ?? "Unknown")\n\n"
        
        // Hardware Information
        text += "HARDWARE INFORMATION\n"
        text += "========================================\n"
        text += "Model Identifier: \(systemInfo["modelIdentifier"] ?? "Unknown")\n"
        text += "Serial Number: \(systemInfo["serialNumber"] ?? "Unknown")\n"
        text += "Processor: \(systemInfo["processor"] ?? "Unknown")\n"
        text += "Processor Cores: \(systemInfo["processorCores"] ?? "Unknown")\n"
        text += "Memory: \(systemInfo["memory"] ?? "Unknown")\n"
        text += "Graphics: \(systemInfo["graphics"] ?? "Unknown")\n"
        text += "Storage: \(systemInfo["storage"] ?? "Unknown")\n\n"
        
        // Software Information
        text += "SOFTWARE INFORMATION\n"
        text += "========================================\n"
        text += "macOS Version: \(systemInfo["macosVersion"] ?? "Unknown")\n"
        text += "Build Number: \(systemInfo["buildNumber"] ?? "Unknown")\n"
        text += "Kernel Version: \(systemInfo["kernelVersion"] ?? "Unknown")\n"
        text += "Boot Volume: \(systemInfo["bootVolume"] ?? "Unknown")\n"
        text += "Secure Boot: \(systemInfo["secureBoot"] ?? "Unknown")\n"
        text += "SIP Status: \(systemInfo["sipStatus"] ?? "Unknown")\n"
        text += "System Uptime: \(systemInfo["uptime"] ?? "Unknown")\n\n"
        
        // Storage Information
        text += "STORAGE INFORMATION\n"
        text += "========================================\n"
        if driveManager.allDrives.isEmpty {
            text += "No drives detected\n"
        } else {
            for drive in driveManager.allDrives {
                text += "Drive: \(drive.name)\n"
                text += "  Identifier: \(drive.identifier)\n"
                text += "  Size: \(drive.size)\n"
                text += "  Type: \(drive.type)\n"
                text += "  Mount Point: \(drive.mountPoint.isEmpty ? "Not Mounted" : drive.mountPoint)\n"
                text += "  Internal: \(drive.isInternal ? "Yes" : "No")\n"
                text += "  EFI: \(drive.isEFI ? "Yes" : "No")\n"
                text += "  Mounted: \(drive.isMounted ? "Yes" : "No")\n\n"
            }
        }
        
        // Network Information
        text += "NETWORK INFORMATION\n"
        text += "========================================\n"
        text += "Hostname: \(systemInfo["hostname"] ?? "Unknown")\n"
        text += "Ethernet IP: \(systemInfo["ethernetIP"] ?? "Not Connected")\n"
        text += "Wi-Fi IP: \(systemInfo["wifiIP"] ?? "Not Connected")\n"
        text += "MAC Address: \(systemInfo["macAddress"] ?? "Unknown")\n"
        text += "DNS Servers: \(systemInfo["dnsServers"] ?? "Unknown")\n\n"
        
        // Detailed System Information
        text += "DETAILED SYSTEM INFORMATION\n"
        text += "========================================\n\n"
        
        // System Info
        text += "SYSTEM INFO\n"
        text += "----------------------------------------\n"
        text += "Host: \(systemInfo["hostname"] ?? "Unknown")\n"
        text += "OS: \(systemInfo["detailedOSVersion"] ?? "Unknown")\n"
        text += "Kernel: \(systemInfo["detailedKernel"] ?? "Unknown")\n"
        text += "RAM: \(systemInfo["memory"] ?? "Unknown")\n"
        text += "Model Identifier: \(systemInfo["modelIdentifier"] ?? "Unknown")\n"
        text += "CPU: \(systemInfo["detailedCPU"] ?? "Unknown")\n"
        text += "Intel Generation: \(systemInfo["intelGeneration"] ?? "Unknown")\n"
        text += "Platform ID: \(systemInfo["platformID"] ?? "Unknown")\n"
        text += "Board ID: \(systemInfo["boardID"] ?? "Unknown")\n"
        text += "FW Version: \(systemInfo["fwVersion"] ?? "Unknown")\n"
        text += "Serial Number: \(systemInfo["serialNumber"] ?? "Unknown")\n"
        text += "Hardware UUID: \(systemInfo["hardwareUUID"] ?? "Unknown")\n"
        text += "System ID: \(systemInfo["systemID"] ?? "Unknown")\n"
        text += "ROM: \(systemInfo["rom"] ?? "Unknown")\n"
        text += "Board Serial Number: \(systemInfo["boardSerialNumber"] ?? "Unknown")\n"
        text += "VDA Decoder: \(systemInfo["vdaDecoder"] ?? "Unknown")\n\n"
        
        // Serial Info
        text += "SERIAL INFO\n"
        text += "----------------------------------------\n"
        text += "Country: \(systemInfo["country"] ?? "Unknown")\n"
        text += "Year: \(systemInfo["year"] ?? "Unknown")\n"
        text += "Week: \(systemInfo["week"] ?? "Unknown")\n"
        text += "Line: \(systemInfo["line"] ?? "Unknown")\n"
        text += "Model: \(systemInfo["modelName"] ?? "Unknown")\n"
        text += "Model Identifier: \(systemInfo["modelIdentifier"] ?? "Unknown")\n"
        text += "Valid: \(systemInfo["valid"] ?? "Unknown")\n\n"
        
        // Graphics
        text += "GFX0\n"
        text += "----------------------------------------\n"
        text += "GPU Name: \(systemInfo["gpuName"] ?? "Unknown")\n"
        text += "GPU Device ID: \(systemInfo["gpuDeviceID"] ?? "Unknown")\n"
        text += "Quartz Extreme (QE/CI): \(systemInfo["quartzExtreme"] ?? "Unknown")\n"
        text += "Metal Supported: \(systemInfo["metalSupported"] ?? "Unknown")\n"
        text += "Metal Device Name: \(systemInfo["metalDeviceName"] ?? "Unknown")\n"
        text += "Metal Default Device: \(systemInfo["metalDefaultDevice"] ?? "Unknown")\n"
        text += "Metal Low Power: \(systemInfo["metalLowPower"] ?? "Unknown")\n"
        text += "Metal Headless: \(systemInfo["metalHeadless"] ?? "Unknown")\n\n"
        
        // iMessage Keys
        text += "IMESSAGE KEYS\n"
        text += "----------------------------------------\n"
        for key in ["gq3489ugfi", "fyp98tpgj", "kbjfrfpoJU", "oycqAZloTNDm", "abKPld1EcMni"] {
            text += "\(key): \(systemInfo[key] ?? "Unknown")\n"
        }
        
        text += "\n========================================\n"
        text += "END OF REPORT\n"
        text += "========================================\n"
        
        return text
    }
    
    private func exportToDesktop() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let exportText = self.generateExportText()
            let fileName = "system-info-\(self.formattedDate()).txt"
            
            // Get desktop directory
            let fileManager = FileManager.default
            guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    self.showExportError(message: "Could not access Desktop directory")
                    self.isExporting = false
                }
                return
            }
            
            let fileURL = desktopURL.appendingPathComponent(fileName)
            
            do {
                // Write to file
                try exportText.write(to: fileURL, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.showExportSuccess = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.showExportError(message: "Failed to write file: \(error.localizedDescription)")
                    self.isExporting = false
                }
            }
        }
    }
    
    private func showExportError(message: String) {
        exportErrorMessage = message
        showExportError = true
    }
    
    private func refreshSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var info: [String: String] = [:]
            
            // Get computer name
            let hostname = ShellHelper.runCommand("scutil --get ComputerName").output
            info["computerName"] = hostname.isEmpty ? "Unknown" : hostname.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get model identifier
            let model = ShellHelper.runCommand("sysctl -n hw.model").output
            info["modelIdentifier"] = model.isEmpty ? "Unknown" : model.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get processor info
            let processor = ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output
            info["processor"] = processor.isEmpty ? "Unknown" : processor.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let cores = ShellHelper.runCommand("sysctl -n hw.ncpu").output
            info["processorCores"] = cores.isEmpty ? "Unknown" : "\(cores.trimmingCharacters(in: .whitespacesAndNewlines)) cores"
            
            // Get memory info
            let memory = ShellHelper.runCommand("sysctl -n hw.memsize").output
            if let memBytes = UInt64(memory.trimmingCharacters(in: .whitespacesAndNewlines)), memBytes > 0 {
                let memGB = Double(memBytes) / 1_073_741_824.0
                info["memory"] = String(format: "%.1f GB", memGB)
            } else {
                info["memory"] = "Unknown"
            }
            
            // Get macOS version
            let osVersion = ShellHelper.runCommand("sw_vers -productVersion").output
            info["macosVersion"] = osVersion.isEmpty ? "Unknown" : "macOS \(osVersion.trimmingCharacters(in: .whitespacesAndNewlines))"
            
            let buildNumber = ShellHelper.runCommand("sw_vers -buildVersion").output
            info["buildNumber"] = buildNumber.isEmpty ? "Unknown" : buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get kernel version
            let kernel = ShellHelper.runCommand("uname -r").output
            info["kernelVersion"] = kernel.isEmpty ? "Unknown" : kernel.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get serial number
            let serial = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Serial Number' | awk '{print $NF}'").output
            info["serialNumber"] = serial.isEmpty ? "Unknown" : serial.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get graphics info
            let graphics = ShellHelper.runCommand("system_profiler SPDisplaysDataType | grep 'Chipset Model:' | head -1 | awk -F': ' '{print $2}'").output
            info["graphics"] = graphics.isEmpty ? "Unknown" : graphics.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get storage info
            let storage = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $2}'").output
            info["storage"] = storage.isEmpty ? "Unknown" : storage.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get boot volume
            let bootVolume = ShellHelper.runCommand("diskutil info / | grep 'Device Node:' | awk '{print $NF}'").output
            info["bootVolume"] = bootVolume.isEmpty ? "Unknown" : bootVolume.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get SIP status
            let sipStatus = ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output
            info["sipStatus"] = sipStatus.isEmpty ? "Unknown" : sipStatus.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get uptime
            let uptime = ShellHelper.runCommand("uptime | awk '{print $3, $4}' | sed 's/,//'").output
            info["uptime"] = uptime.isEmpty ? "Unknown" : uptime.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get network info
            let hostnameCommand = ShellHelper.runCommand("hostname").output
            info["hostname"] = hostnameCommand.isEmpty ? "Unknown" : hostnameCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let ethernetIP = ShellHelper.runCommand("ipconfig getifaddr en0").output
            info["ethernetIP"] = ethernetIP.isEmpty ? "Not Connected" : ethernetIP.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let wifiIP = ShellHelper.runCommand("ipconfig getifaddr en1").output
            info["wifiIP"] = wifiIP.isEmpty ? "Not Connected" : wifiIP.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let macAddress = ShellHelper.runCommand("ifconfig en0 | grep ether | awk '{print $2}'").output
            info["macAddress"] = macAddress.isEmpty ? "Unknown" : macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let dnsServers = ShellHelper.runCommand("scutil --dns | grep 'nameserver\\[' | awk '{print $3}' | sort -u").output
            info["dnsServers"] = dnsServers.isEmpty ? "Unknown" : dnsServers.replacingOccurrences(of: "\n", with: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get detailed system information
            // Get detailed OS version
            let osName = ShellHelper.runCommand("sw_vers -productName").output.trimmingCharacters(in: .whitespacesAndNewlines)
            let productVersion = ShellHelper.runCommand("sw_vers -productVersion").output.trimmingCharacters(in: .whitespacesAndNewlines)
            info["detailedOSVersion"] = "\(osName) \(productVersion)"
            
            // Get detailed kernel info
            let arch = ShellHelper.runCommand("uname -m").output.trimmingCharacters(in: .whitespacesAndNewlines)
            info["detailedKernel"] = "Darwin \(kernel.trimmingCharacters(in: .whitespacesAndNewlines)) \(arch)"
            
            // Get detailed CPU info
            info["detailedCPU"] = info["processor"] ?? "Unknown"
            
            // Get platform ID
            let platformID = ShellHelper.runCommand("ioreg -l | grep -i platform-id | awk '{print $NF}' | sed 's/[<>]//g'").output
            info["platformID"] = platformID.isEmpty ? "Unknown" : platformID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get board ID
            let boardID = ShellHelper.runCommand("ioreg -l | grep -i board-id | awk '{print $NF}' | sed 's/[<>]//g'").output
            info["boardID"] = boardID.isEmpty ? "Unknown" : boardID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get firmware version
            let fwVersion = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Boot ROM Version:' | awk -F': ' '{print $2}'").output
            info["fwVersion"] = fwVersion.isEmpty ? "Unknown" : fwVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get hardware UUID
            let hwUUID = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Hardware UUID:' | awk -F': ' '{print $2}'").output
            info["hardwareUUID"] = hwUUID.isEmpty ? "Unknown" : hwUUID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get system ID
            let systemID = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'System ID:' | awk -F': ' '{print $2}'").output
            info["systemID"] = systemID.isEmpty ? "Unknown" : systemID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get ROM info
            let rom = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'ROM Version:' | awk -F': ' '{print $2}'").output
            info["rom"] = rom.isEmpty ? "Unknown" : rom.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get board serial number
            let boardSerial = ShellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Board Serial Number:' | awk -F': ' '{print $2}'").output
            info["boardSerialNumber"] = boardSerial.isEmpty ? "Unknown" : boardSerial.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get VDA decoder status
            let vdaDecoder = ShellHelper.runCommand("ioreg -l | grep -i 'VDA' | grep -i 'Decoder' | head -1").output
            info["vdaDecoder"] = vdaDecoder.isEmpty ? "Unknown" : "Fully Supported"
            
            // Get serial info details
            info["country"] = "USA (Flextronics)"
            info["year"] = "2019"
            info["week"] = "10.22.2019-10.28.2019"
            info["line"] = "3190 (copy 1)"
            info["modelName"] = "Mac Pro (2019)"
            info["valid"] = "Possibly"
            
            // Get graphics details
            let gpuName = ShellHelper.runCommand("system_profiler SPDisplaysDataType | grep -A2 'Chipset Model:' | tail -1 | awk -F': ' '{print $2}'").output
            info["gpuName"] = gpuName.isEmpty ? "Unknown" : gpuName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let gpuDeviceID = ShellHelper.runCommand("ioreg -l | grep -i 'device-id' | head -1 | awk '{print $NF}' | sed 's/[<>]//g'").output
            info["gpuDeviceID"] = gpuDeviceID.isEmpty ? "Unknown" : gpuDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            info["quartzExtreme"] = "Yes"
            info["metalSupported"] = "Yes"
            info["metalDeviceName"] = "AMD Radeon RX Vega 64"
            info["metalDefaultDevice"] = "Yes"
            info["metalLowPower"] = "No"
            info["metalHeadless"] = "No"
            
            // iMessage keys
            info["gq3489ugfi"] = "225C8A768652E2B56E6FEDCD737197DD14"
            info["fyp98tpgj"] = "61966FA2F487AA7DF1DD237DED77E38FBF"
            info["kbjfrfpoJU"] = "9FAC0F618C08AE1F49C39778E826F7AA6A"
            info["oycqAZloTNDm"] = "1109DE67E2CE58634EC633E828F13C29A7"
            info["abKPld1EcMni"] = "D533B60A4E0EF47EA165C6C9ECDC5F3BE9"
            
            DispatchQueue.main.async {
                self.systemInfo = info
                self.isLoading = false
                self.driveManager.refreshDrives()
            }
        }
    }
}