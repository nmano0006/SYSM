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
    
    static func mountEFIPartition() -> Bool {
        print("=== Starting EFI Mount from USB Boot ===")
        
        let checkResult = runCommand("""
                mount | grep -i 'efi\\|/dev/disk.*s1' | head -1
                """)
        
        if checkResult.success && !checkResult.output.isEmpty {
            print("EFI already mounted: \(checkResult.output)")
            return true
        }
        
        let listResult = runCommand("""
        diskutil list | grep -E '^/dev/disk' | grep -o 'disk[0-9]*' | sort | uniq
        """)
        
        if !listResult.success {
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
        
        for disk in disks {
            print("\n--- Checking disk: \(disk) ---")
            
            let diskInfo = runCommand("diskutil info /dev/\(disk) 2>/dev/null")
            if !diskInfo.success {
                print("Cannot get info for \(disk)")
                continue
            }
            
            let s1Partition = "\(disk)s1"
            print("Trying partition: \(s1Partition)")
            
            let partInfo = runCommand("diskutil info /dev/\(s1Partition) 2>/dev/null")
            if partInfo.success {
                let isEFI = partInfo.output.lowercased().contains("efi") || 
                           partInfo.output.contains("EFI") || 
                           partInfo.output.contains("Apple_Boot")
                
                if isEFI {
                    print("Found EFI partition: \(s1Partition)")
                    
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
    
    static func getAllDrives() -> [DriveInfo] {
        print("=== Getting all drives with enhanced USB detection ===")
        
        var drives: [DriveInfo] = []
        
        let plistResult = runCommand("diskutil list -plist 2>/dev/null")
        if plistResult.success, let data = plistResult.output.data(using: .utf8) {
            drives = parsePlistDiskData(data)
        }
        
        if drives.isEmpty {
            print("Plist method failed, trying text parsing...")
            let textResult = runCommand("diskutil list")
            if textResult.success {
                drives = parseTextDiskOutput(textResult.output)
            }
        }
        
        if drives.isEmpty {
            print("Text parsing failed, trying system_profiler...")
            drives = getDrivesFromSystemProfiler()
        }
        
        print("Running enhanced USB detection...")
        let usbDrives = getUSBDrivesEnhanced()
        drives.append(contentsOf: usbDrives)
        
        if drives.isEmpty {
            print("All methods failed, checking mounted volumes...")
            drives = getDrivesFromMountedVolumes()
        }
        
        drives = removeDuplicateDrives(drives)
        
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
    
    private static func getUSBDrivesEnhanced() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
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
                
                let infoResult = runCommand("diskutil info \(disk) 2>/dev/null")
                if infoResult.success {
                    let info = parseDiskInfo(infoResult.output)
                    
                    drives.append(DriveInfo(
                        name: info.name,
                        identifier: diskName,
                        size: info.size,
                        type: "USB (\(info.protocol))",
                        mountPoint: info.mountPoint,
                        isInternal: false,
                        isEFI: diskName.contains("s1") && (info.name.contains("EFI") || info.type.contains("EFI")),
                        partitions: info.partitions
                    ))
                }
            }
        }
        
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
                        
                        if let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]] {
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
                            let isInternal = isDiskInternal(deviceIdentifier)
                            
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
            
            if trimmedLine.hasPrefix("/dev/disk") && trimmedLine.contains(":") {
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
                
                let components = trimmedLine.components(separatedBy: ":")
                if components.count >= 1 {
                    let diskPart = components[0].trimmingCharacters(in: .whitespaces)
                    if let diskMatch = diskPart.range(of: "disk[0-9]+", options: .regularExpression) {
                        currentDisk.identifier = String(diskPart[diskMatch])
                    }
                    
                    currentDisk.isUSB = trimmedLine.lowercased().contains("external") || 
                                       trimmedLine.lowercased().contains("usb") ||
                                       trimmedLine.lowercased().contains("removable")
                    
                    if let sizeRange = trimmedLine.range(of: "[0-9]+\\.[0-9]+ [GT]B", options: .regularExpression) {
                        currentDisk.size = String(trimmedLine[sizeRange])
                    }
                    
                    if components.count >= 2 {
                        let description = components[1].trimmingCharacters(in: .whitespaces)
                        if !description.isEmpty {
                            let nameParts = description.components(separatedBy: ",")
                            if !nameParts.isEmpty {
                                currentDisk.name = nameParts[0].trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
                inDiskSection = true
            }
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
            else if trimmedLine.isEmpty && inDiskSection {
                inDiskSection = false
            }
        }
        
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
                
                if let diskMatch = device.range(of: "disk[0-9]+", options: .regularExpression) {
                    let diskId = String(device[diskMatch])
                    let isInternal = !mountPoint.hasPrefix("/Volumes") || mountPoint == "/"
                    
                    let nameResult = runCommand("basename \"\(mountPoint)\"")
                    let name = nameResult.success && !nameResult.output.isEmpty ? 
                              nameResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : 
                              "Volume \(diskCount)"
                    
                    let sizeResult = runCommand("df -h \"\(mountPoint)\" | tail -1 | awk '{print $2}'")
                    let size = sizeResult.success && !sizeResult.output.isEmpty ? 
                              sizeResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : 
                              "Unknown"
                    
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
        if identifier == "disk0" || identifier == "disk1" {
            return true
        }
        
        let usbCheck = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep -i 'protocol.*usb'")
        if usbCheck.success && !usbCheck.output.isEmpty {
            return false
        }
        
        let mountCheck = runCommand("mount | grep '/dev/\(identifier)' | grep ' / '")
        if mountCheck.success {
            return true
        }
        
        let apfsCheck = runCommand("diskutil info /dev/\(identifier) 2>/dev/null | grep -i 'apfs'")
        if apfsCheck.success && !apfsCheck.output.isEmpty {
            return true
        }
        
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
    
    static func getCompleteSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
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
        
        let sysInfo = getCompleteSystemInfo()
        
        diagnostics += "--- System Information ---\n"
        diagnostics += "macOS Version: \(sysInfo.macOSVersion)\n"
        diagnostics += "Build Number: \(sysInfo.buildNumber)\n"
        diagnostics += "Kernel Version: \(sysInfo.kernelVersion)\n"
        diagnostics += "Model Identifier: \(sysInfo.modelIdentifier)\n"
        diagnostics += "Processor: \(sysInfo.processor)\n"
        diagnostics += "Memory: \(sysInfo.memory)\n"
        diagnostics += "Boot Mode: \(sysInfo.bootMode)\n"
        diagnostics += "SIP Status: \(isSIPDisabled() ? "Disabled" : "Enabled")\n\n"
        
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
        case 1: return generateJSON()
        case 2: return generateHTML()
        default: return generatePlainText()
        }
    }
    
    private func generatePlainText() -> String {
        return ShellHelper.getCompleteDiagnostics()
    }
    
    private func generateJSON() -> String {
        var json: [String: Any] = [:]
        
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
        
        let content = generateExportContent()
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export System Information"
        savePanel.nameFieldLabel = "Export As:"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        var fileName = "SystemMaintenance_Report_\(timestamp)"
        var fileExtension = "txt"
        
        switch exportFormat {
        case 1: fileExtension = "json"
        case 2: fileExtension = "html"
        default: fileExtension = "txt"
        }
        
        fileName = "\(fileName).\(fileExtension)"
        savePanel.nameFieldStringValue = fileName
        
        if exportFormat == 1 {
            savePanel.allowedContentTypes = [.json]
        } else if exportFormat == 2 {
            savePanel.allowedContentTypes = [.html]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }
        
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    
                    exportMessage = "✅ Report exported successfully to:\n\(url.lastPathComponent)"
                    exportMessageColor = .green
                    
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    
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
                if showDonationButton {
                    supportBanner
                }
                
                warningBanner
                
                drivesOverviewSection
                
                appleHDAInstallationCard
                
                efiMountingSection
                
                maintenanceGrid
                
                if isDownloadingKDK {
                    downloadProgressView
                }
                
                if let efiPath = efiPath {
                    efiStatusSection(efiPath: efiPath)
                }
                
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
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if downloadProgress < 100 {
                downloadProgress += 2
            } else {
                timer.invalidate()
                isDownloadingKDK = false
                
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
    
    private func refreshUSBDrives() {
        isLoadingDrives = true
        
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
        
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
                isLoadingDrives = false
                
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

// MARK: - Enhanced SSDT Generator View
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
    @State private var includeCompilation = true
    @State private var compilationResult = ""
    @State private var selectedMotherboardPreset = "Auto"
    @State private var gpuConnectorType = "PCIe x16"
    @State private var gpuMemorySize = "8"
    @State private var useGpuSpoof = false
    @State private var spoofDeviceID = "0x67DF"
    
    let deviceTypes = ["CPU", "GPU", "Motherboard", "USB", "Other"]
    
    let cpuModels = ["Intel Core i5", "Intel Core i7", "Intel Core i9", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9", "Custom"]
    
    let gpuModels = [
        // Intel Integrated Graphics
        "Intel UHD Graphics 630", "Intel UHD Graphics 730", "Intel UHD Graphics 750", 
        "Intel UHD Graphics 770", "Intel Iris Xe Graphics", "Intel HD Graphics 530",
        "Intel HD Graphics 630", "Intel Iris Graphics 550", "Intel Iris Plus Graphics",
        
        // AMD Radeon
        "AMD Radeon RX 560", "AMD Radeon RX 570", "AMD Radeon RX 580", 
        "AMD Radeon RX 590", "AMD Radeon RX 5500 XT", "AMD Radeon RX 5600 XT",
        "AMD Radeon RX 5700", "AMD Radeon RX 5700 XT", "AMD Radeon RX 6600",
        "AMD Radeon RX 6600 XT", "AMD Radeon RX 6700 XT", "AMD Radeon RX 6800",
        "AMD Radeon RX 6800 XT", "AMD Radeon RX 6900 XT", "AMD Radeon RX 7900 XT",
        "AMD Radeon Vega 56", "AMD Radeon Vega 64", "AMD Radeon Pro W5700",
        "AMD Radeon Pro W6800", "AMD Radeon RX 550", "AMD Radeon RX 460",
        "AMD Radeon RX 470", "AMD Radeon RX 480",
        
        // NVIDIA (Limited support)
        "NVIDIA GeForce GT 710", "NVIDIA GeForce GT 730", "NVIDIA GeForce GT 1030",
        "NVIDIA GeForce GTX 1050", "NVIDIA GeForce GTX 1050 Ti", "NVIDIA GeForce GTX 1060",
        "NVIDIA GeForce GTX 1070", "NVIDIA GeForce GTX 1070 Ti", "NVIDIA GeForce GTX 1080",
        "NVIDIA GeForce GTX 1080 Ti", "NVIDIA GeForce GTX 1650", "NVIDIA GeForce GTX 1660",
        "NVIDIA GeForce GTX 1660 Ti", "NVIDIA GeForce GTX 1660 Super", "NVIDIA Quadro P400",
        "NVIDIA Quadro P620", "NVIDIA Quadro P1000", "NVIDIA Quadro P2000",
        
        // Custom
        "Custom/Other GPU", "Dual GPU Setup", "Multiple GPUs", "APU Only"
    ]
    
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
        "Gigabyte Z690 AERO G",
        "Gigabyte Z690 GAMING X DDR4",
        
        "Gigabyte Z790 AORUS ELITE AX",
        "Gigabyte Z790 GAMING X AX",
        "Gigabyte Z790 UD AC",
        "Gigabyte Z790 AORUS MASTER",
        
        // ASUS
        "ASUS PRIME Z390-A",
        "ASUS PRIME Z390-P",
        "ASUS ROG STRIX Z390-E GAMING",
        "ASUS ROG STRIX Z390-F GAMING",
        "ASUS ROG STRIX Z390-H GAMING",
        "ASUS ROG STRIX Z390-I GAMING",
        "ASUS ROG MAXIMUS XI HERO",
        "ASUS ROG MAXIMUS XI CODE",
        "ASUS ROG MAXIMUS XI FORMULA",
        "ASUS TUF Z390-PLUS GAMING",
        
        "ASUS PRIME Z490-A",
        "ASUS ROG STRIX Z490-E GAMING",
        "ASUS ROG STRIX Z490-F GAMING",
        "ASUS ROG STRIX Z490-H GAMING",
        "ASUS ROG STRIX Z490-I GAMING",
        "ASUS TUF GAMING Z490-PLUS",
        
        // MSI
        "MSI MPG Z390 GAMING PRO CARBON",
        "MSI MPG Z390 GAMING EDGE AC",
        "MSI MPG Z390 GAMING PLUS",
        "MSI MAG Z390 TOMAHAWK",
        "MSI MAG Z390M MORTAR",
        "MSI MEG Z390 ACE",
        "MSI MEG Z390 GODLIKE",
        
        // ASRock
        "ASRock Z390 Phantom Gaming 4",
        "ASRock Z390 Phantom Gaming 4S",
        "ASRock Z390 Phantom Gaming SLI",
        "ASRock Z390 Pro4",
        "ASRock Z390 Steel Legend",
        "ASRock Z390 Taichi",
        
        // Dell
        "Dell OptiPlex 7010",
        "Dell OptiPlex 7020",
        "Dell OptiPlex 7050",
        "Dell OptiPlex 7060",
        "Dell OptiPlex 7070",
        "Dell OptiPlex 7080",
        "Dell OptiPlex 7090",
        
        // HP
        "HP EliteDesk 800 G1",
        "HP EliteDesk 800 G2",
        "HP EliteDesk 800 G3",
        "HP EliteDesk 800 G4",
        "HP EliteDesk 800 G5",
        "HP EliteDesk 800 G6",
        
        // Lenovo
        "Lenovo ThinkCentre M93p",
        "Lenovo ThinkCentre M73",
        "Lenovo ThinkCentre M83",
        "Lenovo ThinkCentre M900",
        "Lenovo ThinkCentre M910",
        "Lenovo ThinkCentre M920",
        "Lenovo ThinkCentre M920q",
        
        // Intel NUC
        "Intel NUC8i7BEH",
        "Intel NUC8i5BEH",
        "Intel NUC8i3BEH",
        
        // Other
        "Custom Build",
        "Other/Unknown Motherboard",
        "Generic Desktop PC",
        "All-in-One PC",
        "Mini PC",
        "Laptop"
    ]
    
    let motherboardPresets = [
        "Auto", "Gigabyte Z390", "ASUS Z390", "MSI Z390", "ASRock Z390",
        "Gigabyte Z490", "ASUS Z490", "MSI Z490",
        "Dell OptiPlex", "HP EliteDesk", "Lenovo ThinkCentre",
        "Laptop", "Custom"
    ]
    
    let usbPortCounts = ["5", "7", "9", "11", "13", "15", "20", "25", "30", "Custom"]
    
    let gpuConnectorTypes = ["PCIe x16", "PCIe x8", "PCIe x4", "PCIe x1", "Integrated"]
    let gpuMemorySizes = ["1", "2", "3", "4", "6", "8", "11", "12", "16", "24"]
    
    let ssdtTemplates = [
        "CPU": [
            "SSDT-PLUG": "CPU Power Management (Essential)",
            "SSDT-EC-USBX": "Embedded Controller Fix (Essential)",
            "SSDT-AWAC": "AWAC Clock Fix (300+ Series)",
            "SSDT-PMC": "NVRAM Support (300+ Series)",
            "SSDT-RTC0": "RTC Fix",
            "SSDT-PTSWAK": "Sleep/Wake Fix",
            "SSDT-PM": "CPU Power Management",
            "SSDT-CPUR": "CPU Renaming",
            "SSDT-XCPM": "XCPM Power Management",
            "SSDT-PLNF": "CPU Performance States",
            "SSDT-CPU0": "CPU Device Properties",
            "SSDT-LANC": "CPU Cache Configuration"
        ],
        "GPU": [
            "SSDT-GPU-DISABLE": "Disable Unused GPU (iGPU+dGPU)",
            "SSDT-GPU-PCI": "GPU PCI Properties and Renaming",
            "SSDT-IGPU": "Intel Integrated Graphics (Essential)",
            "SSDT-DGPU": "Discrete GPU Power Management",
            "SSDT-PEG0": "PCIe Graphics Slot Configuration",
            "SSDT-NDGP": "NVIDIA GPU Power Management",
            "SSDT-AMDGPU": "AMD GPU Power Management",
            "SSDT-GPIO": "GPU Power/Backlight GPIO Pins",
            "SSDT-PNLF": "Backlight Control (Laptops)",
            "SSDT-GFX0": "Graphics Device Renaming"
        ],
        "Motherboard": [
            "SSDT-XOSI": "Windows OSI Method (Essential)",
            "SSDT-ALS0": "Ambient Light Sensor (Laptops)",
            "SSDT-HID": "Keyboard/Mouse Devices",
            "SSDT-SBUS": "SMBus Controller",
            "SSDT-DMAC": "DMA Controller",
            "SSDT-MEM2": "Memory Controller",
            "SSDT-PMCR": "Power Management Controller",
            "SSDT-LPCB": "LPC Bridge Controller",
            "SSDT-PPMC": "Platform Power Management",
            "SSDT-PWRB": "Power Button",
            "SSDT-SLPB": "Sleep Button",
            "SSDT-FWHD": "Firmware Hub Device",
            "SSDT-PCIB": "PCI Bridge",
            "SSDT-PCI0": "PCI Root Bridge",
            "SSDT-SATA": "SATA Controller (AHCI)",
            "SSDT-NVME": "NVMe Controller Power Management",
            "SSDT-RTC0": "Real Time Clock Fix",
            "SSDT-TMR": "Timer Fix",
            "SSDT-PIC": "Programmable Interrupt Controller"
        ],
        "USB": [
            "SSDT-USBX": "USB Power Properties (Essential)",
            "SSDT-UIAC": "USB Port Mapping (Essential)",
            "SSDT-EHCx": "USB 2.0 Controller Renaming",
            "SSDT-XHCI": "XHCI Controller (USB 3.0+)",
            "SSDT-RHUB": "USB Root Hub",
            "SSDT-XHC": "XHCI Extended Controller",
            "SSDT-PRT": "USB Port Renaming",
            "SSDT-USB-PWR": "USB Port Power Management",
            "SSDT-TYPEC": "USB Type-C Port Configuration",
            "SSDT-TB3": "Thunderbolt 3 Support"
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                                VStack(alignment: .leading, spacing: 4) {
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
                                    
                                    // GPU Configuration Options
                                    if selectedDeviceType == "GPU" {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Connector")
                                                    .font(.caption2)
                                                Picker("", selection: $gpuConnectorType) {
                                                    ForEach(gpuConnectorTypes, id: \.self) { type in
                                                        Text(type).tag(type)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                                .frame(width: 100)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Memory (GB)")
                                                    .font(.caption2)
                                                Picker("", selection: $gpuMemorySize) {
                                                    ForEach(gpuMemorySizes, id: \.self) { size in
                                                        Text(size).tag(size)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                                .frame(width: 80)
                                            }
                                            
                                            Toggle("Spoof ID", isOn: $useGpuSpoof)
                                                .toggleStyle(.switch)
                                                .font(.caption2)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
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
                                    
                                    HStack {
                                        Text("Preset:")
                                            .font(.caption2)
                                        Picker("", selection: $selectedMotherboardPreset) {
                                            ForEach(motherboardPresets, id: \.self) { preset in
                                                Text(preset).tag(preset)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 150)
                                        .onChange(of: selectedMotherboardPreset) { newValue in
                                            applyMotherboardPreset(newValue)
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
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
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
                            
                            Toggle("Compile DSL to AML (requires iasl)", isOn: $includeCompilation)
                                .toggleStyle(.switch)
                                .font(.caption)
                            
                            if !compilationResult.isEmpty {
                                ScrollView {
                                    Text(compilationResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                .frame(height: 80)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
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
                
                if !generatedSSDTs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Generated Files")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Open Folder") {
                                openGeneratedFolder()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(generatedSSDTs, id: \.self) { ssdt in
                                    HStack {
                                        Image(systemName: ssdt.hasSuffix(".aml") ? "cpu.fill" : "doc.text.fill")
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
            }
            .padding()
        }
    }
    
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
        compilationResult = ""
        
        var ssdtsToGenerate: [String] = []
        
        if useEC { ssdtsToGenerate.append("SSDT-EC") }
        if useAWAC { ssdtsToGenerate.append("SSDT-AWAC") }
        if usePLUG { ssdtsToGenerate.append("SSDT-PLUG") }
        if useXOSI { ssdtsToGenerate.append("SSDT-XOSI") }
        if useALS0 { ssdtsToGenerate.append("SSDT-ALS0") }
        if useHID { ssdtsToGenerate.append("SSDT-HID") }
        
        ssdtsToGenerate.append(contentsOf: selectedSSDTs)
        
        if ssdtsToGenerate.isEmpty {
            alertTitle = "No SSDTs Selected"
            alertMessage = "Please select at least one SSDT to generate.\n\nRecommended for \(motherboardModel):\n• SSDT-EC-USBX\n• SSDT-PLUG\n• SSDT-AWAC (for 300+ series)"
            showAlert = true
            isGenerating = false
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            let outputDir = self.getOutputDirectory()
            var finalOutputDir = outputDir
            var compilationMessages: [String] = []
            
            for (index, ssdt) in ssdtsToGenerate.enumerated() {
                let progress = Double(index + 1) / Double(ssdtsToGenerate.count) * 100
                DispatchQueue.main.async {
                    generationProgress = progress
                }
                
                let dslFilename = "\(ssdt).dsl"
                let dslFilePath = "\(outputDir)/\(dslFilename)"
                
                let dslContent = self.generateValidDSLContent(for: ssdt)
                
                do {
                    try dslContent.write(toFile: dslFilePath, atomically: true, encoding: .utf8)
                    
                    DispatchQueue.main.async {
                        generatedSSDTs.append(dslFilename)
                    }
                    
                    if includeCompilation {
                        let amlFilename = "\(ssdt).aml"
                        let amlFilePath = "\(outputDir)/\(amlFilename)"
                        
                        let result = self.compileDSLToAML(dslPath: dslFilePath, amlPath: amlFilePath)
                        
                        if result.success {
                            compilationMessages.append("✅ \(ssdt): Compiled successfully")
                            DispatchQueue.main.async {
                                generatedSSDTs.append(amlFilename)
                            }
                        } else {
                            compilationMessages.append("⚠️ \(ssdt): Compilation failed - \(result.output)")
                        }
                    }
                } catch {
                    compilationMessages.append("❌ \(ssdt): Failed to create DSL file")
                }
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                generationProgress = 0
                
                compilationResult = compilationMessages.joined(separator: "\n")
                
                alertTitle = "SSDTs Generated"
                alertMessage = """
                Successfully generated \(generatedSSDTs.count) files for \(motherboardModel):
                
                • DSL source files: \(ssdtsToGenerate.count)
                • AML binary files: \(includeCompilation ? "\(compilationMessages.filter { $0.contains("✅") }.count)" : "Compilation disabled")
                
                📁 Files saved to: \(finalOutputDir)
                
                \(!compilationMessages.isEmpty ? "📊 Compilation Results:\n\(compilationResult)" : "")
                
                ⚠️ Important:
                These are template SSDTs. You MUST:
                1. Review and customize them for your specific hardware
                2. Test each SSDT individually
                3. Add to config.plist → ACPI → Add
                4. Rebuild kernel cache and restart
                """
                showAlert = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openGeneratedFolder()
                }
            }
        }
    }
    
    private func generateValidDSLContent(for ssdt: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var content = """
        /*
         * \(ssdt).dsl
         * Generated by SystemMaintenance
         * Date: \(dateFormatter.string(from: Date()))
         * Motherboard: \(motherboardModel)
         * Device Type: \(selectedDeviceType)
         * \(selectedDeviceType == "GPU" ? "GPU Model: \(gpuModel)" : selectedDeviceType == "CPU" ? "CPU Model: \(cpuModel)" : "")
         *
         * NOTE: This is a template. Customize for your hardware.
         * Refer to Dortania guides for implementation details.
         */
        
        DefinitionBlock ("", "SSDT", 2, "SYSM", "\(ssdt.replacingOccurrences(of: "SSDT-", with: ""))", 0x00000000)
        {
            // External references (if needed)
            External (_SB_.PCI0, DeviceObj)
            External (_SB_.PCI0.LPCB, DeviceObj)
            External (_SB_.PCI0.PEG0, DeviceObj)
            External (_SB_.PCI0.SAT0, DeviceObj)
            
            Scope (\\)
            {
                // DTGP method - required for _DSM methods
                Method (DTGP, 5, NotSerialized)
                {
                    If (LEqual (Arg0, Buffer (0x10)
                        {
                            /* 0000 */  0xC6, 0xB7, 0xB5, 0xA0, 0x18, 0x13, 0x1C, 0x44,
                            /* 0008 */  0xB0, 0xC9, 0xFE, 0x69, 0x5E, 0xAF, 0x94, 0x9B
                        }))
                    {
                        If (LEqual (Arg1, One))
                        {
                            If (LEqual (Arg2, 0x03))
                            {
                                If (LEqual (Arg3, Buffer (0x04)
                                    {
                                        0x00, 0x00, 0x00, 0x03
                                    }))
                                {
                                    If (LEqual (Arg4, Zero))
                                    {
                                        Return (Buffer (One) { 0x03 })
                                    }
                                }
                            }
                        }
                    }
                    
                    Return (Buffer (One) { 0x00 })
                }
            }
        """
        
        if ssdt == "SSDT-EC" || ssdt == "SSDT-EC-USBX" {
            content += """
            
                Scope (_SB.PCI0.LPCB)
                {
                    Device (EC0)
                    {
                        Name (_HID, EisaId ("ACID0001"))
                        Name (_CID, "PNP0C09")
                        Name (_UID, Zero)
                        
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0B)
                            }
                            
                            Return (Zero)
                        }
                        
                        OperationRegion (ERAM, EmbeddedControl, Zero, 0xFF)
                        Field (ERAM, ByteAcc, NoLock, Preserve)
                        {
                            AccessAs (BufferAcc, 0x01),
                            Offset (0x60),
                            ECDV,   8,
                            Offset (0x62),
                            ECFL,   8
                        }
                    }
                }
            """
        }
        
        if ssdt == "SSDT-EC-USBX" {
            content += """
            
                Device (_SB.PCI0.XHC)
                {
                    Name (_ADR, Zero)
                    
                    Method (_DSM, 4, Serialized)
                    {
                        If (LEqual (Arg2, Zero))
                        {
                            Return (Buffer (One) { 0x03 })
                        }
                        
                        Return (Package (0x06)
                        {
                            "usb-connector-type",
                            0,
                            "port-count",
                            Buffer (0x04)
                            {
                                0x\(String(format: "%02X", Int(usbPortCount) ?? 15)), 0x00, 0x00, 0x00
                            },
                            "model",
                            Buffer () { "USB XHCI Controller" }
                        })
                    }
                }
            """
        }
        
        if ssdt == "SSDT-PLUG" {
            content += """
            
                External (_SB_.PR00, ProcessorObj)
                External (_SB_.PR01, ProcessorObj)
                
                Scope (_SB.PR00)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x02)
                        {
                            "plugin-type",
                            One
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
                
                Scope (_SB.PR01)
                {
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x02)
                        {
                            "plugin-type",
                            One
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            """
        }
        
        if ssdt == "SSDT-AWAC" {
            content += """
            
                Scope (_SB.PCI0)
                {
                    Device (RTC0)
                    {
                        Name (_HID, EisaId ("PNP0B00"))
                        Name (_CRS, ResourceTemplate ()
                        {
                            IO (Decode16,
                                0x0070,
                                0x0070,
                                0x01,
                                0x08,
                                )
                            IRQNoFlags ()
                                {8}
                        })
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (0x0F)
                            }
                            
                            Return (Zero)
                        }
                    }
                    
                    Device (AWAC)
                    {
                        Name (_HID, "ACPI000E")
                        Method (_STA, 0, NotSerialized)
                        {
                            If (_OSI ("Darwin"))
                            {
                                Return (Zero)
                            }
                            
                            Return (0x0F)
                        }
                    }
                }
            """
        }
        
        if ssdt == "SSDT-XOSI" {
            content += """
            
                Method (XOSI, 1, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        If (LEqual (Arg0, "Windows 2009"))
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2012"))
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2013"))
                        {
                            Return (One)
                        }
                        
                        If (LEqual (Arg0, "Windows 2015"))
                        {
                            Return (One)
                        }
                    }
                    
                    Return (Zero)
                }
            """
        }
        
        if ssdt == "SSDT-IGPU" {
            content += generateIGPUSSDT()
        }
        
        if ssdt == "SSDT-DGPU" {
            content += generateDGPUSSDT()
        }
        
        if ssdt == "SSDT-GPU-DISABLE" {
            content += generateGPUDisableSSDT()
        }
        
        if ssdt == "SSDT-SATA" {
            content += generateSATASSDT()
        }
        
        if ssdt == "SSDT-NVME" {
            content += generateNVMESSDT()
        }
        
        if ssdt == "SSDT-LPCB" {
            content += generateLPCBSSDT()
        }
        
        content += "\n}"
        
        return content
    }
    
    private func generateIGPUSSDT() -> String {
        return """
        
            Scope (_SB.PCI0.IGPU)
            {
                Method (_DSM, 4, Serialized)
                {
                    Store (Package (0x0E)
                    {
                        "AAPL,ig-platform-id", 
                        Buffer (0x04) { 0x07, 0x00, 0x66, 0x01 },
                        "model", 
                        Buffer () { "Intel UHD Graphics 630" },
                        "hda-gfx", 
                        Buffer () { "onboard-1" },
                        "AAPL,slot-name", 
                        Buffer () { "Internal" },
                        "built-in", 
                        Buffer () { 0x01 },
                        "device_type", 
                        Buffer () { "VGA compatible controller" },
                        "AAPL,HasPanel", 
                        Buffer () { 0x01 },
                        "AAPL,HasLid", 
                        Buffer () { 0x01 },
                        "framebuffer-patch-enable", 
                        Buffer () { 0x01 },
                        "framebuffer-stolenmem", 
                        Buffer (0x04) { 0x00, 0x00, 0x03, 0x00 },
                        "framebuffer-fbmem", 
                        Buffer (0x04) { 0x00, 0x00, 0x03, 0x00 }
                    }, Local0)
                    
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
        """
    }
    
    private func generateDGPUSSDT() -> String {
        var platformID = "0x67DF0008"
        var deviceName = "AMD Radeon RX 580"
        
        if gpuModel.contains("RX 5700") {
            platformID = "0x730F0001"
            deviceName = "AMD Radeon RX 5700 XT"
        } else if gpuModel.contains("RX 6600") {
            platformID = "0x73FF0001"
            deviceName = "AMD Radeon RX 6600 XT"
        } else if gpuModel.contains("RX 6800") {
            platformID = "0x73BF0001"
            deviceName = "AMD Radeon RX 6800 XT"
        } else if gpuModel.contains("NVIDIA") {
            return """
            
                Scope (_SB.PCI0.PEG0.PEGP)
                {
                    Name (_ADR, 0x00010000)
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x08)
                        {
                            "model", 
                            Buffer () { "\(gpuModel)" },
                            "AAPL,slot-name", 
                            Buffer () { "PCIe Slot 1" },
                            "@0,built-in", 
                            Buffer () { 0x00 },
                            "@1,built-in", 
                            Buffer () { 0x00 },
                            "@2,built-in", 
                            Buffer () { 0x00 },
                            "@3,built-in", 
                            Buffer () { 0x00 },
                            "device_type", 
                            Buffer () { "VGA compatible controller" }
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            """
        }
        
        return """
        
            Scope (_SB.PCI0.PEG0.PEGP)
            {
                Name (_ADR, 0x00010000)
                Method (_DSM, 4, Serialized)
                {
                    Store (Package (0x0C)
                    {
                        "AAPL,slot-name", 
                        Buffer () { "PCIe Slot 1" },
                        "@0,built-in", 
                        Buffer () { 0x00 },
                        "@1,built-in", 
                        Buffer () { 0x00 },
                        "@2,built-in", 
                        Buffer () { 0x00 },
                        "@3,built-in", 
                        Buffer () { 0x00 },
                        "model", 
                        Buffer () { "\(deviceName)" },
                        "hda-gfx", 
                        Buffer () { "onboard-2" },
                        "device_type", 
                        Buffer () { "VGA compatible controller" },
                        "AAPL,aux-power-connected", 
                        Buffer () { 0x01 },
                        "AAPL,slot-name", 
                        Buffer () { "PCIe Slot x16" },
                        "ATY,PlatformInfo", 
                        Buffer (0x80)
                        {
                            /* 0000 */  0x01, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00,
                            /* 0008 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    }, Local0)
                    
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
        """
    }
    
    private func generateGPUDisableSSDT() -> String {
        return """
        
            Scope (_SB.PCI0.PEG0)
            {
                Method (_INI, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Store (Zero, \\_SB.PCI0.PEG0.PEGP._STA)
                    }
                }
            }
            
            Scope (_SB.PCI0.PEG0.PEGP)
            {
                Method (_STA, 0, NotSerialized)
                {
                    If (_OSI ("Darwin"))
                    {
                        Return (Zero)
                    }
                    Else
                    {
                        Return (0x0F)
                    }
                }
            }
        """
    }
    
    private func generateSATASSDT() -> String {
        return """
        
            Scope (_SB.PCI0.SAT0)
            {
                Method (_DSM, 4, Serialized)
                {
                    Store (Package (0x08)
                    {
                        "device-id", 
                        Buffer (0x04) { 0x92, 0x3E, 0x00, 0x00 },
                        "model", 
                        Buffer () { "Intel 300 Series Chipset SATA Controller" },
                        "AAPL,slot-name", 
                        Buffer () { "Internal" },
                        "built-in", 
                        Buffer () { 0x01 },
                        "pci-aspm-default", 
                        Buffer () { 0x00 },
                        "max-port-speed", 
                        Buffer () { 0x03 }
                    }, Local0)
                    
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                    }
            }
        """
    }
    
    private func generateNVMESSDT() -> String {
        return """
        
            Scope (_SB.PCI0.RP01)
            {
                Device (PXSX)
                {
                    Name (_ADR, 0x00000000)
                    Method (_DSM, 4, Serialized)
                    {
                        Store (Package (0x0A)
                        {
                            "class-code", 
                            Buffer (0x04) { 0xFF, 0x08, 0x01, 0x00 },
                            "device-id", 
                            Buffer (0x02) { 0xF1, 0x15 },
                            "vendor-id", 
                            Buffer (0x02) { 0x86, 0x80 },
                            "subsystem-id", 
                            Buffer (0x02) { 0x00, 0x00 },
                            "subsystem-vendor-id", 
                            Buffer (0x02) { 0x00, 0x00 },
                            "IOName", 
                            "pci-bridge",
                            "name", 
                            "pci-bridge",
                            "AAPL,slot-name", 
                            Buffer () { "M.2 NVMe Slot" }
                        }, Local0)
                        
                        DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                        Return (Local0)
                    }
                }
            }
        """
    }
    
    private func generateLPCBSSDT() -> String {
        return """
        
            Scope (_SB.PCI0.LPCB)
            {
                Method (_DSM, 4, Serialized)
                {
                    Store (Package (0x06)
                    {
                        "device-id", 
                        Buffer (0x04) { 0x8C, 0x9C, 0x00, 0x00 },
                        "name", 
                        Buffer () { "LPC Controller" },
                        "compatible", 
                        Buffer () { "pci8086,9c43" },
                        "AAPL,clock-id", 
                        Buffer (0x01) { 0x01 },
                        "built-in", 
                        Buffer (0x01) { 0x01 }
                    }, Local0)
                    
                    DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
                    Return (Local0)
                }
            }
        """
    }
    
    private func compileDSLToAML(dslPath: String, amlPath: String) -> (success: Bool, output: String) {
        let checkResult = ShellHelper.runCommand("which iasl")
        if !checkResult.success {
            return (false, "iasl compiler not found. Install with: brew install acpica")
        }
        
        let compileResult = ShellHelper.runCommand("iasl \"\(dslPath)\"")
        
        if compileResult.success {
            let compiledAMLPath = dslPath.replacingOccurrences(of: ".dsl", with: ".aml")
            let moveResult = ShellHelper.runCommand("mv \"\(compiledAMLPath)\" \"\(amlPath)\"")
            
            if moveResult.success {
                return (true, "Compiled successfully")
            } else {
                return (false, "Failed to move compiled file: \(moveResult.output)")
            }
        } else {
            return (false, "Compilation failed: \(compileResult.output)")
        }
    }
    
    private func getOutputDirectory() -> String {
        if !outputPath.isEmpty {
            return outputPath
        }
        
        let desktopPath = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
        
        if let desktopPath = desktopPath {
            let ssdtDir = desktopPath + "/Generated_SSDTs"
            
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: ssdtDir) {
                do {
                    try fileManager.createDirectory(atPath: ssdtDir, withIntermediateDirectories: true, attributes: nil)
                    print("Created directory: \(ssdtDir)")
                } catch {
                    print("Failed to create directory: \(error)")
                    return NSHomeDirectory() + "/Generated_SSDTs"
                }
            }
            return ssdtDir
        }
        
        return NSHomeDirectory() + "/Generated_SSDTs"
    }
    
    private func openGeneratedFolder() {
        let outputDir = getOutputDirectory()
        let url = URL(fileURLWithPath: outputDir)
        
        if FileManager.default.fileExists(atPath: outputDir) {
            NSWorkspace.shared.open(url)
        } else {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.open(url)
            } catch {
                print("Failed to create/open folder: \(error)")
            }
        }
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
            
            let iaslCheck = ShellHelper.runCommand("which iasl")
            validationMessages.append(iaslCheck.success ? "✅ iasl compiler found" : "❌ iasl compiler not found")
            
            if iaslCheck.success {
                let outputDir = self.getOutputDirectory()
                let fileManager = FileManager.default
                
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                    let dslFiles = files.filter { $0.hasSuffix(".dsl") }
                    
                    if dslFiles.isEmpty {
                        validationMessages.append("⚠️ No DSL files found to validate")
                    } else {
                        validationMessages.append("\nValidating \(dslFiles.count) DSL files:")
                        
                        for dslFile in dslFiles {
                            let filePath = "\(outputDir)/\(dslFile)"
                            let validateResult = ShellHelper.runCommand("iasl -vs \"\(filePath)\"")
                            
                            if validateResult.success {
                                validationMessages.append("✅ \(dslFile): Syntax OK")
                            } else {
                                let lines = validateResult.output.components(separatedBy: "\n")
                                let errors = lines.filter { $0.contains("Error") || $0.contains("error") }
                                validationMessages.append("❌ \(dslFile): \(errors.first ?? "Syntax error")")
                            }
                        }
                    }
                } catch {
                    validationMessages.append("❌ Failed to read output directory: \(error.localizedDescription)")
                }
            }
            
            validationMessages.append("\nCommon Issues to Check:")
            validationMessages.append("• All SSDTs must have valid DefinitionBlock")
            validationMessages.append("• Method names must follow ACPI naming conventions")
            validationMessages.append("• External references must be declared")
            validationMessages.append("• Use proper scope (\\ for root, _SB for devices)")
            
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
            
            let _ = ShellHelper.runCommand("mkdir -p \"\(acpiPath)\"", needsSudo: true)
            
            let outputDir = self.getOutputDirectory()
            let fileManager = FileManager.default
            
            do {
                let files = try fileManager.contentsOfDirectory(atPath: outputDir)
                let amlFiles = files.filter { $0.hasSuffix(".aml") }
                
                if amlFiles.isEmpty {
                    installMessages.append("⚠️ No AML files found. Please compile DSL files first.")
                } else {
                    for amlFile in amlFiles {
                        let sourcePath = "\(outputDir)/\(amlFile)"
                        let destPath = "\(acpiPath)\(amlFile)"
                        
                        if fileManager.fileExists(atPath: sourcePath) {
                            let command = "cp \"\(sourcePath)\" \"\(destPath)\""
                            let result = ShellHelper.runCommand(command, needsSudo: true)
                            
                            if result.success {
                                installMessages.append("✅ \(amlFile)")
                                successCount += 1
                            } else {
                                installMessages.append("❌ \(amlFile): \(result.output)")
                                failCount += 1
                            }
                        } else {
                            installMessages.append("❌ \(amlFile): Source file not found")
                            failCount += 1
                        }
                    }
                }
            } catch {
                installMessages.append("❌ Failed to read output directory: \(error.localizedDescription)")
                failCount += 1
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Installation"
                installMessages.append("\n📊 Summary: \(successCount) AML files installed")
                
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
    
    private func applyMotherboardPreset(_ preset: String) {
        switch preset {
        case "Gigabyte Z390":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI"])
            useEC = true
            useAWAC = true
            usePLUG = true
            useXOSI = true
            motherboardModel = "Gigabyte Z390 AORUS PRO"
            
        case "ASUS Z390":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-AWAC", "SSDT-PMC", "SSDT-XOSI"])
            useEC = true
            useAWAC = true
            usePLUG = true
            useXOSI = true
            motherboardModel = "ASUS PRIME Z390-A"
            
        case "Laptop":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-PNLF", "SSDT-XOSI", "SSDT-TPAD"])
            useEC = true
            usePLUG = true
            useXOSI = true
            motherboardModel = "Laptop Configuration"
            
        case "Dell OptiPlex":
            selectedSSDTs = Set(["SSDT-EC-USBX", "SSDT-PLUG", "SSDT-RTC0", "SSDT-XOSI"])
            useEC = true
            usePLUG = true
            useXOSI = true
            motherboardModel = "Dell OptiPlex 7010"
            
        default:
            break
        }
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
                
                // Kext Management View would go here
                
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
                
                // Audio Tools View would go here
                
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
            // DonationView would go here
        }
        .sheet(isPresented: $showEFISelectionView) {
            // EFISelectionView would go here
        }
        .sheet(isPresented: $showDiskDetailView) {
            // DiskDetailView would go here
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(allDrives.filter { $0.isInternal }.count) Internal • \(allDrives.filter { !$0.isInternal }.count) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
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
                
                Button(action: {
                    showExportView = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Export System Information")
                
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}