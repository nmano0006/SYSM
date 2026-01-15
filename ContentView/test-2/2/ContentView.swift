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
            do shell script "\(escapedCommand)" ¬
            with administrator privileges ¬
            with prompt "SystemMaintenance needs administrator access" ¬
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
    
    // Enhanced mount function specifically for USB boot
    static func mountEFIPartition(partition: String? = nil) -> Bool {
        print("=== Starting EFI Mount from USB Boot ===")
        
        // First, check if any EFI is already mounted
        let checkResult = runCommand("""
        mount | grep -i 'efi\\|/dev/disk.*s1' | grep -v ' / ' | head -1
        """)
        
        if checkResult.success && !checkResult.output.isEmpty {
            print("EFI already mounted: \(checkResult.output)")
            return true
        }
        
        // If a specific partition was requested, try to mount it
        if let partition = partition {
            print("Trying specific partition: \(partition)")
            let mountResult = runCommand("diskutil mount \(partition)", needsSudo: true)
            if mountResult.success {
                print("✅ Successfully mounted: \(partition)")
                return true
            } else {
                print("❌ Failed to mount \(partition): \(mountResult.output)")
                return false
            }
        }
        
        // Get all disks - improved for USB boot
        let listResult = runCommand("""
        diskutil list | grep -E '^/dev/disk' | grep -o 'disk[0-9]*' | sort | uniq
        """)
        
        if !listResult.success {
            print("Failed to list disks: \(listResult.output)")
            // Try alternative command for USB boot
            let altResult = runCommand("ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$' | sort | uniq")
            if !altResult.success {
                print("Alternative disk listing also failed")
                return false
            }
            print("Found disks via alternative method")
        }
        
        let disks = listResult.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        print("Found disks: \(disks)")
        
        if disks.isEmpty {
            print("No disks found! Trying emergency scan...")
            // Emergency scan for USB boot
            return emergencyEFIScan()
        }
        
        // Try each disk for EFI partition
        for disk in disks {
            print("\n--- Checking disk: \(disk) ---")
            
            // Skip the USB boot disk itself
            if isBootDisk(disk) {
                print("Skipping boot disk: \(disk)")
                continue
            }
            
            // Check disk info
            let diskInfo = runCommand("diskutil info /dev/\(disk) 2>/dev/null")
            if !diskInfo.success {
                print("Cannot get info for \(disk)")
                continue
            }
            
            // Look for EFI partitions
            let allParts = runCommand("diskutil list /dev/\(disk) 2>/dev/null | grep -o '\(disk)s[0-9]*'")
            let partitions = allParts.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            
            for partition in partitions {
                print("Checking partition: \(partition)")
                let partInfo = runCommand("diskutil info /dev/\(partition) 2>/dev/null")
                if partInfo.success {
                    let isEFI = partInfo.output.lowercased().contains("efi") || 
                               partInfo.output.contains("EFI") || 
                               partInfo.output.contains("Apple_Boot") ||
                               partInfo.output.contains("EFI System Partition")
                    
                    if isEFI {
                        print("Found EFI partition: \(partition)")
                        
                        // Try to mount with multiple methods
                        let mountResult = mountPartitionWithRetry(partition)
                        if mountResult.success {
                            print("✅ Successfully mounted: \(partition)")
                            return true
                        } else {
                            print("❌ Failed to mount \(partition)")
                            // Try alternative mount method
                            if mountWithAlternativeMethod(partition) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        
        // If no EFI found, try to mount common partitions
        print("\n--- Trying fallback: mount common partitions ---")
        for disk in disks {
            if isBootDisk(disk) {
                continue
            }
            
            let commonPartitions = ["\(disk)s1", "\(disk)s2", "\(disk)s3"]
            for partition in commonPartitions {
                print("Trying to mount \(partition) as fallback...")
                let mountResult = mountPartitionWithRetry(partition)
                if mountResult.success {
                    print("✅ Mounted \(partition) (fallback)")
                    return true
                }
            }
        }
        
        print("❌ Failed to mount any EFI partition")
        return false
    }
    
    private static func isBootDisk(_ disk: String) -> Bool {
        // Check if this is the current boot disk
        let bootResult = runCommand("""
        diskutil info /dev/\(disk) 2>/dev/null | grep "Mount Point" | grep -q " / "
        """)
        return bootResult.success
    }
    
    private static func mountPartitionWithRetry(_ partition: String) -> (success: Bool, output: String) {
        // Method 1: Normal mount
        let result1 = runCommand("diskutil mount \(partition)", needsSudo: true)
        if result1.success {
            return (true, result1.output)
        }
        
        // Method 2: Mount with force
        let result2 = runCommand("diskutil mount force \(partition)", needsSudo: true)
        if result2.success {
            return (true, result2.output)
        }
        
        // Method 3: Mount read-only
        let result3 = runCommand("diskutil mount readOnly \(partition)", needsSudo: true)
        if result3.success {
            return (true, result3.output)
        }
        
        return (false, result1.output)
    }
    
    private static func mountWithAlternativeMethod(_ partition: String) -> Bool {
        print("Trying alternative mount methods for \(partition)...")
        
        // Method 1: Use mount command directly
        let mountPoint = "/Volumes/EFI_\(partition.replacingOccurrences(of: "/dev/", with: ""))"
        let _ = runCommand("sudo mkdir -p \(mountPoint)", needsSudo: true)
        let result = runCommand("sudo mount -t msdos /dev/\(partition) \(mountPoint)", needsSudo: true)
        
        if result.success {
            print("✅ Mounted using direct mount command")
            return true
        }
        
        // Method 2: Try hdiutil
        let hdiResult = runCommand("sudo hdiutil mount /dev/\(partition)", needsSudo: true)
        if hdiResult.success {
            print("✅ Mounted using hdiutil")
            return true
        }
        
        return false
    }
    
    private static func emergencyEFIScan() -> Bool {
        print("=== Starting emergency EFI scan ===")
        
        // Try to find any mounted EFI volumes
        let findResult = runCommand("""
        ls /Volumes/ 2>/dev/null | while read volume; do
            if [[ "$volume" == *EFI* ]] || [[ -d "/Volumes/$volume/EFI" ]]; then
                echo "/Volumes/$volume"
                exit 0
            fi
        done
        """)
        
        if findResult.success && !findResult.output.isEmpty {
            print("Found existing EFI volume: \(findResult.output)")
            return true
        }
        
        // Check system_profiler for disks
        let spResult = runCommand("system_profiler SPStorageDataType 2>/dev/null | grep -A5 'Mount Point:'")
        print("System Profiler output: \(spResult.output)")
        
        return false
    }
    
    // Enhanced authentication helper for USB boot
    static func authenticateForUSB() -> Bool {
        print("=== Starting authentication for USB boot ===")
        
        // Try to authenticate with a simple command first
        let testResult = runCommand("whoami", needsSudo: true)
        if testResult.success {
            print("✅ Authentication successful")
            return true
        }
        
        print("❌ Authentication failed: \(testResult.output)")
        
        // Try alternative authentication methods
        print("Trying alternative authentication...")
        
        // Method 1: Direct sudo with osascript
        let directAuth = runCommand("osascript -e 'do shell script \"echo authenticated\" with administrator privileges'")
        if directAuth.success {
            print("✅ Direct authentication successful")
            return true
        }
        
        // Method 2: Use security command
        let securityResult = runCommand("""
        osascript <<EOF
        tell application "System Events"
            activate
            display dialog "SystemMaintenance needs administrator access to mount EFI partitions." ¬
            buttons {"Cancel", "Authenticate"} ¬
            default button "Authenticate" ¬
            with icon caution ¬
            with title "Administrator Access Required"
            
            if button returned of result is "Authenticate" then
                return "authenticated"
            else
                return "cancelled"
            end if
        end tell
        EOF
        """)
        
        if securityResult.output.contains("authenticated") {
            print("✅ User authenticated via dialog")
            return true
        }
        
        print("❌ All authentication methods failed")
        return false
    }
    
    static func getEFIPath() -> String? {
        // Multiple methods to find mounted EFI
        
        // Method 1: Check mounted volumes
        let result1 = runCommand("""
        mount | grep -E '/dev/disk.*s[0-9]' | grep -v ' / ' | awk '{print $3}' | while read mount; do
            if [ -d "$mount/EFI" ] || [ -d "$mount/BOOT" ] || [ -f "$mount/EFI/OC/config.plist" ]; then
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
        
        // Method 3: Check for OpenCore config
        let result3 = runCommand("""
        find /Volumes -name "config.plist" -path "*/OC/*" 2>/dev/null | head -1 | xargs dirname | xargs dirname | xargs dirname
        """)
        
        if result3.success && !result3.output.isEmpty {
            let path = result3.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.fileExists(atPath: path) {
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
    
    // Enhanced hard drive detection for USB boot
    static func getAllDrives() -> [DriveInfo] {
        print("=== Getting all drives for USB boot ===")
        
        var drives: [DriveInfo] = []
        
        // Method 1: Use diskutil list -plist
        let plistResult = runCommand("diskutil list -plist 2>/dev/null")
        if plistResult.success, let data = plistResult.output.data(using: .utf8) {
            drives = parsePlistDiskData(data)
        }
        
        // Method 2: If plist fails, try simpler approach
        if drives.isEmpty {
            print("Plist method failed, trying simple detection...")
            drives = getDrivesSimple()
        }
        
        // Filter out the USB boot drive if possible
        drives = drives.filter { !isLikelyUSBBootDrive($0.identifier) }
        
        print("Found \(drives.count) drives after filtering")
        return drives
    }
    
    private static func isLikelyUSBBootDrive(_ identifier: String) -> Bool {
        // Check if this is likely the USB boot drive
        let mountCheck = runCommand("""
        diskutil info /dev/\(identifier) 2>/dev/null | grep -E "Mount Point|Volume Name" | grep -i "install\\|recovery\\|base system"
        """)
        return mountCheck.success
    }
    
    private static func getDrivesSimple() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Simple disk listing for USB boot
        let result = runCommand("""
        diskutil list | grep -E '^/dev/disk[0-9]+' | while read line; do
            disk=$(echo "$line" | grep -o 'disk[0-9]+')
            name=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//' | cut -d, -f1)
            size=$(echo "$line" | grep -o '[0-9]\\+\\.[0-9]\\+ [GT]B' || echo "Unknown")
            echo "$disk|$name|$size"
        done
        """)
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 3 {
                    let identifier = parts[0]
                    let name = parts[1]
                    let size = parts[2]
                    let isInternal = !identifier.contains("external") && !name.lowercased().contains("external")
                    
                    drives.append(DriveInfo(
                        name: name.isEmpty ? "Disk \(identifier)" : name,
                        identifier: identifier,
                        size: size,
                        type: isInternal ? "Internal" : "External",
                        mountPoint: "",
                        isInternal: isInternal,
                        isEFI: false,
                        partitions: []
                    ))
                }
            }
        }
        
        return drives
    }
    
    private static func parsePlistDiskData(_ data: Data) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                
                for disk in allDisks {
                    if let deviceIdentifier = disk["DeviceIdentifier"] as? String,
                       !isLikelyUSBBootDrive(deviceIdentifier) {
                        
                        let size = disk["Size"] as? Int64 ?? 0
                        let sizeGB = size > 0 ? String(format: "%.1f GB", Double(size) / 1_000_000_000) : "Unknown"
                        
                        // Check if APFS Container
                        if let apfsVolumes = disk["APFSVolumes"] as? [[String: Any]] {
                            // APFS Container
                            let isInternal = isDiskInternal(deviceIdentifier)
                            
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
                            
                            // Get disk info
                            let infoResult = runCommand("diskutil info /dev/\(deviceIdentifier) 2>/dev/null")
                            let infoLines = infoResult.output.components(separatedBy: "\n")
                            
                            var protocolType = "Unknown"
                            var deviceModel = "Unknown"
                            
                            for line in infoLines {
                                if line.contains("Protocol:") {
                                    protocolType = line.components(separatedBy: ": ").last ?? "Unknown"
                                } else if line.contains("Device / Media Name:") {
                                    deviceModel = line.components(separatedBy: ": ").last ?? "Unknown"
                                }
                            }
                            
                            let driveName = deviceModel != "Unknown" ? deviceModel : "Disk (\(deviceIdentifier))"
                            
                            drives.append(DriveInfo(
                                name: driveName,
                                identifier: deviceIdentifier,
                                size: sizeGB,
                                type: protocolType,
                                mountPoint: "",
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
    
    private static func isDiskInternal(_ identifier: String) -> Bool {
        // Check if mounted at root or has internal characteristics
        let mountCheck = runCommand("mount | grep '/dev/\(identifier)' | grep ' / '")
        if mountCheck.success {
            return true
        }
        
        // Check disk info for internal/external
        let infoCheck = runCommand("""
        diskutil info /dev/\(identifier) 2>/dev/null | grep -i "internal\\|external"
        """)
        
        if infoCheck.success {
            return infoCheck.output.lowercased().contains("internal")
        }
        
        // Default to internal for disk0, disk1
        return identifier == "disk0" || identifier == "disk1"
    }
    
    static func listAllPartitions() -> [String] {
        let result = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s[0-9]*' | sort | uniq | grep -v 'disk[0-9]*s[0-9]*$' 2>/dev/null || echo ""
        """)
        
        if result.success && !result.output.isEmpty {
            let partitions = result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return partitions
        }
        
        // Fallback partitions
        return ["disk0s1", "disk1s1", "disk2s1", "disk3s1"]
    }
    
    // MARK: - System Information Gathering
    
    static func getCompleteSystemInfo() -> SystemInfo {
        var info = SystemInfo()
        
        // Get basic system info
        DispatchQueue.global().sync {
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
        }
        
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
            "timestamp": Date().ISO8601Format()
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
                "timestamp": Date().ISO8601Format()
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

// MARK: - Enhanced System Maintenance View for USB Boot
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
    @State private var showManualMountDialog = false
    @State private var manualPartitionID = ""
    
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
                // USB Boot Warning
                usbBootWarningBanner
                
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
        .alert("Manual EFI Mount", isPresented: $showManualMountDialog) {
            TextField("Enter partition ID (e.g., disk0s1)", text: $manualPartitionID)
            Button("Cancel", role: .cancel) { }
            Button("Mount") {
                if !manualPartitionID.isEmpty {
                    mountSpecificPartition(manualPartitionID)
                }
            }
        } message: {
            Text("Enter the EFI partition identifier to mount:\n\nCommon EFI partitions: disk0s1, disk1s1, disk2s1")
        }
    }
    
    private var usbBootWarningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("USB Boot Mode Detected")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Some features may require manual authentication. If you encounter password errors:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Use 'Manual Mount' option for EFI partitions")
                    .font(.caption2)
                Text("• Try mounting via Terminal: sudo diskutil mount diskXs1")
                    .font(.caption2)
                Text("• Check Disk Utility for available partitions")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
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
                
                Button(action: refreshDrives) {
                    Label("Refresh", systemImage: "arrow.clockwise")
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
                        
                        Button("Manual Mount") {
                            showManualMountDialog = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Select...") {
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
                title: "Manual Mount...",
                icon: "keyboard",
                color: .blue,
                isLoading: false,
                action: { showManualMountDialog = true }
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
    
    // MARK: - Enhanced Action Functions for USB Boot
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            // Try to authenticate first
            let authenticated = ShellHelper.authenticateForUSB()
            
            if authenticated {
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
                        Could not auto-mount EFI partition.
                        
                        Please try:
                        1. Click "Manual Mount" and enter partition ID (e.g., disk0s1)
                        2. Open Terminal and run: diskutil list
                        3. Find your EFI partition (usually diskXs1)
                        4. Run: sudo diskutil mount diskXs1
                        """
                    }
                    showAlert = true
                }
            } else {
                DispatchQueue.main.async {
                    isMountingPartition = false
                    alertTitle = "Authentication Required"
                    alertMessage = """
                    Administrator authentication failed from USB boot.
                    
                    Please try:
                    1. Click "Manual Mount" option
                    2. Enter partition ID manually
                    3. Or mount via Terminal with: sudo diskutil mount diskXs1
                    """
                    showAlert = true
                }
            }
        }
    }
    
    private func mountSpecificPartition(_ partitionID: String) {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountEFIPartition(partition: partitionID)
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success && path != nil {
                    alertTitle = "Success"
                    alertMessage = "EFI partition \(partitionID) mounted at: \(path ?? "Unknown")"
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount \(partitionID)
                    
                    Try these steps in Terminal:
                    1. diskutil list
                    2. Find correct EFI partition
                    3. sudo diskutil mount <partition>
                    
                    Common EFI partitions: disk0s1, disk1s1, disk2s1
                    """
                }
                showAlert = true
                manualPartitionID = ""
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
            
            var messages: [String] = ["EFI Structure Check:"]
            
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
}

// MARK: - Enhanced EFI Selection View for USB Boot
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
    @State private var showManualInput = false
    @State private var manualPartition = ""
    
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
                                Button("Enter Partition Manually") {
                                    showManualInput = true
                                }
                                .buttonStyle(.bordered)
                                .padding(.top)
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
                            
                            Divider()
                            
                            Button("Enter Partition Manually") {
                                showManualInput = true
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
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
                        .disabled((selectedPartition.isEmpty && manualPartition.isEmpty) || isMounting)
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
        .alert("Manual Partition Input", isPresented: $showManualInput) {
            TextField("Enter partition ID (e.g., disk0s1)", text: $manualPartition)
            Button("Cancel", role: .cancel) { }
            Button("Use This") {
                if !manualPartition.isEmpty {
                    selectedPartition = manualPartition
                }
            }
        } message: {
            Text("Enter the partition identifier manually.\n\nCommon EFI partitions: disk0s1, disk1s1, disk2s1")
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
                    alertMessage = "Could not find any partitions. Please use manual input."
                    showAlert = true
                    showManualInput = true
                }
            }
        }
    }
    
    private func mountSelectedPartition() {
        isMounting = true
        
        let partitionToMount = manualPartition.isEmpty ? selectedPartition : manualPartition
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(partitionToMount)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    let path = ShellHelper.getEFIPath()
                    efiPath = path
                    
                    alertTitle = "Success"
                    alertMessage = """
                    Successfully mounted \(partitionToMount)
                    
                    Mounted at: \(path ?? "Unknown location")
                    
                    You can now proceed with kext installation.
                    """
                    isPresented = false
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount \(partitionToMount):
                    
                    \(result.output)
                    
                    Try another partition or use Terminal:
                    sudo diskutil mount \(partitionToMount)
                    """
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Missing Views (DiskDetailView and DonationView)
struct DiskDetailView: View {
    @Binding var isPresented: Bool
    let drive: DriveInfo
    @Binding var allDrives: [DriveInfo]
    let refreshDrives: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Drive Details")
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
                VStack(alignment: .leading, spacing: 20) {
                    // Drive Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Drive Information")
                            .font(.headline)
                        
                        InfoCard(title: "Name", value: drive.name)
                        InfoCard(title: "Identifier", value: drive.identifier)
                        InfoCard(title: "Size", value: drive.size)
                        InfoCard(title: "Type", value: drive.type)
                        InfoCard(title: "Mount Point", value: drive.mountPoint.isEmpty ? "Not Mounted" : drive.mountPoint)
                        InfoCard(title: "Internal", value: drive.isInternal ? "Yes" : "No")
                        InfoCard(title: "EFI Drive", value: drive.isEFI ? "Yes" : "No")
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Partitions
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
                    
                    // Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions")
                            .font(.headline)
                        
                        HStack {
                            Button("Refresh Info") {
                                refreshDrives()
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            if !drive.mountPoint.isEmpty {
                                Button("Open in Finder") {
                                    let url = URL(fileURLWithPath: drive.mountPoint)
                                    NSWorkspace.shared.open(url)
                                }
                                .buttonStyle(.borderedProminent)
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
        .frame(width: 500, height: 600)
    }
}

struct DonationView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Support Development")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    // Close action will be handled by parent
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Thank You Message
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("Thank You for Your Support!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your donations help fund:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Testing hardware and devices", systemImage: "desktopcomputer")
                            Label("Server costs for development", systemImage: "server.rack")
                            Label("Continued open-source development", systemImage: "hammer.fill")
                            Label("Creating free tools for the community", systemImage: "wrench.and.screwdriver")
                        }
                        .padding()
                    }
                    .padding()
                    
                    // Donation Options
                    VStack(spacing: 20) {
                        Text("Donation Options")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        // PayPal Donation
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            Text("PayPal")
                                .font(.headline)
                            
                            Text("One-time or recurring donations via PayPal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Donate via PayPal") {
                                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    // Contact Info
                    VStack(spacing: 12) {
                        Text("Other Ways to Support")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Share the app with others", systemImage: "square.and.arrow.up")
                            Label("Report bugs and issues", systemImage: "ant")
                            Label("Suggest new features", systemImage: "lightbulb")
                            Label("Star the project on GitHub", systemImage: "star")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
    }
}

// MARK: - Main Content View
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