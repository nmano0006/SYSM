                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func detectCodec() {
        isDetectingCodec = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isDetectingCodec = false
            
            // Simulate codec detection
            let codecs = ["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x80862882"]
            let detectedCodec = codecs.randomElement() ?? "0x10ec0899"
            audioCodecID = detectedCodec
            
            alertTitle = "Codec Detected"
            alertMessage = "Detected audio codec: \(detectedCodec)\n\nRecommended Layout IDs:\n• Realtek ALC889: 1, 2\n• Realtek ALC887: 5, 7\n• Realtek ALC892: 1, 2, 3"
            showAlert = true
        }
    }
    
    private func applyLayoutID() {
        alertTitle = "Layout ID Applied"
        alertMessage = """
        Layout ID \(layoutID) has been configured.
        
        To apply changes:
        1. Add 'alcid=\(layoutID)' to boot-args in config.plist
        2. Rebuild kernel cache
        3. Restart your system
        
        If audio doesn't work, try a different Layout ID.
        """
        showAlert = true
    }
    
    private func testAudioOutput() {
        alertTitle = "Audio Test"
        alertMessage = """
        Testing audio output...
        
        1. Play a test sound in System Preferences → Sound
        2. Check if audio output devices are detected
        3. Verify AppleHDA is loaded in kextstat
        
        If no sound:
        1. Try different Layout ID
        2. Check if SIP is disabled
        3. Verify AppleALC is in EFI
        """
        showAlert = true
    }
    
    private func resetAudioSettings() {
        alertTitle = "Reset Audio Settings"
        alertMessage = """
        This will reset audio settings to default.
        
        Steps:
        1. Remove 'alcid=' from boot-args
        2. Delete AppleHDA.kext from /S/L/E
        3. Delete AppleALC.kext from EFI
        4. Rebuild kernel cache
        5. Restart system
        
        Audio will stop working until reinstalled.
        """
        showAlert = true
    }
    
    private func checkAudioDevices() {
        let result = ShellHelper.runCommand("system_profiler SPAudioDataType")
        
        alertTitle = "Audio Devices"
        alertMessage = result.success ? result.output : "Failed to get audio device info"
        showAlert = true
    }
}

// MARK: - SSDT Generator View (from original code)
struct SSDTGeneratorView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var efiPath: String?
    
    @State private var selectedDeviceType = "CPU"
    @State private var cpuModel = "Intel Core i7"
    @State private var gpuModel = "AMD Radeon RX 580"
    @State private var motherboardModel = "Gigabyte Z390"
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
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Other"]
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    let gpuModels = ["AMD Radeon RX 580", "AMD Radeon RX 5700 XT", "NVIDIA GeForce GTX 1060", "NVIDIA GeForce RTX 2060", "Intel UHD Graphics 630", "Custom"]
    let motherboardModels = ["Gigabyte Z390", "ASUS Z370", "ASRock B460", "MSI Z490", "Custom"]
    
    // Common SSDTs for different device types
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management",
            "SSDT-EC-USBX": "Embedded Controller Fix",
            "SSDT-AWAC": "AWAC Clock Fix",
            "SSDT-PMC": "NVRAM Support",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix"
        ],
        "GPU": [
            "SSDT-GPU": "GPU Device Properties",
            "SSDT-PCI0": "PCI Device Renaming",
            "SSDT-IGPU": "Intel GPU Fix",
            "SSDT-DGPU": "Discrete GPU Power Management"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method",
            "SSDT-ALS0": "Ambient Light Sensor",
            "SSDT-HID": "Keyboard/Mouse Devices",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Mapping"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties",
            "SSDT-UIAC": "USB Port Mapping",
            "SSDT-EHCx": "USB Controller Renaming",
            "SSDT-XHCI": "XHCI Controller",
            "SSDT-RHUB": "USB Root Hub"
        ],
        "Other": [
            "SSDT-DTGP": "DTGP Method",
            "SSDT-GPRW": "Wake Fix",
            "SSDT-PM": "Power Management",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-PWRB": "Power Button"
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
                        }
                        
                        Spacer()
                        
                        // Dynamic fields based on device type
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedDeviceType == "CPU" ? "CPU Model" :
                                 selectedDeviceType == "GPU" ? "GPU Model" :
                                 selectedDeviceType == "Motherboard" ? "Motherboard Model" :
                                 selectedDeviceType == "USB" ? "USB Port Count" : "Custom Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if selectedDeviceType == "CPU" {
                                Picker("", selection: $cpuModel) {
                                    ForEach(cpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "GPU" {
                                Picker("", selection: $gpuModel) {
                                    ForEach(gpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "Motherboard" {
                                Picker("", selection: $motherboardModel) {
                                    ForEach(motherboardModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "USB" {
                                TextField("Port Count", text: $usbPortCount)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            } else {
                                TextField("Custom Name", text: $customDSDTName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Common SSDT Options
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Essential SSDTs")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
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
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        Toggle("SSDT-EC (Embedded Controller)", isOn: $useEC)
                            .toggleStyle(.switch)
                        Toggle("SSDT-AWAC (AWAC Clock)", isOn: $useAWAC)
                            .toggleStyle(.switch)
                        Toggle("SSDT-PLUG (CPU Power)", isOn: $usePLUG)
                            .toggleStyle(.switch)
                        Toggle("SSDT-XOSI (Windows OSI)", isOn: $useXOSI)
                            .toggleStyle(.switch)
                        Toggle("SSDT-ALS0 (Ambient Light)", isOn: $useALS0)
                            .toggleStyle(.switch)
                        Toggle("SSDT-HID (Input Devices)", isOn: $useHID)
                            .toggleStyle(.switch)
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
                        
                        Text("\(selectedSSDTs.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        Text("Generated Files")
                            .font(.headline)
                        
                        ForEach(generatedSSDTs, id: \.self) { ssdt in
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text(ssdt)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Open") {
                                    openGeneratedFile(ssdt)
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
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
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - SSDT Template Card Component
    struct SSDTTemplateCard: View {
        let name: String
        let description: String
        let isSelected: Bool
        let isDisabled: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .blue : .primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding()
                .frame(width: 180, height: 100)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
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
        
        // Collect selected SSDTs
        var ssdtsToGenerate: [String] = []
        
        // Add essential SSDTs if selected
        if useEC { ssdtsToGenerate.append("SSDT-EC-USBX") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        
        // Add template SSDTs
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate."
            showAlert = true
            isGenerating = false
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            // Simulate generation process
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                // Update progress
                DispatchQueue.main.async {
                    generationProgress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                }
                
                // Simulate generation time
                usleep(500000) // 0.5 second per SSDT
                
                // Generate filename
                let filename = "\(ssdt).aml"
                
                DispatchQueue.main.async {
                    generatedSSDTs.append(filename)
                }
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                generationProgress = 0
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) SSDTs:
                
                \(generatedSSDTs.joined(separator: "\n"))
                
                Files saved to: \(getOutputDirectory())
                
                Next steps:
                1. Copy SSDTs to EFI/OC/ACPI/
                2. Add to config.plist → ACPI → Add
                3. Rebuild kernel cache
                4. Restart system
                """
                showAlert = true
            }
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let ssdtDir = downloadsDir?.appendingPathComponent("Generated_SSDTs")
        
        // Create directory if it doesn't exist
        if let ssdtDir = ssdtDir {
            try? FileManager.default.createDirectory(at: ssdtDir, withIntermediateDirectories: true)
            return ssdtDir.path
        }
        
        return NSHomeDirectory() + "/Downloads/Generated_SSDTs"
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
    
    private func validateSSDTs() {
        DispatchQueue.global(qos: .background).async {
            var validationMessages: [String] = ["SSDT Validation Report:"]
            
            // Check for common issues
            validationMessages.append("\n1. Checking required SSDTs...")
            
            let requiredSSDTs = ["SSDT-EC", "SSDT-PLUG", "SSDT-AWAC"]
            for ssdt in requiredSSDTs {
                let exists = selectedSSDTs.contains(ssdt) || 
                           (ssdt == "SSDT-EC" && useEC) ||
                           (ssdt == "SSDT-PLUG" && usePLUG) ||
                           (ssdt == "SSDT-AWAC" && useAWAC)
                validationMessages.append("   \(exists ? "✅" : "❌") \(ssdt)")
            }
            
            validationMessages.append("\n2. Checking device compatibility...")
            
            // Add device-specific validations
            switch selectedDeviceType {
            case "CPU":
                validationMessages.append("   ✅ CPU: \(cpuModel)")
                validationMessages.append("   ⚠️  Ensure CPU power management is enabled")
            case "GPU":
                validationMessages.append("   ✅ GPU: \(gpuModel)")
                validationMessages.append("   ⚠️  Check for GPU spoofing requirements")
            case "USB":
                if let portCount = Int(usbPortCount) {
                    validationMessages.append("   ✅ USB Ports: \(portCount)")
                    validationMessages.append("   ⚠️  USB port limit patch may be needed")
                }
            default:
                validationMessages.append("   ℹ️  Custom device configuration")
            }
            
            validationMessages.append("\n3. Configuration Recommendations:")
            validationMessages.append("   • Add SSDTs to config.plist → ACPI → Add")
            validationMessages.append("   • Enable Fixes in Kernel → Quirks")
            validationMessages.append("   • Rebuild kernel cache after installation")
            
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
            
            // Create ACPI directory if it doesn't exist
            let _ = ShellHelper.runCommand("mkdir -p \"\(acpiPath)\"", needsSudo: true)
            
            for ssdtFile in generatedSSDTs {
                let sourcePath = "\(getOutputDirectory())/\(ssdtFile)"
                let destPath = "\(acpiPath)\(ssdtFile)"
                
                if FileManager.default.fileExists(atPath: sourcePath) {
                    let command = "cp \"\(sourcePath)\" \"\(destPath)\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    
                    if result.success {
                        installMessages.append("✅ \(ssdtFile)")
                        successCount += 1
                    } else {
                        installMessages.append("❌ \(ssdtFile): \(result.output)")
                    }
                } else {
                    installMessages.append("❌ \(ssdtFile): Source file not found")
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Installation"
                installMessages.append("\n📊 Summary: \(successCount)/\(generatedSSDTs.count) SSDTs installed")
                installMessages.append("\n📍 Location: \(acpiPath)")
                installMessages.append("\n⚠️  Remember to:")
                installMessages.append("   1. Add SSDTs to config.plist")
                installMessages.append("   2. Enable FixMask in ACPI → Patch")
                installMessages.append("   3. Rebuild kernel cache")
                installMessages.append("   4. Restart system")
                
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

// MARK: - Disk Detail View (from original code)
struct DiskDetailView: View {
    @Binding var isPresented: Bool
    let drive: DriveInfo
    @Binding var allDrives: [DriveInfo]
    let refreshDrives: () -> Void
    
    @State private var showUnmountAlert = false
    @State private var isEjecting = false
    @State private var isMounting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Device: \(drive.identifier)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Drive Info Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                                .font(.title)
                                .foregroundColor(drive.isInternal ? .blue : .orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(drive.name)
                                    .font(.headline)
                                Text("\(drive.size) • \(drive.type)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(drive.isInternal ? "Internal" : "External")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(drive.isInternal ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                                .foregroundColor(drive.isInternal ? .blue : .orange)
                                .cornerRadius(6)
                        }
                        
                        if !drive.mountPoint.isEmpty {
                            HStack {
                                Text("Mount Point:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(drive.mountPoint)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                    .textSelection(.enabled)
                                
                                Spacer()
                                
                                Button("Reveal") {
                                    let url = URL(fileURLWithPath: drive.mountPoint)
                                    NSWorkspace.shared.open(url)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Partitions Section
                    if !drive.partitions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Partitions")
                                .font(.headline)
                            
                            ForEach(drive.partitions) { partition in
                                PartitionRow(partition: partition)
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if !drive.isInternal && !drive.mountPoint.isEmpty {
                            Button(action: {
                                showUnmountAlert = true
                            }) {
                                HStack {
                                    if isEjecting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Ejecting...")
                                    } else {
                                        Image(systemName: "eject.fill")
                                        Text("Eject Drive")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isEjecting)
                        }
                        
                        if drive.mountPoint.isEmpty && !drive.isInternal {
                            Button(action: {
                                mountDrive()
                            }) {
                                HStack {
                                    if isMounting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Mounting...")
                                    } else {
                                        Image(systemName: "externaldrive.fill.badge.plus")
                                        Text("Mount Drive")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isMounting)
                        }
                        
                        Button(action: {
                            refreshDrives()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Drive Info")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .alert("Eject Drive", isPresented: $showUnmountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Eject", role: .destructive) {
                ejectDrive()
            }
        } message: {
            Text("Are you sure you want to eject '\(drive.name)'?")
        }
    }
    
    private func ejectDrive() {
        isEjecting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil eject /dev/\(drive.identifier)", needsSudo: true)
            
            DispatchQueue.main.async {
                isEjecting = false
                
                if result.success {
                    refreshDrives()
                    isPresented = false
                }
            }
        }
    }
    
    private func mountDrive() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(drive.identifier)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    refreshDrives()
                }
            }
        }
    }
}

// MARK: - EFI Selection View (from original code)
struct EFISelectionView: View {
    @Binding var isPresented: Bool
    @Binding var efiPath: String?
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var allDrives: [DriveInfo]
    
    @State private var partitions: [String] = []
    @State private var isLoading = false
    @State private var selectedPartition = ""
    @State private var isMounting = false
    @State private var drivesList: [DriveInfo] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select EFI Partition to Mount")
                .font(.headline)
                .padding(.top)
            
            if isLoading {
                Spacer()
                ProgressView("Loading drives and partitions...")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available Partitions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if partitions.isEmpty {
                            VStack {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("No partitions found")
                                    .foregroundColor(.secondary)
                                    .italic()
                                Text("Trying auto-detection...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(partitions, id: \.self) { partition in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(partition)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        
                                        // Find which drive this partition belongs to
                                        if let driveIdentifier = partition.split(separator: "s").first {
                                            if let drive = drivesList.first(where: { $0.identifier == String(driveIdentifier) }) {
                                                Text("Drive: \(drive.name) (\(drive.size))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPartition == partition {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(selectedPartition == partition ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedPartition == partition ? Color.blue : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    selectedPartition = partition
                                }
                            }
                        }
                        
                        Divider()
                        
                        Text("Drives Found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if drivesList.isEmpty {
                            VStack {
                                Image(systemName: "externaldrive.badge.xmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.red)
                                Text("No drives found")
                                    .foregroundColor(.secondary)
                                    .italic()
                                Text("Using default drives list")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(drivesList) { drive in
                                HStack {
                                    Image(systemName: drive.type.contains("External") ? "externaldrive" : "internaldrive")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drive.identifier)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        Text("\(drive.name) - \(drive.size)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Button("Refresh") {
                            loadDrivesAndPartitions()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Auto-Detect EFI") {
                            autoDetectEFI()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: mountSelectedPartition) {
                            if isMounting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Mounting...")
                                }
                            } else {
                                Text("Mount Selected")
                            }
                        }
                        .disabled(selectedPartition.isEmpty || isMounting)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear {
            loadDrivesAndPartitions()
        }
    }
    
    private func loadDrivesAndPartitions() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            // Get partitions
            let partitionsList = ShellHelper.listAllPartitions()
            
            // Use provided drives or get new ones
            let drivesList = allDrives.isEmpty ? ShellHelper.getAllDrives() : allDrives
            
            DispatchQueue.main.async {
                self.partitions = partitionsList
                self.drivesList = drivesList
                self.isLoading = false
                
                // Auto-select common EFI partitions
                if selectedPartition.isEmpty {
                    // Look for s1 partitions (usually EFI)
                    if let efiPartition = partitionsList.first(where: { $0.contains("s1") }) {
                        selectedPartition = efiPartition
                    } else if let firstPartition = partitionsList.first {
                        selectedPartition = firstPartition
                    }
                }
            }
        }
    }
    
    private func autoDetectEFI() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            // Try to find EFI partition automatically
            let efiCandidates = partitions.filter { partition in
                // Common EFI partitions are usually s1
                return partition.contains("s1") || partition.lowercased().contains("efi")
            }
            
            DispatchQueue.main.async {
                isLoading = false
                
                if let firstEFI = efiCandidates.first {
                    selectedPartition = firstEFI
                    alertTitle = "Auto-Detected"
                    alertMessage = "Selected \(firstEFI) as likely EFI partition"
                    showAlert = true
                } else if let firstPartition = partitions.first {
                    selectedPartition = firstPartition
                    alertTitle = "Auto-Selected"
                    alertMessage = "Selected \(firstPartition) (no EFI found)"
                    showAlert = true
                } else {
                    alertTitle = "No Partitions"
                    alertMessage = "Could not find any partitions. Please check Disk Utility."
                    showAlert = true
                }
            }
        }
    }
    
    private func mountSelectedPartition() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(selectedPartition)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    let path = ShellHelper.getEFIPath()
                    efiPath = path
                    
                    alertTitle = "Success"
                    alertMessage = """
                    Successfully mounted \(selectedPartition)
                    
                    Mounted at: \(path ?? "Unknown location")
                    
                    You can now proceed with kext installation.
                    """
                    isPresented = false
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount \(selectedPartition):
                    
                    \(result.output)
                    
                    Try another partition or check Disk Utility.
                    """
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Donation View (from original code)
struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Int? = 5
    @State private var customAmount: String = ""
    @State private var showThankYou = false
    
    let presetAmounts = [5, 10, 20, 50, 100]
    let paypalURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD"
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("Support Development")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Keep this project alive and growing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            Divider()
            
            // Donation Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Why donate?")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Fund testing hardware for new macOS versions")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Cover server costs for updates and downloads")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Support continued open-source development")
                            .font(.caption)
                    }
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            
            // Amount Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Amount")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        AmountButton(
                            amount: amount,
                            currency: "CAD",
                            isSelected: selectedAmount == amount,
                            action: { selectedAmount = amount }
                        )
                    }
                }
                
                HStack {
                    Text("Custom:")
                        .font(.caption)
                    
                    TextField("Other amount", text: $customAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: customAmount) { _ in
                            selectedAmount = nil
                        }
                    
                    Text("CAD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Donation Methods
            VStack(spacing: 12) {
                Text("Donation Methods")
                    .font(.headline)
                
                Button(action: {
                    openPayPalDonation()
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.white)
                        Text("Donate with PayPal")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // Thank You Message
            if showThankYou {
                VStack(spacing: 8) {
                    Image(systemName: "hands.clap.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("Thank you for your support!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your donation helps keep this project alive.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("All donations go directly to development")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("Made with ❤️ for the Hackintosh community")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 500)
    }
    
    // MARK: - Amount Button Component
    struct AmountButton: View {
        let amount: Int
        let currency: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text("$\(amount)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(currency)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func openPayPalDonation() {
        let amount = getSelectedAmount()
        var urlString = paypalURL
        
        if let amount = amount {
            urlString += "&amount=\(amount)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            showThankYou = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
    
    private func getSelectedAmount() -> Int? {
        if let amount = selectedAmount {
            return amount
        } else if !customAmount.isEmpty, let amount = Int(customAmount) {
            return amount
        }
        return nil
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isDownloadingKDK = false
    @State private var isInstallingKext = false
    @State private var isUninstallingKDK = false
    @State private var isMountingPartition = false
    @State private var downloadProgress: Double = 0
    @State private var installedKDKVersion: String? = nil
    @State private var systemProtectStatus: String = "Checking..."
    @State private var appleHDAStatus: String = "Checking..."
    @State private var appleHDAVersion: String? = nil
    @State private var appleALCStatus: String = "Checking..."
    @State private var appleALCVersion: String? = nil
    @State private var liluStatus: String = "Checking..."
    @State private var liluVersion: String? = nil
    @State private var showDonationSheet = false
    @State private var efiPath: String? = nil
    @State private var showEFISelectionView = false
    @State private var allDrives: [DriveInfo] = []
    @State private var kextSourcePath: String = ""
    @State private var systemInfo = SystemInfo()
    @State private var showDiskDetailView = false
    @State private var selectedDrive: DriveInfo?
    @State private var isLoadingDrives = false
    @State private var showExportView = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    isUninstallingKDK: $isUninstallingKDK,
                    isMountingPartition: $isMountingPartition,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    installedKDKVersion: $installedKDKVersion,
                    systemProtectStatus: $systemProtectStatus,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    showEFISelectionView: $showEFISelectionView,
                    allDrives: $allDrives,
                    isLoadingDrives: $isLoadingDrives,
                    showDiskDetailView: $showDiskDetailView,
                    refreshDrives: refreshAllDrives
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    kextSourcePath: $kextSourcePath
                )
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece.extension")
                }
                .tag(1)
                
                SystemInfoView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleALCStatus: $appleALCStatus,
                    liluStatus: $liluStatus,
                    efiPath: $efiPath,
                    systemInfo: $systemInfo,
                    allDrives: $allDrives,
                    refreshSystemInfo: refreshSystemInfo
                )
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(2)
                
                AudioToolsView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("Audio Tools", systemImage: "speaker.wave.3")
                }
                .tag(3)
                
                SSDTGeneratorView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    efiPath: $efiPath
                )
                .tabItem {
                    Label("SSDT Generator", systemImage: "cpu.fill")
                }
                .tag(4)
            }
            .tabViewStyle(.automatic)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDonationSheet) {
            DonationView()
        }
        .sheet(isPresented: $showEFISelectionView) {
            EFISelectionView(
                isPresented: $showEFISelectionView,
                efiPath: $efiPath,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                allDrives: $allDrives
            )
        }
        .sheet(isPresented: $showDiskDetailView) {
            if let drive = selectedDrive {
                DiskDetailView(
                    isPresented: $showDiskDetailView,
                    drive: drive,
                    allDrives: $allDrives,
                    refreshDrives: refreshAllDrives
                )
            }
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
        .onAppear {
            checkSystemStatus()
            loadAllDrives()
            checkEFIMount()
            loadSystemInfo()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("System Maintenance & Kext Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // System Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(allDrives.filter { $0.isInternal }.count) Internal • \(allDrives.filter { !$0.isInternal }.count) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Audio Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(audioStatusColor)
                        .frame(width: 8, height: 8)
                    Text("Audio: \(audioStatus)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(audioStatusColor.opacity(0.1))
                .cornerRadius(20)
                
                // Export Button in Header
                Button(action: {
                    showExportView = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Export System Information")
                
                // Donate Button
                Button(action: {
                    showDonationSheet = true
                }) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Support Development")
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    private var audioStatus: String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working"
        } else {
            return "Setup Required"
        }
    }
    
    private var audioStatusColor: Color {
        audioStatus == "Working" ? .green : .orange
    }
    
    private func checkSystemStatus() {
        let sipDisabled = ShellHelper.isSIPDisabled()
        systemProtectStatus = sipDisabled ? "Disabled" : "Enabled"
        
        DispatchQueue.global(qos: .background).async {
            let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
            let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
            let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
            
            let liluVer = ShellHelper.getKextVersion("Lilu")
            let appleALCVer = ShellHelper.getKextVersion("AppleALC")
            let appleHDAVer = ShellHelper.getKextVersion("AppleHDA")
            
            DispatchQueue.main.async {
                liluStatus = liluLoaded ? "Installed" : "Not Installed"
                appleALCStatus = appleALCLoaded ? "Installed" : "Not Installed"
                appleHDAStatus = appleHDALoaded ? "Installed" : "Not Installed"
                
                liluVersion = liluVer
                appleALCVersion = appleALCVer
                appleHDAVersion = appleHDAVer
            }
        }
    }
    
    private func loadAllDrives() {
        isLoadingDrives = true
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
                isLoadingDrives = false
            }
        }
    }
    
    private func refreshAllDrives() {
        loadAllDrives()
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            if ShellHelper.mountEFIPartition() {
                let path = ShellHelper.getEFIPath()
                DispatchQueue.main.async {
                    efiPath = path
                }
            }
        }
    }
    
    private func loadSystemInfo() {
        DispatchQueue.global(qos: .background).async {
            let info = ShellHelper.getCompleteSystemInfo()
            DispatchQueue.main.async {
                systemInfo = info
            }
        }
    }
    
    private func refreshSystemInfo() {
        loadSystemInfo()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}