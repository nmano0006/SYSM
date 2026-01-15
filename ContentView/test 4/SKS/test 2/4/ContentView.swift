import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine

// MARK: - Shell Helper (Fixed parsing)
class ShellHelper {
    static let shared = ShellHelper()
    
    private init() {}
    
    func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, error: String, success: Bool) {
        print("🔧 Running command: \(command)")
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if needsSudo {
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
            print("❌ Process execution error: \(error)")
            return ("", "Process execution error: \(error)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        print("📝 Command output length: \(output.count) characters")
        if !errorOutput.isEmpty {
            print("⚠️ Command error: \(errorOutput)")
        }
        print("✅ Command success: \(success)")
        
        return (output, errorOutput, success)
    }
    
    // Improved debug function
    func debugDriveDetection() -> String {
        var debugInfo = "=== Drive Detection Debug ===\n\n"
        
        // Test basic diskutil access with verbose output
        debugInfo += "1. Testing diskutil access (verbose):\n"
        let test1 = runCommand("diskutil list 2>&1 | head -30")
        debugInfo += "   Success: \(test1.success)\n"
        debugInfo += "   Error: \(test1.error.isEmpty ? "None" : test1.error)\n"
        debugInfo += "   Output: \(test1.output.isEmpty ? "EMPTY - Likely permission issue" : test1.output)\n\n"
        
        // Test diskutil list with full output
        debugInfo += "2. Testing diskutil list (full):\n"
        let test1b = runCommand("diskutil list")
        debugInfo += "   Output length: \(test1b.output.count) characters\n"
        debugInfo += "   First 500 chars: \(test1b.output.prefix(500))\n\n"
        
        // Test list disks directly
        debugInfo += "3. Testing disk list:\n"
        let test2 = runCommand("ls /dev/disk* 2>&1")
        debugInfo += "   Success: \(test2.success)\n"
        debugInfo += "   Output: \(test2.output)\n\n"
        
        // Test mount points
        debugInfo += "4. Testing mount points:\n"
        let test3 = runCommand("mount | grep /dev/disk 2>&1")
        debugInfo += "   Output: \(test3.output.isEmpty ? "No mounted disks found" : test3.output)\n\n"
        
        // Test volumes
        debugInfo += "5. Testing /Volumes directory:\n"
        let test4 = runCommand("ls -la /Volumes 2>&1")
        debugInfo += "   Success: \(test4.success)\n"
        debugInfo += "   Output: \(test4.output)\n\n"
        
        // Test system profiler
        debugInfo += "6. Testing system profiler:\n"
        let test5 = runCommand("system_profiler SPStorageDataType 2>&1 | head -100")
        debugInfo += "   Success: \(test5.success)\n"
        debugInfo += "   Output preview: \(test5.output.prefix(500))...\n"
        
        return debugInfo
    }
    
    func findUSBDrives() -> [String] {
        print("🔍 Searching for USB drives...")
        var usbDrives: Set<String> = []
        
        // Method 1: Using diskutil info
        let diskutilResult = runCommand("""
        for disk in $(ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$'); do
            disk_name=$(basename $disk)
            if diskutil info $disk 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' >/dev/null; then
                echo $disk_name
            fi
        done
        """)
        
        print("📊 USB detection result: \(diskutilResult.output)")
        
        if !diskutilResult.output.isEmpty {
            let drives = diskutilResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            drives.forEach { usbDrives.insert($0) }
        }
        
        // Method 2: Alternative detection
        if usbDrives.isEmpty {
            print("🔄 Trying alternative USB detection method...")
            let altResult = runCommand("""
            mount | grep /Volumes/ | grep -v 'Data\\|Preboot\\|VM\\|Update' | grep -o 'disk[0-9]\\+s[0-9]\\+' | cut -d's' -f1 | sort -u
            """)
            
            if !altResult.output.isEmpty {
                let drives = altResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                drives.forEach { usbDrives.insert($0) }
            }
        }
        
        print("✅ Found USB drives: \(Array(usbDrives))")
        return Array(usbDrives).sorted()
    }
    
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        // First, get all mounted volumes from mount command
        let mountedDrives = getMountedDrivesFromMount()
        print("📌 Found \(mountedDrives.count) mounted drives from mount command")
        
        // Try to get detailed info from diskutil
        let listResult = runCommand("diskutil list")
        
        var drives: [DriveInfo] = []
        
        if listResult.success && !listResult.output.isEmpty {
            print("📊 Parsing diskutil output...")
            drives = parseDiskUtilText(listResult.output, mountedDrives: mountedDrives)
        } else {
            print("⚠️ Could not parse diskutil, using mount info only")
            drives = mountedDrives
        }
        
        // Sort: external first, then internal
        drives.sort { 
            if $0.isInternal != $1.isInternal {
                return !$0.isInternal && $1.isInternal
            }
            return $0.name < $1.name
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getMountedDrivesFromMount() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        let mountResult = runCommand("mount")
        let lines = mountResult.output.components(separatedBy: "\n")
        
        var processedDisks: Set<String> = []
        
        for line in lines {
            if line.contains("/dev/disk") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                if components.count >= 3 {
                    let diskPath = components[0]  // e.g., /dev/disk4s4s1
                    let mountPoint = components[2] // e.g., /
                    let filesystem = components.count > 4 ? components[4].replacingOccurrences(of: ",", with: "") : "Unknown"
                    
                    // Extract base disk (e.g., disk4 from disk4s4s1)
                    if let diskRange = diskPath.range(of: "disk[0-9]+", options: .regularExpression) {
                        let diskId = String(diskPath[diskRange])
                        
                        // Only add each disk once
                        if !processedDisks.contains(diskId) {
                            let isInternal = !mountPoint.contains("/Volumes/") || mountPoint == "/"
                            
                            // Get size info for this disk
                            let sizeInfo = getDiskSize(diskId: diskId)
                            
                            // Get partition info
                            let partitions = getPartitionsForDisk(diskId: diskId)
                            
                            // Determine drive name from mount point or disk ID
                            let name: String
                            if mountPoint == "/" {
                                name = "System Disk"
                            } else if mountPoint.contains("/Volumes/") {
                                let volumeName = (mountPoint as NSString).lastPathComponent
                                name = volumeName.isEmpty ? "Disk \(diskId)" : volumeName
                            } else {
                                name = "Disk \(diskId)"
                            }
                            
                            // Check if this is a USB/External drive
                            let isUSB = isUSBDrive(diskId: diskId)
                            let driveType = isUSB ? "USB/External" : (isInternal ? "Internal" : "External")
                            
                            drives.append(DriveInfo(
                                name: name,
                                identifier: diskId,
                                size: sizeInfo,
                                type: driveType,
                                mountPoint: mountPoint,
                                isInternal: isInternal,
                                isEFI: false,
                                partitions: partitions,
                                isMounted: true
                            ))
                            
                            processedDisks.insert(diskId)
                        }
                    }
                }
            }
        }
        
        return drives
    }
    
    private func getDiskSize(diskId: String) -> String {
        // Try to get size from diskutil info
        let infoResult = runCommand("diskutil info /dev/\(diskId) 2>/dev/null | grep 'Disk Size' | head -1")
        if infoResult.success && !infoResult.output.isEmpty {
            let components = infoResult.output.components(separatedBy: ":")
            if components.count > 1 {
                let size = components[1].trimmingCharacters(in: .whitespaces)
                return size
            }
        }
        
        // Fallback: try to get from df command
        let dfResult = runCommand("df -h /dev/\(diskId) 2>/dev/null | tail -1 | awk '{print $2}'")
        if dfResult.success && !dfResult.output.isEmpty {
            return dfResult.output
        }
        
        return "Unknown"
    }
    
    private func isUSBDrive(diskId: String) -> Bool {
        let usbCheck = runCommand("""
        diskutil info /dev/\(diskId) 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' | head -1
        """)
        return !usbCheck.output.isEmpty
    }
    
    private func getPartitionsForDisk(diskId: String) -> [PartitionInfo] {
        var partitions: [PartitionInfo] = []
        
        let listResult = runCommand("diskutil list /dev/\(diskId) 2>/dev/null")
        let lines = listResult.output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Look for partition lines (containing "diskXsY")
            if trimmedLine.contains(diskId) && trimmedLine.contains("s") {
                let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if components.count >= 3 {
                    var partitionId = ""
                    var partitionName = "Unnamed"
                    var partitionType = "Unknown"
                    var partitionSize = "Unknown"
                    var isEFIPartition = false
                    
                    // Find partition identifier (e.g., disk1s1)
                    for component in components {
                        if component.contains(diskId) && component.contains("s") {
                            partitionId = component.replacingOccurrences(of: "*", with: "")
                            break
                        }
                    }
                    
                    // Skip if we couldn't find a partition ID
                    if partitionId.isEmpty {
                        continue
                    }
                    
                    // Find partition name (usually after identifier)
                    if let idIndex = components.firstIndex(where: { $0.contains(partitionId) }),
                       idIndex + 1 < components.count {
                        partitionName = components[idIndex + 1]
                    }
                    
                    // Check if EFI partition
                    isEFIPartition = partitionName.contains("EFI") || 
                                    partitionType.contains("EFI") ||
                                    trimmedLine.contains("EFI")
                    
                    // Get partition size
                    let sizeInfo = getPartitionSize(partitionId: partitionId)
                    partitionSize = sizeInfo
                    
                    // Get mount point for this partition
                    let mountPoint = getPartitionMountPoint(partitionId: partitionId)
                    
                    partitions.append(PartitionInfo(
                        name: partitionName,
                        identifier: partitionId,
                        size: partitionSize,
                        type: partitionType,
                        mountPoint: mountPoint,
                        isEFI: isEFIPartition,
                        isMounted: !mountPoint.isEmpty
                    ))
                }
            }
        }
        
        return partitions
    }
    
    private func getPartitionSize(partitionId: String) -> String {
        let infoResult = runCommand("diskutil info /dev/\(partitionId) 2>/dev/null | grep 'Size' | head -1")
        if infoResult.success && !infoResult.output.isEmpty {
            let components = infoResult.output.components(separatedBy: ":")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown"
    }
    
    private func getPartitionMountPoint(partitionId: String) -> String {
        let mountResult = runCommand("mount | grep \"/dev/\(partitionId) \" | awk '{print $3}'")
        if mountResult.success && !mountResult.output.isEmpty {
            return mountResult.output
        }
        return ""
    }
    
    private func parseDiskUtilText(_ output: String, mountedDrives: [DriveInfo]) -> [DriveInfo] {
        print("📝 Parsing diskutil text (length: \(output.count) chars)")
        
        if output.isEmpty {
            print("❌ Output is empty, cannot parse")
            return mountedDrives
        }
        
        // Log first few lines for debugging
        let lines = output.components(separatedBy: "\n")
        print("📄 First 30 lines of diskutil output:")
        for (index, line) in lines.prefix(30).enumerated() {
            print("   \(index): \(line)")
        }
        
        var drives: [DriveInfo] = []
        var currentDisk: String?
        var currentSize: String = "Unknown"
        var currentType: String = "Unknown"
        var currentPartitions: [PartitionInfo] = []
        var isExternal = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Look for disk header (e.g., "/dev/disk0 (internal, physical):")
            if (trimmedLine.contains("/dev/disk") || trimmedLine.hasPrefix("disk")) && 
               trimmedLine.contains(":") && 
               (trimmedLine.contains("internal") || trimmedLine.contains("external") || trimmedLine.contains("physical") || trimmedLine.contains("virtual")) {
                
                // Save previous disk if exists
                if let diskId = currentDisk {
                    // Find existing drive info from mounted drives
                    let existingDrive = mountedDrives.first { $0.identifier == diskId }
                    
                    drives.append(DriveInfo(
                        name: existingDrive?.name ?? "Disk \(diskId)",
                        identifier: diskId,
                        size: existingDrive?.size ?? currentSize,
                        type: isExternal ? "USB/External" : "Internal",
                        mountPoint: existingDrive?.mountPoint ?? "",
                        isInternal: existingDrive?.isInternal ?? !isExternal,
                        isEFI: false,
                        partitions: currentPartitions,
                        isMounted: existingDrive?.isMounted ?? false
                    ))
                    print("📦 Added disk: \(diskId)")
                }
                
                // Parse new disk
                currentDisk = nil
                currentSize = "Unknown"
                currentType = "Unknown"
                currentPartitions = []
                
                // Extract disk identifier
                if let diskRange = trimmedLine.range(of: "disk[0-9]+", options: .regularExpression) {
                    currentDisk = String(trimmedLine[diskRange])
                }
                
                // Check if external
                isExternal = trimmedLine.lowercased().contains("external") || 
                            trimmedLine.lowercased().contains("usb") ||
                            trimmedLine.lowercased().contains("removable")
                
                // Try to extract size
                if let sizeRange = trimmedLine.range(of: #"\d+\.?\d*\s*[A-Z]{2}"#, options: .regularExpression) {
                    currentSize = String(trimmedLine[sizeRange])
                }
                
                print("📋 Found disk: \(currentDisk ?? "nil"), Size: \(currentSize), External: \(isExternal)")
            }
            // Look for partition info within current disk section
            else if let diskId = currentDisk, 
                    (trimmedLine.contains("disk") && trimmedLine.contains("s") && trimmedLine.contains(diskId)) {
                
                let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if components.count >= 3 {
                    var partitionId = ""
                    var partitionName = "Unnamed"
                    var partitionType = "Unknown"
                    var partitionSize = "Unknown"
                    var isEFIPartition = false
                    
                    // Find partition identifier
                    for component in components {
                        if component.contains("disk") && component.contains("s") {
                            partitionId = component.replacingOccurrences(of: "*", with: "")
                            break
                        }
                    }
                    
                    if partitionId.isEmpty {
                        continue
                    }
                    
                    // Find partition name (skip if it's just the identifier again)
                    if let idIndex = components.firstIndex(where: { $0 == partitionId }),
                       idIndex + 1 < components.count {
                        let nextComponent = components[idIndex + 1]
                        if !nextComponent.contains("disk") {
                            partitionName = nextComponent
                        }
                    }
                    
                    // Try to get size from the line
                    if let sizeRange = trimmedLine.range(of: #"\d+\.?\d*\s*[A-Z]{2}"#, options: .regularExpression) {
                        partitionSize = String(trimmedLine[sizeRange])
                    }
                    
                    // Check if EFI partition
                    isEFIPartition = partitionName.contains("EFI") || 
                                    partitionType.contains("EFI") ||
                                    trimmedLine.contains("EFI")
                    
                    // Get mount point from existing drives
                    var mountPoint = ""
                    for drive in mountedDrives {
                        for partition in drive.partitions {
                            if partition.identifier == partitionId {
                                mountPoint = partition.mountPoint
                                break
                            }
                        }
                    }
                    
                    currentPartitions.append(PartitionInfo(
                        name: partitionName,
                        identifier: partitionId,
                        size: partitionSize,
                        type: partitionType,
                        mountPoint: mountPoint,
                        isEFI: isEFIPartition,
                        isMounted: !mountPoint.isEmpty
                    ))
                    
                    print("📂 Added partition: \(partitionName) (\(partitionId))")
                }
            }
        }
        
        // Add last disk
        if let diskId = currentDisk {
            // Find existing drive info from mounted drives
            let existingDrive = mountedDrives.first { $0.identifier == diskId }
            
            drives.append(DriveInfo(
                name: existingDrive?.name ?? "Disk \(diskId)",
                identifier: diskId,
                size: existingDrive?.size ?? currentSize,
                type: isExternal ? "USB/External" : "Internal",
                mountPoint: existingDrive?.mountPoint ?? "",
                isInternal: existingDrive?.isInternal ?? !isExternal,
                isEFI: false,
                partitions: currentPartitions,
                isMounted: existingDrive?.isMounted ?? false
            ))
            print("📦 Added final disk: \(diskId)")
        }
        
        // Merge with mounted drives (add any mounted drives we missed)
        for mountedDrive in mountedDrives {
            if !drives.contains(where: { $0.identifier == mountedDrive.identifier }) {
                drives.append(mountedDrive)
                print("➕ Added missing mounted drive: \(mountedDrive.identifier)")
            }
        }
        
        print("✅ Parsed \(drives.count) total drives")
        return drives
    }
    
    private func getMountInfo(for diskId: String) -> (mountPoint: String, isMounted: Bool) {
        print("📍 Getting mount info for \(diskId)")
        
        // Try multiple methods to get mount info
        let commands = [
            "diskutil info /dev/\(diskId) 2>/dev/null | grep 'Mount Point' | head -1",
            "mount | grep \"/dev/\(diskId)\" | awk '{print $3}' | head -1",
            "df -h 2>/dev/null | grep \"/dev/\(diskId)\" | awk '{print $NF}' | head -1"
        ]
        
        for command in commands {
            let result = runCommand(command)
            if result.success && !result.output.isEmpty {
                var mountPoint = result.output
                
                // Clean up the output
                if mountPoint.contains("Mount Point:") {
                    let components = mountPoint.components(separatedBy: ":")
                    if components.count > 1 {
                        mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                    }
                }
                
                if !mountPoint.isEmpty && mountPoint != "Not applicable" && mountPoint != "(null)" {
                    print("📍 Mount point for \(diskId): \(mountPoint)")
                    return (mountPoint, true)
                }
            }
        }
        
        return ("", false)
    }
    
    func mountDrive(_ diskId: String) -> (success: Bool, message: String, mountPoint: String) {
        print("⏫ Attempting to mount \(diskId)")
        
        // First check if already mounted
        let mountInfo = getMountInfo(for: diskId)
        if mountInfo.isMounted {
            return (true, "Drive already mounted at \(mountInfo.mountPoint)", mountInfo.mountPoint)
        }
        
        // Try to mount the disk
        let mountResult = runCommand("diskutil mount /dev/\(diskId)")
        
        if mountResult.success {
            // Get new mount point
            let newMountInfo = getMountInfo(for: diskId)
            if newMountInfo.isMounted {
                return (true, "Successfully mounted at \(newMountInfo.mountPoint)", newMountInfo.mountPoint)
            } else {
                return (false, "Mount command succeeded but mount point not found", "")
            }
        } else {
            print("❌ Mount failed: \(mountResult.error)")
            return (false, "Failed to mount: \(mountResult.error)", "")
        }
    }
    
    func unmountDrive(_ diskId: String) -> (success: Bool, message: String) {
        print("⏬ Attempting to unmount \(diskId)")
        
        // Check if mounted
        let mountInfo = getMountInfo(for: diskId)
        if !mountInfo.isMounted {
            return (true, "Drive already unmounted")
        }
        
        // Try to unmount
        let unmountResult = runCommand("diskutil unmount /dev/\(diskId)")
        
        if unmountResult.success {
            return (true, "Successfully unmounted")
        } else {
            print("❌ Unmount failed: \(unmountResult.error)")
            return (false, "Failed to unmount: \(unmountResult.error)")
        }
    }
    
    func mountEFIPartition(for diskId: String) -> (success: Bool, message: String, mountPoint: String) {
        print("🔍 Looking for EFI partition on \(diskId)")
        
        // First, find EFI partition for this disk
        let findEFIResult = runCommand("""
        diskutil list /dev/\(diskId) 2>/dev/null | grep -i 'EFI' | head -1
        """)
        
        guard findEFIResult.success && !findEFIResult.output.isEmpty else {
            print("❌ No EFI partition found for disk \(diskId)")
            return (false, "No EFI partition found for disk \(diskId)", "")
        }
        
        // Extract partition identifier
        let lines = findEFIResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var efiPartitionId = ""
        
        for component in lines {
            if component.contains("disk") && component.contains("s") {
                efiPartitionId = component.replacingOccurrences(of: "*", with: "")
                break
            }
        }
        
        guard !efiPartitionId.isEmpty else {
            return (false, "Could not parse EFI partition identifier", "")
        }
        
        print("✅ Found EFI partition: \(efiPartitionId)")
        
        // Check if already mounted
        let efiMountInfo = getMountInfo(for: efiPartitionId)
        if efiMountInfo.isMounted {
            return (true, "EFI partition already mounted at \(efiMountInfo.mountPoint)", efiMountInfo.mountPoint)
        }
        
        // Mount EFI partition (may need sudo for EFI)
        print("⏫ Mounting EFI partition \(efiPartitionId)")
        let mountEFIResult = runCommand("sudo diskutil mount /dev/\(efiPartitionId)", needsSudo: true)
        
        if mountEFIResult.success {
            let newMountInfo = getMountInfo(for: efiPartitionId)
            if newMountInfo.isMounted {
                return (true, "EFI partition mounted at \(newMountInfo.mountPoint)", newMountInfo.mountPoint)
            } else {
                return (false, "Mount succeeded but mount point not found", "")
            }
        } else {
            print("❌ EFI mount failed: \(mountEFIResult.error)")
            return (false, "Failed to mount EFI: \(mountEFIResult.error)", "")
        }
    }
    
    func unmountAll() -> (success: Bool, message: String) {
        print("⏬ Unmounting all volumes")
        
        // Unmount all non-system volumes
        let result = runCommand("""
        diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | while read partition; do
            if diskutil info /dev/$partition 2>/dev/null | grep -q 'Mount Point.*/Volumes/'; then
                echo "Unmounting $partition"
                diskutil unmount /dev/$partition
            fi
        done
        """)
        
        return (result.success, result.success ? "All volumes unmounted" : "Failed to unmount some volumes")
    }
    
    func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    func checkFullDiskAccess() -> Bool {
        // More comprehensive FDA check
        let testCommands = [
            "diskutil list 2>&1",
            "ls /Volumes/ 2>&1",
            "system_profiler SPStorageDataType 2>&1 | head -5"
        ]
        
        for command in testCommands {
            let testResult = runCommand(command)
            if testResult.error.contains("Operation not permitted") {
                print("🔐 Full Disk Access check FAILED for command: \(command)")
                print("⚠️ Error: \(testResult.error)")
                return false
            }
        }
        
        print("🔐 Full Disk Access check: Granted")
        return true
    }
}

// MARK: - Data Structures
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
    var isMounted: Bool
    
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
    var isMounted: Bool
    
    static func == (lhs: PartitionInfo, rhs: PartitionInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

// MARK: - Drive Manager
class DriveManager: ObservableObject {
    static let shared = DriveManager()
    private let shellHelper = ShellHelper.shared
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            DispatchQueue.main.async {
                self.allDrives = drives
                self.isLoading = false
            }
        }
    }
    
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountDrive(drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.unmountDrive(drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func mountEFIPartition(for drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountEFIPartition(for: drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountAll() -> (success: Bool, message: String) {
        let result = shellHelper.unmountAll()
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
}

// MARK: - Permission Manager
class PermissionManager {
    static let shared = PermissionManager()
    private let shellHelper = ShellHelper.shared
    
    private init() {}
    
    // MARK: - Main Fix All Permissions Function
    func fixAllPermissions(cancelRequested: Binding<Bool>? = nil) -> (success: Bool, report: String, needsRestart: Bool, manualSteps: [String]) {
        print("🛠️ Starting comprehensive permission fix...")
        
        var reportLines: [String] = ["=== SystemMaintenance Permission Fix Report ==="]
        var successSteps: [String] = []
        var failedSteps: [String] = []
        var manualSteps: [String] = []
        var needsRestart = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        reportLines.append("Generated: \(dateFormatter.string(from: Date()))")
        reportLines.append("")
        
        // Check for cancellation before each step
        func checkCancellation() -> Bool {
            if let cancelRequested = cancelRequested, cancelRequested.wrappedValue {
                reportLines.append("⚠️ Fix operation cancelled by user")
                return true
            }
            return false
        }
        
        // Step 1: Check and fix app location
        reportLines.append("STEP 1: Application Location Check")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let appLocationResult = checkAndFixAppLocation()
        reportLines.append(contentsOf: appLocationResult.report)
        if appLocationResult.success {
            successSteps.append("App Location")
            if appLocationResult.needsRestart {
                needsRestart = true
            }
        } else {
            failedSteps.append("App Location")
            manualSteps.append(contentsOf: appLocationResult.manualSteps)
        }
        reportLines.append("")
        
        // Step 2: Full Disk Access
        reportLines.append("STEP 2: Full Disk Access")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let fdaResult = handleFullDiskAccess()
        reportLines.append(contentsOf: fdaResult.report)
        if fdaResult.success {
            successSteps.append("Full Disk Access")
        } else {
            failedSteps.append("Full Disk Access")
            manualSteps.append(contentsOf: fdaResult.manualSteps)
        }
        reportLines.append("")
        
        // Step 3: System Permissions
        reportLines.append("STEP 3: System File Permissions")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let systemPermResult = fixSystemFilePermissions()
        reportLines.append(contentsOf: systemPermResult.report)
        if systemPermResult.success {
            successSteps.append("System Permissions")
        } else {
            failedSteps.append("System Permissions")
        }
        reportLines.append("")
        
        // Step 4: Disk Utility Permissions
        reportLines.append("STEP 4: Disk Utility Access")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let diskUtilResult = fixDiskUtilityPermissions()
        reportLines.append(contentsOf: diskUtilResult.report)
        if diskUtilResult.success {
            successSteps.append("Disk Utility Access")
        } else {
            failedSteps.append("Disk Utility Access")
        }
        reportLines.append("")
        
        // Step 5: Kernel Extension Permissions
        reportLines.append("STEP 5: Kernel Extension Access")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let kextResult = fixKextPermissions()
        reportLines.append(contentsOf: kextResult.report)
        if kextResult.success {
            successSteps.append("Kext Access")
        } else {
            failedSteps.append("Kext Access")
        }
        reportLines.append("")
        
        // Step 6: Reset Launch Services
        reportLines.append("STEP 6: System Cache Reset")
        if checkCancellation() {
            return (false, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
        }
        
        let cacheResult = resetSystemCaches()
        reportLines.append(contentsOf: cacheResult.report)
        if cacheResult.success {
            successSteps.append("System Cache")
        } else {
            failedSteps.append("System Cache")
        }
        reportLines.append("")
        
        // Summary
        reportLines.append("=== SUMMARY ===")
        if let cancelRequested = cancelRequested, cancelRequested.wrappedValue {
            reportLines.append("STATUS: OPERATION CANCELLED")
        }
        reportLines.append("Successful: \(successSteps.count) steps")
        reportLines.append("Failed: \(failedSteps.count) steps")
        reportLines.append("Manual Steps Required: \(manualSteps.count)")
        reportLines.append("Restart Needed: \(needsRestart ? "Yes" : "No")")
        reportLines.append("")
        
        if !successSteps.isEmpty {
            reportLines.append("✅ SUCCESSFUL STEPS:")
            for step in successSteps {
                reportLines.append("  • \(step)")
            }
        }
        
        if !failedSteps.isEmpty {
            reportLines.append("⚠️ FAILED STEPS:")
            for step in failedSteps {
                reportLines.append("  • \(step)")
            }
        }
        
        if !manualSteps.isEmpty {
            reportLines.append("🛠️ MANUAL STEPS REQUIRED:")
            for (index, step) in manualSteps.enumerated() {
                reportLines.append("  \(index + 1). \(step)")
            }
        }
        
        let overallSuccess = failedSteps.isEmpty && manualSteps.isEmpty && !(cancelRequested?.wrappedValue ?? false)
        
        return (overallSuccess, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
    }
    
    // MARK: - Step 1: App Location
    private func checkAndFixAppLocation() -> (success: Bool, report: [String], needsRestart: Bool, manualSteps: [String]) {
        var report: [String] = []
        var manualSteps: [String] = []
        let needsRestart: Bool
        
        let appPath = Bundle.main.bundlePath
        let appName = (appPath as NSString).lastPathComponent
        
        report.append("Current location: \(appPath)")
        
        // Check if in Applications folder
        if appPath.contains("/Applications/") {
            report.append("✅ App is in Applications folder")
            
            // Fix permissions on existing app
            let commands = [
                "xattr -c \"\(appPath)\"",
                "chmod -R 755 \"\(appPath)\"",
                "chown -R $(whoami):staff \"\(appPath)\"",
                "xattr -d com.apple.quarantine \"\(appPath)\" 2>/dev/null || true"
            ]
            
            var allSuccess = true
            for command in commands {
                let result = shellHelper.runCommand(command)
                if result.success {
                    report.append("  ✅ \(command.components(separatedBy: " ").first ?? command)")
                } else {
                    report.append("  ⚠️ Failed: \(command)")
                    allSuccess = false
                }
            }
            
            needsRestart = false
            return (allSuccess, report, needsRestart, manualSteps)
        } else {
            report.append("⚠️ App is NOT in Applications folder")
            report.append("For Full Disk Access to work properly, app must be in /Applications/")
            
            manualSteps.append("Move \(appName) to /Applications/ folder")
            manualSteps.append("Remove old app from current location after moving")
            manualSteps.append("Grant Full Disk Access to the app in /Applications/")
            
            needsRestart = true
            return (false, report, needsRestart, manualSteps)
        }
    }
    
    // MARK: - Step 2: Full Disk Access
    private func handleFullDiskAccess() -> (success: Bool, report: [String], manualSteps: [String]) {
        var report: [String] = []
        var manualSteps: [String] = []
        
        // Test FDA
        let testCommands = [
            ("ls /Volumes", "List volumes"),
            ("ls /System/Library/Extensions", "List system extensions"),
            ("diskutil list", "List disks")
        ]
        
        var hasAccess = true
        for (command, description) in testCommands {
            let result = shellHelper.runCommand(command)
            if !result.success && result.error.contains("Operation not permitted") {
                report.append("❌ \(description): Permission denied")
                hasAccess = false
            } else {
                report.append("✅ \(description): Access granted")
            }
        }
        
        if hasAccess {
            report.append("✅ Full Disk Access appears to be working")
            return (true, report, manualSteps)
        } else {
            report.append("⚠️ Full Disk Access not fully granted")
            manualSteps.append("Open System Settings → Privacy & Security → Full Disk Access")
            manualSteps.append("Click the lock icon (bottom left) to make changes")
            manualSteps.append("Click '+' and select SystemMaintenance from /Applications/")
            manualSteps.append("Make sure the checkbox is enabled")
            manualSteps.append("Restart SystemMaintenance")
            return (false, report, manualSteps)
        }
    }
    
    // MARK: - Step 3: System File Permissions
    private func fixSystemFilePermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let directories = [
            "/System/Library/Extensions",
            "/Library/Extensions",
            "/Library/Application Support"
        ]
        
        var successCount = 0
        var totalCount = 0
        
        for directory in directories {
            let commands = [
                "chmod -R 755 \"\(directory)\" 2>/dev/null || true",
                "chown -R root:wheel \"\(directory)\" 2>/dev/null || true",
                "touch \"\(directory)\" 2>/dev/null || true"
            ]
            
            for command in commands {
                totalCount += 1
                let result = shellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    successCount += 1
                }
            }
        }
        
        let successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) : 1.0
        let success = successRate >= 0.8
        
        report.append("Fixed permissions for \(successCount)/\(totalCount) operations (\(Int(successRate * 100))%)")
        
        return (success, report)
    }
    
    // MARK: - Step 4: Disk Utility Permissions
    private func fixDiskUtilityPermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let commands = [
            "sudo killall diskmanagementd 2>/dev/null || true",
            "sudo killall diskarbitrationd 2>/dev/null || true"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: true)
            if result.success {
                successCount += 1
            }
        }
        
        // Test diskutil access
        let testResult = shellHelper.runCommand("diskutil list 2>&1 | head -5")
        let hasAccess = testResult.success && !testResult.error.contains("Operation not permitted")
        
        if hasAccess {
            report.append("✅ Disk Utility access working")
            return (true, report)
        } else {
            report.append("⚠️ Disk Utility access may be limited")
            report.append("Error: \(testResult.error.prefix(100))")
            return (false, report)
        }
    }
    
    // MARK: - Step 5: Kext Permissions
    private func fixKextPermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        // Check SIP status first
        let sipDisabled = shellHelper.isSIPDisabled()
        
        report.append("SIP Status: \(sipDisabled ? "Disabled ✓" : "Enabled ⚠️")")
        
        if !sipDisabled {
            report.append("Note: SIP must be disabled for kext loading")
            return (false, report)
        }
        
        // Fix kextcache permissions
        let commands = [
            "sudo chmod 755 /System/Library/Extensions",
            "sudo chmod 755 /Library/Extensions",
            "sudo touch /System/Library/Extensions",
            "sudo touch /Library/Extensions"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: true)
            if result.success {
                successCount += 1
            }
        }
        
        // Rebuild kernel cache
        report.append("Rebuilding kernel cache...")
        let cacheResult = shellHelper.runCommand("sudo kextcache -i /", needsSudo: true)
        
        if cacheResult.success {
            report.append("✅ Kernel cache rebuild initiated")
        } else {
            report.append("⚠️ Kernel cache rebuild may have issues")
            report.append("Error: \(cacheResult.error.prefix(100))")
        }
        
        let success = successCount >= 3
        return (success, report)
    }
    
    // MARK: - Step 6: System Cache Reset
    private func resetSystemCaches() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let commands = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user",
            "sudo update_dyld_shared_cache -force 2>/dev/null || true",
            "sudo rm -rf /Library/Caches/* 2>/dev/null || true"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: command.contains("sudo"))
            if result.success || result.error.isEmpty {
                successCount += 1
            }
        }
        
        report.append("Reset \(successCount)/\(commands.count) cache operations")
        
        return (successCount > 1, report)
    }
    
    // MARK: - Quick Permission Check
    func getPermissionStatusText() -> String {
        let appPath = Bundle.main.bundlePath
        let inApps = appPath.contains("/Applications/")
        let hasFDA = shellHelper.checkFullDiskAccess()
        let sipDisabled = shellHelper.isSIPDisabled()
        
        var status = "🔍 Permission Status:\n\n"
        status += "Application Location: \(inApps ? "✅ /Applications/" : "❌ Not in Applications")\n"
        status += "Full Disk Access: \(hasFDA ? "✅ Granted" : "❌ Not Granted")\n"
        status += "SIP Status: \(sipDisabled ? "✅ Disabled" : "⚠️ Enabled")\n"
        
        return status
    }
    
    // MARK: - Open System Settings Helper
    func openSystemSettings() {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "System Settings Opened"
                alert.informativeText = """
                Please:
                1. Go to Privacy & Security → Full Disk Access
                2. Click the lock icon (bottom left) to make changes
                3. Click '+' and select SystemMaintenance from /Applications/
                4. Make sure the checkbox is enabled
                5. Restart SystemMaintenance
                
                If SystemMaintenance is not in /Applications/, please move it there first.
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                
                alert.runModal()
            }
        }
    }
    
    // MARK: - Public method to show guide
    func showDetailedGuide() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "📋 Complete Permission Setup Guide"
            alert.informativeText = """
            1. APPLICATION LOCATION
               • SystemMaintenance MUST be in /Applications/ folder
               • If it's in Downloads or elsewhere, move it to Applications
               • Right-click the app → "Move to Applications"
            
            2. FULL DISK ACCESS
               • Open System Settings → Privacy & Security → Full Disk Access
               • Click the lock icon (bottom left), enter password
               • Click the '+' button
               • Navigate to /Applications/ → Select "SystemMaintenance.app"
               • Make sure the checkbox is checked (enabled)
            
            3. RESTART APPLICATION
               • Quit SystemMaintenance completely
               • Open it again from /Applications/
            
            4. SYSTEM INTEGRITY PROTECTION (SIP)
               For USB boot and kext installation, SIP should be disabled:
               • Restart Mac and hold Cmd+R (Recovery Mode)
               • Open Terminal from Utilities menu
               • Run: csrutil disable
               • Reboot
            
            TROUBLESHOOTING:
            • If drives not detected: Grant Full Disk Access
            • If can't mount EFI: Check SIP is disabled
            • If app crashes: Ensure it's in /Applications/
            • If "Operation not permitted": Re-grant Full Disk Access
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open System Settings")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.openSystemSettings()
            }
        }
    }
}

// MARK: - Permission Fix View
struct PermissionFixView: View {
    @Binding var isPresented: Bool
    @State private var fixInProgress = false
    @State private var fixComplete = false
    @State private var fixReport = ""
    @State private var needsRestart = false
    @State private var manualSteps: [String] = []
    @State private var showDetailedReport = false
    @State private var cancelRequested = false
    
    let permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "lock.shield")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Fix All Permissions")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Comprehensive permission repair for SystemMaintenance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    if fixInProgress {
                        cancelRequested = true
                        fixInProgress = false
                    }
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .disabled(fixInProgress)
            }
            .padding(.top)
            
            Divider()
            
            if fixInProgress {
                FixInProgressView
            } else if fixComplete {
                FixCompleteView
            } else {
                InitialView
            }
            
            Spacer()
            
            // Footer
            HStack {
                Button("Quick Check") {
                    runQuickCheck()
                }
                .buttonStyle(.bordered)
                .disabled(fixInProgress)
                
                Spacer()
                
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .disabled(fixInProgress)
                
                Button("Show Guide") {
                    permissionManager.showDetailedGuide()
                }
                .buttonStyle(.bordered)
                .disabled(fixInProgress)
                
                if fixInProgress {
                    Button("Cancel Fix") {
                        cancelRequested = true
                        fixInProgress = false
                        fixComplete = true
                        fixReport = "=== Permission Fix Cancelled ===\n\nFix operation was cancelled by user."
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Button(fixComplete ? "Fix Again" : "Start Fix") {
                        if !fixInProgress {
                            startFix()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fixInProgress)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 700, height: 600)
    }
    
    private var InitialView: some View {
        VStack(spacing: 16) {
            Text("This will fix:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FixItem(icon: "folder", text: "Application location and permissions")
                FixItem(icon: "lock.open", text: "Full Disk Access setup")
                FixItem(icon: "gear", text: "System file permissions")
                FixItem(icon: "internaldrive", text: "Disk Utility access")
                FixItem(icon: "puzzlepiece", text: "Kernel extension permissions")
                FixItem(icon: "trash", text: "System cache reset")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            
            Text("⚠️ Some steps may require administrator password")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("Make sure SystemMaintenance is in your Applications folder for best results.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if cancelRequested {
                Text("Last operation was cancelled")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
        }
    }
    
    private var FixInProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Fixing permissions...")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This may take a few minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if cancelRequested {
                Text("Cancelling...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressStep(step: "Application Location", isActive: true)
                ProgressStep(step: "Full Disk Access", isActive: true)
                ProgressStep(step: "System Permissions", isActive: true)
                ProgressStep(step: "Disk Utility", isActive: true)
                ProgressStep(step: "Kernel Extensions", isActive: true)
                ProgressStep(step: "System Cache", isActive: true)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    private var FixCompleteView: some View {
        VStack(spacing: 20) {
            Image(systemName: needsRestart || cancelRequested ? "exclamationmark.triangle" : "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(needsRestart ? .orange : (cancelRequested ? .orange : .green))
            
            if cancelRequested {
                Text("Fix Cancelled")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            } else {
                Text(needsRestart ? "Manual Steps Required" : "Fix Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(needsRestart ? .orange : .green)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if cancelRequested {
                        Text("The fix operation was cancelled before completion. Some steps may have been partially applied.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.bottom, 8)
                    }
                    
                    Text("Summary:")
                        .font(.headline)
                    
                    if needsRestart && !cancelRequested {
                        Text("Please complete these manual steps:")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        ForEach(Array(manualSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(step)
                                    .font(.caption)
                            }
                            .padding(.leading, 8)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    if showDetailedReport {
                        Text("Detailed Report:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text(fixReport)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 300)
            
            HStack {
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fixReport, forType: .string)
                }
                .buttonStyle(.bordered)
                
                Button(showDetailedReport ? "Hide Details" : "Show Details") {
                    showDetailedReport.toggle()
                }
                .buttonStyle(.bordered)
                
                if needsRestart && !cancelRequested {
                    Button("Show Guide") {
                        permissionManager.showDetailedGuide()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                if cancelRequested {
                    Button("Retry Fix") {
                        cancelRequested = false
                        fixComplete = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
    }
    
    private func FixItem(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private func ProgressStep(step: String, isActive: Bool) -> some View {
        HStack {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(step)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
            Spacer()
            if isActive {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }
    
    private func startFix() {
        fixInProgress = true
        fixComplete = false
        cancelRequested = false
        fixReport = ""
        needsRestart = false
        manualSteps = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = permissionManager.fixAllPermissions()
            
            DispatchQueue.main.async {
                fixInProgress = false
                
                if cancelRequested {
                    fixComplete = true
                    fixReport = "=== Permission Fix Cancelled ===\n\nFix operation was cancelled by user.\n\nSome steps may have been partially completed.\n"
                } else {
                    fixComplete = true
                    fixReport = result.report
                    needsRestart = result.needsRestart
                    manualSteps = result.manualSteps
                    
                    if result.success && !needsRestart {
                        let alert = NSAlert()
                        alert.messageText = "Permissions Fixed Successfully"
                        alert.informativeText = "All permissions have been fixed. You may need to restart the application for changes to take full effect."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func runQuickCheck() {
        let status = permissionManager.getPermissionStatusText()
        
        let alert = NSAlert()
        alert.messageText = "Permission Status Check"
        alert.informativeText = status
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Fix Now")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            startFix()
        }
    }
}

// MARK: - Drive Detail View
struct DriveDetailView: View {
    let drive: DriveInfo
    @EnvironmentObject var driveManager: DriveManager
    @State private var operationInProgress = false
    @State private var operationMessage = ""
    @State private var showOperationAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .font(.largeTitle)
                    .foregroundColor(drive.isInternal ? .blue : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Text(drive.identifier)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Mount Status Badge
                if drive.isMounted {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Mounted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                } else {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("Unmounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            Divider()
            
            // Drive Info
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Type:", value: drive.type)
                InfoRow(label: "Internal:", value: drive.isInternal ? "Yes" : "No")
                InfoRow(label: "Mount Point:", value: drive.mountPoint.isEmpty ? "Not mounted" : drive.mountPoint)
                InfoRow(label: "Partitions:", value: "\(drive.partitions.count)")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Partition List
            if !drive.partitions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Partitions")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(drive.partitions) { partition in
                                PartitionRow(partition: partition)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if operationInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        if drive.isMounted {
                            unmountDrive()
                        } else {
                            mountDrive()
                        }
                    }) {
                        HStack {
                            Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                            Text(drive.isMounted ? "Unmount" : "Mount")
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(drive.isMounted ? .orange : .blue)
                    
                    // EFI Button (only show if drive has EFI partitions)
                    if drive.partitions.contains(where: { $0.isEFI }) {
                        Button("Mount EFI") {
                            mountEFIPartition()
                        }
                        .buttonStyle(.bordered)
                        .disabled(drive.isMounted)
                    }
                    
                    Button("Show in Finder") {
                        showInFinder()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!drive.isMounted || drive.mountPoint.isEmpty)
                }
                
                Spacer()
                
                Button("Refresh") {
                    driveManager.refreshDrives()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 500)
        .alert("Operation Result", isPresented: $showOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func PartitionRow(partition: PartitionInfo) -> some View {
        HStack {
            Image(systemName: partition.isEFI ? "puzzlepiece.fill" : "square.fill")
                .foregroundColor(partition.isEFI ? .purple : .gray)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(partition.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(partition.identifier)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(partition.size)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(partition.type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func mountDrive() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.mountDrive(drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func unmountDrive() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.unmountDrive(drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func mountEFIPartition() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.mountEFIPartition(for: drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func showInFinder() {
        guard !drive.mountPoint.isEmpty else { return }
        
        let url = URL(fileURLWithPath: drive.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var showPermissionFixView = false
    @State private var selectedDrive: DriveInfo?
    @StateObject private var driveManager = DriveManager.shared
    @State private var hasFullDiskAccess = false
    @State private var showDebugInfo = false
    
    let shellHelper = ShellHelper.shared
    let permissionManager = PermissionManager.shared
    
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
            
            if driveManager.isLoading {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showPermissionFixView) {
            PermissionFixView(isPresented: $showPermissionFixView)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive)
                .environmentObject(driveManager)
        }
        .onAppear {
            checkPermissions()
            driveManager.refreshDrives()
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
                    let internalCount = driveManager.allDrives.filter { $0.isInternal }.count
                    let externalCount = driveManager.allDrives.filter { !$0.isInternal }.count
                    Text("\(internalCount) Internal • \(externalCount) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(driveManager.allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // SIP Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(shellHelper.isSIPDisabled() ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text("SIP: \(shellHelper.isSIPDisabled() ? "Disabled" : "Enabled")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(shellHelper.isSIPDisabled() ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(20)
                
                // Fix Permissions Button
                Button(action: {
                    showPermissionFixView = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Fix Permissions")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
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
                
                // Permission Fix Section
                PermissionFixSection
                
                // Quick Actions
                QuickActionsGrid
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
                
                Button("Fix Now") {
                    showPermissionFixView = true
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
                
                HStack(spacing: 8) {
                    Button("Unmount All") {
                        unmountAllDrives()
                    }
                    .buttonStyle(.bordered)
                    .disabled(driveManager.allDrives.allSatisfy { !$0.isMounted })
                    
                    Button(action: {
                        driveManager.refreshDrives()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(driveManager.isLoading)
                }
            }
            
            if driveManager.allDrives.isEmpty {
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
            
            Button("Check USB Drives") {
                checkUSBDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
            
            Button("Debug Info") {
                showDebugInfoAlert()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var DrivesListView: some View {
        VStack(spacing: 8) {
            ForEach(driveManager.allDrives) { drive in
                DriveRow(drive: drive)
                    .onTapGesture {
                        selectedDrive = drive
                    }
            }
        }
    }
    
    private func DriveRow(drive: DriveInfo) -> some View {
        HStack {
            // Drive Icon
            Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                .foregroundColor(drive.isInternal ? .blue : .orange)
                .font(.title3)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(drive.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                
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
                    
                    if !drive.mountPoint.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Spacer()
            
            // Mount/Unmount Button
            Button(action: {
                toggleMount(drive)
            }) {
                HStack {
                    Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        .font(.caption)
                    Text(drive.isMounted ? "Unmount" : "Mount")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(drive.isMounted ? .orange : .blue)
            
            // Detail Button
            Button(action: {
                selectedDrive = drive
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
    
    private var PermissionFixSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Permission Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Quick Check") {
                    runQuickPermissionCheck()
                }
                .buttonStyle(.bordered)
            }
            
            let status = permissionManager.getPermissionStatusText()
            Text(status)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.bordered)
                
                Button("Show Guide") {
                    permissionManager.showDetailedGuide()
                }
                .buttonStyle(.bordered)
                
                Button("Fix All") {
                    showPermissionFixView = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var QuickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ActionButton(
                title: "Refresh All",
                icon: "arrow.clockwise",
                color: .blue,
                action: {
                    driveManager.refreshDrives()
                    checkPermissions()
                }
            )
            
            ActionButton(
                title: "Check USB",
                icon: "magnifyingglass",
                color: .green,
                action: checkUSBDrives
            )
            
            ActionButton(
                title: "System Info",
                icon: "info.circle",
                color: .purple,
                action: showSystemInfo
            )
            
            ActionButton(
                title: "Unmount All",
                icon: "eject",
                color: .orange,
                action: unmountAllDrives
            )
            
            ActionButton(
                title: "Debug Info",
                icon: "ladybug",
                color: .red,
                action: showDebugInfoAlert
            )
            
            ActionButton(
                title: "Fix Permissions",
                icon: "lock.shield",
                color: .blue,
                action: {
                    showPermissionFixView = true
                }
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func ActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundColor(color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
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
                    
                    Button(action: {
                        driveManager.refreshDrives()
                        showAlert(title: "Refreshed", message: "System information updated")
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Permission Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permission Status")
                        .font(.headline)
                    
                    let status = permissionManager.getPermissionStatusText()
                    Text(status)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drives Info
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Storage Drives")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(driveManager.allDrives.count) drives total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(driveManager.allDrives) { drive in
                            DriveInfoCard(drive: drive)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
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
                
                if drive.isMounted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
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
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            
            if !drive.partitions.isEmpty {
                Text("Partitions: \(drive.partitions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            selectedDrive = drive
        }
    }
    
    // MARK: - Progress Overlay
    private var ProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading drives...")
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
                             message: "Full Disk Access is required for drive detection. Use 'Fix Permissions' to resolve this.")
                }
            }
        }
    }
    
    private func toggleMount(_ drive: DriveInfo) {
        if drive.isMounted {
            let result = driveManager.unmountDrive(drive)
            showAlert(title: result.success ? "Unmounted" : "Error",
                     message: result.message)
        } else {
            let result = driveManager.mountDrive(drive)
            showAlert(title: result.success ? "Mounted" : "Error",
                     message: result.message)
        }
    }
    
    private func unmountAllDrives() {
        let result = driveManager.unmountAll()
        showAlert(title: result.success ? "Unmounted All" : "Error",
                 message: result.message)
    }
    
    private func checkUSBDrives() {
        let usbDrives = shellHelper.findUSBDrives()
        
        if usbDrives.isEmpty {
            showAlert(title: "No USB Drives",
                     message: "No USB drives detected.\n\nPlease ensure:\n1. USB drive is connected\n2. Try different USB port\n3. Check if drive appears in Disk Utility")
        } else {
            showAlert(title: "USB Drives Found",
                     message: "Found \(usbDrives.count) USB drive(s):\n\n\(usbDrives.joined(separator: "\n"))")
        }
    }
    
    private func showSystemInfo() {
        let appPath = Bundle.main.bundlePath
        let inApps = appPath.contains("/Applications/")
        let hasFDA = shellHelper.checkFullDiskAccess()
        let sipDisabled = shellHelper.isSIPDisabled()
        
        var info = "=== System Information ===\n\n"
        info += "App Path: \(appPath)\n"
        info += "In Applications: \(inApps ? "Yes" : "No")\n"
        info += "Full Disk Access: \(hasFDA ? "Granted" : "Not Granted")\n"
        info += "SIP Status: \(sipDisabled ? "Disabled" : "Enabled")\n"
        info += "USB Drives: \(shellHelper.findUSBDrives().count)\n"
        info += "Total Drives: \(driveManager.allDrives.count)\n"
        info += "Mounted Drives: \(driveManager.allDrives.filter { $0.isMounted }.count)\n"
        
        showAlert(title: "System Information", message: info)
    }
    
    private func runQuickPermissionCheck() {
        let status = permissionManager.getPermissionStatusText()
        showAlert(title: "Permission Status", message: status)
    }
    
    private func showDebugInfoAlert() {
        let debugInfo = shellHelper.debugDriveDetection()
        
        // Create a scrollable text view for the debug info
        let alert = NSAlert()
        alert.messageText = "Drive Detection Debug Info"
        alert.informativeText = "Please share this info if you're having issues:"
        
        // Create a scrollable text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: scrollView.bounds)
        textView.string = debugInfo
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        alert.accessoryView = scrollView
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(debugInfo, forType: .string)
        }
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