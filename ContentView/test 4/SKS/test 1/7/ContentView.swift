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
            task.launchPath = "/bin/zsh"
        } else {
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
        }
        
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
        
        // Method 1: Direct detection using diskutil info
        print("Method 1: Checking diskutil info...")
        let result = runCommand("""
        diskutil list | grep -oE '^/dev/disk[0-9]+' | sed 's|/dev/||' | while read disk; do
            protocol=$(diskutil info /dev/$disk 2>/dev/null | grep -i "Protocol" | awk -F': ' '{print $2}' | tr -d ' ')
            bus=$(diskutil info /dev/$disk 2>/dev/null | grep -i "Bus Protocol" | awk -F': ' '{print $2}' | tr -d ' ')
            removable=$(diskutil info /dev/$disk 2>/dev/null | grep -i "Removable Media" | awk -F': ' '{print $2}' | tr -d ' ')
            if [[ "$protocol" == "USB" ]] || [[ "$bus" == "USB" ]] || [[ "$removable" == "Removable" ]]; then
                echo "$disk"
            fi
        done
        """)
        
        if result.success && !result.output.isEmpty {
            usbDrives = result.output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
            print("Found USB drives via diskutil info: \(usbDrives)")
        }
        
        // Method 2: Check system_profiler for USB drives
        if usbDrives.isEmpty {
            print("Method 2: Checking system_profiler...")
            let spResult = runCommand("""
            system_profiler SPUSBDataType 2>/dev/null | grep -A 5 "Mount Point:" | grep "/Volumes" | sed 's|.*/Volumes/||' | xargs -I {} diskutil info "/Volumes/{}" 2>/dev/null | grep "Device Node" | awk -F': ' '{print $2}' | sed 's|/dev/||'
            """)
            
            if spResult.success && !spResult.output.isEmpty {
                let drives = spResult.output.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                for drive in drives {
                    if !usbDrives.contains(drive) {
                        usbDrives.append(drive)
                    }
                }
                print("Found USB drives via system_profiler: \(drives)")
            }
        }
        
        // Method 3: Check for disk9 (common for USB)
        if !usbDrives.contains("disk9") {
            let disk9Check = runCommand("diskutil info disk9 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB'")
            if disk9Check.success {
                print("Adding disk9 as potential USB drive")
                usbDrives.append("disk9")
            }
        }
        
        // Method 4: Fallback - check for external physical drives
        if usbDrives.isEmpty {
            print("Method 4: Checking for external physical drives...")
            let externalResult = runCommand("""
            diskutil list | grep -E 'external.*physical|USB.*physical' | grep -oE '/dev/disk[0-9]+' | sed 's|/dev/||' | sort -u
            """)
            
            if externalResult.success && !externalResult.output.isEmpty {
                let drives = externalResult.output.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                
                for drive in drives {
                    if !usbDrives.contains(drive) {
                        usbDrives.append(drive)
                    }
                }
                print("Found drives via external detection: \(drives)")
            }
        }
        
        print("Total USB drives found: \(usbDrives.count) - \(usbDrives)")
        return usbDrives
    }
    
    // MARK: - Enhanced Drive Mounting Function
    static func mountDrive(identifier: String) -> (success: Bool, mountPoint: String?) {
        print("=== Attempting to mount \(identifier) ===")
        
        // Check if already mounted
        let checkCommand = """
        diskutil info /dev/\(identifier) 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs
        """
        
        let checkResult = runCommand(checkCommand)
        if checkResult.success, let mountPoint = checkResult.output.nonEmpty,
           mountPoint != "(Not Mounted)" && !mountPoint.isEmpty {
            print("Already mounted at: \(mountPoint)")
            return (true, mountPoint)
        }
        
        // Try to mount with verbose output
        print("Mounting \(identifier)...")
        let mountResult = runCommand("diskutil mount \(identifier)", needsSudo: true)
        
        if mountResult.success {
            print("✅ Mount command succeeded for \(identifier)")
            
            // Get the mount point
            let verifyCommand = """
            sleep 1 && diskutil info /dev/\(identifier) 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs
            """
            
            let verifyResult = runCommand(verifyCommand)
            if verifyResult.success, let mountPoint = verifyResult.output.nonEmpty,
               mountPoint != "(Not Mounted)" && !mountPoint.isEmpty {
                print("✅ Mounted at: \(mountPoint)")
                return (true, mountPoint)
            }
            
            // Alternative check using mount command
            let altCheck = runCommand("""
            sleep 1 && mount | grep "/dev/\(identifier)" | awk '{print $3}'
            """)
            
            if altCheck.success, let mountPoint = altCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                print("✅ Mounted at (via mount): \(mountPoint)")
                return (true, mountPoint)
            }
            
            // Check /Volumes for recently mounted volumes
            let volumeCheck = runCommand("""
            ls -t /Volumes/ | head -1
            """)
            
            if volumeCheck.success, let volumeName = volumeCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                let volumePath = "/Volumes/\(volumeName)"
                print("✅ Possibly mounted at: \(volumePath)")
                return (true, volumePath)
            }
            
            // Even if we can't get the mount point, the mount succeeded
            return (true, "/Volumes/UNTITLED")
        } else {
            print("❌ Mount failed for \(identifier): \(mountResult.output)")
            
            // Try alternative mount command
            print("Trying alternative mount command...")
            let altMountResult = runCommand("sudo mount -t msdos /dev/\(identifier) /Volumes/EFI 2>/dev/null || sudo mount -t hfs /dev/\(identifier) /Volumes/EFI 2>/dev/null", needsSudo: true)
            
            if altMountResult.success {
                print("✅ Alternative mount succeeded")
                return (true, "/Volumes/EFI")
            }
            
            return (false, nil)
        }
    }
    
    // MARK: - Get ALL Drives (Enhanced)
    static func getAllDrives() -> [DriveInfo] {
        print("=== Getting all drives ===")
        
        var drives: [DriveInfo] = []
        
        // First try: Use diskutil list
        let listResult = runCommand("diskutil list")
        
        if listResult.success {
            drives = parseDiskUtilOutput(listResult.output)
        } else {
            // Fallback: Try with sudo
            print("Initial diskutil failed, trying with sudo...")
            let sudoResult = runCommand("diskutil list", needsSudo: true)
            if sudoResult.success {
                drives = parseDiskUtilOutput(sudoResult.output)
            }
        }
        
        // If still empty, try system_profiler
        if drives.isEmpty {
            print("Trying system_profiler...")
            let spResult = runCommand("system_profiler SPStorageDataType 2>/dev/null")
            if spResult.success {
                drives = parseSystemProfilerOutput(spResult.output)
            }
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
        
        print("Found \(drives.count) total drives")
        return drives
    }
    
    private static func parseDiskUtilOutput(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDisk: DriveInfo?
        var currentPartitions: [PartitionInfo] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Look for disk header
            if trimmedLine.hasPrefix("/dev/disk") && trimmedLine.contains(":") {
                // Save previous disk
                if let disk = currentDisk {
                    let finalDisk = DriveInfo(
                        name: disk.name,
                        identifier: disk.identifier,
                        size: disk.size,
                        type: disk.type,
                        mountPoint: disk.mountPoint,
                        isInternal: disk.isInternal,
                        isEFI: disk.isEFI,
                        partitions: currentPartitions
                    )
                    drives.append(finalDisk)
                }
                
                // Parse new disk
                let components = trimmedLine.components(separatedBy: ":")
                if components.count >= 1 {
                    let diskPart = components[0].trimmingCharacters(in: .whitespaces)
                    let diskId = diskPart.replacingOccurrences(of: "/dev/", with: "")
                    
                    // Determine if internal or external
                    let isExternal = trimmedLine.lowercased().contains("external") || 
                                    trimmedLine.lowercased().contains("usb") ||
                                    trimmedLine.lowercased().contains("removable")
                    
                    // Extract size if available
                    var size = "Unknown"
                    if let starRange = trimmedLine.range(of: "*") {
                        let afterStar = trimmedLine[starRange.upperBound...]
                        let sizeComponents = afterStar.components(separatedBy: ",")
                        if !sizeComponents.isEmpty {
                            size = sizeComponents[0].trimmingCharacters(in: .whitespaces)
                        }
                    }
                    
                    // Get disk name
                    var name = "Disk \(diskId)"
                    if components.count >= 2 {
                        let description = components[1].trimmingCharacters(in: .whitespaces)
                        if !description.isEmpty {
                            let nameParts = description.components(separatedBy: ",")
                            if !nameParts.isEmpty {
                                name = nameParts[0].trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                    
                    // Get mount point
                    var mountPoint = ""
                    let mountResult = runCommand("""
                    diskutil info /dev/\(diskId) 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs
                    """)
                    if mountResult.success {
                        mountPoint = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if mountPoint == "(Not Mounted)" {
                            mountPoint = ""
                        }
                    }
                    
                    currentDisk = DriveInfo(
                        name: name,
                        identifier: diskId,
                        size: size,
                        type: isExternal ? "USB Drive" : "Internal Disk",
                        mountPoint: mountPoint,
                        isInternal: !isExternal,
                        isEFI: false,
                        partitions: []
                    )
                    currentPartitions = []
                    
                    // Get partitions for this disk
                    currentPartitions = getPartitionsForDisk(diskId)
                }
            }
        }
        
        // Add the last disk
        if let disk = currentDisk {
            let finalDisk = DriveInfo(
                name: disk.name,
                identifier: disk.identifier,
                size: disk.size,
                type: disk.type,
                mountPoint: disk.mountPoint,
                isInternal: disk.isInternal,
                isEFI: disk.isEFI,
                partitions: currentPartitions
            )
            drives.append(finalDisk)
        }
        
        return drives
    }
    
    private static func parseSystemProfilerOutput(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDrive: [String: String] = [:]
        var inDriveSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains(":") && !trimmed.hasPrefix("        ") {
                if !currentDrive.isEmpty {
                    if let name = currentDrive["Name"],
                       let size = currentDrive["Size"],
                       let mountPoint = currentDrive["Mount Point"] {
                        
                        let identifier = name.replacingOccurrences(of: " ", with: "").lowercased()
                        let isInternal = !(mountPoint.contains("Volumes") && mountPoint != "/")
                        
                        drives.append(DriveInfo(
                            name: name,
                            identifier: identifier,
                            size: size,
                            type: isInternal ? "Internal Disk" : "USB Drive",
                            mountPoint: mountPoint,
                            isInternal: isInternal,
                            isEFI: false,
                            partitions: []
                        ))
                    }
                    currentDrive = [:]
                }
                inDriveSection = true
            }
            
            if inDriveSection && trimmed.contains(":") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    currentDrive[key] = value
                }
            }
        }
        
        return drives
    }
    
    private static func getPartitionsForDisk(_ disk: String) -> [PartitionInfo] {
        var partitions: [PartitionInfo] = []
        
        // List partitions on this disk with better error handling
        let listResult = runCommand("""
        if diskutil list /dev/\(disk) >/dev/null 2>&1; then
            diskutil list /dev/\(disk) | grep -E '^[[:space:]]*[0-9]+:' | while read line; do
                part_num=$(echo "$line" | awk '{print $1}' | sed 's/://')
                part_id="\(disk)s$part_num"
                part_name=$(echo "$line" | awk '{print $3}')
                part_size=$(echo "$line" | awk '{print $4, $5}')
                echo "$part_id|$part_name|$part_size"
            done
        else
            echo "ERROR: Cannot access /dev/\(disk)"
        fi
        """)
        
        if listResult.success && !listResult.output.contains("ERROR") {
            let partitionLines = listResult.output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
            
            for line in partitionLines {
                let components = line.components(separatedBy: "|")
                if components.count >= 3 {
                    let partId = components[0]
                    var partName = components[1]
                    let partSize = components[2]
                    
                    if partName == "-" || partName.isEmpty {
                        partName = "Partition \(partId.replacingOccurrences(of: disk, with: ""))"
                    }
                    
                    // Check if this is an EFI partition
                    let isEFI = partId.hasSuffix("s1") || partName.contains("EFI")
                    
                    // Get mount point
                    var mountPoint = ""
                    let mountResult = runCommand("""
                    diskutil info /dev/\(partId) 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs
                    """)
                    if mountResult.success {
                        mountPoint = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if mountPoint == "(Not Mounted)" {
                            mountPoint = ""
                        }
                    }
                    
                    // Get partition type
                    var partType = "Unknown"
                    let typeResult = runCommand("""
                    diskutil info /dev/\(partId) 2>/dev/null | grep "Type (Bundle)" | awk -F': ' '{print $2}' | xargs
                    """)
                    if typeResult.success && !typeResult.output.isEmpty {
                        partType = typeResult.output
                    }
                    
                    partitions.append(PartitionInfo(
                        name: partName,
                        identifier: partId,
                        size: partSize,
                        type: partType,
                        mountPoint: mountPoint,
                        isEFI: isEFI
                    ))
                }
            }
        }
        
        return partitions
    }
    
    // MARK: - Enhanced EFI Functions
    static func mountUSBEFI() -> (success: Bool, path: String?) {
        print("=== Mounting USB EFI ===")
        
        // Check if already mounted
        if let mountedPath = getEFIPath() {
            print("EFI already mounted at: \(mountedPath)")
            return (true, mountedPath)
        }
        
        // Find USB drives
        let usbDrives = findUSBDrives()
        
        if usbDrives.isEmpty {
            print("No USB drives found")
            return (false, nil)
        }
        
        print("Found USB drives: \(usbDrives)")
        
        // Try each USB drive
        for usbDrive in usbDrives {
            print("\nTrying USB drive: \(usbDrive)")
            
            // First, try common EFI partitions
            let commonPartitions = ["s1", "s0", "s2"]
            
            for suffix in commonPartitions {
                let efiPartition = "\(usbDrive)\(suffix)"
                print("Trying partition: \(efiPartition)")
                
                // Check if partition exists
                let checkResult = runCommand("diskutil list /dev/\(efiPartition) 2>&1")
                
                if !checkResult.output.contains("No such file or directory") && !checkResult.output.contains("Could not find") {
                    print("Found partition: \(efiPartition)")
                    
                    // Try to mount it
                    let mountResult = mountDrive(identifier: efiPartition)
                    
                    if mountResult.success {
                        print("✅ Successfully mounted \(efiPartition)")
                        
                        // Get the actual mount point
                        let mountPoint = mountResult.mountPoint ?? getEFIPath()
                        return (true, mountPoint)
                    }
                }
            }
            
            // If common partitions didn't work, try all partitions
            print("Checking all partitions on \(usbDrive)...")
            let partitions = getPartitionsForDisk(usbDrive)
            for partition in partitions {
                if partition.isEFI || partition.type.contains("EFI") || partition.type.contains("FAT") || partition.name.contains("EFI") {
                    print("Trying EFI candidate: \(partition.identifier)")
                    let mountResult = mountDrive(identifier: partition.identifier)
                    
                    if mountResult.success {
                        print("✅ Successfully mounted \(partition.identifier)")
                        return (true, mountResult.mountPoint)
                    }
                }
            }
        }
        
        print("❌ Failed to mount any USB EFI partition")
        return (false, nil)
    }
    
    static func mountEFIPartition() -> (success: Bool, path: String?) {
        print("=== Mounting any EFI partition ===")
        
        // Check if already mounted
        if let mountedPath = getEFIPath() {
            print("EFI already mounted at: \(mountedPath)")
            return (true, mountedPath)
        }
        
        // Get all drives
        let allDrives = getAllDrives()
        
        // Look for EFI partitions in all drives
        for drive in allDrives {
            for partition in drive.partitions {
                if partition.isEFI || partition.type.contains("EFI") || partition.type.contains("FAT") {
                    print("Found EFI partition: \(partition.identifier) on drive \(drive.name)")
                    
                    // Try to mount it
                    let mountResult = mountDrive(identifier: partition.identifier)
                    
                    if mountResult.success {
                        print("✅ Successfully mounted \(partition.identifier)")
                        return (true, mountResult.mountPoint)
                    }
                }
            }
        }
        
        // Try common EFI partitions
        let commonPartitions = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1", "disk6s1", "disk7s1", "disk8s1", "disk9s1"]
        for partition in commonPartitions {
            print("Trying common partition: \(partition)")
            let mountResult = mountDrive(identifier: partition)
            
            if mountResult.success {
                print("✅ Successfully mounted \(partition)")
                return (true, mountResult.mountPoint)
            }
        }
        
        print("❌ Failed to mount any EFI partition")
        return (false, nil)
    }
    
    static func getEFIPath() -> String? {
        // Check for mounted EFI volumes with better detection
        let checkCommands = [
            // Check for EFI mounted volumes
            "mount | grep -E '(msdos|fat32|hfs|apfs)' | grep -i efi | awk '{print $3}'",
            // Check /Volumes for EFI
            "ls -d /Volumes/EFI* 2>/dev/null | head -1",
            // Check for any FAT volume
            "mount | grep -E '(msdos|fat32)' | awk '{print $3}' | head -1",
            // Check for disk9s1 specifically
            "mount | grep '/dev/disk9s1' | awk '{print $3}'",
            // Check for any mounted diskXs1
            "mount | grep -E '/dev/disk[0-9]+s1' | awk '{print $3}' | head -1"
        ]
        
        for command in checkCommands {
            let result = runCommand(command)
            if result.success, let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                print("Found EFI at: \(path)")
                return path
            }
        }
        
        print("No EFI found")
        return nil
    }
    
    // MARK: - Permission Functions
    static func requestFullDiskAccess() -> Bool {
        print("=== Requesting Full Disk Access ===")
        
        // Check if we have access to /Volumes
        let testAccess = runCommand("ls /Volumes/ 2>&1")
        if !testAccess.success && testAccess.output.contains("Operation not permitted") {
            print("Full Disk Access required")
            
            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "Full Disk Access Required"
            alert.informativeText = """
            SystemMaintenance needs Full Disk Access to detect drives and mount EFI partitions.
            
            1. Open System Settings > Privacy & Security > Full Disk Access
            2. Click the '+' button
            3. Navigate to /Applications/ and select SystemMaintenance
            4. Toggle the switch ON
            5. Restart the application
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Full Disk Access
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                NSWorkspace.shared.open(url)
            }
            return false
        }
        
        print("Full Disk Access appears to be granted")
        return true
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        diagnostics += "Generated: \(dateFormatter.string(from: Date()))\n\n"
        
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
        
        // Permission Status
        diagnostics += "\n--- Permission Status ---\n"
        let testAccess = runCommand("ls /Volumes/ 2>&1")
        if testAccess.success {
            diagnostics += "Full Disk Access: Granted ✓\n"
        } else {
            diagnostics += "Full Disk Access: Not Granted ✗\n"
            if testAccess.output.contains("Operation not permitted") {
                diagnostics += "Error: \(testAccess.output)\n"
            }
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
    
    init(title: String, status: String, version: String? = nil, detail: String? = nil, statusColor: Color = .gray) {
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

// MARK: - Permission Request View
struct PermissionRequestView: View {
    @Binding var isShowing: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
                
                Text("Full Disk Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    permissionStep(number: "1", text: "Open System Settings > Privacy & Security > Full Disk Access")
                    permissionStep(number: "2", text: "Click the '+' button")
                    permissionStep(number: "3", text: "Navigate to /Applications/ and select SystemMaintenance")
                    permissionStep(number: "4", text: "Toggle the switch ON")
                    permissionStep(number: "5", text: "Restart the application")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                HStack(spacing: 20) {
                    Button("Open System Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Later") {
                        isShowing = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(30)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(width: 500)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func permissionStep(number: String, text: String) -> some View {
        HStack(alignment: .top) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
            
            Spacer()
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
    @State private var searchText = ""
    @State private var showPermissionRequest = false
    @State private var hasFullDiskAccess = false
    
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
        ZStack {
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
                checkPermissions()
                checkSystemStatus()
                loadAllDrives()
                checkEFIMount()
                loadSystemInfo()
            }
            
            // Permission Request Overlay
            if showPermissionRequest {
                PermissionRequestView(isShowing: $showPermissionRequest)
                    .transition(.opacity)
            }
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
                // Permission Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(hasFullDiskAccess ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(hasFullDiskAccess ? "Permissions: OK" : "Permissions: Required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasFullDiskAccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(20)
                
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
                // Permission Warning
                if !hasFullDiskAccess {
                    permissionWarningSection
                }
                
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
    
    private var permissionWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Permissions Required")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("Fix Permissions") {
                    showPermissionRequest = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            
            Text("SystemMaintenance needs Full Disk Access to detect drives and mount EFI partitions. Without this permission, drive detection will not work properly.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
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
                        if !hasFullDiskAccess {
                            Text("Full Disk Access permissions required")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("Try refreshing or checking system logs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
            
            StatusCard(
                title: "Permissions",
                status: hasFullDiskAccess ? "Granted" : "Required",
                version: nil,
                detail: hasFullDiskAccess ? "Full Disk Access OK" : "Click to fix",
                statusColor: hasFullDiskAccess ? .green : .orange
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
    
    private func checkPermissions() {
        DispatchQueue.global(qos: .background).async {
            let hasAccess = ShellHelper.requestFullDiskAccess()
            DispatchQueue.main.async {
                hasFullDiskAccess = hasAccess
                if !hasAccess {
                    showPermissionRequest = true
                }
            }
        }
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
                
                if drives.isEmpty {
                    alertTitle = "Drive Detection"
                    alertMessage = """
                    No drives found. This could be due to:
                    
                    1. Full Disk Access permissions not granted
                    2. Disk utility not responding
                    3. No storage devices connected
                    
                    To fix permissions:
                    1. Open System Settings > Privacy & Security > Full Disk Access
                    2. Add SystemMaintenance to the list
                    3. Toggle the switch ON
                    4. Restart the application
                    
                    Try running in Terminal: diskutil list
                    """
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
                    3. Permission issues (check Full Disk Access)
                    4. USB drive not properly formatted
                    
                    Try:
                    • Connect a USB drive with EFI partition
                    • Use "Manual Mount EFI" instead
                    • Check if USB is detected in System Information tab
                    • Ensure Full Disk Access is granted in System Settings
                    """
                }
                showAlert = true
            }
        }
    }
    
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.mountEFIPartition()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = result.path
                
                if result.success {
                    alertTitle = "EFI Mounted"
                    alertMessage = "EFI partition mounted successfully!"
                    if let path = result.path {
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
                    
                    Also ensure Full Disk Access is granted.
                    """
                }
                showAlert = true
            }
        }
    }
    
    private func mountSelectedDrive() {
        guard let drive = selectedDrive else { return }
        
        // Try to mount the main partition (usually s1)
        let partition = "\(drive.identifier)s1"
        
        let result = ShellHelper.mountDrive(identifier: partition)
        
        if result.success {
            alertTitle = "Drive Mounted"
            alertMessage = "Successfully mounted \(partition)"
            if let mountPoint = result.mountPoint {
                alertMessage += "\n\nMounted at: \(mountPoint)"
                loadAllDrives()
            }
        } else {
            // Try the disk itself
            let diskResult = ShellHelper.mountDrive(identifier: drive.identifier)
            if diskResult.success {
                alertTitle = "Drive Mounted"
                alertMessage = "Successfully mounted \(drive.identifier)"
                if let mountPoint = diskResult.mountPoint {
                    alertMessage += "\n\nMounted at: \(mountPoint)"
                    loadAllDrives()
                }
            } else {
                alertTitle = "Mount Failed"
                alertMessage = """
                Failed to mount \(drive.identifier)
                
                Try manually in Terminal:
                sudo diskutil mount \(drive.identifier)s1
                
                Ensure Full Disk Access is granted.
                """
            }
        }
        showAlert = true
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