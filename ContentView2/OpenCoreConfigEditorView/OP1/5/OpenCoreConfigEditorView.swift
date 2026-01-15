import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Main OpenCore Config Editor View
struct OpenCoreConfigEditorView: View {
    @State private var configContent = ""
    @State private var formattedConfigContent = ""
    @State private var filePath = ""
    @State private var isEditing = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "OpenCore Config"
    @State private var isLoading = false
    @State private var validationErrors: [String] = []
    @State private var showRawXML = false
    @State private var searchText = ""
    @State private var configData: [String: Any] = [:]
    @State private var expandedSections: Set<String> = []
    @State private var showSampleLoader = false
    
    var filteredContent: String {
        if searchText.isEmpty {
            return showRawXML ? configContent : formattedConfigContent
        }
        if showRawXML {
            return highlightSearch(in: configContent)
        } else {
            return highlightSearch(in: formattedConfigContent)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "platter.2.filled.ipad")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("OpenCore Config.plist Editor")
                        .font(.headline)
                    Spacer()
                    
                    // Search field
                    if !configContent.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: importConfig) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: exportConfig) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(configContent.isEmpty)
                    
                    if !configContent.isEmpty {
                        Button(action: {
                            showRawXML.toggle()
                        }) {
                            Label(showRawXML ? "Formatted" : "Raw XML", 
                                  systemImage: showRawXML ? "text.alignleft" : "chevron.left.forwardslash.chevron.right")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: validateConfig) {
                            Label("Validate", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if configContent.isEmpty {
                        Button(action: {
                            showSampleLoader = true
                        }) {
                            Label("Load Sample", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(.green)
                    }
                    
                    if !configContent.isEmpty {
                        Button(action: {
                            if isEditing {
                                saveConfig()
                            } else {
                                isEditing = true
                            }
                        }) {
                            Label(isEditing ? "Save" : "Edit", 
                                  systemImage: isEditing ? "square.and.arrow.down.fill" : "pencil")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            if !filePath.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(URL(fileURLWithPath: filePath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Reload") {
                        loadConfig(path: filePath)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
            }
            
            if !validationErrors.isEmpty {
                ValidationErrorView(errors: $validationErrors)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // Editor or Tree View
            if !configContent.isEmpty {
                if showRawXML {
                    // Raw XML Editor/Viewer
                    ConfigEditorView(
                        content: $configContent,
                        isEditing: $isEditing,
                        searchText: searchText,
                        filteredContent: filteredContent
                    )
                } else {
                    // Tree/Formatted View
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ConfigTreeView(
                                data: configData,
                                expandedSections: $expandedSections,
                                searchText: searchText,
                                depth: 0
                            )
                        }
                    }
                    .background(Color.gray.opacity(0.05))
                }
            } else {
                // Empty state
                EmptyConfigView(
                    importConfig: importConfig,
                    createNewConfig: createNewConfig,
                    openEFIConfig: openEFIConfig,
                    loadSampleConfig: loadSampleConfig
                )
            }
            
            // Status bar
            StatusBarView(
                isLoading: isLoading,
                isEditing: isEditing,
                configContent: configContent,
                filePath: filePath,
                showRawXML: showRawXML
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.propertyList, UTType.xml],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: OpenCoreConfigDocument(content: configContent),
            contentType: UTType.propertyList,
            defaultFilename: "config-\(Date().formatted(date: .numeric, time: .omitted)).plist"
        ) { result in
            handleExportResult(result)
        }
        .sheet(isPresented: $showSampleLoader) {
            SampleConfigLoaderView(loadSampleConfig: loadSampleConfig)
        }
    }
    
    // MARK: - Helper Functions
    
    private func highlightSearch(in text: String) -> String {
        if searchText.isEmpty { return text }
        
        // Simple search highlighting
        let lines = text.components(separatedBy: "\n")
        var highlightedLines: [String] = []
        
        for line in lines {
            if line.lowercased().contains(searchText.lowercased()) {
                // Add a marker to indicate this line contains search results
                highlightedLines.append("🔍 \(line)")
            } else {
                highlightedLines.append(line)
            }
        }
        
        return highlightedLines.joined(separator: "\n")
    }
    
    private func formatXML(_ xml: String) -> String {
        // Simple XML formatting
        var formatted = ""
        var indentLevel = 0
        
        let lines = xml.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("</") && !trimmed.hasPrefix("</?") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            let indent = String(repeating: "  ", count: indentLevel)
            formatted += "\(indent)\(trimmed)\n"
            
            if !trimmed.hasPrefix("</") && 
               !trimmed.hasPrefix("<?") && 
               !trimmed.hasPrefix("<!") && 
               !trimmed.contains("/>") &&
               !trimmed.hasPrefix("<key>") && 
               !trimmed.hasPrefix("<string>") && 
               !trimmed.hasPrefix("<integer>") && 
               !trimmed.hasPrefix("<true/>") && 
               !trimmed.hasPrefix("<false/>") && 
               !trimmed.hasPrefix("<data>") && 
               !trimmed.hasPrefix("<date>") {
                indentLevel += 1
            }
        }
        
        return formatted
    }
    
    private func parsePlist(_ data: Data) -> [String: Any]? {
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                return plist
            }
        } catch {
            print("Error parsing plist: \(error)")
        }
        return nil
    }
    
    // MARK: - Actions
    
    private func importConfig() {
        showImportPicker = true
    }
    
    private func exportConfig() {
        showExportPicker = true
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                
                // Try to parse as XML first
                if let xmlString = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.configContent = xmlString
                        self.formattedConfigContent = self.formatXML(xmlString)
                        
                        // Try to parse as plist for tree view
                        if let plistData = self.parsePlist(data) {
                            self.configData = plistData
                        } else {
                            // If parsing fails, create empty dict
                            self.configData = [:]
                        }
                        
                        self.filePath = url.path
                        self.isEditing = false
                        self.validationErrors.removeAll()
                        self.searchText = ""
                        
                        // Auto-expand main sections
                        let mainSections = ["ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI", "DeviceProperties"]
                        self.expandedSections = Set(mainSections)
                        
                        self.showSuccess("Config loaded successfully")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showError("Unable to read config file - invalid encoding")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to load config: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func loadConfig(path: String) {
        let url = URL(fileURLWithPath: path)
        loadConfig(url: url)
    }
    
    private func saveConfig() {
        guard !filePath.isEmpty else {
            showError("No file selected for saving")
            return
        }
        
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if let data = self.configContent.data(using: .utf8) {
                    try data.write(to: URL(fileURLWithPath: self.filePath))
                    
                    DispatchQueue.main.async {
                        self.isEditing = false
                        
                        // Reload to refresh parsed data
                        self.loadConfig(path: self.filePath)
                        
                        self.showSuccess("Config saved successfully")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showError("Unable to encode config data")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to save config: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func createNewConfig() {
        let template = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>#WARNING - 1</key>
    <string>This is just a sample. Do NOT try loading it.</string>
    <key>#WARNING - 2</key>
    <string>Ensure you understand EVERY field before booting.</string>
    <key>#WARNING - 3</key>
    <string>In most cases recommended to use Sample.plist</string>
    <key>#WARNING - 4</key>
    <string>Use SampleCustom.plist only for special cases.</string>
    <key>ACPI</key>
    <dict>
        <key>Add</key>
        <array/>
        <key>Delete</key>
        <array/>
        <key>Patch</key>
        <array/>
        <key>Quirks</key>
        <dict>
            <key>FadtEnableReset</key>
            <false/>
            <key>NormalizeHeaders</key>
            <false/>
            <key>RebaseRegions</key>
            <false/>
            <key>ResetHwSig</key>
            <false/>
            <key>ResetLogoStatus</key>
            <true/>
            <key>SyncTableIds</key>
            <false/>
        </dict>
    </dict>
    
    <key>Booter</key>
    <dict>
        <key>MmioWhitelist</key>
        <array/>
        <key>Patch</key>
        <array/>
        <key>Quirks</key>
        <dict>
            <key>AvoidRuntimeDefrag</key>
            <true/>
            <key>DevirtualiseMmio</key>
            <false/>
            <key>DisableSingleUser</key>
            <false/>
            <key>DisableVariableWrite</key>
            <false/>
            <key>DiscardHibernateMap</key>
            <false/>
            <key>EnableSafeModeSlide</key>
            <true/>
            <key>EnableWriteUnprotector</key>
            <true/>
            <key>ForceExitBootServices</key>
            <false/>
            <key>ProtectMemoryRegions</key>
            <false/>
            <key>ProtectSecureBoot</key>
            <false/>
            <key>ProtectUefiServices</key>
            <false/>
            <key>ProvideCustomSlide</key>
            <true/>
            <key>RebuildAppleMemoryMap</key>
            <false/>
            <key>SetupVirtualMap</key>
            <true/>
            <key>SignalAppleOS</key>
            <false/>
            <key>SyncRuntimePermissions</key>
            <false/>
        </dict>
    </dict>
    
    <key>DeviceProperties</key>
    <dict>
        <key>Add</key>
        <dict/>
        <key>Delete</key>
        <dict/>
    </dict>
    
    <key>Kernel</key>
    <dict>
        <key>Add</key>
        <array/>
        <key>Block</key>
        <array/>
        <key>Emulate</key>
        <dict/>
        <key>Force</key>
        <array/>
        <key>Patch</key>
        <array/>
        <key>Quirks</key>
        <dict>
            <key>AppleCpuPmCfgLock</key>
            <false/>
            <key>AppleXcpmCfgLock</key>
            <false/>
            <key>AppleXcpmExtraMsrs</key>
            <false/>
            <key>AppleXcpmForceBoost</key>
            <false/>
            <key>CustomSMBIOSGuid</key>
            <false/>
            <key>DisableIoMapper</key>
            <false/>
            <key>DisableRtcChecksum</key>
            <false/>
            <key>ExternalDiskIcons</key>
            <false/>
            <key>IncreasePciBarSize</key>
            <false/>
            <key>LapicKernelPanic</key>
            <false/>
            <key>PanicNoKextDump</key>
            <false/>
            <key>PowerTimeoutKernelPanic</key>
            <false/>
            <key>ThirdPartyDrives</key>
            <false/>
            <key>XhciPortLimit</key>
            <false/>
        </dict>
        <key>Scheme</key>
        <dict>
            <key>FuzzyMatch</key>
            <true/>
        </dict>
    </dict>
    
    <key>Misc</key>
    <dict>
        <key>Boot</key>
        <dict>
            <key>Timeout</key>
            <integer>5</integer>
            <key>ShowPicker</key>
            <true/>
            <key>HideAuxiliary</key>
            <true/>
            <key>PollAppleHotKeys</key>
            <false/>
        </dict>
        <key>Security</key>
        <dict>
            <key>AllowNvramReset</key>
            <false/>
            <key>SecureBootModel</key>
            <string>Default</string>
            <key>Vault</key>
            <string>Secure</string>
        </dict>
        <key>Debug</key>
        <dict>
            <key>AppleDebug</key>
            <false/>
            <key>ApplePanic</key>
            <false/>
            <key>DisableWatchDog</key>
            <false/>
            <key>DisplayDelay</key>
            <integer>0</integer>
            <key>DisplayLevel</key>
            <integer>2147483650</integer>
            <key>Target</key>
            <integer>3</integer>
        </dict>
        <key>Entries</key>
        <array/>
        <key>Tools</key>
        <array/>
    </dict>
    
    <key>NVRAM</key>
    <dict>
        <key>Add</key>
        <dict>
            <key>4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14</key>
            <dict>
                <key>DefaultBackgroundColor</key>
                <data>AAAAAA==</data>
            </dict>
            <key>7C436110-AB2A-4BBB-A880-FE41995C9F82</key>
            <dict>
                <key>boot-args</key>
                <string>-v keepsyms=1</string>
                <key>csr-active-config</key>
                <data>AAAAAA==</data>
                <key>prev-lang:kbd</key>
                <data>cnUtUlU6MjUy</data>
            </dict>
        </dict>
        <key>Delete</key>
        <dict/>
        <key>LegacyEnable</key>
        <false/>
        <key>LegacyOverwrite</key>
        <false/>
        <key>LegacySchema</key>
        <dict/>
        <key>WriteFlash</key>
        <true/>
    </dict>
    
    <key>PlatformInfo</key>
    <dict>
        <key>Automatic</key>
        <true/>
        <key>CustomMemory</key>
        <false/>
        <key>Generic</key>
        <dict>
            <key>AdviseFeatures</key>
            <false/>
            <key>MLB</key>
            <string>M0000000000000001</string>
            <key>MaxBIOSVersion</key>
            <false/>
            <key>ProcessorType</key>
            <integer>0</integer>
            <key>ROM</key>
            <data>ESIzRFVm</data>
            <key>SpoofVendor</key>
            <true/>
            <key>SystemMemoryStatus</key>
            <string>Auto</string>
            <key>SystemProductName</key>
            <string>iMac19,1</string>
            <key>SystemSerialNumber</key>
            <string>W00000000001</string>
            <key>SystemUUID</key>
            <string>00000000-0000-0000-0000-000000000000</string>
        </dict>
        <key>UpdateDataHub</key>
        <true/>
        <key>UpdateNVRAM</key>
        <true/>
        <key>UpdateSMBIOS</key>
        <true/>
        <key>UpdateSMBIOSMode</key>
        <string>Create</string>
        <key>UseRawUuidEncoding</key>
        <false/>
    </dict>
    
    <key>UEFI</key>
    <dict>
        <key>APFS</key>
        <dict>
            <key>EnableJumpstart</key>
            <true/>
            <key>GlobalConnect</key>
            <false/>
            <key>HideVerbose</key>
            <true/>
            <key>JumpstartHotPlug</key>
            <false/>
            <key>MinDate</key>
            <integer>0</integer>
            <key>MinVersion</key>
            <integer>0</integer>
        </dict>
        <key>AppleInput</key>
        <dict>
            <key>AppleEvent</key>
            <string>Builtin</string>
            <key>CustomDelays</key>
            <false/>
            <key>GraphicsInputMirroring</key>
            <true/>
            <key>KeyInitialDelay</key>
            <integer>50</integer>
            <key>KeySubsequentDelay</key>
            <integer>5</integer>
            <key>KeySupport</key>
            <true/>
        </dict>
        <key>Audio</key>
        <dict>
            <key>AudioCodec</key>
            <integer>0</integer>
            <key>AudioDevice</key>
            <string></string>
            <key>AudioOutMask</key>
            <integer>1</integer>
            <key>AudioSupport</key>
            <false/>
            <key>DisconnectHda</key>
            <false/>
            <key>MaximumGain</key>
            <integer>-15</integer>
            <key>PlayChime</key>
            <string>Auto</string>
            <key>ResetTrafficClass</key>
            <false/>
            <key>SetupDelay</key>
            <integer>0</integer>
        </dict>
        <key>ConnectDrivers</key>
        <true/>
        <key>Drivers</key>
        <array>
            <dict>
                <key>Arguments</key>
                <string></string>
                <key>Comment</key>
                <string></string>
                <key>Enabled</key>
                <true/>
                <key>LoadEarly</key>
                <false/>
                <key>Path</key>
                <string>OpenRuntime.efi</string>
            </dict>
            <dict>
                <key>Arguments</key>
                <string></string>
                <key>Comment</key>
                <string>HFS+ Driver</string>
                <key>Enabled</key>
                <true/>
                <key>LoadEarly</key>
                <false/>
                <key>Path</key>
                <string>HfsPlus.efi</string>
            </dict>
        </array>
        <key>Input</key>
        <dict>
            <key>KeyFiltering</key>
            <false/>
            <key>KeyForgetThreshold</key>
            <integer>5</integer>
            <key>KeySupport</key>
            <true/>
            <key>KeySupportMode</key>
            <string>Auto</string>
            <key>KeySwap</key>
            <false/>
            <key>PointerSupport</key>
            <false/>
            <key>TimerResolution</key>
            <integer>50000</integer>
        </dict>
        <key>Output</key>
        <dict>
            <key>ClearScreenOnModeSwitch</key>
            <false/>
            <key>ConsoleMode</key>
            <string></string>
            <key>DirectGopRendering</key>
            <false/>
            <key>IgnoreTextInGraphics</key>
            <false/>
            <key>ProvideConsoleGop</key>
            <true/>
            <key>ReconnectOnResChange</key>
            <false/>
            <key>ReplaceTabWithSpace</key>
            <false/>
            <key>Resolution</key>
            <string>Max</string>
            <key>SanitiseClearScreen</key>
            <false/>
            <key>TextRenderer</key>
            <string>BuiltinGraphics</string>
            <key>UgaPassThrough</key>
            <false/>
        </dict>
        <key>ProtocolOverrides</key>
        <dict>
            <key>AppleAudio</key>
            <false/>
            <key>AppleBootPolicy</key>
            <false/>
            <key>AppleDebugLog</key>
            <false/>
            <key>AppleFramebufferInfo</key>
            <false/>
            <key>AppleImageConversion</key>
            <false/>
            <key>AppleKeyMap</key>
            <false/>
            <key>AppleRtcRam</key>
            <false/>
            <key>AppleSmcIo</key>
            <false/>
            <key>AppleUserInterfaceTheme</key>
            <false/>
            <key>DataHub</key>
            <false/>
            <key>DeviceProperties</key>
            <false/>
            <key>FirmwareVolume</key>
            <true/>
            <key>HashServices</key>
            <false/>
            <key>OSInfo</key>
            <false/>
            <key>UnicodeCollation</key>
            <false/>
        </dict>
        <key>Quirks</key>
        <dict>
            <key>ActivateHpetSupport</key>
            <false/>
            <key>EnableVectorAcceleration</key>
            <true/>
            <key>ExitBootServicesDelay</key>
            <integer>0</integer>
            <key>ForceOcWriteFlash</key>
            <false/>
            <key>ForgeUefiSupport</key>
            <false/>
            <key>IgnoreInvalidFlexRatio</key>
            <false/>
            <key>ReleaseUsbOwnership</key>
            <false/>
            <key>RequestBootVarRouting</key>
            <true/>
            <key>TscSyncTimeout</key>
            <integer>0</integer>
            <key>UnblockFsConnect</key>
            <false/>
        </dict>
        <key>ReservedMemory</key>
        <array/>
    </dict>
</dict>
</plist>
"""
        
        configContent = template
        formattedConfigContent = formatXML(template)
        
        // Parse the template for tree view
        if let data = template.data(using: .utf8),
           let plistData = parsePlist(data) {
            configData = plistData
        } else {
            configData = [:]
        }
        
        filePath = ""
        isEditing = true
        validationErrors.removeAll()
        searchText = ""
        
        // Auto-expand main sections
        let mainSections = ["#WARNING - 1", "ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI", "DeviceProperties"]
        expandedSections = Set(mainSections)
    }
    
    private func loadSampleConfig() {
        // Load the sample config you provided
        let sampleConfig = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>#WARNING - 1</key>
    <string>This is just a sample. Do NOT try loading it.</string>
    <key>#WARNING - 2</key>
    <string>Ensure you understand EVERY field before booting.</string>
    <key>#WARNING - 3</key>
    <string>In most cases recommended to use Sample.plist</string>
    <key>#WARNING - 4</key>
    <string>Use SampleCustom.plist only for special cases.</string>
    <key>ACPI</key>
    <dict>
        <key>Add</key>
        <array>
            <dict>
                <key>Comment</key>
                <string>My custom DSDT</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>DSDT.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>My custom SSDT</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-1.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-ALS0.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-AWAC-DISABLE.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-BRG0.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-EC-USBX.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-EC.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-EHCx-DISABLE.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-IMEI.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-PLUG.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-PMC.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-PNLF.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-RTC0-RANGE.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-RTC0.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-SBUS-MCHC.aml</string>
            </dict>
            <dict>
                <key>Comment</key>
                <string>Read the comment in dsl sample</string>
                <key>Enabled</key>
                <false/>
                <key>Path</key>
                <string>SSDT-UNC.aml</string>
            </dict>
        </array>
        <key>Delete</key>
        <array>
            <dict>
                <key>All</key>
                <false/>
                <key>Comment</key>
                <string>Delete CpuPm</string>
                <key>Enabled</key>
                <false/>
                <key>OemTableId</key>
                <data>Q3B1UG0AAAA=</data>
                <key>TableLength</key>
                <integer>0</integer>
                <key>TableSignature</key>
                <data>U1NEVA==</data>
            </dict>
            <dict>
                <key>All</key>
                <false/>
                <key>Comment</key>
                <string>Delete Cpu0Ist</string>
                <key>Enabled</key>
                <false/>
                <key>OemTableId</key>
                <data>Q3B1MElzdAA=</data>
                <key>TableLength</key>
                <integer>0</integer>
                <key>TableSignature</key>
                <data>U1NEVA==</data>
            </dict>
        </array>
        <key>Patch</key>
        <array>
            <dict>
                <key>Base</key>
                <string></string>
                <key>BaseSkip</key>
                <integer>0</integer>
                <key>Comment</key>
                <string>Replace one byte sequence with another</string>
                <key>Count</key>
                <integer>0</integer>
                <key>Enabled</key>
                <false/>
                <key>Find</key>
                <data>ESIzRA==</data>
                <key>Limit</key>
                <integer>0</integer>
                <key>Mask</key>
                <data></data>
                <key>OemTableId</key>
                <data></data>
                <key>Replace</key>
                <data>RDMiEQ==</data>
                <key>ReplaceMask</key>
                <data></data>
                <key>Skip</key>
                <integer>0</integer>
                <key>TableLength</key>
                <integer>0</integer>
                <key>TableSignature</key>
                <data></data>
            </dict>
            <dict>
                <key>Base</key>
                <string>\_SB.PCI0.LPCB.HPET</string>
                <key>BaseSkip</key>
                <integer>0</integer>
                <key>Comment</key>
                <string>HPET _CRS to XCRS</string>
                <key>Count</key>
                <integer>1</integer>
                <key>Enabled</key>
                <false/>
                <key>Find</key>
                <data>X0NSUw==</data>
                <key>Limit</key>
                <integer>0</integer>
                <key>Mask</key>
                <data></data>
                <key>OemTableId</key>
                <data></data>
                <key>Replace</key>
                <data>WENSUw==</data>
                <key>ReplaceMask</key>
                <data></data>
                <key>Skip</key>
                <integer>0</integer>
                <key>TableLength</key>
                <integer>0</integer>
                <key>TableSignature</key>
                <data></data>
            </dict>
            <dict>
                <key>Base</key>
                <string></string>
                <key>BaseSkip</key>
                <integer>0</integer>
                <key>Comment</key>
                <string>RTC 0x70,1,8 to 0x70,1,2</string>
                <key>Count</key>
                <integer>1</integer>
                <key>Enabled</key>
                <false/>
                <key>Find</key>
                <data>AXAAcAABCA==</data>
                <key>Limit</key>
                <integer>0</integer>
                <key>Mask</key>
                <data></data>
                <key>OemTableId</key>
                <data></data>
                <key>Replace</key>
                <data>AXAAcAABAg==</data>
                <key>ReplaceMask</key>
                <data></data>
                <key>Skip</key>
                <integer>0</integer>
                <key>TableLength</key>
                <integer>0</integer>
                <key>TableSignature</key>
                <data>RFNEVA==</data>
            </dict>
        </array>
        <key>Quirks</key>
        <dict>
            <key>FadtEnableReset</key>
            <false/>
            <key>NormalizeHeaders</key>
            <false/>
            <key>RebaseRegions</key>
            <false/>
            <key>ResetHwSig</key>
            <false/>
            <key>ResetLogoStatus</key>
            <true/>
            <key>SyncTableIds</key>
            <false/>
        </dict>
    </dict>
    <key>Booter</key>
    <dict>
        <key>MmioWhitelist</key>
        <array>
            <dict>
                <key>Address</key>
                <integer>4275159040</integer>
                <key>Comment</key>
                <string>Haswell: SB_RCBA is a 0x4 page memory region, containing SPI_BASE at 0x3800 (SPI_BASE_ADDRESS)</string>
                <key>Enabled</key>
                <false/>
            </dict>
            <dict>
                <key>Address</key>
                <integer>4278190080</integer>
                <key>Comment</key>
                <string>Generic: PCI root is a 0x1000 page memory region used by some types of firmware</string>
                <key>Enabled</key>
                <false/>
            </dict>
        </array>
        <key>Patch</key>
        <array>
            <dict>
                <key>Arch</key>
                <string>Any</string>
                <key>Comment</key>
                <string>macOS to hacOS</string>
                <key>Count</key>
                <integer>1</integer>
                <key>Enabled</key>
                <false/>
                <key>Find</key>
                <data>bWFjT1M=</data>
                <key>Identifier</key>
                <string>Apple</string>
                <key>Limit</key>
                <integer>0</integer>
                <key>Mask</key>
                <data></data>
                <key>Replace</key>
                <data>aGFjT1M=</data>
                <key>ReplaceMask</key>
                <data></data>
                <key>Skip</key>
                <integer>0</integer>
            </dict>
        </array>
        <key>Quirks</key>
        <dict>
            <key>AllowRelocationBlock</key>
            <false/>
            <key>AvoidRuntimeDefrag</key>
            <true/>
            <key>ClearTaskSwitchBit</key>
            <false/>
            <key>DevirtualiseMmio</key>
            <false/>
            <key>DisableSingleUser</key>
            <false/>
            <key>DisableVariableWrite</key>
            <false/>
            <key>DiscardHibernateMap</key>
            <false/>
            <key>EnableSafeModeSlide</key>
            <true/>
            <key>EnableWriteUnprotector</key>
            <true/>
            <key>FixupAppleEfiImages</key>
            <true/>
            <key>ForceBooterSignature</key>
            <false/>
            <key>ForceExitBootServices</key>
            <false/>
            <key>ProtectMemoryRegions</key>
            <false/>
            <key>ProtectSecureBoot</key>
            <false/>
            <key>ProtectUefiServices</key>
            <false/>
            <key>ProvideCustomSlide</key>
            <true/>
            <key>ProvideMaxSlide</key>
            <integer>0</integer>
            <key>RebuildAppleMemoryMap</key>
            <false/>
            <key>ResizeAppleGpuBars</key>
            <integer>-1</integer>
            <key>SetupVirtualMap</key>
            <true/>
            <key>SignalAppleOS</key>
            <false/>
            <key>SyncRuntimePermissions</key>
            <false/>
        </dict>
    </dict>
    <key>DeviceProperties</key>
    <dict>
        <key>Add</key>
        <dict>
            <key>PciRoot(0x0)/Pci(0x1b,0x0)</key>
            <dict>
                <key>layout-id</key>
                <data>AQAAAA==</data>
            </dict>
        </dict>
        <key>Delete</key>
        <dict/>
    </dict>
    <key>Kernel</key>
    <dict>
        <key>Add</key>
        <array>
            <dict>
                <key>Arch</key>
                <string>Any</string>
                <key>BundlePath</key>
                <string>Lilu.kext</string>
                <key>Comment</key>
                <string>Patch engine</string>
                <key>Enabled</key>
                <true/>
                <key>ExecutablePath</key>
                <string>Contents/MacOS/Lilu</string>
                <key>MaxKernel</key>
                <string></string>
                <key>MinKernel</key>
                <string>8.0.0</string>
                <key>PlistPath</key>
                <string>Contents/Info.plist</string>
            </dict>
            <dict>
                <key>Arch</key>
                <string>Any</string>
                <key>BundlePath</key>
                <string>VirtualSMC.kext</string>
                <key>Comment</key>
                <string>SMC emulator</string>
                <key>Enabled</key>
                <true/>
                <key>ExecutablePath</key>
                <string>Contents/MacOS/VirtualSMC</string>
                <key>MaxKernel</key>
                <string></string>
                <key>MinKernel</key>
                <string>8.0.0</string>
                <key>PlistPath</key>
                <string>Contents/Info.plist</string>
            </dict>
            <dict>
                <key>Arch</key>
                <string>x86_64</string>
                <key>BundlePath</key>
                <string>WhateverGreen.kext</string>
                <key>Comment</key>
                <string>Video patches</string>
                <key>Enabled</key>
                <true/>
                <key>ExecutablePath</key>
                <string>Contents/MacOS/WhateverGreen</string>
                <key>MaxKernel</key>
                <string></string>
                <key>MinKernel</key>
                <string>10.0.0</string>
                <key>PlistPath</key>
                <string>Contents/Info.plist</string>
            </dict>
            <dict>
                <key>Arch</key>
                <string>Any</string>
                <key>BundlePath</key>
                <string>AppleALC.kext</string>
                <key>Comment</key>
                <string>Audio patches</string>
                <key>Enabled</key>
                <true/>
                <key>ExecutablePath</key>
                <string>Contents/MacOS/AppleALC</string>
                <key>MaxKernel</key>
                <string></string>
                <key>MinKernel</key>
                <string>8.0.0</string>
                <key>PlistPath</key>
                <string>Contents/Info.plist</string>
            </dict>
        </array>
        <key>Block</key>
        <array/>
        <key>Emulate</key>
        <dict>
            <key>DummyPowerManagement</key>
            <false/>
        </dict>
        <key>Force</key>
        <array/>
        <key>Patch</key>
        <array/>
        <key>Quirks</key>
        <dict>
            <key>AppleCpuPmCfgLock</key>
            <false/>
            <key>AppleXcpmCfgLock</key>
            <false/>
            <key>AppleXcpmExtraMsrs</key>
            <false/>
            <key>AppleXcpmForceBoost</key>
            <false/>
            <key>CustomSMBIOSGuid</key>
            <false/>
            <key>DisableIoMapper</key>
            <false/>
            <key>DisableRtcChecksum</key>
            <false/>
            <key>ExternalDiskIcons</key>
            <false/>
            <key>IncreasePciBarSize</key>
            <false/>
            <key>LapicKernelPanic</key>
            <false/>
            <key>PanicNoKextDump</key>
            <false/>
            <key>PowerTimeoutKernelPanic</key>
            <false/>
            <key>ThirdPartyDrives</key>
            <false/>
            <key>XhciPortLimit</key>
            <false/>
        </dict>
        <key>Scheme</key>
        <dict>
            <key>FuzzyMatch</key>
            <true/>
        </dict>
    </dict>
    <key>Misc</key>
    <dict>
        <key>Boot</key>
        <dict>
            <key>ConsoleAttributes</key>
            <integer>0</integer>
            <key>HibernateMode</key>
            <string>None</string>
            <key>HideAuxiliary</key>
            <true/>
            <key>PickerAttributes</key>
            <integer>17</integer>
            <key>PickerAudioAssist</key>
            <false/>
            <key>PollAppleHotKeys</key>
            <false/>
            <key>ShowPicker</key>
            <true/>
            <key>Timeout</key>
            <integer>5</integer>
        </dict>
        <key>Debug</key>
        <dict>
            <key>AppleDebug</key>
            <false/>
            <key>ApplePanic</key>
            <false/>
            <key>DisableWatchDog</key>
            <false/>
            <key>DisplayDelay</key>
            <integer>0</integer>
            <key>DisplayLevel</key>
            <integer>2147483650</integer>
            <key>Target</key>
            <integer>3</integer>
        </dict>
        <key>Entries</key>
        <array/>
        <key>Security</key>
        <dict>
            <key>AllowSetDefault</key>
            <false/>
            <key>ApECID</key>
            <integer>0</integer>
            <key>AuthRestart</key>
            <false/>
            <key>BlacklistAppleUpdate</key>
            <true/>
            <key>DmgLoading</key>
            <string>Signed</string>
            <key>EnablePassword</key>
            <false/>
            <key>ExposeSensitiveData</key>
            <integer>6</integer>
            <key>HaltLevel</key>
            <integer>2147483648</integer>
            <key>ScanPolicy</key>
            <integer>17760515</integer>
            <key>SecureBootModel</key>
            <string>Default</string>
            <key>Vault</key>
            <string>Secure</string>
        </dict>
        <key>Tools</key>
        <array/>
    </dict>
    <key>NVRAM</key>
    <dict>
        <key>Add</key>
        <dict>
            <key>4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14</key>
            <dict>
                <key>DefaultBackgroundColor</key>
                <data>AAAAAA==</data>
            </dict>
            <key>7C436110-AB2A-4BBB-A880-FE41995C9F82</key>
            <dict>
                <key>boot-args</key>
                <string>-v keepsyms=1</string>
                <key>csr-active-config</key>
                <data>AAAAAA==</data>
                <key>prev-lang:kbd</key>
                <data>cnUtUlU6MjUy</data>
            </dict>
        </dict>
        <key>Delete</key>
        <dict/>
        <key>WriteFlash</key>
        <true/>
    </dict>
    <key>PlatformInfo</key>
    <dict>
        <key>Automatic</key>
        <true/>
        <key>CustomMemory</key>
        <false/>
        <key>Generic</key>
        <dict>
            <key>AdviseFeatures</key>
            <false/>
            <key>MLB</key>
            <string>M0000000000000001</string>
            <key>MaxBIOSVersion</key>
            <false/>
            <key>ProcessorType</key>
            <integer>0</integer>
            <key>ROM</key>
            <data>ESIzRFVm</data>
            <key>SpoofVendor</key>
            <true/>
            <key>SystemMemoryStatus</key>
            <string>Auto</string>
            <key>SystemProductName</key>
            <string>iMac19,1</string>
            <key>SystemSerialNumber</key>
            <string>W00000000001</string>
            <key>SystemUUID</key>
            <string>00000000-0000-0000-0000-000000000000</string>
        </dict>
        <key>UpdateDataHub</key>
        <true/>
        <key>UpdateNVRAM</key>
        <true/>
        <key>UpdateSMBIOS</key>
        <true/>
        <key>UpdateSMBIOSMode</key>
        <string>Create</string>
    </dict>
    <key>UEFI</key>
    <dict>
        <key>ConnectDrivers</key>
        <true/>
        <key>Drivers</key>
        <array>
            <dict>
                <key>Arguments</key>
                <string></string>
                <key>Comment</key>
                <string></string>
                <key>Enabled</key>
                <true/>
                <key>LoadEarly</key>
                <false/>
                <key>Path</key>
                <string>OpenRuntime.efi</string>
            </dict>
            <dict>
                <key>Arguments</key>
                <string></string>
                <key>Comment</key>
                <string>HFS+ Driver</string>
                <key>Enabled</key>
                <true/>
                <key>LoadEarly</key>
                <false/>
                <key>Path</key>
                <string>HfsPlus.efi</string>
            </dict>
        </array>
        <key>Input</key>
        <dict>
            <key>KeySupport</key>
            <true/>
        </dict>
        <key>Output</key>
        <dict>
            <key>ProvideConsoleGop</key>
            <true/>
            <key>Resolution</key>
            <string>Max</string>
        </dict>
        <key>Quirks</key>
        <dict>
            <key>RequestBootVarRouting</key>
            <true/>
        </dict>
    </dict>
</dict>
</plist>
"""
        
        configContent = sampleConfig
        formattedConfigContent = formatXML(sampleConfig)
        
        // Parse the sample for tree view
        if let data = sampleConfig.data(using: .utf8),
           let plistData = parsePlist(data) {
            configData = plistData
        } else {
            configData = [:]
        }
        
        filePath = "Sample.plist"
        isEditing = false
        validationErrors.removeAll()
        searchText = ""
        
        // Auto-expand main sections
        let mainSections = ["#WARNING - 1", "ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI", "DeviceProperties"]
        expandedSections = Set(mainSections)
        
        showSuccess("Sample OpenCore config loaded")
    }
    
    private func openEFIConfig() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Mount EFI partition and find config.plist
            let mountResult = ShellHelper.runCommand("""
            diskutil list | grep -E 'EFI.*EFI' | head -1 | awk '{print $NF}'
            """)
            
            if mountResult.success && !mountResult.output.isEmpty {
                let efiDisk = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let mountCmd = ShellHelper.runCommand("diskutil mount /dev/\(efiDisk)")
                
                if mountCmd.success {
                    let findCmd = ShellHelper.runCommand("""
                    find /Volumes/EFI -name "config.plist" 2>/dev/null | head -1
                    """)
                    
                    if findCmd.success && !findCmd.output.isEmpty {
                        let configPath = findCmd.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        DispatchQueue.main.async {
                            self.loadConfig(path: configPath)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showError("No config.plist found in EFI partition")
                        }
                    }
                    
                    _ = ShellHelper.runCommand("diskutil unmount /dev/\(efiDisk)")
                } else {
                    DispatchQueue.main.async {
                        self.showError("Failed to mount EFI partition")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.showError("No EFI partition found")
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func validateConfig() {
        validationErrors.removeAll()
        
        if configContent.isEmpty {
            validationErrors.append("Config is empty")
            return
        }
        
        // Basic XML validation
        if !configContent.contains("<?xml") {
            validationErrors.append("Missing XML declaration")
        }
        
        if !configContent.contains("DOCTYPE plist") {
            validationErrors.append("Missing plist DOCTYPE")
        }
        
        if !configContent.contains("<plist version=\"1.0\">") {
            validationErrors.append("Missing or incorrect plist version")
        }
        
        // Check for required OpenCore sections
        let requiredSections = ["ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
        for section in requiredSections {
            if !configContent.contains("<key>\(section)</key>") {
                validationErrors.append("Missing required section: \(section)")
            }
        }
        
        // Check for required OpenRuntime.efi driver
        if !configContent.contains("OpenRuntime.efi") {
            validationErrors.append("Missing required driver: OpenRuntime.efi")
        }
        
        if validationErrors.isEmpty {
            showSuccess("Config validation passed - All required sections present")
        }
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
    
    private func showSuccess(_ message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
    
    private func showError(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Supporting Views

struct SampleConfigLoaderView: View {
    @Environment(\.dismiss) var dismiss
    let loadSampleConfig: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Load Sample OpenCore Config")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This will load a sample OpenCore configuration file with example settings for Hackintosh/OpenCore bootloader.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                Label("Includes common kexts: Lilu, VirtualSMC, WhateverGreen", systemImage: "checkmark.circle")
                Label("Example ACPI patches and SSDTs", systemImage: "checkmark.circle")
                Label("Sample NVRAM settings", systemImage: "checkmark.circle")
                Label("Example PlatformInfo (iMac19,1)", systemImage: "checkmark.circle")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Text("⚠️ Warning: This is a sample configuration for reference only. Do not use it directly without understanding each setting.")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Load Sample") {
                    loadSampleConfig()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

struct ConfigEditorView: View {
    @Binding var content: String
    @Binding var isEditing: Bool
    let searchText: String
    let filteredContent: String
    
    var body: some View {
        if isEditing {
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        .padding()
                )
        } else {
            ScrollView {
                Text(filteredContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.gray.opacity(0.05))
        }
    }
}

struct ConfigTreeView: View {
    let data: [String: Any]
    @Binding var expandedSections: Set<String>
    let searchText: String
    let depth: Int
    
    var body: some View {
        ForEach(Array(data.keys.sorted()), id: \.self) { key in
            if let value = data[key] {
                ConfigTreeItem(
                    key: key,
                    value: value,
                    expandedSections: $expandedSections,
                    searchText: searchText,
                    depth: depth
                )
            }
        }
    }
}

struct ConfigTreeItem: View {
    let key: String
    let value: Any
    @Binding var expandedSections: Set<String>
    let searchText: String
    let depth: Int
    
    var isExpanded: Bool {
        expandedSections.contains(key)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Indentation
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1)
                        .padding(.leading, 4)
                }
                
                // Expand/collapse button for dictionaries and arrays
                if isDictionary || isArray {
                    Button(action: {
                        if isExpanded {
                            expandedSections.remove(key)
                        } else {
                            expandedSections.insert(key)
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Spacer()
                        .frame(width: 20)
                }
                
                // Key with special styling for warning comments
                Text(key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(key.hasPrefix("#WARNING") ? .bold : .semibold)
                    .foregroundColor(key.hasPrefix("#WARNING") ? .orange : .blue)
                
                // Value
                if !isDictionary && !isArray {
                    Spacer()
                    Text(stringValue)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                key.lowercased().contains(searchText.lowercased()) || 
                stringValue.lowercased().contains(searchText.lowercased()) ?
                Color.yellow.opacity(0.2) : Color.clear
            )
            
            // Nested content
            if isExpanded {
                if let dict = value as? [String: Any] {
                    ConfigTreeView(
                        data: dict,
                        expandedSections: $expandedSections,
                        searchText: searchText,
                        depth: depth + 1
                    )
                    .padding(.leading, 20)
                } else if let array = value as? [Any] {
                    ForEach(0..<array.count, id: \.self) { index in
                        HStack {
                            ForEach(0..<(depth + 1), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 1)
                                    .padding(.leading, 4)
                            }
                            
                            Text("[\(index)]")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            if let item = array[index] as? [String: Any] {
                                Text("Dictionary (\(item.count) items)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(array[index])")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
    
    private var isDictionary: Bool {
        value is [String: Any]
    }
    
    private var isArray: Bool {
        value is [Any]
    }
    
    private var stringValue: String {
        if let boolValue = value as? Bool {
            return boolValue ? "<true/>" : "<false/>"
        } else if let intValue = value as? Int {
            return "<integer>\(intValue)</integer>"
        } else if let stringValue = value as? String {
            return "<string>\(stringValue)</string>"
        } else if let dataValue = value as? Data {
            return "<data>\(dataValue.count) bytes</data>"
        } else if let dateValue = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return "<date>\(formatter.string(from: dateValue))</date>"
        } else if isDictionary {
            let dict = value as! [String: Any]
            return "Dictionary (\(dict.count) items)"
        } else if isArray {
            let arr = value as! [Any]
            return "Array (\(arr.count) items)"
        }
        return "\(value)"
    }
}

struct EmptyConfigView: View {
    let importConfig: () -> Void
    let createNewConfig: () -> Void
    let openEFIConfig: () -> Void
    let loadSampleConfig: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "platter.2.filled.ipad")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))
            
            VStack(spacing: 10) {
                Text("No OpenCore config loaded")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Import a config.plist file or create a new one to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 20) {
                ActionButton(
                    icon: "square.and.arrow.down",
                    title: "Import",
                    color: .blue,
                    action: importConfig
                )
                
                ActionButton(
                    icon: "plus.square",
                    title: "New Config",
                    color: .green,
                    action: createNewConfig
                )
                
                ActionButton(
                    icon: "externaldrive",
                    title: "Open from EFI",
                    color: .orange,
                    action: openEFIConfig
                )
                
                ActionButton(
                    icon: "doc.text.magnifyingglass",
                    title: "Load Sample",
                    color: .purple,
                    action: loadSampleConfig
                )
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 100, height: 100)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

struct ValidationErrorView: View {
    @Binding var errors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Validation Issues")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    errors.removeAll()
                }
                .buttonStyle(.borderless)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(errors, id: \.self) { error in
                        HStack(alignment: .top) {
                            Image(systemName: "smallcircle.filled.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatusBarView: View {
    let isLoading: Bool
    let isEditing: Bool
    let configContent: String
    let filePath: String
    let showRawXML: Bool
    
    var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing...")
                    .font(.caption)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
        } else {
            HStack {
                if !configContent.isEmpty {
                    Image(systemName: isEditing ? "pencil" : "eye")
                        .foregroundColor(isEditing ? .blue : .gray)
                    Text(isEditing ? "Editing Mode" : "View Mode")
                        .font(.caption)
                    
                    Divider()
                        .frame(height: 12)
                    
                    let lines = configContent.components(separatedBy: "\n").count
                    let words = configContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                    Text("\(lines) lines, \(words) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .frame(height: 12)
                    
                    Text(showRawXML ? "Raw XML" : "Tree View")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if !filePath.isEmpty {
                    Text("File: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
    }
}

// MARK: - OpenCore Config Document
struct OpenCoreConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.propertyList] }
    
    var content: String
    
    init(content: String = "") {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview
struct OpenCoreConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        OpenCoreConfigEditorView()
    }
}