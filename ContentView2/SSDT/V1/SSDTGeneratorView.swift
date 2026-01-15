import SwiftUI

struct SSDTGeneratorView: View {
    @State private var systemInfo: [String: String] = [:]
    @State private var selectedPlatform: String = "Auto-detect"
    @State private var selectedFeatures: Set<String> = []
    @State private var ssdtCode: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSavePanel = false
    @State private var generatedFilePath: URL?
    
    let platforms = [
        "Auto-detect",
        "Intel Desktop",
        "Intel Laptop",
        "AMD Desktop",
        "AMD Laptop",
        "Custom"
    ]
    
    let availableFeatures = [
        "USB Mapping",
        "Power Management",
        "Graphics",
        "Audio",
        "Ethernet",
        "Wi-Fi",
        "Bluetooth",
        "Thunderbolt",
        "NVMe",
        "SATA"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("SSDT Generator")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: generateSSDT) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Generate SSDT")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                
                // Platform Selection
                PlatformSelectionSection
                
                // Features Selection
                FeaturesSelectionSection
                
                // System Info
                SystemInfoSection
                
                // Generated Code Preview
                if !ssdtCode.isEmpty {
                    GeneratedCodeSection
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            gatherSystemInfo()
        }
        .alert("SSDT Generator", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .fileExporter(
            isPresented: $showSavePanel,
            document: SSDTDocument(text: ssdtCode),
            contentType: .amlFile,
            defaultFilename: "generated_ssdt.aml"
        ) { result in
            switch result {
            case .success(let url):
                alertMessage = "SSDT saved to: \(url.path)"
                generatedFilePath = url
                showAlert = true
            case .failure(let error):
                alertMessage = "Failed to save SSDT: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private var PlatformSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform Selection")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select target platform:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(platforms, id: \.self) { platform in
                        Text(platform)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var FeaturesSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SSDT Features")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select features to include in SSDT:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(availableFeatures, id: \.self) { feature in
                    FeatureToggle(feature: feature, isSelected: selectedFeatures.contains(feature)) {
                        if selectedFeatures.contains(feature) {
                            selectedFeatures.remove(feature)
                        } else {
                            selectedFeatures.insert(feature)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var SystemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            if systemInfo.isEmpty {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Gathering system information...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    InfoRow(label: "Processor:", value: systemInfo["processor"] ?? "Unknown")
                    InfoRow(label: "Motherboard:", value: systemInfo["motherboard"] ?? "Unknown")
                    InfoRow(label: "BIOS:", value: systemInfo["bios"] ?? "Unknown")
                    InfoRow(label: "Memory:", value: systemInfo["memory"] ?? "Unknown")
                    InfoRow(label: "Graphics:", value: systemInfo["graphics"] ?? "Unknown")
                    InfoRow(label: "Network:", value: systemInfo["network"] ?? "Unknown")
                    InfoRow(label: "Audio:", value: systemInfo["audio"] ?? "Unknown")
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var GeneratedCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated SSDT Code")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showSavePanel = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save As AML")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            TextEditor(text: .constant(ssdtCode))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Text("\(ssdtCode.components(separatedBy: "\n").count) lines of code")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private func FeatureToggle(feature: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(feature)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func InfoRow(label: String, value: String) -> View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    private func gatherSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let shellHelper = ShellHelper.shared
            var info: [String: String] = [:]
            
            // Get processor info
            let processor = shellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output
            info["processor"] = processor.isEmpty ? "Unknown" : processor
            
            // Try to get motherboard info (for Hackintosh this would be custom)
            info["motherboard"] = "Custom (Hackintosh)"
            
            // Get BIOS/UEFI info
            let bios = shellHelper.runCommand("system_profiler SPHardwareDataType | grep 'Boot ROM Version' | awk -F': ' '{print $2}'").output
            info["bios"] = bios.isEmpty ? "Unknown" : bios
            
            // Get memory info
            let memory = shellHelper.runCommand("sysctl -n hw.memsize").output
            if let memBytes = UInt64(memory), memBytes > 0 {
                let memGB = Double(memBytes) / 1_073_741_824.0
                info["memory"] = String(format: "%.1f GB", memGB)
            } else {
                info["memory"] = "Unknown"
            }
            
            // Get graphics info
            let graphics = shellHelper.runCommand("system_profiler SPDisplaysDataType | grep 'Chipset Model:' | head -1 | awk -F': ' '{print $2}'").output
            info["graphics"] = graphics.isEmpty ? "Unknown" : graphics
            
            // Get network info
            let network = shellHelper.runCommand("system_profiler SPNetworkDataType | grep 'Type:' | head -2 | awk -F': ' '{print $2}' | tr '\\n' ','").output
            info["network"] = network.isEmpty ? "Unknown" : network.trimmingCharacters(in: CharacterSet(charactersIn: ","))
            
            // Get audio info
            let audio = shellHelper.runCommand("system_profiler SPAudioDataType | grep '_name:' | head -2 | awk -F': ' '{print $2}' | tr '\\n' ','").output
            info["audio"] = audio.isEmpty ? "Unknown" : audio.trimmingCharacters(in: CharacterSet(charactersIn: ","))
            
            DispatchQueue.main.async {
                self.systemInfo = info
                self.isLoading = false
                
                // Auto-detect platform based on processor
                if processor.contains("Intel") {
                    self.selectedPlatform = processor.contains("Mobile") || processor.contains("U") || processor.contains("H") ? "Intel Laptop" : "Intel Desktop"
                } else if processor.contains("AMD") {
                    self.selectedPlatform = processor.contains("Mobile") || processor.contains("U") || processor.contains("H") ? "AMD Laptop" : "AMD Desktop"
                }
            }
        }
    }
    
    private func generateSSDT() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Generate SSDT based on selected platform and features
            var ssdt = "/*\n"
            ssdt += " * Generated SSDT\n"
            ssdt += " * Platform: \(self.selectedPlatform)\n"
            ssdt += " * Features: \(self.selectedFeatures.sorted().joined(separator: ", "))\n"
            ssdt += " * Generated: \(Date())\n"
            ssdt += " * Generator: SystemMaintenance SSDT Generator\n"
            ssdt += " */\n\n"
            
            // Add AML header
            ssdt += "DefinitionBlock (\"\", \"SSDT\", 2, \"SYSTEM\", \"SSDT\", 0x00001000)\n"
            ssdt += "{\n"
            
            // Add processor scope if Intel
            if self.selectedPlatform.contains("Intel") {
                ssdt += "    Scope (_SB.PC00)\n"
                ssdt += "    {\n"
                
                // Add CPU power management
                if self.selectedFeatures.contains("Power Management") {
                    ssdt += generateCPUPowerManagement()
                }
                
                ssdt += "    }\n\n"
            }
            
            // Add device entries based on selected features
            for feature in self.selectedFeatures.sorted() {
                ssdt += generateFeatureSSDT(feature: feature)
            }
            
            // Add closing brace
            ssdt += "}\n"
            
            DispatchQueue.main.async {
                self.ssdtCode = ssdt
                self.isLoading = false
                self.alertMessage = "SSDT generated successfully with \(self.selectedFeatures.count) features"
                self.showAlert = true
            }
        }
    }
    
    private func generateCPUPowerManagement() -> String {
        return """
        // CPU Power Management
        Processor (CP00, 0x00, 0x00000410, 0x06)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, Zero)
        }
        
        Processor (CP01, 0x01, 0x00000410, 0x06)
        {
            Name (_HID, "ACPI0007")
            Name (_UID, One)
        }
        
        """
    }
    
    private func generateFeatureSSDT(feature: String) -> String {
        switch feature {
        case "USB Mapping":
            return """
            // USB Mapping
            Device (XHCI)
            {
                Name (_HID, "XHCI")
                Name (_UID, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "Graphics":
            return """
            // Graphics Device
            Device (GFX0)
            {
                Name (_ADR, Zero)
                Name (_SUN, One)
                
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x02)
                    {
                        "model", 
                        Buffer () { "Graphics Device" }
                    }, Local0)
                    Return (Local0)
                }
            }
            
            """
            
        case "Audio":
            return """
            // Audio Device
            Device (HDEF)
            {
                Name (_ADR, 0x001B0000)
                
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x04)
                    {
                        "layout-id", 
                        Buffer () { 0x0C, 0x00, 0x00, 0x00 },
                        "PinConfigurations", 
                        Buffer () { }
                    }, Local0)
                    Return (Local0)
                }
            }
            
            """
            
        case "Ethernet":
            return """
            // Ethernet Device
            Device (ETH0)
            {
                Name (_ADR, Zero)
                Name (_SUN, One)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "Wi-Fi":
            return """
            // Wi-Fi Device
            Device (WIFI)
            {
                Name (_ADR, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "Bluetooth":
            return """
            // Bluetooth Device
            Device (BT)
            {
                Name (_ADR, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "Thunderbolt":
            return """
            // Thunderbolt Device
            Device (TB)
            {
                Name (_ADR, 0x001D0000)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "NVMe":
            return """
            // NVMe Storage
            Device (NVME)
            {
                Name (_ADR, Zero)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        case "SATA":
            return """
            // SATA Controller
            Device (SATA)
            {
                Name (_ADR, 0x001F0002)
                
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
            
            """
            
        default:
            return ""
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ssdtCode, forType: .string)
        
        alertMessage = "SSDT code copied to clipboard"
        showAlert = true
    }
}

// Custom document type for AML files
struct SSDTDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.amlFile] }
    
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// Extension for AML file type
extension UTType {
    static var amlFile: UTType {
        UTType(importedAs: "com.apple.aml")
    }
}