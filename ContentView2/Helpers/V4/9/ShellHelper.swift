// ShellHelper.swift - Fix EFI detection
import Foundation
import AppKit

// Keep the struct definitions...

struct ShellHelper {
    
    // MARK: - EFI Specific Functions
    
    static func mountEFIDrive(_ identifier: String) -> (success: Bool, message: String) {
        print("⏫ Mounting EFI partition: \(identifier)")
        
        // First check if it's already mounted
        let checkResult = runCommand("mount | grep '/dev/\(identifier)'")
        if checkResult.success && !checkResult.output.isEmpty {
            return (true, "EFI partition is already mounted")
        }
        
        // Standard mount attempt
        let mountResult = runCommand("diskutil mount /dev/\(identifier)")
        
        if mountResult.success {
            return (true, "✅ Successfully mounted EFI partition")
        } else {
            print("⚠️ Standard mount failed: \(mountResult.output)")
            
            // Alternative: Create mount point and mount manually
            let mountDir = "/Volumes/EFI-\(identifier.replacingOccurrences(of: "s", with: "-"))"
            
            // Clean up if exists
            _ = runCommand("sudo rm -rf \(mountDir) 2>/dev/null || true")
            
            // Create mount point
            _ = runCommand("sudo mkdir -p \(mountDir)")
            
            // Try different filesystem types
            let filesystems = ["msdos", "hfs", "exfat", "fat32"]
            
            for fs in filesystems {
                print("🔧 Trying filesystem: \(fs)")
                let manualMount = runCommand("sudo mount -t \(fs) /dev/\(identifier) \(mountDir) 2>&1")
                
                if manualMount.success {
                    return (true, "✅ Mounted EFI partition (\(fs)) to \(mountDir)")
                }
            }
            
            // Last resort: diskutil mountDisk
            let diskResult = runCommand("diskutil mountDisk /dev/\(identifier)")
            
            if diskResult.success {
                return (true, "✅ Mounted using mountDisk")
            }
            
            return (false, "❌ Failed to mount EFI. Try in Terminal: sudo diskutil mount /dev/\(identifier)")
        }
    }
    
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives (including EFI)...")
        
        var drives: [DriveInfo] = []
        
        // Get disk list
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        var currentDisk = ""
        var foundPartitions: [String] = []
        
        for line in lines {
            // Find disk identifiers
            if line.contains("/dev/disk") && !line.contains("s") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let disk = parts.first?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = disk
                    print("📀 Found disk: \(currentDisk)")
                }
            }
            
            // Find partitions on current disk
            if line.contains(currentDisk) && line.contains("s") && !line.contains("synthesized") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let partition = parts.first, partition.hasPrefix(currentDisk) {
                    foundPartitions.append(partition)
                }
            }
        }
        
        print("🔍 Found partitions: \(foundPartitions)")
        
        // Get info for each partition
        for partitionId in foundPartitions {
            print("📋 Getting info for: \(partitionId)")
            let drive = getDriveInfo(deviceId: partitionId)
            
            // IMPORTANT: Don't filter here - return all drives
            drives.append(drive)
        }
        
        // Also get mounted volumes from df
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 6 && parts[0].hasPrefix("/dev/disk") {
                let deviceId = parts[0].replacingOccurrences(of: "/dev/", with: "")
                
                // Check if we already have this drive
                if !drives.contains(where: { $0.identifier == deviceId }) {
                    let drive = getDriveInfo(deviceId: deviceId)
                    drives.append(drive)
                }
            }
        }
        
        // Sort drives: mounted first, then EFI, then others
        let sortedDrives = drives.sorted { d1, d2 in
            if d1.isMounted != d2.isMounted {
                return d1.isMounted && !d2.isMounted
            }
            if d1.isEFI != d2.isEFI {
                return d1.isEFI && !d2.isEFI
            }
            return d1.identifier < d2.identifier
        }
        
        print("✅ Total drives found: \(sortedDrives.count)")
        for drive in sortedDrives {
            print("   - \(drive.identifier): \(drive.name) (\(drive.type)) \(drive.isMounted ? "Mounted" : "Unmounted") \(drive.isEFI ? "EFI" : "")")
        }
        
        return sortedDrives
    }
    
    private static func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting detailed info for: \(deviceId)")
        
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
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("Volume Name:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let volName = parts[1].trimmingCharacters(in: .whitespaces)
                    if !volName.isEmpty && volName != "Not applicable" {
                        name = volName
                    }
                }
            }
            else if trimmed.contains("Device / Media Name:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let mediaName = parts[1].trimmingCharacters(in: .whitespaces)
                    if !mediaName.isEmpty && name == "Disk \(deviceId)" {
                        name = mediaName
                    }
                }
            }
            else if trimmed.contains("Volume Size:") || trimmed.contains("Disk Size:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    size = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            else if trimmed.contains("Mount Point:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    mountPoint = parts[1].trimmingCharacters(in: .whitespaces)
                    isMounted = !mountPoint.isEmpty && 
                               mountPoint != "Not applicable" && 
                               mountPoint != "Not applicable (none)" &&
                               !mountPoint.contains("Not mounted")
                }
            }
            else if trimmed.contains("Protocol:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let protocolType = parts[1].trimmingCharacters(in: .whitespaces)
                    if protocolType.contains("USB") || protocolType.contains("External") {
                        isInternal = false
                        type = "USB"
                    } else if protocolType.contains("SATA") || protocolType.contains("PCI") {
                        isInternal = true
                        type = "Internal"
                    }
                }
            }
            else if trimmed.contains("Type (Bundle):") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let bundleType = parts[1].trimmingCharacters(in: .whitespaces)
                    if bundleType.contains("EFI") {
                        isEFI = true
                        type = "EFI"
                        name = "EFI System Partition"
                    }
                }
            }
            else if trimmed.contains("Internal:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let internalStr = parts[1].trimmingCharacters(in: .whitespaces)
                    isInternal = internalStr.contains("Yes")
                }
            }
        }
        
        // Check for EFI by identifier pattern (diskXs1 is usually EFI)
        if !isEFI && (deviceId.contains("s1") || deviceId.hasSuffix("1")) {
            if size.contains("MB") || size == "209.7 MB" || size == "314.6 MB" {
                let checkEFI = runCommand("diskutil info /dev/\(deviceId) | grep -i 'efi'")
                if checkEFI.success || checkEFI.output.lowercased().contains("efi") {
                    isEFI = true
                    type = "EFI"
                    name = "EFI System Partition"
                }
            }
        }
        
        // Check if it's external by disk number
        if !deviceId.starts(with: "disk0") && !deviceId.starts(with: "disk1") && !isEFI {
            isInternal = false
            if type == "Unknown" {
                type = "External"
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
    
    // Keep the rest of the functions...
    static func mountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏫ Mounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForMount && !drive.isMounted {
            print("🔧 Mounting: \(drive.name) (\(drive.identifier))")
            
            // Special handling for EFI
            if drive.isEFI {
                let result = mountEFIDrive(drive.identifier)
                if result.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): EFI mounted")
                } else {
                    failedCount += 1
                    messages.append("❌ \(drive.name): \(result.message)")
                }
                continue
            }
            
            let result = runCommand("diskutil mount /dev/\(drive.identifier)")
            
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): Mounted")
            } else {
                failedCount += 1
                let altResult = runCommand("diskutil mountDisk /dev/\(drive.identifier)")
                
                if altResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Mounted (disk method)")
                } else {
                    messages.append("❌ \(drive.name): Failed - \(result.output)")
                }
            }
        }
        
        let finalMessage = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Successfully mounted \(successCount) drive(s)\n\n\(finalMessage)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Mounted \(successCount), failed \(failedCount)\n\n\(finalMessage)")
        } else if failedCount > 0 {
            return (false, "❌ Failed to mount drives\n\n\(finalMessage)")
        } else {
            return (false, "No drives to mount")
        }
    }
    
    // Rest of the functions remain the same...
}