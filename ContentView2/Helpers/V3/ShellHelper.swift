//
//  ShellHelper.swift
//  System Maintenance Tool
//
//  Created by Shell helper with macOS 14+ compatibility
//

import Foundation
import AppKit

// MARK: - Shell Helper
struct ShellHelper {
    static func runCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running command: \(command)")
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            print("❌ Process execution error: \(error)")
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            return ("Error: \(error.localizedDescription)\nStderr: \(errorOutput)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        if !errorOutput.isEmpty && !errorOutput.contains("doesn't exist") {
            print("⚠️ Command error: \(errorOutput)")
        }
        
        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")
        return (combinedOutput, success)
    }
    
    // Method to run commands with sudo using AppleScript - No file writing
    static func runSudoCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running sudo command: \(command)")
        
        // Escape the command properly for AppleScript
        var escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        // Create AppleScript with proper escaping
        let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        // Escape the AppleScript itself for the shell
        let escapedAppleScript = appleScript.replacingOccurrences(of: "\"", with: "\\\"")
        
        // Run osascript
        let result = runCommand("osascript -e \"\(escapedAppleScript)\"")
        return result
    }
    
    // Alternative: Run sudo command by calling sudo directly (if sudo is cached)
    static func runSudoCommandDirect(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running sudo command directly: \(command)")
        return runCommand("sudo \(command)")
    }
    
    // Get ALL drives (mounted and unmounted) - Compatible version
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        if #available(macOS 14.0, *) {
            return getAllDrivesModern()
        } else {
            return getAllDrivesLegacy()
        }
    }
    
    @available(macOS 14.0, *)
    private static func getAllDrivesModern() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Get all user-mounted volumes from /Volumes (excluding system volumes)
        let mountedVolumes = getMountedVolumes()
        print("📌 Found \(mountedVolumes.count) mounted volumes")
        drives.append(contentsOf: mountedVolumes)
        
        // Get potentially unmounted partitions (excluding system partitions)
        let unmountedPartitions = getUnmountedPartitions()
        print("📌 Found \(unmountedPartitions.count) unmounted partitions")
        drives.append(contentsOf: unmountedPartitions)
        
        // Get external unmounted drives specifically
        let externalUnmounted = getExternalUnmountedDrives()
        print("📌 Found \(externalUnmounted.count) external unmounted drives")
        drives.append(contentsOf: externalUnmounted)
        
        return processAndSortDrives(drives)
    }
    
    private static func getAllDrivesLegacy() -> [DriveInfo] {
        print("📌 Using legacy drive detection for macOS < 14")
        var drives: [DriveInfo] = []
        
        // Method 1: List all disks
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        for line in lines {
            if line.contains("/dev/disk") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                for component in components {
                    if component.contains("disk") && component.contains("/dev/") {
                        let diskId = component.replacingOccurrences(of: "/dev/", with: "")
                        let drive = getDriveInfo(deviceId: diskId)
                        
                        // Skip obviously system/recovery partitions
                        if !shouldSkipDrive(drive) {
                            drives.append(drive)
                        }
                        break
                    }
                }
            }
        }
        
        // Method 2: Check mounted volumes
        let mountResult = runCommand("mount")
        let mountLines = mountResult.output.components(separatedBy: "\n")
        
        for line in mountLines {
            if line.contains("/dev/disk") && line.contains("on /Volumes/") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                if components.count >= 3 {
                    let devicePath = components[0]
                    let mountPoint = components[2]
                    
                    if devicePath.hasPrefix("/dev/disk") {
                        let diskId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                        
                        // Check if already in list
                        if !drives.contains(where: { $0.identifier == diskId }) {
                            let drive = getDriveInfo(deviceId: diskId)
                            var updatedDrive = drive
                            updatedDrive.isMounted = true
                            updatedDrive.mountPoint = mountPoint
                            
                            // Get volume name from mount point
                            let volumeName = (mountPoint as NSString).lastPathComponent
                            if !volumeName.isEmpty {
                                updatedDrive.name = volumeName
                            }
                            
                            drives.append(updatedDrive)
                        }
                    }
                }
            }
        }
        
        return processAndSortDrives(drives)
    }
    
    private static func shouldSkipDrive(_ drive: DriveInfo) -> Bool {
        let skipKeywords = [
            "Recovery",
            "VM",
            "Preboot",
            "Update",
            "Apple_APFS_ISC",
            "com.apple.os.update",
            "Boot",
            "macOS Install"
        ]
        
        for keyword in skipKeywords {
            if drive.name.contains(keyword) || drive.identifier.contains(keyword.lowercased()) {
                return true
            }
        }
        
        return drive.size == "0 B" || drive.size.contains("Zero") || drive.size.contains("zero")
    }
    
    private static func processAndSortDrives(_ drives: [DriveInfo]) -> [DriveInfo] {
        // Remove duplicates
        var uniqueDrives: [DriveInfo] = []
        var seenIdentifiers = Set<String>()
        
        for drive in drives {
            if !seenIdentifiers.contains(drive.identifier) {
                seenIdentifiers.insert(drive.identifier)
                uniqueDrives.append(drive)
            }
        }
        
        // Sort: mounted first, then unmounted, then alphabetically
        uniqueDrives.sort {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            if $0.isInternal != $1.isInternal {
                return !$0.isInternal && $1.isInternal  // External first
            }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        
        print("✅ Total unique drives found: \(uniqueDrives.count)")
        for drive in uniqueDrives {
            print("   - \(drive.name) (\(drive.identifier)): \(drive.isMounted ? "Mounted" : "Unmounted") - \(drive.type)")
        }
        
        return uniqueDrives
    }
    
    private static func getMountedVolumes() -> [DriveInfo] {
        print("📌 Getting mounted volumes...")
        var volumes: [DriveInfo] = []
        
        // Get df output for all mounted volumes
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        // Parse df output
        for line in dfLines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Skip header and empty lines
            if components.count < 6 || components[0] == "Filesystem" {
                continue
            }
            
            let devicePath = components[0]
            let mountPoint = components[5]
            
            // Only process /dev/disk devices that are user volumes
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                // Skip system partitions if not in /Volumes/
                if !mountPoint.hasPrefix("/Volumes/") && 
                   (mountPoint.contains("/System/Volumes/") ||
                    mountPoint == "/" ||
                    mountPoint.contains("home") ||
                    mountPoint.contains("private/var") ||
                    mountPoint.contains("Library/Developer")) {
                    print("⚠️ Skipping system volume: \(deviceId) at \(mountPoint)")
                    continue
                }
                
                let volumeName = (mountPoint as NSString).lastPathComponent
                let size = components.count >= 2 ? components[1] : "Unknown"
                
                // Get detailed info
                let drive = getDriveInfo(deviceId: deviceId)
                
                let updatedDrive = DriveInfo(
                    name: drive.name == deviceId ? volumeName : drive.name,
                    identifier: deviceId,
                    size: size != "Unknown" ? size : drive.size,
                    type: drive.type,
                    mountPoint: mountPoint,
                    isInternal: drive.isInternal,
                    isEFI: deviceId.contains("EFI") || volumeName == "EFI" || drive.name.contains("EFI"),
                    partitions: drive.partitions,
                    isMounted: true,
                    isSelectedForMount: false,
                    isSelectedForUnmount: false
                )
                
                volumes.append(updatedDrive)
                print("📌 Found mounted volume: \(updatedDrive.name) (\(deviceId)) at \(mountPoint)")
            }
        }
        
        return volumes
    }
    
    private static func getUnmountedPartitions() -> [DriveInfo] {
        print("📌 Getting unmounted partitions...")
        var partitions: [DriveInfo] = []
        
        // Get list of ALL disk partitions
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        var currentDisk = ""
        
        for line in lines {
            // Check for disk identifier line
            if line.contains("/dev/disk") && line.contains("GUID_partition_scheme") {
                let components = line.components(separatedBy: " ")
                if let diskId = components.first(where: { $0.contains("disk") })?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = diskId
                    print("📋 Processing disk: \(currentDisk)")
                }
            }
            
            // Look for partition lines
            if line.contains("disk") && line.contains("s") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if let partitionId = components.first(where: { $0.hasPrefix("disk") && $0.contains("s") }) {
                    // Skip if it starts with the current disk (like disk0s1 on disk0)
                    if !currentDisk.isEmpty && partitionId.hasPrefix(currentDisk) {
                        // Get partition info
                        let drive = getDriveInfo(deviceId: partitionId)
                        
                        // Check if it's mounted
                        let mountCheck = runCommand("diskutil info /dev/\(partitionId) | grep -i 'mount point'")
                        let isMounted = !mountCheck.output.lowercased().contains("not applicable") && 
                                       !mountCheck.output.lowercased().contains("no mount point")
                        
                        if !isMounted {
                            // Skip empty or system partitions
                            if !shouldSkipDrive(drive) {
                                let unmountedDrive = DriveInfo(
                                    name: drive.name,
                                    identifier: partitionId,
                                    size: drive.size,
                                    type: drive.type,
                                    mountPoint: "",
                                    isInternal: drive.isInternal,
                                    isEFI: partitionId.contains("EFI") || drive.name.contains("EFI"),
                                    partitions: drive.partitions,
                                    isMounted: false,
                                    isSelectedForMount: false,
                                    isSelectedForUnmount: false
                                )
                                
                                partitions.append(unmountedDrive)
                                print("📌 Found unmounted partition: \(drive.name) (\(partitionId)) - Size: \(drive.size)")
                            }
                        }
                    }
                }
            }
        }
        
        return partitions
    }
    
    private static func getExternalUnmountedDrives() -> [DriveInfo] {
        print("📌 Getting external unmounted drives...")
        var drives: [DriveInfo] = []
        
        // List all external disks
        let listResult = runCommand("""
        diskutil list | grep -i 'external\|usb' | grep -E 'disk[0-9]+s[0-9]+' | awk '{print $1}' | sort -u
        """)
        
        let partitionIds = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for partitionId in partitionIds {
            let drive = getDriveInfo(deviceId: partitionId)
            
            if !drive.isMounted && !drive.isInternal {
                let unmountedDrive = DriveInfo(
                    name: drive.name,
                    identifier: partitionId,
                    size: drive.size,
                    type: drive.type,
                    mountPoint: "",
                    isInternal: false,
                    isEFI: false,
                    partitions: drive.partitions,
                    isMounted: false,
                    isSelectedForMount: false,
                    isSelectedForUnmount: false
                )
                
                drives.append(unmountedDrive)
                print("📌 Found external unmounted: \(drive.name) (\(partitionId))")
            }
        }
        
        return drives
    }
    
    static func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting info for device: \(deviceId)")
        
        // Get detailed info from diskutil
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null || echo 'Not found'")
        
        var name = deviceId
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = false
        var isUSB = false
        var isMounted = false
        
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lowercasedLine = trimmedLine.lowercased()
            
            if lowercasedLine.contains("volume name:") || lowercasedLine.contains("device / media name:") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && !value.lowercased().contains("not applicable") {
                        name = value
                    }
                }
            } else if lowercasedLine.contains("volume size:") || lowercasedLine.contains("disk size:") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        size = value
                    }
                }
            } else if lowercasedLine.contains("mount point:") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && !value.lowercased().contains("not applicable") {
                        mountPoint = value
                        isMounted = true
                    }
                }
            } else if lowercasedLine.contains("protocol:") || lowercasedLine.contains("bus protocol:") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    if value.lowercased().contains("usb") {
                        isUSB = true
                        type = "USB"
                    } else if value.lowercased().contains("sata") || value.lowercased().contains("pci") {
                        isInternal = true
                        type = "Internal"
                    } else if !value.isEmpty {
                        type = value
                    }
                }
            } else if lowercasedLine.contains("internal:") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    isInternal = value.lowercased().contains("yes")
                }
            } else if lowercasedLine.contains("type (bundle):") {
                let components = trimmedLine.split(separator: ":", maxSplits: 1)
                if components.count > 1 {
                    let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                    if value.lowercased().contains("efi") {
                        name = "EFI System Partition"
                        type = "EFI"
                    }
                }
            }
        }
        
        // If still no name, use a generic one
        if name == deviceId || name.isEmpty {
            name = "Disk \(deviceId)"
        }
        
        // Determine type if still unknown
        if type == "Unknown" {
            if deviceId.lowercased().contains("efi") {
                type = "EFI"
            } else if isUSB {
                type = "USB"
            } else if isInternal {
                type = "Internal"
            } else {
                // Try to determine by disk number
                let diskNum = deviceId.replacingOccurrences(of: "disk", with: "").prefix(1)
                if let num = Int(diskNum), num < 5 {
                    type = "Internal"
                    isInternal = true
                } else {
                    type = "External"
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
            isEFI: deviceId.lowercased().contains("efi") || type == "EFI" || name.lowercased().contains("efi"),
            partitions: [],
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    // Mount selected drives - IMPROVED with better error handling
    static func mountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏫ Mounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForMount && !drive.isMounted {
            print("🔧 Attempting to mount drive: \(drive.name) (\(drive.identifier))")
            
            let mountResult = runCommand("diskutil mount /dev/\(drive.identifier)")
            
            if mountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Mounted successfully")
                
                // Verify mount
                let verifyResult = runCommand("diskutil info /dev/\(drive.identifier) | grep -i 'mount point'")
                if verifyResult.output.lowercased().contains("not applicable") || verifyResult.output.contains("No mount point") {
                    messages.append("⚠️ \(drive.name): Mounted but no mount point found")
                }
            } else {
                failedCount += 1
                // Try alternative method
                print("⚠️ Standard mount failed, trying alternative method...")
                let altResult = runCommand("diskutil mountDisk /dev/\(drive.identifier)")
                
                if altResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Mounted using alternative method")
                } else {
                    let errorMsg = mountResult.output.isEmpty ? "Unknown error" : mountResult.output
                    messages.append("❌ \(drive.name): Failed - \(errorMsg)")
                    
                    // Try one more time with verbose output
                    let debugResult = runCommand("diskutil mount /dev/\(drive.identifier) 2>&1")
                    print("🔍 Debug mount output: \(debugResult.output)")
                }
            }
            
            // Small delay between mounts
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully mounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Mounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "Failed to mount all selected drives\n\n\(message)")
        } else {
            return (true, "No drives selected for mount")
        }
    }
    
    // Unmount selected drives - FIXED to only unmount user volumes
    static func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            print("🔧 Unmounting drive: \(drive.name) (\(drive.identifier))")
            
            // Skip system volumes and mounted applications
            if drive.mountPoint.contains("/System/Volumes/") || 
               drive.mountPoint == "/" ||
               drive.mountPoint.contains("home") ||
               drive.mountPoint.contains("private/var") ||
               drive.mountPoint.contains("Library/Developer") {
                print("⚠️ Skipping system volume: \(drive.name) at \(drive.mountPoint)")
                messages.append("⚠️ \(drive.name): Skipped (system volume)")
                continue
            }
            
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted successfully")
            } else {
                failedCount += 1
                // Try force unmount
                print("⚠️ Standard unmount failed, trying force unmount...")
                let forceResult = runSudoCommand("diskutil unmount force /dev/\(drive.identifier)")
                
                if forceResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Force unmounted")
                } else {
                    let errorMsg = unmountResult.output.isEmpty ? "Unknown error" : unmountResult.output
                    messages.append("❌ \(drive.name): Failed - \(errorMsg)")
                }
            }
            
            // Small delay between unmounts
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully unmounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "Failed to unmount all selected drives\n\n\(message)")
        } else {
            return (true, "No drives selected for unmount")
        }
    }
    
    // Mount all unmounted external drives
    static func mountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏫ Mounting all external drives")
        
        // Find all unmounted external disks - compatible method
        let result = runCommand("""
        diskutil list | grep -E '^/dev/disk' | grep -v 'internal' | awk '{print $1}' | sed 's|/dev/||' | while read disk; do
            if ! mount | grep -q "/dev/$disk "; then
                info=$(diskutil info /dev/$disk 2>/dev/null)
                if echo "$info" | grep -q 'Protocol.*USB\\|Bus Protocol.*USB\\|Removable.*Yes\\|Internal.*No'; then
                    echo "$disk"
                fi
            fi
        done
        """)
        
        let diskIds = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 Found \(diskIds.count) unmounted external drives: \(diskIds)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in diskIds {
            print("🔧 Mounting external drive: \(diskId)")
            let mountResult = runCommand("diskutil mount /dev/\(diskId)")
            
            if mountResult.success {
                successCount += 1
                messages.append("✅ Disk \(diskId): Mounted")
            } else {
                failedCount += 1
                messages.append("❌ Disk \(diskId): Failed")
            }
            
            // Small delay
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully mounted \(successCount) external drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Mounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && diskIds.isEmpty {
            return (true, "No unmounted external drives found")
        } else {
            return (false, "Failed to mount external drives\n\n\(message)")
        }
    }
    
    // Unmount all external drives - FIXED to only unmount user volumes
    static func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all external drives")
        
        // Get all mounted user volumes (not system volumes) - compatible method
        let result = runCommand("""
        mount | grep '/Volumes/' | grep -v '/System/Volumes/' | awk '{print $1}' | sed 's|/dev/||' | sort -u
        """)
        
        let diskIds = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 Found \(diskIds.count) mounted external drives: \(diskIds)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in diskIds {
            // Skip if it's a system disk (disk0-4)
            if diskId.starts(with: "disk0") || diskId.starts(with: "disk1") || 
               diskId.starts(with: "disk2") || diskId.starts(with: "disk3") || 
               diskId.starts(with: "disk4") {
                print("⚠️ Skipping system disk: \(diskId)")
                continue
            }
            
            print("🔧 Unmounting external drive: \(diskId)")
            let unmountResult = runCommand("diskutil unmount /dev/\(diskId)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(diskId): Unmounted")
            } else {
                failedCount += 1
                messages.append("❌ \(diskId): Failed")
            }
            
            // Small delay
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully unmounted \(successCount) external drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && diskIds.isEmpty {
            return (true, "No external drives mounted")
        } else {
            return (false, "Failed to unmount external drives\n\n\(message)")
        }
    }
    
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    static func checkFullDiskAccess() -> Bool {
        // Try multiple methods for better compatibility
        let testCommands = [
            "ls /Volumes/ 2>&1",
            "stat /System/Library/CoreServices 2>&1",
            "cat ~/Library/Preferences/.GlobalPreferences.plist 2>&1 | head -1"
        ]
        
        for command in testCommands {
            let result = runCommand(command)
            if result.output.lowercased().contains("operation not permitted") ||
               result.output.lowercased().contains("permission denied") {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Additional Helper Methods for KextsManager
extension ShellHelper {
    // Check if a kext is loaded
    static func checkKextLoaded(_ kextName: String) -> Bool {
        let result = runCommand("kextstat | grep -i \(kextName)")
        return result.success && !result.output.isEmpty
    }
    
    // Alias for runSudoCommand for compatibility
    static func runCommandWithSudo(_ command: String) -> (output: String, success: Bool) {
        return runSudoCommand(command)
    }
}