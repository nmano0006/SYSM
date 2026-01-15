// MARK: - Enhanced SystemInfoView
struct SystemInfoView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleALCStatus: String
    @Binding var liluStatus: String
    @Binding var efiPath: String?
    @Binding var systemInfo: SystemInfo
    @Binding var allDrives: [DriveInfo]
    let refreshSystemInfo: () -> Void
    
    @State private var showAllDrives = false
    @State private var showExportView = false
    @State private var selectedDetailSection: String? = "System"
    
    let detailSections = [
        "System", "Graphics", "Network", "Wireless", "Storage", "USB",
        "USB XHC", "Thunderbolt", "Ethernet", "NVMe", "AHCI", "Audio",
        "Bluetooth", "PCI", "Drives"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Export Button
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showExportView = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        refreshSystemInfo()
                        alertTitle = "Refreshed"
                        alertMessage = "System information updated"
                        showAlert = true
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Detail Sections Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detailSections, id: \.self) { section in
                            DetailSectionButton(
                                title: section,
                                isSelected: selectedDetailSection == section
                            ) {
                                selectedDetailSection = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Display selected section
                Group {
                    switch selectedDetailSection {
                    case "System":
                        systemInfoSection
                    case "Graphics":
                        graphicsInfoSection
                    case "Network":
                        networkInfoSection
                    case "Wireless":
                        wirelessInfoSection
                    case "Storage":
                        storageInfoSection
                    case "USB":
                        usbInfoSection
                    case "USB XHC":
                        usbXHCInfoSection
                    case "Thunderbolt":
                        thunderboltInfoSection
                    case "Ethernet":
                        ethernetInfoSection
                    case "NVMe":
                        nvmeInfoSection
                    case "AHCI":
                        ahciInfoSection
                    case "Audio":
                        audioInfoSection
                    case "Bluetooth":
                        bluetoothInfoSection
                    case "PCI":
                        pciInfoSection
                    case "Drives":
                        drivesInfoSection
                    default:
                        systemInfoSection
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showExportView) {
            ExportSystemInfoView(
                isPresented: $showExportView,
                systemInfo: systemInfo,
                allDrives: allDrives,
                appleHDAStatus: appleHDAStatus,
                appleALCStatus: appleALCStatus,
                liluStatus: liluStatus,
                efiPath: efiPath
            )
        }
    }
    
    // MARK: - Detail Section Views
    
    private var systemInfoSection: some View {
        VStack(spacing: 16) {
            Text("System Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InfoCard(title: "macOS Version", value: systemInfo.macOSVersion)
                InfoCard(title: "Build Number", value: systemInfo.buildNumber)
                InfoCard(title: "Kernel Version", value: systemInfo.kernelVersion)
                InfoCard(title: "Model Identifier", value: systemInfo.modelIdentifier)
                InfoCard(title: "Processor", value: systemInfo.processor)
                InfoCard(title: "Processor Details", value: systemInfo.processorDetails)
                InfoCard(title: "Memory", value: systemInfo.memory)
                InfoCard(title: "System UUID", value: systemInfo.systemUUID)
                InfoCard(title: "Platform UUID", value: systemInfo.platformUUID)
                InfoCard(title: "Serial Number", value: systemInfo.serialNumber)
                InfoCard(title: "Boot ROM Version", value: systemInfo.bootROMVersion)
                InfoCard(title: "SMC Version", value: systemInfo.smcVersion)
                InfoCard(title: "Boot Mode", value: systemInfo.bootMode)
                InfoCard(title: "SIP Status", value: ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
                InfoCard(title: "EFI Status", value: efiPath != nil ? "Mounted ✓" : "Not Mounted ✗")
                InfoCard(title: "Audio Status", value: getAudioStatus())
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var graphicsInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Graphics Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.gpuInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var networkInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.networkInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var wirelessInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wireless Network Controller")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.wirelessInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var storageInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Controllers")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.storageInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var usbInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("USB Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.usbInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var usbXHCInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("USB eXtensible Host-Controller (XHC)")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.usbXHCInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var thunderboltInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thunderbolt Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.thunderboltInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var ethernetInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ethernet Controller")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.ethernetInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var nvmeInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NVMe Controller")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.nvmeInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var ahciInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AHCI/SATA Controller")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.ahciInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var audioInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.audioInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
            
            // Audio Kext Status
            VStack(spacing: 8) {
                Text("Audio Kext Status")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    StatusBadge(
                        title: "Lilu",
                        status: liluStatus,
                        color: liluStatus == "Installed" ? .green : .red
                    )
                    StatusBadge(
                        title: "AppleALC",
                        status: appleALCStatus,
                        color: appleALCStatus == "Installed" ? .green : .red
                    )
                    StatusBadge(
                        title: "AppleHDA",
                        status: appleHDAStatus,
                        color: appleHDAStatus == "Installed" ? .green : .red
                    )
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var bluetoothInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bluetooth Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.bluetoothInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var pciInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PCI Devices")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(systemInfo.pciDevices)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 300)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var drivesInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Drives")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(showAllDrives ? "Show Less" : "Show All") {
                    showAllDrives.toggle()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            VStack(spacing: 12) {
                DriveSummaryCard(
                    title: "Internal Storage",
                    icon: "internaldrive.fill",
                    color: .blue,
                    drives: internalDrives,
                    isExpanded: showAllDrives
                )
                
                DriveSummaryCard(
                    title: "External Storage",
                    icon: "externaldrive.fill",
                    color: .orange,
                    drives: externalDrives,
                    isExpanded: showAllDrives
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties and Functions
    
    var internalDrives: [DriveInfo] {
        allDrives.filter { $0.isInternal }
    }
    
    var externalDrives: [DriveInfo] {
        allDrives.filter { !$0.isInternal }
    }
    
    private func getAudioStatus() -> String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working ✓"
        } else {
            return "Setup Required ⚠️"
        }
    }
}

// MARK: - Detail Section Button Component
struct DetailSectionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}