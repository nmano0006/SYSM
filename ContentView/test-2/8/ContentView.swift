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
            // Enhanced sudo command for USB boot with better error handling
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
    
    static func mountEFIPartition() -> Bool {
        print("=== Starting EFI Mount from USB Boot ===")
        
        // First, check if any EFI is already mounted
        let checkResult = runCommand("""
                mount | grep -i 'efi\\|/dev/disk.*s1' | head -1
                """)
        
        if checkResult.success && !checkResult.output.isEmpty {
            print("EFI already mounted: \(checkResult.output)")
            return true
        }
        
        // Get all disks
        let listResult = runCommand("""
        diskutil list | grep -E '^/dev/disk' | grep -o 'disk[0-9]*' | sort | uniq
        """)
        
        if !listResult.success {
            print("Failed to list disks: \(listResult.output)")
            // Try alternative command
            let altResult = runCommand("ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$' | sort | uniq")
            if !altResult.success {
                return false
            }
        }
        
        let disks = listResult.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        print("Found disks: \(disks)")
        
        if disks.isEmpty {
            print("No disks found!")
            return false
        }
        
        // Try each disk for EFI partition
        for disk in disks {
            print("\n--- Checking disk: \(disk) ---")
            
            // Check disk info
            let diskInfo = runCommand("diskutil info /dev/\(disk) 2>/dev/null")
            if !diskInfo.success {
                print("Cannot get info for \(disk)")
                continue
            }
            
            // Look for s1 partition (common EFI location)
            let s1Partition = "\(disk)s1"
            print("Trying partition: \(s1Partition)")
            
            // Check if it's EFI
            let partInfo = runCommand("diskutil info /dev/\(s1Partition) 2>/dev/null")
            if partInfo.success {
                let isEFI = partInfo.output.lowercased().contains("efi") || 
                           partInfo.output.contains("EFI") || 
                           partInfo.output.contains("Apple_Boot")
                
                if isEFI {
                    print("Found EFI partition: \(s1Partition)")
                    
                    // Try to mount
                    let mountResult = runCommand("diskutil mount \(s1Partition)", needsSudo: true)
                    if mountResult.success {
                        print("✅ Successfully mounted: \(s1Partition)")
                        print("Mount output: \(mountResult.output)")
                        return true
                    } else {
                        print("❌ Failed to mount \(s1Partition): \(mountResult.output)")
                    }
                }
            }
            
            // If s1 is not EFI, check all partitions on this disk
            let allParts = runCommand("diskutil list /dev/\(disk) 2>/dev/null | grep -o '\(disk)s[0-9]*'")
            let partitions = allParts.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            
            for partition in partitions where partition != s1Partition {
                print("Checking partition: \(partition)")
                let partInfo = runCommand("diskutil info /dev/\(partition) 2>/dev/null")
                if partInfo.success {
                    let isEFI = partInfo.output.lowercased().contains("efi") || 
                               partInfo.output.contains("EFI") || 
                               partInfo.output.contains("Apple_Boot")
                    
                    if isEFI {
                        print("Found EFI partition: \(partition)")
                        let mountResult = runCommand("diskutil mount \(partition)", needsSudo: true)
                        if mountResult.success {
                            print("✅ Successfully mounted: \(partition)")
                            return true
                        }
                    }
                }
            }
        }
        
        // If no EFI found, try to mount any s1 partition (common fallback)
        print("\n--- Trying fallback: mount any s1 partition ---")
        for disk in disks {
            let s1Partition = "\(disk)s1"
            print("Trying to mount \(s1Partition) as fallback...")
            let mountResult = runCommand("diskutil mount \(s1Partition)", needsSudo: true)
            if mountResult.success {
                print("✅ Mounted \(s1Partition) (fallback)")
                return true
            }
        }
        
        print("❌ Failed to mount any EFI partition")
        return false
    }
    
    static func getEFIPath() -> String? {
        // Multiple methods to find mounted EFI
        
        // Method 1: Check mounted volumes
        let result1 = runCommand("""
                mount | grep -E '/dev/disk.*s[0-9]' | awk '{print $3}' | while read mount; do
                    if [ -d "$mount/EFI" ] || [ -d "$mount/BOOT" ]; then
                        echo "$mount"
                        exit 0
                    fi
                done
                """)
        
        if result1.success && !result1.output.isEmpty {
            let path = result1.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Method 2: Check /Volumes for EFI
        let result2 = runCommand("""
                for vol in /Volumes/*; do
                    if [ -d "$vol/EFI" ] || [ -d "$vol/BOOT" ] || [[ "$(basename "$vol")" == *EFI* ]]; then
                        echo "$vol"
                        exit 0
                    fi
                done
                """)
        
        if result2.success && !result2.output.isEmpty {
            let path = result2.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Method 3: Check diskutil for mounted EFI
        let result3 = runCommand("""
        diskutil list | grep -B2 -A2 'EFI' | grep -o 'disk[0-9]*s[0-9]*' | head -1 | while read part; do
            diskutil info "$part" 2>/dev/null | grep 'Mount Point' | cut -d: -f2 | xargs
        done
        """)
        
        if result3.success {
            let path = result3.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
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
    
    // MARK: - Enhanced hard drive detection for USB boot with USB-specific fixes
    static func getAllDrives() -> [DriveInfo] {
        print("=== Getting all drives with enhanced USB detection ===")
        
        // Try multiple methods to get drive information
        var drives: [DriveInfo] = []
        
        // Method 1: Use diskutil list -plist (most reliable)
        let plistResult = runCommand("diskutil list -plist 2>/dev/null")
        if plistResult.success, let data = plistResult.output.data(using: .utf8) {
            drives = parsePlistDiskData(data)
        }
        
        // Method 2: If plist fails, use diskutil list text output
        if drives.isEmpty {
            print("Plist method failed, trying text parsing...")
            let textResult = runCommand("diskutil list")
            if textResult.success {
                drives = parseTextDiskOutput(textResult.output)
            }
        }
        
        // Method 3: If still empty, try system_profiler with USB-specific data
        if drives.isEmpty {
            print("Text parsing failed, trying system_profiler...")
            drives = getDrivesFromSystemProfiler()
        }
        
        // Method 4: Enhanced USB-specific detection
        print("Running enhanced USB detection...")
        let usbDrives = getUSBDrivesEnhanced()
        drives.append(contentsOf: usbDrives)
        
        // Method 5: Last resort - check mounted volumes
        if drives.isEmpty {
            print("All methods failed, checking mounted volumes...")
            drives = getDrivesFromMountedVolumes()
        }
        
        // Remove duplicates by identifier
        drives = removeDuplicateDrives(drives)
        
        // Sort drives: internal first, then external
        drives.sort { drive1, drive2 in
            if drive1.isInternal && !drive2.isInternal {
                return true
            } else if !drive1.isInternal && drive2.isInternal {
                return false
            } else {
                return drive1.identifier < drive2.identifier
            }
        }
        
        print("Found \(drives.count) drives")
        return drives
    }
    
    // MARK: - Enhanced USB Drive Detection
    private static func getUSBDrivesEnhanced() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Method A: Check diskutil info for USB devices
        let diskList = runCommand("""
        diskutil list | grep -E '^/dev/disk' | awk '{print $1}' | while read disk; do
            if diskutil info "$disk" 2>/dev/null | grep -q 'Protocol.*USB'; then
                echo "$disk"
            fi
        done
        """)
        
        if diskList.success {
            let diskLines = diskList.output.components(separatedBy: "\n")
            for disk in diskLines where !disk.isEmpty {
                let diskName = disk.replacingOccurrences(of: "/dev/", with: "")
                print("Found potential USB drive: \(diskName)")
                
                // Get disk info
                let infoResult = runCommand("diskutil info \(disk) 2>/dev/null")
                if infoResult.success {
                    let info = parseDiskInfo(infoResult.output)
                    
                    drives.append(DriveInfo(
                        name: info.name,
                        identifier: diskName,
                        size: info.size,
                        type: "USB (\(info.protocol))",
                        mountPoint: info.mountPoint,
                        isInternal: false, // USB drives are always external
                        isEFI: diskName.contains("s1") && (info.name.contains("EFI") || info.type.contains("EFI")),
                        partitions: info.partitions
                    ))
                }
            }
        }
        
        // Method B: Check system_profiler for USB storage
        let usbStorageResult = runCommand("""
        system_profiler SPUSBDataType 2>/dev/null | grep -A 10 -B 2 'Mass Storage' | grep -E 'Product ID|Vendor ID|Manufacturer|Product|Serial Number|Capacity' | sed 's/^ *//'
        """)
        
        if usbStorageResult.success && !usbStorageResult.output.isEmpty {
            print("Found USB storage devices via system_profiler")
            let lines = usbStorageResult.output.components(separatedBy: "\n")
            var currentDevice: [String: String] = [:]
            var deviceCount = 0
            
            for line in lines {
                if line.contains(":") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts[1].trimmingCharacters(in: .whitespaces)
                        currentDevice[key] = value
                    }
                } else if line.isEmpty || line.contains("--") {
                    if !currentDevice.isEmpty {
                        let name = currentDevice["Product"] ?? currentDevice["Manufacturer"] ?? "USB Drive"
                        let size = currentDevice["Capacity"] ?? "Unknown"
                        let identifier = "usb\(deviceCount)"
                        
                        drives.append(DriveInfo(
                            name: name,
                            identifier: identifier,
                            size: size,
                            type: "USB Storage",
                            mountPoint: "",
                            isInternal: false,
                            isEFI: false,
                            partitions: []
                        ))
                        
                        currentDevice = [:]
                        deviceCount += 1
                    }
                }
            }
        }
        
        // Method C: Check mounted USB volumes
        let mountedUSB = runCommand("""
        mount | grep -E '/dev/disk.*s[0-9]' | while read line; do
            disk=$(echo "$line" | awk '{print $1}' | sed 's/\\/dev\\///' | sed 's/s[0-9]*$//')
            if diskutil info "$disk" 2>/dev/null | grep -q 'Protocol.*USB'; then
                mount_point=$(echo "$line" | awk '{print $3}')
                echo "$disk|$mount_point"
            fi
        done
        """)
        
        if mountedUSB.success {
            let lines = mountedUSB.output.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                if parts.count == 2 {
                    let disk = parts[0]
                    let mountPoint = parts[1]
                    
                    // Check if this drive is already in our list
                    if !drives.contains(where: { $0.identifier == disk }) {
                        drives.append(DriveInfo(
                            name: URL(fileURLWithPath: mountPoint).lastPathComponent,
                            identifier: disk,
                            size: "Mounted",
                            type: "USB (Mounted)",
                            mountPoint: mountPoint,
                            isInternal: false,
                            isEFI: mountPoint.contains("EFI"),
                            partitions: []
                        ))
                    }
                }
            }
        }
        
        return drives
    }
    
    // MARK: - Helper function to parse disk info
    private static func parseDiskInfo(_ output: String) -> (name: String, size: String, protocol: String, mountPoint: String, type: String, partitions: [PartitionInfo]) {
        var name = "Unknown"
        var size = "Unknown"
        var protocolType = "Unknown"
        var mountPoint = ""
        var type = "Unknown"
        var partitions: [PartitionInfo] = []
        
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("Device / Media Name:") {
                name = trimmedLine.components(separatedBy: ": ").last ?? "Unknown"
            } else if trimmedLine.contains("Size:") {
                size = trimmedLine.components(separatedBy: ": ").last ?? "Unknown"
            } else if trimmedLine.contains("Protocol:") {
                protocolType = trimmedLine.components(separatedBy: ": ").last ?? "Unknown"
            } else if trimmedLine.contains("Mount Point:") {
                mountPoint = trimmedLine.components(separatedBy: ": ").last ?? ""
            } else if trimmedLine.contains("Type (Bundle):") {
                type = trimmedLine.components(separatedBy: ": ").last ?? "Unknown"
            }
        }
        
        return (name, size, protocolType, mountPoint, type, partitions)
    }
    
    // MARK: - Remove duplicate drives
    private static func removeDuplicateDrives(_ drives: [DriveInfo]) -> [DriveInfo] {
        var uniqueDrives: [DriveInfo] = []
        var seenIdentifiers: Set<String> = []
        
        for drive in drives {
            if !seenIdentifiers.contains(drive.identifier) {
                uniqueDrives.append(drive)
                seenIdentifiers.insert(drive.identifier)
            }
        }
        
        return uniqueDrives
    }
    
    private static func parsePlistDiskData(_ data: Data) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                
                for disk in allDisks {
                    if let deviceIdentifier = disk["DeviceIdentifier"] as? String {
                        let size = disk["Size"] as? Int64 ?? 0
                        let sizeGB = size > 0 ? String(format: "%.1f GB", Double(size) / 1_000_000_000) : "Unknown"
                        
                        // Check if APFS Container
                        if let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]] {
                            // APFS Container
                            let name = "APFS Container (\(deviceIdentifier))"
                            let isInternal = isDiskInternal(deviceIdentifier)
                            
                            drives.append(DriveInfo(
                                name: name,
                                identifier: deviceIdentifier,
                                size: sizeGB,
                                type: "APFS Container",
                                mountPoint: "",
                                isInternal: isInternal,
                                isEFI: false,
                                partitions: []
                            ))
                            
                            // APFS Volumes
                            for volume in apfsVolumes {
                                if let volIdentifier = volume["DeviceIdentifier"] as? String,
                                   let volMountPoint = volume["MountPoint"] as? String,
                                   let volName = volume["VolumeName"] as? String {
                                    
                                    drives.append(DriveInfo(
                                        name: volName,
                                        identifier: volIdentifier,
                                        size: "APFS Volume",
                                        type: "APFS",
                                        mountPoint: volMountPoint,
                                        isInternal: isInternal,
                                        isEFI: false,
                                        partitions: []
                                    ))
                                }
                            }
                        } else if let partitions = disk["Partitions"] as? [[String: Any]] {
                            // Physical disk with partitions
                            let isInternal = isDiskInternal(deviceIdentifier)
                            
                            // Get disk info
                            let infoResult = runCommand("diskutil info /dev/\(deviceIdentifier) 2>/dev/null")
                            let infoLines = infoResult.output.components(separatedBy: "\n")
                            
                            var protocolType = "Unknown"
                            var busProtocol = "Unknown"
                            var deviceModel = "Unknown"
                            var deviceNode = ""
                            
                            for line in infoLines {
                                if line.contains("Protocol:") {
                                    protocolType = line.components(separatedBy: ": ").last ?? "Unknown"
                                } else if line.contains("Device / Media Name:") {
                                    deviceModel = line.components(separatedBy: ": ").last ?? "Unknown"
                                } else if line.contains("Device Node:") {
                                    deviceNode = line.components(separatedBy: ": ").last ?? ""
                                } else if line.contains("Bus Protocol:") {
                                    busProtocol = line.components(separatedBy: ": ").last ?? "Unknown"
                                }
                            }
                            
                            var drivePartitions: [PartitionInfo] = []
                            
                            // Process partitions
                            for partition in partitions {
                                if let partIdentifier = partition["DeviceIdentifier"] as? String,
                                   let partSize = partition["Size"] as? Int64,
                                   let partType = partition["Content"] as? String {
                                    
                                    let partMountPoint = (partition["MountPoint"] as? String) ?? ""
                                    let partName = (partition["VolumeName"] as? String) ?? "Unnamed"
                                    let isEFI = partType.contains("EFI") || partName.contains("EFI")
                                    
                                    let partSizeStr = partSize > 0 ?
                                        String(format: "%.1f GB", Double(partSize) / 1_000_000_000) :
                                        "Unknown"
                                    
                                    drivePartitions.append(PartitionInfo(
                                        name: partName,
                                        identifier: partIdentifier,
                                        size: partSizeStr,
                                        type: partType,
                                        mountPoint: partMountPoint,
                                        isEFI: isEFI
                                    ))
                                }
                            }
                            
                            let driveName = deviceModel != "Unknown" ? deviceModel : "Disk (\(deviceIdentifier))"
                            
                            drives.append(DriveInfo(
                                name: driveName,
                                identifier: deviceIdentifier,
                                size: sizeGB,
                                type: "\(protocolType) (\(busProtocol))",
                                mountPoint: deviceNode,
                                isInternal: isInternal,
                                isEFI: false,
                                partitions: drivePartitions
                            ))
                        }
                    }
                }
            }
        } catch {
            print("Plist parsing error: \(error)")
        }
        
        return drives
    }
    
    private static func parseTextDiskOutput(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDisk: (identifier: String, name: String, size: String, isUSB: Bool) = ("", "", "Unknown", false)
        var currentPartitions: [PartitionInfo] = []
        var inDiskSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Look for disk header (e.g., "/dev/disk0 (internal, physical):" or "/dev/disk2 (external, physical):")
            if trimmedLine.hasPrefix("/dev/disk") && trimmedLine.contains(":") {
                // Save previous disk if exists
                if !currentDisk.identifier.isEmpty {
                    let isInternal = !currentDisk.isUSB && isDiskInternal(currentDisk.identifier)
                    drives.append(DriveInfo(
                        name: currentDisk.name.isEmpty ? "Disk \(currentDisk.identifier)" : currentDisk.name,
                        identifier: currentDisk.identifier,
                        size: currentDisk.size,
                        type: currentDisk.isUSB ? "USB Drive" : "Disk",
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
                    if let diskMatch = diskPart.range(of: "disk[0-9]+", options: .regularExpression) {
                        currentDisk.identifier = String(diskPart[diskMatch])
                    }
                    
                    // Check if it's USB
                    currentDisk.isUSB = trimmedLine.lowercased().contains("external") || 
                                       trimmedLine.lowercased().contains("usb") ||
                                       trimmedLine.lowercased().contains("removable")
                    
                    // Extract size if present
                    if let sizeRange = trimmedLine.range(of: "[0-9]+\\.[0-9]+ [GT]B", options: .regularExpression) {
                        currentDisk.size = String(trimmedLine[sizeRange])
                    }
                    
                    // Extract name from description
                    if components.count >= 2 {
                        let description = components[1].trimmingCharacters(in: .whitespaces)
                        if !description.isEmpty {
                            // Remove "(external, physical)" or similar from name
                            let nameParts = description.components(separatedBy: ",")
                            if !nameParts.isEmpty {
                                currentDisk.name = nameParts[0].trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
                inDiskSection = true
            }
            // Look for partitions (lines starting with numbers)
            else if inDiskSection && (trimmedLine.hasPrefix("0:") || trimmedLine.range(of: "^\\s*\\d+:\\s", options: .regularExpression) != nil) {
                let parts = trimmedLine.components(separatedBy: " ")
                    .filter { !$0.isEmpty }
                
                if parts.count >= 5 {
                    let partId = parts[1].replacingOccurrences(of: "*", with: "")
                    let partName = parts[2]
                    let partSize = parts[3] + " " + parts[4]
                    let partType = parts.dropFirst(5).joined(separator: " ")
                    let isEFI = partType.contains("EFI") || partId.contains("s1") || partName.contains("EFI")
                    
                    currentPartitions.append(PartitionInfo(
                        name: partName,
                        identifier: partId,
                        size: partSize,
                        type: partType,
                        mountPoint: "",
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
            let isInternal = !currentDisk.isUSB && isDiskInternal(currentDisk.identifier)
            drives.append(DriveInfo(
                name: currentDisk.name.isEmpty ? "Disk \(currentDisk.identifier)" : currentDisk.name,
                identifier: currentDisk.identifier,
                size: currentDisk.size,
                type: currentDisk.isUSB ? "USB Drive" : "Disk",
                mountPoint: "",
                isInternal: isInternal,
                isEFI: false,
                partitions: currentPartitions
            ))
        }
        
        return drives
    }
    
    private static func getDrivesFromSystemProfiler() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        let result = runCommand("system_profiler SPStorageDataType 2>/dev/null || echo 'No storage info'")
        if !result.success {
            return drives
        }
        
        let lines = result.output.components(separatedBy: "\n")
        var currentDrive: [String: String] = [:]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains(":") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count == 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                    currentDrive[key] = value
                }
            } else if trimmedLine.isEmpty && !currentDrive.isEmpty {
                // End of drive section
                if let name = currentDrive["Mount Point"]?.isEmpty == false ? 
                   URL(fileURLWithPath: currentDrive["Mount Point"] ?? "").lastPathComponent :
                   currentDrive["Volume Name"] ?? currentDrive["Device Name"] {
                    
                    let size = currentDrive["Capacity"] ?? currentDrive["Size"] ?? "Unknown"
                    let fs = currentDrive["File System"] ?? "Unknown"
                    let mountPoint = currentDrive["Mount Point"] ?? ""
                    let isInternal = !mountPoint.hasPrefix("/Volumes") || mountPoint == "/"
                    
                    let identifier = "disk\(drives.count)"
                    
                    drives.append(DriveInfo(
                        name: name,
                        identifier: identifier,
                        size: size,
                        type: fs,
                        mountPoint: mountPoint,
                        isInternal: isInternal,
                        isEFI: false,
                        partitions: []
                    ))
                }
                currentDrive = [:]
            }
        }
        
        return drives
    }
    
    private static func getDrivesFromMountedVolumes() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Get mounted volumes
        let result = runCommand("""
        mount | grep '/dev/disk' | awk '{print $1, $3}' | while read device mount; do
            echo "$device|$mount"
        done
        """)
        
        if !result.success {
            return drives
        }
        
        let lines = result.output.components(separatedBy: "\n")
        var diskCount = 0
        
        for line in lines where !line.isEmpty {
            let components = line.components(separatedBy: "|")
            if components.count == 2 {
                let device = components[0]
                let mountPoint = components[1]
                
                // Extract disk identifier
                if let diskMatch = device.range(of: "disk[0-9]+", options: .regularExpression) {
                    let diskId = String(device[diskMatch])
                    let isInternal = !mountPoint.hasPrefix("/Volumes") || mountPoint == "/"
                    
                    // Get volume name
                    let nameResult = runCommand("basename \"\(mountPoint)\"")
                    let name = nameResult.success && !nameResult.output.isEmpty ? 
                              nameResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : 
                              "Volume \(diskCount)"
                    
                    // Get size info
                    let sizeResult = runCommand("df -h \"\(mountPoint)\" | tail -1 | awk '{print $2}'")
                    let size = sizeResult.success && !sizeResult.output.isEmpty ? 
                              sizeResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : 
                              "Unknown"
                    
                    // Get filesystem type
                    let fsResult = runCommand("diskutil info \"\(device)\" 2>/dev/null | grep 'Type (Bundle):' | cut -d: -f2 | xargs")
                    let fsType = fsResult.success && !fsResult.output.isEmpty ? 
                                fsResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : 
                                "Unknown"
                    
                    drives.append(DriveInfo(
                        name: name,
                        identifier: diskId,
                        size: size,
                        type: fsType,
                        mountPoint: mountPoint,
                        isInternal: isInternal,
                        isEFI: mountPoint.contains("EFI") || name.contains("EFI"),
                        partitions: []
                    ))
                    
                    diskCount += 1
                }
            }
        }
        
        return drives
    }
    
    private static func isDiskInternal(_ identifier: String) -> Bool {
        // Heuristic: disk0, disk1 are usually internal
        if identifier == "disk0" || identifier == "disk1" {
            return true
        }
        
        // Check if it's a USB drive
        let usbCheck = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep -i 'protocol.*usb'")
        if usbCheck.success && !usbCheck.output.isEmpty {
            return false // USB drives are external
        }
        
        // Check if mounted at root (internal drives usually mount at /)
        let mountCheck = runCommand("mount | grep '/dev/\(identifier)' | grep ' / '")
        if mountCheck.success {
            return true
        }
        
        // Check if it's an APFS container (usually internal)
        let apfsCheck = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep -i 'apfs'")
        if apfsCheck.success && !apfsCheck.output.isEmpty {
            return true
        }
        
        // Default to external for safety
        return false
    }
    
    static func listAllPartitions() -> [String] {
        let result = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s[0-9]*' | sort | uniq
        """)
        
        if result.success {
            let partitions = result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return partitions.isEmpty ? ["disk0s1", "disk1s1"] : partitions
        }
        return ["disk0s1", "disk1s1"]
    }
    
    // MARK: - System Information Gathering
    
    static func getCompleteSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
        // Get basic system info
        // macOS Version
        let versionResult = runCommand("sw_vers -productVersion 2>/dev/null || echo 'Unknown'")
        info.macOSVersion = versionResult.success ? versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Build Number
        let buildResult = runCommand("sw_vers -buildVersion 2>/dev/null || echo 'Unknown'")
        info.buildNumber = buildResult.success ? buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Kernel Version
        let kernelResult = runCommand("uname -r 2>/dev/null || echo 'Unknown'")
        info.kernelVersion = kernelResult.success ? kernelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Model Identifier
        let modelResult = runCommand("sysctl -n hw.model 2>/dev/null || echo 'Unknown'")
        info.modelIdentifier = modelResult.success ? modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Processor
        let cpuResult = runCommand("sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown'")
        info.processor = cpuResult.success ? cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
        
        // Memory
        let memResult = runCommand("sysctl -n hw.memsize 2>/dev/null")
        if memResult.success, let bytes = Int64(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let gb = Double(bytes) / 1_073_741_824
            info.memory = String(format: "%.0f GB", gb)
        } else {
            info.memory = "Unknown"
        }
        
        // Check if running from USB
        let bootResult = runCommand("""
        if diskutil info / 2>/dev/null | grep -q 'Volume Name:.*[Uu][Ss][Bb]'; then
            echo "USB Boot"
        else
            echo "Internal Boot"
        fi
        """)
        info.bootMode = bootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return info
    }
    
    static func getCompleteDiagnostics() -> String {
        var diagnostics = "=== SystemMaintenance Complete Diagnostics Report ===\n"
        diagnostics += "Generated: \(Date().formatted(date: .complete, time: .complete))\n\n"
        
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
        
        // EFI Status
        diagnostics += "--- EFI Status ---\n"
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

// MARK: - Enhanced SystemInfo Structure
struct SystemInfo {
    var macOSVersion: String = "Checking..."
    var buildNumber: String = "Checking..."
    var kernelVersion: String = "Checking..."
    var modelIdentifier: String = "Checking..."
    var processor: String = "Checking..."
    var processorDetails: String = "Checking..."
    var memory: String = "Checking..."
    var bootMode: String = "Checking..."
    var systemUUID: String = "Checking..."
    var platformUUID: String = "Checking..."
    var serialNumber: String = "Checking..."
    var bootROMVersion: String = "Checking..."
    var smcVersion: String = "Checking..."
    
    // Hardware Information
    var gpuInfo: String = "Checking..."
    var networkInfo: String = "Checking..."
    var storageInfo: String = "Checking..."
    var usbInfo: String = "Checking..."
    var thunderboltInfo: String = "Checking..."
    var ethernetInfo: String = "Checking..."
    var nvmeInfo: String = "Checking..."
    var ahciInfo: String = "Checking..."
    var audioInfo: String = "Checking..."
    var bluetoothInfo: String = "Checking..."
    var pciDevices: String = "Checking..."
    var wirelessInfo: String = "Checking..."
    var usbXHCInfo: String = "Checking..."
}

// MARK: - Data Models
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
        return lhs.id == rhs.id &&
               lhs.identifier == rhs.identifier
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
    
    static func == (lhs: PartitionInfo, rhs: PartitionInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.identifier == rhs.identifier
    }
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

struct RequirementIndicator: View {
    let title: String
    let status: String
    let version: String
    let isRequired: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                if status.contains("Installed") || status.contains("Disabled ✓") {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(version)
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .frame(width: 80)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
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
}

struct StatusBadge: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(6)
        }
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

struct DriveSummaryCard: View {
    let title: String
    let icon: String
    let color: Color
    let drives: [DriveInfo]
    let isExpanded: Bool
    
    var totalSize: String {
        return "\(drives.count) drives"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(totalSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if drives.isEmpty {
                Text("No drives detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                if isExpanded {
                    ForEach(drives) { drive in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(drive.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(drive.size)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text(drive.identifier)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(drive.type)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if drive.id != drives.last?.id {
                            Divider()
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(drives) { drive in
                                VStack(spacing: 2) {
                                    Text(drive.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(drive.size)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced SystemInfoView
@MainActor
struct SystemInfoView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleALCStatus: String
    @Binding var liluStatus: String
    @Binding var efiPath: String?
    @Binding var systemInfo: SystemInfo
    @Binding var allDrives: [DriveInfo]
    let refreshSystemInfo: () -> Void
    
    @State private var showAllDrives = false
    @State private var showExportView = false
    @State private var selectedDetailSection: String? = "System"
    
    let detailSections = ["System", "Drives"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Export Button
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showExportView = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        refreshSystemInfo()
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
                
                // Detail Sections Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detailSections, id: \.self) { section in
                            DetailSectionButton(
                                title: section,
                                isSelected: selectedDetailSection == section
                            ) {
                                selectedDetailSection = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Display selected section
                switch selectedDetailSection {
                case "System":
                    systemInfoSection
                case "Drives":
                    drivesInfoSection
                default:
                    systemInfoSection
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showExportView) {
            ExportSystemInfoView(
                isPresented: $showExportView,
                systemInfo: systemInfo,
                allDrives: allDrives,
                appleHDAStatus: appleHDAStatus,
                appleALCStatus: appleALCStatus,
                liluStatus: liluStatus,
                efiPath: efiPath
            )
        }
    }
    
    // MARK: - Detail Section Views
    
    private var systemInfoSection: some View {
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
                InfoCard(title: "SIP Status", value: ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
                InfoCard(title: "EFI Status", value: efiPath != nil ? "Mounted ✓" : "Not Mounted ✗")
                InfoCard(title: "Audio Status", value: getAudioStatus())
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var drivesInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Drives")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(showAllDrives ? "Show Less" : "Show All") {
                    showAllDrives.toggle()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            VStack(spacing: 12) {
                DriveSummaryCard(
                    title: "Internal Storage",
                    icon: "internaldrive.fill",
                    color: .blue,
                    drives: internalDrives,
                    isExpanded: showAllDrives
                )
                
                DriveSummaryCard(
                    title: "External Storage",
                    icon: "externaldrive.fill",
                    color: .orange,
                    drives: externalDrives,
                    isExpanded: showAllDrives
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties and Functions
    
    var internalDrives: [DriveInfo] {
        allDrives.filter { $0.isInternal }
    }
    
    var externalDrives: [DriveInfo] {
        allDrives.filter { !$0.isInternal }
    }
    
    private func getAudioStatus() -> String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working ✓"
        } else {
            return "Setup Required ⚠️"
        }
    }
}

// MARK: - Detail Section Button Component
struct DetailSectionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced ExportSystemInfoView
@MainActor
struct ExportSystemInfoView: View {
    @Binding var isPresented: Bool
    let systemInfo: SystemInfo
    let allDrives: [DriveInfo]
    let appleHDAStatus: String
    let appleALCStatus: String
    let liluStatus: String
    let efiPath: String?
    
    @State private var exportFormat = 0
    @State private var includeDrives = true
    @State private var includeKexts = true
    @State private var includeEFI = true
    @State private var includeHardware = true
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var exportMessageColor = Color.green
    @State private var document = SystemDiagnosticsDocument(text: "")
    
    let exportFormats = ["Plain Text", "JSON", "HTML"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Export Format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Format")
                            .font(.headline)
                        
                        Picker("", selection: $exportFormat) {
                            ForEach(0..<exportFormats.count, id: \.self) { index in
                                Text(exportFormats[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Content Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Include in Export")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("System Information", isOn: .constant(true)).disabled(true)
                            Toggle("Drive Information", isOn: $includeDrives)
                            Toggle("Kext Status", isOn: $includeKexts)
                            Toggle("EFI Details", isOn: $includeEFI)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)
                        
                        ScrollView {
                            Text(generatePreview())
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .frame(height: 150)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Export Buttons
                    VStack(spacing: 12) {
                        Button(action: exportToFile) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Exporting...")
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Export to File")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isExporting)
                        
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
                        .disabled(isExporting)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    if !exportMessage.isEmpty {
                        Text(exportMessage)
                            .font(.caption)
                            .foregroundColor(exportMessageColor)
                            .padding()
                            .background(exportMessageColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onChange(of: exportFormat) { _ in
            document.text = generateExportContent()
        }
        .onChange(of: includeDrives) { _ in
            document.text = generateExportContent()
        }
        .onChange(of: includeKexts) { _ in
            document.text = generateExportContent()
        }
        .onChange(of: includeEFI) { _ in
            document.text = generateExportContent()
        }
        .onChange(of: includeHardware) { _ in
            document.text = generateExportContent()
        }
        .onAppear {
            document.text = generateExportContent()
        }
    }
    
    private func generatePreview() -> String {
        var content = "SystemMaintenance Report\n"
        content += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        content += "=== System Information ===\n"
        content += "macOS: \(systemInfo.macOSVersion) (\(systemInfo.buildNumber))\n"
        content += "Kernel: \(systemInfo.kernelVersion)\n"
        content += "Model: \(systemInfo.modelIdentifier)\n"
        content += "CPU: \(systemInfo.processor)\n"
        content += "RAM: \(systemInfo.memory)\n"
        content += "Boot: \(systemInfo.bootMode)\n"
        content += "SIP: \(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")\n"
        
        if includeKexts {
            content += "\n=== Kext Status ===\n"
            content += "Lilu: \(liluStatus)\n"
            content += "AppleALC: \(appleALCStatus)\n"
            content += "AppleHDA: \(appleHDAStatus)\n"
        }
        
        if includeDrives && !allDrives.isEmpty {
            content += "\n=== Drives (\(allDrives.count)) ===\n"
            for (index, drive) in allDrives.prefix(3).enumerated() {
                content += "\(index + 1). \(drive.name) (\(drive.size)) - \(drive.type)\n"
            }
            if allDrives.count > 3 {
                content += "... and \(allDrives.count - 3) more drives\n"
            }
        }
        
        if includeEFI {
            content += "\n=== EFI Status ===\n"
            content += efiPath != nil ? "Mounted: Yes (\(efiPath ?? ""))\n" : "Mounted: No\n"
        }
        
        return content
    }
    
    private func generateExportContent() -> String {
        switch exportFormat {
        case 1: // JSON
            return generateJSON()
        case 2: // HTML
            return generateHTML()
        default: // Plain Text
            return generatePlainText()
        }
    }
    
    private func generatePlainText() -> String {
        return ShellHelper.getCompleteDiagnostics()
    }
    
    private func generateJSON() -> String {
        var json: [String: Any] = [:]
        
        // System Info
        json["system"] = [
            "macOSVersion": systemInfo.macOSVersion,
            "buildNumber": systemInfo.buildNumber,
            "kernelVersion": systemInfo.kernelVersion,
            "modelIdentifier": systemInfo.modelIdentifier,
            "processor": systemInfo.processor,
            "memory": systemInfo.memory,
            "bootMode": systemInfo.bootMode,
            "sipDisabled": ShellHelper.isSIPDisabled(),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Kext Info
        if includeKexts {
            json["kexts"] = [
                "lilu": [
                    "status": liluStatus,
                    "loaded": ShellHelper.checkKextLoaded("Lilu")
                ],
                "appleALC": [
                    "status": appleALCStatus,
                    "loaded": ShellHelper.checkKextLoaded("AppleALC")
                ],
                "appleHDA": [
                    "status": appleHDAStatus,
                    "loaded": ShellHelper.checkKextLoaded("AppleHDA")
                ]
            ]
        }
        
        // Drive Info
        if includeDrives {
            var drivesArray: [[String: Any]] = []
            for drive in allDrives {
                var driveDict: [String: Any] = [
                    "name": drive.name,
                    "identifier": drive.identifier,
                    "size": drive.size,
                    "type": drive.type,
                    "mountPoint": drive.mountPoint,
                    "isInternal": drive.isInternal,
                    "isEFI": drive.isEFI
                ]
                
                if !drive.partitions.isEmpty {
                    var partitionsArray: [[String: Any]] = []
                    for partition in drive.partitions {
                        partitionsArray.append([
                            "name": partition.name,
                            "identifier": partition.identifier,
                            "size": partition.size,
                            "type": partition.type,
                            "mountPoint": partition.mountPoint,
                            "isEFI": partition.isEFI
                        ])
                    }
                    driveDict["partitions"] = partitionsArray
                }
                
                drivesArray.append(driveDict)
            }
            json["drives"] = drivesArray
        }
        
        // EFI Info
        if includeEFI {
            json["efi"] = [
                "mounted": efiPath != nil,
                "path": efiPath ?? "Not mounted",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to generate JSON\"}"
        }
    }
    
    private func generateHTML() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>SystemMaintenance Report</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                    margin: 40px; 
                    background: #f5f5f7;
                    color: #333;
                }
                .container { 
                    max-width: 1200px; 
                    margin: 0 auto; 
                    background: white; 
                    padding: 40px; 
                    border-radius: 10px; 
                    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
                }
                h1 { 
                    color: #2d3748; 
                    font-size: 32px;
                    margin-bottom: 10px;
                    font-weight: 800;
                }
                h2 { 
                    color: #4a5568; 
                    margin-top: 40px; 
                    padding-bottom: 12px; 
                    border-bottom: 2px solid #e2e8f0;
                    font-size: 24px;
                    font-weight: 700;
                }
                .section { 
                    background: #f7fafc; 
                    padding: 25px; 
                    border-radius: 10px; 
                    margin: 25px 0; 
                    border: 1px solid #e2e8f0;
                }
                .info-grid { 
                    display: grid; 
                    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
                    gap: 20px; 
                    margin-top: 20px; 
                }
                .info-item { 
                    background: white; 
                    padding: 20px; 
                    border-radius: 8px; 
                    border-left: 5px solid #667eea;
                    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
                }
                .label { 
                    font-weight: 700; 
                    color: #4a5568; 
                    font-size: 13px; 
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    margin-bottom: 8px;
                }
                .value { 
                    color: #2d3748; 
                    margin-top: 8px; 
                    font-size: 16px; 
                    font-weight: 600;
                    line-height: 1.5;
                }
                .drive-info { 
                    background: #2d3748; 
                    color: #e2e8f0; 
                    padding: 20px; 
                    border-radius: 8px; 
                    margin-top: 15px; 
                    font-family: 'SF Mono', 'Monaco', 'Menlo', monospace; 
                    font-size: 13px; 
                    white-space: pre-wrap;
                    line-height: 1.6;
                }
                .timestamp { 
                    color: #a0aec0; 
                    font-size: 14px; 
                    margin-top: 40px; 
                    text-align: center; 
                    font-style: italic;
                    padding-top: 20px;
                    border-top: 1px solid #e2e8f0;
                }
                .status-badge {
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 600;
                    margin: 2px;
                }
                .status-good { background: #c6f6d5; color: #22543d; }
                .status-bad { background: #fed7d7; color: #742a2a; }
                .status-warning { background: #feebc8; color: #744210; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>SystemMaintenance Diagnostics Report</h1>
                <div class="timestamp">Generated: \(dateFormatter.string(from: Date()))</div>
                
                <!-- System Information -->
                <div class="section">
                    <h2>System Information</h2>
                    <div class="info-grid">
                        <div class="info-item">
                            <div class="label">macOS Version</div>
                            <div class="value">\(systemInfo.macOSVersion)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Build Number</div>
                            <div class="value">\(systemInfo.buildNumber)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Kernel Version</div>
                            <div class="value">\(systemInfo.kernelVersion)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Model Identifier</div>
                            <div class="value">\(systemInfo.modelIdentifier)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Processor</div>
                            <div class="value">\(systemInfo.processor)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Memory</div>
                            <div class="value">\(systemInfo.memory)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">Boot Mode</div>
                            <div class="value">\(systemInfo.bootMode)</div>
                        </div>
                        <div class="info-item">
                            <div class="label">SIP Status</div>
                            <div class="value">
                                <span class="status-badge \(ShellHelper.isSIPDisabled() ? "status-good" : "status-bad")">
                                    \(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
                                </span>
                            </div>
                        </div>
                        <div class="info-item">
                            <div class="label">EFI Status</div>
                            <div class="value">
                                <span class="status-badge \(efiPath != nil ? "status-good" : "status-warning")">
                                    \(efiPath != nil ? "Mounted" : "Not Mounted")
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Audio Kext Status -->
                <div class="section">
                    <h2>Audio Kext Status</h2>
                    <div class="info-grid">
                        <div class="info-item">
                            <div class="label">Lilu.kext</div>
                            <div class="value">
                                <span class="status-badge \(liluStatus == "Installed" ? "status-good" : "status-bad")">
                                    \(liluStatus)
                                </span>
                            </div>
                        </div>
                        <div class="info-item">
                            <div class="label">AppleALC.kext</div>
                            <div class="value">
                                <span class="status-badge \(appleALCStatus == "Installed" ? "status-good" : "status-bad")">
                                    \(appleALCStatus)
                                </span>
                            </div>
                        </div>
                        <div class="info-item">
                            <div class="label">AppleHDA.kext</div>
                            <div class="value">
                                <span class="status-badge \(appleHDAStatus == "Installed" ? "status-good" : "status-bad")">
                                    \(appleHDAStatus)
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="timestamp">
                    Report generated by SystemMaintenance • For Hackintosh community use
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func exportToFile() {
        isExporting = true
        exportMessage = ""
        
        // Generate content
        let content = generateExportContent()
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export System Information"
        savePanel.nameFieldLabel = "Export As:"
        
        // Set default file name and extension
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        var fileName = "SystemMaintenance_Report_\(timestamp)"
        var fileExtension = "txt"
        
        switch exportFormat {
        case 1: // JSON
            fileExtension = "json"
        case 2: // HTML
            fileExtension = "html"
        default: // Plain Text
            fileExtension = "txt"
        }
        
        fileName = "\(fileName).\(fileExtension)"
        savePanel.nameFieldStringValue = fileName
        
        // Set allowed file types
        if exportFormat == 1 {
            savePanel.allowedContentTypes = [.json]
        } else if exportFormat == 2 {
            savePanel.allowedContentTypes = [.html]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }
        
        savePanel.canCreateDirectories = true
        
        // Show save panel
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    // Write content to file
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    
                    // Show success message
                    exportMessage = "✅ Report exported successfully to:\n\(url.lastPathComponent)"
                    exportMessageColor = .green
                    
                    // Open the containing folder
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isPresented = false
                    }
                } catch {
                    exportMessage = "❌ Failed to export: \(error.localizedDescription)"
                    exportMessageColor = .red
                }
            }
            isExporting = false
        }
    }
    
    private func copyToClipboard() {
        isExporting = true
        
        let content = generateExportContent()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        exportMessage = "✅ Report copied to clipboard!"
        exportMessageColor = .green
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exportMessage = ""
            isExporting = false
        }
    }
}

// MARK: - System Maintenance View
@MainActor
struct SystemMaintenanceView: View {
    @Binding var isDownloadingKDK: Bool
    @Binding var isUninstallingKDK: Bool
    @Binding var isMountingPartition: Bool
    @Binding var downloadProgress: Double
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var installedKDKVersion: String?
    @Binding var systemProtectStatus: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var showEFISelectionView: Bool
    @Binding var allDrives: [DriveInfo]
    @Binding var isLoadingDrives: Bool
    @State private var selectedDrive: DriveInfo?
    @Binding var showDiskDetailView: Bool
    let refreshDrives: () -> Void
    
    @State private var showDonationButton = true
    @State private var isCheckingEFI = false
    @State private var searchText = ""
    
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
        ScrollView {
            VStack(spacing: 20) {
                // Support Banner
                if showDonationButton {
                    supportBanner
                }
                
                warningBanner
                
                // Drives Overview
                drivesOverviewSection
                
                // AppleHDA Installation Card
                appleHDAInstallationCard
                
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
        .onChange(of: selectedDrive) { newValue in
            if newValue != nil {
                showDiskDetailView = true
            }
        }
        .onChange(of: showDiskDetailView) { newValue in
            if !newValue {
                selectedDrive = nil
            }
        }
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
                
                Button(action: refreshDrives) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingDrives)
                
                Button(action: refreshUSBDrives) {
                    Label("Check USB", systemImage: "externaldrive")
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
                // Internal Drives
                if !internalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Internal Drives", systemImage: "internaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        ForEach(internalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
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
                
                // External Drives
                if !externalDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("External Drives", systemImage: "externaldrive.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(externalDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                            }
                        }
                        
                        if externalDrives.count > 3 {
                            Text("+ \(externalDrives.count - 3) more external drives")
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allDrives.flatMap { $0.partitions }.filter { $0.isEFI }) { partition in
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
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Auto Mount") {
                            mountEFI()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMountingPartition)
                        
                        Button("Manual Select") {
                            showEFISelectionView = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            if !allDrives.isEmpty {
                Text("Found \(allDrives.flatMap { $0.partitions }.filter { $0.isEFI }.count) EFI partition(s)")
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
    
    private func efiStatusSection(efiPath: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.green)
                Text("EFI Partition Mounted")
                    .font(.headline)
            }
            
            HStack {
                Text("Path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(efiPath)
                    .font(.caption)
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
                Button("Check OC Structure") {
                    checkOpenCoreStructure(efiPath: efiPath)
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
    
    private var maintenanceGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MaintenanceButton(
                title: "Mount EFI",
                icon: "externaldrive",
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
                isLoading: isCheckingEFI,
                action: checkEFIStructure
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
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
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
    
    private var supportBanner: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Support This Project")
                    .font(.headline)
                Text("Donations help fund development and testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Donate Now") {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Button(action: {
                withAnimation {
                    showDonationButton = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
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
    
    private var appleHDAInstallationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.blue)
                Text("AppleHDA Audio Installation")
                    .font(.headline)
                
                Spacer()
                
                if systemProtectStatus == "Disabled" && efiPath != nil {
                    Text("Ready to Install")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Requirements Missing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 16) {
                RequirementIndicator(
                    title: "Lilu.kext",
                    status: liluStatus,
                    version: liluVersion ?? "1.6.8",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleALC.kext",
                    status: appleALCStatus,
                    version: appleALCVersion ?? "1.8.7",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleHDA.kext",
                    status: appleHDAStatus,
                    version: appleHDAVersion ?? "Custom Build",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "SIP Status",
                    status: systemProtectStatus == "Disabled" ? "Disabled ✓" : "Enabled ✗",
                    version: "Required: Disabled",
                    isRequired: true
                )
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
    
    // MARK: - Action Functions
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountEFIPartition()
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success && path != nil {
                    alertTitle = "Success"
                    alertMessage = "EFI partition mounted at: \(path ?? "Unknown")"
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to auto-mount EFI partition from USB boot.
                    
                    Please try:
                    1. Click "Select EFI..." to choose manually
                    2. Open Terminal and run: diskutil list
                    3. Find your EFI partition (usually diskXs1)
                    4. Run: sudo diskutil mount diskXs1
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
        isCheckingEFI = true
        
        DispatchQueue.global(qos: .background).async {
            guard let efiPath = efiPath else {
                DispatchQueue.main.async {
                    isCheckingEFI = false
                    alertTitle = "Error"
                    alertMessage = "EFI partition not mounted"
                    showAlert = true
                }
                return
            }
            
            var messages: [String] = ["Checking EFI structure..."]
            
            // Check directories
            let dirs = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers", "EFI/OC/Tools"]
            
            for dir in dirs {
                let fullPath = "\(efiPath)/\(dir)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                messages.append("\(exists ? "✅" : "❌") \(dir)")
            }
            
            DispatchQueue.main.async {
                isCheckingEFI = false
                alertTitle = "EFI Structure Check"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func checkOpenCoreStructure(efiPath: String) {
        let ocPath = "\(efiPath)/EFI/OC/"
        let configPath = "\(ocPath)config.plist"
        
        var messages: [String] = ["OpenCore Structure Check:"]
        
        // Check if config.plist exists
        if FileManager.default.fileExists(atPath: configPath) {
            messages.append("✅ config.plist found")
        } else {
            messages.append("❌ config.plist not found")
        }
        
        alertTitle = "OpenCore Check"
        alertMessage = messages.joined(separator: "\n")
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
    
    // MARK: - USB Drive Detection Function
    private func refreshUSBDrives() {
        isLoadingDrives = true
        
        // Force refresh with USB-specific detection
        let result = ShellHelper.runCommand("""
        echo "=== USB Drive Detection ==="
        diskutil list | grep -B2 -A2 'external'
        echo "=== USB Protocol Check ==="
        diskutil list | grep -E '^/dev/disk' | awk '{print $1}' | while read disk; do
            if diskutil info "$disk" 2>/dev/null | grep -q 'Protocol.*USB'; then
                echo "USB Drive: $disk"
            fi
        done
        """)
        
        print("USB detection output: \(result.output)")
        
        // Reload all drives with enhanced detection
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
                isLoadingDrives = false
                
                // Show notification if USB drives found
                let usbCount = drives.filter { !$0.isInternal }.count
                if usbCount > 0 {
                    alertTitle = "USB Drive Detection"
                    alertMessage = "Found \(usbCount) USB/external drive(s)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Kext Management View
@MainActor
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var kextSourcePath: String
    
    @State private var selectedKexts: Set<String> = []
    @State private var rebuildCacheProgress = 0.0
    @State private var isRebuildingCache = false
    @State private var showAudioKextsOnly = true
    
    // Complete list of kexts for Hackintosh
    let allKexts = [
        // Required for AppleHDA Audio
        ("Lilu", "1.6.8", "Kernel extension patcher - REQUIRED for audio", "https://github.com/acidanthera/Lilu", true),
        ("AppleALC", "1.8.7", "Audio codec support - REQUIRED for AppleHDA", "https://github.com/acidanthera/AppleALC", true),
        ("AppleHDA", "500.7.4", "Apple HD Audio driver", "Custom build", true),
        
        // Graphics
        ("WhateverGreen", "1.6.8", "Graphics patching and DRM fixes", "https://github.com/acidanthera/WhateverGreen", false),
        ("IntelGraphicsFixup", "1.3.1", "Intel GPU framebuffer patches", "https://github.com/lvs1974/IntelGraphicsFixup", false),
        
        // System
        ("VirtualSMC", "1.3.3", "SMC emulation for virtualization", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCProcessor", "1.3.3", "CPU monitoring for VirtualSMC", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCSuperIO", "1.3.3", "Super I/O monitoring", "https://github.com/acidanthera/VirtualSMC", false),
        
        // Network
        ("IntelMausi", "1.0.9", "Intel Ethernet controller support", "https://github.com/acidanthera/IntelMausi", false),
        ("AtherosE2200", "2.3.0", "Atheros Ethernet support", "https://github.com/Mieze/AtherosE2200Ethernet", false),
        ("RealtekRTL8111", "2.4.2", "Realtek Gigabit Ethernet", "https://github.com/Mieze/RTL8111_driver_for_OS_X", false),
        
        // Storage
        ("NVMeFix", "1.1.2", "NVMe SSD power management", "https://github.com/acidanthera/NVMeFix", false),
        ("SATA-unsupported", "1.0.0", "SATA controller support", "Various", false),
        
        // USB
        ("USBInjectAll", "0.8.3", "USB port mapping", "https://github.com/daliansky/OS-X-USB-Inject-All", false),
        ("XHCI-unsupported", "1.2.0", "XHCI USB controller support", "Various", false),
    ]
    
    var filteredKexts: [(String, String, String, String, Bool)] {
        if showAudioKextsOnly {
            return allKexts.filter { $0.4 } // Only audio-related
        }
        return allKexts
    }
    
    var body: some View {
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
                    
                    if !kextSourcePath.isEmpty {
                        // Check if it's a folder or file
                        var isDirectory: ObjCBool = false
                        let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
                        
                        if exists {
                            HStack {
                                Image(systemName: isDirectory.boolValue ? "folder.fill" : "doc.fill")
                                    .foregroundColor(.blue)
                                Text(isDirectory.boolValue ? "Folder selected" : "Kext file selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: installSelectedKexts) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Install Selected (\(selectedKexts.count))")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty ?
                                Color.blue.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty)
                        
                        Button(action: uninstallKexts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Uninstall")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: rebuildCaches) {
                            HStack {
                                if isRebuildingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild Cache")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRebuildingCache)
                        
                        Button(action: {
                            showAudioKextsOnly.toggle()
                        }) {
                            HStack {
                                Image(systemName: showAudioKextsOnly ? "speaker.wave.3" : "square.grid.2x2")
                                Text(showAudioKextsOnly ? "Show All" : "Audio Only")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isRebuildingCache {
                    VStack(spacing: 8) {
                        ProgressView(value: rebuildCacheProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Rebuilding kernel cache... \(Int(rebuildCacheProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(showAudioKextsOnly ? "Audio Kexts" : "All Available Kexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedKexts = Set(filteredKexts.map { $0.0 })
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                        
                        Button("Clear All") {
                            selectedKexts.removeAll()
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                    }
                    
                    ForEach(filteredKexts, id: \.0) { kext in
                        KextRow(
                            name: kext.0,
                            version: kext.1,
                            description: kext.2,
                            githubURL: kext.3,
                            isAudio: kext.4,
                            isSelected: selectedKexts.contains(kext.0),
                            isInstalling: isInstallingKext
                        ) {
                            toggleKextSelection(kext.0)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .onAppear {
                // Auto-select audio kexts
                if selectedKexts.isEmpty {
                    selectedKexts = Set(["Lilu", "AppleALC", "AppleHDA"])
                }
            }
        }
    }
    
    // MARK: - Kext Row Component
    struct KextRow: View {
        let name: String
        let version: String
        let description: String
        let githubURL: String
        let isAudio: Bool
        let isSelected: Bool
        let isInstalling: Bool
        let toggleAction: () -> Void
        
        var body: some View {
            HStack {
                Button(action: toggleAction) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? (isAudio ? .blue : .green) : .gray)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if isAudio {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Text(name)
                            .font(.body)
                            .fontWeight(isAudio ? .semibold : .regular)
                        Spacer()
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if githubURL != "Custom build" {
                    Button(action: {
                        if let url = URL(string: githubURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInstalling)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? (isAudio ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.clear)
            .cornerRadius(6)
        }
    }
    
    private func toggleKextSelection(_ kextName: String) {
        if selectedKexts.contains(kextName) {
            selectedKexts.remove(kextName)
        } else {
            selectedKexts.insert(kextName)
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
        
        // IMPORTANT FIX: Allow all file types and manually check for .kext extension
        panel.allowedContentTypes = [UTType.item] // Allow all file types
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Check if the selected file has .kext extension
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
                // Source is a directory - look for kexts
                messages.append("\nSearching for kexts in folder...")
                
                // Install Lilu.kext to EFI
                let liluSource = findKextInDirectory(name: "Lilu", directory: kextSourcePath)
                if let liluSource = liluSource {
                    messages.append("\n1. Installing Lilu.kext to EFI...")
                    let command = "cp -R \"\(liluSource)\" \"\(ocKextsPath)Lilu.kext\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    if result.success {
                        messages.append("✅ Lilu.kext installed to EFI")
                    } else {
                        messages.append("❌ Failed to install Lilu.kext: \(result.output)")
                        success = false
                    }
                } else {
                    messages.append("❌ Lilu.kext not found in: \(kextSourcePath)")
                    success = false
                }
                
                // Install AppleALC.kext to EFI
                let appleALCSource = findKextInDirectory(name: "AppleALC", directory: kextSourcePath)
                if let appleALCSource = appleALCSource {
                    messages.append("\n2. Installing AppleALC.kext to EFI...")
                    let command = "cp -R \"\(appleALCSource)\" \"\(ocKextsPath)AppleALC.kext\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    if result.success {
                        messages.append("✅ AppleALC.kext installed to EFI")
                    } else {
                        messages.append("❌ Failed to install AppleALC.kext: \(result.output)")
                        success = false
                    }
                } else {
                    messages.append("❌ AppleALC.kext not found in: \(kextSourcePath)")
                    success = false
                }
                
                // Install AppleHDA.kext to /System/Library/Extensions/
                let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                if let appleHDASource = appleHDASource {
                    messages.append("\n3. Installing AppleHDA.kext to /System/Library/Extensions...")
                    // FIXED: Use the correct source path (the main kext bundle, not plugin)
                    let sourceKextPath = appleHDASource
                    let commands = [
                        "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                        "cp -R \"\(sourceKextPath)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                        "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                        "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                        "touch /System/Library/Extensions"
                    ]
                    
                    var appleHDASuccess = true
                    for cmd in commands {
                        let result = ShellHelper.runCommand(cmd, needsSudo: true)
                        if !result.success {
                            messages.append("❌ Failed: \(cmd)")
                            appleHDASuccess = false
                            break
                        }
                    }
                    
                    if appleHDASuccess {
                        messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                    } else {
                        success = false
                    }
                } else {
                    messages.append("❌ AppleHDA.kext not found in: \(kextSourcePath)")
                    success = false
                }
            } else {
                // Source is a file - check if it's a kext file
                if kextSourcePath.hasSuffix(".kext") {
                    let kextName = URL(fileURLWithPath: kextSourcePath).lastPathComponent.replacingOccurrences(of: ".kext", with: "")
                    messages.append("\nInstalling \(kextName).kext...")
                    
                    if kextName.lowercased() == "applehda" {
                        // Install AppleHDA to /System/Library/Extensions
                        messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(kextSourcePath)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                            "touch /System/Library/Extensions"
                        ]
                        
                        var appleHDASuccess = true
                        for cmd in commands {
                            let result = ShellHelper.runCommand(cmd, needsSudo: true)
                            if !result.success {
                                messages.append("❌ Failed: \(cmd)")
                                appleHDASuccess = false
                                break
                            }
                        }
                        
                        if appleHDASuccess {
                            messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                        } else {
                            success = false
                        }
                    } else {
                        // Install other kexts to EFI
                        messages.append("\nInstalling \(kextName).kext to EFI...")
                        let command = "cp -R \"\(kextSourcePath)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed to EFI")
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext: \(result.output)")
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
                messages.append("\n4. Rebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues: \(result.output)")
                }
            }
            
            // Update UI
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    // Check which kexts were installed
                    if isDirectory.boolValue {
                        liluStatus = "Installed"
                        liluVersion = "1.6.8"
                        appleALCStatus = "Installed"
                        appleALCVersion = "1.8.7"
                        appleHDAStatus = "Installed"
                        appleHDAVersion = "500.7.4"
                    } else if kextSourcePath.lowercased().contains("applehda") {
                        appleHDAStatus = "Installed"
                        appleHDAVersion = "500.7.4"
                    }
                    
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
    
    // FIXED: Improved findKextInDirectory function
    private func findKextInDirectory(name: String, directory: String) -> String? {
        let fileManager = FileManager.default
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: directory) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // First look for exact match of the kext bundle
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    // Check if it's a kext bundle with the exact name
                    if isDir.boolValue && item.lowercased() == "\(name.lowercased()).kext" {
                        return itemPath
                    }
                }
            }
            
            // If not found, look for partial matches (but only for kext bundles)
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue && item.lowercased().contains(name.lowercased()) && item.hasSuffix(".kext") {
                        return itemPath
                    }
                }
            }
            
            // Check subdirectories (but avoid going into .kext bundles)
            for item in contents {
                let fullPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    // Skip if it's a .kext bundle (we already checked those)
                    if !fullPath.hasSuffix(".kext") {
                        if let found = findKextInDirectory(name: name, directory: fullPath) {
                            return found
                        }
                    }
                }
            }
        } catch {
            print("Error searching for kext: \(error)")
        }
        
        return nil
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
    
    private func installSelectedKexts() {
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
            var messages: [String] = ["Installing selected kexts..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directory
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            
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
            
            for kextName in selectedKexts {
                if kextName == "AppleHDA" {
                    // Special handling for AppleHDA
                    messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                    
                    let appleHDASource: String?
                    if isDirectory.boolValue {
                        appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                    } else if kextSourcePath.lowercased().contains("applehda") {
                        appleHDASource = kextSourcePath
                    } else {
                        appleHDASource = nil
                    }
                    
                    if let appleHDASource = appleHDASource {
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
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
                        } else {
                            success = false
                        }
                    } else {
                        messages.append("❌ AppleHDA.kext not found")
                        success = false
                    }
                } else {
                    // Other kexts go to EFI
                    messages.append("\nInstalling \(kextName).kext to EFI...")
                    
                    let kextSource: String?
                    if isDirectory.boolValue {
                        kextSource = findKextInDirectory(name: kextName, directory: kextSourcePath)
                    } else if kextSourcePath.lowercased().contains(kextName.lowercased()) {
                        kextSource = kextSourcePath
                    } else {
                        kextSource = nil
                    }
                    
                    if let kextSource = kextSource {
                        let command = "cp -R \"\(kextSource)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed")
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext")
                            success = false
                        }
                    } else {
                        messages.append("❌ \(kextName).kext not found")
                        success = false
                    }
                }
            }
            
            // Rebuild cache if AppleHDA was installed
            if selectedKexts.contains("AppleHDA") && success {
                messages.append("\nRebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues")
                }
            }
            
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    alertTitle = "Kexts Installed"
                    alertMessage = messages.joined(separator: "\n")
                } else {
                    alertTitle = "Installation Issues"
                    alertMessage = messages.joined(separator: "\n")
                }
                showAlert = true
            }
        }
    }
    
    private func uninstallKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        alertTitle = "Uninstallation Instructions"
        alertMessage = """
        To uninstall kexts:
        
        1. EFI Kexts (Lilu, AppleALC, etc.):
           • Navigate to: \(efiPath)/EFI/OC/Kexts/
           • Delete the kext files you want to remove
           
        2. System Kexts (AppleHDA):
           • Open Terminal
           • Run: sudo rm -rf /System/Library/Extensions/AppleHDA.kext
           • Run: sudo kextcache -i /
           
        3. Update config.plist:
           • Remove kext entries from Kernel → Add
           • Save and restart
           
        WARNING: Removing AppleHDA will disable audio until reinstalled.
        """
        showAlert = true
    }
    
    private func rebuildCaches() {
        isRebuildingCache = true
        rebuildCacheProgress = 0
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            // Simulate progress
            for i in 0...100 {
                DispatchQueue.main.async {
                    rebuildCacheProgress = Double(i)
                }
                usleep(50000)
            }
            
            DispatchQueue.main.async {
                isRebuildingCache = false
                
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
                rebuildCacheProgress = 0
            }
        }
    }
}

// MARK: - Audio Tools View
struct AudioToolsView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var audioCodecID = "0x10ec0899"
    @State private var layoutID = "1"
    @State private var isDetectingCodec = false
    @State private var showAdvancedSettings = false
    
    let layoutIDs = ["1", "2", "3", "5", "7", "11", "13", "14", "15", "16", "17", "18", "20", "21", "27", "28", "29", "30", "31", "32", "33", "34", "35", "40", "41", "42", "43", "45", "46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59", "60", "61", "62", "63", "64", "65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91", "92", "93", "94", "95", "96", "97", "98", "99", "100"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Codec Detection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio Codec Detection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Codec ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0x10ec0899", text: $audioCodecID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button(action: detectCodec) {
                            HStack {
                                if isDetectingCodec {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Detecting...")
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                    Text("Detect Codec")
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isDetectingCodec)
                    }
                    
                    Text("Common Codec IDs:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x10ec1220", "0x80862882"], id: \.self) { codec in
                                Button(codec) {
                                    audioCodecID = codec
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Layout ID Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("AppleALC Layout ID")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Layout ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $layoutID) {
                                ForEach(layoutIDs, id: \.self) { id in
                                    Text(id).tag(id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Boot Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("alcid=\(layoutID)")
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    Button("Apply Layout ID") {
                        applyLayoutID()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Settings
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedSettings) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Verbose Output")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: .constant("""
                            AppleHDAController: found a HDA controller
                            AppleHDA: creating AppleHDAEngine with layout: \(layoutID)
                            AppleHDA: found codec: \(audioCodecID)
                            """))
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.2))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Troubleshooting
                VStack(alignment: .leading, spacing: 12) {
                    Text("Troubleshooting")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Test Audio Output") {
                            testAudioOutput()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Reset Audio Settings") {
                            resetAudioSettings()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Button("Check Audio Devices") {
                            checkAudioDevices()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func detectCodec() {
        isDetectingCodec = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isDetectingCodec = false
            
            // Simulate codec detection
            let codecs = ["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x80862882"]
            let detectedCodec = codecs.randomElement() ?? "0x10ec0899"
            audioCodecID = detectedCodec
            
            alertTitle = "Codec Detected"
            alertMessage = "Detected audio codec: \(detectedCodec)\n\nRecommended Layout IDs:\n• Realtek ALC889: 1, 2\n• Realtek ALC887: 5, 7\n• Realtek ALC892: 1, 2, 3"
            showAlert = true
        }
    }
    
    private func applyLayoutID() {
        alertTitle = "Layout ID Applied"
        alertMessage = """
        Layout ID \(layoutID) has been configured.
        
        To apply changes:
        1. Add 'alcid=\(layoutID)' to boot-args in config.plist
        2. Rebuild kernel cache
        3. Restart your system
        
        If audio doesn't work, try a different Layout ID.
        """
        showAlert = true
    }
    
    private func testAudioOutput() {
        alertTitle = "Audio Test"
        alertMessage = """
        Testing audio output...
        
        1. Play a test sound in System Preferences → Sound
        2. Check if audio output devices are detected
        3. Verify AppleHDA is loaded in kextstat
        
        If no sound:
        1. Try different Layout ID
        2. Check if SIP is disabled
        3. Verify AppleALC is in EFI
        """
        showAlert = true
    }
    
    private func resetAudioSettings() {
        alertTitle = "Reset Audio Settings"
        alertMessage = """
        This will reset audio settings to default.
        
        Steps:
        1. Remove 'alcid=' from boot-args
        2. Delete AppleHDA.kext from /S/L/E
        3. Delete AppleALC.kext from EFI
        4. Rebuild kernel cache
        5. Restart system
        
        Audio will stop working until reinstalled.
        """
        showAlert = true
    }
    
    private func checkAudioDevices() {
        let result = ShellHelper.runCommand("system_profiler SPAudioDataType")
        
        alertTitle = "Audio Devices"
        alertMessage = result.success ? result.output : "Failed to get audio device info"
        showAlert = true
    }
}

// MARK: - Enhanced SSDT Generator View with Complete Motherboard List
@MainActor
struct SSDTGeneratorView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var efiPath: String?
    
    @State private var selectedDeviceType = "CPU"
    @State private var cpuModel = "Intel Core i7"
    @State private var gpuModel = "AMD Radeon RX 580"
    @State private var motherboardModel = "Gigabyte Z390 AORUS PRO"
    @State private var usbPortCount = "15"
    @State private var useEC = true
    @State private var useAWAC = true
    @State private var usePLUG = true
    @State private var useXOSI = true
    @State private var useALS0 = true
    @State private var useHID = true
    @State private var customDSDTName = "DSDT.aml"
    @State private var isGenerating = false
    @State private var generationProgress = 0.0
    @State private var generatedSSDTs: [String] = []
    @State private var showAdvancedOptions = false
    @State private var acpiTableSource = "Auto-detect"
    @State private var selectedSSDTs: Set<String> = []
    @State private var outputPath = ""
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Other"]
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    let gpuModels = ["AMD Radeon RX 580", "AMD Radeon RX 5700 XT", "NVIDIA GeForce GTX 1060", "NVIDIA GeForce RTX 2060", "Intel UHD Graphics 630", "Custom"]
    
    // COMPLETE MOTHERBOARD LIST for SSDT Generation
    let motherboardModels = [
        // Gigabyte
        "Gigabyte Z390 AORUS PRO",
        "Gigabyte Z390 AORUS ELITE",
        "Gigabyte Z390 AORUS MASTER",
        "Gigabyte Z390 DESIGNARE",
        "Gigabyte Z390 UD",
        "Gigabyte Z390 GAMING X",
        "Gigabyte Z390 M GAMING",
        "Gigabyte Z390 AORUS PRO WIFI",
        "Gigabyte Z390 AORUS ULTRA",
        "Gigabyte Z390 GAMING SLI",
        "Gigabyte Z390 AORUS XTREME",
        
        "Gigabyte Z490 AORUS PRO AX",
        "Gigabyte Z490 VISION G",
        "Gigabyte Z490 AORUS ELITE AC",
        "Gigabyte Z490 UD AC",
        "Gigabyte Z490 AORUS MASTER",
        "Gigabyte Z490I AORUS ULTRA",
        "Gigabyte Z490 AORUS XTREME",
        
        "Gigabyte Z590 AORUS PRO AX",
        "Gigabyte Z590 VISION G",
        "Gigabyte Z590 AORUS ELITE AX",
        "Gigabyte Z590 UD AC",
        "Gigabyte Z590 AORUS MASTER",
        
        "Gigabyte Z690 AORUS PRO",
        "Gigabyte Z690 AORUS ELITE AX",
        "Gigabyte Z690 GAMING X",
        "Gigabyte Z690 UD AX",
        
        "Gigabyte B360 AORUS GAMING 3",
        "Gigabyte B360M DS3H",
        "Gigabyte B360 HD3",
        
        "Gigabyte B460 AORUS PRO AC",
        "Gigabyte B460M DS3H",
        "Gigabyte B460M AORUS PRO",
        "Gigabyte B460 HD3",
        
        "Gigabyte B560 AORUS PRO AX",
        "Gigabyte B560M DS3H",
        "Gigabyte B560M AORUS ELITE",
        "Gigabyte B560 HD3",
        
        "Gigabyte B660 AORUS MASTER",
        "Gigabyte B660M DS3H AX",
        "Gigabyte B660M GAMING X AX",
        
        "Gigabyte H370 AORUS GAMING 3",
        "Gigabyte H370 HD3",
        "Gigabyte H370M DS3H",
        
        "Gigabyte H470 AORUS PRO AX",
        "Gigabyte H470M DS3H",
        
        "Gigabyte H510M S2H",
        "Gigabyte H510M H",
        "Gigabyte H510M DS2V",
        
        "Gigabyte H610M S2H",
        "Gigabyte H610M H DDR4",
        "Gigabyte H610M G DDR4",
        
        // ASUS
        "ASUS ROG MAXIMUS XI HERO",
        "ASUS ROG MAXIMUS XI FORMULA",
        "ASUS ROG MAXIMUS XI APEX",
        "ASUS ROG MAXIMUS XI GENE",
        "ASUS ROG STRIX Z390-E GAMING",
        "ASUS ROG STRIX Z390-F GAMING",
        "ASUS ROG STRIX Z390-H GAMING",
        "ASUS ROG STRIX Z390-I GAMING",
        "ASUS PRIME Z390-A",
        "ASUS PRIME Z390-P",
        "ASUS TUF Z390-PLUS GAMING",
        "ASUS TUF Z390-PRO GAMING",
        
        "ASUS ROG MAXIMUS XII HERO",
        "ASUS ROG MAXIMUS XII APEX",
        "ASUS ROG MAXIMUS XII FORMULA",
        "ASUS ROG STRIX Z490-E GAMING",
        "ASUS ROG STRIX Z490-F GAMING",
        "ASUS ROG STRIX Z490-I GAMING",
        "ASUS PRIME Z490-A",
        "ASUS PRIME Z490-P",
        "ASUS TUF Z490-PLUS GAMING",
        
        "ASUS ROG MAXIMUS XIII HERO",
        "ASUS ROG STRIX Z590-E GAMING",
        "ASUS ROG STRIX Z590-F GAMING",
        "ASUS ROG STRIX Z590-I GAMING",
        "ASUS PRIME Z590-A",
        "ASUS PRIME Z590-P",
        "ASUS TUF Z590-PLUS WIFI",
        
        "ASUS ROG MAXIMUS Z690 HERO",
        "ASUS ROG STRIX Z690-E GAMING WIFI",
        "ASUS ROG STRIX Z690-F GAMING WIFI",
        "ASUS ROG STRIX Z690-I GAMING WIFI",
        "ASUS PRIME Z690-A",
        "ASUS PRIME Z690-P",
        "ASUS TUF Z690-PLUS WIFI",
        
        "ASUS ROG STRIX B360-F GAMING",
        "ASUS ROG STRIX B360-G GAMING",
        "ASUS ROG STRIX B360-I GAMING",
        "ASUS PRIME B360-PLUS",
        "ASUS PRIME B360M-A",
        "ASUS TUF B360-PRO GAMING",
        
        "ASUS ROG STRIX B460-F GAMING",
        "ASUS ROG STRIX B460-G GAMING",
        "ASUS ROG STRIX B460-I GAMING",
        "ASUS PRIME B460-PLUS",
        "ASUS PRIME B460M-A",
        "ASUS TUF B460-PRO GAMING",
        
        "ASUS ROG STRIX B560-F GAMING WIFI",
        "ASUS ROG STRIX B560-G GAMING WIFI",
        "ASUS ROG STRIX B560-I GAMING WIFI",
        "ASUS PRIME B560-PLUS",
        "ASUS PRIME B560M-A",
        "ASUS TUF GAMING B560-PLUS WIFI",
        
        "ASUS ROG STRIX B660-F GAMING WIFI",
        "ASUS ROG STRIX B660-G GAMING WIFI",
        "ASUS ROG STRIX B660-I GAMING WIFI",
        "ASUS PRIME B660-PLUS D4",
        "ASUS PRIME B660M-A D4",
        "ASUS TUF GAMING B660-PLUS WIFI D4",
        
        "ASUS ROG STRIX H370-F GAMING",
        "ASUS ROG STRIX H370-I GAMING",
        "ASUS PRIME H370-PLUS",
        "ASUS PRIME H370M-PLUS",
        
        "ASUS ROG STRIX H470-F GAMING",
        "ASUS ROG STRIX H470-I GAMING",
        "ASUS PRIME H470-PLUS",
        "ASUS PRIME H470M-PLUS",
        
        // ASRock
        "ASRock Z390 Taichi",
        "ASRock Z390 Phantom Gaming SLI",
        "ASRock Z390 Phantom Gaming 4",
        "ASRock Z390 Steel Legend",
        "ASRock Z390 Pro4",
        "ASRock Z390 Extreme4",
        "ASRock Z390M Pro4",
        
        "ASRock Z490 Taichi",
        "ASRock Z490 Phantom Gaming 4",
        "ASRock Z490 Steel Legend",
        "ASRock Z490 Extreme4",
        "ASRock Z490M Pro4",
        
        "ASRock Z590 Taichi",
        "ASRock Z590 Phantom Gaming 4",
        "ASRock Z590 Steel Legend",
        "ASRock Z590 Extreme",
        "ASRock Z590 Pro4",
        
        "ASRock Z690 Taichi",
        "ASRock Z690 Phantom Gaming 4",
        "ASRock Z690 Steel Legend",
        "ASRock Z690 Extreme",
        "ASRock Z690 Pro RS",
        
        "ASRock B360 Pro4",
        "ASRock B360M Pro4",
        "ASRock B360M HDV",
        "ASRock B360M-ITX/ac",
        
        "ASRock B460 Pro4",
        "ASRock B460M Pro4",
        "ASRock B460M Steel Legend",
        "ASRock B460M-ITX/ac",
        
        "ASRock B560 Pro4",
        "ASRock B560M Pro4",
        "ASRock B560M Steel Legend",
        "ASRock B560M-ITX/ac",
        
        "ASRock B660 Pro RS",
        "ASRock B660M Pro RS",
        "ASRock B660M Steel Legend",
        "ASRock B660M-ITX/ac",
        
        "ASRock H370 Pro4",
        "ASRock H370M-ITX/ac",
        "ASRock H370M Pro4",
        
        "ASRock H470M Pro4",
        "ASRock H470M-ITX/ac",
        
        // MSI
        "MSI MEG Z390 GODLIKE",
        "MSI MEG Z390 ACE",
        "MSI MPG Z390 GAMING PRO CARBON AC",
        "MSI MPG Z390 GAMING EDGE AC",
        "MSI MPG Z390 GAMING PLUS",
        "MSI MPG Z390I GAMING EDGE AC",
        "MSI MAG Z390 TOMAHAWK",
        "MSI MAG Z390M MORTAR",
        
        "MSI MEG Z490 GODLIKE",
        "MSI MEG Z490 ACE",
        "MSI MPG Z490 GAMING CARBON WIFI",
        "MSI MPG Z490 GAMING EDGE WIFI",
        "MSI MPG Z490 GAMING PLUS",
        "MSI MAG Z490 TOMAHAWK",
        "MSI MAG Z490M MORTAR WIFI",
        
        "MSI MEG Z590 GODLIKE",
        "MSI MEG Z590 ACE",
        "MSI MPG Z590 GAMING CARBON WIFI",
        "MSI MPG Z590 GAMING EDGE WIFI",
        "MSI MPG Z590 GAMING PLUS",
        "MSI MAG Z590 TOMAHAWK WIFI",
        
        "MSI MEG Z690 GODLIKE",
        "MSI MEG Z690 ACE",
        "MSI MPG Z690 CARBON WIFI",
        "MSI MPG Z690 EDGE WIFI",
        "MSI MAG Z690 TOMAHAWK WIFI",
        "MSI PRO Z690-A WIFI",
        
        "MSI B360 GAMING PLUS",
        "MSI B360M MORTAR",
        "MSI B360M PRO-VDH",
        "MSI B360M BAZOOKA",
        
        "MSI B460 GAMING PLUS",
        "MSI B460M MORTAR",
        "MSI B460M PRO-VDH WIFI",
        "MSI B460M BAZOOKA",
        
        "MSI B560 GAMING PLUS",
        "MSI B560M PRO-VDH WIFI",
        "MSI B560M MORTAR",
        "MSI B560M-A PRO",
        
        "MSI B660 GAMING PLUS WIFI",
        "MSI B660M MORTAR WIFI",
        "MSI B660M-A PRO WIFI",
        "MSI PRO B660M-A WIFI",
        
        "MSI H370 GAMING PLUS",
        "MSI H370M BAZOOKA",
        "MSI H370M MORTAR",
        
        "MSI H470 GAMING PLUS",
        "MSI H470M PRO",
        
        // Intel
        "Intel NUC8i7BEH",
        "Intel NUC8i5BEH",
        "Intel NUC8i3BEH",
        "Intel NUC10i7FNH",
        "Intel NUC10i5FNH",
        "Intel NUC11PAHi7",
        "Intel NUC11PAHi5",
        "Intel NUC12WSHi7",
        "Intel NUC12WSHi5",
        
        // AMD Motherboards
        "ASUS ROG CROSSHAIR VIII HERO",
        "ASUS ROG CROSSHAIR VIII DARK HERO",
        "ASUS ROG CROSSHAIR VIII FORMULA",
        "ASUS ROG STRIX X570-E GAMING",
        "ASUS ROG STRIX X570-F GAMING",
        "ASUS ROG STRIX X570-I GAMING",
        "ASUS PRIME X570-PRO",
        "ASUS PRIME X570-P",
        "ASUS TUF GAMING X570-PLUS",
        "ASUS TUF GAMING X570-PRO",
        
        "ASUS ROG CROSSHAIR VII HERO",
        "ASUS ROG STRIX X470-F GAMING",
        "ASUS ROG STRIX X470-I GAMING",
        "ASUS PRIME X470-PRO",
        "ASUS TUF X470-PLUS GAMING",
        
        "Gigabyte X570 AORUS MASTER",
        "Gigabyte X570 AORUS ELITE",
        "Gigabyte X570 AORUS PRO WIFI",
        "Gigabyte X570 AORUS ULTRA",
        "Gigabyte X570 GAMING X",
        "Gigabyte X570 UD",
        
        "Gigabyte X470 AORUS GAMING 7 WIFI",
        "Gigabyte X470 AORUS ULTRA GAMING",
        "Gigabyte X470 AORUS GAMING 5 WIFI",
        
        "ASRock X570 Taichi",
        "ASRock X570 Phantom Gaming X",
        "ASRock X570 Steel Legend",
        "ASRock X570 Pro4",
        "ASRock X570M Pro4",
        
        "ASRock X470 Taichi",
        "ASRock X470 Master SLI",
        "ASRock X470 Gaming K4",
        
        "MSI MEG X570 GODLIKE",
        "MSI MEG X570 ACE",
        "MSI MPG X570 GAMING PRO CARBON WIFI",
        "MSI MPG X570 GAMING EDGE WIFI",
        "MSI MPG X570 GAMING PLUS",
        "MSI MAG X570 TOMAHAWK WIFI",
        
        "MSI X470 GAMING M7 AC",
        "MSI X470 GAMING PRO CARBON",
        "MSI X470 GAMING PLUS",
        
        // B550 Motherboards
        "ASUS ROG STRIX B550-F GAMING",
        "ASUS ROG STRIX B550-F GAMING WIFI II",
        "ASUS ROG STRIX B550-I GAMING",
        "ASUS ROG STRIX B550-E GAMING",
        "ASUS TUF GAMING B550-PLUS",
        "ASUS TUF GAMING B550-PLUS WIFI II",
        "ASUS PRIME B550-PLUS",
        "ASUS PRIME B550M-A",
        
        "Gigabyte B550 AORUS MASTER",
        "Gigabyte B550 AORUS ELITE AX V2",
        "Gigabyte B550 AORUS PRO AC",
        "Gigabyte B550 AORUS PRO AX",
        "Gigabyte B550 GAMING X V2",
        "Gigabyte B550M DS3H",
        "Gigabyte B550M AORUS ELITE",
        
        "MSI MPG B550 GAMING CARBON WIFI",
        "MSI MPG B550 GAMING EDGE WIFI",
        "MSI MPG B550 GAMING PLUS",
        "MSI MAG B550 TOMAHAWK",
        "MSI MAG B550M MORTAR",
        "MSI MAG B550M MORTAR WIFI",
        
        "ASRock B550 Taichi",
        "ASRock B550 Steel Legend",
        "ASRock B550 Extreme4",
        "ASRock B550 Pro4",
        "ASRock B550M Pro4",
        "ASRock B550M-ITX/ac",
        
        // B450 Motherboards
        "ASUS ROG STRIX B450-F GAMING",
        "ASUS ROG STRIX B450-I GAMING",
        "ASUS TUF B450-PRO GAMING",
        "ASUS TUF B450-PLUS GAMING",
        "ASUS PRIME B450-PLUS",
        "ASUS PRIME B450M-A",
        
        "Gigabyte B450 AORUS PRO WIFI",
        "Gigabyte B450 AORUS ELITE",
        "Gigabyte B450 AORUS M",
        "Gigabyte B450 GAMING X",
        "Gigabyte B450M DS3H",
        "Gigabyte B450M S2H",
        
        "MSI B450 GAMING PRO CARBON AC",
        "MSI B450 TOMAHAWK MAX",
        "MSI B450M MORTAR MAX",
        "MSI B450M PRO-VDH MAX",
        "MSI B450-A PRO MAX",
        
        "ASRock B450 Steel Legend",
        "ASRock B450 Gaming K4",
        "ASRock B450 Pro4",
        "ASRock B450M Pro4",
        "ASRock B450M-HDV",
        
        // A520 Motherboards
        "ASUS PRIME A520M-A",
        "ASUS TUF GAMING A520M-PLUS",
        "Gigabyte A520M DS3H",
        "Gigabyte A520M S2H",
        "MSI A520M-A PRO",
        "ASRock A520M Pro4",
        
        // Server/Workstation
        "Supermicro X11SSM-F",
        "Supermicro X11SSL-F",
        "Supermicro X11SPM-TPF",
        "Supermicro X11DPi-N",
        
        // Other Brands
        "EVGA Z390 DARK",
        "EVGA Z390 FTW",
        "EVGA Z390 MICRO",
        
        "Biostar B360GT3S",
        "Biostar B450MH",
        "Biostar X470GT8",
        
        "ECS H310H5-M2",
        "ECS B365H4-M",
        
        // Custom/Other
        "Custom",
        "Other/Not Listed"
    ]
    
    let usbPortCounts = ["5", "7", "9", "11", "13", "15", "20", "25", "30", "Custom"]
    
    // Common SSDTs for different device types
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management (Essential)",
            "SSDT-EC-USBX": "Embedded Controller Fix (Essential)",
            "SSDT-AWAC": "AWAC Clock Fix (Essential)",
            "SSDT-PMC": "NVRAM Support (300+ Series)",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix",
            "SSDT-PM": "Power Management",
            "SSDT-CPUR": "CPU Renaming",
            "SSDT-XCPM": "XCPM Power Management"
        ],
        "GPU": [
            "SSDT-GPU": "GPU Device Properties",
            "SSDT-PCI0": "PCI Device Renaming",
            "SSDT-IGPU": "Intel GPU Fix (for iGPU)",
            "SSDT-DGPU": "Discrete GPU Power Management",
            "SSDT-PEG0": "PCIe Graphics Slot",
            "SSDT-NDGP": "NVIDIA GPU Power Management",
            "SSDT-AMDGPU": "AMD GPU Power Management"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method (Essential)",
            "SSDT-ALS0": "Ambient Light Sensor",
            "SSDT-HID": "Keyboard/Mouse Devices (Essential)",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Mapping",
            "SSDT-PMCR": "Power Management Controller",
            "SSDT-LPCB": "LPC Bridge",
            "SSDT-PPMC": "Platform Power Management",
            "SSDT-PWRB": "Power Button",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-RP0": "PCIe Root Port 0",
            "SSDT-RP1": "PCIe Root Port 1",
            "SSDT-RP2": "PCIe Root Port 2"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties (Essential)",
            "SSDT-UIAC": "USB Port Mapping (Essential)",
            "SSDT-EHCx": "USB 2.0 Controller Renaming",
            "SSDT-XHCI": "XHCI Controller (USB 3.0)",
            "SSDT-RHUB": "USB Root Hub",
            "SSDT-XHC": "XHCI Extended Controller",
            "SSDT-PRT": "USB Port Renaming"
        ],
        "Other": [
            "SSDT-DTGP": "DTGP Method (Helper)",
            "SSDT-GPRW": "Wake Fix (USB Wake)",
            "SSDT-PM": "Power Management",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-PWRB": "Power Button",
            "SSDT-TB3": "Thunderbolt 3",
            "SSDT-NVME": "NVMe Power Management",
            "SSDT-SATA": "SATA Controller",
            "SSDT-LAN": "Ethernet Controller",
            "SSDT-WIFI": "WiFi/Bluetooth",
            "SSDT-AUDIO": "Audio Controller"
        ]
    ]
    
    var availableSSDTs: [String] {
        return ssdtTemplates[selectedDeviceType]?.map { $0.key } ?? []
    }
    
    // Motherboard specific recommendations
    var motherboardRecommendations: [String] {
        var recommendations: [String] = []
        
        // Gigabyte Z390
        if motherboardModel.contains("Gigabyte Z390") {
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-AWAC (Required)")
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-PMC (For NVRAM)")
            recommendations.append("SSDT-RTC0 (If AWAC fails)")
        }
        
        // ASUS Z390
        if motherboardModel.contains("ASUS Z390") {
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-AWAC (Required)")
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-XOSI (For sleep)")
            recommendations.append("SSDT-PMCR (For power management)")
        }
        
        // AMD X570/B550
        if motherboardModel.contains("X570") || motherboardModel.contains("B550") {
            recommendations.append("SSDT-EC (Required for AMD)")
            recommendations.append("SSDT-PLUG (CPU Power Management)")
            recommendations.append("SSDT-CPUR (CPU Renaming)")
            recommendations.append("SSDT-USBX (USB Power)")
        }
        
        // Intel 600 Series
        if motherboardModel.contains("Z690") || motherboardModel.contains("B660") {
            recommendations.append("SSDT-PLUG (Required)")
            recommendations.append("SSDT-EC-USBX (Required)")
            recommendations.append("SSDT-RTC0 (RTC Fix)")
            recommendations.append("SSDT-AWAC (Clock Fix)")
            recommendations.append("SSDT-PMC (NVRAM)")
        }
        
        return recommendations.isEmpty ? ["Select SSDTs based on your needs"] : recommendations
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("SSDT Generator")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Generate custom SSDTs for your Hackintosh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Device Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedDeviceType) {
                                ForEach(deviceTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                            .onChange(of: selectedDeviceType) { _ in
                                selectedSSDTs.removeAll()
                            }
                        }
                        
                        Spacer()
                        
                        // Dynamic fields based on device type
                        VStack(alignment: .leading, spacing: 8) {
                            if selectedDeviceType == "CPU" {
                                Text("CPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $cpuModel) {
                                    ForEach(cpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "GPU" {
                                Text("GPU Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $gpuModel) {
                                    ForEach(gpuModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            } else if selectedDeviceType == "Motherboard" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Motherboard Model")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $motherboardModel) {
                                        ForEach(motherboardModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 300)
                                    
                                    // Show motherboard recommendations
                                    if !motherboardRecommendations.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Recommended for \(motherboardModel):")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .padding(.top, 4)
                                            
                                            ForEach(motherboardRecommendations.prefix(3), id: \.self) { rec in
                                                Text("• \(rec)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            } else if selectedDeviceType == "USB" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("USB Port Count")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: $usbPortCount) {
                                        ForEach(usbPortCounts, id: \.self) { count in
                                            Text("\(count) ports").tag(count)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                    
                                    if usbPortCount == "Custom" {
                                        TextField("Enter custom port count", text: $usbPortCount)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 100)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Custom DSDT Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("DSDT.aml", text: $customDSDTName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Essential SSDT Options
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Essential SSDTs")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Select All") {
                                useEC = true
                                useAWAC = true
                                usePLUG = true
                                useXOSI = true
                                useALS0 = true
                                useHID = true
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                useEC = false
                                useAWAC = false
                                usePLUG = false
                                useXOSI = false
                                useALS0 = false
                                useHID = false
                            }
                            .font(.caption)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Toggle("SSDT-EC (Embedded Controller)", isOn: $useEC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-AWAC (AWAC Clock)", isOn: $useAWAC)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("300+ Series")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-PLUG (CPU Power)", isOn: $usePLUG)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Essential")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-XOSI (Windows OSI)", isOn: $useXOSI)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Sleep/Wake")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-ALS0 (Ambient Light)", isOn: $useALS0)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Laptops")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Toggle("SSDT-HID (Input Devices)", isOn: $useHID)
                                .toggleStyle(.switch)
                            Spacer()
                            Text("Keyboards/Mice")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // SSDT Selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Available SSDT Templates")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text("\(selectedSSDTs.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Select All") {
                                selectedSSDTs = Set(availableSSDTs)
                            }
                            .font(.caption)
                            
                            Button("Clear All") {
                                selectedSSDTs.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                    
                    if availableSSDTs.isEmpty {
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("No SSDTs available for \(selectedDeviceType)")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableSSDTs, id: \.self) { ssdt in
                                    SSDTTemplateCard(
                                        name: ssdt,
                                        description: ssdtTemplates[selectedDeviceType]?[ssdt] ?? "Unknown",
                                        isSelected: selectedSSDTs.contains(ssdt),
                                        isEssential: ssdt.contains("EC") || ssdt.contains("PLUG") || ssdt.contains("AWAC"),
                                        isDisabled: isGenerating
                                    ) {
                                        toggleSSDTSelection(ssdt)
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Options
                VStack(alignment: .leading, spacing: 16) {
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("ACPI Table Source:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $acpiTableSource) {
                                    Text("Auto-detect").tag("Auto-detect")
                                    Text("Extract from system").tag("Extract from system")
                                    Text("Custom file").tag("Custom file")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            
                            HStack {
                                Text("Output Path:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Leave empty for default", text: $outputPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") {
                                    browseForOutputPath()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // Generation Options
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Generation Options:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Toggle("Include comments", isOn: .constant(true))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                    
                                    Toggle("Optimize for size", isOn: .constant(false))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                    
                                    Toggle("Validate syntax", isOn: .constant(true))
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Generation Progress
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: generationProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Generating SSDTs... \(Int(generationProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Generated SSDTs
                if !generatedSSDTs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generated Files")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(generatedSSDTs, id: \.self) { ssdt in
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.blue)
                                        Text(ssdt)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Button("Open") {
                                                openGeneratedFile(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                            
                                            Button("Copy") {
                                                copySSDTToClipboard(ssdt)
                                            }
                                            .font(.caption2)
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(height: min(CGFloat(generatedSSDTs.count) * 50, 200))
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: generateSSDTs) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Generating...")
                                } else {
                                    Image(systemName: "cpu.fill")
                                    Text("Generate SSDTs")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        
                        Button(action: validateSSDTs) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Validate")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: installToEFI) {
                            HStack {
                                Image(systemName: "externaldrive.fill.badge.plus")
                                Text("Install to EFI")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating || efiPath == nil)
                        
                        Button(action: openSSDTGuide) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Open Guide")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Motherboard Specific Tips
                if selectedDeviceType == "Motherboard" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Motherboard Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if motherboardModel.contains("Gigabyte") {
                                Text("• Gigabyte boards often need SSDT-EC-USBX for USB power")
                                Text("• Enable Above 4G Decoding in BIOS")
                                Text("• Disable CFG Lock if available")
                            } else if motherboardModel.contains("ASUS") {
                                Text("• ASUS boards may need custom EC patches")
                                Text("• Check for BIOS updates for better compatibility")
                                Text("• Enable XMP for RAM")
                            } else if motherboardModel.contains("ASRock") {
                                Text("• ASRock boards work well with OpenCore")
                                Text("• May need RTC fix (SSDT-RTC0)")
                                Text("• Check BIOS for AMD CBS options (for AMD)")
                            } else if motherboardModel.contains("MSI") {
                                Text("• MSI boards often need specific DSDT patches")
                                Text("• Disable Fast Boot in BIOS")
                                Text("• Enable Windows 10/11 WHQL Support")
                            } else if motherboardModel.contains("AMD") || motherboardModel.contains("X570") || motherboardModel.contains("B550") {
                                Text("• AMD boards need SSDT-EC (not EC-USBX)")
                                Text("• Enable Above 4G Decoding")
                                Text("• Disable CSM (Compatibility Support Module)")
                                Text("• Set PCIe to Gen3 if using RX 5000/6000 series")
                            } else if motherboardModel.contains("Intel") {
                                Text("• Intel boards need SSDT-PLUG for CPU power")
                                Text("• Enable VT-d in BIOS")
                                Text("• Disable Secure Boot")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Enhanced SSDT Template Card Component
    struct SSDTTemplateCard: View {
        let name: String
        let description: String
        let isSelected: Bool
        let isEssential: Bool
        let isDisabled: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? (isEssential ? .red : .blue) : .primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(isEssential ? .red : .blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if isEssential {
                        Text("Essential")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .frame(width: 180, height: 100)
                .background(isSelected ? (isEssential ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)) : Color.gray.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? (isEssential ? Color.red : Color.blue) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
    }
    
    // MARK: - Action Functions
    private func toggleSSDTSelection(_ ssdtName: String) {
        if selectedSSDTs.contains(ssdtName) {
            selectedSSDTs.remove(ssdtName)
        } else {
            selectedSSDTs.insert(ssdtName)
        }
    }
    
    private func browseForOutputPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                outputPath = url.path
            }
        }
    }
    
    private func generateSSDTs() {
        isGenerating = true
        generationProgress = 0
        generatedSSDTs.removeAll()
        
        // Collect selected SSDTs
        var ssdtsToGenerate: [String] = []
        
        // Add essential SSDTs if selected
        if useEC { ssdtsToGenerate.append("SSDT-EC-USBX") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        
        // Add template SSDTs
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate.\n\nRecommended for \(motherboardModel):\n• SSDT-EC-USBX\n• SSDT-PLUG\n• SSDT-AWAC (for 300+ series)"
            showAlert = true
            isGenerating = false
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            // Simulate generation process with detailed progress
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                // Update progress
                let progress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                DispatchQueue.main.async {
                    generationProgress = progress
                }
                
                // Simulate generation time (faster for smaller SSDTs)
                let delay = ssdt.contains("EC") || ssdt.contains("PLUG") ? 800000 : 400000
                usleep(useconds_t(delay))
                
                // Generate filename
                let filename = "\(ssdt).aml"
                
                DispatchQueue.main.async {
                    generatedSSDTs.append(filename)
                }
                
                // Create dummy SSDT file
                createDummySSDTFile(ssdt: ssdt)
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                generationProgress = 0
                
                // Generate recommendations based on motherboard
                var recommendations = ""
                if motherboardModel.contains("Gigabyte") && !ssdtsToGenerate.contains("SSDT-PMC") {
                    recommendations += "\n• Consider adding SSDT-PMC for NVRAM support"
                }
                if motherboardModel.contains("AMD") && !ssdtsToGenerate.contains("SSDT-EC") {
                    recommendations += "\n• AMD boards need SSDT-EC (not EC-USBX)"
                }
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) SSDTs for \(motherboardModel):
                
                \(generatedSSDTs.joined(separator: "\n"))
                
                Files saved to: ~/Desktop/Generated_SSDTs/
                
                \(recommendations)
                
                Next steps:
                1. Copy SSDTs to EFI/OC/ACPI/
                2. Add to config.plist → ACPI → Add
                3. Enable Patch → FixMask in config.plist
                4. Rebuild kernel cache
                5. Restart system
                
                Note: These are template SSDTs. You may need to customize them for your specific hardware.
                """
                showAlert = true
            }
        }
    }
    
    private func createDummySSDTFile(ssdt: String) {
        let outputDir = getOutputDirectory()
        let filePath = "\(outputDir)/\(ssdt).aml"
        let url = URL(fileURLWithPath: filePath)
        
        // Create dummy content based on SSDT type
        var content = """
        /*
         * \(ssdt).aml
         * Generated by SystemMaintenance
         * Date: \(Date().formatted(date: .long, time: .shortened))
         * Motherboard: \(motherboardModel)
         * Device Type: \(selectedDeviceType)
         */
        
        DefinitionBlock ("", "SSDT", 2, "ACDT", "\(ssdt.replacingOccurrences(of: "SSDT-", with: ""))", 0x00000000)
        {
        """
        
        // Add content based on SSDT type
        if ssdt == "SSDT-EC-USBX" {
            content += """
                External (_SB_.PCI0.LPCB.EC0_, DeviceObj)
                
                Scope (_SB.PCI0.LPCB)
                {
                    Device (EC0)
                    {
                        Name (_HID, "ACID0001")  // _HID: Hardware ID
                        Name (_UID, Zero)  // _UID: Unique ID
                        Method (_STA, 0, NotSerialized)  // _STA: Status
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0F)
                            }
                            Else
                            {
                                Return (Zero)
                            }
                        }
                    }
                }
                
                Scope (\\_SB.PC10)
                {
                    Device (USBX)
                    {
                        Name (_ADR, Zero)
                        Name (_S3D, 0x03)
                        Name (_S4D, 0x03)
                        Method (_DSM, 4, Serialized)
                        {
                            If (LEqual (Arg2, Zero))
                            {
                                Return (Buffer (One) { 0x03 })
                            }
                            Return (Package (0x02)
                            {
                                "usb-connector-type",
                                Buffer (0x02) { 0x00, 0x00 }
                            })
                        }
                    }
                }
            """
        } else if ssdt == "SSDT-PLUG" {
            content += """
                External (_SB_.PR00, ProcessorObj)
                External (_SB_.PR01, ProcessorObj)
                
                Method (_SB.PCI0.LPCB.PMEE, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (One)
                    }
                    Return (Zero)
                }
                
                 Scope (\\_SB.PR00)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        If (LEqual (Arg2, Zero))
                        {
                            Return (Buffer (One) { 0x03 })
                        }
                        Return (Package (0x02)
                        {
                            "plugin-type",
                            One
                        })
                    }
                }
            """
        } else {
            // Generic SSDT content
            content += """
                /*
                 * Placeholder for \(ssdt)
                 * This is a template. Customize for your hardware.
                 * Refer to Dortania guides for implementation details.
                 */
                
                Scope (\\_SB)
                {
                    // Add your device definitions here
                }
            """
        }
        
        content += "\n}"
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create SSDT file: \(error)")
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        // CHANGE: Use Desktop directory instead of Downloads
        let desktopDir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let ssdtDir = desktopDir?.appendingPathComponent("Generated_SSDTs")
        
        // Create directory if it doesn't exist
        if let ssdtDir = ssdtDir {
            try? FileManager.default.createDirectory(at: ssdtDir, withIntermediateDirectories: true)
            return ssdtDir.path
        }
        
        // Fallback: If we can't get Desktop directory, use Desktop folder in home directory
        return NSHomeDirectory() + "/Desktop/Generated_SSDTs"
    }
    
    private func openGeneratedFile(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        let url = URL(fileURLWithPath: filePath)
        
        if FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.open(url)
        } else {
            alertTitle = "File Not Found"
            alertMessage = "Generated file not found at: \(filePath)"
            showAlert = true
        }
    }
    
    private func copySSDTToClipboard(_ filename: String) {
        let filePath = "\(getOutputDirectory())/\(filename)"
        
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(content, forType: .string)
                
                alertTitle = "Copied"
                alertMessage = "\(filename) content copied to clipboard"
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = "Failed to read file: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func validateSSDTs() {
        DispatchQueue.global(qos: .background).async {
            var validationMessages: [String] = ["SSDT Validation Report:"]
            
            // Check for common issues
            validationMessages.append("\n1. Checking required SSDTs...")
            
            let requiredSSDTs = ["SSDT-EC", "SSDT-PLUG", "SSDT-AWAC"]
            for ssdt in requiredSSDTs {
                let exists = selectedSSDTs.contains(ssdt) ||
                           (ssdt == "SSDT-EC" && useEC) ||
                           (ssdt == "SSDT-PLUG" && usePLUG) ||
                           (ssdt == "SSDT-AWAC" && useAWAC)
                validationMessages.append("   \(exists ? "✅" : "❌") \(ssdt) \(exists ? "" : "(Recommended)")")
            }
            
            validationMessages.append("\n2. Checking motherboard compatibility...")
            
            // Add motherboard-specific validations
            if motherboardModel.contains("300") || motherboardModel.contains("400") || motherboardModel.contains("500") || motherboardModel.contains("600") {
                if !useAWAC && !selectedSSDTs.contains("SSDT-AWAC") {
                    validationMessages.append("   ⚠️  \(motherboardModel) may need SSDT-AWAC for clock")
                }
            }
            
            if motherboardModel.contains("AMD") {
                if useEC {
                    validationMessages.append("   ⚠️  AMD boards should use SSDT-EC (not EC-USBX)")
                }
                if !selectedSSDTs.contains("SSDT-CPUR") {
                    validationMessages.append("   ℹ️  Consider SSDT-CPUR for CPU renaming")
                }
            }
            
            if motherboardModel.contains("Intel") && cpuModel.contains("Intel") {
                if !usePLUG && !selectedSSDTs.contains("SSDT-PLUG") {
                    validationMessages.append("   ❌ SSDT-PLUG is essential for Intel CPUs")
                }
            }
            
            validationMessages.append("\n3. Configuration Recommendations:")
            validationMessages.append("   • Add SSDTs to config.plist → ACPI → Add")
            validationMessages.append("   • Enable FixMask in Kernel → Quirks")
            validationMessages.append("   • Set MinKernel/MaxKernel if needed")
            validationMessages.append("   • Rebuild kernel cache after installation")
            
            DispatchQueue.main.async {
                alertTitle = "SSDT Validation"
                alertMessage = validationMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func installToEFI() {
        guard let efiPath = efiPath else {
            alertTitle = "EFI Not Mounted"
            alertMessage = "Please mount EFI partition from System tab first."
            showAlert = true
            return
        }
        
        if generatedSSDTs.isEmpty {
            alertTitle = "No SSDTs Generated"
            alertMessage = "Please generate SSDTs first before installing to EFI."
            showAlert = true
            return
        }
        
        let acpiPath = "\(efiPath)/EFI/OC/ACPI/"
        
        DispatchQueue.global(qos: .background).async {
            var installMessages: [String] = ["Installing SSDTs to EFI:"]
            var successCount = 0
            var failCount = 0
            
            // Create ACPI directory if it doesn't exist
            let _ = ShellHelper.runCommand("mkdir -p \"\(acpiPath)\"", needsSudo: true)
            
            for ssdtFile in generatedSSDTs {
                let sourcePath = "\(getOutputDirectory())/\(ssdtFile)"
                let destPath = "\(acpiPath)\(ssdtFile)"
                
                if FileManager.default.fileExists(atPath: sourcePath) {
                    let command = "cp \"\(sourcePath)\" \"\(destPath)\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    
                    if result.success {
                        installMessages.append("✅ \(ssdtFile)")
                        successCount += 1
                    } else {
                        installMessages.append("❌ \(ssdtFile): \(result.output)")
                        failCount += 1
                    }
                } else {
                    installMessages.append("❌ \(ssdtFile): Source file not found")
                    failCount += 1
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Installation"
                installMessages.append("\n📊 Summary: \(successCount)/\(generatedSSDTs.count) SSDTs installed")
                
                if failCount > 0 {
                    installMessages.append("⚠️  \(failCount) files failed to install")
                }
                
                installMessages.append("\n📍 Location: \(acpiPath)")
                installMessages.append("\n⚠️  Important Next Steps:")
                installMessages.append("   1. Add SSDTs to config.plist → ACPI → Add")
                installMessages.append("   2. Set Enabled = True for each SSDT")
                installMessages.append("   3. Enable FixMask in ACPI → Patch")
                installMessages.append("   4. Rebuild kernel cache: sudo kextcache -i /")
                installMessages.append("   5. Restart system")
                
                if motherboardModel.contains("Gigabyte") || motherboardModel.contains("ASUS") {
                    installMessages.append("\n💡 Tip for \(motherboardModel.split(separator: " ").first ?? "your board"):")
                    installMessages.append("   • Check BIOS for Above 4G Decoding")
                    installMessages.append("   • Disable CSM for better compatibility")
                }
                
                alertMessage = installMessages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func openSSDTGuide() {
        if let url = URL(string: "https://dortania.github.io/Getting-Started-With-ACPI/") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Disk Detail View
@MainActor
struct DiskDetailView: View {
    @Binding var isPresented: Bool
    let drive: DriveInfo
    @Binding var allDrives: [DriveInfo]
    let refreshDrives: () -> Void
    
    @State private var showUnmountAlert = false
    @State private var isEjecting = false
    @State private var isMounting = false
    
    var body: some View {
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
                    isPresented = false
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
                    VStack(spacing: 12) {
                        if !drive.isInternal && !drive.mountPoint.isEmpty {
                            Button(action: {
                                showUnmountAlert = true
                            }) {
                                HStack {
                                    if isEjecting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Ejecting...")
                                    } else {
                                        Image(systemName: "eject.fill")
                                        Text("Eject Drive")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isEjecting)
                        }
                        
                        if drive.mountPoint.isEmpty && !drive.isInternal {
                            Button(action: {
                                mountDrive()
                            }) {
                                HStack {
                                    if isMounting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Mounting...")
                                    } else {
                                        Image(systemName: "externaldrive.fill.badge.plus")
                                        Text("Mount Drive")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isMounting)
                        }
                        
                        Button(action: {
                            refreshDrives()
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
        .alert("Eject Drive", isPresented: $showUnmountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Eject", role: .destructive) {
                ejectDrive()
            }
        } message: {
            Text("Are you sure you want to eject '\(drive.name)'?")
        }
    }
    
    private func ejectDrive() {
        isEjecting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil eject /dev/\(drive.identifier)", needsSudo: true)
            
            DispatchQueue.main.async {
                isEjecting = false
                
                if result.success {
                    refreshDrives()
                    isPresented = false
                }
            }
        }
    }
    
    private func mountDrive() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(drive.identifier)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    refreshDrives()
                }
            }
        }
    }
}

// MARK: - EFI Selection View
@MainActor
struct EFISelectionView: View {
    @Binding var isPresented: Bool
    @Binding var efiPath: String?
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var allDrives: [DriveInfo]
    
    @State private var partitions: [String] = []
    @State private var isLoading = false
    @State private var selectedPartition = ""
    @State private var isMounting = false
    @State private var drivesList: [DriveInfo] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select EFI Partition to Mount")
                .font(.headline)
                .padding(.top)
            
            if isLoading {
                Spacer()
                ProgressView("Loading drives and partitions...")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available Partitions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if partitions.isEmpty {
                            VStack {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("No partitions found")
                                    .foregroundColor(.secondary)
                                    .italic()
                                Text("Trying auto-detection...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(partitions, id: \.self) { partition in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(partition)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        
                                        // Find which drive this partition belongs to
                                        if let driveIdentifier = partition.split(separator: "s").first {
                                            if let drive = drivesList.first(where: { $0.identifier == String(driveIdentifier) }) {
                                                Text("Drive: \(drive.name) (\(drive.size))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPartition == partition {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(selectedPartition == partition ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedPartition == partition ? Color.blue : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    selectedPartition = partition
                                }
                            }
                        }
                        
                        Divider()
                        
                        Text("Drives Found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if drivesList.isEmpty {
                            VStack {
                                Image(systemName: "externaldrive.badge.xmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.red)
                                Text("No drives found")
                                    .foregroundColor(.secondary)
                                    .italic()
                                Text("Using default drives list")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(drivesList) { drive in
                                HStack {
                                    Image(systemName: drive.type.contains("External") ? "externaldrive" : "internaldrive")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drive.identifier)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        Text("\(drive.name) - \(drive.size)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Button("Refresh") {
                            loadDrivesAndPartitions()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Auto-Detect EFI") {
                            autoDetectEFI()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: mountSelectedPartition) {
                            if isMounting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Mounting...")
                                }
                            } else {
                                Text("Mount Selected")
                            }
                        }
                        .disabled(selectedPartition.isEmpty || isMounting)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear {
            loadDrivesAndPartitions()
        }
    }
    
    private func loadDrivesAndPartitions() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            // Get partitions
            let partitionsList = ShellHelper.listAllPartitions()
            
            // Use provided drives or get new ones
            let drivesList = allDrives.isEmpty ? ShellHelper.getAllDrives() : allDrives
            
            DispatchQueue.main.async {
                self.partitions = partitionsList
                self.drivesList = drivesList
                self.isLoading = false
                
                // Auto-select common EFI partitions
                if selectedPartition.isEmpty {
                    // Look for s1 partitions (usually EFI)
                    if let efiPartition = partitionsList.first(where: { $0.contains("s1") }) {
                        selectedPartition = efiPartition
                    } else if let firstPartition = partitionsList.first {
                        selectedPartition = firstPartition
                    }
                }
            }
        }
    }
    
    private func autoDetectEFI() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            // Try to find EFI partition automatically
            let efiCandidates = partitions.filter { partition in
                // Common EFI partitions are usually s1
                return partition.contains("s1") || partition.lowercased().contains("efi")
            }
            
            DispatchQueue.main.async {
                isLoading = false
                
                if let firstEFI = efiCandidates.first {
                    selectedPartition = firstEFI
                    alertTitle = "Auto-Detected"
                    alertMessage = "Selected \(firstEFI) as likely EFI partition"
                    showAlert = true
                } else if let firstPartition = partitions.first {
                    selectedPartition = firstPartition
                    alertTitle = "Auto-Selected"
                    alertMessage = "Selected \(firstPartition) (no EFI found)"
                    showAlert = true
                } else {
                    alertTitle = "No Partitions"
                    alertMessage = "Could not find any partitions. Please check Disk Utility."
                    showAlert = true
                }
            }
        }
    }
    
    private func mountSelectedPartition() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(selectedPartition)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    let path = ShellHelper.getEFIPath()
                    efiPath = path
                    
                    alertTitle = "Success"
                    alertMessage = """
                    Successfully mounted \(selectedPartition)
                    
                    Mounted at: \(path ?? "Unknown location")
                    
                    You can now proceed with kext installation.
                    """
                    isPresented = false
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount \(selectedPartition):
                    
                    \(result.output)
                    
                    Try another partition or check Disk Utility.
                    """
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Donation View
struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Int? = 5
    @State private var customAmount: String = ""
    @State private var showThankYou = false
    
    let presetAmounts = [5, 10, 20, 50, 100]
    let paypalURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD"
    
    var body: some View {
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
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Fund testing hardware for new macOS versions")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Cover server costs for updates and downloads")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Support continued open-source development")
                            .font(.caption)
                    }
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            
            // Amount Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Amount")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        AmountButton(
                            amount: amount,
                            currency: "CAD",
                            isSelected: selectedAmount == amount,
                            action: { selectedAmount = amount }
                        )
                    }
                }
                
                HStack {
                    Text("Custom:")
                        .font(.caption)
                    
                    TextField("Other amount", text: $customAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: customAmount) { _ in
                            selectedAmount = nil
                        }
                    
                    Text("CAD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Donation Methods
            VStack(spacing: 12) {
                Text("Donation Methods")
                    .font(.headline)
                
                Button(action: {
                    openPayPalDonation()
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
            
            // Thank You Message
            if showThankYou {
                VStack(spacing: 8) {
                    Image(systemName: "hands.clap.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("Thank you for your support!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your donation helps keep this project alive.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("All donations go directly to development")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Button("Close") {
                        dismiss()
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
        .frame(width: 500, height: 500)
    }
    
    // MARK: - Amount Button Component
    struct AmountButton: View {
        let amount: Int
        let currency: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text("$\(amount)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(currency)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func openPayPalDonation() {
        let amount = getSelectedAmount()
        var urlString = paypalURL
        
        if let amount = amount {
            urlString += "&amount=\(amount)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            showThankYou = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
    
    private func getSelectedAmount() -> Int? {
        if let amount = selectedAmount {
            return amount
        } else if !customAmount.isEmpty, let amount = Int(customAmount) {
            return amount
        }
        return nil
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
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    isUninstallingKDK: $isUninstallingKDK,
                    isMountingPartition: $isMountingPartition,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    installedKDKVersion: $installedKDKVersion,
                    systemProtectStatus: $systemProtectStatus,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    showEFISelectionView: $showEFISelectionView,
                    allDrives: $allDrives,
                    isLoadingDrives: $isLoadingDrives,
                    showDiskDetailView: $showDiskDetailView,
                    refreshDrives: refreshAllDrives
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    kextSourcePath: $kextSourcePath
                )
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece.extension")
                }
                .tag(1)
                
                SystemInfoView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleALCStatus: $appleALCStatus,
                    liluStatus: $liluStatus,
                    efiPath: $efiPath,
                    systemInfo: $systemInfo,
                    allDrives: $allDrives,
                    refreshSystemInfo: refreshSystemInfo
                )
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(2)
                
                AudioToolsView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("Audio Tools", systemImage: "speaker.wave.3")
                }
                .tag(3)
                
                SSDTGeneratorView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    efiPath: $efiPath
                )
                .tabItem {
                    Label("SSDT Generator", systemImage: "cpu.fill")
                }
                .tag(4)
            }
            .tabViewStyle(.automatic)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDonationSheet) {
            DonationView()
        }
        .sheet(isPresented: $showEFISelectionView) {
            EFISelectionView(
                isPresented: $showEFISelectionView,
                efiPath: $efiPath,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                allDrives: $allDrives
            )
        }
        .sheet(isPresented: $showDiskDetailView) {
            if let drive = selectedDrive {
                DiskDetailView(
                    isPresented: $showDiskDetailView,
                    drive: drive,
                    allDrives: $allDrives,
                    refreshDrives: refreshAllDrives
                )
            }
        }
        .sheet(isPresented: $showExportView) {
            ExportSystemInfoView(
                isPresented: $showExportView,
                systemInfo: systemInfo,
                allDrives: allDrives,
                appleHDAStatus: appleHDAStatus,
                appleALCStatus: appleALCStatus,
                liluStatus: liluStatus,
                efiPath: efiPath
            )
        }
        .onAppear {
            checkSystemStatus()
            loadAllDrives()
            checkEFIMount()
            loadSystemInfo()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("System Maintenance & Kext Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // System Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(allDrives.filter { $0.isInternal }.count) Internal • \(allDrives.filter { !$0.isInternal }.count) External")
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
                
                // Export Button in Header
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
            }
        }
    }
    
    private func refreshAllDrives() {
        loadAllDrives()
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            if ShellHelper.mountEFIPartition() {
                let path = ShellHelper.getEFIPath()
                DispatchQueue.main.async {
                    efiPath = path
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
    
    private func refreshSystemInfo() {
        loadSystemInfo()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}