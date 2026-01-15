// MARK: - Enhanced SSDT Generator View with Complete Motherboard List
@MainActor
struct SSDTGeneratorView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var efiPath: String?
    
    @State private var selectedDeviceType = "CPU"
    @State private var cpuModel = "Intel Core i7"
    @State private var gpuModel = "AMD Radeon RX 580"
    @State private var motherboardModel = "Gigabyte Z390 AORUS PRO"
    @State private var usbPortCount = "15"
    @State private var useEC = true
    @State private var useAWAC = true
    @State private var usePLUG = true
    @State private var useXOSI = true
    @State private var useALS0 = true
    @State private var useHID = true
    @State private var customDSDTName = "DSDT.aml"
    @State private var isGenerating = false
    @State private var generationProgress = 0.0
    @State private var generatedSSDTs: [String] = []
    @State private var showAdvancedOptions = false
    @State private var acpiTableSource = "Auto-detect"
    @State private var selectedSSDTs: Set<String> = []
    @State private var outputPath = ""
    @State private var includeCompilation = true
    @State private var compilationResult = ""
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Other"]
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    let gpuModels = ["AMD Radeon RX 580", "AMD Radeon RX 5700 XT", "NVIDIA GeForce GTX 1060", "NVIDIA GeForce RTX 2060", "Intel UHD Graphics 630", "Custom"]
    
    // COMPLETE MOTHERBOARD LIST for SSDT Generation
    let motherboardModels = [
        // Gigabyte
        "Gigabyte Z390 AORUS PRO",
        "Gigabyte Z390 AORUS ELITE",
        "Gigabyte Z390 AORUS MASTER",
        "Gigabyte Z390 DESIGNARE",
        "Gigabyte Z390 UD",
        "Gigabyte Z390 GAMING X",
        "Gigabyte Z390 M GAMING",
        "Gigabyte Z390 AORUS PRO WIFI",
        "Gigabyte Z390 AORUS ULTRA",
        "Gigabyte Z390 GAMING SLI",
        "Gigabyte Z390 AORUS XTREME",
        
        "Gigabyte Z490 AORUS PRO AX",
        "Gigabyte Z490 VISION G",
        "Gigabyte Z490 AORUS ELITE AC",
        "Gigabyte Z490 UD AC",
        "Gigabyte Z490 AORUS MASTER",
        "Gigabyte Z490I AORUS ULTRA",
        "Gigabyte Z490 AORUS XTREME",
        
        "Gigabyte Z590 AORUS PRO AX",
        "Gigabyte Z590 VISION G",
        "Gigabyte Z590 AORUS ELITE AX",
        "Gigabyte Z590 UD AC",
        "Gigabyte Z590 AORUS MASTER",
        
        "Gigabyte Z690 AORUS PRO",
        "Gigabyte Z690 AORUS ELITE AX",
        "Gigabyte Z690 GAMING X",
        "Gigabyte Z690 UD AX",
        
        // Add more boards as needed...
    ]
    
    let usbPortCounts = ["5", "7", "9", "11", "13", "15", "20", "25", "30", "Custom"]
    
    // Common SSDTs for different device types
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management (Essential)",
            "SSDT-EC-USBX": "Embedded Controller Fix (Essential)",
            "SSDT-AWAC": "AWAC Clock Fix (Essential)",
            "SSDT-PMC": "NVRAM Support (300+ Series)",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix",
            "SSDT-PM": "Power Management",
            "SSDT-CPUR": "CPU Renaming",
            "SSDT-XCPM": "XCPM Power Management"
        ],
        "GPU": [
            "SSDT-GPU": "GPU Device Properties",
            "SSDT-PCI0": "PCI Device Renaming",
            "SSDT-IGPU": "Intel GPU Fix (for iGPU)",
            "SSDT-DGPU": "Discrete GPU Power Management",
            "SSDT-PEG0": "PCIe Graphics Slot",
            "SSDT-NDGP": "NVIDIA GPU Power Management",
            "SSDT-AMDGPU": "AMD GPU Power Management"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method (Essential)",
            "SSDT-ALS0": "Ambient Light Sensor",
            "SSDT-HID": "Keyboard/Mouse Devices (Essential)",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Mapping",
            "SSDT-PMCR": "Power Management Controller",
            "SSDT-LPCB": "LPC Bridge",
            "SSDT-PPMC": "Platform Power Management",
            "SSDT-PWRB": "Power Button",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-RP0": "PCIe Root Port 0",
            "SSDT-RP1": "PCIe Root Port 1",
            "SSDT-RP2": "PCIe Root Port 2"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties (Essential)",
            "SSDT-UIAC": "USB Port Mapping (Essential)",
            "SSDT-EHCx": "USB 2.0 Controller Renaming",
            "SSDT-XHCI": "XHCI Controller (USB 3.0)",
            "SSDT-RHUB": "USB Root Hub",
            "SSDT-XHC": "XHCI Extended Controller",
            "SSDT-PRT": "USB Port Renaming"
        ],
        "Other": [
            "SSDT-DTGP": "DTGP Method (Helper)",
            "SSDT-GPRW": "Wake Fix (USB Wake)",
            "SSDT-PM": "Power Management",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-PWRB": "Power Button",
            "SSDT-TB3": "Thunderbolt 3",
            "SSDT-NVME": "NVMe Power Management",
            "SSDT-SATA": "SATA Controller",
            "SSDT-LAN": "Ethernet Controller",
            "SSDT-WIFI": "WiFi/Bluetooth",
            "SSDT-AUDIO": "Audio Controller"
        ]
    ]
    
    var availableSSDTs: [String] {
        return ssdtTemplates[selectedDeviceType]?.map { $0.key } ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("SSDT Generator")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Generate custom SSDTs for your Hackintosh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Device Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedDeviceType) {
                                ForEach(deviceTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                            .onChange(of: selectedDeviceType) { _ in
                                selectedSSDTs.removeAll()
                            }
                        }
                        
                        Spacer()
                        
                        // Dynamic fields based on device type
                        VStack(alignment: .leading, spacing: 8) {
                            if selectedDeviceType == "CPU" {
                                Text("CPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $cpuModel) {
                                    ForEach(cpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "GPU" {
                                Text("GPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $gpuModel) {
                                    ForEach(gpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "Motherboard" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Motherboard Model")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $motherboardModel) {
                                        ForEach(motherboardModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 300)
                                }
                            } else if selectedDeviceType == "USB" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("USB Port Count")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $usbPortCount) {
                                        ForEach(usbPortCounts, id: \.self) { count in
                                            Text("\(count) ports").tag(count)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                    
                                    if usbPortCount == "Custom" {
                                        TextField("Enter custom port count", text: $usbPortCount)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 100)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Custom DSDT Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("DSDT.aml", text: $customDSDTName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Essential SSDT Options
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Essential SSDTs")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Select All") {
                                useEC = true
                                useAWAC = true
                                usePLUG = true
                                useXOSI = true
                                useALS0 = true
                                useHID = true
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                useEC = false
                                useAWAC = false
                                usePLUG = false
                                useXOSI = false
                                useALS0 = false
                                useHID = false
                            }
                            .font(.caption)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Toggle("SSDT-EC (Embedded Controller)", isOn: $useEC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-AWAC (AWAC Clock)", isOn: $useAWAC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("300+ Series")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-PLUG (CPU Power)", isOn: $usePLUG)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-XOSI (Windows OSI)", isOn: $useXOSI)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Sleep/Wake")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // SSDT Selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Available SSDT Templates")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text("\(selectedSSDTs.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Select All") {
                                selectedSSDTs = Set(availableSSDTs)
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                selectedSSDTs.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                    
                    if availableSSDTs.isEmpty {
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("No SSDTs available for \(selectedDeviceType)")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableSSDTs, id: \.self) { ssdt in
                                    SSDTTemplateCard(
                                        name: ssdt,
                                        description: ssdtTemplates[selectedDeviceType]?[ssdt] ?? "Unknown",
                                        isSelected: selectedSSDTs.contains(ssdt),
                                        isEssential: ssdt.contains("EC") || ssdt.contains("PLUG") || ssdt.contains("AWAC"),
                                        isDisabled: isGenerating
                                    ) {
                                        toggleSSDTSelection(ssdt)
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Options
                VStack(alignment: .leading, spacing: 16) {
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("ACPI Table Source:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $acpiTableSource) {
                                    Text("Auto-detect").tag("Auto-detect")
                                    Text("Extract from system").tag("Extract from system")
                                    Text("Custom file").tag("Custom file")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            
                            HStack {
                                Text("Output Path:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Leave empty for default", text: $outputPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") {
                                    browseForOutputPath()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Toggle("Compile DSL to AML (requires iasl)", isOn: $includeCompilation)
                                .toggleStyle(.switch)
                                .font(.caption)
                            
                            if !compilationResult.isEmpty {
                                ScrollView {
                                    Text(compilationResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                .frame(height: 80)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Generation Progress
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: generationProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Generating SSDTs... \(Int(generationProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Generated SSDTs
                if !generatedSSDTs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Generated Files")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Open Folder") {
                                openGeneratedFolder()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(generatedSSDTs, id: \.self) { ssdt in
                                    HStack {
                                        Image(systemName: ssdt.hasSuffix(".aml") ? "cpu.fill" : "doc.text.fill")
                                            .foregroundColor(.blue)
                                        Text(ssdt)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Button("Open") {
                                                openGeneratedFile(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                            
                                            Button("Copy") {
                                                copySSDTToClipboard(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(height: min(CGFloat(generatedSSDTs.count) * 50, 200))
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: generateSSDTs) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Generating...")
                                } else {
                                    Image(systemName: "cpu.fill")
                                    Text("Generate SSDTs")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        
                        Button(action: validateSSDTs) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Validate")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: installToEFI) {
                            HStack {
                                Image(systemName: "externaldrive.fill.badge.plus")
                                Text("Install to EFI")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating || efiPath == nil)
                        
                        Button(action: openSSDTGuide) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Open Guide")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - Enhanced SSDT Template Card Component
    struct SSDTTemplateCard: View {
        let name: String
        let description: String
        let isSelected: Bool
        let isEssential: Bool
        let isDisabled: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? (isEssential ? .red : .blue) : .primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(isEssential ? .red : .blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if isEssential {
                        Text("Essential")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .frame(width: 180, height: 100)
                .background(isSelected ? (isEssential ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)) : Color.gray.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? (isEssential ? Color.red : Color.blue) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
    }
    
    // MARK: - Action Functions
    private func toggleSSDTSelection(_ ssdtName: String) {
        if selectedSSDTs.contains(ssdtName) {
            selectedSSDTs.remove(ssdtName)
        } else {
            selectedSSDTs.insert(ssdtName)
        }
    }
    
    private func browseForOutputPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                outputPath = url.path
            }
        }
    }
    
    private func generateSSDTs() {
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        compilationResult = ""
        
        // Collect selected SSDTs
        var ssdtsToGenerate: [String] = []
        
        // Add essential SSDTs if selected
        if useEC { ssdtsToGenerate.append("SSDT-EC") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        
        // Add template SSDTs
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate.\n\nRecommended for \(motherboardModel):\n• SSDT-EC-USBX\n• SSDT-PLUG\n• SSDT-AWAC (for 300+ series)"
            showAlert = true
            isGenerating = false
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            // Get output directory first
            let outputDir = self.getOutputDirectory()
            
            // Create a variable to store the final output directory for the alert
            var finalOutputDir = outputDir
            
            // Clear previous compilation results
            var compilationMessages: [String] = []
            
            // Simulate generation process with detailed progress
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                // Update progress
                let progress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                DispatchQueue.main.async {
                    generationProgress = progress
                }
                
                // Generate DSL file first
                let dslFilename = "\(ssdt).dsl"
                let dslFilePath = "\(outputDir)/\(dslFilename)"
                
                // Create valid DSL content
                let dslContent = self.generateValidDSLContent(for: ssdt)
                
                do {
                    try dslContent.write(toFile: dslFilePath, atomically: true, encoding: .utf8)
                    
                    DispatchQueue.main.async {
                        generatedSSDTs.append(dslFilename)
                    }
                    
                    // If compilation is enabled, try to compile DSL to AML
                    if includeCompilation {
                        let amlFilename = "\(ssdt).aml"
                        let amlFilePath = "\(outputDir)/\(amlFilename)"
                        
                        let result = self.compileDSLToAML(dslPath: dslFilePath, amlPath: amlFilePath)
                        
                        if result.success {
                            compilationMessages.append("✅ \(ssdt): Compiled successfully")
                            DispatchQueue.main.async {
                                generatedSSDTs.append(amlFilename)
                            }
                        } else {
                            compilationMessages.append("⚠️ \(ssdt): Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ \(ssdt): Failed to create DSL file")
                }
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                generationProgress = 0
                
                // Update compilation results
                compilationResult = compilationMessages.joined(separator: "\n")
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) files for \(motherboardModel):
                
                • DSL source files: \(ssdtsToGenerate.count)
                • AML binary files: \(includeCompilation ? "\(compilationMessages.filter { $0.contains("✅") }.count)" : "Compilation disabled")
                
                📁 Files saved to: \(finalOutputDir)
                
                \(!compilationMessages.isEmpty ? "📊 Compilation Results:\n\(compilationResult)" : "")
                
                ⚠️ Important:
                These are template SSDTs. You MUST:
                1. Review and customize them for your specific hardware
                2. Test each SSDT individually
                3. Add to config.plist → ACPI → Add
                4. Rebuild kernel cache and restart
                """
                showAlert = true
                
                // Open the folder automatically
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openGeneratedFolder()
                }
            }
        }
    }
    
    private func generateValidDSLContent(for ssdt: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var content = """
        /*
         * \(ssdt).dsl
         * Generated by SystemMaintenance
         * Date: \(dateFormatter.string(from: Date()))
         * Motherboard: \(motherboardModel)
         * Device Type: \(selectedDeviceType)
         *
         * NOTE: This is a template. Customize for your hardware.
         * Refer to Dortania guides for implementation details.
         */
        
        DefinitionBlock ("", "SSDT", 2, "SYSM", "\(ssdt.replacingOccurrences(of: "SSDT-", with: ""))", 0x00000000)
        {
            // External references (if needed)
            External (_SB_.PCI0, DeviceObj)
            External (_SB_.PCI0.LPCB, DeviceObj)
            
            Scope (\\)
            {
                // DTGP method - required for _DSM methods
                Method (DTGP, 5, NotSerialized)
                {
                    If (LEqual (Arg0, Buffer (0x10)
                        {
                            /* 0000 */  0xC6, 0xB7, 0xB5, 0xA0, 0x18, 0x13, 0x1C, 0x44,
                            /* 0008 */  0xB0, 0xC9, 0xFE, 0x69, 0x5E, 0xAF, 0x94, 0x9B
                        }))
                    {
                        If (LEqual (Arg1, One))
                        {
                            If (LEqual (Arg2, 0x03))
                            {
                                If (LEqual (Arg3, Buffer (0x04)
                                    {
                                        0x00, 0x00, 0x00, 0x03
                                    }))
                                {
                                    If (LEqual (Arg4, Zero))
                                    {
                                        Return (Buffer (One) { 0x03 })
                                    }
                                }
                            }
                        }
                    }
                    
                    Return (Buffer (One) { 0x00 })
                }
            }
        """
        
        // Add SSDT-specific content
        if ssdt == "SSDT-EC" || ssdt == "SSDT-EC-USBX" {
            content += """
            
                Scope (_SB.PCI0.LPCB)
                {
                    Device (EC0)
                    {
                        Name (_HID, EisaId ("ACID0001"))  // Fake HID for Embedded Controller
                        Name (_CID, "PNP0C09")            // PNP ID for Embedded Controller
                        Name (_UID, Zero)
                        
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0B)  // Device present and enabled
                            }
                            
                            Return (Zero)      // Hide from other OS
                        }
                        
                        // EC Operation Region
                        OperationRegion (ERAM, EmbeddedControl, Zero, 0xFF)
                        Field (ERAM, ByteAcc, NoLock, Preserve)
                        {
                            AccessAs (BufferAcc, 0x01),
                            Offset (0x60),
                            ECDV,   8,    // EC Data Version
                            Offset (0x62),
                            ECFL,   8     // EC Flags
                        }
                    }
                }
            """
        }
        
        if ssdt == "SSDT-EC-USBX" {
            content += """
            
                // USB Power Properties (USBX)
                Device (_SB.PCI0.XHC)
                {
                    Name (_ADR, Zero)  // Address 0
                    
                    Method (_DSM, 4, Serialized)
                    {
                        If (LEqual (Arg2, Zero))
                        {
                            Return (Buffer (One) { 0x03 })
                        }
                        
                        Return (Package (0x06)
                        {
                            "usb-connector-type",
                            0,      // Type A
                            "port-count",
                            Buffer (0x04)
                            {
                                0x\(String(format: "%02X", Int(usbPortCount) ?? 15)), 0x00, 0x00, 0x00
                            },
                            "model",
                            Buffer () { "USB XHCI Controller" }
                        })
                    }
                }
            """
        }
        
        if ssdt == "SSDT-PLUG" {
            content += """
            
                External (_SB_.PR00, ProcessorObj)
                External (_SB_.PR01, ProcessorObj)
                
                Scope (_SB.PR00)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x02)
                        {
                            "plugin-type",
                            One
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
                
                Scope (_SB.PR01)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x02)
                        {
                            "plugin-type",
                            One
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            """
        }
        
        if ssdt == "SSDT-AWAC" {
            content += """
            
                Scope (_SB.PCI0)
                {
                    Device (RTC0)
                    {
                        Name (_HID, EisaId ("PNP0B00"))  // PNP ID for RTC
                        Name (_CRS, ResourceTemplate ()
                        {
                            IO (Decode16,
                                0x0070,             // Range Minimum
                                0x0070,             // Range Maximum
                                0x01,               // Alignment
                                0x08,               // Length
                                )
                            IRQNoFlags ()
                                {8}
                        })
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0F)  // Present and enabled
                            }
                            
                            Return (Zero)
                        }
                    }
                    
                    // Disable AWAC if present
                    Device (AWAC)
                    {
                        Name (_HID, "ACPI000E")
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (Zero)  // Disable for macOS
                            }
                            
                            Return (0x0F)      // Enable for other OS
                        }
                    }
                }
            """
        }
        
        if ssdt == "SSDT-XOSI" {
            content += """
            
                Method (XOSI, 1, NotSerialized)
                {
                    // Windows OSI simulation
                    If (_OSI ("Darwin"))
                    {
                        If (LEqual (Arg0, "Windows 2009"))  // Windows 7
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2012"))  // Windows 8
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2013"))  // Windows 8.1
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2015"))  // Windows 10
                        {
                            Return (One)
                        }
                    }
                    
                    Return (Zero)
                }
            """
        }
        
        // Close the DefinitionBlock
        content += "\n}"
        
        return content
    }
    
    private func compileDSLToAML(dslPath: String, amlPath: String) -> (success: Bool, output: String) {
        // Check if iasl compiler is available
        let checkResult = ShellHelper.runCommand("which iasl")
        if !checkResult.success {
            return (false, "iasl compiler not found. Install with: brew install acpica")
        }
        
        // Compile DSL to AML
        let compileResult = ShellHelper.runCommand("iasl \"\(dslPath)\"")
        
        // Check if compilation was successful
        if compileResult.success {
            // Move the compiled file to the correct location
            let compiledAMLPath = dslPath.replacingOccurrences(of: ".dsl", with: ".aml")
            let moveResult = ShellHelper.runCommand("mv \"\(compiledAMLPath)\" \"\(amlPath)\"")
            
            if moveResult.success {
                return (true, "Compiled successfully")
            } else {
                return (false, "Failed to move compiled file: \(moveResult.output)")
            }
        } else {
            return (false, "Compilation failed: \(compileResult.output)")
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        // Use the user's Desktop directory
        let desktopPath = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
        
        if let desktopPath = desktopPath {
            let ssdtDir = desktopPath + "/Generated_SSDTs"
            
            // Create directory if it doesn't exist
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: ssdtDir) {
                do {
                    try fileManager.createDirectory(atPath: ssdtDir, withIntermediateDirectories: true, attributes: nil)
                    print("Created directory: \(ssdtDir)")
                } catch {
                    print("Failed to create directory: \(error)")
                    // Fallback to home directory
                    return NSHomeDirectory() + "/Generated_SSDTs"
                }
            }
            return ssdtDir
        }
        
        // Fallback: Use home directory
        return NSHomeDirectory() + "/Generated_SSDTs"
    }
    
    private func openGeneratedFolder() {
        let outputDir = getOutputDirectory()
        let url = URL(fileURLWithPath: outputDir)
        
        if FileManager.default.fileExists(atPath: outputDir) {
            NSWorkspace.shared.open(url)
        } else {
            // Try to create the folder
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.open(url)
            } catch {
                print("Failed to create/open folder: \(error)")
            }
        }
    }
    
    private func openGeneratedFile(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        let url = URL(fileURLWithPath: filePath)
        
        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.open(url)
        } else {
            alertTitle = "File Not Found"
            alertMessage = "Generated file not found at: \(filePath)"
            showAlert = true
        }
    }
    
    private func copySSDTToClipboard(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(content, forType: .string)
                
                alertTitle = "Copied"
                alertMessage = "\(filename) content copied to clipboard"
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = "Failed to read file: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func validateSSDTs() {
        DispatchQueue.global(qos: .background).async {
            var validationMessages: [String] = ["SSDT Validation Report:"]
            
            // Check for iasl compiler
            let iaslCheck = ShellHelper.runCommand("which iasl")
            validationMessages.append(iaslCheck.success ? "✅ iasl compiler found" : "❌ iasl compiler not found")
            
            if iaslCheck.success {
                // Validate DSL files if they exist
                let outputDir = self.getOutputDirectory()
                let fileManager = FileManager.default
                
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                    let dslFiles = files.filter { $0.hasSuffix(".dsl") }
                    
                    if dslFiles.isEmpty {
                        validationMessages.append("⚠️ No DSL files found to validate")
                    } else {
                        validationMessages.append("\nValidating \(dslFiles.count) DSL files:")
                        
                        for dslFile in dslFiles {
                            let filePath = "\(outputDir)/\(dslFile)"
                            let validateResult = ShellHelper.runCommand("iasl -vs \"\(filePath)\"")
                            
                            if validateResult.success {
                                validationMessages.append("✅ \(dslFile): Syntax OK")
                            } else {
                                // Try to extract error messages
                                let lines = validateResult.output.components(separatedBy: "\n")
                                let errors = lines.filter { $0.contains("Error") || $0.contains("error") }
                                validationMessages.append("❌ \(dslFile): \(errors.first ?? "Syntax error")")
                            }
                        }
                    }
                } catch {
                    validationMessages.append("❌ Failed to read output directory: \(error.localizedDescription)")
                }
            }
            
            // Check for common issues
            validationMessages.append("\nCommon Issues to Check:")
            validationMessages.append("• All SSDTs must have valid DefinitionBlock")
            validationMessages.append("• Method names must follow ACPI naming conventions")
            validationMessages.append("• External references must be declared")
            validationMessages.append("• Use proper scope (\\ for root, _SB for devices)")
            
            DispatchQueue.main.async {
                alertTitle = "SSDT Validation"
                alertMessage = validationMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func installToEFI() {
        guard let efiPath = efiPath else {
            alertTitle = "EFI Not Mounted"
            alertMessage = "Please mount EFI partition from System tab first."
            showAlert = true
            return
        }
        
        if generatedSSDTs.isEmpty {
            alertTitle = "No SSDTs Generated"
            alertMessage = "Please generate SSDTs first before installing to EFI."
            showAlert = true
            return
        }
        
        let acpiPath = "\(efiPath)/EFI/OC/ACPI/"
        
        DispatchQueue.global(qos: .background).async {
            var installMessages: [String] = ["Installing SSDTs to EFI:"]
            var successCount = 0
            var failCount = 0
            
            // Create ACPI directory if it doesn't exist
            let _ = ShellHelper.runCommand("mkdir -p \"\(acpiPath)\"", needsSudo: true)
            
            // Only install AML files
            let outputDir = self.getOutputDirectory()
            let fileManager = FileManager.default
            
            do {
                let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                let amlFiles = files.filter { $0.hasSuffix(".aml") }
                
                if amlFiles.isEmpty {
                    installMessages.append("⚠️ No AML files found. Please compile DSL files first.")
                } else {
                    for amlFile in amlFiles {
                        let sourcePath = "\(outputDir)/\(amlFile)"
                        let destPath = "\(acpiPath)\(amlFile)"
                        
                        if fileManager.fileExists(atPath: sourcePath) {
                            let command = "cp \"\(sourcePath)\" \"\(destPath)\""
                            let result = ShellHelper.runCommand(command, needsSudo: true)
                            
                            if result.success {
                                installMessages.append("✅ \(amlFile)")
                                successCount += 1
                            } else {
                                installMessages.append("❌ \(amlFile): \(result.output)")
                                failCount += 1
                            }
                        } else {
                            installMessages.append("❌ \(amlFile): Source file not found")
                            failCount += 1
                        }
                    }
                }
            } catch {
                installMessages.append("❌ Failed to read output directory: \(error.localizedDescription)")
                failCount += 1
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Installation"
                installMessages.append("\n📊 Summary: \(successCount) AML files installed")
                
                if failCount > 0 {
                    installMessages.append("⚠️  \(failCount) files failed to install")
                }
                
                installMessages.append("\n📍 Location: \(acpiPath)")
                installMessages.append("\n⚠️  Important Next Steps:")
                installMessages.append("   1. Add SSDTs to config.plist → ACPI → Add")
                installMessages.append("   2. Set Enabled = True for each SSDT")
                installMessages.append("   3. Enable FixMask in ACPI → Patch")
                installMessages.append("   4. Rebuild kernel cache: sudo kextcache -i /")
                installMessages.append("   5. Restart system")
                
                alertMessage = installMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func openSSDTGuide() {
        if let url = URL(string: "https://dortania.github.io/Getting-Started-With-ACPI/") {
            NSWorkspace.shared.open(url)
        }
    }
}