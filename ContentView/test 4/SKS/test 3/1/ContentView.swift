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
            with prompt "SystemMaintenance needs administrator access to mount drives" \
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
    
    // Get ALL drives (mounted and unmounted)
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get ALL mounted volumes from df -h
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        // Parse df output for mounted drives
        for line in dfLines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Skip header and empty lines
            if components.count < 6 || components[0] == "Filesystem" {
                continue
            }
            
            let devicePath = components[0]
            let mountPoint = components[5]
            
            // Only process /dev/disk devices
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                let size = components[1]
                
                // Get detailed info
                let drive = getDriveInfo(deviceId: deviceId)
                
                let volumeName = (mountPoint as NSString).lastPathComponent
                var finalName = drive.name
                
                // Use volume name from mount point if available and better
                if volumeName != "." && volumeName != "/" && !volumeName.contains("System/Volumes") {
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
                print("📌 Found mounted: \(updatedDrive.name) (\(deviceId)) at \(mountPoint)")
            }
        }
        
        // Get ALL partitions from diskutil list
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        var currentDisk = ""
        
        for line in lines {
            // Check for disk identifier line
            if line.contains("/dev/disk") {
                let components = line.components(separatedBy: " ")
                if let diskId = components.first(where: { $0.contains("disk") })?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = diskId
                    print("📋 Processing disk: \(currentDisk)")
                }
            }
            
            // Look for partition lines
            if line.contains("disk") && line.contains("s") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                // Look for partition identifier pattern (diskXsY)
                for component in components {
                    if component.hasPrefix("disk") && component.contains("s") {
                        let partitionId = component
                        
                        // Skip if already in mounted list
                        if !drives.contains(where: { $0.identifier == partitionId }) {
                            
                            // Get drive info
                            let drive = getDriveInfoWithName(deviceId: partitionId, fromDiskList: lines)
                            
                            // Check if it's actually mounted
                            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                            let isActuallyMounted = !mountCheck.output.isEmpty
                            
                            if !isActuallyMounted {
                                // Skip system partitions
                                if !drive.name.contains("Recovery") && 
                                   !drive.name.contains("VM") && 
                                   !drive.name.contains("Preboot") && 
                                   !drive.name.contains("Update") &&
                                   !drive.name.contains("Apple_APFS_ISC") &&
                                   drive.size != "0 B" &&
                                   !partitionId.contains("s6") &&
                                   !partitionId.contains("s5") {
                                    
                                    let unmountedDrive = DriveInfo(
                                        name: drive.name,
                                        identifier: partitionId,
                                        size: drive.size,
                                        type: drive.type,
                                        mountPoint: "",
                                        isInternal: drive.isInternal,
                                        isEFI: drive.isEFI,
                                        partitions: drive.partitions,
                                        isMounted: false,
                                        isSelectedForMount: false,
                                        isSelectedForUnmount: false
                                    )
                                    
                                    drives.append(unmountedDrive)
                                    print("📌 Found unmounted: \(drive.name) (\(partitionId)) Size: \(drive.size)")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Sort: mounted first, then unmounted, then by identifier
        drives.sort {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        return getDriveInfoWithName(deviceId: deviceId, fromDiskList: [])
    }
    
    private func getDriveInfoWithName(deviceId: String, fromDiskList: [String]) -> DriveInfo {
        print("📋 Getting info for device: \(deviceId)")
        
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null")
        
        var name = "Disk \(deviceId)"
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = true
        var isMounted = false
        var isEFI = false
        var fileSystem = "Unknown"
        
        // Parse diskutil info output
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            // Parse key-value pairs
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
                        
                    case "File System Personality":
                        fileSystem = value
                        
                    case "Type (Bundle)":
                        if value.contains("EFI") || value.contains("msdos") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name.isEmpty {
                                name = "EFI System Partition"
                            }
                        } else if value.contains("ntfs") || value.contains("NTFS") {
                            type = "NTFS"
                        } else if value.contains("hfs") || value.contains("HFS") {
                            type = "HFS+"
                        } else if value.contains("apfs") || value.contains("APFS") {
                            type = "APFS"
                        } else if value.contains("fat") || value.contains("FAT") {
                            type = "FAT32"
                        }
                        
                    case "Protocol":
                        if !value.isEmpty && value != "(null)" {
                            type = value
                            if value.contains("USB") {
                                isInternal = false
                            }
                        }
                        
                    case "Internal":
                        isInternal = value.contains("Yes")
                        
                    case "Removable Media":
                        if value.contains("Yes") || value.contains("Removable") {
                            isInternal = false
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
        
        // If we still don't have a good name, try to extract it from diskutil list
        if (name == "Disk \(deviceId)" || name.isEmpty) && !fromDiskList.isEmpty {
            for line in fromDiskList {
                if line.contains(deviceId) {
                    let pattern = "\(deviceId)\\s+(.+?)\\s+"
                    if let range = line.range(of: pattern, options: .regularExpression) {
                        let afterId = line[range.upperBound...]
                        let nameComponents = afterId.components(separatedBy: .whitespaces)
                        if let possibleName = nameComponents.first, !possibleName.isEmpty {
                            name = possibleName
                            break
                        }
                    }
                }
            }
        }
        
        // Determine file system type if still unknown
        if type == "Unknown" {
            if fileSystem.contains("NTFS") {
                type = "NTFS"
            } else if fileSystem.contains("APFS") {
                type = "APFS"
            } else if fileSystem.contains("HFS") {
                type = "HFS+"
            } else if fileSystem.contains("FAT32") || fileSystem.contains("MS-DOS") {
                type = "FAT32"
            } else if isEFI {
                type = "EFI"
            } else if deviceId.contains("EFI") {
                type = "EFI"
                isEFI = true
                name = "EFI System Partition"
            } else {
                type = "Unknown"
            }
        }
        
        // Determine if internal based on disk number
        let diskNum = deviceId.replacingOccurrences(of: "disk", with: "").replacingOccurrences(of: "s.*", with: "", options: .regularExpression)
        if let num = Int(diskNum) {
            isInternal = num <= 4
        }
        
        // If size is still unknown, try to get it from df or lsblk
        if size == "Unknown" {
            let sizeCheck = runCommand("df -h /dev/\(deviceId) 2>/dev/null | tail -1 | awk '{print $2}'")
            if !sizeCheck.output.isEmpty && sizeCheck.output != "0B" {
                size = sizeCheck.output
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
    
    // Mount selected drives - IMPROVED VERSION
    func mountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏫ Mounting selected drives: \(drives.count)")
        
        guard !drives.isEmpty else {
            return (false, "❌ No drives selected for mounting")
        }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForMount && !drive.isMounted {
            print("🔧 Attempting to mount drive: \(drive.name) (\(drive.identifier))")
            
            var mountCommand = ""
            var needsSudo = false
            
            // Determine the appropriate mount command based on drive type
            if drive.isEFI {
                mountCommand = "diskutil mount /dev/\(drive.identifier)"
                needsSudo = true
                messages.append("🔧 \(drive.name): EFI partition detected, using sudo")
            } else if drive.type == "NTFS" {
                mountCommand = "diskutil mount /dev/\(drive.identifier)"
                needsSudo = true
                messages.append("🔧 \(drive.name): NTFS detected, attempting mount")
            } else {
                mountCommand = "diskutil mount /dev/\(drive.identifier)"
                needsSudo = false
            }
            
            // First, check if drive exists and can be mounted
            let checkCommand = "diskutil info /dev/\(drive.identifier)"
            let checkResult = runCommand(checkCommand)
            
            if !checkResult.success {
                messages.append("❌ \(drive.name): Cannot access drive - \(checkResult.error)")
                failedCount += 1
                continue
            }
            
            // Try to mount
            let result = runCommand(mountCommand, needsSudo: needsSudo)
            
            if result.success {
                // Verify mount was successful
                let verifyCommand = "diskutil info /dev/\(drive.identifier) | grep 'Mount Point'"
                let verifyResult = runCommand(verifyCommand)
                
                if verifyResult.output.contains("Not mounted") || verifyResult.output.contains("Not applicable") {
                    // Mount reported success but drive not actually mounted
                    messages.append("⚠️ \(drive.name): Mount reported success but drive not showing as mounted")
                    
                    // Try alternative method
                    messages.append("🔄 \(drive.name): Trying alternative mount method...")
                    let altResult = runCommand("diskutil mountDisk /dev/\(drive.identifier)", needsSudo: true)
                    
                    if altResult.success {
                        successCount += 1
                        messages.append("✅ \(drive.name): Mounted using disk method")
                    } else {
                        failedCount += 1
                        messages.append("❌ \(drive.name): Alternative mount also failed")
                    }
                } else {
                    successCount += 1
                    // Extract actual mount point
                    let mountPointCmd = "diskutil info /dev/\(drive.identifier) | awk -F': ' '/Mount Point/ {print $2}' | head -1"
                    let mountPointResult = runCommand(mountPointCmd)
                    let mountPoint = mountPointResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !mountPoint.isEmpty && mountPoint != "Not applicable" {
                        messages.append("✅ \(drive.name): Mounted successfully at \(mountPoint)")
                    } else {
                        messages.append("✅ \(drive.name): Mounted successfully")
                    }
                }
            } else {
                failedCount += 1
                
                // Try different mount strategies
                if drive.type == "NTFS" {
                    messages.append("🔄 \(drive.name): NTFS standard mount failed, trying read-only...")
                    let roResult = runCommand("diskutil mount readOnly /dev/\(drive.identifier)", needsSudo: true)
                    
                    if roResult.success {
                        successCount += 1
                        messages.append("✅ \(drive.name): Mounted read-only (NTFS)")
                        messages.append("💡 Note: NTFS write support requires additional software")
                    } else {
                        messages.append("❌ \(drive.name): Failed to mount NTFS")
                        messages.append("💡 Tip: Install NTFS-3G or Paragon NTFS for write support")
                    }
                } else {
                    // Try alternative methods
                    messages.append("🔄 \(drive.name): Trying alternative mount methods...")
                    
                    // Method 1: mountDisk
                    let alt1Result = runCommand("diskutil mountDisk /dev/\(drive.identifier)", needsSudo: true)
                    if alt1Result.success {
                        successCount += 1
                        messages.append("✅ \(drive.name): Mounted using mountDisk")
                    } else {
                        // Method 2: mount with force
                        let alt2Result = runCommand("diskutil mount force /dev/\(drive.identifier)", needsSudo: true)
                        if alt2Result.success {
                            successCount += 1
                            messages.append("✅ \(drive.name): Force mounted")
                        } else {
                            messages.append("❌ \(drive.name): All mount methods failed")
                            messages.append("📋 Error details: \(result.error)")
                        }
                    }
                }
            }
            
            // Small delay between operations
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Successfully mounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Partially successful - Mounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "❌ Failed to mount any drives\n\n\(message)")
        } else {
            return (true, "ℹ️ No drives were mounted (none selected or all already mounted)")
        }
    }
    
    // Unmount selected drives
    func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            print("🔧 Unmounting drive: \(drive.name) (\(drive.identifier))")
            
            // Skip system volumes
            if drive.mountPoint == "/" || 
               drive.mountPoint.contains("/System/Volumes/") ||
               drive.mountPoint.contains("home") ||
               drive.mountPoint.contains("private/var") {
                print("⚠️ Skipping system volume: \(drive.name)")
                messages.append("⚠️ \(drive.name): Skipped (system volume)")
                continue
            }
            
            let unmountCommand = "diskutil unmount /dev/\(drive.identifier)"
            let result = runCommand(unmountCommand)
            
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted successfully")
            } else {
                failedCount += 1
                
                // Try force unmount
                print("⚠️ Standard unmount failed, trying force...")
                let forceResult = runCommand("diskutil unmount force /dev/\(drive.identifier)")
                
                if forceResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Force unmounted")
                } else {
                    messages.append("❌ \(drive.name): Failed - \(result.error)")
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Successfully unmounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "❌ Failed to unmount all selected drives\n\n\(message)")
        } else {
            return (true, "ℹ️ No drives selected for unmount")
        }
    }
    
    // Mount all unmounted non-system drives
    func mountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏫ Mounting all unmounted drives")
        
        // Get list of all unmounted partitions
        let listResult = runCommand("diskutil list | grep -E 'disk[0-9]+s[0-9]+' | awk '{print $1}'")
        let allPartitions = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for partitionId in allPartitions {
            // Check if already mounted
            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
            if !mountCheck.output.isEmpty {
                continue // Already mounted
            }
            
            // Get drive info to decide mounting method
            let drive = getDriveInfo(deviceId: partitionId)
            
            // Skip system partitions
            if drive.name.contains("Recovery") || 
               drive.name.contains("VM") || 
               drive.name.contains("Preboot") ||
               drive.name.contains("Update") ||
               drive.isEFI {
                continue
            }
            
            print("🔧 Mounting: \(drive.name) (\(partitionId))")
            
            var mountCommand = "diskutil mount /dev/\(partitionId)"
            let needsSudo = drive.type == "EFI" || drive.type == "FAT32" || drive.type == "NTFS"
            
            let result = runCommand(mountCommand, needsSudo: needsSudo)
            
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): Mounted")
            } else {
                failedCount += 1
                messages.append("❌ \(drive.name): Failed")
            }
            
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Successfully mounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Mounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && allPartitions.isEmpty {
            return (true, "ℹ️ No unmounted drives found")
        } else {
            return (false, "❌ Failed to mount drives\n\n\(message)")
        }
    }
    
    // Unmount all non-system drives
    func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all non-system drives")
        
        // Get all mounted non-system volumes
        let mountResult = runCommand("mount | grep '/Volumes/' | grep -v '/System/Volumes/' | awk '{print $1}' | sed 's|/dev/||'")
        let mountedDrives = mountResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in mountedDrives {
            // Skip if it looks like a system disk
            if diskId.starts(with: "disk0") || diskId.starts(with: "disk1") || 
               diskId.starts(with: "disk2") || diskId.starts(with: "disk3") {
                // Check if it's actually a user volume
                let drive = getDriveInfo(deviceId: diskId)
                if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
                    continue
                }
            }
            
            print("🔧 Unmounting: \(diskId)")
            let result = runCommand("diskutil unmount /dev/\(diskId)")
            
            if result.success {
                successCount += 1
                messages.append("✅ \(diskId): Unmounted")
            } else {
                failedCount += 1
                messages.append("❌ \(diskId): Failed")
            }
            
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Successfully unmounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && mountedDrives.isEmpty {
            return (true, "ℹ️ No non-system drives mounted")
        } else {
            return (false, "❌ Failed to unmount drives\n\n\(message)")
        }
    }
    
    // Check if a drive can be mounted (test without actually mounting)
    func canMountDrive(_ drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return false // Already mounted
        }
        
        // EFI partitions can usually be mounted
        if drive.isEFI {
            return true
        }
        
        // Skip system partitions
        if drive.name.contains("Recovery") || 
           drive.name.contains("VM") || 
           drive.name.contains("Preboot") ||
           drive.name.contains("Update") {
            return false
        }
        
        // Check if it has a valid size
        if drive.size == "0 B" || drive.size.contains("0.0") {
            return false
        }
        
        return true
    }
    
    func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    func checkFullDiskAccess() -> Bool {
        let testResult = runCommand("ls /Volumes/ 2>&1")
        return !testResult.error.contains("Operation not permitted")
    }
    
    // NEW: Test mount functionality
    func testMountFunctionality() -> (success: Bool, message: String) {
        print("🧪 Testing mount functionality...")
        
        // First, get a list of unmounted drives
        let listResult = runCommand("diskutil list | grep -E 'disk[0-9]+s[0-9]+' | grep -v 'mounted' | head -5")
        let testDrives = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var messages: [String] = []
        var foundTestDrive = false
        
        for driveId in testDrives {
            // Skip system partitions
            if driveId.contains("s1") || driveId.contains("s2") || driveId.contains("s3") {
                continue
            }
            
            // Get drive info
            let infoResult = runCommand("diskutil info /dev/\(driveId) 2>/dev/null")
            if infoResult.output.contains("Mount Point:") && !infoResult.output.contains("Not mounted") {
                continue // Already mounted
            }
            
            foundTestDrive = true
            messages.append("🧪 Testing with drive: \(driveId)")
            
            // Try to mount
            let mountResult = runCommand("diskutil mount /dev/\(driveId)")
            
            if mountResult.success {
                messages.append("✅ SUCCESS: Drive \(driveId) mounted successfully")
                
                // Unmount it
                let unmountResult = runCommand("diskutil unmount /dev/\(driveId)")
                if unmountResult.success {
                    messages.append("✅ Drive \(driveId) unmounted successfully")
                } else {
                    messages.append("⚠️ Could not unmount test drive")
                }
                
                return (true, messages.joined(separator: "\n"))
            } else {
                messages.append("❌ FAILED: Could not mount \(driveId)")
                messages.append("📋 Error: \(mountResult.error)")
            }
        }
        
        if !foundTestDrive {
            messages.append("ℹ️ No suitable test drives found")
        }
        
        return (false, messages.joined(separator: "\n"))
    }
    
    // NEW: Debug function to check permissions and setup
    func debugMountIssues() -> String {
        var messages: [String] = []
        
        messages.append("🔍 Debugging Mount Issues:")
        messages.append("==========================")
        
        // Check diskutil availability
        let diskutilCheck = runCommand("which diskutil")
        messages.append("diskutil path: \(diskutilCheck.output)")
        
        // Check permissions
        let lsCheck = runCommand("ls /Volumes/ 2>&1")
        if lsCheck.error.contains("Operation not permitted") {
            messages.append("❌ Full Disk Access permission issue detected")
        } else {
            messages.append("✅ Full Disk Access appears OK")
        }
        
        // Check sudo capabilities
        let sudoCheck = runCommand("sudo -n true 2>&1")
        if sudoCheck.success {
            messages.append("✅ Sudo available without password prompt")
        } else {
            messages.append("⚠️ Sudo requires password")
        }
        
        // Check current mounts
        let mountCheck = runCommand("mount | grep '/Volumes/' | wc -l")
        messages.append("Currently mounted volumes: \(mountCheck.output)")
        
        // List available unmounted drives
        let unmountedCheck = runCommand("diskutil list | grep -E 'disk[0-9]+s[0-9]+' | grep -v 'mounted' | wc -l")
        messages.append("Unmounted partitions available: \(unmountedCheck.output)")
        
        // Check disk arbitration daemon
        let diskArbCheck = runCommand("ps aux | grep diskarbitrationd | grep -v grep")
        if diskArbCheck.output.isEmpty {
            messages.append("⚠️ diskarbitrationd not running")
        } else {
            messages.append("✅ diskarbitrationd is running")
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
    @Published var mountSelection: Set<String> = []
    @Published var unmountSelection: Set<String> = []
    @Published var lastOperationMessage: String = ""
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        print("🔄 Starting drive refresh...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            
            DispatchQueue.main.async {
                // Preserve selection state by creating new DriveInfo objects with updated selection
                var updatedDrives: [DriveInfo] = []
                for drive in drives {
                    let updatedDrive = DriveInfo(
                        name: drive.name,
                        identifier: drive.identifier,
                        size: drive.size,
                        type: drive.type,
                        mountPoint: drive.mountPoint,
                        isInternal: drive.isInternal,
                        isEFI: drive.isEFI,
                        partitions: drive.partitions,
                        isMounted: drive.isMounted,
                        isSelectedForMount: self.mountSelection.contains(drive.identifier),
                        isSelectedForUnmount: self.unmountSelection.contains(drive.identifier)
                    )
                    updatedDrives.append(updatedDrive)
                }
                self.allDrives = updatedDrives
                self.isLoading = false
                
                print("🔄 Drive refresh complete. Found \(self.allDrives.count) drives:")
                for drive in self.allDrives {
                    let selection = drive.isSelectedForMount ? "✅ Mount" : (drive.isSelectedForUnmount ? "✅ Unmount" : "⬜ None")
                    print("   - \(drive.name) (\(drive.identifier)): \(drive.isMounted ? "📌 Mounted" : "📦 Unmounted") - Size: \(drive.size) - \(selection)")
                }
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            
            // Can only select unmounted drives for mount
            if currentDrive.isMounted {
                print("⚠️ Drive is already mounted, cannot select for mount")
                lastOperationMessage = "⚠️ \(drive.name) is already mounted"
                return
            }
            
            // Check if drive can be mounted
            if !shellHelper.canMountDrive(currentDrive) {
                print("⚠️ Drive cannot be mounted: \(drive.identifier)")
                lastOperationMessage = "⚠️ \(drive.name) cannot be mounted (system or invalid)"
                return
            }
            
            let newIsSelectedForMount = !currentDrive.isSelectedForMount
            var newIsSelectedForUnmount = currentDrive.isSelectedForUnmount
            
            if newIsSelectedForMount && currentDrive.isSelectedForUnmount {
                newIsSelectedForUnmount = false
                unmountSelection.remove(drive.identifier)
                print("🔄 Removed from unmount selection")
            }
            
            if newIsSelectedForMount {
                mountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to mount selection")
                lastOperationMessage = "✅ Selected \(drive.name) for mounting"
            } else {
                mountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from mount selection")
                lastOperationMessage = "❌ Deselected \(drive.name) for mounting"
            }
            
            // Update the drive in the array
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
            objectWillChange.send()
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        print("🔘 Toggle unmount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            
            // Can only select mounted drives for unmount
            if !currentDrive.isMounted {
                print("⚠️ Drive is not mounted, cannot select for unmount")
                lastOperationMessage = "⚠️ \(drive.name) is not mounted"
                return
            }
            
            // Cannot unmount system volumes
            if currentDrive.mountPoint.contains("/System/Volumes/") || 
               currentDrive.mountPoint == "/" ||
               currentDrive.mountPoint.contains("home") ||
               currentDrive.mountPoint.contains("private/var") ||
               currentDrive.mountPoint.contains("Library/Developer") {
                print("⚠️ Cannot unmount system volume: \(currentDrive.mountPoint)")
                lastOperationMessage = "⚠️ Cannot unmount system volume: \(drive.name)"
                return
            }
            
            let newIsSelectedForUnmount = !currentDrive.isSelectedForUnmount
            var newIsSelectedForMount = currentDrive.isSelectedForMount
            
            if newIsSelectedForUnmount && currentDrive.isSelectedForMount {
                newIsSelectedForMount = false
                mountSelection.remove(drive.identifier)
            }
            
            if newIsSelectedForUnmount {
                unmountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to unmount selection")
                lastOperationMessage = "✅ Selected \(drive.name) for unmounting"
            } else {
                unmountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from unmount selection")
                lastOperationMessage = "❌ Deselected \(drive.name) for unmounting"
            }
            
            // Update the drive in the array
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
            objectWillChange.send()
        }
    }
    
    func selectAllForUnmount() {
        print("🔘 Select all for unmount")
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        for drive in allDrives {
            // Only select user volumes for unmount (not system volumes)
            let shouldSelectForUnmount = drive.isMounted && 
                                         !drive.mountPoint.contains("/System/Volumes/") &&
                                         drive.mountPoint != "/" &&
                                         !drive.mountPoint.contains("home") &&
                                         !drive.mountPoint.contains("private/var") &&
                                         !drive.mountPoint.contains("Library/Developer")
            
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: shouldSelectForUnmount
            )
            updatedDrives.append(updatedDrive)
            
            if shouldSelectForUnmount {
                unmountSelection.insert(drive.identifier)
            }
        }
        allDrives = updatedDrives
        lastOperationMessage = "✅ Selected all mountable drives for unmount"
        objectWillChange.send()
    }
    
    func clearAllSelections() {
        print("🔘 Clear all selections")
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        for drive in allDrives {
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: false
            )
            updatedDrives.append(updatedDrive)
        }
        allDrives = updatedDrives
        lastOperationMessage = "✅ Cleared all selections"
        objectWillChange.send()
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Mounting selected drives")
        let drivesToMount = allDrives.filter { $0.isSelectedForMount }
        print("📦 Drives to mount: \(drivesToMount.count)")
        
        if drivesToMount.isEmpty {
            return (false, "❌ No drives selected for mounting")
        }
        
        for drive in drivesToMount {
            print("   - \(drive.name) (\(drive.identifier)) mounted=\(drive.isMounted)")
        }
        
        let result = shellHelper.mountSelectedDrives(drives: drivesToMount)
        
        // Clear selections
        clearAllSelections()
        
        // Force refresh with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔄 Force refreshing drives after mount operation")
            self.refreshDrives()
            
            // Additional debug info
            print("🔍 Current drive states after refresh:")
            for drive in self.allDrives {
                print("   - \(drive.name): mounted=\(drive.isMounted), mountPoint=\(drive.mountPoint)")
            }
        }
        
        return (result.success, result.message)
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Unmounting selected drives")
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount }
        print("📦 Drives to unmount: \(drivesToUnmount.count)")
        
        for drive in drivesToUnmount {
            print("   - \(drive.name) (\(drive.identifier))")
        }
        
        let result = shellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        
        // Clear selections
        clearAllSelections()
        
        // Force refresh with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        
        return (result.success, result.message)
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Mount all external drives")
        let result = shellHelper.mountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
        }
        
        return (result.success, result.message)
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Unmount all external drives")
        let result = shellHelper.unmountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        
        return (result.success, result.message)
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
    
    // NEW: Test mount functionality
    func testMountFunctionality() -> (success: Bool, message: String) {
        return shellHelper.testMountFunctionality()
    }
    
    // NEW: Debug function
    func debugMountIssues() -> String {
        return shellHelper.debugMountIssues()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var selectedDrive: DriveInfo?
    @StateObject private var driveManager = DriveManager.shared
    @State private var hasFullDiskAccess = false
    @State private var debugOutput = ""
    
    let shellHelper = ShellHelper.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    DriveManagementView
                        .tabItem {
                            Label("Drives", systemImage: "externaldrive")
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
            Button("OK") { 
                // Refresh after alert is dismissed
                if alertTitle == "Success" || alertTitle == "Error" || alertTitle == "Debug Information" {
                    driveManager.refreshDrives()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive, driveManager: driveManager)
        }
        .onAppear {
            checkPermissions()
            driveManager.refreshDrives()
        }
    }
    
    // MARK: - Header View (FIXED - using unmountSelected not unmountCount)
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Manual Drive Control")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let mountSelected = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                    let unmountSelected = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                    if mountSelected > 0 {
                        Text("\(mountSelected) to mount")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if unmountSelected > 0 {
                        Text("\(unmountSelected) to unmount")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
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
    
    // MARK: - Drive Management View
    private var DriveManagementView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Control Panel
                ControlPanelView
                
                // Drives List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    DrivesListView
                }
                
                // Quick Actions
                QuickActionsGrid
            }
            .padding()
        }
    }
    
    private var ControlPanelView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Drive Controls")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Debug Button
                Button("Debug") {
                    showDebugView()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                // Clear Selection Button
                Button("Clear All") {
                    driveManager.clearAllSelections()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(driveManager.mountSelection.isEmpty && driveManager.unmountSelection.isEmpty)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Mount Button
                Button(action: {
                    mountSelected()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Mount Selected")
                        if !driveManager.mountSelection.isEmpty {
                            Text("(\(driveManager.mountSelection.count))")
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(driveManager.mountSelection.isEmpty)
                
                // Unmount Button
                Button(action: {
                    unmountSelected()
                }) {
                    HStack {
                        Image(systemName: "eject.fill")
                        Text("Unmount Selected")
                        if !driveManager.unmountSelection.isEmpty {
                            Text("(\(driveManager.unmountSelection.count))")
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.unmountSelection.isEmpty)
                
                Spacer()
                
                // Test Mount Button
                Button("Test Mount") {
                    testMountFunction()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                // Only "Select All to Unmount" button
                Button("Select All to Unmount") {
                    driveManager.selectAllForUnmount()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(driveManager.allDrives.filter { 
                    $0.isMounted && 
                    !$0.mountPoint.contains("/System/Volumes/") &&
                    $0.mountPoint != "/" &&
                    !$0.mountPoint.contains("home") &&
                    !$0.mountPoint.contains("private/var") &&
                    !$0.mountPoint.contains("Library/Developer")
                }.isEmpty)
            }
            
            // Status Message
            if !driveManager.lastOperationMessage.isEmpty {
                Text(driveManager.lastOperationMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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
            
            Text("Connect a drive or check permissions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var DrivesListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Drives")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let mountCount = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                let unmountCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                if mountCount > 0 {
                    Text("\(mountCount) to mount")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if unmountCount > 0 {
                    Text("\(unmountCount) to unmount")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // List
            ForEach(driveManager.allDrives) { drive in
                DriveRow(drive: drive)
                    .onTapGesture {
                        selectedDrive = drive
                    }
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveRow(drive: DriveInfo) -> some View {
        HStack(spacing: 8) {
            // Mount/Unmount Selection
            VStack(spacing: 2) {
                // Mount checkbox (only for unmounted drives)
                if !drive.isMounted && shellHelper.canMountDrive(drive) {
                    Button(action: {
                        driveManager.toggleMountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForMount ? "play.circle.fill" : "play.circle")
                            .foregroundColor(drive.isSelectedForMount ? .green : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to mount")
                }
                
                // Unmount checkbox (only for mounted drives that are not system volumes)
                if drive.isMounted && 
                   !drive.mountPoint.contains("/System/Volumes/") &&
                   drive.mountPoint != "/" &&
                   !drive.mountPoint.contains("home") &&
                   !drive.mountPoint.contains("private/var") &&
                   !drive.mountPoint.contains("Library/Developer") {
                    
                    Button(action: {
                        driveManager.toggleUnmountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForUnmount ? "eject.circle.fill" : "eject.circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to unmount")
                }
            }
            .frame(width: 40)
            
            // Drive Icon
            Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
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
                        .foregroundColor(drive.isEFI ? .purple : (drive.type.contains("USB") ? .orange : .secondary))
                    
                    if !drive.mountPoint.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Status Badge
            if drive.isMounted {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            } else {
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            
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
                title: "Mount All External",
                icon: "play.circle",
                color: .green,
                action: {
                    mountAllExternal()
                }
            )
            
            ActionButton(
                title: "Unmount All External",
                icon: "eject.circle",
                color: .orange,
                action: {
                    unmountAllExternal()
                }
            )
            
            ActionButton(
                title: "Clear Selection",
                icon: "xmark.circle",
                color: .gray,
                action: {
                    driveManager.clearAllSelections()
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
                
                // Drives Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Storage Drives")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                        Text("\(mountedCount)/\(driveManager.allDrives.count) mounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if driveManager.allDrives.isEmpty {
                        Text("No drives detected")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(driveManager.allDrives) { drive in
                            DriveInfoCard(drive: drive)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func DriveInfoCard(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                    .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                
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
                
                if drive.isMounted && !drive.mountPoint.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
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
                    showAlert(title: "Permissions Info",
                             message: "Full Disk Access is required for full functionality. The app will still work with limited features.")
                }
            }
        }
    }
    
    private func mountSelected() {
        print("🔄 Starting mount operation...")
        print("📊 Selected drives: \(driveManager.mountSelection)")
        
        // Double-check selections are valid
        let drivesToMount = driveManager.allDrives.filter { $0.isSelectedForMount }
        if drivesToMount.isEmpty {
            showAlert(title: "Error", message: "No valid drives selected for mounting")
            return
        }
        
        // Show progress
        alertTitle = "Mounting..."
        alertMessage = "Mounting \(drivesToMount.count) drive(s)..."
        showAlert = true
        
        // Perform mount operation
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.mountSelectedDrives()
            
            DispatchQueue.main.async {
                alertTitle = result.success ? "Success" : "Error"
                alertMessage = result.message
                
                // Force refresh UI
                driveManager.refreshDrives()
                
                // Show alert
                showAlert = true
            }
        }
    }
    
    private func unmountSelected() {
        let result = driveManager.unmountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountAllExternal() {
        let result = driveManager.mountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func unmountAllExternal() {
        let result = driveManager.unmountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func showDebugView() {
        DispatchQueue.global(qos: .userInitiated).async {
            let debugInfo = driveManager.debugMountIssues()
            DispatchQueue.main.async {
                debugOutput = debugInfo
                alertTitle = "Debug Information"
                alertMessage = debugInfo
                showAlert = true
            }
        }
    }
    
    private func testMountFunction() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.testMountFunctionality()
            DispatchQueue.main.async {
                alertTitle = result.success ? "Test Success" : "Test Failed"
                alertMessage = result.message
                showAlert = true
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Drive Detail View
struct DriveDetailView: View {
    let drive: DriveInfo
    @ObservedObject var driveManager: DriveManager
    @Environment(\.dismiss) var dismiss
    
    @State private var operationInProgress = false
    @State private var operationMessage = ""
    @State private var showOperationAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                    .font(.largeTitle)
                    .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                
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
                InfoRow(label: "EFI:", value: drive.isEFI ? "Yes" : "No")
                InfoRow(label: "Mount Point:", value: drive.mountPoint.isEmpty ? "Not mounted" : drive.mountPoint)
                InfoRow(label: "Selected for Mount:", value: getCurrentDrive()?.isSelectedForMount ?? false ? "Yes" : "No")
                InfoRow(label: "Selected for Unmount:", value: getCurrentDrive()?.isSelectedForUnmount ?? false ? "Yes" : "No")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Action Buttons
            HStack(spacing: 12) {
                if operationInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Mount/Unmount Toggle
                    let currentDrive = getCurrentDrive()
                    
                    if drive.isMounted {
                        // Only show unmount option for non-system volumes
                        if !drive.mountPoint.contains("/System/Volumes/") &&
                           drive.mountPoint != "/" &&
                           !drive.mountPoint.contains("home") &&
                           !drive.mountPoint.contains("private/var") &&
                           !drive.mountPoint.contains("Library/Developer") {
                            
                            Button(action: {
                                if let currentDrive = currentDrive {
                                    driveManager.toggleUnmountSelection(for: currentDrive)
                                }
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: currentDrive?.isSelectedForUnmount ?? false ? "eject.circle.fill" : "eject.circle")
                                    Text(currentDrive?.isSelectedForUnmount ?? false ? "Deselect Unmount" : "Select to Unmount")
                                }
                                .frame(minWidth: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(currentDrive?.isSelectedForUnmount ?? false ? .orange : .blue)
                        } else {
                            Text("System Volume")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 180)
                        }
                    } else {
                        Button(action: {
                            if let currentDrive = currentDrive {
                                driveManager.toggleMountSelection(for: currentDrive)
                            }
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: currentDrive?.isSelectedForMount ?? false ? "play.circle.fill" : "play.circle")
                                Text(currentDrive?.isSelectedForMount ?? false ? "Deselect Mount" : "Select to Mount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(currentDrive?.isSelectedForMount ?? false ? .green : .blue)
                    }
                    
                    Button("Show in Finder") {
                        showInFinder()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!drive.isMounted || drive.mountPoint.isEmpty)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
        .alert("Operation Result", isPresented: $showOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
        .onAppear {
            print("📱 DriveDetailView appeared for: \(drive.identifier)")
            print("📱 Current selection state - Mount: \(getCurrentDrive()?.isSelectedForMount ?? false), Unmount: \(getCurrentDrive()?.isSelectedForUnmount ?? false)")
        }
    }
    
    private func getCurrentDrive() -> DriveInfo? {
        return driveManager.allDrives.first { $0.identifier == drive.identifier }
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func showInFinder() {
        guard !drive.mountPoint.isEmpty else { return }
        
        let url = URL(fileURLWithPath: drive.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}