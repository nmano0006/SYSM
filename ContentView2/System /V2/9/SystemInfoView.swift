import SwiftUI
import UniformTypeIdentifiers

struct SystemInfoView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedDrive: DriveInfo?
    @State private var systemInfo: [String: String] = [:]
    @State private var isLoading = false
    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var isPreparingExport = false
    
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
                            prepareAndExport()
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || isPreparingExport)
                    }
                }
                .padding(.horizontal)
                
                if isPreparingExport {
                    ProgressView("Preparing export...")
                        .padding()
                }
                
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
            ExportSheetView(exportText: exportText, isPresented: $showExportSheet)
        }
    }
    
    // ... (Keep all the existing section views and helper functions exactly as they were)
    // Just replace the prepareAndExport function and add the ExportSheetView
    
    private func prepareAndExport() {
        print("🔄 Starting export preparation...")
        isPreparingExport = true
        
        // Create export content immediately from current systemInfo
        createExportContent()
    }
    
    private func createExportContent() {
        print("📝 Creating export content from systemInfo...")
        print("System info count: \(systemInfo.count)")
        
        // Debug: Print all systemInfo keys
        for (key, value) in systemInfo {
            print("  \(key): \(value)")
        }
        
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
        
        print("✅ Export content created, length: \(exportContent.count) characters")
        
        // Set the export text and show the sheet
        DispatchQueue.main.async {
            self.exportText = exportContent
            self.isPreparingExport = false
            self.showExportSheet = true
            print("📤 Export sheet shown: \(self.showExportSheet)")
        }
    }
}

// Export Sheet View - COMPLETELY REWRITTEN
struct ExportSheetView: View {
    let exportText: String
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview:")
                    .font(.headline)
                    .padding(.horizontal)
                
                if exportText.isEmpty {
                    VStack {
                        Text("No data available")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(height: 200)
                } else {
                    ScrollView {
                        Text(exportText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            
            Divider()
            
            // Export buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Options:")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    ExportButton(
                        title: "Copy",
                        icon: "doc.on.doc",
                        color: .blue,
                        action: copyToClipboard
                    )
                    
                    ExportButton(
                        title: "Save to Desktop",
                        icon: "desktopcomputer",
                        color: .green,
                        action: saveToDesktopDirect
                    )
                    
                    ExportButton(
                        title: "Save As...",
                        icon: "folder",
                        color: .orange,
                        action: saveAs
                    )
                    
                    ExportButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: .purple,
                        action: { showingShareSheet = true }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Spacer()
        }
        .frame(width: 800, height: 500)
        .alert("Export Status", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportText])
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportText, forType: .string)
        saveAlertMessage = "✅ System information copied to clipboard!"
        showSaveAlert = true
        print("📋 Copied to clipboard")
    }
    
    private func saveToDesktopDirect() {
        print("💾 Attempting to save to Desktop...")
        
        // Get Desktop path
        let fileManager = FileManager.default
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            saveAlertMessage = "❌ Could not find Desktop directory"
            showSaveAlert = true
            print("❌ Desktop URL not found")
            return
        }
        
        print("📁 Desktop URL: \(desktopURL.path)")
        
        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "System_Info_\(dateString).txt"
        let fileURL = desktopURL.appendingPathComponent(fileName)
        
        print("📄 Attempting to save to: \(fileURL.path)")
        
        // Try to save the file
        do {
            try exportText.write(to: fileURL, atomically: true, encoding: .utf8)
            saveAlertMessage = "✅ System information saved to Desktop:\n\(fileName)"
            showSaveAlert = true
            print("✅ File saved successfully")
            
            // Reveal in Finder
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: desktopURL.path)
        } catch {
            saveAlertMessage = "❌ Error saving to Desktop:\n\(error.localizedDescription)\n\nTrying alternative method..."
            showSaveAlert = true
            print("❌ Direct save failed: \(error)")
            
            // Try alternative method with save panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                saveWithPanel(to: desktopURL)
            }
        }
    }
    
    private func saveWithPanel(to directory: URL) {
        print("🔄 Opening save panel...")
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save System Information"
        savePanel.message = "Choose where to save the system information report"
        savePanel.nameFieldLabel = "File name:"
        
        // Set default filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "System_Info_\(dateString).txt"
        
        // Set directory
        savePanel.directoryURL = directory
        
        // Set allowed file types
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt", "text"]
        }
        
        // Show the panel
        savePanel.begin { response in
            print("📋 Save panel response: \(response.rawValue)")
            if response == .OK, let url = savePanel.url {
                print("📄 Save panel selected URL: \(url.path)")
                self.saveToURL(url)
            } else {
                print("❌ Save panel cancelled or failed")
                self.saveAlertMessage = "Save cancelled"
                self.showSaveAlert = true
            }
        }
    }
    
    private func saveAs() {
        print("📂 Opening Save As dialog...")
        saveWithPanel(to: FileManager.default.homeDirectoryForCurrentUser)
    }
    
    private func saveToURL(_ url: URL) {
        print("💾 Saving to URL: \(url.path)")
        
        do {
            try exportText.write(to: url, atomically: true, encoding: .utf8)
            saveAlertMessage = "✅ System information saved to:\n\(url.lastPathComponent)"
            showSaveAlert = true
            print("✅ File saved successfully")
            
            // Reveal in Finder
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        } catch {
            saveAlertMessage = "❌ Error saving file:\n\(error.localizedDescription)"
            showSaveAlert = true
            print("❌ Save failed: \(error)")
        }
    }
}

// Button Component
struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 100, height: 70)
            .background(color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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