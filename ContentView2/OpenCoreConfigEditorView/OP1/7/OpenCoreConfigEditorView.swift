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
    
    // Sections similar to the image
    let sections = [
        "ACPI", "AppleInput", "Audio", "Drivers", "Input", "Output", "ProtocolOverrides", "ReservedMemory", "Unload",
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
    
    var body: some View {
        NavigationView {
            // Left sidebar - Sections
            List {
                Section(header: Text("Core Sections")) {
                    ForEach(sections, id: \.self) { section in
                        HStack {
                            Text(section)
                                .font(.system(size: 12, design: .monospaced))
                            Spacer()
                            if selectedSection == section {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSection = section
                        }
                    }
                }
                
                Section(header: Text("Quirks")) {
                    ForEach(quirks, id: \.self) { quirk in
                        HStack {
                            Text(quirk)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: .constant(false))
                                .labelsHidden()
                                .scaleEffect(0.7)
                        }
                        .padding(.vertical, 1)
                    }
                }
                
                Section(header: Text("APFS Settings")) {
                    ForEach(apfsSettings, id: \.self) { setting in
                        HStack {
                            Text(setting)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            if setting == "MinVersion" {
                                Text("1.0.6")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            } else {
                                Toggle("", isOn: .constant(true))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 250)
            
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("OpenCore Config Editor")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !filePath.isEmpty {
                        Text(URL(fileURLWithPath: filePath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200)
                    }
                    
                    Button(action: importConfig) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: exportConfig) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(configData.isEmpty)
                    
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Label(isEditing ? "Save" : "Edit", 
                              systemImage: isEditing ? "square.and.arrow.down.fill" : "pencil")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search in config...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content based on selected section
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(section: selectedSection)
                        
                        if selectedSection == "ACPI" {
                            ACPSectionView()
                        } else if selectedSection == "DeviceProperties" {
                            DevicePropertiesSectionView()
                        } else if selectedSection == "Kernel" {
                            KernelSectionView()
                        } else if selectedSection == "Misc" {
                            MiscSectionView()
                        } else if selectedSection == "NVRAM" {
                            NVRAMSectionView()
                        } else if selectedSection == "PlatformInfo" {
                            PlatformInfoSectionView()
                        } else if selectedSection == "UEFI" {
                            UEFISectionView()
                        } else {
                            // Generic section view for other sections
                            GenericSectionView(section: selectedSection)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
                
                // Status bar
                StatusBarView(
                    isLoading: isLoading,
                    isEditing: isEditing,
                    configData: configData,
                    filePath: filePath
                )
            }
            .frame(minWidth: 500)
        }
        .navigationTitle("")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("OpenCore Config"),
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
        }
    }
    
    // MARK: - Section Views
    
    struct SectionHeaderView: View {
        let section: String
        
        var body: some View {
            HStack {
                Image(systemName: sectionIcon(for: section))
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(section)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("Configuration Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
        
        private func sectionIcon(for section: String) -> String {
            switch section {
            case "ACPI": return "cpu"
            case "Kernel": return "gear"
            case "DeviceProperties": return "laptopcomputer"
            case "Misc": return "slider.horizontal.3"
            case "NVRAM": return "memorychip"
            case "PlatformInfo": return "info.circle"
            case "UEFI": return "powerplug"
            default: return "doc.text"
            }
        }
    }
    
    struct ACPSectionView: View {
        @State private var addEntries: [String] = ["SSDT-EC.aml", "SSDT-PLUG.aml"]
        @State private var patchEntries: [String] = ["Rename _OSI to XOSI"]
        @State private var deleteEntries: [String] = []
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ConfigTableSection(title: "Add", entries: $addEntries, placeholder: "Add ACPI table...")
                
                ConfigTableSection(title: "Patch", entries: $patchEntries, placeholder: "Add patch...")
                
                ConfigTableSection(title: "Delete", entries: $deleteEntries, placeholder: "Add table to delete...")
                
                HStack {
                    Text("Enabled")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    struct DevicePropertiesSectionView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Properties Configuration")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    PropertyRow(key: "PciRoot(0x0)/Pci(0x2,0x0)", value: "AAPL,ig-platform-id", data: "07009B3E")
                    PropertyRow(key: "PciRoot(0x0)/Pci(0x1B,0x0)", value: "layout-id", data: "1B000000")
                    PropertyRow(key: "PciRoot(0x0)/Pci(0x1F,0x3)", value: "layout-id", data: "1B000000")
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Button("Add Device Property") {
                    // Add property action
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    struct PropertyRow: View {
        let key: String
        let value: String
        let data: String
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(value)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(data)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }
    
    struct KernelSectionView: View {
        @State private var addEntries: [String] = ["Lilu.kext", "WhateverGreen.kext", "VirtualSMC.kext"]
        @State private var blockEntries: [String] = []
        @State private var patchEntries: [String] = []
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ConfigTableSection(title: "Add", entries: $addEntries, placeholder: "Add kernel extension...")
                
                ConfigTableSection(title: "Block", entries: $blockEntries, placeholder: "Add kext to block...")
                
                ConfigTableSection(title: "Patch", entries: $patchEntries, placeholder: "Add kernel patch...")
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quirks")
                            .font(.headline)
                        HStack {
                            Toggle("AppleCpuPmCfgLock", isOn: .constant(false))
                            Toggle("AppleXcpmCfgLock", isOn: .constant(true))
                            Toggle("DisableIoMapper", isOn: .constant(true))
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    struct MiscSectionView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    ConfigRow(title: "Boot Timeout", value: "5", type: .integer)
                    ConfigRow(title: "Show Picker", value: "true", type: .boolean)
                    ConfigRow(title: "Takeoff Delay", value: "0", type: .integer)
                    ConfigRow(title: "PollAppleHotKeys", value: "true", type: .boolean)
                }
                
                Divider()
                
                Group {
                    Text("Security")
                        .font(.headline)
                    ConfigRow(title: "AllowNvramReset", value: "true", type: .boolean)
                    ConfigRow(title: "AllowSetDefault", value: "true", type: .boolean)
                    ConfigRow(title: "AuthRestart", value: "false", type: .boolean)
                    ConfigRow(title: "SecureBootModel", value: "Default", type: .string)
                    ConfigRow(title: "Vault", value: "Optional", type: .string)
                }
                .padding(.leading, 20)
            }
        }
    }
    
    struct NVRAMSectionView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("NVRAM Variables")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    NVRAMRow(key: "boot-args", value: "keepsyms=1 debug=0x100")
                    NVRAMRow(key: "csr-active-config", value: "00000000")
                    NVRAMRow(key: "prev-lang:kbd", value: "en-US:0")
                    NVRAMRow(key: "SystemAudioVolume", value: "46")
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
                
                HStack {
                    Button("Add Variable") {
                        // Add variable action
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Reset NVRAM") {
                        // Reset NVRAM action
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    struct NVRAMRow: View {
        let key: String
        let value: String
        
        var body: some View {
            HStack {
                Text(key)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.purple)
                    .frame(width: 150, alignment: .leading)
                
                Divider()
                    .frame(height: 12)
                
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }
    
    struct PlatformInfoSectionView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("SMBIOS Settings")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ConfigRow(title: "SystemProductName", value: "iMacPro1,1", type: .string)
                    ConfigRow(title: "SystemSerialNumber", value: "XXXXXXXXXXXX", type: .string)
                    ConfigRow(title: "SystemUUID", value: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", type: .string)
                    ConfigRow(title: "MLB", value: "XXXXXXXXXXXXXX", type: .string)
                    ConfigRow(title: "ROM", value: "XXXXXXXXXXXX", type: .data)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                Text("Note: Fill in your actual SMBIOS data for iCloud services")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    struct UEFISectionView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Drivers")
                        .font(.headline)
                    ConfigRow(title: "OpenCanopy.efi", value: "true", type: .boolean)
                    ConfigRow(title: "OpenRuntime.efi", value: "true", type: .boolean)
                    ConfigRow(title: "OpenUsbKbDxe.efi", value: "false", type: .boolean)
                }
                
                Divider()
                
                Group {
                    Text("Audio")
                        .font(.headline)
                    ConfigRow(title: "AudioDevice", value: "PciRoot(0x0)/Pci(0x1b,0x0)", type: .string)
                    ConfigRow(title: "AudioCodec", value: "0", type: .integer)
                    ConfigRow(title: "AudioOut", value: "0", type: .integer)
                    ConfigRow(title: "MinimumVolume", value: "20", type: .integer)
                    ConfigRow(title: "VolumeAmplifier", value: "0", type: .integer)
                }
                .padding(.leading, 20)
                
                Divider()
                
                Group {
                    Text("Input")
                        .font(.headline)
                    ConfigRow(title: "KeySupport", value: "false", type: .boolean)
                    ConfigRow(title: "KeyForgetThreshold", value: "5", type: .integer)
                    ConfigRow(title: "KeySwap", value: "false", type: .boolean)
                    ConfigRow(title: "PointerSupport", value: "false", type: .boolean)
                }
                .padding(.leading, 20)
            }
        }
    }
    
    struct GenericSectionView: View {
        let section: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(section) Configuration")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("This section contains configuration options for \(section).")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack {
                            Text("Option \(index + 1)")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: .constant(index % 2 == 0))
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                
                Button("Add Option") {
                    // Add option action
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Reusable Components
    
    struct ConfigTableSection: View {
        let title: String
        @Binding var entries: [String]
        let placeholder: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("\(entries.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 0) {
                    ForEach(entries, id: \.self) { entry in
                        HStack {
                            Text(entry)
                                .font(.system(size: 11, design: .monospaced))
                            Spacer()
                            Button(action: {
                                if let index = entries.firstIndex(of: entry) {
                                    entries.remove(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.5))
                        
                        Divider()
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                HStack {
                    TextField(placeholder, text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                    
                    Button("Add") {
                        // Add entry action
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }
    
    struct ConfigRow: View {
        let title: String
        let value: String
        let type: ValueType
        
        enum ValueType {
            case string, integer, boolean, data
        }
        
        var body: some View {
            HStack {
                Text(title)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                
                switch type {
                case .boolean:
                    Toggle("", isOn: .constant(value.lowercased() == "true"))
                        .labelsHidden()
                case .integer, .string, .data:
                    Text(value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(type == .data ? .green : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            type == .data ? Color.green.opacity(0.1) : 
                            type == .integer ? Color.orange.opacity(0.1) : 
                            Color.blue.opacity(0.1)
                        )
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    struct StatusBarView: View {
        let isLoading: Bool
        let isEditing: Bool
        let configData: [String: Any]
        let filePath: String
        
        var body: some View {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading configuration...")
                        .font(.caption)
                } else {
                    Image(systemName: isEditing ? "pencil.circle.fill" : "eye.circle")
                        .foregroundColor(isEditing ? .blue : .gray)
                    Text(isEditing ? "Editing" : "Viewing")
                        .font(.caption)
                    
                    Divider()
                        .frame(height: 12)
                    
                    if !configData.isEmpty {
                        Text("\(configData.keys.count) sections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !filePath.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text(URL(fileURLWithPath: filePath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .frame(height: 32)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadDefaultConfig() {
        // Load a default configuration template
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
            showError("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showSuccess("Config exported successfully")
        case .failure(let error):
            showError("Export failed: \(error.localizedDescription)")
        }
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            filePath = url.path
            showSuccess("Configuration loaded from: \(url.lastPathComponent)")
            isLoading = false
        }
    }
    
    private func showSuccess(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
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