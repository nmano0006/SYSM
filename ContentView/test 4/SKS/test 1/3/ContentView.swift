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
    
    // MARK: - USB Boot Specific Functions
    
    static func detectBootDrive() -> String? {
        print("=== Detecting Boot Drive ===")
        
        // Method 1: Check the root volume's parent disk
        let bootResult = runCommand("""
        mount | grep ' / ' | head -1 | awk '{print $1}' | \
        xargs -I {} diskutil info {} 2>/dev/null | \
        grep "Part of Whole" | awk '{print $4}' | \
        sed 's/disk//'
        """)
        
        if bootResult.success && !bootResult.output.isEmpty {
            let bootDiskNumber = bootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Boot disk number: \(bootDiskNumber)")
            return "disk\(bootDiskNumber)"
        }
        
        // Method 2: Look for USB devices specifically
        let usbCheck = runCommand("""
        diskutil list | grep -E '^/dev/disk[0-9]+' | awk '{print $1}' | while read disk; do
            # Get disk identifier without /dev/
            disk_id=$(basename "$disk")
            
            # Check if it's USB
            if diskutil info "$disk" 2>/dev/null | grep -qi "Protocol.*USB"; then
                echo "$disk_id"
                exit 0
            fi
        done
        """)
        
        if usbCheck.success && !usbCheck.output.isEmpty {
            let usbDisk = usbCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("USB boot disk detected: \(usbDisk)")
            return usbDisk
        }
        
        print("No boot drive detected")
        return nil
    }
    
    static func mountUSBEFI() -> Bool {
        print("=== Mounting USB EFI Partition ===")
        
        // First, detect if we're booting from USB
        guard let bootDisk = detectBootDrive() else {
            print("Could not detect boot disk")
            return false
        }
        
        print("Boot disk detected: \(bootDisk)")
        
        // Check if it's USB
        let usbCheck = runCommand("diskutil info /dev/\(bootDisk) 2>/dev/null | grep -i 'protocol.*usb'")
        let isUSB = usbCheck.success && !usbCheck.output.isEmpty
        
        if !isUSB {
            print("Not booting from USB")
            // Still try to mount first EFI partition
            return mountEFIPartition()
        }
        
        // We're booting from USB - find the EFI partition
        print("Looking for EFI partition on USB drive: \(bootDisk)")
        
        // List all partitions on the USB drive
        let partitionList = runCommand("""
        diskutil list /dev/\(bootDisk) | grep -E '^ +[0-9]+:' | while read line; do
            part_num=$(echo "$line" | awk '{print $1}' | sed 's/://')
            part_id="\(bootDisk)s$part_num"
            part_type=$(echo "$line" | grep -o 'EFI\\|Apple_Boot\\|Apple_APFS')
            
            if [ -n "$part_type" ]; then
                echo "$part_id"
                exit 0
            fi
        done
        """)
        
        var efiPartition: String?
        
        if partitionList.success && !partitionList.output.isEmpty {
            efiPartition = partitionList.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Found EFI partition: \(efiPartition!)")
        } else {
            // If no EFI partition found by type, try s1 as fallback
            efiPartition = "\(bootDisk)s1"
            print("No EFI partition found by type, trying default: \(efiPartition!)")
        }
        
        // Check if already mounted
        let checkResult = runCommand("""
        diskutil info /dev/\(efiPartition!) 2>/dev/null | \
        grep "Mount Point" | \
        awk -F': ' '{print $2}' | \
        xargs echo
        """)
        
        if checkResult.success && !checkResult.output.isEmpty && checkResult.output != "(Not Mounted)" {
            print("USB EFI already mounted at: \(checkResult.output)")
            return true
        }
        
        print("Attempting to mount USB EFI: \(efiPartition!)")
        
        // Try to mount with diskutil first
        let mountResult = runCommand("diskutil mount \(efiPartition!)", needsSudo: true)
        
        if mountResult.success {
            print("✅ Successfully mounted USB EFI: \(efiPartition!)")
            
            // Verify mount
            let verifyResult = runCommand("""
            diskutil info /dev/\(efiPartition!) 2>/dev/null | \
            grep "Mount Point" | \
            awk -F': ' '{print $2}' | \
            xargs echo
            """)
            
            if !verifyResult.output.isEmpty && verifyResult.output != "(Not Mounted)" {
                print("Mounted at: \(verifyResult.output)")
            }
            return true
        } else {
            print("❌ Failed to mount USB EFI with diskutil: \(mountResult.output)")
            
            // Try alternative methods
            print("Trying alternative mount methods...")
            
            // Method 1: Try mount_msdos
            let altResult = runCommand("""
            mkdir -p /Volumes/EFI 2>/dev/null; \
            mount -t msdos /dev/\(efiPartition!) /Volumes/EFI 2>/dev/null && echo "Success" || echo "Failed"
            """, needsSudo: true)
            
            if altResult.success && altResult.output.contains("Success") {
                print("✅ Alternative mount successful at /Volumes/EFI")
                return true
            }
            
            // Method 2: Try hdiutil
            print("Trying hdiutil...")
            let hdiutilResult = runCommand("""
            hdiutil mount /dev/\(efiPartition!) 2>/dev/null | \
            grep -o '/Volumes/[^ ]*' | \
            head -1
            """)
            
            if hdiutilResult.success && !hdiutilResult.output.isEmpty {
                print("✅ hdiutil mount successful: \(hdiutilResult.output)")
                return true
            }
            
            print("❌ All mount methods failed")
            return false
        }
    }
    
    static func mountEFIPartition() -> Bool {
        print("=== Mounting EFI Partition ===")
        
        // First, check if any EFI is already mounted
        let mountedCheck = runCommand("""
        mount | grep -E 'EFI|msdos' | head -1
        """)
        
        if mountedCheck.success && !mountedCheck.output.isEmpty {
            print("EFI already mounted: \(mountedCheck.output)")
            return true
        }
        
        // Look for all disks with EFI partitions
        let allDisks = runCommand("diskutil list | grep -E '^/dev/disk[0-9]+' | awk '{print $1}'")
        
        if allDisks.success {
            let disks = allDisks.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for disk in disks {
                let diskName = disk.replacingOccurrences(of: "/dev/", with: "")
                print("\nChecking disk: \(diskName)")
                
                // Look for EFI partitions on this disk
                let efiCheck = runCommand("""
                diskutil list \(disk) | grep -E 'EFI|Apple_Boot' | head -1
                """)
                
                if efiCheck.success && !efiCheck.output.isEmpty {
                    // Extract partition identifier
                    let parts = efiCheck.output.components(separatedBy: " ")
                        .filter { !$0.isEmpty }
                    
                    if parts.count >= 2 {
                        let partitionId = parts[0].replacingOccurrences(of: "*", with: "")
                        print("Found potential EFI partition: \(partitionId)")
                        
                        // Try to mount it
                        let mountResult = runCommand("diskutil mount \(partitionId)", needsSudo: true)
                        
                        if mountResult.success {
                            print("✅ Successfully mounted \(partitionId)")
                            return true
                        } else {
                            print("❌ Failed to mount \(partitionId): \(mountResult.output)")
                        }
                    }
                }
            }
        }
        
        // If no EFI found, try mounting any s1 partition as fallback
        print("\nTrying fallback - any s1 partition...")
        let s1Partitions = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s1' | sort | uniq
        """)
        
        if s1Partitions.success {
            let partitions = s1Partitions.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for partition in partitions {
                print("Trying fallback mount: \(partition)")
                let fallbackResult = runCommand("diskutil mount \(partition)", needsSudo: true)
                
                if fallbackResult.success {
                    print("✅ Successfully mounted \(partition) as fallback")
                    return true
                }
            }
        }
        
        print("❌ Failed to mount any EFI partition")
        return false
    }
    
    static func getEFIPath() -> String? {
        print("=== Searching for mounted EFI ===")
        
        // Method 1: Check all mounted volumes for EFI folder
        let mountedVolumes = runCommand("""
        mount | awk '{print $3}' | while read mount_point; do
            if [ -d "$mount_point/EFI" ]; then
                echo "$mount_point"
                exit 0
            fi
        done
        """)
        
        if !mountedVolumes.output.isEmpty {
            let path = mountedVolumes.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Found EFI via mount check: \(path)")
            return path
        }
        
        // Method 2: Check /Volumes directory directly
        let volumesCheck = runCommand("""
        ls -d /Volumes/* 2>/dev/null | while read volume; do
            if [ -d "$volume/EFI" ]; then
                echo "$volume"
                exit 0
            fi
        done
        """)
        
        if !volumesCheck.output.isEmpty {
            let path = volumesCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Found EFI via /Volumes check: \(path)")
            return path
        }
        
        // Method 3: Check all s1 partitions for EFI
        let s1Partitions = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s1' | while read part; do
            mount_point=$(diskutil info "/dev/$part" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
            if [ -n "$mount_point" ] && [ -d "$mount_point/EFI" ]; then
                echo "$mount_point"
                exit 0
            fi
        done
        """)
        
        if !s1Partitions.output.isEmpty {
            let path = s1Partitions.output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Found EFI via s1 partition check: \(path)")
            return path
        }
        
        print("No EFI found in any mounted volume")
        return nil
    }
    
    // MARK: - Enhanced Drive Detection for USB Boot
    
    static func getAllDrives() -> [DriveInfo] {
        print("=== Getting all drives for USB Boot ===")
        
        var drives: [DriveInfo] = []
        
        // Get diskutil list output
        let listResult = runCommand("diskutil list")
        
        if listResult.success {
            drives = parseDiskUtilOutput(listResult.output)
        }
        
        // If we got no drives, try system_profiler
        if drives.isEmpty {
            print("diskutil failed, trying system_profiler...")
            drives = getDrivesFromSystemProfiler()
        }
        
        // Sort drives: USB/external first (since we're booted from USB)
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
    
    private static func parseDiskUtilOutput(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDisk: (identifier: String, name: String, size: String, isExternal: Bool) = ("", "", "Unknown", false)
        var currentPartitions: [PartitionInfo] = []
        var inDiskSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Look for disk header
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
                    // Extract disk identifier using string manipulation
                    if let diskRange = diskPart.range(of: "disk") {
                        let startIndex = diskPart.index(diskRange.lowerBound, offsetBy: 0)
                        var endIndex = diskPart.index(startIndex, offsetBy: 4) // "disk"
                        while endIndex < diskPart.endIndex && diskPart[endIndex].isNumber {
                            endIndex = diskPart.index(endIndex, offsetBy: 1)
                        }
                        currentDisk.identifier = String(diskPart[startIndex..<endIndex])
                    }
                    
                    // Check if it's external/USB
                    currentDisk.isExternal = trimmedLine.lowercased().contains("external")
                    
                    // Extract size if present
                    if let starRange = trimmedLine.range(of: "*") {
                        let afterStar = trimmedLine[starRange.upperBound...]
                        let sizePattern = try? NSRegularExpression(pattern: "[0-9.]+ [GT]B")
                        if let sizeMatch = sizePattern?.firstMatch(in: String(afterStar), range: NSRange(location: 0, length: afterStar.count)) {
                            if let range = Range(sizeMatch.range, in: String(afterStar)) {
                                currentDisk.size = String(afterStar[range])
                            }
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
                }
                inDiskSection = true
            }
            // Look for partitions (lines starting with numbers)
            else if inDiskSection && trimmedLine.range(of: "^\\s*\\d+:\\s", options: .regularExpression) != nil {
                let parts = trimmedLine.components(separatedBy: " ")
                    .filter { !$0.isEmpty }
                
                if parts.count >= 5 {
                    let partNumber = parts[0].replacingOccurrences(of: ":", with: "")
                    let partIdentifier = "\(currentDisk.identifier)s\(partNumber)"
                    let partName = parts[2]
                    let partSize = "\(parts[3]) \(parts[4])"
                    let partType = parts.dropFirst(5).joined(separator: " ")
                    let isEFI = partType.contains("EFI") || partIdentifier.contains("s1") || partName.contains("EFI")
                    
                    // Get mount point
                    var mountPoint = ""
                    let mountCheck = runCommand("diskutil info /dev/\(partIdentifier) 2>/dev/null | grep \"Mount Point\" | awk -F': ' '{print $2}' | xargs")
                    if mountCheck.success && !mountCheck.output.isEmpty {
                        mountPoint = mountCheck.output
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
        
        // Now update mount points for drives themselves
        for i in 0..<drives.count {
            var drive = drives[i]
            
            // Get mount point for the drive itself
            let driveMountResult = runCommand("diskutil info /dev/\(drive.identifier) 2>/dev/null | grep \"Mount Point\" | awk -F': ' '{print $2}' | xargs")
            
            if driveMountResult.success && !driveMountResult.output.isEmpty {
                drive = DriveInfo(
                    name: drive.name,
                    identifier: drive.identifier,
                    size: drive.size,
                    type: drive.type,
                    mountPoint: driveMountResult.output.trimmingCharacters(in: .whitespacesAndNewlines),
                    isInternal: drive.isInternal,
                    isEFI: drive.isEFI,
                    partitions: drive.partitions
                )
                drives[i] = drive
            }
        }
        
        return drives
    }
    
    private static func getDrivesFromSystemProfiler() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Try SPStorageDataType first
        let storageResult = runCommand("system_profiler SPStorageDataType 2>/dev/null")
        
        if storageResult.success {
            let lines = storageResult.output.components(separatedBy: "\n")
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
                        let isInternal = mountPoint == "/" || !mountPoint.hasPrefix("/Volumes")
                        
                        let identifier = currentDrive["BSD Name"] ?? "disk\(drives.count)"
                        
                        drives.append(DriveInfo(
                            name: name,
                            identifier: identifier,
                            size: size,
                            type: fs,
                            mountPoint: mountPoint,
                            isInternal: isInternal,
                            isEFI: name.contains("EFI"),
                            partitions: []
                        ))
                    }
                    currentDrive = [:]
                }
            }
        }
        
        // If no drives found, try USB detection
        if drives.isEmpty {
            let usbResult = runCommand("system_profiler SPUSBDataType 2>/dev/null | grep -A 10 'Mass Storage'")
            
            if usbResult.success {
                let lines = usbResult.output.components(separatedBy: "\n")
                var deviceInfo: [String: String] = [:]
                var deviceCount = 0
                
                for line in lines {
                    if line.contains(":") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespaces)
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            deviceInfo[key] = value
                        }
                    } else if line.contains("--") && !deviceInfo.isEmpty {
                        if let product = deviceInfo["Product"] {
                            drives.append(DriveInfo(
                                name: product,
                                identifier: "usb\(deviceCount)",
                                size: deviceInfo["Capacity"] ?? "Unknown",
                                type: "USB Storage",
                                mountPoint: "",
                                isInternal: false,
                                isEFI: false,
                                partitions: []
                            ))
                            deviceCount += 1
                        }
                        deviceInfo = [:]
                    }
                }
            }
        }
        
        return drives
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
        
        // Check if running from USB
        let bootResult = runCommand("if diskutil info / 2>/dev/null | grep -q 'Protocol.*USB'; then echo \"USB Boot\"; else echo \"Internal Boot\"; fi")
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
    
    // MARK: - Debug Functions
    
    static func debugUSBMount() -> String {
        var debugOutput = "=== USB Mount Debug ===\n\n"
        
        // 1. Check current mount
        debugOutput += "1. Current Mount Status:\n"
        let mountStatus = runCommand("mount | grep -E 'EFI|msdos'")
        debugOutput += mountStatus.success ? mountStatus.output : "No EFI mounted\n"
        
        // 2. Check diskutil list
        debugOutput += "\n2. Disk List:\n"
        let diskList = runCommand("diskutil list")
        debugOutput += diskList.output
        
        // 3. Check root disk info
        debugOutput += "\n3. Root Disk Info:\n"
        let rootInfo = runCommand("diskutil info /")
        debugOutput += rootInfo.output
        
        // 4. Check USB devices
        debugOutput += "\n4. USB Devices:\n"
        let usbDevices = runCommand("system_profiler SPUSBDataType 2>/dev/null | grep -A 30 'Mass Storage'")
        debugOutput += usbDevices.output
        
        // 5. Try to detect boot drive
        debugOutput += "\n5. Boot Drive Detection:\n"
        if let bootDrive = detectBootDrive() {
            debugOutput += "Boot Drive: \(bootDrive)\n"
            
            // 6. Check boot drive info
            debugOutput += "\n6. Boot Drive Info:\n"
            let bootInfo = runCommand("diskutil info /dev/\(bootDrive)")
            debugOutput += bootInfo.output
            
            // 7. Check partitions on boot drive
            debugOutput += "\n7. Partitions on Boot Drive:\n"
            let partitions = runCommand("diskutil list /dev/\(bootDrive)")
            debugOutput += partitions.output
        } else {
            debugOutput += "Failed to detect boot drive\n"
        }
        
        return debugOutput
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
    @State private var showDebugView = false
    @State private var debugOutput: String = ""
    @State private var isDebugging = false
    
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
        .sheet(isPresented: $showDebugView) {
            debugUSBView
        }
        .onAppear {
            checkSystemStatus()
            loadAllDrives()
            checkEFIMount()
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
                
                // Debug Button
                Button(action: {
                    debugUSBMount()
                }) {
                    Image(systemName: "ladybug.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.bordered)
                .help("Debug USB Mount")
                
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
                Text("Running from USB installer - EFI access optimized")
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
                
                Button(action: forceUSBCheck) {
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
                // USB/External Drives First (since booting from USB)
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
                        Button("Mount USB EFI") {
                            mountUSBEFI()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMountingPartition)
                        
                        Button("Manual Mount") {
                            mountEFI()
                        }
                        .buttonStyle(.bordered)
                        
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
                title: "Debug USB",
                icon: "ladybug.fill",
                color: .orange,
                isLoading: isDebugging,
                action: debugUSBMount
            )
            
            MaintenanceButton(
                title: "Manual Mount Guide",
                icon: "terminal.fill",
                color: .green,
                isLoading: false,
                action: showManualMountInstructions
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
    
    private var debugUSBView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("USB Mount Debug")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    showDebugView = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Debug Output")
                        .font(.headline)
                        .padding(.top)
                    
                    if isDebugging {
                        HStack {
                            Spacer()
                            ProgressView("Running debug commands...")
                            Spacer()
                        }
                        .frame(height: 100)
                    } else {
                        ScrollView {
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .frame(height: 300)
                    }
                    
                    // Action Buttons
                    HStack {
                        Button("Copy to Clipboard") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(debugOutput, forType: .string)
                            
                            alertTitle = "Copied"
                            alertMessage = "Debug output copied to clipboard!"
                            showAlert = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Save to File") {
                            let savePanel = NSSavePanel()
                            savePanel.title = "Save Debug Output"
                            savePanel.nameFieldLabel = "File Name:"
                            savePanel.nameFieldStringValue = "usb_debug_\(Date().timeIntervalSince1970).txt"
                            savePanel.allowedContentTypes = [.plainText]
                            
                            savePanel.begin { response in
                                if response == .OK, let url = savePanel.url {
                                    do {
                                        try debugOutput.write(to: url, atomically: true, encoding: .utf8)
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    } catch {
                                        alertTitle = "Save Failed"
                                        alertMessage = error.localizedDescription
                                        showAlert = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Run Debug Again") {
                            debugUSBMount()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 500)
    }
    
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
            
            Text("USB Boot Edition - Automatic USB EFI detection enabled")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Auto-Mount USB EFI") {
                    mountUSBEFI()
                    showEFISelectionView = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("Manual Mount Any EFI") {
                    mountEFI()
                    showEFISelectionView = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Debug USB Mount") {
                    debugUSBMount()
                    showEFISelectionView = false
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                
                Button("Show Manual Instructions") {
                    showManualMountInstructions()
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
        .frame(width: 400, height: 350)
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
            }
        }
    }
    
    private func forceUSBCheck() {
        isLoadingDrives = true
        
        DispatchQueue.global(qos: .background).async {
            let usbResult = ShellHelper.runCommand("""
            echo "=== USB Drive Detection ==="
            diskutil list | grep -B2 -A2 'external'
            echo ""
            echo "=== USB Protocol Check ==="
            diskutil list | grep -E '^/dev/disk' | awk '{print $1}' | while read disk; do
                if diskutil info "$disk" 2>/dev/null | grep -qi 'Protocol.*USB'; then
                    echo "USB Drive: $disk"
                fi
            done
            """)
            
            print("USB detection output: \(usbResult.output)")
            
            // Reload all drives
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
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            if ShellHelper.mountUSBEFI() {
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
    
    private func mountUSBEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountUSBEFI()
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success {
                    alertTitle = "USB EFI Mounted"
                    alertMessage = "USB EFI partition mounted successfully!"
                    if let path = path {
                        alertMessage += "\n\nLocation: \(path)"
                    }
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount USB EFI partition.
                    
                    Try:
                    1. Use "Debug USB" button to diagnose
                    2. Use "Manual Mount Guide" for terminal commands
                    3. Or try "Manual Mount EFI" button
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
                    alertMessage = "Failed to mount EFI partition. Try using the Debug USB feature."
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
            var messages: [String] = ["Checking EFI structure..."]
            
            // Check directories
            let dirs = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers", "EFI/OC/Tools"]
            
            for dir in dirs {
                let fullPath = "\(efiPath)/\(dir)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                messages.append("\(exists ? "✅" : "❌") \(dir)")
            }
            
            DispatchQueue.main.async {
                alertTitle = "EFI Structure Check"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func debugUSBMount() {
        isDebugging = true
        showDebugView = true
        
        DispatchQueue.global(qos: .background).async {
            let debugInfo = ShellHelper.debugUSBMount()
            
            DispatchQueue.main.async {
                debugOutput = debugInfo
                isDebugging = false
            }
        }
    }
    
    private func showManualMountInstructions() {
        let instructions = """
        Manual EFI Mount Instructions:
        
        1. Open Terminal
        2. Run: diskutil list
        3. Look for your USB drive (usually disk1, disk2, etc.)
        4. Look for the EFI partition (usually has "EFI" or "Apple_Boot" type)
        5. Mount it with: sudo diskutil mount diskXsY
        
        Example:
        - If USB is disk2 and EFI is partition 1: sudo diskutil mount disk2s1
        
        After mounting, refresh in the app.
        
        Common partition numbers for EFI:
        - macOS USB Installer: Usually diskXs1
        - Windows USB: May have different partition layout
        - Linux USB: Varies by distribution
        
        Note: If diskutil fails, try:
        sudo mkdir /Volumes/EFI
        sudo mount -t msdos /dev/diskXsY /Volumes/EFI
        """
        
        alertTitle = "Manual Mount Instructions"
        alertMessage = instructions
        showAlert = true
        
        // Also open Terminal with helpful command
        let script = """
        echo "=== Manual EFI Mount Helper ==="
        echo ""
        echo "1. List all disks:"
        echo "diskutil list"
        echo ""
        echo "2. Look for your USB drive and EFI partition"
        echo "3. Mount with: sudo diskutil mount diskXsY"
        echo "   Replace X with disk number, Y with partition number"
        echo ""
        echo "Example:"
        echo "sudo diskutil mount disk2s1"
        echo ""
        echo "Press Control+C to exit"
        echo "==============================="
        """
        
        let tempFile = "/tmp/efi_mount_helper.sh"
        do {
            try script.write(toFile: tempFile, atomically: true, encoding: .utf8)
            ShellHelper.runCommand("chmod +x \(tempFile)")
            ShellHelper.runCommand("open -a Terminal \(tempFile)")
        } catch {
            print("Error creating script: \(error)")
        }
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