import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Author Information
/*
👨‍💻 Author: Navaratnam Manoranjan
📧 Email: nmano0006@gmail.com
🔧 OpenCore Configurator Editor for System Maintenance Tool
*/

// MARK: - Data Models
struct ConfigEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    var key: String
    var type: String
    var value: String
    var isEnabled: Bool
    var actualValue: AnyHashable?
    var isOpenCoreSpecific: Bool = false
    var parentKey: String?
    var depth: Int = 0
    var isExpandable: Bool = false
    var childrenLoaded: Bool = false
    
    // Add mutable properties for editing
    var editedValue: String = ""
    var isEditing: Bool = false
    
    static func == (lhs: ConfigEntry, rhs: ConfigEntry) -> Bool {
        return lhs.id == rhs.id && lhs.value == rhs.value
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(value)
    }
    
    // Safe wrapper for AnyHashable
    var safeValue: Any? {
        if let dict = actualValue as? [String: AnyHashable] {
            return dict
        } else if let array = actualValue as? [AnyHashable] {
            return array
        } else if let string = actualValue as? String {
            return string
        } else if let bool = actualValue as? Bool {
            return bool
        } else if let int = actualValue as? Int {
            return int
        } else if let double = actualValue as? Double {
            return double
        } else if let data = actualValue as? Data {
            return data
        }
        return nil
    }
}

// MARK: - Helper Views

struct AuthorInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                
                Text("Author")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("Navaratnam Manoranjan")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.leading, 16)
            
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                
                Text("nmano0006@gmail.com")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
            }
            .padding(.leading, 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

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

struct DebugInfoView: View {
    let configData: [String: AnyHashable]
    
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
                                let typeDescription = getTypeDescription(value)
                                Text(typeDescription)
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        if let sectionData = configData[key] {
                            let entryCount = countEntries(in: sectionData)
                            if entryCount > 0 {
                                Text("  \(entryCount) entries")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                            }
                        }
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
    
    private func getTypeDescription(_ value: AnyHashable) -> String {
        let unwrapped = value.base
        if let dict = unwrapped as? [String: AnyHashable] {
            return "Dictionary (\(dict.count))"
        } else if let array = unwrapped as? [AnyHashable] {
            return "Array (\(array.count))"
        } else if unwrapped is String {
            return "String"
        } else if let number = unwrapped as? NSNumber {
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
                return "Boolean"
            }
            return "Number"
        } else if unwrapped is Bool {
            return "Boolean"
        } else if unwrapped is Int {
            return "Integer"
        } else if unwrapped is Double {
            return "Double"
        } else if let data = unwrapped as? Data {
            return "Data (\(data.count) bytes)"
        }
        
        let typeName = String(describing: type(of: unwrapped))
        if typeName.contains("Dictionary") {
            return "Dictionary"
        } else if typeName.contains("Array") {
            return "Array"
        } else if typeName.contains("String") {
            return "String"
        } else if typeName.contains("Boolean") || typeName.contains("Bool") {
            return "Boolean"
        } else if typeName.contains("Number") || typeName.contains("Int") || typeName.contains("Double") {
            return "Number"
        }
        
        return "Unknown"
    }
    
    private func countEntries(in value: AnyHashable) -> Int {
        let unwrapped = value.base
        if let dict = unwrapped as? [String: AnyHashable] {
            return dict.count
        } else if let array = unwrapped as? [AnyHashable] {
            return array.count
        }
        return 0
    }
}

struct RawJSONView: View {
    let jsonText: String
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Raw JSON View")
                    .font(.headline)
                
                Spacer()
                
                Button("Copy") {
                    copyToClipboard(jsonText)
                }
                .buttonStyle(.bordered)
                
                Button("Close") {
                    onClose()
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                Text(jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
        }
        .frame(width: 700, height: 500)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Component Views

struct APFSSettingRow: View {
    let setting: String
    @Binding var isOn: Bool
    let showTextField: Bool
    @Binding var textValue: String
    
    var body: some View {
        HStack {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundColor(isOn ? .green : .gray)
                .frame(width: 20)
            
            Text(setting)
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 120, alignment: .leading)
            
            if showTextField {
                TextField("", text: $textValue)
                    .font(.system(size: 10))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    .disabled(setting == "MinVersion")
            } else {
                Text(isOn ? "true" : "false")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isOn ? .green : .gray)
                    .frame(width: 40)
            }
            
            Spacer()
            
            if !showTextField {
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .scaleEffect(0.6)
                    .labelsHidden()
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
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
            Image(systemName: getSectionIcon(section))
                .font(.system(size: 10))
                .foregroundColor(getSectionColor(section))
                .frame(width: 20)
            
            Text(section)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(width: 100, alignment: .leading)
            
            Text(status)
                .font(.system(size: 9))
                .foregroundColor(getStatusColor(status))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(getStatusBackgroundColor(status))
                .cornerRadius(3)
                .frame(width: 60, alignment: .center)
            
            Text("\(entryCount)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func getSectionIcon(_ section: String) -> String {
        switch section {
        case "APFS": return "externaldrive.fill"
        case "ACPI": return "cpu.fill"
        case "Kernel": return "gear"
        case "Misc": return "ellipsis.circle"
        case "NVRAM": return "memorychip"
        case "PlatformInfo": return "info.circle"
        case "UEFI": return "opticaldiscdrive"
        default: return "folder"
        }
    }
    
    private func getSectionColor(_ section: String) -> Color {
        switch section {
        case "APFS": return .blue
        case "ACPI": return .orange
        case "Kernel": return .purple
        case "Misc": return .gray
        case "NVRAM": return .green
        case "PlatformInfo": return .yellow
        case "UEFI": return .pink
        default: return .secondary
        }
    }
    
    private func getStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active", "available", "configured": return .green
        case "default": return .blue
        case "disabled", "inactive": return .gray
        default: return .secondary
        }
    }
    
    private func getStatusBackgroundColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active", "available", "configured": return .green.opacity(0.1)
        case "default": return .blue.opacity(0.1)
        case "disabled", "inactive": return .gray.opacity(0.1)
        default: return .clear
        }
    }
}

struct QuirkRow: View {
    let quirk: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .labelsHidden()
                .frame(width: 30)
            
            Text(quirk)
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 140, alignment: .leading)
            
            Spacer()
            
            Image(systemName: isOn ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 10))
                .foregroundColor(isOn ? .green : .red)
                .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - Main View

@MainActor
class ConfigViewModel: ObservableObject {
    @Published var configData: [String: AnyHashable] = [:]
    @Published var selectedSection: String = "ACPI"
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var filePath = ""
    @Published var isEditing = false
    @Published var ocVersion = "1.0.6"
    @Published var configTitle = "OpenCore Configurator"
    @Published var configEntries: [ConfigEntry] = []
    @Published var openCoreInfo: OpenCoreInfo?
    @Published var showOpenCoreInfo = true
    @Published var isScanning = false
    @Published var expandedEntries: Set<UUID> = []
    @Published var selectedEntryForDetail: ConfigEntry?
    @Published var showDetailView = false
    @Published var showRawJSON = false
    @Published var rawJSONText = ""
    @Published var showDebugInfo = false
    @Published var showAuthorInfo = true
    
    // Track which entries are being edited
    @Published var editingEntries: Set<UUID> = []
    
    // State for UI components
    @Published var apfsToggleStates: [String: Bool] = [
        "EnableJumpstart": true,
        "GlobalConnect": true,
        "HideVerbose": false,
        "JumpstartHotPlug": false,
        "MinDate": false,
        "MinVersion": false
    ]
    
    @Published var apfsTextValues: [String: String] = [
        "MinDate": "",
        "MinVersion": "1.0.6"
    ]
    
    @Published var quirksToggleStates: [String: Bool] = [
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
    
    let sections = [
        "APFS", "AppleInput", "Audio", "Booter", "Drivers", "Input", "Output", 
        "ProtocolOverrides", "ReservedMemory", "Unload", "---",
        "ACPI", "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"
    ]
    
    let quirks = [
        "ActivateHpetSupport", "ForgeUefiSupport", "ResizeUsePeiRblo", "ExitBootServicesDelay",
        "DisableSecurityPolicy", "IgnoreInvalidFireRadio", "ShimRetainProtocol",
        "EnableVectorAcceleration", "ReleasedJobOwnership", "UnblockFsConnect",
        "EnableVmx", "ReloadOptionRoms", "ForceOcWriteFlash", "RequestBootVarRouting"
    ]
    
    let apfsSettings = [
        "EnableJumpstart", "GlobalConnect", "HideVerbose", "JumpstartHotPlug", 
        "MinDate", "MinVersion"
    ]
    
    private var loadTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    
    deinit {
        loadTask?.cancel()
        scanTask?.cancel()
    }
    
    func importConfig() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select OpenCore Config.plist"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [UTType.propertyList]
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            loadConfig(url: url)
        }
    }
    
    func exportConfig() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save OpenCore Config"
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = true
        savePanel.nameFieldStringValue = "config-\(Date().formatted(date: .numeric, time: .omitted)).plist"
        savePanel.allowedContentTypes = [UTType.propertyList]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            saveConfig(to: url)
        }
    }
    
    func scanForOpenCore() {
        scanTask?.cancel()
        scanTask = Task {
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
                    
                    if let config = ShellHelper.getOpenCoreConfig() {
                        // Convert to AnyHashable safely
                        self.configData = convertToHashable(config)
                        self.updateConfigEntriesForSection(self.selectedSection)
                        self.alertMessage = "Loaded OpenCore configuration from EFI partition"
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    func loadConfig(url: URL) {
        loadTask?.cancel()
        loadTask = Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                let data = try Data(contentsOf: url)
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                
                await MainActor.run {
                    if let config = plist as? [String: Any] {
                        self.configData = convertToHashable(config)
                        self.filePath = url.path
                        self.configTitle = "\(url.lastPathComponent) - OpenCore [\(self.ocVersion) Development Configuration]"
                        self.updateConfigEntriesForSection(self.selectedSection)
                        
                        let acpiAddCount = getACPIEntryCount(for: "Add")
                        let kextCount = getKernelEntryCount(for: "Add")
                        let driverCount = getUEFIEntryCount(for: "Drivers")
                        
                        self.alertMessage = "Configuration loaded successfully from: \(url.lastPathComponent)\n" +
                                          "Found \(self.configData.count) sections\n" +
                                          "ACPI Add: \(acpiAddCount) entries\n" +
                                          "Kexts: \(kextCount) entries\n" +
                                          "Drivers: \(driverCount) entries"
                        self.showAlert = true
                        self.isLoading = false
                    } else {
                        self.alertMessage = "Failed to parse config.plist file (not a dictionary)\nFile might be corrupted or in wrong format"
                        self.showAlert = true
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to load config: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func convertToHashable(_ dict: [String: Any]) -> [String: AnyHashable] {
        var result: [String: AnyHashable] = [:]
        for (key, value) in dict {
            result[key] = convertValueToHashable(value)
        }
        return result
    }
    
    private func convertValueToHashable(_ value: Any) -> AnyHashable {
        if let dict = value as? [String: Any] {
            var result: [String: AnyHashable] = [:]
            for (k, v) in dict {
                result[k] = convertValueToHashable(v)
            }
            return result
        } else if let array = value as? [Any] {
            return array.map { convertValueToHashable($0) }
        } else if let string = value as? String {
            return AnyHashable(string)
        } else if let bool = value as? Bool {
            return bool
        } else if let int = value as? Int {
            return int
        } else if let double = value as? Double {
            return double
        } else if let data = value as? Data {
            return data
        } else if let date = value as? Date {
            return date
        } else if let number = value as? NSNumber {
            return number
        }
        return AnyHashable("Unknown")
    }
    
    func updateConfigEntriesForSection(_ section: String) {
        let entries = generateEntriesFromConfigData(section: section)
        configEntries = entries
        expandedEntries.removeAll()
        editingEntries.removeAll() // Reset editing when section changes
    }
    
    private func generateEntriesFromConfigData(section: String) -> [ConfigEntry] {
        guard let sectionData = configData[section] else {
            return generateDefaultEntriesForSection(section)
        }
        
        let isOpenCoreSpecificValue = isOpenCoreSection(section)
        let isExpandable = !isEmptyValue(sectionData)
        
        let entry = ConfigEntry(
            key: section,
            type: getTypeString(for: sectionData),
            value: getValueString(for: sectionData, type: getTypeString(for: sectionData)),
            isEnabled: true,
            actualValue: sectionData,
            isOpenCoreSpecific: isOpenCoreSpecificValue,
            parentKey: nil,
            depth: 0,
            isExpandable: isExpandable
        )
        
        return [entry]
    }
    
    func isOpenCoreSection(_ section: String) -> Bool {
        let openCoreSections = ["ACPI", "Booter", "DeviceProperties", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
        return openCoreSections.contains(section)
    }
    
    private func getTypeString(for value: AnyHashable) -> String {
        let unwrapped = value.base
        switch unwrapped {
        case is String: return "String"
        case is Bool: return "Boolean"
        case is Int, is Int64, is Int32, is Int16, is Int8: return "Integer"
        case is Double, is Float: return "Double"
        case is [AnyHashable]: return "Array"
        case is [String: AnyHashable]: return "Dictionary"
        case is Data: return "Data"
        case is Date: return "Date"
        case is NSNumber: return "Number"
        default: return "Unknown"
        }
    }
    
    private func getValueString(for value: AnyHashable, type: String) -> String {
        let unwrapped = value.base
        switch unwrapped {
        case let string as String:
            return string
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as NSNumber:
            return "\(number)"
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return String(format: "%.2f", double)
        case let array as [AnyHashable]:
            return "\(array.count) items"
        case let dict as [String: AnyHashable]:
            return "\(dict.count) keys"
        case let data as Data:
            return "Data (\(data.count) bytes)"
        case let date as Date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        default:
            return "\(unwrapped)"
        }
    }
    
    private func isEmptyValue(_ value: AnyHashable) -> Bool {
        let unwrapped = value.base
        if let dict = unwrapped as? [String: AnyHashable] {
            return dict.isEmpty
        } else if let array = unwrapped as? [AnyHashable] {
            return array.isEmpty
        }
        return false
    }
    
    private func generateDefaultEntriesForSection(_ section: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        let isOpenCoreSpecificValue = isOpenCoreSection(section)
        
        switch section {
        case "APFS":
            let defaultAPFS: [String: AnyHashable] = [
                "EnableJumpstart": true,
                "GlobalConnect": true,
                "HideVerbose": false,
                "JumpstartHotPlug": false,
                "MinDate": 0,
                "MinVersion": ""
            ]
            
            entries = [
                ConfigEntry(
                    key: section,
                    type: "Dictionary",
                    value: "\(defaultAPFS.count) settings",
                    isEnabled: true,
                    actualValue: defaultAPFS,
                    isOpenCoreSpecific: false,
                    depth: 0,
                    isExpandable: true
                )
            ]
        case "ACPI":
            let defaultACPI: [String: AnyHashable] = [
                "Add": [] as [AnyHashable],
                "Delete": [] as [AnyHashable],
                "Patch": [] as [AnyHashable],
                "Quirks": [:] as [String: AnyHashable]
            ]
            
            entries = [
                ConfigEntry(
                    key: section,
                    type: "Dictionary",
                    value: "4 sections",
                    isEnabled: true,
                    actualValue: defaultACPI,
                    isOpenCoreSpecific: true,
                    depth: 0,
                    isExpandable: true
                )
            ]
        case "Kernel":
            let defaultKernel: [String: AnyHashable] = [
                "Add": [] as [AnyHashable],
                "Block": [] as [AnyHashable],
                "Patch": [] as [AnyHashable],
                "Quirks": [:] as [String: AnyHashable],
                "Scheme": [:] as [String: AnyHashable]
            ]
            
            entries = [
                ConfigEntry(
                    key: section,
                    type: "Dictionary",
                    value: "5 sections",
                    isEnabled: true,
                    actualValue: defaultKernel,
                    isOpenCoreSpecific: true,
                    depth: 0,
                    isExpandable: true
                )
            ]
        case "UEFI":
            let defaultUEFI: [String: AnyHashable] = [
                "APFS": [:] as [String: AnyHashable],
                "Drivers": [] as [AnyHashable],
                "Input": [:] as [String: AnyHashable],
                "Output": [:] as [String: AnyHashable],
                "Quirks": [:] as [String: AnyHashable]
            ]
            
            entries = [
                ConfigEntry(
                    key: section,
                    type: "Dictionary",
                    value: "5 sections",
                    isEnabled: true,
                    actualValue: defaultUEFI,
                    isOpenCoreSpecific: true,
                    depth: 0,
                    isExpandable: true
                )
            ]
        default:
            entries = [
                ConfigEntry(
                    key: section,
                    type: "Dictionary",
                    value: "Empty",
                    isEnabled: true,
                    actualValue: [:] as [String: AnyHashable],
                    isOpenCoreSpecific: isOpenCoreSpecificValue,
                    depth: 0,
                    isExpandable: false
                )
            ]
        }
        
        return entries
    }
    
    func getSectionStatus(_ section: String) -> String {
        if configData[section] != nil {
            return "Active"
        }
        
        if isOpenCoreSection(section) && openCoreInfo != nil {
            return "Available"
        }
        
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
    
    func getActualEntryCount(for section: String) -> Int {
        if let sectionData = configData[section] {
            let unwrapped = sectionData.base
            if let dict = unwrapped as? [String: AnyHashable] {
                if section == "ACPI" {
                    var total = 0
                    if let add = dict["Add"]?.base as? [AnyHashable] { total += add.count }
                    if let delete = dict["Delete"]?.base as? [AnyHashable] { total += delete.count }
                    if let patch = dict["Patch"]?.base as? [AnyHashable] { total += patch.count }
                    if let quirks = dict["Quirks"]?.base as? [String: AnyHashable] { total += quirks.count }
                    return total
                } else if section == "Kernel" {
                    var total = 0
                    if let add = dict["Add"]?.base as? [AnyHashable] { total += add.count }
                    if let block = dict["Block"]?.base as? [AnyHashable] { total += block.count }
                    if let patch = dict["Patch"]?.base as? [AnyHashable] { total += patch.count }
                    return total
                } else if section == "UEFI" {
                    if let drivers = dict["Drivers"]?.base as? [AnyHashable] {
                        return drivers.count
                    }
                }
                return dict.count
            } else if let array = unwrapped as? [AnyHashable] {
                return array.count
            }
        }
        
        return 0
    }
    
    private func getACPIEntryCount(for subsection: String) -> Int {
        guard let acpiSection = configData["ACPI"],
              let dict = acpiSection.base as? [String: AnyHashable],
              let subsectionData = dict[subsection]?.base as? [AnyHashable] else {
            return 0
        }
        return subsectionData.count
    }
    
    private func getKernelEntryCount(for subsection: String) -> Int {
        guard let kernelSection = configData["Kernel"],
              let dict = kernelSection.base as? [String: AnyHashable],
              let subsectionData = dict[subsection]?.base as? [AnyHashable] else {
            return 0
        }
        return subsectionData.count
    }
    
    private func getUEFIEntryCount(for subsection: String) -> Int {
        guard let uefiSection = configData["UEFI"],
              let dict = uefiSection.base as? [String: AnyHashable],
              let subsectionData = dict[subsection]?.base as? [AnyHashable] else {
            return 0
        }
        return subsectionData.count
    }
    
    func saveConfig(to url: URL) {
        print("💾 Saving config to: \(url.path)")
        
        // Ensure we have data to save
        guard !configData.isEmpty else {
            alertMessage = "No configuration data to save"
            showAlert = true
            return
        }
        
        do {
            // Convert back to regular dictionary for serialization
            let regularDict = convertFromHashable(configData)
            
            print("📊 Converting config data with \(regularDict.count) sections")
            
            // Try XML format first (most compatible with OpenCore)
            let xmlData = try PropertyListSerialization.data(
                fromPropertyList: regularDict,
                format: .xml,
                options: 0
            )
            
            // Write to file
            try xmlData.write(to: url)
            
            // Update file path and show success message
            filePath = url.path
            alertMessage = "Configuration saved successfully to:\n\(url.lastPathComponent)\n\n" +
                          "Format: XML Property List\n" +
                          "Size: \(xmlData.count) bytes\n" +
                          "Sections: \(configData.count)"
            showAlert = true
            
            print("✅ Config saved successfully: \(url.path)")
            
        } catch let xmlError {
            print("⚠️ XML format failed, trying binary format: \(xmlError)")
            
            do {
                // Try binary format as fallback
                let regularDict = convertFromHashable(configData)
                let binaryData = try PropertyListSerialization.data(
                    fromPropertyList: regularDict,
                    format: .binary,
                    options: 0
                )
                
                try binaryData.write(to: url)
                
                // Update file path and show success message
                filePath = url.path
                alertMessage = "Configuration saved successfully to:\n\(url.lastPathComponent)\n\n" +
                              "Format: Binary Property List\n" +
                              "Size: \(binaryData.count) bytes\n" +
                              "Sections: \(configData.count)\n\n" +
                              "Note: Saved in binary format (XML failed)"
                showAlert = true
                
                print("✅ Config saved in binary format: \(url.path)")
                
            } catch let binaryError {
                print("❌ Binary format also failed: \(binaryError)")
                alertMessage = "Failed to save configuration:\n\n" +
                              "XML Error: \(xmlError.localizedDescription)\n" +
                              "Binary Error: \(binaryError.localizedDescription)\n\n" +
                              "The configuration data might be corrupted or contain unsupported types."
                showAlert = true
            }
        }
    }
    
    private func convertFromHashable(_ dict: [String: AnyHashable]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = convertValueFromHashable(value)
        }
        return result
    }
    
    private func convertValueFromHashable(_ value: AnyHashable) -> Any {
        let unwrapped = value.base
        if let dict = unwrapped as? [String: AnyHashable] {
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result[k] = convertValueFromHashable(v)
            }
            return result
        } else if let array = unwrapped as? [AnyHashable] {
            return array.map { convertValueFromHashable($0) }
        } else if let string = unwrapped as? String {
            return string
        } else if let bool = unwrapped as? Bool {
            return bool
        } else if let int = unwrapped as? Int {
            return int
        } else if let double = unwrapped as? Double {
            return double
        } else if let data = unwrapped as? Data {
            return data
        } else if let date = unwrapped as? Date {
            return date
        } else if let number = unwrapped as? NSNumber {
            return number
        }
        return unwrapped
    }
    
    func generateChildEntries(for parentEntry: ConfigEntry) -> [ConfigEntry] {
        guard let actualValue = parentEntry.actualValue else { return [] }
        
        var children: [ConfigEntry] = []
        
        let unwrapped = actualValue.base
        if let dict = unwrapped as? [String: AnyHashable] {
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                let childEntry = createConfigEntry(
                    key: key,
                    value: value,
                    parentKey: parentEntry.key,
                    depth: parentEntry.depth + 1,
                    isOpenCoreSpecific: parentEntry.isOpenCoreSpecific
                )
                children.append(childEntry)
            }
        } else if let array = unwrapped as? [AnyHashable] {
            for (index, item) in array.enumerated() {
                let childEntry = createConfigEntry(
                    key: "[\(index)]",
                    value: item,
                    parentKey: parentEntry.key,
                    depth: parentEntry.depth + 1,
                    isOpenCoreSpecific: parentEntry.isOpenCoreSpecific
                )
                children.append(childEntry)
            }
        }
        
        return children
    }
    
    private func createConfigEntry(key: String, value: AnyHashable, parentKey: String?, depth: Int, isOpenCoreSpecific: Bool) -> ConfigEntry {
        let type = getTypeString(for: value)
        let valueString = getValueString(for: value, type: type)
        let unwrapped = value.base
        let isEnabled: Bool
        if let bool = unwrapped as? Bool {
            isEnabled = bool
        } else {
            isEnabled = true
        }
        let isExpandable = (type == "Dictionary" || type == "Array") && !isEmptyValue(value)
        
        return ConfigEntry(
            key: key,
            type: type,
            value: valueString,
            isEnabled: isEnabled,
            actualValue: value,
            isOpenCoreSpecific: isOpenCoreSpecific,
            parentKey: parentKey,
            depth: depth,
            isExpandable: isExpandable
        )
    }
    
    func showRawJSONView() {
        do {
            let regularDict = convertFromHashable(configData)
            let jsonData = try JSONSerialization.data(withJSONObject: regularDict, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                rawJSONText = jsonString
                showRawJSON = true
            }
        } catch {
            alertMessage = "Failed to generate JSON: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func filterEntries() {
        guard !searchText.isEmpty else {
            updateConfigEntriesForSection(selectedSection)
            return
        }
        
        let filtered = filterEntriesRecursively(entries: configEntries, searchText: searchText.lowercased())
        configEntries = filtered
    }
    
    private func filterEntriesRecursively(entries: [ConfigEntry], searchText: String) -> [ConfigEntry] {
        var result: [ConfigEntry] = []
        
        for entry in entries {
            var modifiedEntry = entry
            
            // Check if this entry matches the search
            let matches = entry.key.lowercased().contains(searchText) ||
                         entry.value.lowercased().contains(searchText) ||
                         entry.type.lowercased().contains(searchText)
            
            if matches {
                result.append(modifiedEntry)
                expandedEntries.insert(entry.id)
            } else if entry.isExpandable {
                // Check children recursively
                let childEntries = generateChildEntries(for: entry)
                let filteredChildren = filterEntriesRecursively(entries: childEntries, searchText: searchText)
                
                if !filteredChildren.isEmpty {
                    modifiedEntry.isExpandable = true
                    result.append(modifiedEntry)
                    expandedEntries.insert(entry.id)
                }
            }
        }
        
        return result
    }
    
    // MARK: - Editing Functions
    
    func startEditingEntry(_ entry: ConfigEntry) {
        editingEntries.insert(entry.id)
        // Initialize editedValue with current value
        if let index = configEntries.firstIndex(where: { $0.id == entry.id }) {
            configEntries[index].editedValue = entry.value
            configEntries[index].isEditing = true
        }
    }
    
    func stopEditingEntry(_ entry: ConfigEntry) {
        editingEntries.remove(entry.id)
        if let index = configEntries.firstIndex(where: { $0.id == entry.id }) {
            configEntries[index].isEditing = false
        }
    }
    
    func saveEditedValue(for entry: ConfigEntry) {
        guard let index = configEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        
        var updatedEntry = configEntries[index]
        let newValue = updatedEntry.editedValue
        
        // Update the entry's value
        updatedEntry.value = newValue
        updatedEntry.isEditing = false
        
        // Update the actual value based on type
        switch updatedEntry.type {
        case "String":
            updatedEntry.actualValue = AnyHashable(newValue)
        case "Boolean":
            let boolValue = newValue.lowercased() == "true"
            updatedEntry.actualValue = boolValue
            updatedEntry.value = boolValue ? "true" : "false"
        case "Integer":
            if let intValue = Int(newValue) {
                updatedEntry.actualValue = intValue
                updatedEntry.value = "\(intValue)"
            }
        case "Double":
            if let doubleValue = Double(newValue) {
                updatedEntry.actualValue = doubleValue
                updatedEntry.value = String(format: "%.2f", doubleValue)
            }
        default:
            // For complex types, we can't directly edit them
            break
        }
        
        configEntries[index] = updatedEntry
        editingEntries.remove(entry.id)
        
        // Update the main configData if this is a top-level entry
        if updatedEntry.depth == 0 {
            updateConfigDataFromEntry(updatedEntry)
        } else {
            // For nested entries, we need to update the parent
            updateParentEntry(for: updatedEntry)
        }
        
        alertMessage = "Saved changes to: \(updatedEntry.key)"
        showAlert = true
    }
    
    private func updateConfigDataFromEntry(_ entry: ConfigEntry) {
        // Update the main configData dictionary
        if let actualValue = entry.actualValue {
            configData[entry.key] = actualValue
        }
    }
    
    private func updateParentEntry(for childEntry: ConfigEntry) {
        guard let parentKey = childEntry.parentKey,
              let parentIndex = configEntries.firstIndex(where: { $0.key == parentKey && $0.depth == childEntry.depth - 1 }),
              var parentEntry = configEntries[safe: parentIndex],
              var parentActualValue = parentEntry.actualValue?.base as? [String: AnyHashable] else { return }
        
        // Update the parent's dictionary
        parentActualValue[childEntry.key] = childEntry.actualValue
        parentEntry.actualValue = AnyHashable(parentActualValue)
        parentEntry.value = "\(parentActualValue.count) keys"
        
        configEntries[parentIndex] = parentEntry
        
        // If this is a top-level section, update configData
        if parentEntry.depth == 0 {
            configData[parentEntry.key] = parentEntry.actualValue
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct OpenCoreConfigEditorView: View {
    @StateObject private var viewModel = ConfigViewModel()
    @State private var loadDefaultConfigOnAppear = true
    
    var body: some View {
        NavigationView {
            // Left sidebar
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.configTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    if viewModel.showAuthorInfo {
                        Divider()
                            .padding(.vertical, 4)
                        
                        Button(action: {
                            viewModel.showAuthorInfo.toggle()
                        }) {
                            HStack {
                                Text("Author Information")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .rotationEffect(.degrees(viewModel.showAuthorInfo ? 90 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        
                        if viewModel.showAuthorInfo {
                            Divider()
                                .padding(.vertical, 4)
                            
                            AuthorInfoView()
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    if viewModel.showOpenCoreInfo {
                        Divider()
                            .padding(.vertical, 4)
                        
                        Button(action: {
                            viewModel.showOpenCoreInfo.toggle()
                        }) {
                            HStack {
                                Text(viewModel.openCoreInfo != nil ? "OpenCore Detected ✓" : "OpenCore Not Found ⚠️")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(viewModel.openCoreInfo != nil ? .green : .orange)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .rotationEffect(.degrees(viewModel.showOpenCoreInfo ? 90 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        
                        if viewModel.showOpenCoreInfo {
                            Divider()
                                .padding(.vertical, 4)
                            
                            OpenCoreInfoView(openCoreInfo: viewModel.openCoreInfo)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                
                Toggle("Show Debug Info", isOn: $viewModel.showDebugInfo)
                    .toggleStyle(.switch)
                    .font(.system(size: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                
                if viewModel.showDebugInfo {
                    DebugInfoView(configData: viewModel.configData)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APFS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                            
                            ForEach(viewModel.apfsSettings, id: \.self) { setting in
                                APFSSettingRow(
                                    setting: setting,
                                    isOn: Binding(
                                        get: { viewModel.apfsToggleStates[setting] ?? false },
                                        set: { viewModel.apfsToggleStates[setting] = $0 }
                                    ),
                                    showTextField: setting == "MinDate" || setting == "MinVersion",
                                    textValue: Binding(
                                        get: { viewModel.apfsTextValues[setting] ?? "" },
                                        set: { viewModel.apfsTextValues[setting] = $0 }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Configuration Sections")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                            
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
                            
                            ForEach(viewModel.sections, id: \.self) { section in
                                if section == "---" {
                                    Divider()
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 12)
                                } else {
                                    SectionRow(
                                        section: section,
                                        isSelected: viewModel.selectedSection == section,
                                        status: viewModel.getSectionStatus(section),
                                        entryCount: viewModel.getActualEntryCount(for: section),
                                        isOpenCoreSection: viewModel.isOpenCoreSection(section)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectedSection = section
                                        viewModel.updateConfigEntriesForSection(section)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quirks")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                            
                            ForEach(viewModel.quirks, id: \.self) { quirk in
                                QuirkRow(
                                    quirk: quirk,
                                    isOn: Binding(
                                        get: { viewModel.quirksToggleStates[quirk] ?? false },
                                        set: { viewModel.quirksToggleStates[quirk] = $0 }
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
                // Toolbar
                VStack(spacing: 0) {
                    HStack {
                        Text("OpenCore Configurator 2.7.8.1.0")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Author attribution in toolbar
                        HStack(spacing: 4) {
                            Text("👨‍💻")
                                .font(.system(size: 12))
                            Text("Navaratnam Manoranjan")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 150)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)
                        
                        TextField("Search...", text: $viewModel.searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                            .font(.system(size: 11))
                            .onChange(of: viewModel.searchText) { _, newValue in
                                if newValue.isEmpty {
                                    viewModel.updateConfigEntriesForSection(viewModel.selectedSection)
                                } else {
                                    viewModel.filterEntries()
                                }
                            }
                        
                        Button(action: {
                            viewModel.scanForOpenCore()
                        }) {
                            HStack {
                                if viewModel.isScanning {
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
                        .disabled(viewModel.isScanning)
                        
                        Button(action: {
                            viewModel.showDebugInfo.toggle()
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
                        .foregroundColor(viewModel.showDebugInfo ? .red : .primary)
                        
                        Button(action: {
                            viewModel.showRawJSONView()
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
                        .disabled(viewModel.configData.isEmpty)
                        
                        if !viewModel.filePath.isEmpty {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(URL(fileURLWithPath: viewModel.filePath).lastPathComponent)
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
                        
                        Button(action: { viewModel.importConfig() }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 11))
                                Text("Import")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { viewModel.exportConfig() }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                Text("Export")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.configData.isEmpty)
                        
                        Button(action: {
                            viewModel.isEditing.toggle()
                            viewModel.alertMessage = viewModel.isEditing ? "Entered edit mode" : "Exited edit mode"
                            viewModel.showAlert = true
                        }) {
                            HStack {
                                Image(systemName: viewModel.isEditing ? "checkmark.circle.fill" : "pencil")
                                    .font(.system(size: 11))
                                Text(viewModel.isEditing ? "Done" : "Edit")
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
                
                // Main content
                if viewModel.configData.isEmpty {
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
                            viewModel.importConfig()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                        
                        // Author attribution in empty state
                        VStack(spacing: 4) {
                            Text("Developed by:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                
                                Text("Navaratnam Manoranjan")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                
                                Text("nmano0006@gmail.com")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.showRawJSON {
                    RawJSONView(jsonText: viewModel.rawJSONText, onClose: {
                        viewModel.showRawJSON = false
                    })
                } else {
                    ConfigTableView(
                        entries: $viewModel.configEntries,
                        expandedEntries: $viewModel.expandedEntries,
                        editingEntries: $viewModel.editingEntries,
                        isEditing: viewModel.isEditing,
                        onEntryTap: { entry in
                            viewModel.selectedEntryForDetail = entry
                            viewModel.showDetailView = true
                        },
                        onStartEditing: { entry in
                            viewModel.startEditingEntry(entry)
                        },
                        onSaveEditing: { entry in
                            viewModel.saveEditedValue(for: entry)
                        },
                        onCancelEditing: { entry in
                            viewModel.stopEditingEntry(entry)
                        }
                    )
                }
            }
            .frame(minWidth: 1000)
        }
        .navigationTitle("")
        .sheet(isPresented: $viewModel.showDetailView) {
            if let entry = viewModel.selectedEntryForDetail {
                ConfigEntryDetailView(entry: .constant(entry))
            }
        }
        .sheet(isPresented: $viewModel.showRawJSON) {
            RawJSONView(jsonText: viewModel.rawJSONText, onClose: {
                viewModel.showRawJSON = false
            })
        }
        .alert("OpenCore Configurator", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onAppear {
            if loadDefaultConfigOnAppear {
                // Load default config on first appear only
                loadDefaultConfigOnAppear = false
                loadDefaultConfig()
                viewModel.updateConfigEntriesForSection(viewModel.selectedSection)
                
                // Scan for OpenCore
                viewModel.scanForOpenCore()
            }
        }
    }
    
    private func loadDefaultConfig() {
        // Create sample data with AnyHashable
        let defaultACPIQuirks: [String: AnyHashable] = [
            "FadtEnableReset": false,
            "NormalizeHeaders": true,
            "RebaseRegions": true,
            "ResetHwSig": false,
            "ResetLogoStatus": false,
            "SyncTableIds": true
        ]
        
        viewModel.configData = [
            "ACPI": [
                "Add": [] as [AnyHashable],
                "Delete": [] as [AnyHashable],
                "Patch": [] as [AnyHashable],
                "Quirks": defaultACPIQuirks
            ] as [String: AnyHashable],
            "Booter": ["MmioWhitelist": [] as [AnyHashable], "Patch": [] as [AnyHashable], "Quirks": [:] as [String: AnyHashable]] as [String: AnyHashable],
            "DeviceProperties": ["Add": [:] as [String: AnyHashable], "Delete": [:] as [String: AnyHashable]] as [String: AnyHashable],
            "Kernel": [
                "Add": [] as [AnyHashable],
                "Block": [] as [AnyHashable],
                "Patch": [] as [AnyHashable],
                "Quirks": [:] as [String: AnyHashable],
                "Scheme": [:] as [String: AnyHashable]
            ] as [String: AnyHashable],
            "Misc": ["Boot": [:] as [String: AnyHashable], "Debug": [:] as [String: AnyHashable], "Security": [:] as [String: AnyHashable], "Tools": [] as [AnyHashable]] as [String: AnyHashable],
            "NVRAM": ["Add": [:] as [String: AnyHashable], "Delete": [:] as [String: AnyHashable], "WriteFlash": true] as [String: AnyHashable],
            "PlatformInfo": ["Generic": [:] as [String: AnyHashable], "UpdateDataHub": true, "UpdateSMBIOS": true] as [String: AnyHashable],
            "UEFI": [
                "APFS": [:] as [String: AnyHashable],
                "Drivers": [] as [AnyHashable],
                "Input": [:] as [String: AnyHashable],
                "Output": [:] as [String: AnyHashable],
                "Quirks": [:] as [String: AnyHashable]
            ] as [String: AnyHashable]
        ]
    }
}

// MARK: - Config Table Views

struct ConfigTableView: View {
    @Binding var entries: [ConfigEntry]
    @Binding var expandedEntries: Set<UUID>
    @Binding var editingEntries: Set<UUID>
    let isEditing: Bool
    let onEntryTap: (ConfigEntry) -> Void
    let onStartEditing: (ConfigEntry) -> Void
    let onSaveEditing: (ConfigEntry) -> Void
    let onCancelEditing: (ConfigEntry) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                HStack {
                    Text("Key")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 250, alignment: .leading)
                    
                    Text("Type")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 100, alignment: .leading)
                    
                    Text("Value")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 300, alignment: .leading)
                    
                    Spacer()
                    
                    if isEditing {
                        Text("Actions")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 100, alignment: .center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Rows
                ForEach(entries) { entry in
                    ConfigTableRow(
                        entry: entry,
                        expandedEntries: $expandedEntries,
                        editingEntries: $editingEntries,
                        isEditing: isEditing,
                        onTap: {
                            onEntryTap(entry)
                        },
                        onStartEditing: {
                            onStartEditing(entry)
                        },
                        onSaveEditing: {
                            onSaveEditing(entry)
                        },
                        onCancelEditing: {
                            onCancelEditing(entry)
                        }
                    )
                }
                
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No entries found")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
    }
}

struct ConfigTableRow: View {
    let entry: ConfigEntry
    @Binding var expandedEntries: Set<UUID>
    @Binding var editingEntries: Set<UUID>
    let isEditing: Bool
    let onTap: () -> Void
    let onStartEditing: () -> Void
    let onSaveEditing: () -> Void
    let onCancelEditing: () -> Void
    
    @State private var childEntries: [ConfigEntry] = []
    @State private var editedValue: String = ""
    
    var isCurrentlyEditing: Bool {
        editingEntries.contains(entry.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .center) {
                // Indentation
                ForEach(0..<entry.depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 12)
                        .padding(.leading, 8)
                }
                
                // Expand/collapse button
                if entry.isExpandable {
                    Button(action: {
                        toggleExpansion()
                    }) {
                        Image(systemName: expandedEntries.contains(entry.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Key display
                Text(entry.key)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(entry.isOpenCoreSpecific ? .blue : .primary)
                    .lineLimit(1)
                    .frame(width: 250, alignment: .leading)
                
                // Type display
                Text(entry.type)
                    .font(.system(size: 10))
                    .foregroundColor(getTypeColor(entry.type))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(getTypeBackgroundColor(entry.type))
                    .cornerRadius(3)
                    .frame(width: 100, alignment: .leading)
                
                // Value display or edit field
                if isCurrentlyEditing && entry.type != "Dictionary" && entry.type != "Array" {
                    TextField("Value", text: $editedValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                        .frame(width: 300)
                        .onAppear {
                            editedValue = entry.editedValue
                        }
                        .onSubmit {
                            // Update the entry's editedValue when text field is submitted
                            var updatedEntry = entry
                            updatedEntry.editedValue = editedValue
                            // We need to pass this update back to the parent
                            onSaveEditing()
                        }
                } else {
                    valueDisplayView
                        .frame(width: 300, alignment: .leading)
                }
                
                Spacer()
                
                // Count indicator for expandable items
                if entry.isExpandable {
                    Text(getValueCountString(for: entry))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                // Actions column when in edit mode
                if isEditing && entry.type != "Dictionary" && entry.type != "Array" {
                    HStack(spacing: 4) {
                        if isCurrentlyEditing {
                            Button(action: {
                                // Save the edited value
                                var updatedEntry = entry
                                updatedEntry.editedValue = editedValue
                                onSaveEditing()
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .help("Save")
                            
                            Button(action: {
                                onCancelEditing()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel")
                        } else {
                            Button(action: {
                                editedValue = entry.value
                                onStartEditing()
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Edit")
                        }
                        
                        // Detail button
                        Button(action: onTap) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Show details")
                    }
                    .frame(width: 100, alignment: .center)
                } else {
                    // Detail button when not in edit mode
                    Button(action: onTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Show details")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(entry.id.uuidString.hashValue % 2 == 0 ? Color.clear : Color.gray.opacity(0.02))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            // Child rows if expanded
            if expandedEntries.contains(entry.id) && !childEntries.isEmpty {
                ForEach(childEntries) { childEntry in
                    ConfigTableRow(
                        entry: childEntry,
                        expandedEntries: $expandedEntries,
                        editingEntries: $editingEntries,
                        isEditing: isEditing,
                        onTap: onTap,
                        onStartEditing: onStartEditing,
                        onSaveEditing: onSaveEditing,
                        onCancelEditing: onCancelEditing
                    )
                }
            }
        }
    }
    
    private var valueDisplayView: some View {
        Group {
            if entry.type == "Boolean" {
                HStack {
                    Image(systemName: entry.value == "true" ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(entry.value == "true" ? .green : .red)
                    
                    Text(entry.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(entry.value == "true" ? .green : .red)
                }
            } else if entry.type == "Dictionary" || entry.type == "Array" {
                Text(entry.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.purple)
                    .italic()
            } else {
                Text(entry.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }
    
    private func toggleExpansion() {
        if expandedEntries.contains(entry.id) {
            expandedEntries.remove(entry.id)
        } else {
            expandedEntries.insert(entry.id)
            // Generate child entries when expanded
            if childEntries.isEmpty {
                generateChildEntries()
            }
        }
    }
    
    private func generateChildEntries() {
        guard let actualValue = entry.actualValue else { return }
        
        if let dict = actualValue.base as? [String: AnyHashable] {
            childEntries = dict.sorted(by: { $0.key < $1.key }).map { key, value in
                createChildEntry(key: key, value: value)
            }
        } else if let array = actualValue.base as? [AnyHashable] {
            childEntries = array.enumerated().map { index, value in
                createChildEntry(key: "[\(index)]", value: value)
            }
        }
    }
    
    private func createChildEntry(key: String, value: AnyHashable) -> ConfigEntry {
        let type: String
        let valueString: String
        let isEnabled: Bool
        let isExpandable: Bool
        
        switch value.base {
        case is String:
            type = "String"
            valueString = value.base as? String ?? "Unknown"
            isEnabled = true
            isExpandable = false
        case is Bool:
            type = "Boolean"
            valueString = (value.base as? Bool ?? false) ? "true" : "false"
            isEnabled = value.base as? Bool ?? false
            isExpandable = false
        case is Int, is Int64, is Int32, is Int16, is Int8:
            type = "Integer"
            valueString = "\(value.base)"
            isEnabled = true
            isExpandable = false
        case is Double, is Float:
            type = "Double"
            valueString = String(format: "%.2f", value.base as? Double ?? 0.0)
            isEnabled = true
            isExpandable = false
        case let dict as [String: AnyHashable]:
            type = "Dictionary"
            valueString = "\(dict.count) keys"
            isEnabled = true
            isExpandable = !dict.isEmpty
        case let array as [AnyHashable]:
            type = "Array"
            valueString = "\(array.count) items"
            isEnabled = true
            isExpandable = !array.isEmpty
        case is Data:
            type = "Data"
            let data = value.base as? Data ?? Data()
            valueString = "Data (\(data.count) bytes)"
            isEnabled = true
            isExpandable = false
        case is Date:
            type = "Date"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            valueString = formatter.string(from: value.base as? Date ?? Date())
            isEnabled = true
            isExpandable = false
        case is NSNumber:
            type = "Number"
            valueString = "\(value.base)"
            isEnabled = true
            isExpandable = false
        default:
            type = "Unknown"
            valueString = "Unknown"
            isEnabled = true
            isExpandable = false
        }
        
        return ConfigEntry(
            key: key,
            type: type,
            value: valueString,
            isEnabled: isEnabled,
            actualValue: value,
            isOpenCoreSpecific: entry.isOpenCoreSpecific,
            parentKey: entry.key,
            depth: entry.depth + 1,
            isExpandable: isExpandable,
            editedValue: valueString
        )
    }
    
    private func getValueCountString(for entry: ConfigEntry) -> String {
        if let dict = entry.actualValue?.base as? [String: AnyHashable] {
            return "\(dict.count) items"
        } else if let array = entry.actualValue?.base as? [AnyHashable] {
            return "\(array.count) items"
        }
        return ""
    }
    
    private func getTypeColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue
        case "Boolean": return .green
        case "Integer", "Double", "Number": return .orange
        case "Array": return .purple
        case "Dictionary": return .red
        case "Data": return .pink
        default: return .gray
        }
    }
    
    private func getTypeBackgroundColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue.opacity(0.1)
        case "Boolean": return .green.opacity(0.1)
        case "Integer", "Double", "Number": return .orange.opacity(0.1)
        case "Array": return .purple.opacity(0.1)
        case "Dictionary": return .red.opacity(0.1)
        case "Data": return .pink.opacity(0.1)
        default: return .gray.opacity(0.1)
        }
    }
}

// MARK: - Config Entry Detail View
struct ConfigEntryDetailView: View {
    @Binding var entry: ConfigEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Entry Details")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Author attribution in detail view
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            
                            Text("OpenCore Configurator")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Developed by Navaratnam Manoranjan")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("nmano0006@gmail.com")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(6)
                    
                    // Key display
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key")
                            .font(.headline)
                        
                        Text(entry.key)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Type display
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.headline)
                        
                        Text(entry.type)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(getTypeColor(entry.type))
                            .padding()
                            .background(getTypeBackgroundColor(entry.type))
                            .cornerRadius(8)
                    }
                    
                    // Value display
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.headline)
                        
                        Text(entry.value)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Raw value display (if available)
                    if let actualValue = entry.safeValue {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Raw Value")
                                .font(.headline)
                            
                            Text("\(String(describing: actualValue))")
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions")
                            .font(.headline)
                        
                        HStack {
                            Button("Copy Key") {
                                copyToClipboard(entry.key)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Copy Value") {
                                copyToClipboard(entry.value)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func getTypeColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue
        case "Boolean": return .green
        case "Integer", "Double", "Number": return .orange
        case "Array": return .purple
        case "Dictionary": return .red
        case "Data": return .pink
        default: return .gray
        }
    }
    
    private func getTypeBackgroundColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue.opacity(0.1)
        case "Boolean": return .green.opacity(0.1)
        case "Integer", "Double", "Number": return .orange.opacity(0.1)
        case "Array": return .purple.opacity(0.1)
        case "Dictionary": return .red.opacity(0.1)
        case "Data": return .pink.opacity(0.1)
        default: return .gray.opacity(0.1)
        }
    }
}

// MARK: - Preview
struct OpenCoreConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        OpenCoreConfigEditorView()
            .frame(width: 1200, height: 800)
    }
}