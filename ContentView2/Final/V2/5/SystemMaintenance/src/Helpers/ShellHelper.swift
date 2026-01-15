import Foundation
import AppKit

// MARK: - OS Version Detection
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

// MARK: - Shell Helper (Compatible with all macOS versions)
struct ShellHelper {
    
    // MARK: - Core Command Execution
    static func runCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running command: \(command)")
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        // Use compatible shell for all macOS versions
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
        return (combinedOutput, success)
    }
    
    // MARK: - Sudo Command Execution (Compatible)
    static func runSudoCommand(_ command: String) -> (output: String, success: Bool) {
        print("🔧 Running sudo command: \(command)")
        
        // Escape the command properly for all macOS versions
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "'\\''")
        
        // Use different approaches based on macOS version
        if SystemInfo.isMacOS10_15OrEarlier() {
            // For macOS 10.15 and earlier, use simpler approach
            let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
            let escapedAppleScript = appleScript.replacingOccurrences(of: "\"", with: "\\\"")
            return runCommand("osascript -e '\(escapedAppleScript)'")
        } else {
            // For macOS 11+, use newer approach
            let appleScript = """
            do shell script "\(escapedCommand)" \
            with administrator privileges \
            without altering line endings
            """
            let escapedAppleScript = appleScript.replacingOccurrences(of: "\"", with: "\\\"")
            return runCommand("osascript -e \"\(escapedAppleScript)\"")
        }
    }
    
    // MARK: - Bootloader Detection
    static func detectBootloader() -> (name: String, version: String, mode: String) {
        print("🔍 Detecting bootloader...")
        
        var bootloaderName = "Apple (Native)"
        var bootloaderVersion = "Native"
        var bootloaderMode = "Normal"
        
        // Method 1: Check NVRAM variables first (most reliable)
        
        // Check for OpenCore NVRAM variable
        let opencoreNVRAM = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null || echo ''")
        if !opencoreNVRAM.output.isEmpty && !opencoreNVRAM.output.contains("error") {
            bootloaderName = "OpenCore"
            let rawVersion = opencoreNVRAM.output.trimmingCharacters(in: .whitespacesAndNewlines)
            bootloaderVersion = rawVersion.isEmpty ? "Unknown" : rawVersion
            
            // Check mode
            if rawVersion.uppercased().contains("DEBUG") {
                bootloaderMode = "Debug"
            } else if rawVersion.uppercased().contains("RELEASE") {
                bootloaderMode = "Release"
            }
        }
        
        // Check for Clover NVRAM variable
        if bootloaderName == "Apple (Native)" {
            let cloverNVRAM = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:clover-version 2>/dev/null || echo ''")
            if !cloverNVRAM.output.isEmpty && !cloverNVRAM.output.contains("error") {
                bootloaderName = "Clover"
                bootloaderVersion = cloverNVRAM.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Method 2: Check mounted EFI partitions
        if bootloaderName == "Apple (Native)" {
            // List all mounted volumes and check for EFI/OC or EFI/CLOVER
            let mountedVolumes = runCommand("mount | grep '/dev/disk' | grep '/Volumes/'")
            let lines = mountedVolumes.output.components(separatedBy: "\n")
            
            for line in lines {
                if line.contains("/Volumes/") {
                    let components = line.components(separatedBy: " ")
                    if components.count >= 3 {
                        let mountPoint = components[2]
                        
                        // Check for OpenCore
                        let opencoreCheck = runCommand("[ -d '\(mountPoint)/EFI/OC' ] && echo 'OPENOCORE_FOUND' || echo 'NOT_FOUND'")
                        if opencoreCheck.output.contains("OPENOCORE_FOUND") {
                            bootloaderName = "OpenCore"
                            bootloaderVersion = "Unknown"
                            break
                        }
                        
                        // Check for Clover
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
        
        // Method 3: Check for Hackintosh indicators
        if bootloaderName == "Apple (Native)" {
            // Check for common Hackintosh model identifiers
            let modelCheck = runCommand("sysctl -n hw.model 2>/dev/null")
            if modelCheck.success {
                let model = modelCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                let hackintoshModels = ["MacPro6,1", "iMacPro1,1", "MacBookPro15,1", "MacPro7,1", 
                                       "iMac20,1", "iMac20,2", "Macmini8,1"]
                
                if hackintoshModels.contains(model) {
                    // Check for non-Apple hardware
                    let cpuCheck = runCommand("sysctl -n machdep.cpu.brand_string")
                    if cpuCheck.success && !cpuCheck.output.contains("Apple") {
                        bootloaderName = "OpenCore/Clover (Hackintosh)"
                        bootloaderVersion = "Unknown"
                    }
                }
            }
        }
        
        // Method 4: Check boot-args for OpenCore/Clover indicators
        if bootloaderName == "Apple (Native)" {
            let bootArgs = runCommand("nvram boot-args 2>/dev/null || echo ''")
            if bootArgs.output.contains("-v") || bootArgs.output.contains("debug") || 
               bootArgs.output.contains("alcid") || bootArgs.output.contains("igfx") {
                bootloaderName = "OpenCore/Clover (Likely)"
            }
        }
        
        // Try to get version from config files if we know it's OpenCore/Clover but no version yet
        if (bootloaderName.contains("OpenCore") || bootloaderName.contains("Clover")) && bootloaderVersion == "Unknown" {
            // Mount EFI partition temporarily
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
                    // Try to read OpenCore version from config
                    let ocVersion = runCommand("""
                    if [ -f /Volumes/EFI/EFI/OC/OpenCore.efi ]; then
                        strings /Volumes/EFI/EFI/OC/OpenCore.efi | grep -i 'opencore.*version' | head -1
                    fi
                    """)
                    
                    if !ocVersion.output.isEmpty {
                        bootloaderVersion = ocVersion.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if bootloaderName.contains("Clover") {
                    // Try to read Clover version
                    let cloverVersion = runCommand("""
                    if [ -f /Volumes/EFI/EFI/CLOVER/CLOVERX64.efi ]; then
                        strings /Volumes/EFI/EFI/CLOVER/CLOVERX64.efi | grep -i 'clover.*version' | head -1
                    fi
                    """)
                    
                    if !cloverVersion.output.isEmpty {
                        bootloaderVersion = cloverVersion.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Unmount EFI if we mounted it
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
        
        // Get Secure Boot status
        if bootloader.name.contains("OpenCore") {
            // Check OpenCore SecureBootModel
            let secureBootCheck = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:SecureBootModel 2>/dev/null || echo ''")
            if !secureBootCheck.output.isEmpty && !secureBootCheck.output.contains("error") {
                let model = secureBootCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
                details["secureBootModel"] = model.isEmpty ? "Disabled" : model
            } else {
                details["secureBootModel"] = "Disabled"
            }
        } else {
            // Native Apple Secure Boot
            let appleSecureBoot = runCommand("system_profiler SPHardwareDataType 2>/dev/null | grep -i 'Secure Boot' || echo ''")
            if !appleSecureBoot.output.isEmpty {
                details["secureBootModel"] = appleSecureBoot.output.replacingOccurrences(of: "Secure Boot:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                details["secureBootModel"] = "Enabled"
            }
        }
        
        // Get boot-args
        let bootArgs = runCommand("nvram boot-args 2>/dev/null || echo ''")
        if !bootArgs.output.isEmpty && !bootArgs.output.contains("error") {
            details["bootArgs"] = bootArgs.output.replacingOccurrences(of: "boot-args", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            details["bootArgs"] = "None"
        }
        
        // Get csr-active-config (System Integrity Protection status)
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
        
        // Get current boot volume
        let bootVolume = runCommand("diskutil info / | grep 'Device Node:' | awk '{print $3}' || echo 'Unknown'")
        details["currentBootVolume"] = bootVolume.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get filesystem type
        let fsType = runCommand("diskutil info / | grep 'Type (Bundle):' | awk '{print $3}' || echo 'APFS'")
        details["filesystem"] = fsType.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For Hackintosh/OpenCore, try to get more details
        if bootloader.name.contains("OpenCore") || bootloader.name.contains("Clover") {
            // Check if using custom SSDT/ACPI
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
            
            // Check for kext count
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
    
    // MARK: - Drive Management (Compatible)
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get mounted volumes (compatible approach)
        let mountedVolumes = getMountedVolumes()
        print("📌 Found \(mountedVolumes.count) mounted volumes")
        drives.append(contentsOf: mountedVolumes)
        
        // Get unmounted partitions
        let unmountedPartitions = getUnmountedPartitions()
        print("📌 Found \(unmountedPartitions.count) unmounted partitions")
        drives.append(contentsOf: unmountedPartitions)
        
        // Get external unmounted drives
        let externalUnmounted = getExternalUnmountedDrives()
        print("📌 Found \(externalUnmounted.count) external unmounted drives")
        drives.append(contentsOf: externalUnmounted)
        
        // Remove duplicates
        var uniqueDrives: [DriveInfo] = []
        var seenIdentifiers = Set<String>()
        
        for drive in drives {
            if !seenIdentifiers.contains(drive.identifier) {
                seenIdentifiers.insert(drive.identifier)
                uniqueDrives.append(drive)
            }
        }
        
        // Sort
        uniqueDrives.sort {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            if $0.isInternal != $1.isInternal {
                return !$0.isInternal && $1.isInternal
            }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        
        print("✅ Total unique drives found: \(uniqueDrives.count)")
        return uniqueDrives
    }
    
    private static func getMountedVolumes() -> [DriveInfo] {
        print("📌 Getting mounted volumes...")
        var volumes: [DriveInfo] = []
        
        // Use compatible df command options
        let dfCommand: String
        if SystemInfo.isMacOS10_15OrEarlier() {
            dfCommand = "df -h"
        } else {
            dfCommand = "df -h"
        }
        
        let dfResult = runCommand(dfCommand)
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if components.count < 6 || components[0] == "Filesystem" {
                continue
            }
            
            let devicePath = components[0]
            let mountPoint = components[5]
            
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                // Skip system partitions
                if !mountPoint.hasPrefix("/Volumes/") && 
                   (mountPoint.contains("/System/Volumes/") ||
                    mountPoint == "/" ||
                    mountPoint.contains("home") ||
                    mountPoint.contains("private/var") ||
                    mountPoint.contains("Library/Developer")) {
                    continue
                }
                
                let volumeName = (mountPoint as NSString).lastPathComponent
                let size = components.count >= 2 ? components[1] : "Unknown"
                
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
            }
        }
        
        return volumes
    }
    
    private static func getUnmountedPartitions() -> [DriveInfo] {
        print("📌 Getting unmounted partitions...")
        var partitions: [DriveInfo] = []
        
        // Use diskutil list (compatible across all macOS)
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        var currentDisk = ""
        
        for line in lines {
            if line.contains("/dev/disk") && (line.contains("GUID_partition_scheme") || line.contains("Apple_partition_scheme")) {
                let components = line.components(separatedBy: " ")
                if let diskId = components.first(where: { $0.contains("disk") })?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = diskId
                }
            }
            
            if line.contains("disk") && line.contains("s") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if let partitionId = components.first(where: { $0.hasPrefix("disk") && $0.contains("s") }) {
                    if !currentDisk.isEmpty && partitionId.hasPrefix(currentDisk) {
                        let drive = getDriveInfo(deviceId: partitionId)
                        
                        // Check mount status
                        let mountCheck = runCommand("diskutil info /dev/\(partitionId) | grep 'Mount Point'")
                        let isMounted = !mountCheck.output.contains("Not applicable") && 
                                       !mountCheck.output.contains("No mount point") &&
                                       !mountCheck.output.contains("Not mounted")
                        
                        if !isMounted {
                            // Skip system partitions
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
        
        // Compatible command for all macOS versions
        let listResult = runCommand("""
        diskutil list | grep -E '^/dev/disk[0-9]+' | while read line; do
            disk=$(echo "$line" | awk '{print $1}' | sed 's|/dev/||')
            if diskutil info /dev/$disk 2>/dev/null | grep -q 'Internal.*No'; then
                echo "$disk"
            fi
        done
        """)
        
        let diskIds = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for diskId in diskIds {
            let drive = getDriveInfo(deviceId: diskId)
            
            if !drive.isMounted && !drive.isInternal {
                let unmountedDrive = DriveInfo(
                    name: drive.name,
                    identifier: diskId,
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
            }
        }
        
        return drives
    }
    
    private static func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting info for device: \(deviceId)")
        
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
                    isMounted = !mountPoint.isEmpty && 
                               mountPoint != "Not applicable" && 
                               mountPoint != "Not applicable (none)" &&
                               !mountPoint.contains("Not mounted")
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
                    isInternal = internalStr.contains("Yes") || internalStr.contains("yes")
                }
            }
        }
        
        // Fallback name
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
            isEFI: deviceId.contains("EFI") || type == "EFI" || name.contains("EFI"),
            partitions: [],
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    // MARK: - Mount/Unmount Operations
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
            } else {
                failedCount += 1
                // Try alternative method
                let altResult = runCommand("diskutil mountDisk /dev/\(drive.identifier)")
                
                if altResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Mounted using alternative method")
                } else {
                    let errorMsg = mountResult.output.isEmpty ? "Unknown error" : mountResult.output
                    messages.append("❌ \(drive.name): Failed - \(errorMsg)")
                }
            }
            
            // Compatible delay
            if #available(macOS 10.15, *) {
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                usleep(500000) // 0.5 seconds in microseconds
            }
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
    
    static func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives: \(drives.count)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            print("🔧 Unmounting drive: \(drive.name) (\(drive.identifier))")
            
            // Skip system volumes
            if drive.mountPoint.contains("/System/Volumes/") || 
               drive.mountPoint == "/" ||
               drive.mountPoint.contains("home") ||
               drive.mountPoint.contains("private/var") ||
               drive.mountPoint.contains("Library/Developer") {
                messages.append("⚠️ \(drive.name): Skipped (system volume)")
                continue
            }
            
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted successfully")
            } else {
                failedCount += 1
                // Try force unmount with sudo
                let forceResult = runSudoCommand("diskutil unmount force /dev/\(drive.identifier)")
                
                if forceResult.success {
                    successCount += 1
                    messages.append("✅ \(drive.name): Force unmounted")
                } else {
                    let errorMsg = unmountResult.output.isEmpty ? "Unknown error" : unmountResult.output
                    messages.append("❌ \(drive.name): Failed - \(errorMsg)")
                }
            }
            
            // Compatible delay
            if #available(macOS 10.15, *) {
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                usleep(500000)
            }
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
        
        // Compatible command for all macOS versions
        let result = runCommand("""
        diskutil list | grep -E '^/dev/disk[0-9]+' | while read line; do
            disk=$(echo "$line" | awk '{print $1}' | sed 's|/dev/||')
            info=$(diskutil info /dev/$disk 2>/dev/null)
            if echo "$info" | grep -q 'Internal.*No'; then
                if ! mount | grep -q "/dev/$disk "; then
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
            
            if #available(macOS 10.15, *) {
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                usleep(500000)
            }
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
    
    static func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all external drives")
        
        // Get all mounted volumes in /Volumes (excluding system volumes)
        let result = runCommand("""
        mount | grep '/Volumes/' | grep -v '/System/Volumes/' | awk '{print $1}' | sed 's|/dev/||' | sort -u
        """)
        
        let diskIds = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("🔍 Found \(diskIds.count) mounted external drives: \(diskIds)")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in diskIds {
            // Skip system disks
            if diskId.starts(with: "disk0") || diskId.starts(with: "disk1") || 
               diskId.starts(with: "disk2") || diskId.starts(with: "disk3") || 
               diskId.starts(with: "disk4") {
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
            
            if #available(macOS 10.15, *) {
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                usleep(500000)
            }
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
    
    // MARK: - System Checks
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    static func checkFullDiskAccess() -> Bool {
        // Different approaches for different macOS versions
        if SystemInfo.isMacOS11OrLater() {
            // macOS 11+ approach
            let testResult = runCommand("ls /Users/$(whoami)/Library/Containers/ 2>&1")
            return !testResult.output.contains("Operation not permitted")
        } else {
            // macOS 10.15 and earlier
            let testResult = runCommand("ls /Volumes/ 2>&1")
            return !testResult.output.contains("Operation not permitted")
        }
    }
    
    // MARK: - Kext Management (Compatible)
    static func checkKextLoaded(_ kextName: String) -> Bool {
        // Different commands for different macOS versions
        let command: String
        if SystemInfo.isMacOS10_15OrEarlier() {
            command = "kextstat | grep -i '\(kextName)'"
        } else {
            command = "kmutil showloaded --list-only 2>/dev/null | grep -i '\(kextName)' || kextstat | grep -i '\(kextName)'"
        }
        
        let result = runCommand(command)
        return result.success && !result.output.isEmpty
    }
    
    static func runCommandWithSudo(_ command: String) -> (output: String, success: Bool) {
        return runSudoCommand(command)
    }
}