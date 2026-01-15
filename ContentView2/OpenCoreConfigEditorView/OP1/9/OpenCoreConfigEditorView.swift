// MARK: - Views/OpenCoreConfigEditorView.swift
import SwiftUI
import UniformTypeIdentifiers

struct OpenCoreConfigEditorView: View {
    @State private var configData: [String: Any] = [:]
    @State private var selectedSection: String = "ACPI"
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var filePath = ""
    @State private var isEditing = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var ocVersion = "1.0.6"
    @State private var configTitle = "Untitled 2 - for Official OpenCore [1.0.6 Development Configuration]"
    @State private var configEntries: [ConfigEntry] = []
    
    // Sections similar to the image
    let sections = [
        "ACPI", "AppleInput", "Audio", "Drivers", "Input", "Output", 
        "ProtocolOverrides", "ReservedMemory", "Unload",
        "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"
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
    
    struct ConfigEntry: Identifiable {
        let id = UUID()
        let key: String
        let type: String
        let value: String
        let isEnabled: Bool
    }
    
    var body: some View {
        NavigationView {
            // Left sidebar - Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Configuration title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
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
                    
                    // Main sections in a table format
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
                            SectionRow(
                                section: section,
                                isSelected: selectedSection == section,
                                status: getSectionStatus(section),
                                entryCount: getEntryCount(for: section)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSection = section
                                updateConfigEntriesForSection(section)
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
                        
                        // File info
                        if !filePath.isEmpty {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
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
                
                // Content area - Table view
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
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.propertyList],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: OpenCoreConfigDocument(data: configData),
            contentType: UTType.propertyList,
            defaultFilename: "config-\(Date().formatted(date: .numeric, time: .omitted)).plist"
        ) { result in
            handleExportResult(result)
        }
        .onAppear {
            loadDefaultConfig()
            updateConfigEntriesForSection(selectedSection)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSectionStatus(_ section: String) -> String {
        switch section {
        case "ACPI", "Kernel", "Misc", "PlatformInfo", "UEFI":
            return "Active"
        case "DeviceProperties", "NVRAM":
            return "Configured"
        default:
            return "Default"
        }
    }
    
    private func getEntryCount(for section: String) -> Int {
        // Return the actual count from configEntries for the section
        return configEntries.count
    }
    
    private func updateConfigEntriesForSection(_ section: String) {
        // Update configEntries based on the selected section and configData
        configEntries = generateEntriesForSection(section)
    }
    
    private func generateEntriesForSection(_ section: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        
        switch section {
        case "ACPI":
            entries = [
                ConfigEntry(key: "Add", type: "Array", value: "12 items", isEnabled: true),
                ConfigEntry(key: "Delete", type: "Array", value: "0 items", isEnabled: false),
                ConfigEntry(key: "Patch", type: "Array", value: "4 items", isEnabled: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Enabled", isEnabled: true),
                ConfigEntry(key: "ResetAddress", type: "String", value: "Not set", isEnabled: false),
                ConfigEntry(key: "ResetValue", type: "String", value: "Not set", isEnabled: false)
            ]
        case "DeviceProperties":
            entries = [
                ConfigEntry(key: "Add", type: "Dictionary", value: "15 items", isEnabled: true),
                ConfigEntry(key: "Delete", type: "Dictionary", value: "0 items", isEnabled: false)
            ]
        case "Kernel":
            entries = [
                ConfigEntry(key: "Add", type: "Array", value: "8 items", isEnabled: true),
                ConfigEntry(key: "Block", type: "Array", value: "0 items", isEnabled: false),
                ConfigEntry(key: "Patch", type: "Array", value: "3 items", isEnabled: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Enabled", isEnabled: true),
                ConfigEntry(key: "Scheme", type: "Dictionary", value: "Kernel", isEnabled: true)
            ]
        case "Misc":
            entries = [
                ConfigEntry(key: "Boot", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "Debug", type: "Dictionary", value: "Settings", isEnabled: false),
                ConfigEntry(key: "Security", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "Tools", type: "Array", value: "4 items", isEnabled: true)
            ]
        case "NVRAM":
            entries = [
                ConfigEntry(key: "Add", type: "Dictionary", value: "6 items", isEnabled: true),
                ConfigEntry(key: "Delete", type: "Dictionary", value: "0 items", isEnabled: false),
                ConfigEntry(key: "LegacySchema", type: "Dictionary", value: "Not set", isEnabled: false),
                ConfigEntry(key: "LegacyEnable", type: "Boolean", value: "false", isEnabled: false)
            ]
        case "PlatformInfo":
            entries = [
                ConfigEntry(key: "Automatic", type: "Boolean", value: "false", isEnabled: false),
                ConfigEntry(key: "CustomMemory", type: "Boolean", value: "false", isEnabled: false),
                ConfigEntry(key: "Generic", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "UpdateDataHub", type: "Boolean", value: "true", isEnabled: true),
                ConfigEntry(key: "UpdateNVRAM", type: "Boolean", value: "true", isEnabled: true),
                ConfigEntry(key: "UpdateSMBIOS", type: "Boolean", value: "true", isEnabled: true)
            ]
        case "UEFI":
            entries = [
                ConfigEntry(key: "Audio", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "ConnectDrivers", type: "Boolean", value: "true", isEnabled: true),
                ConfigEntry(key: "Drivers", type: "Array", value: "5 items", isEnabled: true),
                ConfigEntry(key: "Input", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "Output", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "ProtocolOverrides", type: "Dictionary", value: "Settings", isEnabled: false),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "Settings", isEnabled: true),
                ConfigEntry(key: "ReservedMemory", type: "Array", value: "0 items", isEnabled: false)
            ]
        default:
            // For other sections, create generic entries
            entries = [
                ConfigEntry(key: "Enabled", type: "Boolean", value: "true", isEnabled: true),
                ConfigEntry(key: "Settings", type: "Dictionary", value: "Not configured", isEnabled: false)
            ]
        }
        
        return entries
    }
    
    private func loadDefaultConfig() {
        // Load a default configuration
        configData = [
            "ACPI": ["Add": [], "Delete": [], "Patch": []],
            "Kernel": ["Add": [], "Block": [], "Patch": []],
            "Misc": ["Boot": ["Timeout": 5], "Security": ["SecureBootModel": "Default"]],
            "PlatformInfo": ["Generic": ["SystemProductName": "iMacPro1,1"]],
            "UEFI": ["Drivers": [], "Audio": [:], "Input": [:]]
        ]
    }
    
    private func importConfig() {
        showImportPicker = true
    }
    
    private func exportConfig() {
        showExportPicker = true
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                loadConfig(url: url)
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            alertMessage = "Config exported successfully"
            showAlert = true
        case .failure(let error):
            alertMessage = "Export failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        // In a real app, you would parse the config.plist file here
        // For now, we'll simulate loading and update the entries
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            filePath = url.path
            configTitle = "\(url.lastPathComponent) - OpenCore [\(ocVersion) Development Configuration]"
            
            // Update configEntries with data from the imported config
            updateConfigEntriesFromImportedConfig()
            
            alertMessage = "Configuration loaded from: \(url.lastPathComponent)"
            showAlert = true
            isLoading = false
        }
    }
    
    private func updateConfigEntriesFromImportedConfig() {
        // This function would parse the actual config.plist file
        // For now, we'll update with sample data
        switch selectedSection {
        case "ACPI":
            configEntries = [
                ConfigEntry(key: "Add", type: "Array", value: "SSDT-EC.aml, SSDT-PLUG.aml", isEnabled: true),
                ConfigEntry(key: "Delete", type: "Array", value: "0 items", isEnabled: false),
                ConfigEntry(key: "Patch", type: "Array", value: "Rename _OSI to XOSI", isEnabled: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "FadtEnableReset: true", isEnabled: true)
            ]
        case "Kernel":
            configEntries = [
                ConfigEntry(key: "Add", type: "Array", value: "Lilu.kext, WhateverGreen.kext", isEnabled: true),
                ConfigEntry(key: "Block", type: "Array", value: "0 items", isEnabled: false),
                ConfigEntry(key: "Patch", type: "Array", value: "2 patches", isEnabled: true),
                ConfigEntry(key: "Quirks", type: "Dictionary", value: "DisableIoMapper: true", isEnabled: true)
            ]
        case "Misc":
            configEntries = [
                ConfigEntry(key: "Boot", type: "Dictionary", value: "Timeout: 5", isEnabled: true),
                ConfigEntry(key: "Debug", type: "Dictionary", value: "Disabled", isEnabled: false),
                ConfigEntry(key: "Security", type: "Dictionary", value: "SecureBootModel: Default", isEnabled: true),
                ConfigEntry(key: "Tools", type: "Array", value: "OpenShell.efi", isEnabled: true)
            ]
        default:
            // Keep current entries for other sections
            break
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
                Text("Type")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 80, alignment: .leading)
                Text("Value")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Enabled")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 12)
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
                                    .foregroundColor(.blue)
                                    .frame(width: 200, alignment: .leading)
                                
                                Text(entry.type)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(entry.value)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if entry.type == "Boolean" {
                                    Toggle("", isOn: .constant(entry.isEnabled))
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                        .controlSize(.mini)
                                        .frame(width: 40)
                                } else {
                                    Text(entry.isEnabled ? "Yes" : "No")
                                        .font(.system(size: 10))
                                        .foregroundColor(entry.isEnabled ? .green : .red)
                                        .frame(width: 40, alignment: .center)
                                }
                                
                                if isEditing {
                                    Button(action: {}) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.horizontal, 12)
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
    
    var body: some View {
        HStack {
            Text(section)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? .blue : .primary)
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
        case "Configured": return .orange
        case "Default": return .gray
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

// MARK: - OpenCore Config Document
struct OpenCoreConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.propertyList] }
    
    var data: [String: Any]
    
    init(data: [String: Any] = [:]) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        if let plist = try? PropertyListSerialization.propertyList(from: fileData, options: [], format: nil) as? [String: Any] {
            data = plist
        } else {
            data = [:]
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try PropertyListSerialization.data(fromPropertyList: self.data, format: .xml, options: 0)
        return FileWrapper(regularFileWithContents: data)
    }
}