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
    
    // NEW: Improved Debug function to check permissions and setup
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
            messages.append("⚠️ Sudo requires password (normal)")
        }
        
        // Check current mounts
        let mountCheck = runCommand("mount | grep '/Volumes/' | wc -l")
        messages.append("Currently mounted volumes: \(mountCheck.output)")
        
        // BETTER: Check for unmounted drives more thoroughly
        messages.append("\n📊 Detailed Drive Analysis:")
        
        // Get all partitions
        let allPartitions = runCommand("diskutil list | grep -E 'disk[0-9]+s[0-9]+' | awk '{print $1}'")
        let partitions = allPartitions.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        messages.append("Total partitions found: \(partitions.count)")
        
        // Check which ones are mounted
        var mountedCount = 0
        var unmountedCount = 0
        var unmountedList: [String] = []
        
        for partition in partitions {
            let mountCheck = runCommand("mount | grep '/dev/\(partition)'")
            if mountCheck.output.isEmpty {
                unmountedCount += 1
                unmountedList.append(partition)
                
                // Check if it's mountable (not system)
                let info = getDriveInfo(deviceId: partition)
                if !info.name.contains("Recovery") && 
                   !info.name.contains("VM") && 
                   !info.name.contains("Preboot") &&
                   !info.name.contains("Update") &&
                   !info.isEFI &&
                   info.size != "0 B" {
                    messages.append("   - \(partition): \(info.name) (\(info.size)) - UNMOUNTED")
                }
            } else {
                mountedCount += 1
            }
        }
        
        messages.append("Mounted partitions: \(mountedCount)")
        messages.append("Unmounted partitions: \(unmountedCount)")
        
        if unmountedCount > 0 {
            messages.append("Potentially mountable: \(unmountedList.count)")
            for drive in unmountedList.prefix(5) {
                let info = getDriveInfo(deviceId: drive)
                if !info.name.contains("Recovery") && !info.name.contains("VM") {
                    messages.append("   - \(drive): \(info.name)")
                }
            }
        } else {
            messages.append("ℹ️ No unmounted drives found - all are already mounted")
        }
        
        // Check disk arbitration daemon
        let diskArbCheck = runCommand("ps aux | grep diskarbitrationd | grep -v grep")
        if diskArbCheck.output.isEmpty {
            messages.append("\n❌ CRITICAL: diskarbitrationd not running")
            messages.append("💡 This system service manages disk mounting")
            messages.append("💡 Try: sudo launchctl load /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist")
        } else {
            messages.append("\n✅ diskarbitrationd is running")
        }
        
        // Check if we can run basic disk commands
        messages.append("\n🧪 Testing basic disk commands:")
        let testCmd = runCommand("diskutil list | head -5")
        if testCmd.success {
            messages.append("✅ Can run diskutil list")
        } else {
            messages.append("❌ Cannot run diskutil list: \(testCmd.error)")
        }
        
        return messages.joined(separator: "\n")
    }
    
    // NEW: Function to restart disk arbitration daemon
    func restartDiskArbitrationDaemon() -> (success: Bool, message: String) {
        print("🔄 Attempting to restart diskarbitrationd")
        
        var messages: [String] = []
        
        // First check if it's running
        let checkResult = runCommand("ps aux | grep diskarbitrationd | grep -v grep")
        
        if checkResult.output.isEmpty {
            // Not running, try to start it
            messages.append("diskarbitrationd is not running, attempting to start...")
            let startResult = runCommand("sudo launchctl load /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist", needsSudo: true)
            
            if startResult.success {
                messages.append("✅ Started diskarbitrationd service")
                return (true, messages.joined(separator: "\n"))
            } else {
                messages.append("❌ Failed to start diskarbitrationd: \(startResult.error)")
                return (false, messages.joined(separator: "\n"))
            }
        } else {
            // Already running, try to restart
            messages.append("diskarbitrationd is running, attempting to restart...")
            let stopResult = runCommand("sudo launchctl unload /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist", needsSudo: true)
            
            Thread.sleep(forTimeInterval: 2.0)
            
            let startResult = runCommand("sudo launchctl load /System/Library/LaunchDaemons/com.apple.diskarbitrationd.plist", needsSudo: true)
            
            if startResult.success {
                messages.append("✅ Restarted diskarbitrationd service")
                return (true, messages.joined(separator: "\n"))
            } else {
                messages.append("❌ Failed to restart diskarbitrationd: \(startResult.error)")
                return (false, messages.joined(separator: "\n"))
            }
        }
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

// MARK: - Simplified Drive Manager
class DriveManager: ObservableObject {
    static let shared = DriveManager()
    private let shellHelper = ShellHelper.shared
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    @Published var operationMessage = ""
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        print("🔄 Starting drive refresh...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            
            DispatchQueue.main.async {
                self.allDrives = drives
                self.isLoading = false
                
                print("🔄 Drive refresh complete. Found \(self.allDrives.count) drives:")
                for drive in self.allDrives {
                    print("   - \(drive.name) (\(drive.identifier)): \(drive.isMounted ? "📌 Mounted" : "📦 Unmounted")")
                }
            }
        }
    }
    
    // Simple one-click toggle
    func toggleMountUnmount(for drive: DriveInfo) -> (success: Bool, message: String) {
        print("🔘 Toggling mount/unmount for: \(drive.identifier)")
        
        if drive.isMounted {
            return unmountDrive(drive)
        } else {
            return mountDrive(drive)
        }
    }
    
    private func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.identifier)")
        
        // Check if drive can be mounted
        if !shellHelper.canMountDrive(drive) {
            return (false, "⚠️ \(drive.name) cannot be mounted (system or invalid)")
        }
        
        // Create array with just this drive
        let drivesToMount = [DriveInfo(
            name: drive.name,
            identifier: drive.identifier,
            size: drive.size,
            type: drive.type,
            mountPoint: drive.mountPoint,
            isInternal: drive.isInternal,
            isEFI: drive.isEFI,
            partitions: drive.partitions,
            isMounted: false,
            isSelectedForMount: true,
            isSelectedForUnmount: false
        )]
        
        let result = shellHelper.mountSelectedDrives(drives: drivesToMount)
        
        // Refresh after mount
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    private func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.identifier)")
        
        // Cannot unmount system volumes
        if drive.mountPoint.contains("/System/Volumes/") || 
           drive.mountPoint == "/" ||
           drive.mountPoint.contains("home") ||
           drive.mountPoint.contains("private/var") ||
           drive.mountPoint.contains("Library/Developer") {
            return (false, "⚠️ Cannot unmount system volume: \(drive.name)")
        }
        
        // Create array with just this drive
        let drivesToUnmount = [DriveInfo(
            name: drive.name,
            identifier: drive.identifier,
            size: drive.size,
            type: drive.type,
            mountPoint: drive.mountPoint,
            isInternal: drive.isInternal,
            isEFI: drive.isEFI,
            partitions: drive.partitions,
            isMounted: true,
            isSelectedForMount: false,
            isSelectedForUnmount: true
        )]
        
        let result = shellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        
        // Refresh after unmount
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        
        return result
    }
    
    // Batch operations
    func mountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.mountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.unmountAllExternalDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        
        return result
    }
    
    // Debug functions
    func debugMountIssues() -> String {
        return shellHelper.debugMountIssues()
    }
    
    func restartDiskArbitrationDaemon() -> (success: Bool, message: String) {
        return shellHelper.restartDiskArbitrationDaemon()
    }
}

// MARK: - Simplified Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @StateObject private var driveManager = DriveManager.shared
    @State private var hasFullDiskAccess = false
    
    let shellHelper = ShellHelper.shared
    
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
                    
                    InfoView
                        .tabItem {
                            Label("Info", systemImage: "info.circle")
                        }
                        .tag(1)
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
        .onAppear {
            checkPermissions()
            driveManager.refreshDrives()
        }
    }
    
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Drive Mount Manager")
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
    
    private var DriveListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Actions
                HStack(spacing: 12) {
                    Button(action: {
                        mountAllExternal()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Mount All")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: {
                        unmountAllExternal()
                    }) {
                        HStack {
                            Image(systemName: "eject.circle.fill")
                            Text("Unmount All")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: {
                        fixDiskArbitration()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Fix Service")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drives List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    VStack(spacing: 8) {
                        ForEach(driveManager.allDrives) { drive in
                            DriveCardView(drive: drive)
                        }
                    }
                }
            }
            .padding()
        }
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
        .padding(40)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveCardView(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Drive Icon
                Image(systemName: driveIcon(for: drive))
                    .font(.title2)
                    .foregroundColor(driveColor(for: drive))
                    .frame(width: 30)
                
                // Drive Name and Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.headline)
                        .lineLimit(1)
                    
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
                            .foregroundColor(drive.isEFI ? .purple : (drive.type.contains("USB") ? .orange : .secondary))
                    }
                }
                
                Spacer()
                
                // Status Badge
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
                
                // Mount/Unmount Button (SINGLE BUTTON)
                Button(action: {
                    toggleDrive(drive)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        Text(drive.isMounted ? "Unmount" : "Mount")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(drive.isMounted ? .orange : .green)
                .disabled(!canToggle(drive: drive))
                .help(drive.isMounted ? "Unmount this drive" : "Mount this drive")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func driveIcon(for drive: DriveInfo) -> String {
        if drive.isEFI {
            return "memorychip"
        } else if drive.isInternal {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
        }
    }
    
    private func driveColor(for drive: DriveInfo) -> Color {
        if drive.isEFI {
            return .purple
        } else if drive.isInternal {
            return .blue
        } else {
            return .orange
        }
    }
    
    private func canToggle(drive: DriveInfo) -> Bool {
        if drive.isMounted {
            // Can unmount non-system volumes
            return !drive.mountPoint.contains("/System/Volumes/") &&
                   drive.mountPoint != "/" &&
                   !drive.mountPoint.contains("home") &&
                   !drive.mountPoint.contains("private/var") &&
                   !drive.mountPoint.contains("Library/Developer")
        } else {
            // Can mount unmounted drives that are mountable
            return shellHelper.canMountDrive(drive)
        }
    }
    
    private var InfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("System Information")
                    .font(.title)
                    .fontWeight(.bold)
                
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(driveManager.allDrives) { drive in
                            HStack {
                                Image(systemName: driveIcon(for: drive))
                                    .foregroundColor(driveColor(for: drive))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(drive.name)
                                        .font(.headline)
                                    
                                    Text("\(drive.identifier) • \(drive.size) • \(drive.type)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(drive.isMounted ? "Mounted" : "Unmounted")
                                    .font(.caption)
                                    .foregroundColor(drive.isMounted ? .green : .secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
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
    
    // MARK: - Action Functions
    
    private func checkPermissions() {
        DispatchQueue.global(qos: .background).async {
            let hasAccess = shellHelper.checkFullDiskAccess()
            DispatchQueue.main.async {
                hasFullDiskAccess = hasAccess
                if !hasAccess {
                    showAlert(title: "Permissions Info",
                             message: "Full Disk Access is required for full functionality.")
                }
            }
        }
    }
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
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
    
    private func fixDiskArbitration() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.restartDiskArbitrationDaemon()
            
            DispatchQueue.main.async {
                alertTitle = result.success ? "Success" : "Error"
                alertMessage = result.message
                
                if result.success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        driveManager.refreshDrives()
                    }
                }
                
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

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}