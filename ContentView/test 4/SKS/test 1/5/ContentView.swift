import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - Enhanced Shell Command Helper for USB Boot
struct ShellHelper {
    static func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, success: Bool) {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = pipe
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
        } else {
            task.arguments = ["-c", command]
        }
        
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            print("Command execution error: \(error)")
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            return ("Error: \(error.localizedDescription)\nStderr: \(errorOutput)", false)
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        if !errorOutput.isEmpty && !errorOutput.contains("doesn't exist") {
            print("Command stderr: \(errorOutput)")
        }
        
        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")
        return (combinedOutput, success)
    }
    
    // MARK: - Enhanced USB Drive Detection
    static func findUSBDrives() -> [String] {
        print("=== Finding USB Drives ===")
        
        var usbDrives: [String] = []
        
        // Direct approach - look for external disks
        let result = runCommand("""
        diskutil list | grep -E "^/dev/disk[0-9]+.*external.*physical" | \
        awk '{print $1}' | \
        sed 's|/dev/||'
        """)
        
        if result.success {
            let drives = result.output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
            
            for drive in drives {
                print("Found USB drive via direct method: \(drive)")
                usbDrives.append(drive)
            }
        }
        
        // Alternative method using diskutil info
        if usbDrives.isEmpty {
            print("Using alternative USB detection...")
            let altResult = runCommand("""
            for disk in $(diskutil list | grep -oE '^/dev/disk[0-9]+'); do
                disk_id=$(echo $disk | sed 's|/dev/||')
                info=$(diskutil info $disk 2>/dev/null | grep -E "Protocol|Internal|External")
                if echo "$info" | grep -qi "external.*yes\\|protocol.*usb\\|internal.*no"; then
                    echo "$disk_id"
                fi
            done
            """)
        
        if altResult.success {
            let drives = altResult.output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
            
            for drive in drives {
                if !usbDrives.contains(drive) {
                    print("Found USB drive via info method: \(drive)")
                    usbDrives.append(drive)
                }
            }
        }
    }
    
    print("Found \(usbDrives.count) USB drives: \(usbDrives)")
    return usbDrives
}

// MARK: - Enhanced USB EFI Mounting
static func mountUSBEFI() -> (success: Bool, path: String?) {
    print("=== Mounting USB EFI Partition ===")
    
    // 1. First check if any EFI is already mounted
    if let mountedEFI = getEFIPath() {
        print("EFI already mounted at: \(mountedEFI)")
        return (true, mountedEFI)
    }
    
    // 2. Find USB drives
    let usbDrives = findUSBDrives()
    
    if usbDrives.isEmpty {
        print("No USB drives found. Trying all EFI partitions...")
        let result = mountEFIPartition()
        return (result, getEFIPath())
    }
    
    // 3. Try to find and mount EFI on USB drives
    for usbDrive in usbDrives {
        print("\nChecking USB drive: \(usbDrive)")
        
        // Look for EFI partition on this USB drive
        let efiPartition = findEFIPartitionOnDisk(usbDrive)
        
        if let efiPart = efiPartition {
            print("Found potential EFI partition: \(efiPart)")
            
            // Check if it's already mounted
            let mountCheck = runCommand("""
            mount | grep "/dev/\(efiPart)" | awk '{print $3}'
            """)
            
            if mountCheck.success, let mountPoint = mountCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                print("Already mounted at: \(mountPoint)")
                return (true, mountPoint)
            }
            
            // Try to mount it
            print("Attempting to mount \(efiPart)...")
            let mountResult = mountDrive(identifier: efiPart)
            
            if mountResult.success {
                print("✅ Successfully mounted: \(efiPart)")
                if let mountPoint = mountResult.mountPoint {
                    print("Mounted at: \(mountPoint)")
                    return (true, mountPoint)
                }
            } else {
                print("❌ Failed to mount \(efiPart)")
            }
        } else {
            print("No EFI partition found on \(usbDrive)")
        }
    }
    
    // 4. If no USB EFI mounted, try manual EFI search
    print("\nNo USB EFI mounted, trying manual EFI search...")
    let result = mountEFIPartition()
    return (result, getEFIPath())
}

static func findEFIPartitionOnDisk(_ disk: String) -> String? {
    print("Looking for EFI partition on disk \(disk)...")
    
    // Get all partitions on this disk
    let partitionsResult = runCommand("""
    diskutil list /dev/\(disk) | \
    grep -oE 'disk[0-9]+s[0-9]+' | \
    head -10
    """)
    
    if !partitionsResult.success || partitionsResult.output.isEmpty {
        print("No partitions found on disk \(disk)")
        return nil
    }
    
    let partitions = partitionsResult.output.components(separatedBy: "\n")
        .filter { !$0.isEmpty }
    
    print("Found partitions: \(partitions)")
    
    // Check each partition for EFI type
    for partition in partitions {
        let typeResult = runCommand("""
        diskutil info /dev/\(partition) 2>/dev/null | \
        grep -E "Type Name|Content" | \
        grep -i "efi\\|fat32\\|msdos" | \
        head -1
        """)
        
        if typeResult.success && !typeResult.output.isEmpty {
            print("Found EFI/FAT partition: \(partition)")
            return partition
        }
        
        // Also check by partition number (s1 is often EFI)
        if partition.hasSuffix("s1") {
            print("Found s1 partition (potential EFI): \(partition)")
            return partition
        }
    }
    
    // If no EFI found, return first partition
    if let firstPartition = partitions.first {
        print("Using first partition as fallback: \(firstPartition)")
        return firstPartition
    }
    
    return nil
}

static func mountEFIPartition() -> Bool {
    print("=== Mounting Any EFI Partition ===")
    
    // Get all potential EFI partitions across all disks
    let efiCandidates = runCommand("""
    for disk in $(diskutil list | grep -oE '^/dev/disk[0-9]+' | sed 's|/dev/||'); do
        for part in $(diskutil list /dev/$disk | grep -oE 'disk[0-9]+s[0-9]+'); do
            type_info=$(diskutil info /dev/$part 2>/dev/null | grep -E "Type Name|Content")
            if echo "$type_info" | grep -iq "efi.*boot\\|fat32\\|msdos"; then
                echo "$part"
            fi
        done
    done
    """)
    
    let candidates = efiCandidates.output.components(separatedBy: "\n")
        .filter { !$0.isEmpty }
    
    print("Found \(candidates.count) EFI candidates: \(candidates)")
    
    for partition in candidates {
        print("Trying to mount \(partition)...")
        
        // Check if already mounted
        let mountCheck = runCommand("""
        diskutil info /dev/\(partition) 2>/dev/null | \
        grep "Mount Point" | \
        awk -F': ' '{print $2}' | \
        xargs
        """)
        
        if mountCheck.success, let mountPoint = mountCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
           mountPoint != "(Not Mounted)" && !mountPoint.isEmpty {
            print("✅ Already mounted at: \(mountPoint)")
            return true
        }
        
        // Try to mount
        let mountResult = mountDrive(identifier: partition)
        
        if mountResult.success {
            print("✅ Successfully mounted \(partition)")
            return true
        } else {
            print("❌ Failed to mount \(partition)")
        }
    }
    
    print("❌ Failed to mount any EFI partition")
    return false
}

// MARK: - Simple Drive Mounting
static func mountDrive(identifier: String) -> (success: Bool, mountPoint: String?) {
    print("=== Mounting Drive \(identifier) ===")
    
    // First check if already mounted
    let checkCommand = """
    diskutil info /dev/\(identifier) 2>/dev/null | \
    grep "Mount Point" | \
    awk -F': ' '{print $2}' | \
    xargs
    """
    
    let checkResult = runCommand(checkCommand)
    if checkResult.success, let mountPoint = checkResult.output.nonEmpty,
       mountPoint != "(Not Mounted)" && !mountPoint.isEmpty {
        print("Already mounted at: \(mountPoint)")
        return (true, mountPoint)
    }
    
    // Try to mount
    let mountResult = runCommand("diskutil mount \(identifier)", needsSudo: true)
    
    if mountResult.success {
        print("✅ Successfully mounted \(identifier)")
        
        // Get mount point after mounting
        let verifyCommand = """
        diskutil info /dev/\(identifier) 2>/dev/null | \
        grep "Mount Point" | \
        awk -F': ' '{print $2}' | \
        xargs
        """
        
        let verifyResult = runCommand(verifyCommand)
        if verifyResult.success, let mountPoint = verifyResult.output.nonEmpty,
           mountPoint != "(Not Mounted)" && !mountPoint.isEmpty {
            print("Mounted at: \(mountPoint)")
            return (true, mountPoint)
        }
        
        // Try alternative method to get mount point
        let altVerify = runCommand("""
        mount | grep "/dev/\(identifier)" | awk '{print $3}'
        """)
        
        if altVerify.success, let mountPoint = altVerify.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            print("Mounted at (via mount): \(mountPoint)")
            return (true, mountPoint)
        }
    }
    
    print("❌ Failed to mount \(identifier): \(mountResult.output)")
    return (false, nil)
}

static func getEFIPath() -> String? {
    print("=== Searching for mounted EFI ===")
    
    // Method 1: Check for mounted EFI volumes (like /Volumes/EFI, /Volumes/EFI 1, etc.)
    let mountedCheck = runCommand("""
    mount | grep -E 'msdos\\|fat32' | grep -v 'VMware' | \
    awk '{print $3}' | \
    grep -i efi
    """)
    
    if let path = mountedCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
        print("Found EFI via mount check: \(path)")
        return path
    }
    
    // Method 2: Look for EFI in /Volumes directory
    let volumesCheck = runCommand("""
    ls -d /Volumes/* 2>/dev/null | \
    while read volume; do
        # Check if it's an EFI volume
        if mount | grep -q "on $volume.*msdos\\\\|fat32"; then
            # Check for EFI folder structure
            if [ -d "$volume/EFI" ] || [ -d "$volume/EFI/BOOT" ] || [ -d "$volume/EFI/OC" ]; then
                echo "$volume"
                exit 0
            fi
        fi
    done
    """)
    
    if let path = volumesCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
        print("Found EFI via /Volumes check: \(path)")
        return path
    }
    
    // Method 3: Check diskutil info for all partitions
    let diskCheck = runCommand("""
    for disk in $(diskutil list | grep -oE '^/dev/disk[0-9]+'); do
        diskutil list $disk | grep -oE 'disk[0-9]+s[0-9]+' | while read part; do
            mount_point=$(diskutil info /dev/$part 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
            if [ "$mount_point" != "(Not Mounted)" ] && [ -n "$mount_point" ]; then
                type_info=$(diskutil info /dev/$part 2>/dev/null | grep -E "Type Name|Content")
                if echo "$type_info" | grep -iq "efi.*boot\\|fat32\\|msdos"; then
                    echo "$mount_point"
                    exit 0
                fi
            fi
        done
    done
    """)
    
    if let path = diskCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
        print("Found EFI via diskutil check: \(path)")
        return path
    }
    
    // Method 4: Direct check for specific USB EFI
    let directCheck = runCommand("""
    if mount | grep -q "/dev/disk9s1"; then
        mount | grep "/dev/disk9s1" | awk '{print $3}'
    fi
    """)
    
    if let path = directCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
        print("Found EFI via direct disk9s1 check: \(path)")
        return path
    }
    
    // Method 5: Check common EFI mount points
    let commonPaths = ["/Volumes/EFI", "/Volumes/EFI 1", "/Volumes/EFI 2", "/Volumes/EFI_1"]
    for path in commonPaths {
        if FileManager.default.fileExists(atPath: path) {
            print("Found EFI via common path check: \(path)")
            return path
        }
    }
    
    print("No mounted EFI found")
    return nil
}

// MARK: - List Mountable Partitions (Simplified)
static func getMountablePartitions() -> [PartitionInfo] {
    print("=== Getting Mountable Partitions ===")
    
    var partitions: [PartitionInfo] = []
    
    // Simple diskutil list command
    let result = runCommand("""
    diskutil list | grep -oE '^/dev/disk[0-9]+' | while read disk; do
        diskutil list $disk | grep -oE 'disk[0-9]+s[0-9]+' | while read part; do
            echo "$part"
        done
    done
    """)
    
    if result.success {
        let partitionIds = result.output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        
        for partitionId in partitionIds {
            // Get partition info
            let infoCommand = """
            diskutil info /dev/\(partitionId) 2>/dev/null
            """
            let infoResult = runCommand(infoCommand)
            
            if infoResult.success {
                var name = "Partition \(partitionId)"
                var size = "Unknown"
                var type = "Unknown"
                var mountPoint = ""
                
                // Parse info
                let lines = infoResult.output.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    
                    if trimmed.hasPrefix("Volume Name:") {
                        name = trimmed.replacingOccurrences(of: "Volume Name:", with: "").trimmingCharacters(in: .whitespaces)
                        if name == "-" || name.isEmpty {
                            name = "Partition \(partitionId)"
                        }
                    } else if trimmed.hasPrefix("Disk Size:") {
                        let sizeStr = trimmed.replacingOccurrences(of: "Disk Size:", with: "").trimmingCharacters(in: .whitespaces)
                        let components = sizeStr.components(separatedBy: " ")
                        if components.count >= 2 {
                            size = "\(components[0]) \(components[1])"
                        }
                    } else if trimmed.hasPrefix("Type (Bundle):") {
                        type = trimmed.replacingOccurrences(of: "Type (Bundle):", with: "").trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("Mount Point:") {
                        let mp = trimmed.replacingOccurrences(of: "Mount Point:", with: "").trimmingCharacters(in: .whitespaces)
                        if mp != "(Not Mounted)" && !mp.isEmpty {
                            mountPoint = mp
                        }
                    }
                }
                
                let isEFI = type.contains("EFI") || partitionId.hasSuffix("s1") || type.contains("FAT")
                
                partitions.append(PartitionInfo(
                    name: name,
                    identifier: partitionId,
                    size: size,
                    type: type,
                    mountPoint: mountPoint,
                    isEFI: isEFI
                ))
            }
        }
    }
    
    print("Found \(partitions.count) mountable partitions")
    return partitions
}

// MARK: - Enhanced Drive Detection
static func getAllDrives() -> [DriveInfo] {
    print("=== Getting all drives ===")
    
    var drives: [DriveInfo] = []
    
    // Get diskutil list output
    let listResult = runCommand("diskutil list")
    
    if listResult.success {
        // Parse plain text output
        drives = parseDiskUtilTextOutput(listResult.output)
    }
    
    // If no drives found, try alternative method
    if drives.isEmpty {
        print("No drives found with diskutil, trying alternative method...")
        drives = getDrivesAlternative()
    }
    
    // Sort drives: USB/external first
    drives.sort { drive1, drive2 in
        if !drive1.isInternal && drive2.isInternal {
            return true  // USB before internal
        } else if drive1.isInternal && !drive2.isInternal {
            return false
        }
        return drive1.identifier < drive2.identifier
    }
    
    print("Found \(drives.count) drives")
    return drives
}

private static func parseDiskUtilTextOutput(_ output: String) -> [DriveInfo] {
    var drives: [DriveInfo] = []
    let lines = output.components(separatedBy: "\n")
    
    var currentDisk: (identifier: String, name: String, size: String, isExternal: Bool) = ("", "Unknown", "Unknown", false)
    var currentPartitions: [PartitionInfo] = []
    var inDiskSection = false
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Look for disk header (e.g., "/dev/disk0 (internal, physical):")
        if trimmedLine.hasPrefix("/dev/disk") && trimmedLine.contains(":") {
            // Save previous disk if exists
            if !currentDisk.identifier.isEmpty {
                let isInternal = !currentDisk.isExternal
                drives.append(DriveInfo(
                    name: currentDisk.name.isEmpty ? "Disk \(currentDisk.identifier)" : currentDisk.name,
                    identifier: currentDisk.identifier,
                    size: currentDisk.size,
                    type: currentDisk.isExternal ? "USB Drive" : "Internal Disk",
                    mountPoint: "",
                    isInternal: isInternal,
                    isEFI: false,
                    partitions: currentPartitions
                ))
                currentPartitions = []
            }
            
            // Parse new disk
            let components = trimmedLine.components(separatedBy: ":")
            if components.count >= 1 {
                let diskPart = components[0].trimmingCharacters(in: .whitespaces)
                // Extract disk identifier (e.g., "disk0" from "/dev/disk0")
                if let diskRange = diskPart.range(of: "disk") {
                    let startIndex = diskPart.index(diskRange.lowerBound, offsetBy: 0)
                    var endIndex = diskPart.index(startIndex, offsetBy: 4) // "disk"
                    while endIndex < diskPart.endIndex && diskPart[endIndex].isNumber {
                        endIndex = diskPart.index(endIndex, offsetBy: 1)
                    }
                    currentDisk.identifier = String(diskPart[startIndex..<endIndex])
                }
                
                // Check if it's external/USB
                currentDisk.isExternal = trimmedLine.lowercased().contains("external") || 
                                       trimmedLine.lowercased().contains("usb") ||
                                       trimmedLine.lowercased().contains("removable")
                
                // Try to extract size
                if let starRange = trimmedLine.range(of: "*") {
                    let afterStar = trimmedLine[starRange.upperBound...]
                    let sizeComponents = afterStar.components(separatedBy: ",")
                    if !sizeComponents.isEmpty {
                        currentDisk.size = sizeComponents[0].trimmingCharacters(in: .whitespaces)
                    }
                }
                
                // Extract name from description
                if components.count >= 2 {
                    let description = components[1].trimmingCharacters(in: .whitespaces)
                    if !description.isEmpty {
                        let nameParts = description.components(separatedBy: ",")
                        if !nameParts.isEmpty {
                            currentDisk.name = nameParts[0].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
                
                // If no name extracted, try to get it from disk info
                if currentDisk.name == "Unknown" {
                    let infoResult = runCommand("diskutil info /dev/\(currentDisk.identifier) | grep 'Volume Name' | head -1")
                    if infoResult.success {
                        let info = infoResult.output
                        if let colonRange = info.range(of: ":") {
                            let name = info[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
                            if name != "-" && !name.isEmpty {
                                currentDisk.name = name
                            }
                        }
                    }
                }
            }
            inDiskSection = true
        }
        // Look for partitions (lines starting with numbers like "0:", "1:", etc.)
        else if inDiskSection && trimmedLine.range(of: "^\\s*\\d+:\\s", options: .regularExpression) != nil {
            // Parse partition info
            let components = trimmedLine.components(separatedBy: " ")
                .filter { !$0.isEmpty }
            
            if components.count >= 5 {
                let partNumber = components[0].replacingOccurrences(of: ":", with: "")
                let partIdentifier = "\(currentDisk.identifier)s\(partNumber)"
                var partName = components[2]
                let partSize = "\(components[3]) \(components[4])"
                let partType = components.dropFirst(5).joined(separator: " ")
                let isEFI = partType.contains("EFI") || 
                           partIdentifier.hasSuffix("s1") || 
                           partName.contains("EFI") ||
                           partType.contains("FAT")
                
                // Clean up partition name
                if partName == "-" || partName.isEmpty {
                    partName = "Partition \(partNumber)"
                }
                
                // Get mount point
                var mountPoint = ""
                let mountCheck = runCommand("""
                diskutil info /dev/\(partIdentifier) 2>/dev/null | \
                grep "Mount Point" | \
                awk -F': ' '{print $2}' | \
                xargs
                """)
                
                if mountCheck.success {
                    mountPoint = mountCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if mountPoint == "(Not Mounted)" {
                        mountPoint = ""
                    }
                }
                
                currentPartitions.append(PartitionInfo(
                    name: partName,
                    identifier: partIdentifier,
                    size: partSize,
                    type: partType,
                    mountPoint: mountPoint,
                    isEFI: isEFI
                ))
            }
        }
        // Empty line ends disk section
        else if trimmedLine.isEmpty && inDiskSection {
            inDiskSection = false
        }
    }
    
    // Add the last disk
    if !currentDisk.identifier.isEmpty {
        let isInternal = !currentDisk.isExternal
        drives.append(DriveInfo(
            name: currentDisk.name.isEmpty ? "Disk \(currentDisk.identifier)" : currentDisk.name,
            identifier: currentDisk.identifier,
            size: currentDisk.size,
            type: currentDisk.isExternal ? "USB Drive" : "Internal Disk",
            mountPoint: "",
            isInternal: isInternal,
            isEFI: false,
            partitions: currentPartitions
        ))
    }
    
    return drives
}

private static func getDrivesAlternative() -> [DriveInfo] {
    var drives: [DriveInfo] = []
    
    // Try using system_profiler
    let spResult = runCommand("""
    system_profiler SPSerialATADataType SPUSBDataType 2>/dev/null | \
    grep -E "BSD Name:|Capacity:|Protocol:" | \
    grep -A2 -B1 "BSD Name:"
    """)
    
    if spResult.success {
        let lines = spResult.output.components(separatedBy: "\n")
        var currentDrive: (name: String, identifier: String?, size: String?, type: String?) = ("Unknown", nil, nil, nil)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("BSD Name:") {
                if let id = trimmed.components(separatedBy: ": ").last, 
                   id.hasPrefix("disk") {
                    currentDrive.identifier = id
                }
            } else if trimmed.hasPrefix("Capacity:") {
                currentDrive.size = trimmed.components(separatedBy: ": ").last
            } else if trimmed.hasPrefix("Protocol:") {
                currentDrive.type = trimmed.components(separatedBy: ": ").last
                
                // If we have all info, create a drive
                if let identifier = currentDrive.identifier {
                    let isExternal = currentDrive.type?.contains("USB") ?? false
                    let drive = DriveInfo(
                        name: "Disk \(identifier)",
                        identifier: identifier,
                        size: currentDrive.size ?? "Unknown",
                        type: isExternal ? "USB Drive" : "Internal Disk",
                        mountPoint: "",
                        isInternal: !isExternal,
                        isEFI: false,
                        partitions: []
                    )
                    drives.append(drive)
                    currentDrive = ("Unknown", nil, nil, nil)
                }
            }
        }
    }
    
    // Fallback: try to find any disks
    if drives.isEmpty {
        let diskCheck = runCommand("ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$' | head -10")
        if diskCheck.success {
            let diskPaths = diskCheck.output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { $0.replacingOccurrences(of: "/dev/", with: "") }
            
            for disk in diskPaths {
                let isExternal = disk.contains("external") || disk.contains("usb")
                let drive = DriveInfo(
                    name: "Disk \(disk)",
                    identifier: disk,
                    size: "Unknown",
                    type: isExternal ? "USB Drive" : "Internal Disk",
                    mountPoint: "",
                    isInternal: !isExternal,
                    isEFI: false,
                    partitions: []
                )
                drives.append(drive)
            }
        }
    }
    
    return drives
}

private static func getPartitionsForDisk(_ disk: String) -> [PartitionInfo] {
    var partitions: [PartitionInfo] = []
    
    // List partitions on this disk
    let listResult = runCommand("diskutil list /dev/\(disk)")
    
    if listResult.success {
        let lines = listResult.output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Look for partition lines (starting with numbers like "0:", "1:", etc.)
            if trimmed.range(of: "^\\d+:\\s", options: .regularExpression) != nil {
                let components = trimmed.components(separatedBy: " ")
                    .filter { !$0.isEmpty }
                
                if components.count >= 5 {
                    let partNumber = components[0].replacingOccurrences(of: ":", with: "")
                    let partIdentifier = "\(disk)s\(partNumber)"
                    var partName = components[2]
                    let partSize = "\(components[3]) \(components[4])"
                    let partType = components.dropFirst(5).joined(separator: " ")
                    let isEFI = partType.contains("EFI") || 
                               partIdentifier.hasSuffix("s1") || 
                               partName.contains("EFI") ||
                               partType.contains("FAT")
                    
                    if partName == "-" || partName.isEmpty {
                        partName = "Partition \(partNumber)"
                    }
                    
                    // Get mount point
                    var mountPoint = ""
                    let mountCheck = runCommand("""
                    diskutil info /dev/\(partIdentifier) 2>/dev/null | \
                    grep "Mount Point" | \
                    awk -F': ' '{print $2}' | \
                    xargs
                    """)
                    
                    if mountCheck.success {
                        mountPoint = mountCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if mountPoint == "(Not Mounted)" {
                            mountPoint = ""
                        }
                    }
                    
                    partitions.append(PartitionInfo(
                        name: partName,
                        identifier: partIdentifier,
                        size: partSize,
                        type: partType,
                        mountPoint: mountPoint,
                        isEFI: isEFI
                    ))
                }
            }
        }
    }
    
    return partitions
}

// MARK: - System Information
static func isSIPDisabled() -> Bool {
    let result = runCommand("csrutil status 2>/dev/null || echo 'Unknown'")
    let output = result.output.lowercased()
    return output.contains("disabled")
}

static func checkKextLoaded(_ kextName: String) -> Bool {
    let result = runCommand("kextstat | grep -i '\(kextName)'")
    return result.success && !result.output.isEmpty
}

static func getKextVersion(_ kextName: String) -> String? {
    let result = runCommand("kextstat | grep -i '\(kextName)' | awk '{print $6}'")
    if result.success {
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }
    return nil
}

static func getCompleteSystemInfo() -> SystemInfo {
    var info = SystemInfo()
    
    // Get basic system info
    let versionResult = runCommand("sw_vers -productVersion 2>/dev/null || echo 'Unknown'")
    info.macOSVersion = versionResult.success ? versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
    
    let buildResult = runCommand("sw_vers -buildVersion 2>/dev/null || echo 'Unknown'")
    info.buildNumber = buildResult.success ? buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
    
    let kernelResult = runCommand("uname -r 2>/dev/null || echo 'Unknown'")
    info.kernelVersion = kernelResult.success ? kernelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
    
    let modelResult = runCommand("sysctl -n hw.model 2>/dev/null || echo 'Unknown'")
    info.modelIdentifier = modelResult.success ? modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
    
    let cpuResult = runCommand("sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown'")
    info.processor = cpuResult.success ? cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
    
    let memResult = runCommand("sysctl -n hw.memsize 2>/dev/null")
    if memResult.success, let bytes = Int64(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
        let gb = Double(bytes) / 1_073_741_824
        info.memory = String(format: "%.0f GB", gb)
    } else {
        info.memory = "Unknown"
    }
    
    // Check boot mode
    let usbDrives = findUSBDrives()
    let bootDrive = runCommand("""
    diskutil info / | grep "Part of Whole" | awk '{print $NF}'
    """)
    
    if bootDrive.success, let bootDisk = bootDrive.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
        let isUSB = usbDrives.contains(bootDisk)
        info.bootMode = isUSB ? "USB Boot" : "Internal Boot"
    } else {
        info.bootMode = usbDrives.isEmpty ? "Internal Boot" : "Unknown"
    }
    
    return info
}

static func getCompleteDiagnostics() -> String {
    var diagnostics = "=== SystemMaintenance Complete Diagnostics Report ===\n"
    
    // Create a date formatter for the timestamp
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .full
    dateFormatter.timeStyle = .full
    diagnostics += "Generated: \(dateFormatter.string(from: Date()))\n\n"
    
    // Get complete system info
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
        diagnostics += "  EFI: \(drive.isEFI)\n"
        if !drive.partitions.isEmpty {
            diagnostics += "  Partitions:\n"
            for partition in drive.partitions {
                diagnostics += "    - \(partition.name) (\(partition.identifier)): \(partition.size) [\(partition.type)]\n"
            }
        }
        diagnostics += "\n"
    }
    
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
    
    // EFI Status
    diagnostics += "\n--- EFI Status ---\n"
    if let efiPath = getEFIPath() {
        diagnostics += "Mounted: Yes\n"
        diagnostics += "Path: \(efiPath)\n"
    } else {
        diagnostics += "Mounted: No\n"
    }
    
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
    
    init(title: String, status: String, version: String?, detail: String?, statusColor: Color) {
        self.title = title
        self.status = status
        self.version = version
        self.detail = detail
        self.statusColor = statusColor
    }
    
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

// MARK: - Main Content View
@MainActor
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
    @State private var showAllDrives = false
    @State private var searchText = ""
    
    // Filtered drives based on search
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
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                // System Maintenance Tab
                systemMaintenanceView
                    .tabItem {
                        Label("System", systemImage: "gear")
                    }
                    .tag(0)
                
                // Kext Management Tab
                kextManagementView
                    .tabItem {
                        Label("Kexts", systemImage: "puzzlepiece.extension")
                    }
                    .tag(1)
                
                // System Info Tab
                systemInfoView
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDonationSheet) {
            donationView
        }
        .sheet(isPresented: $showEFISelectionView) {
            efiSelectionView
        }
        .sheet(isPresented: $showDiskDetailView) {
            if let drive = selectedDrive {
                diskDetailView(drive: drive)
            }
        }
        .sheet(isPresented: $showExportView) {
            exportSystemInfoView
        }
        .onAppear {
            checkSystemStatus()
            loadAllDrives()
            
            // Direct check for specific EFI paths first
            let commonPaths = ["/Volumes/EFI", "/Volumes/EFI 1", "/Volumes/EFI 2", "/Volumes/EFI_1"]
            for path in commonPaths {
                if FileManager.default.fileExists(atPath: path) {
                    efiPath = path
                    print("Found EFI at: \(path)")
                    break
                }
            }
            
            // If not found, try the regular check
            if efiPath == nil {
                checkEFIMount()
            }
            
            loadSystemInfo()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
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
                // System Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(internalDrives.count) Internal • \(externalDrives.count) External")
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
                
                // Export Button
                Button(action: {
                    showExportView = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Export System Information")
                
                // Donate Button
                Button(action: {
                    showDonationSheet = true
                }) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Support Development")
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
    
    // MARK: - System Maintenance View
    private var systemMaintenanceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // USB Boot Banner
                usbBootBanner
                
                // Warning Banner
                warningBanner
                
                // Drives Overview
                drivesOverviewSection
                
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
    }
    
    private var usbBootBanner: some View {
        HStack {
            Image(systemName: "externaldrive.fill.badge.plus")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("USB Boot Mode")
                    .font(.headline)
                Text("Enhanced USB EFI mounting support")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Refresh Status") {
                checkSystemStatus()
                loadAllDrives()
                checkEFIMount()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
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
                
                Button(action: loadAllDrives) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingDrives)
                
                Button(action: {
                    // Force USB detection
                    let usbDrives = ShellHelper.findUSBDrives()
                    alertTitle = "USB Detection"
                    if usbDrives.isEmpty {
                        alertMessage = "No USB drives found.\n\nPlease ensure USB drive is connected and try:\n1. Unplug and replug USB drive\n2. Try different USB port\n3. Check System Information tab for more details"
                    } else {
                        alertMessage = "Found \(usbDrives.count) USB drive(s): \(usbDrives.joined(separator: ", "))"
                    }
                    showAlert = true
                }) {
                    Label("USB Check", systemImage: "externaldrive")
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
                // USB/External Drives First
                if !externalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("USB/External Drives", systemImage: "externaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(externalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                                showDiskDetailView = true
                            }
                        }
                        
                        if externalDrives.count > 3 {
                            Text("+ \(externalDrives.count - 3) more external drives")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                } else {
                    // Show no USB drives message
                    VStack {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("No USB/External Drives Found")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("Connect a USB drive to see it here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Internal Drives
                if !internalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Internal Drives", systemImage: "internaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        ForEach(internalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                                showDiskDetailView = true
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
                
                if filteredDrives.isEmpty {
                    VStack {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No drives found")
                            .foregroundColor(.secondary)
                        Text("Try refreshing or checking system logs")
                            .font(.caption)
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
                    let efiPartitions = allDrives.flatMap { $0.partitions }.filter { $0.isEFI }
                    
                    if efiPartitions.isEmpty {
                        Text("No EFI partitions found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(efiPartitions) { partition in
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
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Mount USB EFI") {
                            mountUSBEFI()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMountingPartition)
                        
                        Button("Manual Mount") {
                            mountEFI()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Select EFI") {
                            showEFISelectionView = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Debug") {
                            debugEFIDetection()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .foregroundColor(.gray)
                    }
                }
            }
            
            if !allDrives.isEmpty {
                let efiCount = allDrives.flatMap { $0.partitions }.filter { $0.isEFI }.count
                Text("Found \(efiCount) EFI partition(s) across \(allDrives.count) drive(s)")
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
    
    private var maintenanceGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MaintenanceButton(
                title: "Mount USB EFI",
                icon: "externaldrive.badge.plus",
                color: .orange,
                isLoading: isMountingPartition,
                action: mountUSBEFI
            )
            
            MaintenanceButton(
                title: "Manual Mount EFI",
                icon: "cylinder.fill",
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
                isLoading: false,
                action: checkEFIStructure
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
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func efiStatusSection(efiPath: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .foregroundColor(.green)
                Text("EFI Partition Mounted")
                    .font(.headline)
            }
            
            HStack {
                Text("Path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(efiPath)
                    .font(.system(.caption, design: .monospaced))
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
                Button("Check Structure") {
                    checkEFIStructure()
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
    
    // MARK: - Kext Management View
    private var kextManagementView: some View {
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
                    Text("Kext Source Selection")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Selection:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if kextSourcePath.isEmpty {
                                Text("No folder selected")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .italic()
                            } else {
                                Text(URL(fileURLWithPath: kextSourcePath).lastPathComponent)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(kextSourcePath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Browse for Folder") {
                                browseForKextFolder()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Browse for Kext File") {
                                browseForKextFile()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Text("Select a folder containing kexts OR select a specific .kext file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: rebuildCaches) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Rebuild Cache")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: fixPermissions) {
                            HStack {
                                Image(systemName: "lock.shield")
                                Text("Fix Permissions")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - System Info View
    private var systemInfoView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showExportView = true
                    }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        loadSystemInfo()
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
                
                // System Info Grid
                VStack(spacing: 16) {
                    Text("System Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        infoCard(title: "macOS Version", value: systemInfo.macOSVersion)
                        infoCard(title: "Build Number", value: systemInfo.buildNumber)
                        infoCard(title: "Kernel Version", value: systemInfo.kernelVersion)
                        infoCard(title: "Model Identifier", value: systemInfo.modelIdentifier)
                        infoCard(title: "Processor", value: systemInfo.processor)
                        infoCard(title: "Memory", value: systemInfo.memory)
                        infoCard(title: "Boot Mode", value: systemInfo.bootMode)
                        infoCard(title: "SIP Status", value: ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
                        infoCard(title: "EFI Status", value: efiPath != nil ? "Mounted ✓" : "Not Mounted ✗")
                        infoCard(title: "Audio Status", value: getAudioStatus())
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drives Summary
                if !allDrives.isEmpty {
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
                        
                        // Drive Details
                        ForEach(allDrives) { drive in
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
                                        
                                        ForEach(drive.partitions) { partition in
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
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
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
    
    private func infoCard(title: String, value: String) -> some View {
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
    
    private func getAudioStatus() -> String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working ✓"
        } else {
            return "Setup Required ⚠️"
        }
    }
    
    // MARK: - Other Views
    private var donationView: some View {
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
                    donationReason(text: "Fund testing hardware for new macOS versions")
                    donationReason(text: "Cover server costs for updates and downloads")
                    donationReason(text: "Support continued open-source development")
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            
            // Donation Button
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                        NSWorkspace.shared.open(url)
                    }
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
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("All donations go directly to development")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Button("Close") {
                        showDonationSheet = false
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
        .frame(width: 500, height: 400)
    }
    
    private func donationReason(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
    
    private var efiSelectionView: some View {
        VStack(spacing: 20) {
            Text("Select EFI Partition to Mount")
                .font(.headline)
                .padding(.top)
            
            Text("Enhanced USB detection - will find disk9s1 (your USB EFI)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Auto-Mount USB EFI (Recommended)") {
                    mountUSBEFI()
                    showEFISelectionView = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("Mount Any EFI") {
                    mountEFI()
                    showEFISelectionView = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Check Current EFI") {
                    checkCurrentEFI()
                    showEFISelectionView = false
                }
                .buttonStyle(.bordered)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button("Cancel") {
                showEFISelectionView = false
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
        .frame(width: 400, height: 300)
    }
    
    private func diskDetailView(drive: DriveInfo) -> some View {
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
                    showDiskDetailView = false
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
                    VStack(spacing: 8) {
                        Button(action: {
                            mountSelectedDrive()
                        }) {
                            HStack {
                                Image(systemName: "externaldrive.fill.badge.plus")
                                Text("Mount This Drive")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            loadAllDrives()
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
    }
    
    private var exportSystemInfoView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    showExportView = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Diagnostics Report")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    Text("This report contains system information, drive details, and EFI status useful for troubleshooting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Report Preview
                    ScrollView {
                        Text(ShellHelper.getCompleteDiagnostics())
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                    
                    // Export Buttons
                    VStack(spacing: 12) {
                        Button(action: exportToFile) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Export to File")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
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
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Action Functions
    
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
                
                // Show notification if no drives found
                if drives.isEmpty {
                    alertTitle = "Drive Detection"
                    alertMessage = "No drives found. This could be due to:\n\n1. Permission issues\n2. Disk utility not responding\n3. No storage devices connected\n\nTry running in Terminal: diskutil list"
                    showAlert = true
                }
            }
        }
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            let path = ShellHelper.getEFIPath()
            DispatchQueue.main.async {
                efiPath = path
                if path == nil {
                    print("No EFI currently mounted")
                }
            }
        }
    }
    
    private func loadSystemInfo() {
        DispatchQueue.global(qos: .background).async {
            let info = ShellHelper.getCompleteSystemInfo()
            DispatchQueue.main.async {
                systemInfo = info
            }
        }
    }
    
    private func mountUSBEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.mountUSBEFI()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = result.path
                
                if result.success {
                    alertTitle = "USB EFI Mounted"
                    alertMessage = "USB EFI partition mounted successfully!"
                    if let path = result.path {
                        alertMessage += "\n\nLocation: \(path)"
                    }
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount USB EFI partition.
                    
                    Possible reasons:
                    1. No USB drive connected
                    2. USB drive doesn't have EFI partition
                    3. Permission issues
                    4. USB drive not properly formatted
                    
                    Try:
                    • Connect a USB drive with EFI partition
                    • Use "Manual Mount EFI" instead
                    • Check if USB is detected in System Information tab
                    """
                }
                showAlert = true
            }
        }
    }
    
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountEFIPartition()
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success {
                    alertTitle = "EFI Mounted"
                    alertMessage = "EFI partition mounted successfully!"
                    if let path = path {
                        alertMessage += "\n\nLocation: \(path)"
                    }
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount any EFI partition.
                    
                    Try manually in Terminal:
                    sudo diskutil mount diskXsY
                    
                    Where X is disk number and Y is partition number.
                    Common USB EFI: disk9s1
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
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it first."
            showAlert = true
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Checking EFI structure at: \(efiPath)"]
            
            // Check directories
            let dirs = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers", "EFI/OC/Tools"]
            
            for dir in dirs {
                let fullPath = "\(efiPath)/\(dir)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                messages.append("\(exists ? "✅" : "❌") \(dir)")
            }
            
            // Check for common files
            let commonFiles = ["EFI/OC/config.plist", "EFI/BOOT/BOOTx64.efi"]
            for file in commonFiles {
                let fullPath = "\(efiPath)/\(file)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                if exists {
                    messages.append("✅ Found: \(file)")
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Structure Check"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func debugEFIDetection() {
        print("=== DEBUG EFI DETECTION ===")
        
        // Run various checks
        let checks = [
            "Check mounted volumes": "mount | grep -E 'msdos|fat32|EFI'",
            "List /Volumes": "ls -la /Volumes/",
            "Check disk9s1 specifically": "diskutil info /dev/disk9s1 | grep -E 'Mount Point|Type Name'",
            "Find EFI folders": "find /Volumes -name 'EFI' -type d 2>/dev/null",
            "Check diskutil list for EFI": "diskutil list | grep -B2 -A2 'EFI'"
        ]
        
        var results = "=== EFI Detection Debug ===\n\n"
        
        for (name, command) in checks {
            let result = ShellHelper.runCommand(command)
            results += "\(name):\n\(result.output)\n---\n"
        }
        
        alertTitle = "EFI Debug Info"
        alertMessage = results
        showAlert = true
        
        // Also print to console
        print(results)
    }
    
    private func checkCurrentEFI() {
        // Check common paths first
        let commonPaths = ["/Volumes/EFI", "/Volumes/EFI 1", "/Volumes/EFI 2", "/Volumes/EFI_1"]
        var foundPath: String?
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPath = path
                break
            }
        }
        
        if let path = foundPath {
            efiPath = path
            alertTitle = "EFI Found!"
            alertMessage = "EFI partition found at:\n\(path)"
        } else {
            // Try the shell helper
            checkEFIMount()
            
            if let path = efiPath {
                alertTitle = "EFI Found!"
                alertMessage = "EFI partition found at:\n\(path)"
            } else {
                alertTitle = "EFI Not Found"
                alertMessage = "No EFI partition is currently mounted.\n\nTry mounting USB EFI from the System tab."
            }
        }
        showAlert = true
    }
    
    private func mountSelectedDrive() {
        guard let drive = selectedDrive else { return }
        
        // Get the main partition (usually s1 or s2)
        let partition: String
        if let efiPartition = drive.partitions.first(where: { $0.isEFI }) {
            partition = efiPartition.identifier
        } else if let firstPartition = drive.partitions.first {
            partition = firstPartition.identifier
        } else {
            // If no partitions, try the disk itself
            partition = drive.identifier
        }
        
        let result = ShellHelper.mountDrive(identifier: partition)
        
        if result.success {
            alertTitle = "Drive Mounted"
            alertMessage = "Successfully mounted \(partition)"
            if let mountPoint = result.mountPoint {
                alertMessage += "\n\nMounted at: \(mountPoint)"
                
                // Update the drive info
                loadAllDrives()
            }
        } else {
            alertTitle = "Mount Failed"
            alertMessage = """
            Failed to mount \(partition)
            
            Try manually in Terminal:
            sudo diskutil mount \(partition)
            
            Common USB EFI: disk9s1
            """
        }
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
    
    private func browseForKextFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Kexts Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                kextSourcePath = url.path
                alertTitle = "Folder Selected"
                alertMessage = "Selected folder: \(url.lastPathComponent)"
                showAlert = true
            }
        }
    }
    
    private func browseForKextFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Kext File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [UTType.item]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if url.pathExtension.lowercased() == "kext" {
                    kextSourcePath = url.path
                    alertTitle = "Kext Selected"
                    alertMessage = "Selected kext file: \(url.lastPathComponent)"
                } else {
                    alertTitle = "Invalid File"
                    alertMessage = "Please select a .kext file. Selected file: \(url.lastPathComponent) has extension: \(url.pathExtension)"
                }
                showAlert = true
            }
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
            alertMessage = "Please select a folder containing kext files or a kext file first."
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
            
            // Check if source is a file or directory
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
            
            if !exists {
                DispatchQueue.main.async {
                    isInstallingKext = false
                    alertTitle = "Error"
                    alertMessage = "Selected path does not exist: \(kextSourcePath)"
                    showAlert = true
                }
                return
            }
            
            if isDirectory.boolValue {
                // Source is a directory
                messages.append("\nSearching for kexts in folder...")
                
                // Look for kexts
                let kexts = findKextsInDirectory(kextSourcePath)
                
                for kext in kexts {
                    let kextName = URL(fileURLWithPath: kext).lastPathComponent
                    messages.append("\nInstalling \(kextName)...")
                    
                    if kextName.lowercased().contains("applehda") {
                        // Install AppleHDA to /System/Library/Extensions
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(kext)\" \"/System/Library/Extensions/AppleHDA.kext\"",
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
                            appleHDAStatus = "Installed"
                        } else {
                            success = false
                        }
                    } else {
                        // Install other kexts to EFI
                        let command = "cp -R \"\(kext)\" \"\(ocKextsPath)\(kextName)\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        
                        if result.success {
                            messages.append("✅ \(kextName) installed to EFI")
                            
                            // Update status for known kexts
                            if kextName.lowercased().contains("lilu") {
                                liluStatus = "Installed"
                            } else if kextName.lowercased().contains("applealc") {
                                appleALCStatus = "Installed"
                            }
                        } else {
                            messages.append("❌ Failed to install \(kextName)")
                            success = false
                        }
                    }
                }
            } else {
                // Source is a file
                if kextSourcePath.hasSuffix(".kext") {
                    let kextName = URL(fileURLWithPath: kextSourcePath).lastPathComponent
                    messages.append("\nInstalling \(kextName)...")
                    
                    if kextName.lowercased().contains("applehda") {
                        // Install AppleHDA to /System/Library/Extensions
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(kextSourcePath)\" \"/System/Library/Extensions/AppleHDA.kext\"",
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
                            appleHDAStatus = "Installed"
                        } else {
                            success = false
                        }
                    } else {
                        // Install other kexts to EFI
                        let command = "cp -R \"\(kextSourcePath)\" \"\(ocKextsPath)\(kextName)\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        
                        if result.success {
                            messages.append("✅ \(kextName) installed to EFI")
                            
                            // Update status for known kexts
                            if kextName.lowercased().contains("lilu") {
                                liluStatus = "Installed"
                            } else if kextName.lowercased().contains("applealc") {
                                appleALCStatus = "Installed"
                            }
                        } else {
                            messages.append("❌ Failed to install \(kextName)")
                            success = false
                        }
                    }
                } else {
                    messages.append("❌ Selected file is not a .kext file")
                    success = false
                }
            }
            
            // Rebuild kernel cache
            if success {
                messages.append("\nRebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues: \(result.output)")
                }
            }
            
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    alertTitle = "✅ Installation Complete"
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
    
    private func findKextsInDirectory(_ directory: String) -> [String] {
        var kexts: [String] = []
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue && item.hasSuffix(".kext") {
                        kexts.append(itemPath)
                    }
                }
            }
        } catch {
            print("Error reading directory: \(error)")
        }
        
        return kexts
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
    
    private func rebuildCaches() {
        rebuildCache()
    }
    
    private func exportToFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export System Information"
        savePanel.nameFieldLabel = "Export As:"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "SystemMaintenance_Report_\(timestamp).txt"
        savePanel.nameFieldStringValue = fileName
        
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let content = ShellHelper.getCompleteDiagnostics()
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    
                    alertTitle = "Export Successful"
                    alertMessage = "Report exported to:\n\(url.lastPathComponent)"
                    showAlert = true
                    
                    // Open the containing folder
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    alertTitle = "Export Failed"
                    alertMessage = "Failed to export: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let content = ShellHelper.getCompleteDiagnostics()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        alertTitle = "Copied"
        alertMessage = "Diagnostics report copied to clipboard!"
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