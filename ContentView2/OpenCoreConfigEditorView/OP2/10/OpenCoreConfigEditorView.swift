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
    var parentKey: String?  // Track parent for nested keys
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
                    // Rescan action - will be handled by parent view
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

// MARK: - Debug Information View
struct DebugInfoView: View {
    let configData: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Information")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("Total Sections: \(configData.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(configData.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("• \(key)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if let value = configData[key] {
                                Text(type(of: value))
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .frame(height: 200)
            .padding(4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
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
    @State private var expandedValues: Set<UUID> = []
    @State private var selectedEntryForDetail: ConfigEntry?
    @State private var showDetailView = false
    @State private var showRawJSON = false
    @State private var rawJSONText = ""
    @State private var showDebugInfo = false
    @State private var debugLog: [String] = []
    
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
                
                // Debug toggle
                Toggle("Show Debug Info", isOn: $showDebugInfo)
                    .toggleStyle(.switch)
                    .font(.system(size: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                
                if showDebugInfo {
                    DebugInfoView(configData: configData)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
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
                        
                        // Search field
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                            .font(.system(size: 11))
                            .onChange(of: searchText) {
                                filterEntries()
                            }
                        
                        // Scan for OpenCore button
                        Button(action: {
                            Task {
                                await scanForOpenCore()
                            }
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
                        
                        // Debug button
                        Button(action: {
                            showDebugInfo.toggle()
                        }) {
                            HStack {
                                Image(systemName: "ladybug")
                                    .font(.system(size: 11))
                                Text("Debug")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(showDebugInfo ? .red : .primary)
                        
                        // View Raw JSON
                        Button(action: {
                            showRawJSONView()
                        }) {
                            HStack {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 11))
                                Text("Raw View")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(configData.isEmpty)
                        
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
                
                // Main content area
                if configData.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Configuration Loaded")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Import a config.plist file or scan for OpenCore")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Import Config") {
                            importConfig()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showRawJSON {
                    RawJSONView(jsonText: rawJSONText, onClose: {
                        showRawJSON = false
                    })
                } else {
                    ConfigTableView(
                        entries: searchText.isEmpty ? configEntries : filteredEntries,
                        isEditing: $isEditing,
                        expandedValues: $expandedValues,
                        onEntryTap: { entry in
                            selectedEntryForDetail = entry
                            showDetailView = true
                        }
                    )
                }
            }
            .frame(minWidth: 600)
        }
        .navigationTitle("")
        .sheet(isPresented: $showDetailView) {
            if let entry = selectedEntryForDetail {
                ConfigEntryDetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showRawJSON) {
            RawJSONView(jsonText: rawJSONText, onClose: {
                showRawJSON = false
            })
        }
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
            
            // Scan for OpenCore on appear
            Task {
                await scanForOpenCore()
            }
        }
    }
    
    @State private var filteredEntries: [ConfigEntry] = []
    
    private func filterEntries() {
        if searchText.isEmpty {
            filteredEntries = []
        } else {
            filteredEntries = configEntries.filter { entry in
                entry.key.localizedCaseInsensitiveContains(searchText) ||
                entry.value.localizedCaseInsensitiveContains(searchText) ||
                entry.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func showRawJSONView() {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: configData, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                rawJSONText = jsonString
                showRawJSON = true
            }
        } catch {
            alertMessage = "Failed to generate JSON: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func addDebugLog(_ message: String) {
        debugLog.append("\(Date().formatted(date: .omitted, time: .standard)): \(message)")
        print("🔍 \(message)")
    }
    
    // MARK: - OpenCore Functions
    
    private func scanForOpenCore() async {
        await MainActor.run {
            isScanning = true
        }
        
        // Perform the scan on a background thread
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
        addDebugLog("Updating entries for section: \(section)")
        
        let entries = generateEntriesForSection(section)
        addDebugLog("Generated \(entries.count) entries for section \(section)")
        
        // Log first few entries
        for (index, entry) in entries.prefix(5).enumerated() {
            addDebugLog("  Entry \(index): \(entry.key) = \(entry.value) (\(entry.type))")
        }
        
        configEntries = entries
        expandedValues.removeAll()
    }
    
    private func generateEntriesForSection(_ section: String) -> [ConfigEntry] {
        addDebugLog("Generating entries for section: \(section)")
        
        // If we have actual config data, use it
        if configData.isEmpty {
            addDebugLog("Config data is empty, using defaults")
            return generateDefaultEntriesForSection(section)
        }
        
        // Check if this section exists in the config
        guard let sectionData = configData[section] else {
            addDebugLog("Section \(section) not found in config data")
            return generateDefaultEntriesForSection(section)
        }
        
        addDebugLog("Section \(section) found, type: \(type(of: sectionData))")
        
        let isOpenCoreSpecificValue = isOpenCoreSection(section)
        
        // Generate entries based on section data type
        let entries = generateEntriesFromValue(
            value: sectionData,
            key: section,
            parentKey: nil,
            isOpenCoreSpecific: isOpenCoreSpecificValue
        )
        
        addDebugLog("Generated \(entries.count) total entries for section \(section)")
        return entries.sorted { $0.key < $1.key }
    }
    
    private func generateEntriesFromValue(value: Any, key: String, parentKey: String?, isOpenCoreSpecific: Bool) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        
        if let dict = value as? [String: Any] {
            // For dictionaries, create entries for each key-value pair
            addDebugLog("  Dictionary '\(key)' with \(dict.count) items")
            
            for (subKey, subValue) in dict {
                let fullKey = parentKey != nil ? "\(parentKey!).\(subKey)" : subKey
                entries.append(contentsOf: generateEntriesFromValue(
                    value: subValue,
                    key: subKey,
                    parentKey: fullKey,
                    isOpenCoreSpecific: isOpenCoreSpecific
                ))
            }
        } else if let array = value as? [Any] {
            // For arrays, create a summary entry and entries for first few items
            addDebugLog("  Array '\(key)' with \(array.count) items")
            
            let type = "Array"
            let valueString = "\(array.count) items"
            
            entries.append(ConfigEntry(
                key: key,
                type: type,
                value: valueString,
                isEnabled: true,
                actualValue: array,
                isOpenCoreSpecific: isOpenCoreSpecific,
                parentKey: parentKey
            ))
            
            // Show first 3 items for preview
            for (index, item) in array.prefix(3).enumerated() {
                let itemKey = "\(key)[\(index)]"
                let fullKey = parentKey != nil ? "\(parentKey!).\(itemKey)" : itemKey
                entries.append(contentsOf: generateEntriesFromValue(
                    value: item,
                    key: itemKey,
                    parentKey: fullKey,
                    isOpenCoreSpecific: isOpenCoreSpecific
                ))
            }
            
            if array.count > 3 {
                entries.append(ConfigEntry(
                    key: "\(key)[3+]",
                    type: "Array Items",
                    value: "... \(array.count - 3) more items",
                    isEnabled: true,
                    actualValue: nil,
                    isOpenCoreSpecific: isOpenCoreSpecific,
                    parentKey: parentKey
                ))
            }
        } else {
            // For primitive values
            let type = getTypeString(for: value)
            let valueString = getValueString(for: value, type: type)
            let isEnabled = type == "Boolean" ? (value as? Bool ?? false) : true
            
            addDebugLog("  Primitive '\(key)': \(valueString) (\(type))")
            
            entries.append(ConfigEntry(
                key: key,
                type: type,
                value: valueString,
                isEnabled: isEnabled,
                actualValue: value,
                isOpenCoreSpecific: isOpenCoreSpecific,
                parentKey: parentKey
            ))
        }
        
        return entries
    }
    
    private func generateDefaultEntriesForSection(_ section: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        
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
            return string
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
        addDebugLog("Loading default config")
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
        addDebugLog("Default config loaded with \(configData.count) sections")
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        addDebugLog("Loading config from: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            addDebugLog("File size: \(data.count) bytes")
            
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                configData = plist
                filePath = url.path
                configTitle = "\(url.lastPathComponent) - OpenCore [\(ocVersion) Development Configuration]"
                
                // Log the loaded data structure for debugging
                addDebugLog("✅ Config loaded successfully!")
                addDebugLog("📊 Top-level keys (\(configData.count)): \(configData.keys.sorted().joined(separator: ", "))")
                
                for (key, value) in configData {
                    addDebugLog("📊 Section '\(key)': type = \(type(of: value)), count = \(getValueCount(value))")
                }
                
                updateConfigEntriesForSection(selectedSection)
                
                alertMessage = "Configuration loaded successfully from: \(url.lastPathComponent)\nFound \(configData.count) sections\nCheck Debug panel for details"
                showAlert = true
            } else {
                addDebugLog("❌ Failed to parse as dictionary")
                alertMessage = "Failed to parse config.plist file (not a dictionary)\nFile might be corrupted or in wrong format"
                showAlert = true
            }
        } catch {
            addDebugLog("❌ Error loading config: \(error.localizedDescription)")
            alertMessage = "Failed to load config: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
    
    private func getValueCount(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            return "\(dict.count) keys"
        } else if let array = value as? [Any] {
            return "\(array.count) items"
        } else {
            return "1 value"
        }
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

// MARK: - Component Views (remain the same as before)
// [Include all the component views from the previous version here...]