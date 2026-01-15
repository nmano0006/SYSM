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

// MARK: - Component Views

struct APFSSettingRow: View {
    let setting: String
    @Binding var isOn: Bool
    let showTextField: Bool
    let textValue: String
    
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
                TextField("", text: .constant(textValue))
                    .font(.system(size: 10))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
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
            // Section icon
            Image(systemName: getSectionIcon(section))
                .font(.system(size: 10))
                .foregroundColor(getSectionColor(section))
                .frame(width: 20)
            
            // Section name
            Text(section)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(width: 100, alignment: .leading)
            
            // Status
            Text(status)
                .font(.system(size: 9))
                .foregroundColor(getStatusColor(status))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(getStatusBackgroundColor(status))
                .cornerRadius(3)
                .frame(width: 60, alignment: .center)
            
            // Entry count
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

struct ConfigTableView: View {
    let entries: [ConfigEntry]
    @Binding var isEditing: Bool
    @Binding var expandedValues: Set<UUID>
    let onEntryTap: (ConfigEntry) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                HStack {
                    Text("Key")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 200, alignment: .leading)
                    
                    Text("Type")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 80, alignment: .leading)
                    
                    Text("Value")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 200, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Entries
                ForEach(entries) { entry in
                    ConfigTableRow(
                        entry: entry,
                        isEditing: isEditing,
                        isExpanded: expandedValues.contains(entry.id),
                        onTap: {
                            onEntryTap(entry)
                        },
                        onExpandToggle: {
                            if expandedValues.contains(entry.id) {
                                expandedValues.remove(entry.id)
                            } else {
                                expandedValues.insert(entry.id)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(entry.id.uuidString.hashValue % 2 == 0 ? Color.clear : Color.gray.opacity(0.02))
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
    let isEditing: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onExpandToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .center) {
                // Expand/collapse button for complex types
                if entry.type == "Dictionary" || entry.type == "Array" {
                    Button(action: onExpandToggle) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Key with indentation for nested entries
                HStack(spacing: 4) {
                    if let parentKey = entry.parentKey {
                        // Show nesting indicator
                        ForEach(0..<getNestingLevel(for: parentKey), id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 12)
                        }
                    }
                    
                    Text(entry.key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(entry.isOpenCoreSpecific ? .blue : .primary)
                        .lineLimit(1)
                }
                .frame(width: 200, alignment: .leading)
                
                // Type
                Text(entry.type)
                    .font(.system(size: 10))
                    .foregroundColor(getTypeColor(entry.type))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(getTypeBackgroundColor(entry.type))
                    .cornerRadius(3)
                    .frame(width: 80, alignment: .leading)
                
                // Value
                if entry.type == "Boolean" {
                    HStack {
                        Image(systemName: entry.value == "true" ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(entry.value == "true" ? .green : .red)
                        
                        Text(entry.value)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(entry.value == "true" ? .green : .red)
                    }
                    .frame(width: 200, alignment: .leading)
                } else {
                    Text(entry.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                        .frame(width: 200, alignment: .leading)
                }
                
                Spacer()
                
                // Edit controls
                if isEditing && entry.type == "Boolean" {
                    Toggle("", isOn: .constant(entry.isEnabled))
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .labelsHidden()
                        .frame(width: 40)
                }
                
                if entry.type == "Dictionary" || entry.type == "Array" {
                    Text(getValueCountString(for: entry))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                Button(action: onTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Show details")
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            // Expanded view for complex types
            if isExpanded && (entry.type == "Dictionary" || entry.type == "Array") {
                ExpandedView(entry: entry)
            }
        }
    }
    
    private func getNestingLevel(for parentKey: String) -> Int {
        return parentKey.split(separator: ".").count
    }
    
    private func getTypeColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue
        case "Boolean": return .green
        case "Integer", "Double": return .orange
        case "Array": return .purple
        case "Dictionary": return .red
        default: return .gray
        }
    }
    
    private func getTypeBackgroundColor(_ type: String) -> Color {
        switch type {
        case "String": return .blue.opacity(0.1)
        case "Boolean": return .green.opacity(0.1)
        case "Integer", "Double": return .orange.opacity(0.1)
        case "Array": return .purple.opacity(0.1)
        case "Dictionary": return .red.opacity(0.1)
        default: return .gray.opacity(0.1)
        }
    }
    
    private func getValueCountString(for entry: ConfigEntry) -> String {
        if let dict = entry.actualValue as? [String: Any] {
            return "\(dict.count) items"
        } else if let array = entry.actualValue as? [Any] {
            return "\(array.count) items"
        }
        return ""
    }
}

struct ExpandedView: View {
    let entry: ConfigEntry
    
    var body: some View {
        if let dict = entry.actualValue as? [String: Any] {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("• \(key):")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        if let value = dict[key] {
                            Text(getValuePreview(value))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 16)
        } else if let array = entry.actualValue as? [Any] {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<min(array.count, 10), id: \.self) { index in
                    HStack {
                        Text("[\(index)]:")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(getValuePreview(array[index]))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 32)
                }
                
                if array.count > 10 {
                    Text("... and \(array.count - 10) more items")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.leading, 32)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 16)
        }
    }
    
    private func getValuePreview(_ value: Any) -> String {
        if let string = value as? String {
            return string.count > 30 ? String(string.prefix(30)) + "..." : string
        } else if let number = value as? Int {
            return "\(number)"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let dict = value as? [String: Any] {
            return "Dictionary (\(dict.count) keys)"
        } else if let array = value as? [Any] {
            return "Array (\(array.count) items)"
        }
        return "\(value)"
    }
}

struct ConfigEntryDetailView: View {
    let entry: ConfigEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Entry Details")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    BasicInfoView(entry: entry)
                    
                    // Value Display
                    ValueDisplayView(entry: entry)
                    
                    // Actions
                    ActionsView(entry: entry)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct BasicInfoView: View {
    let entry: ConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Information")
                .font(.title3)
                .fontWeight(.semibold)
            
            DetailRow(title: "Key:", value: entry.key)
            DetailRow(title: "Full Path:", value: entry.parentKey ?? entry.key)
            DetailRow(title: "Type:", value: entry.type)
            DetailRow(title: "OpenCore:", value: entry.isOpenCoreSpecific ? "Yes" : "No")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ValueDisplayView: View {
    let entry: ConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Value")
                .font(.title3)
                .fontWeight(.semibold)
            
            if entry.type == "Dictionary" || entry.type == "Array" {
                Text("Complex Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let dict = entry.actualValue as? [String: Any] {
                    DictionaryView(dict: dict)
                } else if let array = entry.actualValue as? [Any] {
                    ArrayView(array: array)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                }
            } else {
                DetailRow(title: "Value:", value: entry.value)
                
                if let actualValue = entry.actualValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw Value:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(describing: actualValue))")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActionsView: View {
    let entry: ConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                Button("Copy Key") {
                    copyToClipboard(entry.key)
                }
                .buttonStyle(.bordered)
                
                Button("Copy Value") {
                    copyToClipboard(entry.value)
                }
                .buttonStyle(.bordered)
                
                if entry.type == "Dictionary" || entry.type == "Array" {
                    Button("Export as JSON") {
                        exportAsJSON(entry: entry)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func exportAsJSON(entry: ConfigEntry) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export as JSON"
        savePanel.nameFieldStringValue = "\(entry.key)-\(Date().formatted(date: .numeric, time: .omitted)).json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let jsonObject: Any
                if let dict = entry.actualValue as? [String: Any] {
                    jsonObject = dict
                } else if let array = entry.actualValue as? [Any] {
                    jsonObject = array
                } else {
                    return
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
                try jsonData.write(to: url)
            } catch {
                print("Failed to export JSON: \(error)")
            }
        }
    }
}

struct DictionaryView: View {
    let dict: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top) {
                    Text("\(key):")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 150, alignment: .leading)
                    
                    if let value = dict[key] {
                        Text(getValueString(value))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }
    
    private func getValueString(_ value: Any) -> String {
        if let string = value as? String {
            return "\"\(string)\""
        } else if let number = value as? NSNumber {
            return "\(number)"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let dict = value as? [String: Any] {
            return "{...} (\(dict.count) keys)"
        } else if let array = value as? [Any] {
            return "[...] (\(array.count) items)"
        }
        return "\(value)"
    }
}

struct ArrayView: View {
    let array: [Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<array.count, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("[\(index)]:")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.purple)
                        .frame(width: 50, alignment: .leading)
                    
                    Text(getValueString(array[index]))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }
    
    private func getValueString(_ value: Any) -> String {
        if let string = value as? String {
            return "\"\(string)\""
        } else if let number = value as? NSNumber {
            return "\(number)"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let dict = value as? [String: Any] {
            return "{...} (\(dict.count) keys)"
        } else if let array = value as? [Any] {
            return "[...] (\(array.count) items)"
        }
        return "\(value)"
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

struct RawJSONView: View {
    let jsonText: String
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            
            // JSON Text
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
                                Text(String(describing: type(of: value)))
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
    
    @State private var filteredEntries: [ConfigEntry] = []
    
    var body: some View {
        NavigationView {
            // Left sidebar - Sections
            sidebarView
            
            // Main content area
            mainContentView
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
        .alert("OpenCore Configurator", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            sidebarHeader
            debugToggleView
            sectionsScrollView
        }
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 320)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
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
    }
    
    private var debugToggleView: some View {
        Group {
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
        }
    }
    
    private var sectionsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                apfsSectionView
                
                Divider()
                    .padding(.vertical, 8)
                
                configurationSectionsView
                
                Divider()
                    .padding(.vertical, 8)
                
                quirksSectionView
            }
        }
    }
    
    private var apfsSectionView: some View {
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
    }
    
    private var configurationSectionsView: some View {
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
    }
    
    private var quirksSectionView: some View {
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
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            headerToolbarView
            
            if configData.isEmpty {
                emptyContentView
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
    
    private var headerToolbarView: some View {
        VStack(spacing: 0) {
            HStack {
                headerLeftContent
                Spacer()
                headerRightContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
        }
    }
    
    private var headerLeftContent: some View {
        Text("OpenCore Configurator 2.7.8.1.0")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
    }
    
    private var headerRightContent: some View {
        HStack {
            // Search field
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
                .font(.system(size: 11))
                .onChange(of: searchText) { _ in
                    filterEntries()
                }
            
            // Scan for OpenCore button
            scanButton
            
            // Debug button
            debugButton
            
            // View Raw JSON
            rawJSONButton
            
            // File info
            if !filePath.isEmpty {
                fileInfoView
            }
            
            // Import Button
            importButton
            
            // Export Button
            exportButton
            
            // Edit/Save Button
            editSaveButton
        }
    }
    
    private var scanButton: some View {
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
    }
    
    private var debugButton: some View {
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
    }
    
    private var rawJSONButton: some View {
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
    }
    
    private var fileInfoView: some View {
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
    
    private var importButton: some View {
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
    }
    
    private var exportButton: some View {
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
    }
    
    private var editSaveButton: some View {
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
    
    private var emptyContentView: some View {
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
    }
    
    // MARK: - Helper Methods
    
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
        
        addDebugLog("Section \(section) found, type: \(String(describing: type(of: sectionData)))")
        
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
                
                updateConfigEntriesForSection(selectedSection)
                
                alertMessage = "Configuration loaded successfully from: \(url.lastPathComponent)\nFound \(configData.count) sections"
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

// MARK: - Preview
struct OpenCoreConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        OpenCoreConfigEditorView()
            .frame(width: 900, height: 600)
    }
}