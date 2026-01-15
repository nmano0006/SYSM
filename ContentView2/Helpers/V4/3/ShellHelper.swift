// Helpers/ShellHelper.swift
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

// MARK: - OpenCore Info Model
struct OpenCoreInfo {
    let name: String
    let version: String
    let mode: String
    let configPath: String?
    let secureBootModel: String
    let bootArgs: String
    let sipStatus: String
    let isHackintosh: Bool
    let efiMountPath: String?
    let configData: [String: Any]?
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
    
    // MARK: - Improved OpenCore Detection
    static func detectOpenCore() -> OpenCoreInfo? {
        print("🔍 Detecting OpenCore...")
        
        // Method 1: Check for OpenCore NVRAM variables (all possible formats)
        let nvramCommands = [
            "nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null",
            "nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version | awk '{print $2}' 2>/dev/null",
            "nvram -p | grep -i 'opencore' 2>/dev/null",
            "nvram -x -p | grep -A5 -B5 'opencore' 2>/dev/null"
        ]
        
        var openCoreVersion = ""
        var openCoreMode = "Release"
        
        for cmd in nvramCommands {
            let result = runCommand(cmd)
            if result.success && !result.output.isEmpty && !result.output.contains("error") {
                let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !output.isEmpty {
                    openCoreVersion = output
                    
                    if output.lowercased().contains("debug") {
                        openCoreMode = "Debug"
                    } else if output.lowercased().contains("release") {
                        openCoreMode = "Release"
                    } else if output.lowercased().contains("development") {
                        openCoreMode = "Development"
                    }
                    
                    print("✅ Found OpenCore version in NVRAM: \(openCoreVersion)")
                    break
                }
            }
        }
        
        // If no version found in NVRAM, try to find it on EFI partitions
        if openCoreVersion.isEmpty {
            print("⚠️ No OpenCore version in NVRAM, checking EFI partitions...")
            openCoreVersion = findOpenCoreVersionFromEFI()
        }
        
        // Get Secure Boot status
        var secureBootModel = "Disabled"
        let secureBootCheck = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:SecureBootModel 2>/dev/null || echo ''")
        if !secureBootCheck.output.isEmpty && !secureBootCheck.output.contains("error") {
            let model = secureBootCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            secureBootModel = model.isEmpty ? "Disabled" : model
        }
        
        // Get boot-args
        var bootArgs = "None"
        let bootArgsCheck = runCommand("nvram boot-args 2>/dev/null || echo ''")
        if !bootArgsCheck.output.isEmpty && !bootArgsCheck.output.contains("error") {
            bootArgs = bootArgsCheck.output
                .replacingOccurrences(of: "boot-args", with: "")
                .replacingOccurrences(of: "\t", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get SIP status
        var sipStatus = "Unknown"
        let csrConfig = runCommand("nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:csr-active-config 2>/dev/null || echo ''")
        if !csrConfig.output.isEmpty && !csrConfig.output.contains("error") {
            let csrValue = csrConfig.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if csrValue == "00 00 00 00" || csrValue == "00000000" {
                sipStatus = "Enabled (Full)"
            } else if csrValue == "77 00 00 00" || csrValue == "77000000" {
                sipStatus = "Partially Disabled"
            } else if csrValue == "ff 0f 00 00" || csrValue == "ff0f0000" {
                sipStatus = "Fully Disabled"
            } else {
                sipStatus = "Custom (\(csrValue))"
            }
        }
        
        // Check if Hackintosh
        var isHackintosh = false
        let modelCheck = runCommand("sysctl -n hw.model 2>/dev/null")
        if modelCheck.success {
            let model = modelCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            let realMacModels = ["MacBookAir", "MacBookPro", "iMac", "MacPro", "Macmini", "MacStudio"]
            isHackintosh = !realMacModels.contains(where: { model.contains($0) }) || model.contains("MacPro6,1") || model.contains("iMacPro1,1")
        }
        
        // Find EFI mount path
        var efiMountPath: String? = nil
        var configData: [String: Any]? = nil
        
        if let efiPath = findEFIPartition() {
            efiMountPath = efiPath
            
            // Try to load config.plist
            let configPath = "\(efiPath)/EFI/OC/config.plist"
            if FileManager.default.fileExists(atPath: configPath) {
                configData = loadPlistFile(path: configPath)
            }
        }
        
        return OpenCoreInfo(
            name: "OpenCore",
            version: openCoreVersion.isEmpty ? "Unknown" : openCoreVersion,
            mode: openCoreMode,
            configPath: nil,
            secureBootModel: secureBootModel,
            bootArgs: bootArgs,
            sipStatus: sipStatus,
            isHackintosh: isHackintosh,
            efiMountPath: efiMountPath,
            configData: configData
        )
    }
    
    // MARK: - Find OpenCore Version from EFI
    private static func findOpenCoreVersionFromEFI() -> String {
        print("🔍 Searching for OpenCore on EFI partitions...")
        
        // Mount all EFI partitions first
        let mountResult = runCommand("""
        diskutil list | grep "EFI" | grep -o 'disk[0-9]*s[0-9]*' | while read part; do
            if ! mount | grep -q "/dev/$part"; then
                diskutil mount /dev/$part >/dev/null 2>&1
                echo "$part"
            fi
        done
        """)
        
        var version = ""
        let mountedParts = mountResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for part in mountedParts {
            let mountPath = "/Volumes/EFI"
            
            // Check for OpenCore.efi
            let ocEfiPath = "\(mountPath)/EFI/OC/OpenCore.efi"
            if FileManager.default.fileExists(atPath: ocEfiPath) {
                print("✅ Found OpenCore.efi at \(ocEfiPath)")
                
                // Try to extract version from binary
                let stringsResult = runCommand("strings \(ocEfiPath) | grep -i 'opencore.*version\\|release.*version' | head -1")
                if !stringsResult.output.isEmpty {
                    version = stringsResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
                
                // Try plist in OpenCore.efi - fix unused variable warning
                _ = runCommand("""
                if command -v lipo >/dev/null 2>&1; then
                    lipo -info \(ocEfiPath) 2>/dev/null || echo "Not universal"
                fi
                """)
                
                // Look for version in Info.plist if exists
                let infoPlistPath = "\(mountPath)/EFI/OC/Info.plist"
                if FileManager.default.fileExists(atPath: infoPlistPath) {
                    if let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) {
                        if let ocVersion = infoPlist["CFBundleVersion"] as? String {
                            version = ocVersion
                            break
                        }
                    }
                }
            }
            
            // Unmount after checking
            _ = runCommand("diskutil unmount /dev/\(part) >/dev/null 2>&1")
        }
        
        return version
    }
    
    // MARK: - Find EFI Partition
    private static func findEFIPartition() -> String? {
        print("🔍 Finding EFI partition...")
        
        // First check already mounted EFI
        let mountedCheck = runCommand("mount | grep '/Volumes/EFI' | awk '{print $1}' | sed 's|/dev/||' | head -1")
        if !mountedCheck.output.isEmpty {
            return "/Volumes/EFI"
        }
        
        // Try to find and mount EFI
        let findResult = runCommand("""
        diskutil list | grep -E 'EFI.*EFI' | head -1 | awk '{print $NF}'
        """)
        
        let efiPartition = findResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !efiPartition.isEmpty {
            let mountResult = runCommand("diskutil mount /dev/\(efiPartition) 2>/dev/null && echo '/Volumes/EFI' || echo ''")
            let mountPath = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mountPath.isEmpty && FileManager.default.fileExists(atPath: mountPath) {
                return mountPath
            }
        }
        
        return nil
    }
    
    // MARK: - Load Plist File
    static func loadPlistFile(path: String) -> [String: Any]? {
        print("📖 Loading plist file: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Plist file does not exist")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            
            // Try different plist formats
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                print("✅ Successfully loaded plist with \(plist.count) top-level keys")
                return plist
            } else if let plistArray = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [Any] {
                print("⚠️ Plist is an array, not a dictionary")
                return ["ArrayData": plistArray]
            }
        } catch {
            print("❌ Error loading plist: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Bootloader Detection (Legacy)
    static func detectBootloader() -> (name: String, version: String, mode: String) {
        if let openCoreInfo = detectOpenCore() {
            return (openCoreInfo.name, openCoreInfo.version, openCoreInfo.mode)
        }
        
        // Fallback to Clover detection
        let cloverCheck = runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:clover-version 2>/dev/null || echo ''")
        if !cloverCheck.output.isEmpty && !cloverCheck.output.contains("error") {
            return ("Clover", cloverCheck.output.trimmingCharacters(in: .whitespacesAndNewlines), "Unknown")
        }
        
        return ("Apple (Native)", "Native", "Normal")
    }
    
    // MARK: - Get OpenCore Configuration
    static func getOpenCoreConfig() -> [String: Any]? {
        print("🔍 Getting OpenCore configuration...")
        
        // First try to find and mount EFI
        guard let efiPath = findEFIPartition() else {
            print("❌ Could not find EFI partition")
            return nil
        }
        
        let configPaths = [
            "\(efiPath)/EFI/OC/config.plist",
            "\(efiPath)/EFI/CLOVER/config.plist",
            "\(efiPath)/EFI/BOOT/config.plist"
        ]
        
        for configPath in configPaths {
            if FileManager.default.fileExists(atPath: configPath) {
                print("✅ Found config at: \(configPath)")
                return loadPlistFile(path: configPath)
            }
        }
        
        print("❌ No OpenCore config found")
        return nil
    }
    
    // MARK: - Get OpenCore Details
    static func getOpenCoreDetails() -> [String: String] {
        print("🔍 Getting detailed OpenCore info...")
        
        var details: [String: String] = [:]
        
        guard let openCoreInfo = detectOpenCore() else {
            details["bootloaderName"] = "Not Detected"
            details["bootloaderVersion"] = "Unknown"
            details["bootloaderMode"] = "Unknown"
            return details
        }
        
        details["bootloaderName"] = openCoreInfo.name
        details["bootloaderVersion"] = openCoreInfo.version
        details["bootloaderMode"] = openCoreInfo.mode
        details["secureBootModel"] = openCoreInfo.secureBootModel
        details["bootArgs"] = openCoreInfo.bootArgs
        details["sipStatus"] = openCoreInfo.sipStatus
        details["isHackintosh"] = openCoreInfo.isHackintosh ? "Yes" : "No"
        details["efiMountPath"] = openCoreInfo.efiMountPath ?? "Not mounted"
        
        // Get config details if available
        if let config = openCoreInfo.configData {
            details["configSections"] = "\(config.count)"
            
            // Count important sections
            let importantSections = ["ACPI", "Kernel", "Misc", "NVRAM", "PlatformInfo", "UEFI"]
            var sectionCount = 0
            for section in importantSections {
                if config[section] != nil {
                    sectionCount += 1
                }
            }
            details["activeSections"] = "\(sectionCount)/\(importantSections.count)"
        }
        
        return details
    }
    
    // MARK: - Drive Management
    static func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get mounted volumes
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
        var partitions: [String] = []
        
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
            } else if trimmedLine.contains("Partition Type:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let partitionType = components[1].trimmingCharacters(in: .whitespaces)
                    if !partitionType.isEmpty && partitionType != "Not applicable" {
                        partitions.append(partitionType)
                    }
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
            partitions: partitions,
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