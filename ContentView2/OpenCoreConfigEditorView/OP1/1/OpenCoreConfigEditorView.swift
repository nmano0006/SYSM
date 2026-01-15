// MARK: - Views/OpenCoreConfigEditorView.swift
import SwiftUI
import UniformTypeIdentifiers

struct OpenCoreConfigEditorView: View {
    @State private var configContent = ""
    @State private var filePath = ""
    @State private var isEditing = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "OpenCore Config"
    @State private var isLoading = false
    @State private var validationErrors: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "platter.2.filled.ipad")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("OpenCore Config.plist Editor")
                    .font(.headline)
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Import") {
                        importConfig()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Export") {
                        exportConfig()
                    }
                    .buttonStyle(.bordered)
                    .disabled(configContent.isEmpty)
                    
                    Button("Validate") {
                        validateConfig()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                    
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveConfig()
                        } else {
                            isEditing = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isEditing && filePath.isEmpty)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            
            if !filePath.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(filePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Validation Issues")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            validationErrors.removeAll()
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationErrors, id: \.self) { error in
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
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Editor
            if isEditing {
                TextEditor(text: $configContent)
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
            } else if !configContent.isEmpty {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(configContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            } else {
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
                        Button(action: importConfig) {
                            VStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title)
                                Text("Import")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(15)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: createNewConfig) {
                            VStack {
                                Image(systemName: "plus.square")
                                    .font(.title)
                                Text("New Config")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(15)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: openEFIConfig) {
                            VStack {
                                Image(systemName: "externaldrive")
                                    .font(.title)
                                Text("Open from EFI")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(15)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            // Status bar
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
                    }
                    Spacer()
                    
                    if !filePath.isEmpty {
                        Text("Loaded: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
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
            allowedContentTypes: [UTType.propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadConfig(url: url)
                }
            case .failure(let error):
                showError("Import failed: \(error.localizedDescription)")
            }
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: OpenCoreConfigDocument(content: configContent),
            contentType: UTType.propertyList,
            defaultFilename: "config.plist"
        ) { result in
            switch result {
            case .success:
                showSuccess("Config exported successfully")
            case .failure(let error):
                showError("Export failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func importConfig() {
        showImportPicker = true
    }
    
    private func exportConfig() {
        showExportPicker = true
    }
    
    private func loadConfig(url: URL) {
        isLoading = true
        do {
            let data = try Data(contentsOf: url)
            if let content = String(data: data, encoding: .utf8) {
                configContent = content
                filePath = url.path
                isEditing = false
                validationErrors.removeAll()
                showSuccess("Config loaded successfully")
            } else {
                showError("Unable to read config file")
            }
        } catch {
            showError("Failed to load config: \(error.localizedDescription)")
        }
        isLoading = false
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
        do {
            if let data = configContent.data(using: .utf8) {
                try data.write(to: URL(fileURLWithPath: filePath))
                isEditing = false
                showSuccess("Config saved successfully")
            } else {
                showError("Unable to encode config data")
            }
        } catch {
            showError("Failed to save config: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    private func createNewConfig() {
        configContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- OpenCore Configuration -->
    <key>ACPI</key>
    <dict>
        <key>Add</key>
        <array/>
        <key>Delete</key>
        <array/>
        <key>Patch</key>
        <array/>
    </dict>
    
    <key>Booter</key>
    <dict>
        <key>MmioWhitelist</key>
        <array/>
        <key>Patch</key>
        <array/>
    </dict>
    
    <key>DeviceProperties</key>
    <dict/>
    
    <key>Kernel</key>
    <dict>
        <key>Add</key>
        <array/>
        <key>Block</key>
        <array/>
        <key>Patch</key>
        <array/>
    </dict>
    
    <key>Misc</key>
    <dict>
        <key>Boot</key>
        <dict>
            <key>Timeout</key>
            <integer>5</integer>
            <key>ShowPicker</key>
            <true/>
        </dict>
        <key>Security</key>
        <dict>
            <key>AllowNvramReset</key>
            <true/>
            <key>SecureBootModel</key>
            <string>Default</string>
        </dict>
    </dict>
    
    <key>NVRAM</key>
    <dict>
        <key>Add</key>
        <dict/>
        <key>Delete</key>
        <dict/>
    </dict>
    
    <key>PlatformInfo</key>
    <dict>
        <key>Generic</key>
        <dict>
            <key>SystemProductName</key>
            <string>iMacPro1,1</string>
        </dict>
    </dict>
    
    <key>UEFI</key>
    <dict>
        <key>Audio</key>
        <dict>
            <key>ResetTrafficClass</key>
            <false/>
        </dict>
        <key>Input</key>
        <dict>
            <key>KeySupport</key>
            <false/>
        </dict>
        <key>ProtocolOverrides</key>
        <dict>
            <key>ConsoleMode</key>
            <string>Max</string>
        </dict>
    </dict>
</dict>
</plist>
"""
        filePath = ""
        isEditing = true
        validationErrors.removeAll()
    }
    
    private func openEFIConfig() {
        isLoading = true
        
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
                    loadConfig(path: configPath)
                } else {
                    showError("No config.plist found in EFI partition")
                }
                
                _ = ShellHelper.runCommand("diskutil unmount /dev/\(efiDisk)")
            } else {
                showError("Failed to mount EFI partition")
            }
        } else {
            showError("No EFI partition found")
        }
        
        isLoading = false
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
        
        // Check for common issues
        if configContent.contains("MacBook") && !configContent.contains("SystemProductName") {
            validationErrors.append("SystemProductName should be set in PlatformInfo")
        }
        
        if validationErrors.isEmpty {
            showSuccess("Config validation passed")
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