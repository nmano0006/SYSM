// MARK: - Views/OpenCoreConfigEditorView.swift
import SwiftUI
import UniformTypeIdentifiers

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
                        searchText: $searchText,
                        filteredContent: filteredContent
                    )
                } else {
                    // Tree/Formatted View
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let dict = configData as? [String: Any] {
                                ConfigTreeView(
                                    data: dict,
                                    expandedSections: $expandedSections,
                                    searchText: $searchText,
                                    depth: 0
                                )
                            } else {
                                Text("Unable to parse config data")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                        }
                    }
                    .background(Color.gray.opacity(0.05))
                }
            } else {
                // Empty state
                EmptyConfigView(
                    importConfig: importConfig,
                    createNewConfig: createNewConfig,
                    openEFIConfig: openEFIConfig
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
            defaultFilename: "config-\(Date().formatted(.iso8601.dateSeparator(.dash))).plist"
        ) { result in
            handleExportResult(result)
        }
    }
    
    // MARK: - Helper Views
    
    struct ConfigEditorView: View {
        @Binding var content: String
        @Binding var isEditing: Bool
        @Binding var searchText: String
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
                    Text(AttributedString(filteredContent))
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
                    
                    // Key
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
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
                return "<date>\(dateValue)</date>"
            } else if isDictionary {
                return "Dictionary (\((value as? [String: Any])?.count ?? 0) items)"
            } else if isArray {
                return "Array (\((value as? [Any])?.count ?? 0) items)"
            }
            return "\(value)"
        }
    }
    
    struct EmptyConfigView: View {
        let importConfig: () -> Void
        let createNewConfig: () -> Void
        let openEFIConfig: () -> Void
        
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
                }
                .frame(width: 120, height: 120)
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
    
    // MARK: - Helper Functions
    
    private func highlightSearch(in text: String) -> String {
        if searchText.isEmpty { return text }
        
        let attributedString = NSMutableAttributedString(string: text)
        let range = (text as NSString).range(of: searchText, options: .caseInsensitive)
        if range.location != NSNotFound {
            attributedString.addAttribute(.backgroundColor, value: UIColor.yellow, range: range)
        }
        return attributedString.string
    }
    
    private func formatXML(_ xml: String) -> String {
        // Simple XML formatting - you might want to use a proper XML parser here
        var formatted = ""
        var indentLevel = 0
        let lines = xml.components(separatedBy: ">")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("</") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            let indent = String(repeating: "  ", count: indentLevel)
            formatted += "\(indent)\(trimmed)>\n"
            
            if !trimmed.hasPrefix("</") && !trimmed.hasPrefix("<?") && !trimmed.hasPrefix("<!") && !trimmed.contains("/>") {
                if !trimmed.hasPrefix("<key>") && !trimmed.hasPrefix("<string>") && !trimmed.hasPrefix("<integer>") && !trimmed.hasPrefix("<true/>") && !trimmed.hasPrefix("<false/>") {
                    indentLevel += 1
                }
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
        do {
            let data = try Data(contentsOf: url)
            
            // Try to parse as XML first
            if let xmlString = String(data: data, encoding: .utf8) {
                configContent = xmlString
                formattedConfigContent = formatXML(xmlString)
                
                // Try to parse as plist for tree view
                if let plistData = parsePlist(data) {
                    configData = plistData
                }
                
                filePath = url.path
                isEditing = false
                validationErrors.removeAll()
                searchText = ""
                expandedSections = ["ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
                
                showSuccess("Config loaded successfully")
            } else {
                showError("Unable to read config file - invalid encoding")
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
                
                // Reload to refresh parsed data
                loadConfig(path: filePath)
                
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
        let template = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
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
        
        configContent = template
        formattedConfigContent = formatXML(template)
        
        // Parse the template for tree view
        if let data = template.data(using: .utf8),
           let plistData = parsePlist(data) {
            configData = plistData
        }
        
        filePath = ""
        isEditing = true
        validationErrors.removeAll()
        searchText = ""
        expandedSections = ["ACPI", "Booter", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
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