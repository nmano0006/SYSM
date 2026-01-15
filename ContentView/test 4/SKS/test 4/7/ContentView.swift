import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine

// MARK: - Shell Helper
class ShellHelper {
    static let shared = ShellHelper()
    
    private init() {}
    
    func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, error: String, success: Bool) {
        print("🔧 Running command: \(command)")
        
        guard !command.isEmpty else {
            print("❌ Empty command provided")
            return ("", "Empty command", false)
        }
        
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if needsSudo {
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = """
            do shell script "\(escapedCommand)" \
            with administrator privileges \
            with prompt "Drive Manager needs administrator access" \
            without altering line endings
            """
            
            let appleScriptCommand = "osascript -e '\(appleScript)'"
            print("🛡️ Running with sudo via AppleScript")
            task.arguments = ["-c", appleScriptCommand]
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
        
        if !success {
            print("❌ Command failed with exit code: \(task.terminationStatus)")
        }
        
        print("📝 Command output: \(output)")
        if !errorOutput.isEmpty {
            print("⚠️ Command error: \(errorOutput)")
        }
        print("✅ Command success: \(success)")
        
        return (output, errorOutput, success)
    }
    
    // Get all drives including EFI
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // First get mounted drives from df -h
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.starts(with: "Filesystem") {
                continue
            }
            
            let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 6 else { continue }
            
            let devicePath = components[0]
            let size = components[1]
            let mountPoint = components[5...].joined(separator: " ")
            
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                let drive = getDriveInfo(deviceId: deviceId)
                let volumeName = (mountPoint as NSString).lastPathComponent
                var finalName = drive.name
                
                if volumeName != "." && volumeName != "/" && !volumeName.isEmpty {
                    if finalName == "Disk \(deviceId)" || finalName.isEmpty || finalName == deviceId {
                        finalName = volumeName
                    }
                }
                
                let updatedDrive = DriveInfo(
                    name: finalName,
                    identifier: deviceId,
                    size: size,
                    type: drive.type,
                    mountPoint: mountPoint,
                    isInternal: drive.isInternal,
                    isEFI: drive.isEFI,
                    partitions: drive.partitions,
                    isMounted: true,
                    isSelectedForMount: false,
                    isSelectedForUnmount: false
                )
                
                drives.append(updatedDrive)
                print("📌 Found mounted: \(updatedDrive.name) (\(deviceId))")
            }
        }
        
        // Now actively search for EFI partitions
        print("🔍 Actively searching for EFI partitions...")
        
        // Get detailed info for all potential EFI partitions
        let allDisks = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1", 
                       "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                       "disk12s1", "disk13s1"]
        
        for partitionId in allDisks {
            // Skip if already in list
            if !drives.contains(where: { $0.identifier == partitionId }) {
                let drive = getDriveInfo(deviceId: partitionId)
                
                // Check mount status
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isActuallyMounted = !mountCheck.output.isEmpty
                
                // Update mount point if actually mounted
                var updatedDrive = drive
                updatedDrive.isMounted = isActuallyMounted
                
                if isActuallyMounted {
                    // Extract mount point from mount command
                    let mountLine = mountCheck.output
                    if let range = mountLine.range(of: "on (.+?) \\(|$", options: .regularExpression) {
                        let mountInfo = mountLine[range]
                        if mountInfo.contains("on ") {
                            let parts = mountInfo.components(separatedBy: "on ")
                            if parts.count > 1 {
                                let mountPath = parts[1].components(separatedBy: " ").first ?? ""
                                updatedDrive.mountPoint = mountPath
                            }
                        }
                    }
                }
                
                drives.append(updatedDrive)
                
                if drive.isEFI {
                    print("🔐 Found EFI: \(partitionId) - Mounted: \(isActuallyMounted)")
                }
            }
        }
        
        // Sort: EFI first, then mounted, then unmounted
        drives.sort {
            if $0.isEFI != $1.isEFI {
                return $0.isEFI && !$1.isEFI
            }
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null")
        
        var name = "Disk \(deviceId)"
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = true
        var isMounted = false
        var isEFI = false
        
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            if trimmedLine.contains(":") {
                let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    switch key {
                    case "Volume Name":
                        if !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                    case "Device / Media Name":
                        if (name == "Disk \(deviceId)" || name.isEmpty) && !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                    case "Volume Size", "Disk Size", "Total Size":
                        if !value.isEmpty && value != "(null)" && !value.contains("(zero)") {
                            size = value
                        }
                    case "Mount Point":
                        mountPoint = value
                        isMounted = !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "Not mounted"
                    case "Type (Bundle)":
                        if value.contains("EFI") || value.contains("msdos") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" {
                                name = "EFI System Partition"
                            }
                        } else if value.contains("ntfs") {
                            type = "NTFS"
                        } else if value.contains("hfs") {
                            type = "HFS+"
                        } else if value.contains("apfs") {
                            type = "APFS"
                        } else if value.contains("fat") {
                            type = "FAT32"
                        }
                    case "Partition Type":
                        if value.contains("EFI") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" {
                                name = "EFI System Partition"
                            }
                        }
                    case "Protocol":
                        if value.contains("USB") {
                            isInternal = false
                        }
                    case "Internal":
                        isInternal = value.contains("Yes")
                    default:
                        break
                    }
                }
            }
        }
        
        return DriveInfo(
            name: name,
            identifier: deviceId,
            size: size,
            type: type,
            mountPoint: mountPoint,
            isInternal: isInternal,
            isEFI: isEFI,
            partitions: [],
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    // Mount drive (with special handling for EFI)
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        var mountCommand = "diskutil mount /dev/\(drive.identifier)"
        var needsSudo = false
        
        // EFI partitions need sudo
        if drive.isEFI {
            needsSudo = true
            
            // First unmount any existing EFI mount
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier) 2>/dev/null", needsSudo: true)
            print("Tried unmounting existing: \(unmountResult.success ? "Success" : "Failed")")
            
            // Try different mount methods for EFI
            let result = runCommand(mountCommand, needsSudo: true)
            
            if result.success {
                // Verify it's actually mounted
                let verify = runCommand("mount | grep '/dev/\(drive.identifier)'")
                if !verify.output.isEmpty {
                    return (true, "✅ EFI partition mounted successfully")
                }
            }
            
            // Try alternative method - mount to /Volumes/EFI with proper cleanup
            runCommand("sudo diskutil unmount /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo rm -rf /Volumes/EFI 2>/dev/null", needsSudo: true)
            
            let altResult = runCommand("sudo mkdir -p /Volumes/EFI && sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI", needsSudo: true)
            if altResult.success {
                // Verify mount
                let verify = runCommand("mount | grep '/dev/\(drive.identifier)'")
                if !verify.output.isEmpty {
                    return (true, "✅ EFI mounted at /Volumes/EFI")
                }
            }
            
            // Last resort: try different mount options
            let lastTry = runCommand("sudo mount -t msdos -o noowners,rw /dev/\(drive.identifier) /Volumes/EFI", needsSudo: true)
            if lastTry.success {
                return (true, "✅ EFI mounted with read-write access")
            }
            
            return (false, "❌ Failed to mount EFI. Try manually: sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI")
        }
        
        // Regular mount for non-EFI
        let result = runCommand(mountCommand, needsSudo: needsSudo)
        
        if result.success {
            return (true, "✅ \(drive.name) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(drive.name)")
        }
    }
    
    // Unmount drive
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
            return (false, "⚠️ Cannot unmount system volume")
        }
        
        let unmountCommand = "diskutil unmount /dev/\(drive.identifier)"
        let result = runCommand(unmountCommand)
        
        if result.success {
            return (true, "✅ \(drive.name) unmounted successfully")
        } else {
            // Try force unmount for stubborn drives
            let forceResult = runCommand("diskutil unmount force /dev/\(drive.identifier)")
            if forceResult.success {
                return (true, "✅ \(drive.name) force unmounted")
            }
            return (false, "❌ Failed to unmount \(drive.name)")
        }
    }
    
    // Special EFI mounting function
    func mountEFIPartition(_ partitionId: String) -> (success: Bool, message: String) {
        print("🔐 Mounting EFI partition: \(partitionId)")
        
        // Get drive info first
        let drive = getDriveInfo(deviceId: partitionId)
        
        if !drive.isEFI {
            return (false, "❌ \(partitionId) is not an EFI partition")
        }
        
        // First try standard diskutil mount
        let result1 = runCommand("diskutil mount /dev/\(partitionId)", needsSudo: true)
        
        if result1.success {
            // Verify mount
            let verify = runCommand("mount | grep '/dev/\(partitionId)'")
            if !verify.output.isEmpty {
                return (true, "✅ EFI partition \(partitionId) mounted successfully")
            }
        }
        
        // Clean up any existing mount
        runCommand("sudo diskutil unmount /Volumes/EFI 2>/dev/null", needsSudo: true)
        runCommand("sudo rm -rf /Volumes/EFI 2>/dev/null", needsSudo: true)
        
        // Try manual mount to /Volumes/EFI
        let result2 = runCommand("sudo mkdir -p /Volumes/EFI && sudo mount -t msdos /dev/\(partitionId) /Volumes/EFI", needsSudo: true)
        
        if result2.success {
            let verify = runCommand("mount | grep '/dev/\(partitionId)'")
            if !verify.output.isEmpty {
                return (true, "✅ EFI mounted at /Volumes/EFI")
            }
        }
        
        // Try with read-write permissions
        let result3 = runCommand("sudo mount -t msdos -o noowners,rw /dev/\(partitionId) /Volumes/EFI", needsSudo: true)
        
        if result3.success {
            return (true, "✅ EFI mounted with read-write access")
        }
        
        return (false, "❌ Failed to mount EFI partition \(partitionId)")
    }
    
    func findEFIPartitions() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Partition Search Results:")
        messages.append("=================================")
        
        // Check all potential EFI partitions
        let potentialEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1",
                           "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                           "disk12s1", "disk13s1"]
        
        var foundEFIs: [(String, String, Bool)] = []
        
        for partitionId in potentialEFIs {
            let drive = getDriveInfo(deviceId: partitionId)
            if drive.isEFI {
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isMounted = !mountCheck.output.isEmpty
                foundEFIs.append((partitionId, drive.name, isMounted))
            }
        }
        
        if foundEFIs.isEmpty {
            messages.append("No EFI partitions found")
        } else {
            messages.append("Found \(foundEFIs.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted) in foundEFIs {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id): \(name) - \(status)")
            }
            
            messages.append("")
            messages.append("💡 Recommendations:")
            messages.append("1. Try mounting disk1s1, disk2s1, or disk3s1 (named 'EFI')")
            messages.append("2. These are likely your macOS drive EFI partitions")
            messages.append("3. disk0s1 is likely your Windows drive EFI")
        }
        
        return messages.joined(separator: "\n")
    }
    
    // Enhanced EFI Check function
    func performEFICheck() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Health Check:")
        messages.append("====================")
        
        // Get system info
        messages.append("📋 System Information:")
        let systemInfo = runCommand("sw_vers -productVersion")
        let buildInfo = runCommand("sw_vers -buildVersion")
        messages.append("macOS Version: \(systemInfo.output) (\(buildInfo.output))")
        
        // Check current user
        let userCheck = runCommand("whoami")
        messages.append("Current User: \(userCheck.output)")
        
        // Check disk utility status
        messages.append("\n💾 Disk Utility Status:")
        let diskUtilStatus = runCommand("diskutil list")
        if diskUtilStatus.success {
            messages.append("✅ Disk Utility is responsive")
            
            // Count partitions
            let partitionCount = diskUtilStatus.output.components(separatedBy: "\n").filter { 
                $0.contains("disk") && $0.contains("s")
            }.count
            messages.append("Partitions detected: \(partitionCount)")
        } else {
            messages.append("❌ Disk Utility may not be responding")
        }
        
        // Check for EFI partitions
        messages.append("\n🔐 EFI Partition Scan:")
        
        // Method 1: Check all potential EFI partitions
        let potentialEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1",
                           "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                           "disk12s1", "disk13s1"]
        
        var efiFound: [(String, String, Bool, String)] = []
        
        for partitionId in potentialEFIs {
            let drive = getDriveInfo(deviceId: partitionId)
            if drive.isEFI {
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isMounted = !mountCheck.output.isEmpty
                let mountPoint = isMounted ? drive.mountPoint : "Not mounted"
                efiFound.append((partitionId, drive.name, isMounted, mountPoint))
            }
        }
        
        if efiFound.isEmpty {
            messages.append("❌ No EFI partitions found")
        } else {
            messages.append("✅ Found \(efiFound.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted, mountPoint) in efiFound {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id):")
                messages.append("  Name: \(name)")
                messages.append("  Status: \(status)")
                if isMounted {
                    messages.append("  Mount Point: \(mountPoint)")
                }
                messages.append("")
            }
        }
        
        // Check /Volumes/EFI directory
        messages.append("\n📁 /Volumes/EFI Directory Check:")
        let volumeCheck = runCommand("ls -la /Volumes/ 2>/dev/null | grep -i EFI")
        if volumeCheck.output.isEmpty {
            messages.append("❌ /Volumes/EFI directory does not exist")
            messages.append("   Creating directory...")
            let createResult = runCommand("sudo mkdir -p /Volumes/EFI 2>/dev/null", needsSudo: true)
            if createResult.success {
                messages.append("   ✅ Directory created successfully")
            } else {
                messages.append("   ⚠️ Could not create directory (permissions issue)")
            }
        } else {
            messages.append("✅ /Volumes/EFI directory exists:")
            let lines = volumeCheck.output.components(separatedBy: "\n")
            for line in lines {
                if !line.isEmpty {
                    messages.append("  " + line)
                }
            }
            
            // Check if it's actually a mount point
            let mountCheck = runCommand("mount | grep /Volumes/EFI")
            if mountCheck.output.isEmpty {
                messages.append("  ⚠️ Directory exists but is not mounted")
            } else {
                messages.append("  ✅ Directory is currently mounted")
            }
        }
        
        // Check current mounts
        messages.append("\n📌 Current Mount Status:")
        let mountCheck = runCommand("mount | grep -E 'disk.*s1|EFI' | head -10")
        if mountCheck.output.isEmpty {
            messages.append("No relevant partitions currently mounted")
        } else {
            let lines = mountCheck.output.components(separatedBy: "\n")
            for line in lines {
                if !line.isEmpty {
                    messages.append("  " + line)
                }
            }
        }
        
        // Check permissions
        messages.append("\n🔑 Permissions Check:")
        let sudoCheck = runCommand("sudo -n true 2>&1")
        if sudoCheck.success {
            messages.append("✅ Sudo access available (password cached)")
        } else {
            messages.append("⚠️ Sudo access requires password")
            messages.append("   You'll need to enter your password when mounting EFI")
        }
        
        // Check disk space
        messages.append("\n💾 Available Disk Space:")
        let diskSpace = runCommand("df -h / 2>/dev/null | tail -1")
        if diskSpace.success {
            messages.append("System Drive: \(diskSpace.output)")
        }
        
        // Your specific EFI partitions (from your output)
        messages.append("\n🔍 Your Specific EFI Partitions:")
        messages.append("Based on your system configuration:")
        messages.append("• disk0s1: Windows drive EFI (104.9 MB)")
        messages.append("• disk1s1: macOS drive EFI (SSD 860) - 209.7 MB")
        messages.append("• disk2s1: macOS drive EFI - 209.7 MB")
        messages.append("• disk3s1: macOS drive EFI (pos drive) - 209.7 MB")
        
        // Recommendations
        messages.append("\n💡 Actionable Recommendations:")
        
        if efiFound.isEmpty {
            messages.append("1. No EFI partitions detected - this is unusual")
            messages.append("2. Check if diskutil is working correctly")
            messages.append("3. Try restarting the app or your computer")
        } else {
            let unmountedEFIs = efiFound.filter { !$0.2 }
            if !unmountedEFIs.isEmpty {
                messages.append("1. You have \(unmountedEFIs.count) unmounted EFI partitions")
                messages.append("2. Try mounting disk1s1, disk2s1, or disk3s1")
                messages.append("3. These are your macOS drive EFI partitions")
                messages.append("4. You'll need to enter your password when prompted")
            } else {
                messages.append("1. All EFI partitions are mounted")
                messages.append("2. You can access them through their mount points")
                messages.append("3. Always unmount EFI before shutting down")
            }
            
            messages.append("")
            messages.append("🔧 Quick Mount Commands:")
            messages.append("  • disk1s1: sudo diskutil mount /dev/disk1s1")
            messages.append("  • disk2s1: sudo diskutil mount /dev/disk2s1")
            messages.append("  • disk3s1: sudo diskutil mount /dev/disk3s1")
        }
        
        messages.append("\n✅ EFI Check Complete")
        return messages.joined(separator: "\n")
    }
    
    func debugMountIssues() -> String {
        var messages: [String] = []
        
        messages.append("🔍 Debug Information:")
        messages.append("=====================")
        
        let drives = getAllDrives()
        
        messages.append("Total drives: \(drives.count)")
        messages.append("Mounted: \(drives.filter { $0.isMounted }.count)")
        messages.append("Unmounted: \(drives.filter { !$0.isMounted }.count)")
        messages.append("EFI partitions: \(drives.filter { $0.isEFI }.count)")
        
        messages.append("\n📊 Drive List:")
        for drive in drives {
            let status = drive.isMounted ? "📌 MOUNTED" : "📦 UNMOUNTED"
            let efiMark = drive.isEFI ? "🔐 " : ""
            messages.append("• \(efiMark)\(drive.name) (\(drive.identifier)) - \(drive.size) - \(drive.type) - \(status)")
        }
        
        return messages.joined(separator: "\n")
    }
}

// MARK: - Data Structures
struct DriveInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: String
    let type: String
    var mountPoint: String
    let isInternal: Bool
    let isEFI: Bool
    let partitions: [PartitionInfo]
    var isMounted: Bool
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
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
    @Published var showEFISearch = false
    @Published var efiSearchResult = ""
    @Published var showEFICheck = false
    @Published var efiCheckResult = ""
    
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
    
    func toggleMountUnmount(for drive: DriveInfo) -> (success: Bool, message: String) {
        if drive.isMounted {
            return unmountDrive(drive)
        } else {
            return mountDrive(drive)
        }
    }
    
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountDrive(drive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.unmountDrive(drive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func mountEFIPartition(_ partitionId: String) -> (success: Bool, message: String) {
        let result = shellHelper.mountEFIPartition(partitionId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func searchForEFI() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shellHelper.findEFIPartitions()
            
            DispatchQueue.main.async {
                self.efiSearchResult = result
                self.showEFISearch = true
                self.isLoading = false
            }
        }
    }
    
    func performEFICheck() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shellHelper.performEFICheck()
            
            DispatchQueue.main.async {
                self.efiCheckResult = result
                self.showEFICheck = true
                self.isLoading = false
                self.refreshDrives()
            }
        }
    }
    
    func debugMountIssues() -> String {
        return shellHelper.debugMountIssues()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var selectedEFI = "disk1s1"
    @State private var showQuickMountMenu = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    DriveListView
                        .tabItem {
                            Label("Drives", systemImage: "externaldrive")
                        }
                        .tag(0)
                    
                    EFIView
                        .tabItem {
                            Label("EFI Tools", systemImage: "memorychip")
                        }
                        .tag(1)
                    
                    DebugView
                        .tabItem {
                            Label("Debug", systemImage: "info.circle")
                        }
                        .tag(2)
                }
            }
            
            if driveManager.isLoading {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { 
                if alertTitle == "Success" || alertTitle == "Error" {
                    driveManager.refreshDrives()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .alert("EFI Search Results", isPresented: $driveManager.showEFISearch) {
            Button("OK") { }
            Button("Refresh") {
                driveManager.refreshDrives()
            }
        } message: {
            ScrollView {
                Text(driveManager.efiSearchResult)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 400)
        }
        .alert("EFI Check Results", isPresented: $driveManager.showEFICheck) {
            Button("OK") { }
            Button("Refresh Drives") {
                driveManager.refreshDrives()
            }
        } message: {
            ScrollView {
                Text(driveManager.efiCheckResult)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 500)
        }
        .onAppear {
            driveManager.refreshDrives()
        }
    }
    
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drive Manager")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("EFI & Drive Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    let efiCount = driveManager.allDrives.filter { $0.isEFI }.count
                    
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if efiCount > 0 {
                        Text("\(efiCount) EFI")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                
                // Quick Mount Menu
                Menu {
                    Button("Mount All EFI") {
                        mountAllEFI()
                    }
                    
                    Button("Unmount All EFI") {
                        unmountAllEFI()
                    }
                    
                    Divider()
                    
                    Button("Mount disk1s1") {
                        quickMountEFI("disk1s1")
                    }
                    
                    Button("Mount disk2s1") {
                        quickMountEFI("disk2s1")
                    }
                    
                    Button("Mount disk3s1") {
                        quickMountEFI("disk3s1")
                    }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Quick Actions")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.isLoading)
                
                // Refresh Button
                Button(action: {
                    driveManager.refreshDrives()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.isLoading)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    private var DriveListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Mount Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        driveManager.searchForEFI()
                    }) {
                        HStack {
                            Image(systemName: "memorychip")
                            Text("Find EFI")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    
                    Button(action: {
                        driveManager.performEFICheck()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("EFI Check")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drive List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    VStack(spacing: 8) {
                        // EFI Partitions Section
                        let efiDrives = driveManager.allDrives.filter { $0.isEFI }
                        if !efiDrives.isEmpty {
                            Text("EFI Partitions")
                                .font(.headline)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ForEach(efiDrives) { drive in
                                DriveCardView(drive: drive)
                            }
                        }
                        
                        // Regular Drives Section
                        let regularDrives = driveManager.allDrives.filter { !$0.isEFI }
                        if !regularDrives.isEmpty {
                            Text("Other Drives")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, efiDrives.isEmpty ? 0 : 20)
                            
                            ForEach(regularDrives) { drive in
                                DriveCardView(drive: drive)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var EFIView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("EFI Partition Tools")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                // EFI Check Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("EFI Health Check")
                            .font(.headline)
                    }
                    
                    Text("Comprehensive check of EFI partition status, permissions, and mount readiness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        driveManager.performEFICheck()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Run EFI Check")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Your EFI Partitions Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("Your EFI Partitions")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                            Text("Windows Drive EFI")
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("• disk0s1")
                                .font(.system(.body, design: .monospaced))
                            Text("104.9 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Windows")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "macbook")
                            Text("macOS Drive EFI Partitions")
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("• disk1s1")
                                .font(.system(.body, design: .monospaced))
                            Text("209.7 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("SSD 860")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Text("• disk2s1")
                                .font(.system(.body, design: .monospaced))
                            Text("209.7 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("macOS")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Text("• disk3s1")
                                .font(.system(.body, design: .monospaced))
                            Text("209.7 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("pos drive")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("💡 First partition (s1) of each disk is usually the EFI partition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // EFI Mount Controls
                VStack(spacing: 12) {
                    Text("Mount EFI Partition:")
                        .font(.headline)
                    
                    Picker("Select EFI Partition:", selection: $selectedEFI) {
                        Text("disk1s1 (SSD 860)").tag("disk1s1")
                        Text("disk2s1").tag("disk2s1")
                        Text("disk3s1 (pos drive)").tag("disk3s1")
                        Text("disk0s1 (Windows)").tag("disk0s1")
                    }
                    .pickerStyle(.menu)
                    
                    Button(action: {
                        mountSelectedEFI()
                    }) {
                        HStack {
                            Image(systemName: "memorychip")
                            Text("Mount \(selectedEFI)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    
                    Text("Note: EFI mounting requires administrator password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Manual Command
                VStack(spacing: 12) {
                    Text("Manual EFI Commands:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terminal commands to mount EFI:")
                            .font(.caption)
                        
                        CodeBlock(text: "sudo diskutil mount /dev/disk1s1")
                        
                        CodeBlock(text: "sudo mount -t msdos /dev/disk1s1 /Volumes/EFI")
                        
                        CodeBlock(text: "sudo mount -t msdos -o noowners,rw /dev/disk1s1 /Volumes/EFI")
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func CodeBlock(text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.1))
            .cornerRadius(4)
            .textSelection(.enabled)
    }
    
    private var DebugView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Debug Information")
                    .font(.title)
                    .fontWeight(.bold)
                
                Button("Show Debug Info") {
                    showDebugView()
                }
                .buttonStyle(.borderedProminent)
                
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Drives:")
                            .font(.headline)
                        
                        ForEach(driveManager.allDrives.filter { $0.isEFI }) { drive in
                            EFIDebugCard(drive: drive)
                        }
                        
                        ForEach(driveManager.allDrives.filter { !$0.isEFI }) { drive in
                            DriveDebugCard(drive: drive)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func EFIDebugCard(drive: DriveInfo) -> some View {
        HStack {
            Image(systemName: "memorychip")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.name)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Text("\(drive.identifier) • \(drive.size)")
                    .font(.caption)
                
                if drive.isMounted {
                    Text(drive.mountPoint)
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Unmounted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                toggleDrive(drive)
            }) {
                Text(drive.isMounted ? "Unmount" : "Mount")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func DriveDebugCard(drive: DriveInfo) -> some View {
        HStack {
            Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                .foregroundColor(drive.type == "NTFS" ? .red : (drive.isInternal ? .blue : .orange))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.name)
                    .font(.headline)
                
                Text("\(drive.identifier) • \(drive.size) • \(drive.type)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if drive.isMounted {
                    Text(drive.mountPoint)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Text(drive.isMounted ? "✓" : "○")
                .foregroundColor(drive.isMounted ? .green : .gray)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveCardView(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon
                if drive.isEFI {
                    Image(systemName: "memorychip")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 30)
                } else {
                    Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                        .font(.title2)
                        .foregroundColor(drive.type == "NTFS" ? .red : (drive.isInternal ? .blue : .orange))
                        .frame(width: 30)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(drive.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if drive.isEFI {
                            Text("EFI")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 8) {
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
                            .foregroundColor(drive.type == "NTFS" ? .red : .secondary)
                    }
                }
                
                Spacer()
                
                // Status
                if drive.isMounted {
                    VStack(alignment: .trailing) {
                        Text("Mounted")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        if !drive.mountPoint.isEmpty && drive.mountPoint != "/" {
                            Text(drive.mountPoint)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 150)
                        }
                    }
                } else {
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action Button
                Button(action: {
                    toggleDrive(drive)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        Text(drive.isMounted ? "Unmount" : "Mount")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(drive.isMounted ? .orange : (drive.isEFI ? .purple : .green))
                .disabled(!canToggle(drive: drive))
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(drive.isEFI ? Color.purple.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
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
    
    private func canToggle(drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            return true
        }
    }
    
    // MARK: - Actions
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountSelectedEFI() {
        let result = driveManager.mountEFIPartition(selectedEFI)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func quickMountEFI(_ partitionId: String) {
        let result = driveManager.mountEFIPartition(partitionId)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountAllEFI() {
        let efiDrives = driveManager.allDrives.filter { $0.isEFI && !$0.isMounted }
        
        if efiDrives.isEmpty {
            showAlert(title: "Info", message: "All EFI partitions are already mounted")
            return
        }
        
        var successCount = 0
        for drive in efiDrives {
            let result = driveManager.mountDrive(drive)
            if result.success {
                successCount += 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            driveManager.refreshDrives()
            showAlert(title: "Complete", 
                     message: "Mounted \(successCount) of \(efiDrives.count) EFI partitions")
        }
    }
    
    private func unmountAllEFI() {
        let efiDrives = driveManager.allDrives.filter { $0.isEFI && $0.isMounted }
        
        if efiDrives.isEmpty {
            showAlert(title: "Info", message: "No EFI partitions are mounted")
            return
        }
        
        var successCount = 0
        for drive in efiDrives {
            let result = driveManager.unmountDrive(drive)
            if result.success {
                successCount += 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            driveManager.refreshDrives()
            showAlert(title: "Complete", 
                     message: "Unmounted \(successCount) of \(efiDrives.count) EFI partitions")
        }
    }
    
    private func showDebugView() {
        let debugInfo = driveManager.debugMountIssues()
        alertTitle = "Debug Information"
        alertMessage = debugInfo
        showAlert = true
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
