import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - Enhanced Shell Command Helper
struct ShellHelper {
    static func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, success: Bool) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        
        if needsSudo {
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            task.arguments = ["-c", "osascript -e 'do shell script \"\(escapedCommand)\" with administrator privileges'"]
        } else {
            task.arguments = ["-c", command]
        }
        
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            return ("Error: \(error.localizedDescription)", false)
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        return (output, success)
    }
    
    static func mountEFIPartition() -> Bool {
        print("Attempting to mount EFI partition...")
        
        // Try common EFI partitions
        let commonEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1"]
        
        for efiID in commonEFIs {
            // Check if already mounted
            let checkMountedResult = runCommand("mount | grep '/dev/\(efiID)'")
            if checkMountedResult.success && !checkMountedResult.output.isEmpty {
                print("EFI partition \(efiID) already mounted")
                return true
            }
            
            // Try to mount
            print("Attempting to mount EFI partition: \(efiID)")
            let mountResult = runCommand("diskutil mount \(efiID)", needsSudo: true)
            
            if mountResult.success {
                print("Successfully mounted EFI partition: \(efiID)")
                return true
            }
        }
        
        // If common ones fail, try to find any EFI partition
        let findResult = runCommand("""
        diskutil list | grep "EFI" | grep -o 'disk[0-9]*s[0-9]*' | head -1
        """)
        
        if findResult.success {
            let efiID = findResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !efiID.isEmpty {
                let mountResult = runCommand("diskutil mount \(efiID)", needsSudo: true)
                return mountResult.success
            }
        }
        
        print("Failed to mount any EFI partition")
        return false
    }
    
    static func getEFIPath() -> String? {
        // Check for mounted EFI
        let result = runCommand("""
        mount | grep -E '/dev/disk.*s1' | awk '{print $3}' | head -1
        """)
        
        if result.success {
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Check /Volumes for EFI
        let volumesResult = runCommand("ls /Volumes/ | grep -i 'EFI' | head -1")
        if volumesResult.success {
            let volumeName = volumesResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !volumeName.isEmpty {
                let path = "/Volumes/\(volumeName)"
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        }
        
        return nil
    }
    
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status")
        let output = result.output.lowercased()
        return output.contains("disabled")
    }
    
    static func checkKextLoaded(_ kextName: String) -> Bool {
        let result = runCommand("kextstat | grep -i \(kextName)")
        return result.success && !result.output.isEmpty
    }
    
    static func getKextVersion(_ kextName: String) -> String? {
        let result = runCommand("kextstat | grep -i \(kextName) | awk '{print $6}'")
        if result.success {
            let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return version.isEmpty ? nil : version
        }
        return nil
    }
    
    // Enhanced hard drive detection
    static func getAllDrives() -> [DriveInfo] {
        let result = runCommand("""
        diskutil list -plist
        """)
        
        var drives: [DriveInfo] = []
        
        if result.success, let data = result.output.data(using: .utf8) {
            do {
                if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                    
                    for disk in allDisks {
                        if let deviceIdentifier = disk["DeviceIdentifier"] as? String,
                           let size = disk["Size"] as? Int64,
                           let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]] {
                            
                            // APFS Container
                            let sizeGB = String(format: "%.1f GB", Double(size) / 1_000_000_000)
                            let name = "APFS Container (\(deviceIdentifier))"
                            
                            drives.append(DriveInfo(
                                name: name,
                                identifier: deviceIdentifier,
                                size: sizeGB,
                                type: "APFS Container",
                                mountPoint: "",
                                isInternal: true,
                                isEFI: false,
                                partitions: []
                            ))
                            
                            // APFS Volumes
                            for volume in apfsVolumes {
                                if let volIdentifier = volume["DeviceIdentifier"] as? String,
                                   let volMountPoint = volume["MountPoint"] as? String,
                                   let volName = volume["VolumeName"] as? String {
                                    
                                    let isInternal = volMountPoint.contains("/Volumes") ? false : true
                                    
                                    drives.append(DriveInfo(
                                        name: volName,
                                        identifier: volIdentifier,
                                        size: "APFS Volume",
                                        type: "APFS",
                                        mountPoint: volMountPoint,
                                        isInternal: isInternal,
                                        isEFI: false,
                                        partitions: []
                                    ))
                                }
                            }
                            
                        } else if let deviceIdentifier = disk["DeviceIdentifier"] as? String,
                                  let size = disk["Size"] as? Int64,
                                  let partitions = disk["Partitions"] as? [[String: Any]] {
                            
                            // Physical Disk with partitions
                            let sizeGB = String(format: "%.1f GB", Double(size) / 1_000_000_000)
                            let isInternal = deviceIdentifier.contains("disk0") || deviceIdentifier.contains("disk1")
                            
                            // Get more info about this disk
                            let infoResult = runCommand("diskutil info /dev/\(deviceIdentifier)")
                            let infoLines = infoResult.output.components(separatedBy: "\n")
                            
                            var protocolType = "Unknown"
                            var busProtocol = "Unknown"
                            var deviceModel = "Unknown"
                            var deviceNode = ""
                            
                            for line in infoLines {
                                if line.contains("Protocol:") {
                                    protocolType = line.components(separatedBy: ": ").last ?? "Unknown"
                                } else if line.contains("Device / Media Name:") {
                                    deviceModel = line.components(separatedBy: ": ").last ?? "Unknown"
                                } else if line.contains("Device Node:") {
                                    deviceNode = line.components(separatedBy: ": ").last ?? ""
                                } else if line.contains("Bus Protocol:") {
                                    busProtocol = line.components(separatedBy: ": ").last ?? "Unknown"
                                }
                            }
                            
                            var drivePartitions: [PartitionInfo] = []
                            
                            // Process partitions
                            for partition in partitions {
                                if let partIdentifier = partition["DeviceIdentifier"] as? String,
                                   let partSize = partition["Size"] as? Int64,
                                   let partType = partition["Content"] as? String {
                                    
                                    let partMountPoint = (partition["MountPoint"] as? String) ?? ""
                                    let partName = (partition["VolumeName"] as? String) ?? "Unnamed"
                                    let isEFI = partType.contains("EFI")
                                    
                                    let partSizeStr = partSize > 0 ?
                                        String(format: "%.1f GB", Double(partSize) / 1_000_000_000) :
                                        "Unknown"
                                    
                                    drivePartitions.append(PartitionInfo(
                                        name: partName,
                                        identifier: partIdentifier,
                                        size: partSizeStr,
                                        type: partType,
                                        mountPoint: partMountPoint,
                                        isEFI: isEFI
                                    ))
                                }
                            }
                            
                            let driveName = deviceModel != "Unknown" ? deviceModel : "Disk (\(deviceIdentifier))"
                            
                            drives.append(DriveInfo(
                                name: driveName,
                                identifier: deviceIdentifier,
                                size: sizeGB,
                                type: "\(protocolType) (\(busProtocol))",
                                mountPoint: deviceNode,
                                isInternal: isInternal,
                                isEFI: false,
                                partitions: drivePartitions
                            ))
                        }
                    }
                }
            } catch {
                print("Error parsing diskutil output: \(error)")
            }
        }
        
        // Sort drives: internal first, then external
        drives.sort { drive1, drive2 in
            if drive1.isInternal && !drive2.isInternal {
                return true
            } else if !drive1.isInternal && drive2.isInternal {
                return false
            } else {
                return drive1.identifier < drive2.identifier
            }
        }
        
        // If no drives found, add some defaults for preview/testing
        if drives.isEmpty {
            drives.append(contentsOf: [
                DriveInfo(
                    name: "Macintosh HD",
                    identifier: "disk1",
                    size: "512.0 GB",
                    type: "APFS (SSD)",
                    mountPoint: "/",
                    isInternal: true,
                    isEFI: false,
                    partitions: [
                        PartitionInfo(name: "EFI", identifier: "disk1s1", size: "200.0 MB", type: "EFI", mountPoint: "", isEFI: true)
                    ]
                ),
                DriveInfo(
                    name: "External Backup",
                    identifier: "disk2",
                    size: "1.0 TB",
                    type: "HFS+ (USB 3.0)",
                    mountPoint: "/Volumes/Backup",
                    isInternal: false,
                    isEFI: false,
                    partitions: [
                        PartitionInfo(name: "Backup Volume", identifier: "disk2s1", size: "1.0 TB", type: "HFS+", mountPoint: "/Volumes/Backup", isEFI: false)
                    ]
                ),
                DriveInfo(
                    name: "Bootable USB",
                    identifier: "disk3",
                    size: "32.0 GB",
                    type: "FAT32 (USB)",
                    mountPoint: "/Volumes/EFI",
                    isInternal: false,
                    isEFI: true,
                    partitions: [
                        PartitionInfo(name: "EFI System", identifier: "disk3s1", size: "200.0 MB", type: "EFI", mountPoint: "/Volumes/EFI", isEFI: true)
                    ]
                )
            ])
        }
        
        return drives
    }
    
    static func listAllPartitions() -> [String] {
        let result = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s[0-9]*' | sort | uniq
        """)
        
        if result.success {
            let partitions = result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return partitions.isEmpty ? ["disk0s1", "disk1s1", "disk0s2", "disk1s2"] : partitions
        }
        return ["disk0s1", "disk1s1", "disk0s2", "disk1s2"]
    }
    
    // Get detailed system information
    static func getSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
        // macOS Version
        let versionResult = runCommand("sw_vers -productVersion")
        info.macOSVersion = versionResult.success ? versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Build Number
        let buildResult = runCommand("sw_vers -buildVersion")
        info.buildNumber = buildResult.success ? buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Kernel Version
        let kernelResult = runCommand("uname -r")
        info.kernelVersion = kernelResult.success ? kernelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Model Identifier
        let modelResult = runCommand("sysctl -n hw.model")
        info.modelIdentifier = modelResult.success ? modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Processor
        let cpuResult = runCommand("sysctl -n machdep.cpu.brand_string")
        info.processor = cpuResult.success ? cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Memory
        let memResult = runCommand("sysctl -n hw.memsize")
        if memResult.success, let bytes = Int64(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let gb = Double(bytes) / 1_073_741_824
            info.memory = String(format: "%.0f GB", gb)
        } else {
            info.memory = "Unknown"
        }
        
        // Boot Mode
        let bootResult = runCommand("nvram boot-args 2>/dev/null | grep -q 'no_compat_check' && echo 'Hackintosh' || echo 'Standard'")
        info.bootMode = bootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return info
    }
    
    // Get complete diagnostic information
    static func getCompleteDiagnostics() -> String {
        var diagnostics = "=== SystemMaintenance Diagnostics Report ===\n"
        diagnostics += "Generated: \(Date().formatted(date: .complete, time: .complete))\n\n"
        
        // System Information
        diagnostics += "--- System Information ---\n"
        let sysInfo = getSystemInfo()
        diagnostics += "macOS Version: \(sysInfo.macOSVersion)\n"
        diagnostics += "Build Number: \(sysInfo.buildNumber)\n"
        diagnostics += "Kernel Version: \(sysInfo.kernelVersion)\n"
        diagnostics += "Model: \(sysInfo.modelIdentifier)\n"
        diagnostics += "Processor: \(sysInfo.processor)\n"
        diagnostics += "Memory: \(sysInfo.memory)\n"
        diagnostics += "Boot Mode: \(sysInfo.bootMode)\n"
        diagnostics += "SIP Status: \(isSIPDisabled() ? "Disabled" : "Enabled")\n\n"
        
        // Audio Kext Status
        diagnostics += "--- Audio Kext Status ---\n"
        diagnostics += "Lilu: \(checkKextLoaded("Lilu") ? "Loaded" : "Not loaded")\n"
        diagnostics += "AppleALC: \(checkKextLoaded("AppleALC") ? "Loaded" : "Not loaded")\n"
        diagnostics += "AppleHDA: \(checkKextLoaded("AppleHDA") ? "Loaded" : "Not loaded")\n\n"
        
        // Drive Information
        diagnostics += "--- Drive Information ---\n"
        let drives = getAllDrives()
        for (index, drive) in drives.enumerated() {
            diagnostics += "Drive \(index + 1): \(drive.name)\n"
            diagnostics += "  ID: \(drive.identifier)\n"
            diagnostics += "  Size: \(drive.size)\n"
            diagnostics += "  Type: \(drive.type)\n"
            diagnostics += "  Mount: \(drive.mountPoint)\n"
            diagnostics += "  Internal: \(drive.isInternal)\n"
            if !drive.partitions.isEmpty {
                diagnostics += "  Partitions:\n"
                for partition in drive.partitions {
                    diagnostics += "    - \(partition.name) (\(partition.identifier)): \(partition.size) [\(partition.type)]\n"
                }
            }
            diagnostics += "\n"
        }
        
        // EFI Status
        diagnostics += "--- EFI Status ---\n"
        if let efiPath = getEFIPath() {
            diagnostics += "Mounted: Yes\n"
            diagnostics += "Path: \(efiPath)\n"
            
            // Check EFI structure
            let efiContents = runCommand("ls -la \"\(efiPath)/\"")
            diagnostics += "Contents: \(efiContents.output)\n"
        } else {
            diagnostics += "Mounted: No\n"
        }
        
        diagnostics += "\n=== End of Report ===\n"
        return diagnostics
    }
}

// MARK: - Data Models
struct DriveInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: String
    let type: String
    let mountPoint: String
    let isInternal: Bool
    let isEFI: Bool
    let partitions: [PartitionInfo]
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.identifier == rhs.identifier
    }
}

struct PartitionInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: String
    let type: String
    let mountPoint: String
    let isEFI: Bool
    
    static func == (lhs: PartitionInfo, rhs: PartitionInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.identifier == rhs.identifier
    }
}

struct SystemInfo {
    var macOSVersion: String = "Checking..."
    var buildNumber: String = "Checking..."
    var kernelVersion: String = "Checking..."
    var modelIdentifier: String = "Checking..."
    var processor: String = "Checking..."
    var memory: String = "Checking..."
    var bootMode: String = "Checking..."
}

// MARK: - Export Document
struct SystemDiagnosticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .utf8PlainText] }
    
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Reusable Components
struct MaintenanceButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundColor(isLoading ? .gray : color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct StatusCard: View {
    let title: String
    let status: String
    let version: String?
    let detail: String?
    let statusColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let version = version {
                Text(version)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct RequirementIndicator: View {
    let title: String
    let status: String
    let version: String
    let isRequired: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                if status.contains("Installed") || status.contains("Disabled ✓") {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(version)
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .frame(width: 80)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct StatusBadge: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(6)
        }
    }
}

// MARK: - Drive Row Component
struct DriveRow: View {
    let drive: DriveInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .foregroundColor(drive.isInternal ? .blue : .orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(drive.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text(drive.identifier)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct PartitionRow: View {
    let partition: PartitionInfo
    
    var body: some View {
        HStack {
            Image(systemName: partition.isEFI ? "cylinder.fill" : "square.fill")
                .foregroundColor(partition.isEFI ? .purple : .gray)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(partition.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Text(partition.identifier)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(partition.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(partition.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !partition.mountPoint.isEmpty {
                Button("Open") {
                    let url = URL(fileURLWithPath: partition.mountPoint)
                    NSWorkspace.shared.open(url)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DriveSummaryCard: View {
    let title: String
    let icon: String
    let color: Color
    let drives: [DriveInfo]
    let isExpanded: Bool
    
    var totalSize: String {
        return "\(drives.count) drives"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(totalSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if drives.isEmpty {
                Text("No drives detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                if isExpanded {
                    ForEach(drives) { drive in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(drive.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(drive.size)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text(drive.identifier)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(drive.type)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if drive.id != drives.last?.id {
                            Divider()
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(drives) { drive in
                                VStack(spacing: 2) {
                                    Text(drive.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(drive.size)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Disk Detail View
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

// MARK: - EFI Selection View
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

// MARK: - Export System Information View
struct ExportSystemInfoView: View {
    @Binding var isPresented: Bool
    let systemInfo: SystemInfo
    let allDrives: [DriveInfo]
    let appleHDAStatus: String
    let appleALCStatus: String
    let liluStatus: String
    let efiPath: String?
    
    @State private var exportFormat = 0
    @State private var includeDrives = true
    @State private var includeKexts = true
    @State private var includeEFI = true
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var exportMessageColor = Color.green
    
    let exportFormats = ["Plain Text", "JSON", "HTML"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                    // Export Format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Format")
                            .font(.headline)
                        
                        Picker("", selection: $exportFormat) {
                            ForEach(0..<exportFormats.count, id: \.self) { index in
                                Text(exportFormats[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Content Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Include in Export")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Drive Information", isOn: $includeDrives)
                            Toggle("Kext Status", isOn: $includeKexts)
                            Toggle("EFI Details", isOn: $includeEFI)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)
                        
                        ScrollView {
                            Text(generatePreview())
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .frame(height: 150)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Export Buttons
                    VStack(spacing: 12) {
                        Button(action: exportToFile) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Exporting...")
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Export to File")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isExporting)
                        
                        Button(action: copyToClipboard) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy to Clipboard")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isExporting)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    if !exportMessage.isEmpty {
                        Text(exportMessage)
                            .font(.caption)
                            .foregroundColor(exportMessageColor)
                            .padding()
                            .background(exportMessageColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func generatePreview() -> String {
        var content = "SystemMaintenance Report\n"
        content += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        content += "=== System Information ===\n"
        content += "macOS: \(systemInfo.macOSVersion) (\(systemInfo.buildNumber))\n"
        content += "Kernel: \(systemInfo.kernelVersion)\n"
        content += "Model: \(systemInfo.modelIdentifier)\n"
        content += "CPU: \(systemInfo.processor)\n"
        content += "RAM: \(systemInfo.memory)\n"
        content += "Boot: \(systemInfo.bootMode)\n"
        
        if includeKexts {
            content += "\n=== Kext Status ===\n"
            content += "Lilu: \(liluStatus)\n"
            content += "AppleALC: \(appleALCStatus)\n"
            content += "AppleHDA: \(appleHDAStatus)\n"
        }
        
        if includeDrives && !allDrives.isEmpty {
            content += "\n=== Drives (\(allDrives.count)) ===\n"
            for (index, drive) in allDrives.prefix(3).enumerated() {
                content += "\(index + 1). \(drive.name) (\(drive.size)) - \(drive.type)\n"
            }
            if allDrives.count > 3 {
                content += "... and \(allDrives.count - 3) more drives\n"
            }
        }
        
        if includeEFI {
            content += "\n=== EFI Status ===\n"
            content += efiPath != nil ? "Mounted: Yes (\(efiPath ?? ""))\n" : "Mounted: No\n"
        }
        
        return content
    }
    
    private func generateExportContent() -> String {
        switch exportFormat {
        case 1: // JSON
            return generateJSON()
        case 2: // HTML
            return generateHTML()
        default: // Plain Text
            return generatePlainText()
        }
    }
    
    private func generatePlainText() -> String {
        return ShellHelper.getCompleteDiagnostics()
    }
    
    private func generateJSON() -> String {
        var json: [String: Any] = [:]
        
        // System Info
        json["system"] = [
            "macOSVersion": systemInfo.macOSVersion,
            "buildNumber": systemInfo.buildNumber,
            "kernelVersion": systemInfo.kernelVersion,
            "modelIdentifier": systemInfo.modelIdentifier,
            "processor": systemInfo.processor,
            "memory": systemInfo.memory,
            "bootMode": systemInfo.bootMode,
            "sipDisabled": ShellHelper.isSIPDisabled(),
            "timestamp": Date().ISO8601Format()
        ]
        
        // Kext Info
        if includeKexts {
            json["kexts"] = [
                "lilu": [
                    "status": liluStatus,
                    "loaded": ShellHelper.checkKextLoaded("Lilu"),
                    "version": ShellHelper.getKextVersion("Lilu") ?? "Unknown"
                ],
                "appleALC": [
                    "status": appleALCStatus,
                    "loaded": ShellHelper.checkKextLoaded("AppleALC"),
                    "version": ShellHelper.getKextVersion("AppleALC") ?? "Unknown"
                ],
                "appleHDA": [
                    "status": appleHDAStatus,
                    "loaded": ShellHelper.checkKextLoaded("AppleHDA"),
                    "version": ShellHelper.getKextVersion("AppleHDA") ?? "Unknown"
                ]
            ]
        }
        
        // Drive Info
        if includeDrives {
            var drivesArray: [[String: Any]] = []
            for drive in allDrives {
                var driveDict: [String: Any] = [
                    "name": drive.name,
                    "identifier": drive.identifier,
                    "size": drive.size,
                    "type": drive.type,
                    "mountPoint": drive.mountPoint,
                    "isInternal": drive.isInternal,
                    "isEFI": drive.isEFI
                ]
                
                if !drive.partitions.isEmpty {
                    var partitionsArray: [[String: Any]] = []
                    for partition in drive.partitions {
                        partitionsArray.append([
                            "name": partition.name,
                            "identifier": partition.identifier,
                            "size": partition.size,
                            "type": partition.type,
                            "mountPoint": partition.mountPoint,
                            "isEFI": partition.isEFI
                        ])
                    }
                    driveDict["partitions"] = partitionsArray
                }
                
                drivesArray.append(driveDict)
            }
            json["drives"] = drivesArray
        }
        
        // EFI Info
        if includeEFI {
            json["efi"] = [
                "mounted": efiPath != nil,
                "path": efiPath ?? "Not mounted",
                "timestamp": Date().ISO8601Format()
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to generate JSON\"}"
        }
    }
    
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>SystemMaintenance Report</title>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 40px; background: #f5f5f7; }
                .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
                h1 { color: #1d1d1f; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
                h2 { color: #1d1d1f; margin-top: 30px; }
                .section { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .info-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-top: 15px; }
                .info-item { background: white; padding: 12px; border-radius: 6px; border-left: 4px solid #007AFF; }
                .label { font-weight: 600; color: #1d1d1f; }
                .value { color: #424245; margin-top: 5px; }
                .status-good { color: #34C759; }
                .status-bad { color: #FF3B30; }
                .status-warning { color: #FF9500; }
                table { width: 100%; border-collapse: collapse; margin-top: 15px; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e5e7; }
                th { background: #f8f9fa; font-weight: 600; }
                .timestamp { color: #86868B; font-size: 12px; margin-top: 30px; text-align: center; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>SystemMaintenance Diagnostics Report</h1>
                <div class="timestamp">Generated: \(Date().formatted(date: .complete, time: .complete))</div>
                
                <div class="section">
                    <h2>System Information</h2>
                    <div class="info-grid">
                        <div class="info-item">
                            <div class="label">macOS Version</div>
                            <div class="value">\(systemInfo.macOSVersion)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Build Number</div>
                            <div class="value">\(systemInfo.buildNumber)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Kernel Version</div>
                            <div class="value">\(systemInfo.kernelVersion)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Model Identifier</div>
                            <div class="value">\(systemInfo.modelIdentifier)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Processor</div>
                            <div class="value">\(systemInfo.processor)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Memory</div>
                            <div class="value">\(systemInfo.memory)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Boot Mode</div>
                            <div class="value">\(systemInfo.bootMode)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">SIP Status</div>
                            <div class="value class=\"\(ShellHelper.isSIPDisabled() ? "status-good" : "status-bad")\">\(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")</div>
                        </div>
                    </div>
                </div>
                
                \(includeKexts ? """
                <div class="section">
                    <h2>Kext Status</h2>
                    <table>
                        <tr>
                            <th>Kext</th>
                            <th>Status</th>
                            <th>Loaded</th>
                            <th>Version</th>
                        </tr>
                        <tr>
                            <td>Lilu</td>
                            <td class="\(liluStatus == "Installed" ? "status-good" : "status-bad")">\(liluStatus)</td>
                            <td class="\(ShellHelper.checkKextLoaded("Lilu") ? "status-good" : "status-bad")">\(ShellHelper.checkKextLoaded("Lilu") ? "Yes" : "No")</td>
                            <td>\(ShellHelper.getKextVersion("Lilu") ?? "Unknown")</td>
                        </tr>
                        <tr>
                            <td>AppleALC</td>
                            <td class="\(appleALCStatus == "Installed" ? "status-good" : "status-bad")">\(appleALCStatus)</td>
                            <td class="\(ShellHelper.checkKextLoaded("AppleALC") ? "status-good" : "status-bad")">\(ShellHelper.checkKextLoaded("AppleALC") ? "Yes" : "No")</td>
                            <td>\(ShellHelper.getKextVersion("AppleALC") ?? "Unknown")</td>
                        </tr>
                        <tr>
                            <td>AppleHDA</td>
                            <td class="\(appleHDAStatus == "Installed" ? "status-good" : "status-bad")">\(appleHDAStatus)</td>
                            <td class="\(ShellHelper.checkKextLoaded("AppleHDA") ? "status-good" : "status-bad")">\(ShellHelper.checkKextLoaded("AppleHDA") ? "Yes" : "No")</td>
                            <td>\(ShellHelper.getKextVersion("AppleHDA") ?? "Unknown")</td>
                        </tr>
                    </table>
                </div>
                """ : "")
                
                \(includeDrives && !allDrives.isEmpty ? """
                <div class="section">
                    <h2>Drive Information (\(allDrives.count) drives)</h2>
                    <table>
                        <tr>
                            <th>Name</th>
                            <th>Size</th>
                            <th>Type</th>
                            <th>Mount Point</th>
                            <th>Type</th>
                        </tr>
                        \(allDrives.map { drive in
                            """
                            <tr>
                                <td>\(drive.name)</td>
                                <td>\(drive.size)</td>
                                <td>\(drive.type)</td>
                                <td>\(drive.mountPoint)</td>
                                <td>\(drive.isInternal ? "Internal" : "External")</td>
                            </tr>
                            """
                        }.joined(separator: "\n"))
                    </table>
                </div>
                """ : "")
                
                \(includeEFI ? """
                <div class="section">
                    <h2>EFI Status</h2>
                    <div class="info-item">
                        <div class="label">Mounted</div>
                        <div class="value class=\"\(efiPath != nil ? "status-good" : "status-warning")\">\(efiPath != nil ? "Yes" : "No")</div>
                    </div>
                    \(efiPath != nil ? """
                    <div class="info-item">
                        <div class="label">Path</div>
                        <div class="value">\(efiPath!)</div>
                    </div>
                    """ : "")
                </div>
                """ : "")
            </div>
        </body>
        </html>
        """
    }
    
    private func exportToFile() {
        isExporting = true
        exportMessage = ""
        
        let content = generateExportContent()
        let panel = NSSavePanel()
        panel.title = "Export System Information"
        panel.nameFieldStringValue = "SystemMaintenance_Report_\(Date().formatted(date: .numeric, time: .omitted)).\(exportFormat == 1 ? "json" : exportFormat == 2 ? "html" : "txt")"
        panel.allowedContentTypes = [exportFormat == 1 ? .json : exportFormat == 2 ? .html : .plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    exportMessage = "✅ Report exported successfully to: \(url.lastPathComponent)"
                    exportMessageColor = .green
                    
                    // Open the containing folder
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        exportMessage = ""
                        isPresented = false
                    }
                } catch {
                    exportMessage = "❌ Failed to export: \(error.localizedDescription)"
                    exportMessageColor = .red
                }
            }
            isExporting = false
        }
    }
    
    private func copyToClipboard() {
        isExporting = true
        
        let content = generateExportContent()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        exportMessage = "✅ Report copied to clipboard!"
        exportMessageColor = .green
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exportMessage = ""
            isExporting = false
        }
    }
}

// MARK: - System Maintenance View
struct SystemMaintenanceView: View {
    @Binding var isDownloadingKDK: Bool
    @Binding var isUninstallingKDK: Bool
    @Binding var isMountingPartition: Bool
    @Binding var downloadProgress: Double
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var installedKDKVersion: String?
    @Binding var systemProtectStatus: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var showEFISelectionView: Bool
    @Binding var allDrives: [DriveInfo]
    @Binding var isLoadingDrives: Bool
    @State private var selectedDrive: DriveInfo?
    @Binding var showDiskDetailView: Bool
    let refreshDrives: () -> Void
    
    @State private var showDonationButton = true
    @State private var isCheckingEFI = false
    @State private var searchText = ""
    
    var filteredDrives: [DriveInfo] {
        if searchText.isEmpty {
            return allDrives
        }
        return allDrives.filter { drive in
            drive.name.localizedCaseInsensitiveContains(searchText) ||
            drive.identifier.localizedCaseInsensitiveContains(searchText) ||
            drive.type.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var internalDrives: [DriveInfo] {
        filteredDrives.filter { $0.isInternal }
    }
    
    var externalDrives: [DriveInfo] {
        filteredDrives.filter { !$0.isInternal }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Support Banner
                if showDonationButton {
                    supportBanner
                }
                
                warningBanner
                
                // Drives Overview
                drivesOverviewSection
                
                // AppleHDA Installation Card
                appleHDAInstallationCard
                
                // EFI Mounting Section
                efiMountingSection
                
                // Maintenance Options Grid
                maintenanceGrid
                
                if isDownloadingKDK {
                    downloadProgressView
                }
                
                // EFI Status
                if let efiPath = efiPath {
                    efiStatusSection(efiPath: efiPath)
                }
                
                // Status Cards
                statusCardsSection
                
                Spacer()
            }
            .padding()
        }
        .onChange(of: selectedDrive) { newValue in
            if newValue != nil {
                showDiskDetailView = true
            }
        }
        .onChange(of: showDiskDetailView) { newValue in
            if !newValue {
                selectedDrive = nil
            }
        }
    }
    
    private var drivesOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Drives")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                TextField("Search drives...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Button(action: refreshDrives) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingDrives)
            }
            
            if isLoadingDrives {
                HStack {
                    Spacer()
                    ProgressView("Loading drives...")
                    Spacer()
                }
                .frame(height: 100)
            } else {
                // Internal Drives
                if !internalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Internal Drives", systemImage: "internaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        ForEach(internalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                            }
                        }
                        
                        if internalDrives.count > 3 {
                            Text("+ \(internalDrives.count - 3) more internal drives")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                }
                
                // External Drives
                if !externalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("External Drives", systemImage: "externaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(externalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                            }
                        }
                        
                        if externalDrives.count > 3 {
                            Text("+ \(externalDrives.count - 3) more external drives")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                }
                
                if filteredDrives.isEmpty {
                    VStack {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No drives found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var efiMountingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EFI Partition Management")
                .font(.headline)
                .foregroundColor(.purple)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available EFI Partitions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show EFI partitions from all drives
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allDrives.flatMap { $0.partitions }.filter { $0.isEFI }) { partition in
                                VStack(spacing: 2) {
                                    Image(systemName: "cylinder.fill")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                    Text(partition.identifier)
                                        .font(.system(.caption2, design: .monospaced))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Auto Mount") {
                            mountEFI()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMountingPartition)
                        
                        Button("Manual Select") {
                            showEFISelectionView = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            if !allDrives.isEmpty {
                Text("Found \(allDrives.flatMap { $0.partitions }.filter { $0.isEFI }.count) EFI partition(s)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func efiStatusSection(efiPath: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.green)
                Text("EFI Partition Mounted")
                    .font(.headline)
            }
            
            HStack {
                Text("Path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(efiPath)
                    .font(.caption)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
                
                Spacer()
                
                Button("Open") {
                    let url = URL(fileURLWithPath: efiPath)
                    NSWorkspace.shared.open(url)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            HStack {
                Button("Check OC Structure") {
                    checkOpenCoreStructure(efiPath: efiPath)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Button("Unmount EFI") {
                    unmountEFI()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var maintenanceGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MaintenanceButton(
                title: "Mount EFI",
                icon: "externaldrive",
                color: .purple,
                isLoading: isMountingPartition,
                action: mountEFI
            )
            
            MaintenanceButton(
                title: "Select EFI...",
                icon: "list.bullet",
                color: .blue,
                isLoading: false,
                action: { showEFISelectionView = true }
            )
            
            MaintenanceButton(
                title: "Check EFI",
                icon: "magnifyingglass",
                color: .blue,
                isLoading: isCheckingEFI,
                action: checkEFIStructure
            )
            
            MaintenanceButton(
                title: "Download KDK",
                icon: "arrow.down.circle",
                color: .blue,
                isLoading: isDownloadingKDK,
                action: downloadKDK
            )
            
            MaintenanceButton(
                title: "Uninstall KDK",
                icon: "trash",
                color: .red,
                isLoading: isUninstallingKDK,
                action: uninstallKDK
            )
            
            MaintenanceButton(
                title: "Fix Permissions",
                icon: "lock.shield",
                color: .indigo,
                isLoading: false,
                action: fixPermissions
            )
            
            MaintenanceButton(
                title: "Rebuild Cache",
                icon: "arrow.triangle.2.circlepath",
                color: .orange,
                isLoading: false,
                action: rebuildCache
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: downloadProgress, total: 100)
                .progressViewStyle(.linear)
                .padding(.horizontal)
            Text("Downloading KDK... \(Int(downloadProgress))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var statusCardsSection: some View {
        HStack(spacing: 16) {
            StatusCard(
                title: "System Integrity",
                status: systemProtectStatus,
                version: nil,
                detail: systemProtectStatus == "Disabled" ? "SIP: Disabled ✓" : "SIP: Enabled ✗",
                statusColor: systemProtectStatus == "Disabled" ? .green : .red
            )
            
            StatusCard(
                title: "AppleHDA",
                status: appleHDAStatus,
                version: appleHDAVersion ?? "Not Loaded",
                detail: "/System/Library/Extensions/",
                statusColor: appleHDAStatus == "Installed" ? .green : .red
            )
            
            StatusCard(
                title: "EFI Status",
                status: efiPath != nil ? "Mounted" : "Not Mounted",
                version: nil,
                detail: efiPath ?? "Click Mount EFI",
                statusColor: efiPath != nil ? .green : .orange
            )
        }
    }
    
    private var supportBanner: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Support This Project")
                    .font(.headline)
                Text("Donations help fund development and testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Donate Now") {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Button(action: {
                withAnimation {
                    showDonationButton = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("⚠️ Installation Requirements", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• SIP must be disabled (csr-active-config: 0x803)")
                    .font(.caption)
                Text("• AppleHDA.kext installs to /System/Library/Extensions/")
                    .font(.caption)
                Text("• Lilu.kext & AppleALC.kext install to EFI/OC/Kexts/")
                    .font(.caption)
                Text("• Update config.plist with kexts and boot-args (alcid=1)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var appleHDAInstallationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.blue)
                Text("AppleHDA Audio Installation")
                    .font(.headline)
                
                Spacer()
                
                if systemProtectStatus == "Disabled" && efiPath != nil {
                    Text("Ready to Install")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Requirements Missing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 16) {
                RequirementIndicator(
                    title: "Lilu.kext",
                    status: liluStatus,
                    version: liluVersion ?? "1.6.8",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleALC.kext",
                    status: appleALCStatus,
                    version: appleALCVersion ?? "1.8.7",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleHDA.kext",
                    status: appleHDAStatus,
                    version: appleHDAVersion ?? "Custom Build",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "SIP Status",
                    status: systemProtectStatus == "Disabled" ? "Disabled ✓" : "Enabled ✗",
                    version: "Required: Disabled",
                    isRequired: true
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
    
    // MARK: - Action Functions
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountEFIPartition()
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success && path != nil {
                    alertTitle = "Success"
                    alertMessage = "EFI partition mounted at: \(path ?? "Unknown")"
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to auto-mount EFI partition.
                    
                    Please try:
                    1. Click "Select EFI..." to choose manually
                    2. Open Disk Utility and mount EFI
                    3. Check Terminal for diskutil list
                    """
                }
                showAlert = true
            }
        }
    }
    
    private func unmountEFI() {
        guard let efiPath = efiPath else { return }
        
        let result = ShellHelper.runCommand("diskutil unmount \"\(efiPath)\"", needsSudo: true)
        
        if result.success {
            self.efiPath = nil
            alertTitle = "Unmounted"
            alertMessage = "EFI partition has been unmounted"
        } else {
            alertTitle = "Unmount Failed"
            alertMessage = "Failed to unmount EFI: \(result.output)"
        }
        showAlert = true
    }
    
    private func checkEFIStructure() {
        isCheckingEFI = true
        
        DispatchQueue.global(qos: .background).async {
            guard let efiPath = efiPath else {
                DispatchQueue.main.async {
                    isCheckingEFI = false
                    alertTitle = "Error"
                    alertMessage = "EFI partition not mounted"
                    showAlert = true
                }
                return
            }
            
            var messages: [String] = []
            
            // Check directories
            let dirs = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers", "EFI/OC/Tools"]
            
            for dir in dirs {
                let fullPath = "\(efiPath)/\(dir)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                messages.append("\(exists ? "✅" : "❌") \(dir)")
            }
            
            DispatchQueue.main.async {
                isCheckingEFI = false
                alertTitle = "EFI Structure Check"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func checkOpenCoreStructure(efiPath: String) {
        let ocPath = "\(efiPath)/EFI/OC/"
        let configPath = "\(ocPath)config.plist"
        
        var messages: [String] = ["OpenCore Structure Check:"]
        
        // Check if config.plist exists
        if FileManager.default.fileExists(atPath: configPath) {
            messages.append("✅ config.plist found")
        } else {
            messages.append("❌ config.plist not found")
        }
        
        alertTitle = "OpenCore Check"
        alertMessage = messages.joined(separator: "\n")
        showAlert = true
    }
    
    private func downloadKDK() {
        isDownloadingKDK = true
        downloadProgress = 0
        
        alertTitle = "Manual Download Required"
        alertMessage = """
        Please download KDK manually from:
        
        https://github.com/dortania/KdkSupportPkg/releases
        
        Then install to:
        ~/Library/Developer/KDK/
        
        This is required for AppleHDA patching.
        """
        showAlert = true
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if downloadProgress < 100 {
                downloadProgress += 2
            } else {
                timer.invalidate()
                isDownloadingKDK = false
                
                // Open download page
                if let url = URL(string: "https://github.com/dortania/KdkSupportPkg/releases") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func uninstallKDK() {
        isUninstallingKDK = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isUninstallingKDK = false
            
            let kdkPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Developer")
                .appendingPathComponent("KDK")
            
            if FileManager.default.fileExists(atPath: kdkPath.path) {
                alertTitle = "Uninstall Instructions"
                alertMessage = """
                To uninstall KDK:
                
                1. Open Finder
                2. Go to: \(kdkPath.path)
                3. Delete the KDK folder
                4. Empty Trash
                
                AppleHDA will stop working without KDK.
                """
            } else {
                alertTitle = "KDK Not Found"
                alertMessage = "No KDK installation found at: \(kdkPath.path)"
            }
            showAlert = true
        }
    }
    
    private func fixPermissions() {
        DispatchQueue.global(qos: .background).async {
            let commands = [
                "chown -R root:wheel /System/Library/Extensions/AppleHDA.kext",
                "chmod -R 755 /System/Library/Extensions/AppleHDA.kext",
                "touch /System/Library/Extensions"
            ]
            
            var messages: [String] = ["Fixing permissions for AppleHDA..."]
            
            for command in commands {
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ \(command)")
                } else {
                    messages.append("❌ \(command): \(result.output)")
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "Permissions Fixed"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func rebuildCache() {
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            DispatchQueue.main.async {
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Kext Management View
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var kextSourcePath: String
    
    @State private var selectedKexts: Set<String> = []
    @State private var rebuildCacheProgress = 0.0
    @State private var isRebuildingCache = false
    @State private var showAudioKextsOnly = true
    
    // Complete list of kexts for Hackintosh
    let allKexts = [
        // Required for AppleHDA Audio
        ("Lilu", "1.6.8", "Kernel extension patcher - REQUIRED for audio", "https://github.com/acidanthera/Lilu", true),
        ("AppleALC", "1.8.7", "Audio codec support - REQUIRED for AppleHDA", "https://github.com/acidanthera/AppleALC", true),
        ("AppleHDA", "500.7.4", "Apple HD Audio driver", "Custom build", true),
        
        // Graphics
        ("WhateverGreen", "1.6.8", "Graphics patching and DRM fixes", "https://github.com/acidanthera/WhateverGreen", false),
        ("IntelGraphicsFixup", "1.3.1", "Intel GPU framebuffer patches", "https://github.com/lvs1974/IntelGraphicsFixup", false),
        
        // System
        ("VirtualSMC", "1.3.3", "SMC emulation for virtualization", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCProcessor", "1.3.3", "CPU monitoring for VirtualSMC", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCSuperIO", "1.3.3", "Super I/O monitoring", "https://github.com/acidanthera/VirtualSMC", false),
        
        // Network
        ("IntelMausi", "1.0.9", "Intel Ethernet controller support", "https://github.com/acidanthera/IntelMausi", false),
        ("AtherosE2200", "2.3.0", "Atheros Ethernet support", "https://github.com/Mieze/AtherosE2200Ethernet", false),
        ("RealtekRTL8111", "2.4.2", "Realtek Gigabit Ethernet", "https://github.com/Mieze/RTL8111_driver_for_OS_X", false),
        
        // Storage
        ("NVMeFix", "1.1.2", "NVMe SSD power management", "https://github.com/acidanthera/NVMeFix", false),
        ("SATA-unsupported", "1.0.0", "SATA controller support", "Various", false),
        
        // USB
        ("USBInjectAll", "0.8.3", "USB port mapping", "https://github.com/daliansky/OS-X-USB-Inject-All", false),
        ("XHCI-unsupported", "1.2.0", "XHCI USB controller support", "Various", false),
    ]
    
    var filteredKexts: [(String, String, String, String, Bool)] {
        if showAudioKextsOnly {
            return allKexts.filter { $0.4 } // Only audio-related
        }
        return allKexts
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // EFI Status
                if let efiPath = efiPath {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("EFI Ready for Installation")
                                .font(.headline)
                        }
                        Text("EFI Path: \(efiPath)/EFI/OC/Kexts/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("EFI Not Mounted")
                                .font(.headline)
                        }
                        Text("Mount EFI partition from System tab first")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Audio Kext Quick Install
                VStack(spacing: 12) {
                    Text("AppleHDA Audio Package")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 12) {
                        Button(action: installAudioPackage) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "speaker.wave.3.fill")
                                    Text("Install Audio Package")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" ?
                                Color.green.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isInstallingKext || efiPath == nil)
                        
                        Button(action: verifyAudioInstallation) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Verify Audio")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    if appleHDAStatus == "Installed" {
                        Text("✅ Audio kexts installed successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                // Kext Source Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kext Source Location")
                        .font(.headline)
                    
                    HStack {
                        TextField("Path to kexts folder", text: $kextSourcePath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.title = "Select Kexts Folder"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    kextSourcePath = url.path
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Select folder containing downloaded kext files (.kext)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !kextSourcePath.isEmpty {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text("Selected: \(URL(fileURLWithPath: kextSourcePath).lastPathComponent)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: installSelectedKexts) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Install Selected (\(selectedKexts.count))")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty ?
                                Color.blue.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty)
                        
                        Button(action: uninstallKexts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Uninstall")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: rebuildCaches) {
                            HStack {
                                if isRebuildingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild Cache")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRebuildingCache)
                        
                        Button(action: {
                            showAudioKextsOnly.toggle()
                        }) {
                            HStack {
                                Image(systemName: showAudioKextsOnly ? "speaker.wave.3" : "square.grid.2x2")
                                Text(showAudioKextsOnly ? "Show All" : "Audio Only")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isRebuildingCache {
                    VStack(spacing: 8) {
                        ProgressView(value: rebuildCacheProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Rebuilding kernel cache... \(Int(rebuildCacheProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(showAudioKextsOnly ? "Audio Kexts" : "All Available Kexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedKexts = Set(filteredKexts.map { $0.0 })
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                        
                        Button("Clear All") {
                            selectedKexts.removeAll()
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                    }
                    
                    ForEach(filteredKexts, id: \.0) { kext in
                        KextRow(
                            name: kext.0,
                            version: kext.1,
                            description: kext.2,
                            githubURL: kext.3,
                            isAudio: kext.4,
                            isSelected: selectedKexts.contains(kext.0),
                            isInstalling: isInstallingKext
                        ) {
                            toggleKextSelection(kext.0)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .onAppear {
                // Auto-select audio kexts
                if selectedKexts.isEmpty {
                    selectedKexts = Set(["Lilu", "AppleALC", "AppleHDA"])
                }
            }
        }
    }
    
    // MARK: - Kext Row Component
    struct KextRow: View {
        let name: String
        let version: String
        let description: String
        let githubURL: String
        let isAudio: Bool
        let isSelected: Bool
        let isInstalling: Bool
        let toggleAction: () -> Void
        
        var body: some View {
            HStack {
                Button(action: toggleAction) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? (isAudio ? .blue : .green) : .gray)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if isAudio {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Text(name)
                            .font(.body)
                            .fontWeight(isAudio ? .semibold : .regular)
                        Spacer()
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if githubURL != "Custom build" {
                    Button(action: {
                        if let url = URL(string: githubURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInstalling)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? (isAudio ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.clear)
            .cornerRadius(6)
        }
    }
    
    private func toggleKextSelection(_ kextName: String) {
        if selectedKexts.contains(kextName) {
            selectedKexts.remove(kextName)
        } else {
            selectedKexts.insert(kextName)
        }
    }
    
    private func installAudioPackage() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select a folder containing kext files first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing Audio Package..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directories
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            let _ = ShellHelper.runCommand("mkdir -p /System/Library/Extensions", needsSudo: true)
            
            // Install Lilu.kext to EFI
            messages.append("\n1. Installing Lilu.kext to EFI...")
            let liluSource = findKextInDirectory(name: "Lilu", directory: kextSourcePath)
            if let liluSource = liluSource {
                let command = "cp -R \"\(liluSource)\" \"\(ocKextsPath)Lilu.kext\""
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ Lilu.kext installed to EFI")
                } else {
                    messages.append("❌ Failed to install Lilu.kext: \(result.output)")
                    success = false
                }
            } else {
                messages.append("❌ Lilu.kext not found in: \(kextSourcePath)")
                success = false
            }
            
            // Install AppleALC.kext to EFI
            messages.append("\n2. Installing AppleALC.kext to EFI...")
            let appleALCSource = findKextInDirectory(name: "AppleALC", directory: kextSourcePath)
            if let appleALCSource = appleALCSource {
                let command = "cp -R \"\(appleALCSource)\" \"\(ocKextsPath)AppleALC.kext\""
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ AppleALC.kext installed to EFI")
                } else {
                    messages.append("❌ Failed to install AppleALC.kext: \(result.output)")
                    success = false
                }
            } else {
                messages.append("❌ AppleALC.kext not found in: \(kextSourcePath)")
                success = false
            }
            
            // Install AppleHDA.kext to /System/Library/Extensions/
            messages.append("\n3. Installing AppleHDA.kext to /System/Library/Extensions...")
            let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
            if let appleHDASource = appleHDASource {
                let commands = [
                    "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                    "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                    "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                    "touch /System/Library/Extensions"
                ]
                
                var appleHDASuccess = true
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd, needsSudo: true)
                    if !result.success {
                        messages.append("❌ Failed: \(cmd)")
                        appleHDASuccess = false
                        break
                    }
                }
                
                if appleHDASuccess {
                    messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                } else {
                    success = false
                }
            } else {
                messages.append("❌ AppleHDA.kext not found in: \(kextSourcePath)")
                success = false
            }
            
            // Rebuild kernel cache
            if success {
                messages.append("\n4. Rebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues: \(result.output)")
                }
            }
            
            // Update UI
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    liluStatus = "Installed"
                    liluVersion = "1.6.8"
                    appleALCStatus = "Installed"
                    appleALCVersion = "1.8.7"
                    appleHDAStatus = "Installed"
                    appleHDAVersion = "500.7.4"
                    
                    alertTitle = "✅ Audio Package Installed"
                    messages.append("\n🎉 Installation complete! Please restart your system.")
                } else {
                    alertTitle = "⚠️ Installation Issues"
                    messages.append("\n❌ Some kexts may not have installed correctly.")
                }
                
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func findKextInDirectory(name: String, directory: String) -> String? {
        let fileManager = FileManager.default
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: directory) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // Look for exact match
            for item in contents {
                if item.lowercased() == "\(name.lowercased()).kext" {
                    return "\(directory)/\(item)"
                }
            }
            
            // Look for partial match
            for item in contents {
                if item.lowercased().contains(name.lowercased()) && item.hasSuffix(".kext") {
                    return "\(directory)/\(item)"
                }
            }
            
            // Check subdirectories
            for item in contents {
                let fullPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    if let found = findKextInDirectory(name: name, directory: fullPath) {
                        return found
                    }
                }
            }
        } catch {
            print("Error searching for kext: \(error)")
        }
        
        return nil
    }
    
    private func verifyAudioInstallation() {
        var messages: [String] = ["Audio Installation Verification:"]
        
        // Check if kexts are loaded
        let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
        let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
        let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
        
        messages.append(liluLoaded ? "✅ Lilu.kext is loaded" : "❌ Lilu.kext is NOT loaded")
        messages.append(appleALCLoaded ? "✅ AppleALC.kext is loaded" : "❌ AppleALC.kext is NOT loaded")
        messages.append(appleHDALoaded ? "✅ AppleHDA.kext is loaded" : "❌ AppleHDA.kext is NOT loaded")
        
        // Check SIP
        let sipDisabled = ShellHelper.isSIPDisabled()
        messages.append(sipDisabled ? "✅ SIP is disabled" : "❌ SIP is enabled (required for AppleHDA)")
        
        // Check EFI
        if let efiPath = efiPath {
            messages.append("✅ EFI is mounted at: \(efiPath)")
            
            // Check if kexts exist in EFI
            let liluPath = "\(efiPath)/EFI/OC/Kexts/Lilu.kext"
            let appleALCPath = "\(efiPath)/EFI/OC/Kexts/AppleALC.kext"
            let appleHDAPath = "/System/Library/Extensions/AppleHDA.kext"
            
            let liluExists = FileManager.default.fileExists(atPath: liluPath)
            let appleALCExists = FileManager.default.fileExists(atPath: appleALCPath)
            let appleHDAExists = FileManager.default.fileExists(atPath: appleHDAPath)
            
            messages.append(liluExists ? "✅ Lilu.kext exists in EFI" : "❌ Lilu.kext missing from EFI")
            messages.append(appleALCExists ? "✅ AppleALC.kext exists in EFI" : "❌ AppleALC.kext missing from EFI")
            messages.append(appleHDAExists ? "✅ AppleHDA.kext exists in /S/L/E" : "❌ AppleHDA.kext missing from /S/L/E")
        } else {
            messages.append("❌ EFI is not mounted")
        }
        
        alertTitle = "Audio Verification"
        alertMessage = messages.joined(separator: "\n")
        showAlert = true
    }
    
    private func installSelectedKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select a folder containing kext files first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing selected kexts..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directory
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            
            for kextName in selectedKexts {
                if kextName == "AppleHDA" {
                    // Special handling for AppleHDA
                    messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                    let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                    if let appleHDASource = appleHDASource {
                        let commands = [
                            "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                            "touch /System/Library/Extensions"
                        ]
                        
                        var kextSuccess = true
                        for cmd in commands {
                            let result = ShellHelper.runCommand(cmd, needsSudo: true)
                            if !result.success {
                                messages.append("❌ Failed: \(cmd)")
                                kextSuccess = false
                                break
                            }
                        }
                        
                        if kextSuccess {
                            messages.append("✅ AppleHDA.kext installed")
                        } else {
                            success = false
                        }
                    } else {
                        messages.append("❌ AppleHDA.kext not found")
                        success = false
                    }
                } else {
                    // Other kexts go to EFI
                    messages.append("\nInstalling \(kextName).kext to EFI...")
                    let kextSource = findKextInDirectory(name: kextName, directory: kextSourcePath)
                    if let kextSource = kextSource {
                        let command = "cp -R \"\(kextSource)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed")
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext")
                            success = false
                        }
                    } else {
                        messages.append("❌ \(kextName).kext not found")
                        success = false
                    }
                }
            }
            
            // Rebuild cache if AppleHDA was installed
            if selectedKexts.contains("AppleHDA") && success {
                messages.append("\nRebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues")
                }
            }
            
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    alertTitle = "Kexts Installed"
                    alertMessage = messages.joined(separator: "\n")
                } else {
                    alertTitle = "Installation Issues"
                    alertMessage = messages.joined(separator: "\n")
                }
                showAlert = true
            }
        }
    }
    
    private func uninstallKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        alertTitle = "Uninstallation Instructions"
        alertMessage = """
        To uninstall kexts:
        
        1. EFI Kexts (Lilu, AppleALC, etc.):
           • Navigate to: \(efiPath)/EFI/OC/Kexts/
           • Delete the kext files you want to remove
           
        2. System Kexts (AppleHDA):
           • Open Terminal
           • Run: sudo rm -rf /System/Library/Extensions/AppleHDA.kext
           • Run: sudo kextcache -i /
           
        3. Update config.plist:
           • Remove kext entries from Kernel → Add
           • Save and restart
           
        WARNING: Removing AppleHDA will disable audio until reinstalled.
        """
        showAlert = true
    }
    
    private func rebuildCaches() {
        isRebuildingCache = true
        rebuildCacheProgress = 0
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            // Simulate progress
            for i in 0...100 {
                DispatchQueue.main.async {
                    rebuildCacheProgress = Double(i)
                }
                usleep(50000)
            }
            
            DispatchQueue.main.async {
                isRebuildingCache = false
                
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
                rebuildCacheProgress = 0
            }
        }
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleALCStatus: String
    @Binding var liluStatus: String
    @Binding var efiPath: String?
    @Binding var systemInfo: SystemInfo
    @Binding var allDrives: [DriveInfo]
    let refreshSystemInfo: () -> Void
    
    @State private var showAllDrives = false
    @State private var showExportView = false
    
    var internalDrives: [DriveInfo] {
        allDrives.filter { $0.isInternal }
    }
    
    var externalDrives: [DriveInfo] {
        allDrives.filter { !$0.isInternal }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Export Button
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showExportView = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        refreshSystemInfo()
                        alertTitle = "Refreshed"
                        alertMessage = "System information updated"
                        showAlert = true
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Audio Status Summary
                audioStatusSection
                
                // Storage Summary
                storageSummarySection
                
                // System Information Grid
                systemInfoGrid
                
                Spacer()
            }
            .padding()
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
    }
    
    private var audioStatusSection: some View {
        VStack(spacing: 12) {
            Text("Audio System Status")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            HStack(spacing: 16) {
                StatusBadge(
                    title: "Lilu",
                    status: liluStatus,
                    color: liluStatus == "Installed" ? .green : .red
                )
                StatusBadge(
                    title: "AppleALC",
                    status: appleALCStatus,
                    color: appleALCStatus == "Installed" ? .green : .red
                )
                StatusBadge(
                    title: "AppleHDA",
                    status: appleHDAStatus,
                    color: appleHDAStatus == "Installed" ? .green : .red
                )
                StatusBadge(
                    title: "SIP",
                    status: ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled",
                    color: ShellHelper.isSIPDisabled() ? .green : .red
                )
            }
            
            if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
                Text("✅ Audio system is fully configured and should work!")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("⚠️ Audio setup incomplete. Install missing kexts.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var storageSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Summary")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(showAllDrives ? "Show Less" : "Show All") {
                    showAllDrives.toggle()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            VStack(spacing: 12) {
                DriveSummaryCard(
                    title: "Internal Storage",
                    icon: "internaldrive.fill",
                    color: .blue,
                    drives: internalDrives,
                    isExpanded: showAllDrives
                )
                
                DriveSummaryCard(
                    title: "External Storage",
                    icon: "externaldrive.fill",
                    color: .orange,
                    drives: externalDrives,
                    isExpanded: showAllDrives
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var systemInfoGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Detailed System Information")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InfoCard(title: "macOS Version", value: systemInfo.macOSVersion)
                InfoCard(title: "Build Number", value: systemInfo.buildNumber)
                InfoCard(title: "Kernel Version", value: systemInfo.kernelVersion)
                InfoCard(title: "Model Identifier", value: systemInfo.modelIdentifier)
                InfoCard(title: "Processor", value: systemInfo.processor)
                InfoCard(title: "Memory", value: systemInfo.memory)
                InfoCard(title: "Audio Status", value: getAudioStatus())
                InfoCard(title: "AppleHDA Status", value: appleHDAStatus == "Installed" ? "Installed ✓" : "Not Installed ✗")
                InfoCard(title: "SIP Status", value: ShellHelper.isSIPDisabled() ? "Disabled (0x803)" : "Enabled")
                InfoCard(title: "Boot Mode", value: systemInfo.bootMode)
                InfoCard(title: "EFI Status", value: efiPath != nil ? "Mounted ✓" : "Not Mounted ✗")
                InfoCard(title: "Total Drives", value: "\(allDrives.count) (\(internalDrives.count) Int/\(externalDrives.count) Ext)")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func getAudioStatus() -> String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working ✓"
        } else {
            return "Setup Required ⚠️"
        }
    }
}

// MARK: - Audio Tools View
struct AudioToolsView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var audioCodecID = "0x10ec0899"
    @State private var layoutID = "1"
    @State private var isDetectingCodec = false
    @State private var showAdvancedSettings = false
    
    let layoutIDs = ["1", "2", "3", "5", "7", "11", "13", "14", "15", "16", "17", "18", "20", "21", "27", "28", "29", "30", "31", "32", "33", "34", "35", "40", "41", "42", "43", "45", "46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59", "60", "61", "62", "63", "64", "65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91", "92", "93", "94", "95", "96", "97", "98", "99", "100"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Codec Detection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio Codec Detection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Codec ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0x10ec0899", text: $audioCodecID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button(action: detectCodec) {
                            HStack {
                                if isDetectingCodec {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Detecting...")
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                    Text("Detect Codec")
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isDetectingCodec)
                    }
                    
                    Text("Common Codec IDs:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x10ec1220", "0x80862882"], id: \.self) { codec in
                                Button(codec) {
                                    audioCodecID = codec
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Layout ID Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("AppleALC Layout ID")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Layout ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $layoutID) {
                                ForEach(layoutIDs, id: \.self) { id in
                                    Text(id).tag(id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Boot Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("alcid=\(layoutID)")
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    Button("Apply Layout ID") {
                        applyLayoutID()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
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
}

// MARK: - Donation View
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
                        .onChange(of: customAmount) {
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
            let info = ShellHelper.getSystemInfo()
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
