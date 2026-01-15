import Foundation
import AppKit

struct OpenCoreInfo {
    let version: String
    let mode: String
    let secureBootModel: String
    let sipStatus: String
    let bootArgs: String
    let isHackintosh: Bool
    let efiMountPath: String?
}

struct SystemInfo {
    static func macOSVersion() -> (major: Int, minor: Int, patch: Int) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return (osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion)
    }
    
    static func isMacOS12OrLater() -> Bool {
        let version = macOSVersion()
        return version.major >= 12
    }
    
    static func isMacOS11OrLater() -> Bool {
        let version = macOSVersion()
        return version.major >= 11
    }
    
    static func isMacOS10_15OrEarlier() -> Bool {
        let version = macOSVersion()
        return version.major == 10 && version.minor <= 15
    }
    
    static func isAppleSilicon() -> Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafeBytes(of: &sysinfo.machine) { bufPtr -> String in
            let data = Data(bufPtr)
            if let lastIndex = data.lastIndex(where: { $0 != 0 }) {
                return String(data: data[0...lastIndex], encoding: .isoLatin1) ?? "Unknown"
            } else {
                return String(data: data, encoding: .isoLatin1) ?? "Unknown"
            }
        }
        return machine.hasPrefix("arm64") || machine.contains("Apple")
    }
}

struct ShellHelper {
    
    // MARK: - Basic Command Execution
    
    static func runCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running command: \(command)")
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if SystemInfo.isMacOS10_15OrEarlier() {
            task.launchPath = "/bin/bash"
        } else {
            task.launchPath = "/bin/zsh"
        }
        task.arguments = ["-c", command]
        
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
        return (combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines), success)
    }
    
    static func runSudoCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running sudo command: \(command)")
        
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "'\\''")
        
        if SystemInfo.isMacOS10_15OrEarlier() {
            let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
            let escapedAppleScript = appleScript.replacingOccurrences(of: "\"", with: "\\\"")
            return runCommand("osascript -e '\(escapedAppleScript)'")
        } else {
            let appleScript = """
            do shell script "\(escapedCommand)" \
            with administrator privileges \
            without altering line endings
            """
            let escapedAppleScript = appleScript.replacingOccurrences(of: "\"", with: "\\\"")
            return runCommand("osascript -e \"\(escapedAppleScript)\"")
        }
    }
    
    static func runCommandWithSudo(_ command: String) -> (output: String, success: Bool) {
        return runSudoCommand(command)
    }
    
    // MARK: - EFI Functions
    
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
    
    static func unmountEFIDrive(_ identifier: String) -> (success: Bool, message: String) {
        print("⏬ Unmounting EFI partition: \(identifier)")
        
        let unmountResult = runCommand("diskutil unmount /dev/\(identifier)")
        
        if unmountResult.success {
            return (true, "✅ Successfully unmounted EFI partition")
        } else {
            // Try force unmount
            let forceResult = runCommand("diskutil unmount force /dev/\(identifier)")
            
            if forceResult.success {
                return (true, "✅ Force unmounted EFI partition")
            } else {
                return (false, "❌ Failed to unmount EFI partition. Error: \(unmountResult.output)")
            }
        }
    }
    
    // MARK: - Drive Management Functions
    
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // First, get all mounted volumes from df
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 6 && parts[0].hasPrefix("/dev/disk") {
                let deviceId = parts[0].replacingOccurrences(of: "/dev/", with: "")
                let size = parts[1]
                let mountPoint = parts[5...].joined(separator: " ")
                
                // Skip system volumes we don't want to show (except root and Data)
                if mountPoint.hasPrefix("/System/Volumes/") && 
                   !mountPoint.contains("Data") && 
                   mountPoint != "/" {
                    continue
                }
                
                // Get detailed info
                let drive = getDriveInfo(deviceId: deviceId)
                
                let driveInfo = DriveInfo(
                    name: drive.name,
                    identifier: deviceId,
                    size: size,
                    type: drive.type,
                    mountPoint: mountPoint,
                    isInternal: drive.isInternal,
                    isEFI: false, // Mounted drives are not EFI (EFI is usually unmounted)
                    partitions: [],
                    isMounted: true,
                    isSelectedForMount: false,
                    isSelectedForUnmount: false
                )
                
                if !drives.contains(where: { $0.identifier == deviceId }) {
                    drives.append(driveInfo)
                }
            }
        }
        
        // Now specifically find EFI partitions using diskutil list
        let efisearchResult = runCommand("""
        diskutil list | grep -i 'EFI' | while read line; do
            echo "$line" | awk '{print $NF}'
        done
        """)
        
        let efiIds = efisearchResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 Found EFI partitions: \(efiIds)")
        
        for efiId in efiIds {
            // Get actual size for this EFI partition
            var efiSize = "209.7 MB"
            let sizeResult = runCommand("diskutil info /dev/\(efiId) 2>/dev/null | grep 'Volume Size:' || echo ''")
            if !sizeResult.output.isEmpty {
                let parts = sizeResult.output.components(separatedBy: ":")
                if parts.count > 1 {
                    let size = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !size.isEmpty {
                        efiSize = size
                    }
                }
            }
            
            let efiDrive = DriveInfo(
                name: "EFI System Partition",
                identifier: efiId,
                size: efiSize,
                type: "EFI",
                mountPoint: "",
                isInternal: !efiId.contains("disk6") && !efiId.contains("disk9"), // External disks
                isEFI: true,
                partitions: [],
                isMounted: false,
                isSelectedForMount: false,
                isSelectedForUnmount: false
            )
            
            if !drives.contains(where: { $0.identifier == efiId }) {
                drives.append(efiDrive)
            }
        }
        
        // Also look for s1 partitions that might be EFI but not labeled as EFI
        let s1SearchResult = runCommand("""
        diskutil list | grep -E 'disk[0-9]+s1' | while read line; do
            echo "$line" | awk '{print $NF}'
        done
        """)
        
        let s1Ids = s1SearchResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 Found s1 partitions: \(s1Ids)")
        
        for s1Id in s1Ids {
            // Skip if we already have this as EFI or in drives
            if efiIds.contains(s1Id) || drives.contains(where: { $0.identifier == s1Id }) {
                continue
            }
            
            // Check if it's an EFI partition by size (104.9 MB or 209.7 MB)
            let infoResult = runCommand("diskutil info /dev/\(s1Id) 2>/dev/null || echo ''")
            var isEFIPartition = false
            var size = "Unknown"
            
            for line in infoResult.output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("Volume Size:") || trimmed.contains("Disk Size:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count > 1 {
                        size = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        // EFI partitions are usually 104.9 MB or 209.7 MB
                        if size.contains("104.9 MB") || size.contains("209.7 MB") || size.contains("314.6 MB") {
                            isEFIPartition = true
                        }
                    }
                }
            }
            
            if isEFIPartition {
                let s1Drive = DriveInfo(
                    name: "EFI System Partition",
                    identifier: s1Id,
                    size: size,
                    type: "EFI",
                    mountPoint: "",
                    isInternal: !s1Id.contains("disk6") && !s1Id.contains("disk9"),
                    isEFI: true,
                    partitions: [],
                    isMounted: false,
                    isSelectedForMount: false,
                    isSelectedForUnmount: false
                )
                
                drives.append(s1Drive)
            }
        }
        
        // Get list of all partitions and check for unmounted non-EFI partitions
        let diskListResult = runCommand("""
        for disk in /dev/disk*; do
            if [[ $disk =~ /dev/disk[0-9]+s[0-9]+$ ]]; then
                echo "${disk#/dev/}"
            fi
        done
        """)
        
        let allPartitionIds = diskListResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for partitionId in allPartitionIds {
            // Skip if we already have this drive
            if drives.contains(where: { $0.identifier == partitionId }) {
                continue
            }
            
            // Skip if it's likely an EFI partition (s1)
            if partitionId.hasSuffix("s1") {
                continue
            }
            
            let drive = getDriveInfo(deviceId: partitionId)
            
            // Skip if it's a system partition we don't want to show
            if drive.name.contains("Recovery") || 
               drive.name.contains("VM") || 
               drive.name.contains("Preboot") || 
               drive.name.contains("Update") ||
               drive.name.contains("Snapshot") ||
               drive.name.contains("Apple_APFS_ISC") {
                continue
            }
            
            // Skip if size is 0
            if drive.size == "0 B" || drive.size == "Zero KB" {
                continue
            }
            
            // Only add if it's unmounted and not EFI
            if !drive.isMounted && !drive.isEFI {
                drives.append(drive)
            }
        }
        
        // Sort drives: mounted first, then EFI, then unmounted
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
    
    static func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting info for: \(deviceId)")
        
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null || echo 'Not found'")
        
        var name = "Disk \(deviceId)"
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = true
        var isMounted = false
        var isEFI = false
        
        let lines = infoResult.output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.contains("Volume Name:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let volName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !volName.isEmpty && volName != "Not applicable" {
                        name = volName
                    }
                }
            }
            else if trimmed.contains("Device / Media Name:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let mediaName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !mediaName.isEmpty && name == "Disk \(deviceId)" {
                        name = mediaName
                    }
                }
            }
            else if trimmed.contains("Volume Size:") || trimmed.contains("Disk Size:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    size = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            else if trimmed.contains("Mount Point:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    mountPoint = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    isMounted = !mountPoint.isEmpty && 
                               mountPoint != "Not applicable" && 
                               mountPoint != "Not applicable (none)" &&
                               !mountPoint.contains("Not mounted")
                }
            }
            else if trimmed.contains("Protocol:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let protocolType = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if protocolType.contains("USB") || protocolType.contains("External") {
                        isInternal = false
                        type = "USB"
                    } else if protocolType.contains("SATA") || protocolType.contains("PCI") {
                        isInternal = true
                        type = "Internal"
                    } else if protocolType.contains("NVMe") {
                        isInternal = true
                        type = "NVMe"
                    }
                }
            }
            else if trimmed.contains("Type (Bundle):") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let bundleType = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
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
                    let internalStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    isInternal = internalStr.contains("Yes")
                }
            }
        }
        
        // Detect external drives by disk number (disk0, disk1 are usually internal)
        if !deviceId.starts(with: "disk0") && !deviceId.starts(with: "disk1") && !isEFI {
            isInternal = false
            if type == "Unknown" {
                type = "External"
            }
        }
        
        // If name is still generic, try to get it from mount point
        if (name == "Disk \(deviceId)" || name.isEmpty) && !mountPoint.isEmpty {
            let components = mountPoint.components(separatedBy: "/")
            if let last = components.last, !last.isEmpty {
                name = last
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
            
            Thread.sleep(forTimeInterval: 0.5)
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
    
    static func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            print("🔧 Unmounting: \(drive.name) (\(drive.identifier))")
            
            // Skip system volumes
            if drive.mountPoint.contains("/System/Volumes/") || 
               drive.mountPoint == "/" {
                messages.append("⚠️ \(drive.name): Skipped (system volume)")
                continue
            }
            
            // Special handling for EFI
            if drive.isEFI {
                let result = unmountEFIDrive(drive.identifier)
                if result.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): EFI unmounted")
                } else {
                    failedCount += 1
                    messages.append("❌ \(drive.name): Failed to unmount EFI")
                }
                continue
            }
            
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted successfully")
            } else {
                failedCount += 1
                let forceResult = runSudoCommand("diskutil unmount force /dev/\(drive.identifier)")
                
                if forceResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Force unmounted")
                } else {
                    let errorMsg = unmountResult.output.isEmpty ? "Unknown error" : unmountResult.output
                    messages.append("❌ \(drive.name): Failed - \(errorMsg)")
                }
            }
            
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
    
    static func mountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏫ Mounting all external drives")
        
        // First get list of external unmounted drives
        let externalDrives = getAllDrives().filter { 
            !$0.isInternal && !$0.isMounted && !$0.isEFI 
        }
        
        if externalDrives.isEmpty {
            return (true, "No unmounted external drives found")
        }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in externalDrives {
            print("🔧 Mounting external drive: \(drive.identifier)")
            
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
                    messages.append("❌ \(drive.name): Failed")
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully mounted \(successCount) external drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Mounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else {
            return (false, "Failed to mount external drives\n\n\(message)")
        }
    }
    
    static func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all external drives")
        
        // Get all mounted external drives
        let externalDrives = getAllDrives().filter { 
            !$0.isInternal && $0.isMounted && !$0.isEFI 
        }
        
        if externalDrives.isEmpty {
            return (true, "No external drives mounted")
        }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in externalDrives {
            print("🔧 Unmounting external drive: \(drive.identifier)")
            
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted")
            } else {
                failedCount += 1
                let forceResult = runSudoCommand("diskutil unmount force /dev/\(drive.identifier)")
                
                if forceResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Force unmounted")
                } else {
                    messages.append("❌ \(drive.name): Failed")
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully unmounted \(successCount) external drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else {
            return (false, "Failed to unmount external drives\n\n\(message)")
        }
    }
    
    // MARK: - OpenCore Functions
    
    static func detectOpenCore() -> OpenCoreInfo? {
        print("🔍 Detecting OpenCore...")
        
        let bootloader = detectBootloader()
        
        guard bootloader.name.contains("OpenCore") else {
            print("❌ OpenCore not detected")
            return nil
        }
        
        let details = getBootloaderDetails()
        
        var efiMountPath: String? = nil
        let efiCheck = runCommand("""
        diskutil list | grep -E 'EFI.*EFI' | head -1 | awk '{print $NF}' | while read disk; do
            mount | grep -q "/dev/$disk" && echo "/Volumes/EFI"
        done
        """)
        
        if !efiCheck.output.isEmpty {
            efiMountPath = efiCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var isHackintosh = false
        if bootloader.name.contains("Hackintosh") {
            isHackintosh = true
        } else {
            let cpuCheck = runCommand("sysctl -n machdep.cpu.brand_string")
            if cpuCheck.success && !cpuCheck.output.contains("Apple") && !cpuCheck.output.contains("M1") && !cpuCheck.output.contains("M2") && !cpuCheck.output.contains("M3") {
                isHackintosh = true
            }
        }
        
        let info = OpenCoreInfo(
            version: bootloader.version,
            mode: bootloader.mode,
            secureBootModel: details["secureBootModel"] ?? "Disabled",
            sipStatus: details["sipStatus"] ?? "Unknown",
            bootArgs: details["bootArgs"] ?? "None",
            isHackintosh: isHackintosh,
            efiMountPath: efiMountPath
        )
        
        print("✅ OpenCore Info: \(info.version), Mode: \(info.mode), SecureBoot: \(info.secureBootModel)")
        return info
    }
    
    static func getOpenCoreConfig() -> [String: Any]? {
        print("📖 Reading OpenCore configuration...")
        
        let mountResult = runCommand("""
        diskutil list | grep -E 'EFI.*EFI' | head -1 | awk '{print $NF}' | while read disk; do
            if ! mount | grep -q "/dev/$disk"; then
                diskutil mount /dev/$disk 2>/dev/null
                echo "/Volumes/EFI"
            fi
        done
        """)
        
        let configPaths = [
            "/Volumes/EFI/EFI/OC/config.plist",
            "/Volumes/EFI/EFI/OC/Config.plist",
            "/Volumes/EFI/EFI/BOOT/config.plist",
            "/Volumes/EFI/EFI/BOOT/Config.plist",
            "/Volumes/EFI/config.plist",
            "/Volumes/EFI/Config.plist"
        ]
        
        var foundConfig: [String: Any]? = nil
        
        for configPath in configPaths {
            print("🔍 Checking for config at: \(configPath)")
            
            if FileManager.default.fileExists(atPath: configPath) {
                print("✅ Found config at: \(configPath)")
                
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
                    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        foundConfig = plist
                        print("📊 Successfully parsed config with \(plist.count) top-level keys")
                        break
                    }
                } catch {
                    print("❌ Failed to parse config at \(configPath): \(error)")
                }
            }
        }
        
        if !mountResult.output.isEmpty && foundConfig == nil {
            _ = runCommand("diskutil unmount /Volumes/EFI 2>/dev/null")
        }
        
        if foundConfig == nil {
            print("❌ No OpenCore config found in any standard location")
            
            let userHome = FileManager.default.homeDirectoryForCurrentUser.path
            let userConfigPaths = [
                "\(userHome)/Documents/OpenCore/config.plist",
                "\(userHome)/Downloads/OpenCore/config.plist",
                "\(userHome)/Desktop/OpenCore/config.plist"
            ]
            
            for configPath in userConfigPaths {
                if FileManager.default.fileExists(atPath: configPath) {
                    print("✅ Found user config at: \(configPath)")
                    
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
                        if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                            foundConfig = plist
                            print("📊 Successfully parsed user config")
                            break
                        }
                    } catch {
                        print("❌ Failed to parse user config: \(error)")
                    }
                }
            }
        }
        
        return foundConfig
    }
    
    // MARK: - Bootloader Functions
    
    static func detectBootloader() -> (name: String, version: String, mode: String) {
        print("🔍 Detecting bootloader...")
        
        var bootloaderName = "Apple (Native)"
        var bootloaderVersion = "Native"
        var bootloaderMode = "Normal"
        
        let opencoreNVRAM = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null || echo ''")
        if !opencoreNVRAM.output.isEmpty && !opencoreNVRAM.output.contains("error") {
            bootloaderName = "OpenCore"
            let rawVersion = opencoreNVRAM.output.trimmingCharacters(in: .whitespacesAndNewlines)
            bootloaderVersion = rawVersion.isEmpty ? "Unknown" : rawVersion
            
            if rawVersion.uppercased().contains("DEBUG") {
                bootloaderMode = "Debug"
            } else if rawVersion.uppercased().contains("RELEASE") {
                bootloaderMode = "Release"
            }
        }
        
        if bootloaderName == "Apple (Native)" {
            let cloverNVRAM = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:clover-version 2>/dev/null || echo ''")
            if !cloverNVRAM.output.isEmpty && !cloverNVRAM.output.contains("error") {
                bootloaderName = "Clover"
                bootloaderVersion = cloverNVRAM.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if bootloaderName == "Apple (Native)" {
            let mountedVolumes = runCommand("mount | grep '/dev/disk' | grep '/Volumes/'")
            let lines = mountedVolumes.output.components(separatedBy: "\n")
            
            for line in lines {
                if line.contains("/Volumes/") {
                    let components = line.components(separatedBy: " ")
                    if components.count >= 3 {
                        let mountPoint = components[2]
                        
                        let opencoreCheck = runCommand("[ -d '\(mountPoint)/EFI/OC' ] && echo 'OPENOCORE_FOUND' || echo 'NOT_FOUND'")
                        if opencoreCheck.output.contains("OPENOCORE_FOUND") {
                            bootloaderName = "OpenCore"
                            bootloaderVersion = "Unknown"
                            break
                        }
                        
                        let cloverCheck = runCommand("[ -d '\(mountPoint)/EFI/CLOVER' ] && echo 'CLOVER_FOUND' || echo 'NOT_FOUND'")
                        if cloverCheck.output.contains("CLOVER_FOUND") {
                            bootloaderName = "Clover"
                            bootloaderVersion = "Unknown"
                            break
                        }
                    }
                }
            }
        }
        
        if bootloaderName == "Apple (Native)" {
            let modelCheck = runCommand("sysctl -n hw.model 2>/dev/null")
            if modelCheck.success {
                let model = modelCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                let hackintoshModels = ["MacPro6,1", "iMacPro1,1", "MacBookPro15,1", "MacPro7,1", 
                                       "iMac20,1", "iMac20,2", "Macmini8,1"]
                
                if hackintoshModels.contains(model) {
                    let cpuCheck = runCommand("sysctl -n machdep.cpu.brand_string")
                    if cpuCheck.success && !cpuCheck.output.contains("Apple") {
                        bootloaderName = "OpenCore/Clover (Hackintosh)"
                        bootloaderVersion = "Unknown"
                    }
                }
            }
        }
        
        if bootloaderName == "Apple (Native)" {
            let bootArgs = runCommand("nvram boot-args 2>/dev/null || echo ''")
            if bootArgs.output.contains("-v") || bootArgs.output.contains("debug") || 
               bootArgs.output.contains("alcid") || bootArgs.output.contains("igfx") {
                bootloaderName = "OpenCore/Clover (Likely)"
            }
        }
        
        if (bootloaderName.contains("OpenCore") || bootloaderName.contains("Clover")) && bootloaderVersion == "Unknown" {
            let mountEFI = runCommand("""
            diskutil list | grep -E 'EFI.*EFI' | head -1 | awk '{print $NF}' | while read disk; do
                if ! mount | grep -q "/dev/$disk"; then
                    diskutil mount /dev/$disk 2>/dev/null
                    echo $disk
                fi
            done
            """)
            
            if !mountEFI.output.isEmpty {
                let efiDisk = mountEFI.output.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if bootloaderName.contains("OpenCore") {
                    let ocVersion = runCommand("""
                    if [ -f /Volumes/EFI/EFI/OC/OpenCore.efi ]; then
                        strings /Volumes/EFI/EFI/OC/OpenCore.efi | grep -i 'opencore.*version' | head -1
                    fi
                    """)
                    
                    if !ocVersion.output.isEmpty {
                        bootloaderVersion = ocVersion.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if bootloaderName.contains("Clover") {
                    let cloverVersion = runCommand("""
                    if [ -f /Volumes/EFI/EFI/CLOVER/CLOVERX64.efi ]; then
                        strings /Volumes/EFI/EFI/CLOVER/CLOVERX64.efi | grep -i 'clover.*version' | head -1
                    fi
                    """)
                    
                    if !cloverVersion.output.isEmpty {
                        bootloaderVersion = cloverVersion.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                if !efiDisk.isEmpty {
                    _ = runCommand("diskutil unmount /dev/\(efiDisk) 2>/dev/null")
                }
            }
        }
        
        print("✅ Bootloader detected: \(bootloaderName) \(bootloaderVersion) (\(bootloaderMode))")
        return (bootloaderName, bootloaderVersion, bootloaderMode)
    }
    
    static func getBootloaderDetails() -> [String: String] {
        print("🔍 Getting detailed bootloader info...")
        
        var details: [String: String] = [:]
        let bootloader = detectBootloader()
        
        details["bootloaderName"] = bootloader.name
        details["bootloaderVersion"] = bootloader.version
        details["bootloaderMode"] = bootloader.mode
        
        if bootloader.name.contains("OpenCore") {
            let secureBootCheck = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:SecureBootModel 2>/dev/null || echo ''")
            if !secureBootCheck.output.isEmpty && !secureBootCheck.output.contains("error") {
                let model = secureBootCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                details["secureBootModel"] = model.isEmpty ? "Disabled" : model
            } else {
                details["secureBootModel"] = "Disabled"
            }
        } else {
            let appleSecureBoot = runCommand("system_profiler SPHardwareDataType 2>/dev/null | grep -i 'Secure Boot' || echo ''")
            if !appleSecureBoot.output.isEmpty {
                details["secureBootModel"] = appleSecureBoot.output.replacingOccurrences(of: "Secure Boot:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                details["secureBootModel"] = "Enabled"
            }
        }
        
        let bootArgs = runCommand("nvram boot-args 2>/dev/null || echo ''")
        if !bootArgs.output.isEmpty && !bootArgs.output.contains("error") {
            details["bootArgs"] = bootArgs.output.replacingOccurrences(of: "boot-args", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            details["bootArgs"] = "None"
        }
        
        let csrConfig = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:csr-active-config 2>/dev/null || echo ''")
        if !csrConfig.output.isEmpty && !csrConfig.output.contains("error") {
            let csrValue = csrConfig.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if csrValue == "00 00 00 00" || csrValue == "00000000" {
                details["sipStatus"] = "Enabled (Full)"
            } else if csrValue == "77 00 00 00" || csrValue == "77000000" {
                details["sipStatus"] = "Partially Disabled"
            } else if csrValue == "ff 0f 00 00" || csrValue == "ff0f0000" {
                details["sipStatus"] = "Fully Disabled"
            } else {
                details["sipStatus"] = "Custom (\(csrValue))"
            }
        }
        
        let bootVolume = runCommand("diskutil info / | grep 'Device Node:' | awk '{print $3}' || echo 'Unknown'")
        details["currentBootVolume"] = bootVolume.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fsType = runCommand("diskutil info / | grep 'Type (Bundle):' | awk '{print $3}' || echo 'APFS'")
        details["filesystem"] = fsType.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if bootloader.name.contains("OpenCore") || bootloader.name.contains("Clover") {
            let acpiCheck = runCommand("""
            if [ -d /Volumes/EFI/EFI/OC/ACPI ]; then
                ls /Volumes/EFI/EFI/OC/ACPI/*.aml 2>/dev/null | wc -l | tr -d ' '
            elif [ -d /Volumes/EFI/EFI/CLOVER/ACPI/patched ]; then
                ls /Volumes/EFI/EFI/CLOVER/ACPI/patched/*.aml 2>/dev/null | wc -l | tr -d ' '
            else
                echo "0"
            fi
            """)
            
            if let acpiCount = Int(acpiCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                details["acpiPatches"] = "\(acpiCount)"
            }
            
            let kextCheck = runCommand("""
            if [ -d /Volumes/EFI/EFI/OC/Kexts ]; then
                ls /Volumes/EFI/EFI/OC/Kexts/*.kext 2>/dev/null | wc -l | tr -d ' '
            elif [ -d /Volumes/EFI/EFI/CLOVER/kexts/Other ]; then
                ls /Volumes/EFI/EFI/CLOVER/kexts/Other/*.kext 2>/dev/null | wc -l | tr -d ' '
            else
                echo "0"
            fi
            """)
            
            if let kextCount = Int(kextCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                details["kextCount"] = "\(kextCount)"
            }
        }
        
        print("✅ Bootloader details collected: \(details.count) items")
        return details
    }
    
    // MARK: - System Functions
    
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    static func checkFullDiskAccess() -> Bool {
        if SystemInfo.isMacOS11OrLater() {
            let testResult = runCommand("ls /Users/$(whoami)/Library/Containers/ 2>&1")
            return !testResult.output.contains("Operation not permitted")
        } else {
            let testResult = runCommand("ls /Volumes/ 2>&1")
            return !testResult.output.contains("Operation not permitted")
        }
    }
    
    static func checkKextLoaded(_ kextName: String) -> Bool {
        let command: String
        if SystemInfo.isMacOS10_15OrEarlier() {
            command = "kextstat | grep -i '\(kextName)'"
        } else {
            command = "kmutil showloaded --list-only 2>/dev/null | grep -i '\(kextName)' || kextstat | grep -i '\(kextName)'"
        }
        
        let result = runCommand(command)
        return result.success && !result.output.isEmpty
    }
}