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
                       "disk12s1", "disk13s1", "disk8s4s1", "disk8s2", "disk8s5", "disk8s6",
                       "disk9s4", "disk3s2", "disk3s3", "disk4s2", "disk5s2", "disk6s2",
                       "disk6s3", "disk6s4", "disk0s3"]
        
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
                        if !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "NO NAME" {
                            name = value
                        }
                    case "Device / Media Name":
                        if (name == "Disk \(deviceId)" || name.isEmpty || name == "NO NAME") && !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                    case "Volume Size", "Disk Size", "Total Size":
                        if !value.isEmpty && value != "(null)" && !value.contains("(zero)") {
                            // Clean up the size format
                            if value.contains("(") {
                                // Format like "209.7 MB (209715200 Bytes)"
                                let cleanSize = value.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? value
                                size = cleanSize
                            } else {
                                size = value
                            }
                        }
                    case "Mount Point":
                        mountPoint = value
                        isMounted = !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "Not mounted"
                    case "Type (Bundle)":
                        if value.contains("EFI") || value.contains("msdos") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" || name == "Not applicable" {
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
                        } else if value.contains("crypto") {
                            type = "Encrypted"
                        } else if value.contains("exfat") {
                            type = "exFAT"
                        }
                    case "Partition Type":
                        if value.contains("EFI") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" || name == "Not applicable" {
                                name = "EFI System Partition"
                            }
                        }
                    case "Protocol":
                        if value.contains("USB") || value.contains("SATA") {
                            isInternal = false
                        }
                    case "Internal":
                        isInternal = value.contains("Yes")
                    case "Device Identifier":
                        // Use better naming for APFS containers
                        if value.contains("Apple_APFS") && (name == "Disk \(deviceId)" || name.isEmpty) {
                            name = "APFS Container"
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        // Additional checks for EFI
        if !isEFI {
            // Check if it's an EFI partition by size and position
            if deviceId.hasSuffix("s1") && size.contains("MB") && (size.contains("104.9") || size.contains("209.7") || size.contains("314.6")) {
                let checkResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null | grep -i 'partition.*type.*efi'")
                if checkResult.success {
                    isEFI = true
                    type = "EFI"
                    if name == "Disk \(deviceId)" || name == "NO NAME" || name == "Not applicable" {
                        name = "EFI System Partition"
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
    
    // Enhanced mount function
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        if drive.isMounted {
            return (true, "✅ \(drive.name) is already mounted")
        }
        
        var mountCommand = "diskutil mount /dev/\(drive.identifier)"
        var needsSudo = false
        
        // EFI partitions need sudo
        if drive.isEFI {
            needsSudo = true
            
            print("🔐 Attempting to mount EFI partition...")
            
            // First, check if /Volumes/EFI exists and unmount it if it does
            let checkMount = runCommand("mount | grep /Volumes/EFI")
            if checkMount.success {
                print("⚠️ /Volumes/EFI is already mounted, unmounting...")
                runCommand("sudo diskutil unmount /Volumes/EFI 2>/dev/null", needsSudo: true)
                runCommand("sudo umount /Volumes/EFI 2>/dev/null", needsSudo: true)
            }
            
            // Try standard diskutil mount first
            print("1️⃣ Trying standard diskutil mount...")
            let result1 = runCommand("diskutil mount /dev/\(drive.identifier)", needsSudo: true)
            
            if result1.success {
                // Verify it's actually mounted
                let verify = runCommand("mount | grep '/dev/\(drive.identifier)'")
                if !verify.output.isEmpty {
                    return (true, "✅ EFI partition mounted successfully")
                }
            }
            
            // Clean up any existing EFI mount point
            print("2️⃣ Cleaning up and trying manual mount...")
            runCommand("sudo diskutil unmount /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo umount /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo rm -rf /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo mkdir -p /Volumes/EFI 2>/dev/null", needsSudo: true)
            
            // Try manual mount to /Volumes/EFI
            print("3️⃣ Mounting to /Volumes/EFI...")
            let result2 = runCommand("sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result2.success {
                // Verify mount
                let verify = runCommand("mount | grep '/dev/\(drive.identifier)'")
                if !verify.output.isEmpty {
                    return (true, "✅ EFI mounted at /Volumes/EFI")
                }
            }
            
            // Try with read-write permissions
            print("4️⃣ Trying with read-write permissions...")
            let result3 = runCommand("sudo mount -t msdos -o noowners,rw /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result3.success {
                return (true, "✅ EFI mounted with read-write access at /Volumes/EFI")
            }
            
            // Try different mount options
            print("5️⃣ Trying different mount options...")
            let result4 = runCommand("sudo mount -t msdos -o rw,noowners,noatime /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result4.success {
                return (true, "✅ EFI mounted successfully")
            }
            
            // Last resort: try mount_msdos directly
            print("6️⃣ Trying mount_msdos directly...")
            let result5 = runCommand("sudo /System/Library/Filesystems/msdos.fs/Contents/Resources/mount_msdos /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result5.success {
                return (true, "✅ EFI mounted using mount_msdos")
            }
            
            return (false, "❌ Failed to mount EFI. Error: \(result5.error.isEmpty ? result5.output : result5.error)")
        }
        
        // Regular mount for non-EFI
        let result = runCommand(mountCommand, needsSudo: needsSudo)
        
        if result.success {
            return (true, "✅ \(drive.name) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(drive.name): \(result.error)")
        }
    }
    
    // Enhanced unmount function
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        if !drive.isMounted {
            return (true, "✅ \(drive.name) is already unmounted")
        }
        
        if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
            return (false, "⚠️ Cannot unmount system volume")
        }
        
        // For EFI partitions, try multiple methods
        if drive.isEFI {
            print("🔐 Unmounting EFI partition...")
            
            // Method 1: Standard diskutil unmount
            let result1 = runCommand("diskutil unmount /dev/\(drive.identifier)")
            if result1.success {
                return (true, "✅ \(drive.name) unmounted successfully")
            }
            
            // Method 2: Force unmount
            let result2 = runCommand("diskutil unmount force /dev/\(drive.identifier)")
            if result2.success {
                return (true, "✅ \(drive.name) force unmounted")
            }
            
            // Method 3: umount command
            let result3 = runCommand("umount /dev/\(drive.identifier) 2>/dev/null")
            if result3.success {
                return (true, "✅ \(drive.name) unmounted using umount")
            }
            
            // Method 4: sudo umount
            let result4 = runCommand("sudo umount /dev/\(drive.identifier) 2>/dev/null", needsSudo: true)
            if result4.success {
                return (true, "✅ \(drive.name) unmounted using sudo")
            }
            
            return (false, "❌ Failed to unmount \(drive.name)")
        }
        
        // Regular unmount for non-EFI
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
            return (false, "❌ Failed to unmount \(drive.name): \(result.error)")
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
        
        return mountDrive(drive)
    }
    
    func findEFIPartitions() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Partition Search Results:")
        messages.append("=================================")
        
        // Check all potential EFI partitions
        let potentialEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1",
                           "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                           "disk12s1", "disk13s1"]
        
        var foundEFIs: [(String, String, Bool, String)] = []
        
        for partitionId in potentialEFIs {
            let drive = getDriveInfo(deviceId: partitionId)
            if drive.isEFI {
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isMounted = !mountCheck.output.isEmpty
                foundEFIs.append((partitionId, drive.name, isMounted, drive.size))
            }
        }
        
        if foundEFIs.isEmpty {
            messages.append("No EFI partitions found")
        } else {
            messages.append("Found \(foundEFIs.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted, size) in foundEFIs {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id): \(name) - \(size) - \(status)")
            }
            
            messages.append("")
            messages.append("💡 Recommendations:")
            messages.append("1. Try mounting disk1s1, disk2s1, or disk3s1 (named 'EFI')")
            messages.append("2. These are likely your macOS drive EFI partitions")
            messages.append("3. disk0s1 is likely your Windows drive EFI (104.9 MB)")
            messages.append("4. disk11s1 might be your macOS installer EFI")
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
                efiFound.append((partitionId, drive.name, isMounted, drive.size))
            }
        }
        
        if efiFound.isEmpty {
            messages.append("❌ No EFI partitions found")
        } else {
            messages.append("✅ Found \(efiFound.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted, size) in efiFound {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id): \(name) - \(size) - \(status)")
            }
            
            // Your specific EFI partitions based on debug output
            messages.append("\n🔍 Your EFI Partitions Summary:")
            messages.append("• disk0s1: Windows drive EFI (104.9 MB)")
            messages.append("• disk1s1: macOS drive EFI (209.7 MB)")
            messages.append("• disk2s1: macOS drive EFI (209.7 MB)")
            messages.append("• disk3s1: macOS drive EFI (209.7 MB)")
            messages.append("• disk11s1: macOS Installer EFI (209.7 MB)")
        }
        
        // Check /Volumes/EFI directory
        messages.append("\n📁 /Volumes/EFI Directory Check:")
        let volumeCheck = runCommand("ls -la /Volumes/ 2>/dev/null | grep -i EFI")
        if volumeCheck.output.isEmpty {
            messages.append("❌ /Volumes/EFI directory does not exist")
        } else {
            messages.append("✅ /Volumes/EFI directory exists")
            
            // Check if it's actually a mount point
            let mountCheck = runCommand("mount | grep /Volumes/EFI")
            if mountCheck.output.isEmpty {
                messages.append("  ⚠️ Directory exists but is not mounted")
            } else {
                messages.append("  ✅ Directory is currently mounted")
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
                messages.append("2. Try mounting in this order:")
                messages.append("   • disk1s1 (SSD 860 macOS drive)")
                messages.append("   • disk2s1 (macOS drive)")
                messages.append("   • disk3s1 (pos drive)")
                messages.append("3. You'll need to enter your password when prompted")
            } else {
                messages.append("1. All EFI partitions are mounted")
                messages.append("2. You can access them through their mount points")
                messages.append("3. Always unmount EFI before shutting down")
            }
        }
        
        messages.append("\n✅ EFI Check Complete")
        return messages.joined(separator: "\n")
    }
    
    func debugMountIssues() -> String {
        var messages: [String] = []
        
        messages.append("🔍 Debug Information:")
        messages.append("=====================")
        
        let drives = getAllDrives()
        
        let efiCount = drives.filter { $0.isEFI }.count
        let mountedCount = drives.filter { $0.isMounted }.count
        
        messages.append("Total drives: \(drives.count)")
        messages.append("Mounted: \(mountedCount)")
        messages.append("Unmounted: \(drives.count - mountedCount)")
        messages.append("EFI partitions: \(efiCount)")
        
        if efiCount > 0 {
            messages.append("\n🔐 EFI Partitions:")
            for drive in drives.filter({ $0.isEFI }) {
                let status = drive.isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(drive.identifier): \(drive.name) - \(drive.size) - \(drive.type) - \(status)")
            }
        }
        
        messages.append("\n📊 All Drives:")
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
    let mountPoint: String
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
                    
                    Text("Quick Mount:")
                    
                    Button("Mount disk1s1 (SSD 860)") {
                        quickMountEFI("disk1s1")
                    }
                    
                    Button("Mount disk2s1 (macOS)") {
                        quickMountEFI("disk2s1")
                    }
                    
                    Button("Mount disk3s1 (pos drive)") {
                        quickMountEFI("disk3s1")
                    }
                    
                    Button("Mount disk0s1 (Windows)") {
                        quickMountEFI("disk0s1")
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
                            Text("EFI Partitions (\(efiDrives.count))")
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
                            Text("Other Drives (\(regularDrives.count))")
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
                        // Windows EFI
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundColor(.blue)
                            Text("Windows Drive EFI")
                        }
                        .font(.caption)
                        
                        EFIPartitionRow(id: "disk0s1", size: "104.9 MB", type: "Windows", color: .blue)
                        
                        Divider()
                        
                        // macOS EFI Partitions
                        HStack {
                            Image(systemName: "macbook")
                                .foregroundColor(.green)
                            Text("macOS Drive EFI Partitions")
                        }
                        .font(.caption)
                        
                        EFIPartitionRow(id: "disk1s1", size: "209.7 MB", type: "SSD 860", color: .green)
                        EFIPartitionRow(id: "disk2s1", size: "209.7 MB", type: "macOS", color: .green)
                        EFIPartitionRow(id: "disk3s1", size: "209.7 MB", type: "pos drive", color: .green)
                        EFIPartitionRow(id: "disk11s1", size: "209.7 MB", type: "Installer", color: .green)
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
                        Text("disk2s1 (macOS)").tag("disk2s1")
                        Text("disk3s1 (pos drive)").tag("disk3s1")
                        Text("disk0s1 (Windows)").tag("disk0s1")
                        Text("disk11s1 (Installer)").tag("disk11s1")
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
                        
                        CodeBlock(text: "# If above fails, try:")
                        CodeBlock(text: "sudo /System/Library/Filesystems/msdos.fs/Contents/Resources/mount_msdos /dev/disk1s1 /Volumes/EFI")
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func EFIPartitionRow(id: String, size: String, type: String, color: Color) -> some View {
        HStack {
            Text("• \(id)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .leading)
            
            Text(size)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70)
            
            Text(type)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
            
            Spacer()
            
            // Show current status if available
            if let drive = driveManager.allDrives.first(where: { $0.identifier == id }) {
                Text(drive.isMounted ? "✅ Mounted" : "❌ Unmounted")
                    .font(.caption2)
                    .foregroundColor(drive.isMounted ? .green : .secondary)
            }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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