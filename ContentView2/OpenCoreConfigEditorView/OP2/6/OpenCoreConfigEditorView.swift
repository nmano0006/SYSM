// Views/OpenCoreConfigEditorView.swift
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Models
struct ConfigEntry: Identifiable {
    let id = UUID()
    let key: String
    let type: String
    let value: String
    let isEnabled: Bool
    let actualValue: Any?
    var isOpenCoreSpecific: Bool = false
}

// MARK: - OpenCore Info Display View
struct OpenCoreInfoView: View {
    let openCoreInfo: OpenCoreInfo?
    
    var body: some View {
        if let info = openCoreInfo {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenCore Detected")
                    .font(.headline)
                    .foregroundColor(.green)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(title: "Version:", value: info.version)
                        InfoRow(title: "Mode:", value: info.mode)
                        InfoRow(title: "Secure Boot:", value: info.secureBootModel)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(title: "SIP Status:", value: info.sipStatus)
                        InfoRow(title: "Hackintosh:", value: info.isHackintosh ? "Yes" : "No")
                        InfoRow(title: "Boot Args:", value: info.bootArgs)
                    }
                }
                
                if let efiPath = info.efiMountPath {
                    Text("EFI Path: \(efiPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("OpenCore Not Detected")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("No OpenCore bootloader detected on this system.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Scan Again") {
                    // Rescan action
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Main View
struct OpenCoreConfigEditorView: View {
    @State private var configData: [String: Any] = [:]
    @State private var selectedSection: String = "ACPI"
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var filePath = ""
    @State private var isEditing = false
    @State private var ocVersion = "1.0.6"
    @State private var configTitle = "Untitled 2 - for Official OpenCore [1.0.6 Development Configuration]"
    @State private var configEntries: [ConfigEntry] = []
    @State private var openCoreInfo: OpenCoreInfo?
    @State private var showOpenCoreInfo = true
    @State private var isScanning = false
    
    // All OpenCore sections from Sample.plist
    let sections = [
        "APFS", "AppleInput", "Audio", "Booter", "Drivers", "Input", "Output", 
        "ProtocolOverrides", "ReservedMemory", "Unload", "---",
        "ACPI", "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"
    ]
    
    // Quirks similar to the image
    let quirks = [
        "ActivateHpetSupport", "ForgeUefiSupport", "ResizeUsePeiRblo", "ExitBootServicesDelay",
        "DisableSecurityPolicy", "IgnoreInvalidFireRadio", "ShimRetainProtocol",
        "EnableVectorAcceleration", "ReleasedJobOwnership", "UnblockFsConnect",
        "EnableVmx", "ReloadOptionRoms", "ForceOcWriteFlash", "RequestBootVarRouting"
    ]
    
    // APFS settings similar to the image
    let apfsSettings = [
        "EnableJumpstart", "GlobalConnect", "HideVerbose", "JumpstartHotPlug", 
        "MinDate", "MinVersion"
    ]
    
    // Toggle states for APFS settings
    @State private var apfsToggleStates: [String: Bool] = [
        "EnableJumpstart": true,
        "GlobalConnect": true,
        "HideVerbose": false,
        "JumpstartHotPlug": false,
        "MinDate": false,
        "MinVersion": false
    ]
    
    // Toggle states for quirks
    @State private var quirksToggleStates: [String: Bool] = [
        "ActivateHpetSupport": false,
        "ForgeUefiSupport": false,
        "ResizeUsePeiRblo": false,
        "ExitBootServicesDelay": false,
        "DisableSecurityPolicy": false,
        "IgnoreInvalidFireRadio": false,
        "ShimRetainProtocol": false,
        "EnableVectorAcceleration": false,
        "ReleasedJobOwnership": false,
        "UnblockFsConnect": false,
        "EnableVmx": false,
        "ReloadOptionRoms": false,
        "ForceOcWriteFlash": false,
        "RequestBootVarRouting": false
    ]
    
    var body: some View {
        NavigationView {
            // Left sidebar - Sections
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(configTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    // OpenCore Detection Status
                    if showOpenCoreInfo {
                        Divider()
                            .padding(.vertical, 4)
                        
                        Button(action: {
                            showOpenCoreInfo.toggle()
                        }) {
                            HStack {
                                Text(openCoreInfo != nil ? "OpenCore Detected ✓" : "OpenCore Not Found ⚠️")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(openCoreInfo != nil ? .green : .orange)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .rotationEffect(.degrees(showOpenCoreInfo ? 90 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        
                        if showOpenCoreInfo {
                            Divider()
                                .padding(.vertical, 4)
                            
                            OpenCoreInfoView(openCoreInfo: openCoreInfo)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
                // Scrollable sections
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // APFS Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APFS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                            
                            ForEach(apfsSettings, id: \.self) { setting in
                                APFSSettingRow(
                                    setting: setting,
                                    isOn: Binding(
                                        get: { apfsToggleStates[setting] ?? false },
                                        set: { apfsToggleStates[setting] = $0 }
                                    ),
                                    showTextField: setting == "MinDate" || setting == "MinVersion",
                                    textValue: setting == "MinVersion" ? ocVersion : ""
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Configuration Sections in table format
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Configuration Sections")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                            
                            // Header row
                            HStack {
                                Text("Section")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 120, alignment: .leading)
                                Text("Status")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 60, alignment: .center)
                                Text("Entries")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            
                            // Section rows
                            ForEach(sections, id: \.self) { section in
                                if section == "---" {
                                    Divider()
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 12)
                                } else {
                                    SectionRow(
                                        section: section,
                                        isSelected: selectedSection == section,
                                        status: getSectionStatus(section),
                                        entryCount: getActualEntryCount(for: section),
                                        isOpenCoreSection: isOpenCoreSection(section)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSection = section
                                        updateConfigEntriesForSection(section)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Quirks section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quirks")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                            
                            ForEach(quirks, id: \.self) { quirk in
                                QuirkRow(
                                    quirk: quirk,
                                    isOn: Binding(
                                        get: { quirksToggleStates[quirk] ?? false },
                                        set: { quirksToggleStates[quirk] = $0 }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 300, maxWidth: 320)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main content area
            VStack(spacing: 0) {
                // Header/toolbar
                VStack(spacing: 0) {
                    HStack {
                        Text("OpenCore Configurator 2.7.8.1.0")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Scan for OpenCore button
                        Button(action: {
                            scanForOpenCore()
                        }) {
                            HStack {
                                if isScanning {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 11))
                                }
                                Text("Scan OpenCore")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isScanning)
                        
                        // File info
                        if !filePath.isEmpty {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 150)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
                        // Import Button
                        Button(action: importConfig) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 11))
                                Text("Import")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Export Button
                        Button(action: exportConfig) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                Text("Export")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(configData.isEmpty)
                        
                        // Edit/Save Button
                        Button(action: {
                            isEditing.toggle()
                            if isEditing {
                                alertMessage = "Entered edit mode"
                                showAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                                    .font(.system(size: 11))
                                Text(isEditing ? "Save" : "Edit")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                }
                
                // Main content area - Table view
                ConfigTableView(entries: configEntries, isEditing: $isEditing)
            }
            .frame(minWidth: 600)
        }
        .navigationTitle("")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("OpenCore Configurator"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadDefaultConfig()
            updateConfigEntriesForSection(selectedSection)
            
            // Use Task to avoid modifying state during view update
            Task {
                await scanForOpenCore()
            }
        }
    }
    
    // MARK: - OpenCore Functions
    
    private func scanForOpenCore() async {
        await MainActor.run {
            isScanning = true
        }
        
        let openCoreInfo = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let info = ShellHelper.detectOpenCore()
                continuation.resume(returning: info)
            }
        }
        
        await MainActor.run {
            self.openCoreInfo = openCoreInfo
            self.isScanning = false
            
            if let info = openCoreInfo {
                if !info.version.isEmpty && info.version != "Unknown" {
                    self.ocVersion = info.version
                    self.configTitle = "OpenCore Configurator - \(info.version) (\(info.mode))"
                }
                
                // Try to load OpenCore config if detected
                if let config = ShellHelper.getOpenCoreConfig() {
                    self.configData = config
                    self.updateConfigEntriesForSection(self.selectedSection)
                    self.alertMessage = "Loaded OpenCore configuration from EFI partition"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func isOpenCoreSection(_ section: String) -> Bool {
        let openCoreSections = ["ACPI", "Booter", "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
        return openCoreSections.contains(section)
    }
    
    // MARK: - Import/Export Functions
    
    private func importConfig() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select OpenCore Config.plist"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [UTType.propertyList]
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                loadConfig(url: url)
            }
        }
    }
    
    private func exportConfig() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save OpenCore Config"
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = true
        savePanel.nameFieldStringValue = "config-\(Date().formatted(date: .numeric, time: .omitted)).plist"
        savePanel.allowedContentTypes = [UTType.propertyList]
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                saveConfig(to: url)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSectionStatus(_ section: String) -> String {
        // Check if section exists in config data
        if configData[section] != nil {
            return "Active"
        }
        
        // Check if it's an OpenCore-specific section
        if isOpenCoreSection(section) && openCoreInfo != nil {
            return "Available"
        }
        
        // Default statuses based on typical OpenCore config
        switch section {
        case "APFS", "ACPI", "Kernel", "Misc", "PlatformInfo", "UEFI":
            return openCoreInfo != nil ? "Available" : "Inactive"
        case "Booter", "DeviceProperties", "NVRAM":
            return openCoreInfo != nil ? "Configured" : "Inactive"
        case "AppleInput", "Audio", "Drivers", "Input", "Output":
            return "Default"
        case "ProtocolOverrides", "ReservedMemory", "Unload":
            return "Disabled"
        default:
            return "Default"
        }
    }
    
    private func getActualEntryCount(for section: String) -> Int {
        if let sectionData = configData[section] as? [String: Any] {
            return sectionData.count
        } else if let sectionData = configData[section] as? [Any] {
            return sectionData.count
        }
        
        // Fallback to default counts
        return getEntryCount(for: section)
    }
    
    private func getEntryCount(for section: String) -> Int {
        // Return typical entry counts for each section
        switch section {
        case "APFS":
            return apfsSettings.count
        case "ACPI":
            return 4  // Add, Delete, Patch, Quirks
        case "Booter":
            return 3  // MmioWhitelist, Patch, Quirks
        case "DeviceProperties":
            return 2  // Add, Delete
        case "Kernel":
            return 5  // Add, Block, Patch, Quirks, Scheme
        case "Misc":
            return 6  // Boot, Debug, Security, Tools, Entries, Serial
        case "NVRAM":
            return 4  // Add, Delete, LegacySchema, WriteFlash
        case "PlatformInfo":
            return 7  // Automatic, CustomMemory, Generic, UpdateDataHub, UpdateNVRAM, UpdateSMBIOS, UpdateSMBIOSMode
        case "UEFI":
            return 8  // APFS, Drivers, Input, Output, ProtocolOverrides, Quirks, ReservedMemory, Unload
        case "AppleInput", "Audio":
            return 2
        case "Drivers", "Input", "Output":
            return 3
        case "ProtocolOverrides", "ReservedMemory", "Unload":
            return 0
        default:
            return 0
        }
    }
    
    private func updateConfigEntriesForSection(_ section: String) {
        configEntries = generateEntriesForSection(section)
    }
    
    private func generateEntriesForSection(_ section: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        
        print("🔍 Generating entries for section: \(section)")
        
        // If we have actual config data, use it
        if configData.isEmpty {
            print("⚠️ Config data is empty, using defaults")
            return generateDefaultEntriesForSection(section)
        }
        
        // Check if this section exists in the config
        guard let sectionData = configData[section] else {
            print("⚠️ Section \(section) not found in config data")
            return generateDefaultEntriesForSection(section)
        }
        
        print("✅ Section \(section) found in config data")
        
        // Store the result of isOpenCoreSection to avoid the warning
        let isOpenCoreSpecificValue = isOpenCoreSection(section)
        
        // Handle different types of section data
        if let dictData = sectionData as? [String: Any] {
            print("📊 Section is a dictionary with \(dictData.count) items")
            
            for (key, value) in dictData {
                let type = getTypeString(for: value)
                let valueString = getValueString(for: value, type: type)
                let isEnabled = true
                
                print("   - Key: \(key), Type: \(type), Value: \(valueString)")
                
                entries.append(ConfigEntry(
                    key: key,
                    type: type,
                    value: valueString,
                    isEnabled: isEnabled,
                    actualValue: value,
                    isOpenCoreSpecific: isOpenCoreSpecificValue
                ))
            }
        } else if let arrayData = sectionData as? [Any] {
            print("📊 Section is an array with \(arrayData.count) items")
            
            // For arrays, show count and type
            entries.append(ConfigEntry(
                key: "Items",
                type: "Array",
                value: "\(arrayData.count) items",
                isEnabled: true,
                actualValue: arrayData,
                isOpenCoreSpecific: isOpenCoreSpecificValue
            ))
            
            // Also show first few items if they're dictionaries
            if arrayData.count > 0, let firstItem = arrayData.first as? [String: Any] {
                for (key, value) in firstItem {
                    let type = getTypeString(for: value)
                    let valueString = getValueString(for: value, type: type)
                    
                    entries.append(ConfigEntry(
                        key: "[0].\(key)",
                        type: type,
                        value: valueString,
                        isEnabled: true,
                        actualValue: value,
                        isOpenCoreSpecific: isOpenCoreSpecificValue
                    ))
                }
            }
        } else if let boolData = sectionData as? Bool {
            // For boolean sections
            entries.append(ConfigEntry(
                key: "Enabled",
                type: "Boolean",
                value: boolData ? "true" : "false",
                isEnabled: boolData,
                actualValue: boolData,
                isOpenCoreSpecific: isOpenCoreSpecificValue
            ))
        } else if let stringData = sectionData as? String {
            // For string sections
            entries.append(ConfigEntry(
                key: "Value",
                type: "String",
                value: stringData,
                isEnabled: true,
                actualValue: stringData,
                isOpenCoreSpecific: isOpenCoreSpecificValue
            ))
        } else if let numberData = sectionData as? Int {
            // For number sections
            entries.append(ConfigEntry(
                key: "Value",
                type: "Number",
                value: "\(numberData)",
                isEnabled: true,
                actualValue: numberData,
                isOpenCoreSpecific: isOpenCoreSpecificValue
            ))
        } else if let doubleData = sectionData as? Double {
            // For double sections
            entries.append(ConfigEntry(
                key: "Value",
                type: "Double",
                value: String(format: "%.2f", doubleData),
                isEnabled: true,
                actualValue: doubleData,
                isOpenCoreSpecific: isOpenCoreSpecificValue
            ))
        } else {
            print("⚠️ Unknown section data type for \(section)")
            return generateDefaultEntriesForSection(section)
        }
        
        print("✅ Generated \(entries.count) entries for section \(section)")
        return entries.sorted { $0.key < $1.key }
    }
    
    private func generateDefaultEntriesForSection(_ section: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        
        print("📝 Generating default entries for section: \(section)")
        
        let isOpenCoreSpecificValue = isOpenCoreSection(section)
        
        switch section {
        case "APFS":
            entries = apfsSettings.map { setting in
                ConfigEntry(
                    key: setting,
                    type: setting == "MinDate" || setting == "MinVersion" ? "String" : "Boolean",
                    value: setting == "MinVersion" ? ocVersion : "\(apfsToggleStates[setting] ?? false)",
                    isEnabled: apfsToggleStates[setting] ?? false,
                    actualValue: nil,
                    isOpenCoreSpecific: false
                )
            }
        case "ACPI":
            entries = [
                ConfigEntry(key: "Add", type: "Array", value: "Items", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Delete", type: "Array", value: "Items", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Patch", type: "Array", value: "Items", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "Booter":
            entries = [
                ConfigEntry(key: "MmioWhitelist", type: "Array", value: "Items", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Patch", type: "Array", value: "Items", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "DeviceProperties":
            entries = [
                ConfigEntry(key: "Add", type: "Dictionary", value: "Properties", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Delete", type: "Dictionary", value: "Properties", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "Kernel":
            entries = [
                ConfigEntry(key: "Add", type: "Array", value: "Kexts", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Block", type: "Array", value: "Items", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Patch", type: "Array", value: "Patches", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Scheme", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "Misc":
            entries = [
                ConfigEntry(key: "Boot", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Debug", type: "Dictionary", value: "Settings", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Security", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Tools", type: "Array", value: "Tools", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "NVRAM":
            entries = [
                ConfigEntry(key: "Add", type: "Dictionary", value: "Variables", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Delete", type: "Dictionary", value: "Variables", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "LegacySchema", type: "Dictionary", value: "Settings", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "WriteFlash", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "PlatformInfo":
            entries = [
                ConfigEntry(key: "Automatic", type: "Boolean", value: "false", isEnabled: false, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Generic", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "UpdateDataHub", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "UpdateSMBIOS", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "UEFI":
            entries = [
                ConfigEntry(key: "APFS", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "ConnectDrivers", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Drivers", type: "Array", value: "Drivers", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Input", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Output", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Settings", isEnabled: true, actualValue: nil, isOpenCoreSpecific: true)
            ]
        case "AppleInput":
            entries = [
                ConfigEntry(key: "AppleEvent", type: "String", value: "Builtin", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false),
                ConfigEntry(key: "CustomDelays", type: "Boolean", value: "false", isEnabled: false, actualValue: nil, isOpenCoreSpecific: false)
            ]
        case "Audio":
            entries = [
                ConfigEntry(key: "AudioSupport", type: "Boolean", value: "false", isEnabled: false, actualValue: nil, isOpenCoreSpecific: false),
                ConfigEntry(key: "PlayChime", type: "String", value: "Auto", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false)
            ]
        case "Drivers":
            entries = [
                ConfigEntry(key: "OpenRuntime.efi", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false),
                ConfigEntry(key: "HfsPlus.efi", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false)
            ]
        case "Input":
            entries = [
                ConfigEntry(key: "KeySupport", type: "Boolean", value: "false", isEnabled: false, actualValue: nil, isOpenCoreSpecific: false),
                ConfigEntry(key: "PointerSupport", type: "Boolean", value: "false", isEnabled: false, actualValue: nil, isOpenCoreSpecific: false)
            ]
        case "Output":
            entries = [
                ConfigEntry(key: "ConsoleMode", type: "String", value: "Max", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false),
                ConfigEntry(key: "Resolution", type: "String", value: "Max", isEnabled: true, actualValue: nil, isOpenCoreSpecific: false)
            ]
        default:
            entries = [
                ConfigEntry(key: "Enabled", type: "Boolean", value: "true", isEnabled: true, actualValue: nil, isOpenCoreSpecific: isOpenCoreSpecificValue)
            ]
        }
        
        print("✅ Generated \(entries.count) default entries for section \(section)")
        return entries
    }
    
    private func getTypeString(for value: Any) -> String {
        switch value {
        case is String: return "String"
        case is Bool: return "Boolean"
        case is Int: return "Integer"
        case is Double: return "Double"
        case is [Any]: return "Array"
        case is [String: Any]: return "Dictionary"
        case is Data: return "Data"
        default: return "Unknown"
        }
    }
    
    private func getValueString(for value: Any, type: String) -> String {
        switch value {
        case let string as String:
            let limitedString = String(string.prefix(50))
            return limitedString
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as Int:
            return "\(number)"
        case let number as Double:
            return String(format: "%.2f", number)
        case let array as [Any]:
            return "\(array.count) items"
        case let dict as [String: Any]:
            return "\(dict.count) keys"
        case let data as Data:
            return "Data (\(data.count) bytes)"
        default:
            return "\(value)"
        }
    }
    
    private func loadDefaultConfig() {
        print("📂 Loading default config")
        configData = [
            "ACPI": ["Add": [], "Delete": [], "Patch": [], "Quirks": [:]],
            "Booter": ["MmioWhitelist": [], "Patch": [], "Quirks": [:]],
            "DeviceProperties": ["Add": [:], "Delete": [:]],
            "Kernel": ["Add": [], "Block": [], "Patch": [], "Quirks": [:], "Scheme": [:]],
            "Misc": ["Boot": [:], "Debug": [:], "Security": [:], "Tools": []],
            "NVRAM": ["Add": [:], "Delete": [:], "WriteFlash": true],
            "PlatformInfo": ["Generic": [:], "UpdateDataHub": true, "UpdateSMBIOS": true],
            "UEFI": ["APFS": [:], "Drivers": [], "Input": [:], "Output": [:], "Quirks": [:]]
        ]
        print("✅ Default config loaded with \(configData.count) sections")
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        print("📥 Loading config from: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("📊 File size: \(data.count) bytes")
            
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                configData = plist
                filePath = url.path
                configTitle = "\(url.lastPathComponent) - OpenCore [\(ocVersion) Development Configuration]"
                
                print("✅ Config loaded successfully!")
                print("📊 Sections found: \(configData.keys.joined(separator: ", "))")
                
                // Log all sections for debugging
                for (key, value) in configData {
                    print("📊 Section '\(key)': type = \(type(of: value))")
                    if let dict = value as? [String: Any] {
                        print("   Has \(dict.count) keys: \(dict.keys.joined(separator: ", "))")
                    } else if let array = value as? [Any] {
                        print("   Has \(array.count) items")
                    }
                }
                
                updateConfigEntriesForSection(selectedSection)
                
                // Update APFS settings
                if let uefiConfig = plist["UEFI"] as? [String: Any],
                   let apfsSettingsConfig = uefiConfig["APFS"] as? [String: Any] {
                    for (key, value) in apfsSettingsConfig {
                        if let boolValue = value as? Bool {
                            apfsToggleStates[key] = boolValue
                        }
                    }
                }
                
                // Update Quirks
                if let uefiConfig = plist["UEFI"] as? [String: Any],
                   let quirksConfig = uefiConfig["Quirks"] as? [String: Any] {
                    for (key, value) in quirksConfig {
                        if let boolValue = value as? Bool {
                            quirksToggleStates[key] = boolValue
                        }
                    }
                }
                
                alertMessage = "Configuration loaded successfully from: \(url.lastPathComponent)\nFound \(configData.count) sections"
                showAlert = true
            } else {
                print("❌ Failed to parse as dictionary")
                alertMessage = "Failed to parse config.plist file"
                showAlert = true
            }
        } catch {
            print("❌ Error loading config: \(error.localizedDescription)")
            alertMessage = "Failed to load config: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
    
    private func saveConfig(to url: URL) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: configData, format: .xml, options: 0)
            try data.write(to: url)
            alertMessage = "Configuration saved successfully to: \(url.lastPathComponent)"
            showAlert = true
            filePath = url.path
        } catch {
            alertMessage = "Failed to save config: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Component Views

struct ConfigTableView: View {
    let entries: [ConfigEntry]
    @Binding var isEditing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Table header
            HStack {
                Text("Key")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 200, alignment: .leading)
                    .padding(.leading, 12)
                Text("Type")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 80, alignment: .leading)
                Text("Value")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Enabled")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 60, alignment: .center)
                Spacer()
                    .frame(width: 40)
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            
            // Table rows
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Text("No configuration entries available")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            HStack {
                                Text(entry.key)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(entry.isOpenCoreSpecific ? .blue : .primary)
                                    .frame(width: 200, alignment: .leading)
                                    .padding(.leading, 12)
                                
                                Text(entry.type)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(entry.value)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(entry.isOpenCoreSpecific ? .green : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if entry.type == "Boolean" {
                                    Text(entry.isEnabled ? "Yes" : "No")
                                        .font(.system(size: 10))
                                        .foregroundColor(entry.isEnabled ? .green : .red)
                                        .frame(width: 40, alignment: .center)
                                } else {
                                    Text("N/A")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                        .frame(width: 40, alignment: .center)
                                }
                                
                                if isEditing {
                                    Button(action: {}) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(width: 40)
                                } else {
                                    Spacer()
                                        .frame(width: 40)
                                }
                            }
                            .padding(.vertical, 6)
                            .background(entries.firstIndex(where: { $0.id == entry.id })! % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                            
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct APFSSettingRow: View {
    let setting: String
    @Binding var isOn: Bool
    let showTextField: Bool
    let textValue: String
    
    var body: some View {
        HStack {
            Text(setting)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            if showTextField {
                Text(textValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .frame(width: 60)
            } else {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct SectionRow: View {
    let section: String
    let isSelected: Bool
    let status: String
    let entryCount: Int
    let isOpenCoreSection: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(section)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                if isOpenCoreSection {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 120, alignment: .leading)
            
            Text(status)
                .font(.system(size: 9))
                .foregroundColor(statusColor)
                .frame(width: 60, alignment: .center)
            
            Text("\(entryCount)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status {
        case "Active": return .green
        case "Available": return .blue
        case "Configured": return .orange
        case "Default": return .gray
        case "Disabled": return .red
        case "Inactive": return .secondary
        default: return .secondary
        }
    }
}

struct QuirkRow: View {
    let quirk: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(quirk)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 150, alignment: .leading)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .frame(width: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}