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
    
    // NEW: Method to run commands with sudo using AppleScript
    static func runSudoCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running sudo command: \(command)")
        
        // Escape quotes in the command for AppleScript
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        
        let appleScript = """
        do shell script "\(escapedCommand)" 
        with administrator privileges 
        with prompt "SystemMaintenance needs administrator access" 
        without altering line endings
        """
        
        let result = runCommand("osascript -e '\(appleScript)'")
        return result
    }
    
    // Get ALL drives (mounted and unmounted) - Improved detection
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
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
        
        // Remove duplicates and sort
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
        var partitionPattern = ""
        
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
            if line.contains("disk") && line.contains("s") && line.contains("Apple_") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if let partitionId = components.first(where: { $0.hasPrefix("disk") && $0.contains("s") }) {
                    // Skip if it starts with the current disk (like disk0s1 on disk0)
                    if !currentDisk.isEmpty && partitionId.hasPrefix(currentDisk) {
                        // Get partition info
                        let drive = getDriveInfo(deviceId: partitionId)
                        
                        // Check if it's mounted
                        let mountCheck = runCommand("diskutil info /dev/\(partitionId) | grep 'Mount Point'")
                        let isMounted = !mountCheck.output.contains("Not applicable") && !mountCheck.output.contains("No mount point")
                        
                        if !isMounted {
                            // Skip empty or system partitions
                            if !drive.name.contains("Recovery") && 
                               !drive.name.contains("VM") && 
                               !drive.name.contains("Preboot") && 
                               !drive.name.contains("Update") &&
                               !drive.name.contains("Apple_APFS_ISC") &&
                               drive.size != "0 B" {
                                
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
        diskutil list external | grep -E 'disk[0-9]+s[0-9]+' | awk '{print $1}' | sort -u
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
    
    private static func getDriveInfo(deviceId: String) -> DriveInfo {
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
            
            if trimmedLine.contains("Volume Name:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let volumeName = components[1].trimmingCharacters(in: .whitespaces)
                    if !volumeName.isEmpty && volumeName != "Not applicable" && volumeName != "Not applicable (none)" {
                        name = volumeName
                    }
                }
            } else if trimmedLine.contains("Volume Size:") || trimmedLine.contains("Disk Size:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    size = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.contains("Mount Point:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                    isMounted = !mountPoint.isEmpty && mountPoint != "Not applicable" && mountPoint != "Not applicable (none)"
                }
            } else if trimmedLine.contains("Protocol:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let protocolType = components[1].trimmingCharacters(in: .whitespaces)
                    if protocolType.contains("USB") {
                        isUSB = true
                        type = "USB"
                    } else if protocolType.contains("SATA") || protocolType.contains("PCI") {
                        isInternal = true
                        type = "Internal"
                    } else {
                        type = protocolType
                    }
                }
            } else if trimmedLine.contains("Bus Protocol:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let busType = components[1].trimmingCharacters(in: .whitespaces)
                    if busType.contains("USB") {
                        isUSB = true
                        type = "USB"
                    }
                }
            } else if trimmedLine.contains("Device / Media Name:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let mediaName = components[1].trimmingCharacters(in: .whitespaces)
                    if (name == deviceId || name.isEmpty) && !mediaName.isEmpty {
                        name = mediaName
                    }
                }
            } else if trimmedLine.contains("Type (Bundle):") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let bundleType = components[1].trimmingCharacters(in: .whitespaces)
                    if bundleType.contains("EFI") {
                        name = "EFI System Partition"
                        type = "EFI"
                    }
                }
            } else if trimmedLine.contains("Internal:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let internalStr = components[1].trimmingCharacters(in: .whitespaces)
                    isInternal = internalStr.contains("Yes")
                }
            }
        }
        
        // If still no name, use a generic one
        if name == deviceId || name.isEmpty {
            name = "Disk \(deviceId)"
        }
        
        // Determine type if still unknown
        if type == "Unknown" {
            if deviceId.contains("EFI") {
                type = "EFI"
            } else if isUSB {
                type = "USB"
            } else if isInternal {
                type = "Internal"
            } else {
                // Try to determine by disk number
                let diskNum = deviceId.replacingOccurrences(of: "disk", with: "").replacingOccurrences(of: "s.*", with: "", options: .regularExpression)
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
            isEFI: deviceId.contains("EFI") || type == "EFI" || name.contains("EFI"),
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
                let verifyResult = runCommand("diskutil info /dev/\(drive.identifier) | grep 'Mount Point'")
                if verifyResult.output.contains("Not applicable") || verifyResult.output.contains("No mount point") {
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
        
        // Find all unmounted external disks
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
        
        // Get all mounted user volumes (not system volumes)
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
        let testResult = runCommand("ls /Volumes/ 2>&1")
        return !testResult.output.contains("Operation not permitted")
    }
}