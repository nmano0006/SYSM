import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - Enhanced Shell Command Helper
class ShellHelper {
    static let shared = ShellHelper()
    
    private init() {}
    
    // MARK: - Core Command Execution
    func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, error: String, success: Bool) {
        print("🔧 Executing command: \(command)")
        print("🔑 Needs sudo: \(needsSudo)")
        
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if needsSudo {
            // Use AppleScript for GUI sudo prompt
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = """
            do shell script "\(escapedCommand)" 
            with administrator privileges 
            with prompt "SystemMaintenance needs administrator access" 
            without altering line endings
            """
            
            task.arguments = ["-c", "osascript -e '\(appleScript)'"]
            task.launchPath = "/bin/zsh"
        } else {
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
        }
        
        do {
            try task.run()
        } catch {
            print("❌ Command execution error: \(error)")
            return ("", "Process execution error: \(error)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        if !success && !errorOutput.isEmpty {
            print("⚠️ Command error output: \(errorOutput)")
        }
        
        if !output.isEmpty {
            print("📝 Command output: \(output)")
        }
        
        return (output, errorOutput, success)
    }
    
    // MARK: - Enhanced USB Drive Detection
    func findUSBDrives() -> [String] {
        print("🔍 Starting USB drive detection...")
        
        var usbDrives: Set<String> = []
        
        // Method 1: Check diskutil for USB identifiers
        let diskutilResult = runCommand("""
        diskutil list | grep -oE 'disk[0-9]+' | while read disk; do
            diskutil info /dev/$disk 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' >/dev/null && echo $disk
        done
        """)
        
        if diskutilResult.success && !diskutilResult.output.isEmpty {
            let drives = diskutilResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            print("📋 Found via diskutil: \(drives)")
            drives.forEach { usbDrives.insert($0) }
        }
        
        // Method 2: Check system_profiler
        let spResult = runCommand("""
        system_profiler SPUSBDataType 2>/dev/null | grep -A 5 "BSD Name:" | grep "disk" | awk -F': ' '{print $2}' | sort -u
        """)
        
        if spResult.success && !spResult.output.isEmpty {
            let drives = spResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            print("📋 Found via system_profiler: \(drives)")
            drives.forEach { usbDrives.insert($0) }
        }
        
        // Method 3: Check mount points for USB drives
        let mountResult = runCommand("""
        mount | grep -E '/dev/disk[0-9]+' | awk '{print $1}' | sed 's|/dev/||' | while read disk; do
            diskutil info /dev/$disk 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB' >/dev/null && echo $disk
        done
        """)
        
        if mountResult.success && !mountResult.output.isEmpty {
            let drives = mountResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            print("📋 Found via mount: \(drives)")
            drives.forEach { usbDrives.insert($0) }
        }
        
        // Method 4: Direct check for common USB disk identifiers
        for i in 2...20 { // Check disk2 to disk20 (USB usually starts at disk2)
            let diskName = "disk\(i)"
            let checkResult = runCommand("""
            diskutil info /dev/\(diskName) 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' >/dev/null && echo \(diskName)
            """)
            
            if checkResult.success && !checkResult.output.isEmpty {
                print("📋 Found via direct check: \(diskName)")
                usbDrives.insert(diskName)
            }
        }
        
        let result = Array(usbDrives).sorted()
        print("✅ Total USB drives found: \(result.count) - \(result)")
        return result
    }
    
    // MARK: - Enhanced Drive Mounting
    func mountDrive(identifier: String) -> (success: Bool, mountPoint: String?) {
        print("📌 Attempting to mount \(identifier)")
        
        // First check if already mounted
        let checkResult = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep 'Mount Point' | awk -F': ' '{print $2}'")
        
        if checkResult.success {
            let mountPoint = checkResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mountPoint.isEmpty && mountPoint != "(Not Mounted)" {
                print("✅ Already mounted at: \(mountPoint)")
                return (true, mountPoint)
            }
        }
        
        // Try to mount
        let mountResult = runCommand("diskutil mount /dev/\(identifier)", needsSudo: true)
        
        if mountResult.success {
            print("✅ Mount command succeeded")
            
            // Get the actual mount point
            sleep(1) // Give system time to mount
            
            let verifyResult = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep 'Mount Point' | awk -F': ' '{print $2}'")
            
            if verifyResult.success {
                let mountPoint = verifyResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !mountPoint.isEmpty && mountPoint != "(Not Mounted)" {
                    print("✅ Successfully mounted at: \(mountPoint)")
                    return (true, mountPoint)
                }
            }
            
            // Alternative check
            let altCheck = runCommand("mount | grep \"/dev/\(identifier)\" | awk '{print $3}'")
            if altCheck.success && !altCheck.output.isEmpty {
                print("✅ Mounted at (via mount): \(altCheck.output)")
                return (true, altCheck.output)
            }
            
            return (true, "/Volumes/UNTITLED") // Default fallback
        } else {
            print("❌ Mount failed: \(mountResult.error)")
            
            // Try alternative file systems
            let fileSystems = ["msdos", "hfs", "apfs", "exfat"]
            for fs in fileSystems {
                let altMount = runCommand("sudo mount -t \(fs) /dev/\(identifier) /Volumes/USB_DRIVE 2>/dev/null", needsSudo: true)
                if altMount.success {
                    print("✅ Alternative mount succeeded with \(fs)")
                    return (true, "/Volumes/USB_DRIVE")
                }
            }
            
            return (false, nil)
        }
    }
    
    // MARK: - Get All Drives (Enhanced)
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get disk list
        let listResult = runCommand("diskutil list -plist")
        
        if listResult.success {
            drives = parseDiskUtilPlist(listResult.output)
        } else {
            // Fallback to text parsing
            let textResult = runCommand("diskutil list")
            if textResult.success {
                drives = parseDiskUtilText(textResult.output)
            }
        }
        
        // Sort: USB/external first
        drives.sort { !$0.isInternal && $1.isInternal }
        
        print("✅ Found \(drives.count) drives")
        return drives
    }
    
    // MARK: - EFI Functions
    func mountEFIPartition() -> (success: Bool, path: String?) {
        print("📌 Mounting EFI partition...")
        
        // Check if already mounted
        if let mountedPath = getEFIPath() {
            print("✅ EFI already mounted at: \(mountedPath)")
            return (true, mountedPath)
        }
        
        // Get all drives
        let allDrives = getAllDrives()
        
        // Look for EFI partitions
        for drive in allDrives {
            for partition in drive.partitions {
                if partition.isEFI || partition.type.contains("EFI") || partition.type.contains("FAT") {
                    print("🔍 Found EFI candidate: \(partition.identifier)")
                    
                    let mountResult = mountDrive(identifier: partition.identifier)
                    if mountResult.success {
                        print("✅ Successfully mounted EFI: \(partition.identifier)")
                        return (true, mountResult.mountPoint)
                    }
                }
            }
        }
        
        // Try common EFI partitions
        let commonPartitions = ["disk0s1", "disk1s1", "disk9s1", "disk10s1"]
        for partition in commonPartitions {
            print("🔍 Trying common partition: \(partition)")
            let mountResult = mountDrive(identifier: partition)
            if mountResult.success {
                print("✅ Successfully mounted: \(partition)")
                return (true, mountResult.mountPoint)
            }
        }
        
        print("❌ Failed to mount any EFI partition")
        return (false, nil)
    }
    
    func getEFIPath() -> String? {
        let commands = [
            "mount | grep -E 'msdos|fat32|EFI' | awk '{print $3}' | head -1",
            "ls -d /Volumes/EFI* 2>/dev/null | head -1",
            "mount | grep '/dev/disk[0-9]+s1' | awk '{print $3}' | head -1"
        ]
        
        for command in commands {
            let result = runCommand(command)
            if result.success, let path = result.output.nonEmpty {
                print("📍 Found EFI at: \(path)")
                return path
            }
        }
        
        return nil
    }
    
    // MARK: - Parsing Functions
    private func parseDiskUtilPlist(_ plist: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        guard let data = plist.data(using: .utf8),
              let plistDict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let allDisks = plistDict["AllDisksAndPartitions"] as? [[String: Any]] else {
            return drives
        }
        
        for diskDict in allDisks {
            guard let identifier = diskDict["DeviceIdentifier"] as? String else { continue }
            
            let size = (diskDict["Size"] as? Int64).map { formatBytes($0) } ?? "Unknown"
            let isInternal = !(identifier.hasPrefix("disk") && Int(identifier.dropFirst(4)) ?? 0 >= 2)
            
            var name = "Disk \(identifier)"
            if let volumeName = diskDict["VolumeName"] as? String, !volumeName.isEmpty {
                name = volumeName
            } else if let diskName = diskDict["Content"] as? String {
                name = diskName
            }
            
            var mountPoint = ""
            if let mount = diskDict["MountPoint"] as? String {
                mountPoint = mount
            }
            
            // Get partitions
            var partitions: [PartitionInfo] = []
            if let partDicts = diskDict["Partitions"] as? [[String: Any]] {
                for partDict in partDicts {
                    if let partId = partDict["DeviceIdentifier"] as? String {
                        let partName = (partDict["VolumeName"] as? String) ?? "Partition \(partId)"
                        let partSize = (partDict["Size"] as? Int64).map { formatBytes($0) } ?? "Unknown"
                        let partType = (partDict["Content"] as? String) ?? "Unknown"
                        let partMount = (partDict["MountPoint"] as? String) ?? ""
                        let isEFI = partType.contains("EFI") || partId.hasSuffix("s1")
                        
                        partitions.append(PartitionInfo(
                            name: partName,
                            identifier: partId,
                            size: partSize,
                            type: partType,
                            mountPoint: partMount,
                            isEFI: isEFI
                        ))
                    }
                }
            }
            
            drives.append(DriveInfo(
                name: name,
                identifier: identifier,
                size: size,
                type: isInternal ? "Internal Disk" : "USB/External",
                mountPoint: mountPoint,
                isInternal: isInternal,
                isEFI: false,
                partitions: partitions
            ))
        }
        
        return drives
    }
    
    private func parseDiskUtilText(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDisk: String?
        var currentPartitions: [PartitionInfo] = []
        
        for line in lines {
            if line.hasPrefix("/dev/disk") {
                // Save previous disk
                if let diskId = currentDisk {
                    drives.append(createDriveInfo(for: diskId, partitions: currentPartitions))
                }
                
                // Start new disk
                let components = line.components(separatedBy: ":")
                if components.count > 0 {
                    currentDisk = components[0].replacingOccurrences(of: "/dev/", with: "").trimmingCharacters(in: .whitespaces)
                    currentPartitions = []
                }
            } else if line.contains("s1") || line.contains("EFI") {
                // Parse partition line
                let scanner = Scanner(string: line)
                scanner.charactersToBeSkipped = .whitespaces
                
                var partNumber: NSString?
                scanner.scanUpTo(":", into: &partNumber)
                scanner.scanString(":", into: nil)
                
                var partType: NSString?
                scanner.scanUpTo(" ", into: &partType)
                
                var partName: NSString?
                scanner.scanUpToCharacters(from: .newlines, into: &partName)
                
                if let diskId = currentDisk, let num = partNumber?.replacingOccurrences(of: ":", with: "") {
                    let partId = "\(diskId)s\(num)"
                    let isEFI = partType?.contains("EFI") == true || num == "1"
                    
                    let partition = PartitionInfo(
                        name: (partName as String?) ?? "Partition",
                        identifier: partId,
                        size: "Unknown",
                        type: (partType as String?) ?? "Unknown",
                        mountPoint: "",
                        isEFI: isEFI
                    )
                    currentPartitions.append(partition)
                }
            }
        }
        
        // Add last disk
        if let diskId = currentDisk {
            drives.append(createDriveInfo(for: diskId, partitions: currentPartitions))
        }
        
        return drives
    }
    
    private func createDriveInfo(for identifier: String, partitions: [PartitionInfo]) -> DriveInfo {
        // Get disk info
        let infoResult = runCommand("diskutil info /dev/\(identifier) 2>/dev/null")
        
        var name = "Disk \(identifier)"
        var size = "Unknown"
        var mountPoint = ""
        var isInternal = true
        
        if infoResult.success {
            let lines = infoResult.output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Volume Name:") {
                    name = line.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) ?? name
                } else if line.contains("Disk Size:") {
                    size = line.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) ?? size
                } else if line.contains("Mount Point:") {
                    mountPoint = line.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    if mountPoint == "(Not Mounted)" { mountPoint = "" }
                } else if line.contains("Protocol:") && line.contains("USB") {
                    isInternal = false
                } else if line.contains("Bus Protocol:") && line.contains("USB") {
                    isInternal = false
                }
            }
        }
        
        return DriveInfo(
            name: name,
            identifier: identifier,
            size: size,
            type: isInternal ? "Internal Disk" : "USB/External",
            mountPoint: mountPoint,
            isInternal: isInternal,
            isEFI: false,
            partitions: partitions
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    // MARK: - System Information
    func getCompleteSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
        let versionResult = runCommand("sw_vers -productVersion")
        info.macOSVersion = versionResult.success ? versionResult.output : "Unknown"
        
        let buildResult = runCommand("sw_vers -buildVersion")
        info.buildNumber = buildResult.success ? buildResult.output : "Unknown"
        
        let kernelResult = runCommand("uname -r")
        info.kernelVersion = kernelResult.success ? kernelResult.output : "Unknown"
        
        let modelResult = runCommand("sysctl -n hw.model")
        info.modelIdentifier = modelResult.success ? modelResult.output : "Unknown"
        
        let cpuResult = runCommand("sysctl -n machdep.cpu.brand_string")
        info.processor = cpuResult.success ? cpuResult.output : "Unknown"
        
        let memResult = runCommand("sysctl -n hw.memsize")
        if memResult.success, let bytes = Int64(memResult.output) {
            let gb = Double(bytes) / 1_073_741_824
            info.memory = String(format: "%.0f GB", gb)
        } else {
            info.memory = "Unknown"
        }
        
        // Check boot mode
        let usbDrives = findUSBDrives()
        let bootDrive = runCommand("diskutil info / | grep 'Part of Whole' | awk '{print $NF}'")
        
        if bootDrive.success, let bootDisk = bootDrive.output.nonEmpty {
            info.bootMode = usbDrives.contains(bootDisk) ? "USB Boot" : "Internal Boot"
        } else {
            info.bootMode = "Unknown"
        }
        
        return info
    }
    
    func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    func checkKextLoaded(_ kextName: String) -> Bool {
        let result = runCommand("kextstat | grep -i '\(kextName)'")
        return result.success && !result.output.isEmpty
    }
    
    func getKextVersion(_ kextName: String) -> String? {
        let result = runCommand("kextstat | grep -i '\(kextName)' | awk '{print $6}'")
        return result.success ? result.output.nonEmpty : nil
    }
    
    // MARK: - Permission Check
    func checkFullDiskAccess() -> Bool {
        // Try to access /Volumes directory
        let testResult = runCommand("ls /Volumes/ 2>&1")
        
        if !testResult.success && testResult.error.contains("Operation not permitted") {
            print("❌ Full Disk Access not granted")
            return false
        }
        
        print("✅ Full Disk Access appears to be granted")
        return true
    }
    
    func getCompleteDiagnostics() -> String {
        var diagnostics = "=== SystemMaintenance Diagnostics Report ===\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        diagnostics += "Generated: \(dateFormatter.string(from: Date()))\n\n"
        
        let sysInfo = getCompleteSystemInfo()
        
        // System Information
        diagnostics += "--- System Information ---\n"
        diagnostics += "macOS Version: \(sysInfo.macOSVersion)\n"
        diagnostics += "Build Number: \(sysInfo.buildNumber)\n"
        diagnostics += "Kernel Version: \(sysInfo.kernelVersion)\n"
        diagnostics += "Model Identifier: \(sysInfo.modelIdentifier)\n"
        diagnostics += "Processor: \(sysInfo.processor)\n"
        diagnostics += "Memory: \(sysInfo.memory)\n"
        diagnostics += "Boot Mode: \(sysInfo.bootMode)\n"
        diagnostics += "SIP Status: \(isSIPDisabled() ? "Disabled" : "Enabled")\n\n"
        
        // USB Drives
        diagnostics += "--- USB Drives ---\n"
        let usbDrives = findUSBDrives()
        if usbDrives.isEmpty {
            diagnostics += "No USB drives found\n"
        } else {
            for usbDrive in usbDrives {
                diagnostics += "USB Drive: \(usbDrive)\n"
            }
        }
        diagnostics += "\n"
        
        // All Drives
        diagnostics += "--- All Drives ---\n"
        let allDrives = getAllDrives()
        for drive in allDrives {
            diagnostics += "\(drive.name) (\(drive.identifier)): \(drive.size) - \(drive.type)\n"
            if !drive.partitions.isEmpty {
                for partition in drive.partitions {
                    diagnostics += "  └─ \(partition.identifier): \(partition.name) - \(partition.size) - \(partition.type)\n"
                }
            }
        }
        diagnostics += "\n"
        
        // EFI Status
        diagnostics += "--- EFI Status ---\n"
        if let efiPath = getEFIPath() {
            diagnostics += "Mounted: Yes\n"
            diagnostics += "Path: \(efiPath)\n"
        } else {
            diagnostics += "Mounted: No\n"
        }
        diagnostics += "\n"
        
        // Permissions
        diagnostics += "--- Permissions ---\n"
        let hasAccess = checkFullDiskAccess()
        diagnostics += "Full Disk Access: \(hasAccess ? "Granted ✓" : "Not Granted ✗")\n"
        
        diagnostics += "\n=== End of Report ===\n"
        return diagnostics
    }
}

// MARK: - String Extension
extension String {
    var nonEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Data Structures
struct SystemInfo {
    var macOSVersion: String = "Checking..."
    var buildNumber: String = "Checking..."
    var kernelVersion: String = "Checking..."
    var modelIdentifier: String = "Checking..."
    var processor: String = "Checking..."
    var memory: String = "Checking..."
    var bootMode: String = "Checking..."
}

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
        return lhs.identifier == rhs.identifier
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
}

// MARK: - Document for Export
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

// MARK: - UI Components
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

// MARK: - Main Content View
@MainActor
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isMounting = false
    @State private var isLoadingDrives = false
    @State private var efiPath: String?
    @State private var allDrives: [DriveInfo] = []
    @State private var systemInfo = SystemInfo()
    @State private var hasFullDiskAccess = false
    
    let shellHelper = ShellHelper.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    SystemMaintenanceView
                        .tabItem {
                            Label("System", systemImage: "gear")
                        }
                        .tag(0)
                    
                    SystemInfoView
                        .tabItem {
                            Label("Info", systemImage: "info.circle")
                        }
                        .tag(1)
                }
                .tabViewStyle(.automatic)
            }
            
            if isLoadingDrives {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkPermissions()
            loadSystemInfo()
            loadAllDrives()
            checkEFIMount()
        }
    }
    
    // MARK: - Header View
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("USB Boot Edition")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Permission Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(hasFullDiskAccess ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(hasFullDiskAccess ? "Permissions: OK" : "Permissions: Required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasFullDiskAccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(20)
                
                // Drive Count
                VStack(alignment: .trailing, spacing: 2) {
                    let internalCount = allDrives.filter { $0.isInternal }.count
                    let externalCount = allDrives.filter { !$0.isInternal }.count
                    Text("\(internalCount) Internal • \(externalCount) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // EFI Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(efiPath != nil ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text("EFI: \(efiPath != nil ? "Mounted" : "Not Mounted")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(efiPath != nil ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - System Maintenance View
    private var SystemMaintenanceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Permission Warning
                if !hasFullDiskAccess {
                    PermissionWarningSection
                }
                
                // Drive Management
                DriveManagementSection
                
                // EFI Management
                EFIManagementSection
                
                // Quick Actions
                QuickActionsGrid
                
                // Status Cards
                StatusCardsSection
            }
            .padding()
        }
    }
    
    private var PermissionWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Permissions Required")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("Grant Access") {
                    grantFullDiskAccess()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            
            Text("SystemMaintenance needs Full Disk Access to detect and mount drives. Please grant access in System Settings > Privacy & Security > Full Disk Access.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var DriveManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Drive Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: loadAllDrives) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingDrives)
            }
            
            if allDrives.isEmpty {
                EmptyDrivesView
            } else {
                DrivesListView
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !hasFullDiskAccess {
                Text("Grant Full Disk Access to detect drives")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Try refreshing or connect a USB drive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Debug Drive Detection") {
                debugDriveDetection()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var DrivesListView: some View {
        VStack(spacing: 12) {
            ForEach(allDrives) { drive in
                DriveRow(drive: drive) {
                    showDriveDetail(drive)
                }
            }
        }
    }
    
    private var EFIManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EFI Partition Management")
                .font(.headline)
                .foregroundColor(.purple)
            
            if let efiPath = efiPath {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("EFI Mounted")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Path: \(efiPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Open in Finder") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: efiPath))
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("Check Structure") {
                            checkEFIStructure()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Button("Unmount") {
                            unmountEFI()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No EFI partition is currently mounted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Mount EFI") {
                            mountEFI()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Mount USB EFI") {
                            mountUSBEFI()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Debug") {
                            debugEFIDetection()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var QuickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MaintenanceButton(
                title: "Mount USB EFI",
                icon: "externaldrive.badge.plus",
                color: .orange,
                isLoading: isMounting,
                action: mountUSBEFI
            )
            
            MaintenanceButton(
                title: "Mount EFI",
                icon: "cylinder.fill",
                color: .purple,
                isLoading: isMounting,
                action: mountEFI
            )
            
            MaintenanceButton(
                title: "Refresh All",
                icon: "arrow.clockwise",
                color: .blue,
                isLoading: isLoadingDrives,
                action: {
                    loadAllDrives()
                    checkEFIMount()
                }
            )
            
            MaintenanceButton(
                title: "Fix Permissions",
                icon: "lock.shield",
                color: .indigo,
                isLoading: false,
                action: fixPermissions
            )
            
            MaintenanceButton(
                title: "Check USB",
                icon: "magnifyingglass",
                color: .green,
                isLoading: false,
                action: checkUSBDrives
            )
            
            MaintenanceButton(
                title: "Export Report",
                icon: "square.and.arrow.up",
                color: .blue,
                isLoading: false,
                action: exportReport
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var StatusCardsSection: some View {
        HStack(spacing: 16) {
            StatusCard(
                title: "System Integrity",
                status: shellHelper.isSIPDisabled() ? "Disabled" : "Enabled",
                version: nil,
                detail: shellHelper.isSIPDisabled() ? "SIP: Disabled ✓" : "SIP: Enabled ⚠️",
                statusColor: shellHelper.isSIPDisabled() ? .green : .orange
            )
            
            StatusCard(
                title: "Permissions",
                status: hasFullDiskAccess ? "Granted" : "Required",
                version: nil,
                detail: hasFullDiskAccess ? "Full Disk Access OK" : "Click to fix",
                statusColor: hasFullDiskAccess ? .green : .orange
            )
            
            StatusCard(
                title: "EFI Status",
                status: efiPath != nil ? "Mounted" : "Not Mounted",
                version: nil,
                detail: efiPath ?? "Click Mount EFI",
                statusColor: efiPath != nil ? .green : .orange
            )
            
            StatusCard(
                title: "USB Drives",
                status: "\(allDrives.filter { !$0.isInternal }.count) connected",
                version: nil,
                detail: allDrives.filter { !$0.isInternal }.map { $0.identifier }.joined(separator: ", "),
                statusColor: allDrives.contains { !$0.isInternal } ? .green : .gray
            )
        }
    }
    
    // MARK: - System Info View
    private var SystemInfoView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: exportReport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        loadSystemInfo()
                        showAlert(title: "Refreshed", message: "System information updated")
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // System Info Grid
                SystemInfoGrid
                
                // Drives List
                if !allDrives.isEmpty {
                    DrivesInfoSection
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var SystemInfoGrid: some View {
        VStack(spacing: 16) {
            Text("System Information")
                .font(.title2)
                .fontWeight(.semibold)
            
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
                InfoCard(title: "Boot Mode", value: systemInfo.bootMode)
                InfoCard(title: "SIP Status", value: shellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
                InfoCard(title: "EFI Status", value: efiPath != nil ? "Mounted" : "Not Mounted")
                InfoCard(title: "USB Drives", value: "\(allDrives.filter { !$0.isInternal }.count) connected")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func InfoCard(title: String, value: String) -> some View {
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
    
    private var DrivesInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Drives")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(allDrives.count) drives total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(allDrives) { drive in
                DriveInfoCard(drive: drive)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveInfoCard(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .foregroundColor(drive.isInternal ? .blue : .orange)
                
                Text(drive.name)
                    .font(.headline)
                
                Spacer()
                
                Text(drive.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(drive.identifier)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(drive.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !drive.mountPoint.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Mounted: \(drive.mountPoint)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if !drive.partitions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Partitions:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(drive.partitions.prefix(3)) { partition in
                        HStack {
                            Text(partition.identifier)
                                .font(.system(.caption2, design: .monospaced))
                            Text(partition.name)
                                .font(.caption2)
                            Text(partition.size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if partition.isEFI {
                                Text("EFI")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    
                    if drive.partitions.count > 3 {
                        Text("+ \(drive.partitions.count - 3) more partitions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Progress Overlay
    private var ProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(isMounting ? "Mounting drive..." : "Loading drives...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(20)
        }
    }
    
    // MARK: - Action Functions
    
    private func checkPermissions() {
        DispatchQueue.global(qos: .background).async {
            let hasAccess = shellHelper.checkFullDiskAccess()
            DispatchQueue.main.async {
                hasFullDiskAccess = hasAccess
                if !hasAccess {
                    showAlert(title: "Permissions Required", 
                             message: "Full Disk Access is required for drive detection. Please grant access in System Settings.")
                }
            }
        }
    }
    
    private func grantFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
        
        showAlert(title: "Open System Settings", 
                 message: "Please add SystemMaintenance to the Full Disk Access list and restart the application.")
    }
    
    private func loadSystemInfo() {
        DispatchQueue.global(qos: .background).async {
            let info = shellHelper.getCompleteSystemInfo()
            DispatchQueue.main.async {
                systemInfo = info
            }
        }
    }
    
    private func loadAllDrives() {
        isLoadingDrives = true
        
        DispatchQueue.global(qos: .background).async {
            let drives = shellHelper.getAllDrives()
            
            DispatchQueue.main.async {
                allDrives = drives
                isLoadingDrives = false
                
                if drives.isEmpty {
                    showAlert(title: "No Drives Found",
                             message: "No drives were detected. This could be due to:\n1. Full Disk Access not granted\n2. No storage devices connected\n3. System issue with diskutil\n\nTry granting Full Disk Access first.")
                }
            }
        }
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            let path = shellHelper.getEFIPath()
            DispatchQueue.main.async {
                efiPath = path
            }
        }
    }
    
    private func mountUSBEFI() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            // Find USB drives
            let usbDrives = shellHelper.findUSBDrives()
            
            var resultMessage = ""
            var success = false
            var mountedPath: String?
            
            if usbDrives.isEmpty {
                resultMessage = "No USB drives found. Please connect a USB drive and try again."
            } else {
                resultMessage = "Found USB drives: \(usbDrives.joined(separator: ", "))\n\n"
                
                // Try to mount each USB drive's EFI partition
                for usbDrive in usbDrives {
                    // Try common EFI partition names
                    let partitions = ["s1", "s0", "s2"]
                    
                    for suffix in partitions {
                        let partition = "\(usbDrive)\(suffix)"
                        resultMessage += "Trying to mount \(partition)...\n"
                        
                        let mountResult = shellHelper.mountDrive(identifier: partition)
                        
                        if mountResult.success {
                            success = true
                            mountedPath = mountResult.mountPoint
                            resultMessage += "✅ Successfully mounted \(partition)\n"
                            if let path = mountResult.mountPoint {
                                resultMessage += "Mounted at: \(path)\n"
                            }
                            break
                        } else {
                            resultMessage += "❌ Failed to mount \(partition)\n"
                        }
                    }
                    
                    if success { break }
                }
                
                if !success {
                    resultMessage += "\n❌ Failed to mount any USB EFI partition.\n\nTry manually with: sudo diskutil mount disk9s1"
                }
            }
            
            DispatchQueue.main.async {
                isMounting = false
                efiPath = mountedPath
                
                showAlert(title: success ? "USB EFI Mounted" : "Mount Failed", 
                         message: resultMessage)
            }
        }
    }
    
    private func mountEFI() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = shellHelper.mountEFIPartition()
            
            DispatchQueue.main.async {
                isMounting = false
                efiPath = result.path
                
                if result.success {
                    showAlert(title: "EFI Mounted", 
                             message: "EFI partition mounted successfully!\n\nPath: \(result.path ?? "Unknown")")
                } else {
                    showAlert(title: "Mount Failed", 
                             message: "Failed to mount any EFI partition.\n\nTry manually:\nsudo diskutil mount diskXs1\n\nWhere X is your USB disk number (usually 9 for USB).")
                }
            }
        }
    }
    
    private func unmountEFI() {
        guard let efiPath = efiPath else { return }
        
        let result = shellHelper.runCommand("diskutil unmount \"\(efiPath)\"", needsSudo: true)
        
        if result.success {
            self.efiPath = nil
            showAlert(title: "Unmounted", message: "EFI partition has been unmounted.")
        } else {
            showAlert(title: "Unmount Failed", message: "Failed to unmount EFI: \(result.error)")
        }
    }
    
    private func checkEFIStructure() {
        guard let efiPath = efiPath else {
            showAlert(title: "Error", message: "EFI partition not mounted.")
            return
        }
        
        var messages = ["Checking EFI structure at: \(efiPath)\n"]
        
        let directories = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers"]
        
        for dir in directories {
            let path = "\(efiPath)/\(dir)"
            let exists = FileManager.default.fileExists(atPath: path)
            messages.append("\(exists ? "✅" : "❌") \(dir)")
        }
        
        // Check for important files
        let importantFiles = ["EFI/OC/config.plist", "EFI/BOOT/BOOTx64.efi"]
        for file in importantFiles {
            let path = "\(efiPath)/\(file)"
            let exists = FileManager.default.fileExists(atPath: path)
            if exists {
                messages.append("✅ Found: \(file)")
            }
        }
        
        showAlert(title: "EFI Structure Check", message: messages.joined(separator: "\n"))
    }
    
    private func debugDriveDetection() {
        let commands = [
            ("diskutil list", "List all disks"),
            ("mount", "Show mounted volumes"),
            ("ls -la /Volumes/", "List volumes directory"),
            ("system_profiler SPUSBDataType", "USB device info"),
            ("diskutil info disk9", "Check disk9 specifically")
        ]
        
        var debugOutput = "=== Drive Detection Debug ===\n\n"
        
        for (command, description) in commands {
            debugOutput += "\(description):\n"
            let result = shellHelper.runCommand(command)
            debugOutput += "Exit code: \(result.success ? "0" : "non-zero")\n"
            debugOutput += "Output: \(result.output)\n"
            if !result.error.isEmpty {
                debugOutput += "Error: \(result.error)\n"
            }
            debugOutput += "---\n\n"
        }
        
        showAlert(title: "Debug Information", message: debugOutput)
    }
    
    private func debugEFIDetection() {
        var debugOutput = "=== EFI Detection Debug ===\n\n"
        
        // Check various EFI detection methods
        let checks = [
            ("mount | grep -E 'msdos|fat32|EFI'", "Mounted EFI volumes"),
            ("ls -d /Volumes/EFI* 2>/dev/null", "EFI volumes in /Volumes"),
            ("diskutil list | grep -i efi", "EFI partitions in disk list"),
            ("find /Volumes -name EFI -type d 2>/dev/null", "EFI directories"),
            ("diskutil info /dev/disk9s1 2>/dev/null", "Check disk9s1 specifically")
        ]
        
        for (command, description) in checks {
            debugOutput += "\(description):\n"
            let result = shellHelper.runCommand(command)
            debugOutput += result.output.isEmpty ? "No output\n" : result.output + "\n"
            debugOutput += "---\n"
        }
        
        showAlert(title: "EFI Debug Info", message: debugOutput)
    }
    
    private func checkUSBDrives() {
        let usbDrives = shellHelper.findUSBDrives()
        
        if usbDrives.isEmpty {
            showAlert(title: "No USB Drives", 
                     message: "No USB drives detected.\n\nPlease ensure:\n1. USB drive is connected\n2. Try different USB port\n3. Check if drive appears in Disk Utility")
        } else {
            showAlert(title: "USB Drives Found", 
                     message: "Found \(usbDrives.count) USB drive(s):\n\n\(usbDrives.joined(separator: "\n"))\n\nThese will be used for EFI mounting.")
        }
    }
    
    private func fixPermissions() {
        DispatchQueue.global(qos: .background).async {
            let commands = [
                "chown -R root:wheel /System/Library/Extensions/ 2>/dev/null || true",
                "chmod -R 755 /System/Library/Extensions/ 2>/dev/null || true",
                "touch /System/Library/Extensions 2>/dev/null || true"
            ]
            
            var messages = ["Fixing permissions...\n"]
            
            for command in commands {
                let result = shellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ \(command)")
                } else {
                    messages.append("⚠️ \(command): \(result.error)")
                }
            }
            
            DispatchQueue.main.async {
                showAlert(title: "Permissions Fixed", 
                         message: messages.joined(separator: "\n"))
            }
        }
    }
    
    private func exportReport() {
        DispatchQueue.global(qos: .background).async {
            let diagnostics = shellHelper.getCompleteDiagnostics()
            
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.title = "Export System Report"
                savePanel.nameFieldLabel = "Export as:"
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let fileName = "SystemMaintenance_Report_\(dateFormatter.string(from: Date())).txt"
                savePanel.nameFieldStringValue = fileName
                
                savePanel.allowedContentTypes = [.plainText]
                savePanel.canCreateDirectories = true
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        do {
                            try diagnostics.write(to: url, atomically: true, encoding: .utf8)
                            
                            // Copy to clipboard as well
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(diagnostics, forType: .string)
                            
                            showAlert(title: "Export Successful", 
                                     message: "Report exported to:\n\(url.lastPathComponent)\n\nAlso copied to clipboard.")
                        } catch {
                            showAlert(title: "Export Failed", 
                                     message: "Failed to export: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func showDriveDetail(_ drive: DriveInfo) {
        var message = "\(drive.name)\n"
        message += "Identifier: \(drive.identifier)\n"
        message += "Size: \(drive.size)\n"
        message += "Type: \(drive.type)\n"
        
        if !drive.mountPoint.isEmpty {
            message += "Mounted at: \(drive.mountPoint)\n"
        } else {
            message += "Not mounted\n"
        }
        
        message += "Internal: \(drive.isInternal ? "Yes" : "No")\n\n"
        
        if !drive.partitions.isEmpty {
            message += "Partitions:\n"
            for partition in drive.partitions {
                message += "- \(partition.identifier): \(partition.name) (\(partition.size))\n"
                if partition.isEFI {
                    message += "  [EFI Partition]\n"
                }
            }
        }
        
        showAlert(title: "Drive Details", message: message)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}