import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine

// MARK: - Shell Helper
class ShellHelper {
    static let shared = ShellHelper()
    
    private init() {}
    
    func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, error: String, success: Bool) {
        print("🔧 Running command: \(command)")
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
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
            print("❌ Process execution error: \(error)")
            return ("", "Process execution error: \(error)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        print("📝 Command output length: \(output.count) characters")
        if !errorOutput.isEmpty {
            print("⚠️ Command error: \(errorOutput)")
        }
        print("✅ Command success: \(success)")
        
        return (output, errorOutput, success)
    }
    
    // Get ALL drives (mounted and unmounted) - Improved detection
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get all mounted volumes from /Volumes
        let mountedVolumes = getMountedVolumes()
        drives.append(contentsOf: mountedVolumes)
        
        // Get potentially unmounted partitions
        let unmountedPartitions = getUnmountedPartitions()
        drives.append(contentsOf: unmountedPartitions)
        
        // Remove duplicates and sort
        drives = Array(Set(drives)).sorted {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getMountedVolumes() -> [DriveInfo] {
        print("📌 Getting mounted volumes...")
        var volumes: [DriveInfo] = []
        
        // Get mount info with better parsing
        let mountResult = runCommand("mount")
        let mountLines = mountResult.output.components(separatedBy: "\n")
        
        for line in mountLines {
            // Look for /Volumes mounts
            if line.contains("/Volumes/") && line.contains("on /Volumes/") {
                // Parse the line: /dev/diskXsY on /Volumes/VolumeName
                let components = line.components(separatedBy: " on ")
                if components.count >= 2 {
                    let devicePart = components[0].trimmingCharacters(in: .whitespaces)
                    let mountPathPart = components[1].components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    
                    // Extract device identifier
                    let deviceId = devicePart.replacingOccurrences(of: "/dev/", with: "")
                    
                    // Extract volume name from mount path
                    let volumeName = (mountPathPart as NSString).lastPathComponent
                    
                    if !deviceId.isEmpty && !volumeName.isEmpty {
                        // Get detailed info
                        var drive = getDriveInfo(deviceId: deviceId)
                        let updatedDrive = DriveInfo(
                            name: volumeName,
                            identifier: drive.identifier,
                            size: drive.size,
                            type: drive.type,
                            mountPoint: mountPathPart,
                            isInternal: drive.isInternal,
                            isEFI: drive.isEFI,
                            partitions: drive.partitions,
                            isMounted: true,
                            isSelectedForMount: false,
                            isSelectedForUnmount: false
                        )
                        
                        // Try to get better name from diskutil
                        let nameResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null | grep 'Volume Name:'")
                        if nameResult.success {
                            let nameComponents = nameResult.output.components(separatedBy: ":")
                            if nameComponents.count > 1 {
                                let diskutilName = nameComponents[1].trimmingCharacters(in: .whitespaces)
                                if !diskutilName.isEmpty && diskutilName != "Not applicable" {
                                    let updatedDriveWithName = DriveInfo(
                                        name: diskutilName,
                                        identifier: updatedDrive.identifier,
                                        size: updatedDrive.size,
                                        type: updatedDrive.type,
                                        mountPoint: updatedDrive.mountPoint,
                                        isInternal: updatedDrive.isInternal,
                                        isEFI: updatedDrive.isEFI,
                                        partitions: updatedDrive.partitions,
                                        isMounted: updatedDrive.isMounted,
                                        isSelectedForMount: updatedDrive.isSelectedForMount,
                                        isSelectedForUnmount: updatedDrive.isSelectedForUnmount
                                    )
                                    volumes.append(updatedDriveWithName)
                                    print("📌 Found mounted volume: \(diskutilName) at \(mountPathPart)")
                                    continue
                                }
                            }
                        }
                        
                        volumes.append(updatedDrive)
                        print("📌 Found mounted volume: \(volumeName) at \(mountPathPart)")
                    }
                }
            }
        }
        
        // Also check using df command for all mounts
        let dfResult = runCommand("df -h | grep '/Volumes/'")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 6 && components[5].hasPrefix("/Volumes/") {
                let devicePath = components[0]
                let mountPoint = components[5]
                
                if devicePath.hasPrefix("/dev/") {
                    let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                    let volumeName = (mountPoint as NSString).lastPathComponent
                    
                    // Check if we already have this volume
                    if !volumes.contains(where: { $0.identifier == deviceId }) {
                        var drive = getDriveInfo(deviceId: deviceId)
                        var size = drive.size
                        
                        // Get size from df output
                        if components.count >= 2 {
                            size = components[1]
                        }
                        
                        let updatedDrive = DriveInfo(
                            name: volumeName,
                            identifier: deviceId,
                            size: size,
                            type: drive.type,
                            mountPoint: mountPoint,
                            isInternal: drive.isInternal,
                            isEFI: drive.isEFI,
                            partitions: drive.partitions,
                            isMounted: true,
                            isSelectedForMount: false,
                            isSelectedForUnmount: false
                        )
                        
                        volumes.append(updatedDrive)
                        print("📌 Found mounted volume via df: \(volumeName) at \(mountPoint)")
                    }
                }
            }
        }
        
        return volumes
    }
    
    private func getUnmountedPartitions() -> [DriveInfo] {
        print("📌 Getting unmounted partitions...")
        var partitions: [DriveInfo] = []
        
        // Get list of all partitions
        let listResult = runCommand("""
        diskutil list | grep -o 'disk[0-9]\\+s[0-9]\\+' | sort -u
        """)
        
        let partitionIds = listResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for partitionId in partitionIds {
            // Skip if it's likely a system partition
            if partitionId.contains("EFI") || partitionId.contains("Recovery") {
                continue
            }
            
            // Check if it's already mounted
            let mountCheck = runCommand("mount | grep -q \"/dev/\(partitionId) \" && echo mounted || echo unmounted")
            let isMounted = mountCheck.output.contains("mounted")
            
            if !isMounted {
                let drive = getDriveInfo(deviceId: partitionId)
                
                // Only include if it has a valid name and size
                if drive.name != partitionId && drive.size != "Unknown" {
                    let unmountedDrive = DriveInfo(
                        name: drive.name,
                        identifier: drive.identifier,
                        size: drive.size,
                        type: drive.type,
                        mountPoint: "",
                        isInternal: drive.isInternal,
                        isEFI: drive.isEFI,
                        partitions: drive.partitions,
                        isMounted: false,
                        isSelectedForMount: false,
                        isSelectedForUnmount: false
                    )
                    
                    partitions.append(unmountedDrive)
                    print("📌 Found unmounted partition: \(drive.name) (\(partitionId))")
                }
            }
        }
        
        return partitions
    }
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting info for device: \(deviceId)")
        
        // Get detailed info from diskutil
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null")
        
        var name = deviceId
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = false
        var isUSB = false
        var isMounted = false
        
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Volume Name:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let volumeName = components[1].trimmingCharacters(in: .whitespaces)
                    if !volumeName.isEmpty && volumeName != "Not applicable" {
                        name = volumeName
                    }
                }
            } else if line.contains("Volume Size:") || line.contains("Disk Size:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    size = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if line.contains("Mount Point:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                    isMounted = !mountPoint.isEmpty && mountPoint != "Not applicable"
                }
            } else if line.contains("Protocol:") {
                let components = line.components(separatedBy: ":")
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
            } else if line.contains("Bus Protocol:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let busType = components[1].trimmingCharacters(in: .whitespaces)
                    if busType.contains("USB") {
                        isUSB = true
                        type = "USB"
                    }
                }
            } else if line.contains("Device / Media Name:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let mediaName = components[1].trimmingCharacters(in: .whitespaces)
                    if name == deviceId && !mediaName.isEmpty {
                        name = mediaName
                    }
                }
            }
        }
        
        // If still no name, use a generic one
        if name == deviceId {
            name = "Disk \(deviceId)"
        }
        
        // Determine type if still unknown
        if type == "Unknown" {
            if deviceId.starts(with: "disk0") || deviceId.starts(with: "disk1") || 
               deviceId.starts(with: "disk2") || deviceId.starts(with: "disk3") || 
               deviceId.starts(with: "disk4") {
                type = "Internal"
                isInternal = true
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
            isEFI: deviceId.contains("EFI"),
            partitions: [],
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    // Mount selected drives
    func mountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏫ Mounting selected drives")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForMount && !drive.isMounted {
            print("🔧 Mounting drive: \(drive.name) (\(drive.identifier))")
            
            let mountResult = runCommand("diskutil mount /dev/\(drive.identifier)")
            
            if mountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Mounted successfully")
            } else {
                failedCount += 1
                let errorMsg = mountResult.error.isEmpty ? "Unknown error" : mountResult.error
                messages.append("❌ \(drive.name): Failed - \(errorMsg)")
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
    
    // Unmount selected drives
    func unmountSelectedDrives(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            print("🔧 Unmounting drive: \(drive.name) (\(drive.identifier))")
            
            let unmountResult = runCommand("diskutil unmount /dev/\(drive.identifier)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted successfully")
            } else {
                failedCount += 1
                let errorMsg = unmountResult.error.isEmpty ? "Unknown error" : unmountResult.error
                messages.append("❌ \(drive.name): Failed - \(errorMsg)")
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
    
    // Mount all unmounted external drives
    func mountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏫ Mounting all external drives")
        
        let result = runCommand("""
        for disk in $(diskutil list | grep -o 'disk[0-9]\\+s[0-9]\\+' | sort -u); do
            if ! mount | grep -q "/dev/$disk "; then
                info=$(diskutil info /dev/$disk 2>/dev/null)
                if echo "$info" | grep -q 'Protocol.*USB\\|Bus Protocol.*USB\\|Removable.*Yes'; then
                    echo "$disk"
                fi
            fi
        done
        """)
        
        let diskIds = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in diskIds {
            let mountResult = runCommand("diskutil mount /dev/\(diskId)")
            
            if mountResult.success {
                successCount += 1
                messages.append("✅ Disk \(diskId): Mounted")
            } else {
                failedCount += 1
                messages.append("❌ Disk \(diskId): Failed")
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
    
    // Unmount all external drives
    func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all external drives")
        
        let result = runCommand("""
        mount | grep '/Volumes/' | awk '{print $1}' | sed 's|/dev/||' | sort -u
        """)
        
        let diskIds = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in diskIds {
            let unmountResult = runCommand("diskutil unmount /dev/\(diskId)")
            
            if unmountResult.success {
                successCount += 1
                messages.append("✅ Disk \(diskId): Unmounted")
            } else {
                failedCount += 1
                messages.append("❌ Disk \(diskId): Failed")
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
    
    func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    func checkFullDiskAccess() -> Bool {
        let testResult = runCommand("ls /Volumes/ 2>&1")
        return !testResult.error.contains("Operation not permitted")
    }
    
    func debugDriveDetection() -> String {
        var debugInfo = "=== Drive Detection Debug Info ===\n\n"
        
        debugInfo += "=== Mount Command Output ===\n"
        let mountCheck = runCommand("mount")
        debugInfo += "\(mountCheck.output)\n\n"
        
        debugInfo += "=== DF Command Output ===\n"
        let dfCheck = runCommand("df -h | grep -E '/Volumes/|Filesystem'")
        debugInfo += "\(dfCheck.output)\n\n"
        
        debugInfo += "=== /Volumes Directory ===\n"
        let volumesCheck = runCommand("ls -la /Volumes/")
        debugInfo += "\(volumesCheck.output)\n\n"
        
        debugInfo += "=== Diskutil List ===\n"
        let diskutilCheck = runCommand("diskutil list")
        debugInfo += "\(diskutilCheck.output)\n\n"
        
        return debugInfo
    }
}

// MARK: - Data Structures
struct DriveInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let identifier: String
    let size: String
    let type: String
    let mountPoint: String
    let isInternal: Bool
    let isEFI: Bool
    let partitions: [PartitionInfo]
    var isMounted: Bool
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
    static func == (lhs: DriveInfo, rhs: DriveInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
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
    var isMounted: Bool
    
    static func == (lhs: PartitionInfo, rhs: PartitionInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

// MARK: - Drive Manager
class DriveManager: ObservableObject {
    static let shared = DriveManager()
    private let shellHelper = ShellHelper.shared
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    @Published var mountSelection: Set<String> = []
    @Published var unmountSelection: Set<String> = []
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            DispatchQueue.main.async {
                // Preserve selection state by creating new DriveInfo objects with updated selection
                var updatedDrives: [DriveInfo] = []
                for drive in drives {
                    let updatedDrive = DriveInfo(
                        name: drive.name,
                        identifier: drive.identifier,
                        size: drive.size,
                        type: drive.type,
                        mountPoint: drive.mountPoint,
                        isInternal: drive.isInternal,
                        isEFI: drive.isEFI,
                        partitions: drive.partitions,
                        isMounted: drive.isMounted,
                        isSelectedForMount: self.mountSelection.contains(drive.identifier),
                        isSelectedForUnmount: self.unmountSelection.contains(drive.identifier)
                    )
                    updatedDrives.append(updatedDrive)
                }
                self.allDrives = updatedDrives
                self.isLoading = false
                self.objectWillChange.send()
                print("🔄 Refreshed drives. Found: \(self.allDrives.count)")
                for drive in self.allDrives {
                    print("   - \(drive.name) (\(drive.identifier)): \(drive.isMounted ? "Mounted" : "Unmounted") at \(drive.mountPoint)")
                }
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        print("🔘 Toggle mount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            let newIsSelectedForMount = !currentDrive.isSelectedForMount
            var newIsSelectedForUnmount = currentDrive.isSelectedForUnmount
            
            if newIsSelectedForMount && currentDrive.isSelectedForUnmount {
                newIsSelectedForUnmount = false
                unmountSelection.remove(drive.identifier)
            }
            
            if newIsSelectedForMount {
                mountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to mount selection")
            } else {
                mountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from mount selection")
            }
            
            // Update the drive in the array
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
            objectWillChange.send()
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        print("🔘 Toggle unmount selection for: \(drive.identifier)")
        
        if let index = allDrives.firstIndex(where: { $0.identifier == drive.identifier }) {
            let currentDrive = allDrives[index]
            let newIsSelectedForUnmount = !currentDrive.isSelectedForUnmount
            var newIsSelectedForMount = currentDrive.isSelectedForMount
            
            if newIsSelectedForUnmount && currentDrive.isSelectedForMount {
                newIsSelectedForMount = false
                mountSelection.remove(drive.identifier)
            }
            
            if newIsSelectedForUnmount {
                unmountSelection.insert(drive.identifier)
                print("✅ Added \(drive.identifier) to unmount selection")
            } else {
                unmountSelection.remove(drive.identifier)
                print("❌ Removed \(drive.identifier) from unmount selection")
            }
            
            // Update the drive in the array
            allDrives[index] = DriveInfo(
                name: currentDrive.name,
                identifier: currentDrive.identifier,
                size: currentDrive.size,
                type: currentDrive.type,
                mountPoint: currentDrive.mountPoint,
                isInternal: currentDrive.isInternal,
                isEFI: currentDrive.isEFI,
                partitions: currentDrive.partitions,
                isMounted: currentDrive.isMounted,
                isSelectedForMount: newIsSelectedForMount,
                isSelectedForUnmount: newIsSelectedForUnmount
            )
            
            objectWillChange.send()
        }
    }
    
    func selectAllForMount() {
        print("🔘 Select all for mount")
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        for drive in allDrives {
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: !drive.isMounted,
                isSelectedForUnmount: false
            )
            updatedDrives.append(updatedDrive)
            
            if !drive.isMounted {
                mountSelection.insert(drive.identifier)
            }
        }
        allDrives = updatedDrives
        objectWillChange.send()
    }
    
    func selectAllForUnmount() {
        print("🔘 Select all for unmount")
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        for drive in allDrives {
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: drive.isMounted
            )
            updatedDrives.append(updatedDrive)
            
            if drive.isMounted {
                unmountSelection.insert(drive.identifier)
            }
        }
        allDrives = updatedDrives
        objectWillChange.send()
    }
    
    func clearAllSelections() {
        print("🔘 Clear all selections")
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        var updatedDrives: [DriveInfo] = []
        for drive in allDrives {
            let updatedDrive = DriveInfo(
                name: drive.name,
                identifier: drive.identifier,
                size: drive.size,
                type: drive.type,
                mountPoint: drive.mountPoint,
                isInternal: drive.isInternal,
                isEFI: drive.isEFI,
                partitions: drive.partitions,
                isMounted: drive.isMounted,
                isSelectedForMount: false,
                isSelectedForUnmount: false
            )
            updatedDrives.append(updatedDrive)
        }
        allDrives = updatedDrives
        objectWillChange.send()
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Mounting selected drives")
        let drivesToMount = allDrives.filter { $0.isSelectedForMount }
        print("📦 Drives to mount: \(drivesToMount.count)")
        
        let result = shellHelper.mountSelectedDrives(drives: drivesToMount)
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
                self.clearAllSelections()
            }
        }
        return (result.success, result.message)
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        print("🚀 Unmounting selected drives")
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount }
        print("📦 Drives to unmount: \(drivesToUnmount.count)")
        
        let result = shellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
                self.clearAllSelections()
            }
        }
        return (result.success, result.message)
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Mount all external drives")
        let result = shellHelper.mountAllExternalDrives()
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
            }
        }
        return (result.success, result.message)
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        print("🚀 Unmount all external drives")
        let result = shellHelper.unmountAllExternalDrives()
        if result.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshDrives()
            }
        }
        return (result.success, result.message)
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var selectedDrive: DriveInfo?
    @StateObject private var driveManager = DriveManager.shared
    @State private var hasFullDiskAccess = false
    @State private var showDebugInfo = false
    
    let shellHelper = ShellHelper.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    DriveManagementView
                        .tabItem {
                            Label("Drives", systemImage: "externaldrive")
                        }
                        .tag(0)
                    
                    SystemInfoView
                        .tabItem {
                            Label("Info", systemImage: "info.circle")
                        }
                        .tag(1)
                }
                .tabViewStyle(.automatic)
            }
            
            if driveManager.isLoading {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive, driveManager: driveManager)
        }
        .onAppear {
            checkPermissions()
            driveManager.refreshDrives()
        }
    }
    
    // MARK: - Header View
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SystemMaintenance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Manual Drive Control")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let mountSelected = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                    let unmountSelected = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                    if mountSelected > 0 {
                        Text("\(mountSelected) to mount")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if unmountSelected > 0 {
                        Text("\(unmountSelected) to unmount")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                // Refresh Button
                Button(action: {
                    driveManager.refreshDrives()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.isLoading)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Drive Management View
    private var DriveManagementView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Control Panel
                ControlPanelView
                
                // Drives List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    DrivesListView
                }
                
                // Quick Actions
                QuickActionsGrid
            }
            .padding()
        }
    }
    
    private var ControlPanelView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Drive Controls")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Clear Selection Button
                Button("Clear All") {
                    driveManager.clearAllSelections()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(driveManager.mountSelection.isEmpty && driveManager.unmountSelection.isEmpty)
                
                // Debug Button
                Button("Debug") {
                    showDebugInfoAlert()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .foregroundColor(.red)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Mount Button
                Button(action: {
                    mountSelected()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Mount Selected")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(driveManager.allDrives.filter { $0.isSelectedForMount }.isEmpty)
                
                // Unmount Button
                Button(action: {
                    unmountSelected()
                }) {
                    HStack {
                        Image(systemName: "eject.fill")
                        Text("Unmount Selected")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.allDrives.filter { $0.isSelectedForUnmount }.isEmpty)
                
                Spacer()
                
                // Batch Selection Buttons
                VStack(spacing: 4) {
                    Button("Select All to Mount") {
                        driveManager.selectAllForMount()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Select All to Unmount") {
                        driveManager.selectAllForUnmount()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Connect a drive or check permissions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var DrivesListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Drives")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let mountCount = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                let unmountCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                if mountCount > 0 {
                    Text("\(mountCount) to mount")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if unmountCount > 0 {
                    Text("\(unmountCount) to unmount")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // List
            ForEach(driveManager.allDrives) { drive in
                DriveRow(drive: drive)
                    .onTapGesture {
                        selectedDrive = drive
                    }
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveRow(drive: DriveInfo) -> some View {
        HStack(spacing: 8) {
            // Mount/Unmount Selection
            VStack(spacing: 2) {
                // Mount checkbox (only for unmounted drives)
                if !drive.isMounted {
                    Button(action: {
                        driveManager.toggleMountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForMount ? "play.circle.fill" : "play.circle")
                            .foregroundColor(drive.isSelectedForMount ? .green : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to mount")
                }
                
                // Unmount checkbox (only for mounted drives)
                if drive.isMounted {
                    Button(action: {
                        driveManager.toggleUnmountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForUnmount ? "eject.circle.fill" : "eject.circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to unmount")
                }
            }
            .frame(width: 40)
            
            // Drive Icon
            Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                .foregroundColor(drive.isInternal ? .blue : .orange)
                .font(.title3)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(drive.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                
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
                        .foregroundColor(drive.type.contains("USB") ? .orange : .secondary)
                    
                    if !drive.mountPoint.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Status Badge
            if drive.isMounted {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            } else {
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Detail Button
            Button(action: {
                selectedDrive = drive
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
    
    private var QuickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ActionButton(
                title: "Refresh All",
                icon: "arrow.clockwise",
                color: .blue,
                action: {
                    driveManager.refreshDrives()
                    checkPermissions()
                }
            )
            
            ActionButton(
                title: "Mount All External",
                icon: "play.circle",
                color: .green,
                action: {
                    mountAllExternal()
                }
            )
            
            ActionButton(
                title: "Unmount All External",
                icon: "eject.circle",
                color: .orange,
                action: {
                    unmountAllExternal()
                }
            )
            
            ActionButton(
                title: "Clear Selection",
                icon: "xmark.circle",
                color: .gray,
                action: {
                    driveManager.clearAllSelections()
                }
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func ActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundColor(color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - System Info View
    private var SystemInfoView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("System Information")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        driveManager.refreshDrives()
                        showAlert(title: "Refreshed", message: "System information updated")
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Drives Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Storage Drives")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                        Text("\(mountedCount)/\(driveManager.allDrives.count) mounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if driveManager.allDrives.isEmpty {
                        Text("No drives detected")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(driveManager.allDrives) { drive in
                            DriveInfoCard(drive: drive)
                        }
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
    
    private func DriveInfoCard(drive: DriveInfo) -> some View {
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
                
                if drive.isMounted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
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
                
                if drive.isMounted && !drive.mountPoint.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            selectedDrive = drive
        }
    }
    
    // MARK: - Progress Overlay
    private var ProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading drives...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(20)
        }
    }
    
    // MARK: - Action Functions
    
    private func checkPermissions() {
        DispatchQueue.global(qos: .background).async {
            let hasAccess = shellHelper.checkFullDiskAccess()
            DispatchQueue.main.async {
                hasFullDiskAccess = hasAccess
                if !hasAccess {
                    showAlert(title: "Permissions Info",
                             message: "Full Disk Access is required for full functionality. The app will still work with limited features.")
                }
            }
        }
    }
    
    private func mountSelected() {
        let result = driveManager.mountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func unmountSelected() {
        let result = driveManager.unmountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountAllExternal() {
        let result = driveManager.mountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func unmountAllExternal() {
        let result = driveManager.unmountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func showDebugInfoAlert() {
        let debugInfo = shellHelper.debugDriveDetection()
        
        let alert = NSAlert()
        alert.messageText = "Drive Detection Debug Info"
        alert.informativeText = debugInfo
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(debugInfo, forType: .string)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Drive Detail View
struct DriveDetailView: View {
    let drive: DriveInfo
    @ObservedObject var driveManager: DriveManager
    @Environment(\.dismiss) var dismiss
    
    @State private var operationInProgress = false
    @State private var operationMessage = ""
    @State private var showOperationAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .font(.largeTitle)
                    .foregroundColor(drive.isInternal ? .blue : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Text(drive.identifier)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Mount Status Badge
                if drive.isMounted {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Mounted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                } else {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("Unmounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            Divider()
            
            // Drive Info
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Type:", value: drive.type)
                InfoRow(label: "Internal:", value: drive.isInternal ? "Yes" : "No")
                InfoRow(label: "Mount Point:", value: drive.mountPoint.isEmpty ? "Not mounted" : drive.mountPoint)
                InfoRow(label: "Selected for Mount:", value: getCurrentDrive()?.isSelectedForMount ?? false ? "Yes" : "No")
                InfoRow(label: "Selected for Unmount:", value: getCurrentDrive()?.isSelectedForUnmount ?? false ? "Yes" : "No")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Action Buttons
            HStack(spacing: 12) {
                if operationInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Mount/Unmount Toggle
                    let currentDrive = getCurrentDrive()
                    
                    if drive.isMounted {
                        Button(action: {
                            if let currentDrive = currentDrive {
                                driveManager.toggleUnmountSelection(for: currentDrive)
                            }
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: currentDrive?.isSelectedForUnmount ?? false ? "eject.circle.fill" : "eject.circle")
                                Text(currentDrive?.isSelectedForUnmount ?? false ? "Deselect Unmount" : "Select to Unmount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(currentDrive?.isSelectedForUnmount ?? false ? .orange : .blue)
                    } else {
                        Button(action: {
                            if let currentDrive = currentDrive {
                                driveManager.toggleMountSelection(for: currentDrive)
                            }
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: currentDrive?.isSelectedForMount ?? false ? "play.circle.fill" : "play.circle")
                                Text(currentDrive?.isSelectedForMount ?? false ? "Deselect Mount" : "Select to Mount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(currentDrive?.isSelectedForMount ?? false ? .green : .blue)
                    }
                    
                    Button("Show in Finder") {
                        showInFinder()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!drive.isMounted || drive.mountPoint.isEmpty)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
        .alert("Operation Result", isPresented: $showOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
        .onAppear {
            print("📱 DriveDetailView appeared for: \(drive.identifier)")
            print("📱 Current selection state - Mount: \(getCurrentDrive()?.isSelectedForMount ?? false), Unmount: \(getCurrentDrive()?.isSelectedForUnmount ?? false)")
        }
    }
    
    private func getCurrentDrive() -> DriveInfo? {
        return driveManager.allDrives.first { $0.identifier == drive.identifier }
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func showInFinder() {
        guard !drive.mountPoint.isEmpty else { return }
        
        let url = URL(fileURLWithPath: drive.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}