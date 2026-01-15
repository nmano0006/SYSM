import SwiftUI
import UniformTypeIdentifiers

struct SSDTGeneratorView: View {
    @State private var systemInfo: SystemInfo = SystemInfo()
    @State private var selectedPlatform: String = "Auto-detect"
    @State private var selectedMotherboard: String = "Custom"
    @State private var selectedGPU: String = "Auto-detect"
    @State private var selectedFeatures: Set<SSDTFeature> = []
    @State private var ssdtCode: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSavePanel = false
    @State private var showAdvancedOptions = false
    @State private var ssdtType: SSDTType = .normal
    @State private var customAcpiPath: String = ""
    @State private var showPreview = true
    @State private var generatedSSDTs: [GeneratedSSDT] = []
    
    let platforms = [
        "Auto-detect",
        "Intel Desktop",
        "Intel Laptop",
        "Intel NUC",
        "AMD Desktop",
        "AMD Laptop",
        "AMD APU"
    ]
    
    let motherboards = [
        "Custom",
        "Gigabyte Z390",
        "Gigabyte Z490",
        "ASUS Z390",
        "ASUS Z490",
        "ASRock Z390",
        "MSI Z390",
        "Gigabyte B460",
        "ASUS B460",
        "ASRock B460"
    ]
    
    let gpus = [
        "Auto-detect",
        "Intel UHD 630",
        "Intel UHD 630 (Desktop)",
        "Intel UHD 630 (Mobile)",
        "Intel Iris Plus",
        "AMD Radeon RX 580",
        "AMD Radeon RX 5700 XT",
        "AMD Radeon Vega 56/64",
        "NVIDIA GTX 1060",
        "NVIDIA RTX 2080"
    ]
    
    let ssdtTypes: [SSDTType] = [.normal, .hotpatch, .custom]
    
    let allFeatures: [SSDTFeature] = [
        SSDTFeature(id: "USB", name: "USB Mapping", description: "Generate USB port mapping SSDT", enabled: true),
        SSDTFeature(id: "PLUG", name: "CPU Power", description: "Generate CPU power management SSDT", enabled: true),
        SSDTFeature(id: "PMCR", name: "PMC", description: "Generate PMC SSDT for 300+ series boards", enabled: false),
        SSDTFeature(id: "AWAC", name: "AWAC Clock", description: "Fix AWAC system clock", enabled: false),
        SSDTFeature(id: "EC", name: "Embedded Controller", description: "Create fake EC device", enabled: true),
        SSDTFeature(id: "PNLF", name: "Backlight", description: "Generate backlight control SSDT", enabled: false),
        SSDTFeature(id: "ALS0", name: "Ambient Light", description: "Add ambient light sensor", enabled: false),
        SSDTFeature(id: "HPET", name: "HPET", description: "Fix HPET IRQ conflicts", enabled: false),
        SSDTFeature(id: "XOSI", name: "_OSI Patches", description: "Windows compatibility patches", enabled: false),
        SSDTFeature(id: "GPIO", name: "GPIO", description: "Generate GPIO pin mapping", enabled: false),
        SSDTFeature(id: "SLPB", name: "Sleep", description: "Fix sleep/wake issues", enabled: false),
        SSDTFeature(id: "IMEI", name: "IMEI", description: "Create IMEI device", enabled: false)
    ]
    
    var enabledFeatures: [SSDTFeature] {
        allFeatures.filter { $0.enabled }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HeaderView
                
                // Configuration Sections
                ConfigurationSections
                
                // Advanced Options
                AdvancedOptionsSection
                
                // Generated SSDTs List
                if !generatedSSDTs.isEmpty {
                    GeneratedSSDTsList
                }
                
                // Generated Code Preview
                if showPreview && !ssdtCode.isEmpty {
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
            defaultFilename: "SSDT-\(selectedPlatform.replacingOccurrences(of: " ", with: "-")).aml"
        ) { result in
            handleSaveResult(result)
        }
    }
    
    // MARK: - Header View
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SSDT Generator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Advanced ACPI Table Generator for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: generateSSDT) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Generate SSDT")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button(action: generateAllSSDTs) {
                    HStack {
                        Image(systemName: "gearshape.2.fill")
                        Text("Generate All")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Configuration Sections
    private var ConfigurationSections: some View {
        VStack(spacing: 16) {
            // Platform Selection
            ConfigurationSection(title: "Platform Configuration", icon: "desktopcomputer") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Platform Type:")
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $selectedPlatform) {
                            ForEach(platforms, id: \.self) { platform in
                                Text(platform)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    
                    HStack {
                        Text("Motherboard:")
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $selectedMotherboard) {
                            ForEach(motherboards, id: \.self) { mb in
                                Text(mb)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    
                    HStack {
                        Text("Graphics:")
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $selectedGPU) {
                            ForEach(gpus, id: \.self) { gpu in
                                Text(gpu)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                }
                .padding()
            }
            
            // Features Selection
            ConfigurationSection(title: "SSDT Features", icon: "puzzlepiece.fill") {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(enabledFeatures) { feature in
                        FeatureToggle(feature: feature)
                    }
                }
                .padding()
            }
            
            // System Info Display
            ConfigurationSection(title: "System Information", icon: "info.circle") {
                SystemInfoView(systemInfo: systemInfo)
                    .padding()
            }
        }
    }
    
    // MARK: - Advanced Options Section
    private var AdvancedOptionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showAdvancedOptions.toggle() }) {
                HStack {
                    Image(systemName: showAdvancedOptions ? "chevron.down" : "chevron.right")
                    Text("Advanced Options")
                        .font(.headline)
                    Spacer()
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            if showAdvancedOptions {
                VStack(spacing: 12) {
                    HStack {
                        Text("SSDT Type:")
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $ssdtType) {
                            ForEach(ssdtTypes, id: \.self) { type in
                                Text(type.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if ssdtType == .custom {
                        HStack {
                            Text("ACPI Path:")
                                .fontWeight(.medium)
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("e.g., \\_SB.PCI0", text: $customAcpiPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    Toggle("Show Preview", isOn: $showPreview)
                        .toggleStyle(.switch)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Generated SSDTs List
    private var GeneratedSSDTsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated SSDTs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(generatedSSDTs.count) SSDTs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(generatedSSDTs) { ssdt in
                GeneratedSSDTRow(ssdt: ssdt)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Generated Code Section
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
                        Text("Save")
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
                
                Button(action: compileSSDT) {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Compile")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(!canCompileSSDT)
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
            
            Text("\(ssdtCode.components(separatedBy: "\n").count) lines • \(ssdtCode.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    private func ConfigurationSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
        }
    }
    
    private func FeatureToggle(feature: SSDTFeature) -> some View {
        Button(action: {
            if selectedFeatures.contains(feature) {
                selectedFeatures.remove(feature)
            } else {
                selectedFeatures.insert(feature)
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: selectedFeatures.contains(feature) ? "checkmark.square.fill" : "square")
                        .foregroundColor(selectedFeatures.contains(feature) ? .green : .secondary)
                    
                    Text(feature.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedFeatures.contains(feature) ? Color.green.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedFeatures.contains(feature) ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func GeneratedSSDTRow(ssdt: GeneratedSSDT) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ssdt.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(ssdt.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(ssdt.size) bytes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(ssdt.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Button(action: { loadSSDT(ssdt) }) {
                Image(systemName: "eye")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Preview SSDT")
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var canCompileSSDT: Bool {
        // Check if iasl compiler is available
        let shellHelper = ShellHelper.shared
        let result = shellHelper.runCommand("which iasl")
        return result.success
    }
    
    // MARK: - System Info View
    private struct SystemInfoView: View {
        let systemInfo: SystemInfo
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Processor:", value: systemInfo.processor)
                InfoRow(label: "Cores:", value: systemInfo.cores)
                InfoRow(label: "Memory:", value: systemInfo.memory)
                InfoRow(label: "Model:", value: systemInfo.model)
                InfoRow(label: "Boot Mode:", value: systemInfo.bootMode)
                InfoRow(label: "SIP Status:", value: systemInfo.sipStatus)
            }
        }
        
        private func InfoRow(label: String, value: String) -> some View {
            HStack {
                Text(label)
                    .fontWeight(.medium)
                    .frame(width: 100, alignment: .leading)
                
                Text(value)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Data Models
    struct SystemInfo {
        var processor: String = "Unknown"
        var cores: String = "Unknown"
        var memory: String = "Unknown"
        var model: String = "Unknown"
        var bootMode: String = "Unknown"
        var sipStatus: String = "Unknown"
        var graphics: String = "Unknown"
        var biosVersion: String = "Unknown"
    }
    
    struct SSDTFeature: Identifiable, Hashable {
        let id: String
        let name: String
        let description: String
        let enabled: Bool
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: SSDTFeature, rhs: SSDTFeature) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct GeneratedSSDT: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let code: String
        let size: Int
        let features: [String]
    }
    
    enum SSDTType: String, CaseIterable {
        case normal = "Normal"
        case hotpatch = "Hotpatch"
        case custom = "Custom"
    }
    
    // MARK: - System Info Gathering
    private func gatherSystemInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let shellHelper = ShellHelper.shared
            var info = SystemInfo()
            
            // Get processor info
            let processor = shellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output
            info.processor = processor.isEmpty ? "Unknown" : processor
            
            // Get core count
            let cores = shellHelper.runCommand("sysctl -n hw.ncpu").output
            info.cores = cores.isEmpty ? "Unknown" : "\(cores) cores"
            
            // Get memory
            let memory = shellHelper.runCommand("sysctl -n hw.memsize").output
            if let memBytes = UInt64(memory), memBytes > 0 {
                let memGB = Double(memBytes) / 1_073_741_824.0
                info.memory = String(format: "%.1f GB", memGB)
            }
            
            // Get model identifier
            let model = shellHelper.runCommand("sysctl -n hw.model").output
            info.model = model.isEmpty ? "Unknown" : model
            
            // Get boot mode (UEFI/Legacy)
            let bootMode = shellHelper.runCommand("system_profiler SPSoftwareDataType | grep 'Boot Mode' | awk -F': ' '{print $2}'").output
            info.bootMode = bootMode.isEmpty ? "Unknown" : bootMode
            
            // Get SIP status
            let sipStatus = shellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output
            info.sipStatus = sipStatus.isEmpty ? "Unknown" : sipStatus
            
            // Get graphics info
            let graphics = shellHelper.runCommand("system_profiler SPDisplaysDataType | grep 'Chipset Model:' | head -1 | awk -F': ' '{print $2}'").output
            info.graphics = graphics.isEmpty ? "Unknown" : graphics
            
            // Auto-detect platform
            let platform = self.autoDetectPlatform(processor: processor, graphics: graphics)
            
            DispatchQueue.main.async {
                self.systemInfo = info
                self.selectedPlatform = platform
                self.isLoading = false
                
                // Auto-select GPU based on detection
                if graphics.contains("UHD Graphics 630") {
                    self.selectedGPU = info.model.contains("MacBook") ? "Intel UHD 630 (Mobile)" : "Intel UHD 630 (Desktop)"
                } else if graphics.contains("Radeon RX") {
                    self.selectedGPU = "AMD Radeon RX 580"
                }
                
                // Auto-select features based on platform
                self.autoSelectFeatures(for: platform)
            }
        }
    }
    
    private func autoDetectPlatform(processor: String, graphics: String) -> String {
        if processor.contains("Intel") {
            if processor.contains("Mobile") || processor.contains("U") || processor.contains("H") {
                return "Intel Laptop"
            } else if processor.contains("NUC") {
                return "Intel NUC"
            } else {
                return "Intel Desktop"
            }
        } else if processor.contains("AMD") {
            if processor.contains("Mobile") || processor.contains("U") || processor.contains("H") {
                return "AMD Laptop"
            } else if graphics.contains("Radeon Graphics") {
                return "AMD APU"
            } else {
                return "AMD Desktop"
            }
        }
        return "Auto-detect"
    }
    
    private func autoSelectFeatures(for platform: String) {
        var features: Set<SSDTFeature> = []
        
        // Always select these features
        if let plug = enabledFeatures.first(where: { $0.id == "PLUG" }) {
            features.insert(plug)
        }
        
        if let ec = enabledFeatures.first(where: { $0.id == "EC" }) {
            features.insert(ec)
        }
        
        // Platform-specific features
        switch platform {
        case "Intel Desktop", "Intel Laptop", "Intel NUC":
            if let usb = enabledFeatures.first(where: { $0.id == "USB" }) {
                features.insert(usb)
            }
            if let awac = enabledFeatures.first(where: { $0.id == "AWAC" }) {
                features.insert(awac)
            }
            
        case "AMD Desktop", "AMD Laptop", "AMD APU":
            if let ec = enabledFeatures.first(where: { $0.id == "EC" }) {
                features.insert(ec)
            }
            
        default:
            break
        }
        
        selectedFeatures = features
    }
    
    // MARK: - SSDT Generation
    private func generateSSDT() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Generate SSDT based on selected configuration
            let ssdt = self.generateSSDTCode()
            
            DispatchQueue.main.async {
                self.ssdtCode = ssdt
                self.isLoading = false
                
                // Add to generated SSDTs list
                let generatedSSDT = GeneratedSSDT(
                    name: "SSDT-\(self.getSSDTName())",
                    description: "Generated for \(self.selectedPlatform)",
                    code: ssdt,
                    size: ssdt.count,
                    features: self.selectedFeatures.map { $0.id }
                )
                
                if let index = self.generatedSSDTs.firstIndex(where: { $0.name == generatedSSDT.name }) {
                    self.generatedSSDTs[index] = generatedSSDT
                } else {
                    self.generatedSSDTs.append(generatedSSDT)
                }
                
                self.alertMessage = "SSDT generated successfully with \(self.selectedFeatures.count) features"
                self.showAlert = true
            }
        }
    }
    
    private func generateAllSSDTs() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allSSDTs: [GeneratedSSDT] = []
            
            // Generate SSDT for each feature
            for feature in self.enabledFeatures {
                if self.selectedFeatures.contains(feature) {
                    let ssdt = self.generateSingleSSDT(for: feature)
                    let generatedSSDT = GeneratedSSDT(
                        name: "SSDT-\(feature.id)",
                        description: feature.description,
                        code: ssdt,
                        size: ssdt.count,
                        features: [feature.id]
                    )
                    allSSDTs.append(generatedSSDT)
                }
            }
            
            // Generate combined SSDT
            if allSSDTs.count > 1 {
                let combinedSSDT = self.generateCombinedSSDT(ssdts: allSSDTs)
                let combined = GeneratedSSDT(
                    name: "SSDT-ALL",
                    description: "Combined SSDT with all features",
                    code: combinedSSDT,
                    size: combinedSSDT.count,
                    features: self.selectedFeatures.map { $0.id }
                )
                allSSDTs.insert(combined, at: 0)
            }
            
            DispatchQueue.main.async {
                self.generatedSSDTs = allSSDTs
                
                if let mainSSDT = allSSDTs.first {
                    self.ssdtCode = mainSSDT.code
                }
                
                self.isLoading = false
                self.alertMessage = "Generated \(allSSDTs.count) SSDTs"
                self.showAlert = true
            }
        }
    }
    
    private func getSSDTName() -> String {
        let baseName = selectedPlatform.replacingOccurrences(of: " ", with: "-")
        let featureCodes = selectedFeatures.map { $0.id }.sorted().joined(separator: "-")
        return "\(baseName)-\(featureCodes)"
    }
    
    private func generateSSDTCode() -> String {
        var ssdt = "/*\n"
        ssdt += " * SSDT Generated by SystemMaintenance\n"
        ssdt += " * Platform: \(selectedPlatform)\n"
        ssdt += " * Motherboard: \(selectedMotherboard)\n"
        ssdt += " * GPU: \(selectedGPU)\n"
        ssdt += " * Features: \(selectedFeatures.map { $0.name }.sorted().joined(separator: ", "))\n"
        ssdt += " * Type: \(ssdtType.rawValue)\n"
        ssdt += " * Generated: \(Date())\n"
        ssdt += " */\n\n"
        
        // Add definition block
        let oemTableId = "SSDT"
        let oemId = "SYSTEM"
        let tableId = "SSDT"
        
        ssdt += "DefinitionBlock (\"\", \"\(oemTableId)\", 2, \"\(oemId)\", \"\(tableId)\", 0x00001000)\n"
        ssdt += "{\n"
        
        // Add SSDT content based on features
        for feature in selectedFeatures.sorted(by: { $0.id < $1.id }) {
            ssdt += generateFeatureCode(feature: feature)
        }
        
        // Add platform-specific patches
        ssdt += generatePlatformSpecificCode()
        
        ssdt += "}\n"
        
        return ssdt
    }
    
    private func generateSingleSSDT(for feature: SSDTFeature) -> String {
        var ssdt = "/*\n"
        ssdt += " * SSDT-\(feature.id) Generated by SystemMaintenance\n"
        ssdt += " * Feature: \(feature.name)\n"
        ssdt += " * Generated: \(Date())\n"
        ssdt += " */\n\n"
        
        ssdt += "DefinitionBlock (\"\", \"SSDT\", 2, \"SYSTEM\", \"\(feature.id)\", 0x00001000)\n"
        ssdt += "{\n"
        
        ssdt += generateFeatureCode(feature: feature)
        
        ssdt += "}\n"
        
        return ssdt
    }
    
    private func generateCombinedSSDT(ssdts: [GeneratedSSDT]) -> String {
        var ssdt = "/*\n"
        ssdt += " * Combined SSDT Generated by SystemMaintenance\n"
        ssdt += " * Contains: \(ssdts.count) features\n"
        ssdt += " * Generated: \(Date())\n"
        ssdt += " */\n\n"
        
        ssdt += "DefinitionBlock (\"\", \"SSDT\", 2, \"SYSTEM\", \"ALL\", 0x00001000)\n"
        ssdt += "{\n"
        
        // Combine all feature codes
        for feature in selectedFeatures.sorted(by: { $0.id < $1.id }) {
            ssdt += generateFeatureCode(feature: feature)
        }
        
        ssdt += "}\n"
        
        return ssdt
    }
    
    private func generateFeatureCode(feature: SSDTFeature) -> String {
        switch feature.id {
        case "PLUG":
            return generateCPUPMCode()
        case "EC":
            return generateECCode()
        case "USB":
            return generateUSBMapCode()
        case "AWAC":
            return generateAWAWCode()
        case "PMCR":
            return generatePMCRCode()
        case "PNLF":
            return generatePNLFCode()
        case "HPET":
            return generateHPETCode()
        case "XOSI":
            return generateXOSICode()
        default:
            return generateGenericFeatureCode(feature: feature)
        }
    }
    
    private func generateCPUPMCode() -> String {
        return """
        /*
         * CPU Power Management
         * Enables X86PlatformPlugin
         */
        External (_SB_.PCI0, DeviceObj)
        
        Scope (_SB.PCI0)
        {
            Device (PR00)
            {
                Name (_HID, EisaId ("ACPI0007"))
                Name (_UID, Zero)
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
        }
        
        """
    }
    
    private func generateECCode() -> String {
        return """
        /*
         * Embedded Controller
         * Creates fake EC device
         */
        Scope (_SB)
        {
            Device (EC)
            {
                Name (_HID, EisaId ("ACPI0008"))
                Name (_UID, Zero)
                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
                
                // Basic EC methods
                Method (_REG, 2, NotSerialized)
                {
                    // Empty implementation
                }
            }
        }
        
        """
    }
    
    private func generateUSBMapCode() -> String {
        return """
        /*
         * USB Port Mapping
         * Disables unused ports to stay within 15-port limit
         */
        Scope (_SB.PCI0)
        {
            Device (XHC)
            {
                Name (_ADR, 0x00140000)
                
                // HSxx ports (USB 2.0)
                Name (HS01, Package() { 0x01, 0x03, 0x00, 0x00 }) // Enabled
                Name (HS02, Package() { 0x02, 0x03, 0x00, 0x00 }) // Enabled
                Name (HS03, Package() { 0x03, 0x03, 0x00, 0x00 }) // Enabled
                Name (HS04, Package() { 0x04, 0x03, 0x00, 0x00 }) // Enabled
                Name (HS05, Package() { 0x05, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS06, Package() { 0x06, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS07, Package() { 0x07, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS08, Package() { 0x08, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS09, Package() { 0x09, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS10, Package() { 0x0A, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS11, Package() { 0x0B, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS12, Package() { 0x0C, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS13, Package() { 0x0D, 0x00, 0x00, 0x00 }) // Disabled
                Name (HS14, Package() { 0x0E, 0x00, 0x00, 0x00 }) // Disabled
                
                // SSxx ports (USB 3.0)
                Name (SS01, Package() { 0x01, 0x03, 0x00, 0x00 }) // Enabled
                Name (SS02, Package() { 0x02, 0x03, 0x00, 0x00 }) // Enabled
                Name (SS03, Package() { 0x03, 0x03, 0x00, 0x00 }) // Enabled
                Name (SS04, Package() { 0x04, 0x03, 0x00, 0x00 }) // Enabled
                Name (SS05, Package() { 0x05, 0x00, 0x00, 0x00 }) // Disabled
                Name (SS06, Package() { 0x06, 0x00, 0x00, 0x00 }) // Disabled
                Name (SS07, Package() { 0x07, 0x00, 0x00, 0x00 }) // Disabled
                Name (SS08, Package() { 0x08, 0x00, 0x00, 0x00 }) // Disabled
                Name (SS09, Package() { 0x09, 0x00, 0x00, 0x00 }) // Disabled
                Name (SS10, Package() { 0x0A, 0x00, 0x00, 0x00 }) // Disabled
            }
        }
        
        """
    }
    
    private func generateAWAWCode() -> String {
        return """
        /*
         * AWAC System Clock Fix
         * Fixes AWAC system clock on 300+ series motherboards
         */
        Method (_STA, 0, NotSerialized)
        {
            If (_OSI ("Darwin"))
            {
                Return (Zero) // Disable AWAC
            }
            Else
            {
                Return (0x0F) // Enable for other OS
            }
        }
        
        // Enable RTC
        Device (RTC)
        {
            Name (_HID, EisaId ("PNP0B00"))
            Name (_CRS, ResourceTemplate()
            {
                IO (Decode16, 0x0070, 0x0070, 0x01, 0x08)
            })
            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)
            }
        }
        
        """
    }
    
    private func generatePMCRCode() -> String {
        return """
        /*
         * PMC (Power Management Controller)
         * Required for 300+ series Intel motherboards
         */
        Device (PMCR)
        {
            Name (_HID, EisaId ("APP9876"))
            Name (_CID, "PMCR")
            Name (_STA, 0x0F)
            
            Method (_DSM, 4, NotSerialized)
            {
                Store (Package (0x02)
                {
                    "app9876,force-enable", 
                    Buffer (One) { 0x01 }
                }, Local0)
                Return (Local0)
            }
        }
        
        """
    }
    
    private func generatePNLFCode() -> String {
        return """
        /*
         * Backlight Control (PNLF)
         * Enables brightness control
         */
        Device (PNLF)
        {
            Name (_HID, EisaId ("APP0002"))
            Name (_CID, "backlight")
            Name (_UID, 0x0A)
            Name (_STA, 0x0B)
            
            Method (_DOS, 1, NotSerialized)
            {
                // Display Output Set method
            }
            
            Method (_BCL, 0, NotSerialized)
            {
                Return (Package()
                {
                    0x64, // 100% brightness
                    0x32, // 50% brightness
                    0x00  // 0% brightness
                })
            }
        }
        
        """
    }
    
    private func generateHPETCode() -> String {
        return """
        /*
         * HPET IRQ Fix
         * Fixes HPET IRQ conflicts
         */
        Scope (_SB)
        {
            Device (HPET)
            {
                Name (_HID, EisaId ("PNP0103"))
                Name (_CRS, ResourceTemplate()
                {
                    IRQNoFlags () { 0, 8, 11, 15 }
                    Memory32Fixed (ReadWrite, 0xFED00000, 0x00000400)
                })
            }
        }
        
        """
    }
    
    private func generateXOSICode() -> String {
        return """
        /*
         * _OSI Patches for Windows Compatibility
         */
        Method (_OSI, 1, NotSerialized)
        {
            // Check if query is for Windows
            If (_OSI ("Darwin"))
            {
                // Return true for common Windows queries
                If (CondRefOf (Arg0, Local0))
                {
                    // Common Windows OSI strings
                    If (LNotEqual (Arg0, "Windows 2001"))
                    {
                        If (LNotEqual (Arg0, "Windows 2001 SP1"))
                        {
                            If (LNotEqual (Arg0, "Windows 2001.1"))
                            {
                                If (LNotEqual (Arg0, "Windows 2006"))
                                {
                                    If (LNotEqual (Arg0, "Windows 2009"))
                                    {
                                        If (LNotEqual (Arg0, "Windows 2012"))
                                        {
                                            If (LNotEqual (Arg0, "Windows 2013"))
                                            {
                                                If (LNotEqual (Arg0, "Windows 2015"))
                                                {
                                                    Return (Zero)
                                                }
                                                Else
                                                {
                                                    Return (0xFFFFFFFF)
                                                }
                                            }
                                            Else
                                            {
                                                Return (0xFFFFFFFF)
                                            }
                                        }
                                        Else
                                        {
                                            Return (0xFFFFFFFF)
                                        }
                                    }
                                    Else
                                    {
                                        Return (0xFFFFFFFF)
                                    }
                                }
                                Else
                                {
                                    Return (0xFFFFFFFF)
                                }
                            }
                            Else
                            {
                                Return (0xFFFFFFFF)
                            }
                        }
                        Else
                        {
                            Return (0xFFFFFFFF)
                        }
                    }
                    Else
                    {
                        Return (0xFFFFFFFF)
                    }
                }
            }
            Return (Zero)
        }
        
        """
    }
    
    private func generateGenericFeatureCode(feature: SSDTFeature) -> String {
        return """
        /*
         * \(feature.name)
         * \(feature.description)
         */
        // Placeholder for \(feature.id) feature implementation
        
        """
    }
    
    private func generatePlatformSpecificCode() -> String {
        var code = ""
        
        // Add GPU-specific code
        if selectedGPU != "Auto-detect" {
            code += generateGPUCode()
        }
        
        // Add motherboard-specific patches
        if selectedMotherboard != "Custom" {
            code += generateMotherboardCode()
        }
        
        return code
    }
    
    private func generateGPUCode() -> String {
        var code = "\n    /*\n     * GPU Configuration for \(selectedGPU)\n     */\n"
        
        if selectedGPU.contains("Intel UHD 630") {
            code += """
            Device (GFX0)
            {
                Name (_ADR, 0x00020000)
                Name (_SUN, One)
                
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x16)
                    {
                        "AAPL,ig-platform-id", 
                        Buffer (0x04) { 0x03, 0x00, 0x66, 0x01 },
                        "device-id", 
                        Buffer (0x04) { 0x92, 0x3E, 0x00, 0x00 },
                        "model", 
                        Buffer () { "Intel UHD Graphics 630" },
                        "hda-gfx", 
                        Buffer () { "onboard-1" },
                        "AAPL,slot-name", 
                        Buffer () { "Built-In" },
                        "@0,connector-type", 
                        Buffer () { 0x00, 0x08, 0x00, 0x00 },
                        "@1,connector-type", 
                        Buffer () { 0x00, 0x08, 0x00, 0x00 },
                        "@2,connector-type", 
                        Buffer () { 0x00, 0x08, 0x00, 0x00 },
                        "framebuffer-patch-enable", 
                        Buffer (0x04) { 0x01, 0x00, 0x00, 0x00 },
                        "framebuffer-stolenmem", 
                        Buffer (0x04) { 0x00, 0x00, 0x00, 0x01 },
                        "framebuffer-fbmem", 
                        Buffer (0x04) { 0x00, 0x00, 0x00, 0x01 }
                    }, Local0)
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
            
            """
        } else if selectedGPU.contains("AMD Radeon") {
            code += """
            Device (GFX0)
            {
                Name (_ADR, 0x00010000)
                Name (_SUN, One)
                
                Method (_DSM, 4, NotSerialized)
                {
                    Store (Package (0x08)
                    {
                        "@0,AAPL,boot-display", 
                        Buffer (0x04) { 0x01, 0x00, 0x00, 0x00 },
                        "@0,built-in", 
                        Buffer (0x04) { 0x01, 0x00, 0x00, 0x00 },
                        "@0,device_type", 
                        Buffer () { "display" },
                        "model", 
                        Buffer () { "\(selectedGPU)" }
                    }, Local0)
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
            
            """
        }
        
        return code
    }
    
    private func generateMotherboardCode() -> String {
        var code = "\n    /*\n     * Motherboard-specific patches for \(selectedMotherboard)\n     */\n"
        
        // Add motherboard-specific device renames or patches
        if selectedMotherboard.contains("Z390") || selectedMotherboard.contains("Z490") {
            code += """
            // 300/400 series chipset patches
            Method (DTGP, 5, NotSerialized)
            {
                If (LEqual (Arg0, ToUUID ("a0b5b7c6-1318-441c-b0c9-fe695eaf949b")))
                {
                    If (LEqual (Arg1, One))
                    {
                        If (LEqual (Arg2, Zero))
                        {
                            Store (Buffer (One) { 0x03 }, Arg4)
                            Return (One)
                        }
                        If (LEqual (Arg2, One))
                        {
                            Return (One)
                        }
                    }
                }
                Store (Buffer (One) { 0x00 }, Arg4)
                Return (Zero)
            }
            
            """
        }
        
        return code
    }
    
    // MARK: - SSDT Actions
    private func loadSSDT(_ ssdt: GeneratedSSDT) {
        ssdtCode = ssdt.code
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ssdtCode, forType: .string)
        
        alertMessage = "SSDT code copied to clipboard"
        showAlert = true
    }
    
    private func compileSSDT() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let shellHelper = ShellHelper.shared
            
            // Create temporary file with SSDT code
            let tempDir = FileManager.default.temporaryDirectory
            let sourceFile = tempDir.appendingPathComponent("ssdt_source.dsl")
            let compiledFile = tempDir.appendingPathComponent("SSDT.aml")
            
            do {
                try self.ssdtCode.write(to: sourceFile, atomically: true, encoding: .utf8)
                
                // Compile with iasl
                let compileResult = shellHelper.runCommand("iasl \"\(sourceFile.path)\"")
                
                DispatchQueue.main.async {
                    if compileResult.success {
                        // Check if compiled file exists
                        if FileManager.default.fileExists(atPath: compiledFile.path) {
                            self.alertMessage = "SSDT compiled successfully!\n\nOutput saved to:\n\(compiledFile.path)"
                            
                            // Open the compiled file location
                            NSWorkspace.shared.selectFile(compiledFile.path, inFileViewerRootedAtPath: tempDir.path)
                        } else {
                            self.alertMessage = "Compilation succeeded but no output file found"
                        }
                    } else {
                        self.alertMessage = "Compilation failed:\n\(compileResult.error)"
                    }
                    self.showAlert = true
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to write SSDT source: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleSaveResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "SSDT saved to:\n\(url.path)"
            
            // Try to compile after saving if iasl is available
            if canCompileSSDT {
                DispatchQueue.global(qos: .background).async {
                    let shellHelper = ShellHelper.shared
                    let dslFile = url.deletingPathExtension().appendingPathExtension("dsl")
                    
                    do {
                        // Save DSL source
                        try self.ssdtCode.write(to: dslFile, atomically: true, encoding: .utf8)
                        
                        // Try to compile
                        let compileResult = shellHelper.runCommand("cd \"\(url.deletingLastPathComponent().path)\" && iasl \"\(dslFile.lastPathComponent)\"")
                        
                        if compileResult.success {
                            DispatchQueue.main.async {
                                self.alertMessage += "\n\nCompiled successfully to AML format"
                                self.showAlert = true
                            }
                        }
                    } catch {
                        // Ignore compilation errors for now
                    }
                }
            }
            
        case .failure(let error):
            alertMessage = "Failed to save SSDT: \(error.localizedDescription)"
        }
        
        showAlert = true
    }
}

// MARK: - Supporting Structures
struct SSDTDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.amlFile, .assemblySource, .text] }
    
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

// Extension for file types
extension UTType {
    static var amlFile: UTType {
        UTType(importedAs: "com.apple.aml-file")
    }
    
    static var assemblySource: UTType {
        UTType(importedAs: "public.assembly-source")
    }
}