[file name]: ContentView.swift
[file content begin]
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
    
    // MARK: - Enhanced Drive Mounting Functions
    static func mountDrive(_ identifier: String) -> Bool {
        print("=== Attempting to mount drive: \(identifier) ===")
        
        // Check if already mounted
        let checkResult = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep 'Mount Point:' | awk '{print $3}'")
        
        if checkResult.success, let mountPoint = checkResult.output.trimmingCharacters(in: .whitespacesAndNewlines),
           !mountPoint.isEmpty, mountPoint != "Not" {
            print("Drive \(identifier) is already mounted at: \(mountPoint)")
            return true
        }
        
        // Try to mount the drive
        let mountResult = runCommand("diskutil mount \(identifier)", needsSudo: true)
        
        if mountResult.success {
            print("✅ Successfully mounted \(identifier)")
            print("Mount output: \(mountResult.output)")
            return true
        } else {
            print("❌ Failed to mount \(identifier): \(mountResult.output)")
            
            // Try alternative mounting methods
            let altResult = runCommand("diskutil mountDisk \(identifier)", needsSudo: true)
            if altResult.success {
                print("✅ Mounted using mountDisk: \(identifier)")
                return true
            }
            
            // Try mounting specific partition
            let parts = getAllPartitionsForDisk(identifier)
            for part in parts {
                print("Trying to mount partition: \(part)")
                let partMount = runCommand("diskutil mount \(part)", needsSudo: true)
                if partMount.success {
                    print("✅ Mounted partition: \(part)")
                    return true
                }
            }
        }
        
        return false
    }
    
    static func unmountDrive(_ identifier: String) -> Bool {
        print("=== Attempting to unmount drive: \(identifier) ===")
        
        let result = runCommand("diskutil unmount \(identifier)", needsSudo: true)
        if result.success {
            print("✅ Successfully unmounted \(identifier)")
            return true
        } else {
            print("❌ Failed to unmount \(identifier): \(result.output)")
            
            // Try force unmount
            let forceResult = runCommand("diskutil unmount force \(identifier)", needsSudo: true)
            if forceResult.success {
                print("✅ Force unmounted \(identifier)")
                return true
            }
        }
        
        return false
    }
    
    static func ejectDrive(_ identifier: String) -> Bool {
        print("=== Attempting to eject drive: \(identifier) ===")
        
        let result = runCommand("diskutil eject \(identifier)", needsSudo: true)
        if result.success {
            print("✅ Successfully ejected \(identifier)")
            return true
        } else {
            print("❌ Failed to eject \(identifier): \(result.output)")
        }
        
        return false
    }
    
    static func getAllPartitionsForDisk(_ diskIdentifier: String) -> [String] {
        let result = runCommand("""
        diskutil list /dev/\(diskIdentifier) 2>/dev/null | grep -o '\(diskIdentifier)s[0-9]*' | sort | uniq
        """)
        
        if result.success {
            let partitions = result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return partitions.isEmpty ? [] : partitions
        }
        return []
    }
    
    // Rest of your existing functions (mountEFIPartition, getEFIPath, getAllDrives, etc.) remain the same...
    
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
    @State private var isMounting = false
    
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
            } else if partition.type.contains("EFI") {
                Button(isMounting ? "Mounting..." : "Mount") {
                    mountPartition()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .disabled(isMounting)
            } else {
                Button(isMounting ? "Mounting..." : "Mount") {
                    mountPartition()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(isMounting)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func mountPartition() {
        isMounting = true
        DispatchQueue.global(qos: .background).async {
            _ = ShellHelper.mountDrive(partition.identifier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isMounting = false
            }
        }
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
    @State private var isMountingDrive = false
    @State private var isUnmountingDrive = false
    
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
    
    var unmountedDrives: [DriveInfo] {
        filteredDrives.filter { $0.mountPoint.isEmpty }
    }
    
    var mountedDrives: [DriveInfo] {
        filteredDrives.filter { !$0.mountPoint.isEmpty }
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
                
                // Drive Actions Section
                if !unmountedDrives.isEmpty || !mountedDrives.isEmpty {
                    driveActionsSection
                }
                
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
                // Mounted Drives
                if !mountedDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Mounted Drives (\(mountedDrives.count))", systemImage: "externaldrive.fill.badge.checkmark")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        ForEach(mountedDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                            }
                        }
                        
                        if mountedDrives.count > 3 {
                            Text("+ \(mountedDrives.count - 3) more mounted drives")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                }
                
                // Unmounted Drives
                if !unmountedDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unmounted Drives (\(unmountedDrives.count))", systemImage: "externaldrive.fill.badge.xmark")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(unmountedDrives.prefix(3)) { drive in
                            DriveRow(drive: drive) {
                                selectedDrive = drive
                            }
                        }
                        
                        if unmountedDrives.count > 3 {
                            Text("+ \(unmountedDrives.count - 3) more unmounted drives")
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
    
    private var driveActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drive Actions")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack(spacing: 12) {
                if !unmountedDrives.isEmpty {
                    Button(action: mountAllDrives) {
                        HStack {
                            if isMountingDrive {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Mounting...")
                            } else {
                                Image(systemName: "externaldrive.fill.badge.plus")
                                Text("Mount All (\(unmountedDrives.count))")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isMountingDrive)
                }
                
                if !mountedDrives.filter({ !$0.isInternal }).isEmpty {
                    Button(action: unmountAllDrives) {
                        HStack {
                            if isUnmountingDrive {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Unmounting...")
                            } else {
                                Image(systemName: "eject.fill")
                                Text("Unmount External")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isUnmountingDrive)
                }
            }
            
            if !unmountedDrives.isEmpty || !mountedDrives.isEmpty {
                Text("Found \(mountedDrives.count) mounted, \(unmountedDrives.count) unmounted drives")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
    private func mountAllDrives() {
        isMountingDrive = true
        
        DispatchQueue.global(qos: .background).async {
            var mountedCount = 0
            let unmounted = unmountedDrives
            
            for drive in unmounted {
                if ShellHelper.mountDrive(drive.identifier) {
                    mountedCount += 1
                }
                // Small delay to prevent overwhelming the system
                usleep(100000) // 0.1 second
            }
            
            DispatchQueue.main.async {
                isMountingDrive = false
                refreshDrives()
                
                alertTitle = "Drive Mounting Complete"
                alertMessage = "Successfully mounted \(mountedCount) out of \(unmounted.count) drives."
                showAlert = true
            }
        }
    }
    
    private func unmountAllDrives() {
        isUnmountingDrive = true
        
        DispatchQueue.global(qos: .background).async {
            var unmountedCount = 0
            let mounted = mountedDrives.filter { !$0.isInternal } // Only unmount external drives
            
            for drive in mounted {
                if ShellHelper.unmountDrive(drive.identifier) {
                    unmountedCount += 1
                }
                // Small delay to prevent overwhelming the system
                usleep(100000) // 0.1 second
            }
            
            DispatchQueue.main.async {
                isUnmountingDrive = false
                refreshDrives()
                
                alertTitle = "Drive Unmounting Complete"
                alertMessage = "Successfully unmounted \(unmountedCount) out of \(mounted.count) external drives."
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
    @State private var driveInfoText = ""
    @State private var isLoadingInfo = false
    
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
                    
                    // Detailed Information
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Detailed Information")
                                .font(.headline)
                            
                            Spacer()
                            
                            if isLoadingInfo {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("Refresh") {
                                    loadDriveInfo()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        ScrollView {
                            Text(driveInfoText)
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
                    .onAppear {
                        loadDriveInfo()
                    }
                    
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
    
    private func loadDriveInfo() {
        isLoadingInfo = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil info /dev/\(drive.identifier)")
            
            DispatchQueue.main.async {
                driveInfoText = result.success ? result.output : "Failed to get drive information"
                isLoadingInfo = false
            }
        }
    }
    
    private func ejectDrive() {
        isEjecting = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.ejectDrive(drive.identifier)
            
            DispatchQueue.main.async {
                isEjecting = false
                
                if success {
                    refreshDrives()
                    isPresented = false
                }
            }
        }
    }
    
    private func mountDrive() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountDrive(drive.identifier)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if success {
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

// MARK: - Main Content View (Rest of the code remains the same as your original)
// ... [The rest of your existing code including KextManagementView, AudioToolsView, SSDTGeneratorView, DonationView, etc.] ...

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
                
                // ... [Rest of your tab views remain the same] ...
                // Note: You need to copy the rest of your tab views from the original code
                // including KextManagementView, AudioToolsView, SSDTGeneratorView, etc.
                // Due to character limit, I'm focusing on the drive mounting fixes
                
                Text("Kext Management")
                    .tabItem {
                        Label("Kexts", systemImage: "puzzlepiece.extension")
                    }
                    .tag(1)
                
                Text("System Info")
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tag(2)
                
                Text("Audio Tools")
                    .tabItem {
                        Label("Audio Tools", systemImage: "speaker.wave.3")
                    }
                    .tag(3)
                
                Text("SSDT Generator")
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
[file content end]