import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine  // Add this import

// MARK: - Shell Helper (Fixed)
class ShellHelper {
    static let shared = ShellHelper()
    
    private init() {}
    
    func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, error: String, success: Bool) {
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
            return ("", "Process execution error: \(error)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        return (output, errorOutput, success)
    }
    
    func findUSBDrives() -> [String] {
        var usbDrives: Set<String> = []
        
        let diskutilResult = runCommand("""
        diskutil list | grep -oE 'disk[0-9]+' | while read disk; do
            diskutil info /dev/$disk 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' >/dev/null && echo $disk
        done
        """)
        
        if diskutilResult.success && !diskutilResult.output.isEmpty {
            let drives = diskutilResult.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            drives.forEach { usbDrives.insert($0) }
        }
        
        return Array(usbDrives).sorted()
    }
    
    func getAllDrives() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        let listResult = runCommand("diskutil list")
        if listResult.success {
            drives = parseDiskUtilText(listResult.output)
        }
        
        // Get mount info for each drive
        for i in 0..<drives.count {
            let mountInfo = getMountInfo(for: drives[i].identifier)
            drives[i] = DriveInfo(
                name: drives[i].name,
                identifier: drives[i].identifier,
                size: drives[i].size,
                type: drives[i].type,
                mountPoint: mountInfo.mountPoint,
                isInternal: drives[i].isInternal,
                isEFI: drives[i].isEFI,
                partitions: drives[i].partitions,
                isMounted: mountInfo.isMounted
            )
        }
        
        drives.sort { !$0.isInternal && $1.isInternal }
        return drives
    }
    
    private func parseDiskUtilText(_ output: String) -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        var currentDisk: String?
        var currentSize: String = "Unknown"
        var currentType: String = "Unknown"
        var currentPartitions: [PartitionInfo] = []
        var isExternal = false
        
        for line in lines {
            // Look for disk header
            if line.hasPrefix("/dev/disk") && line.contains(":") {
                // Save previous disk if exists
                if let diskId = currentDisk {
                    drives.append(DriveInfo(
                        name: "Disk \(diskId)",
                        identifier: diskId,
                        size: currentSize,
                        type: isExternal ? "USB/External" : "Internal",
                        mountPoint: "",
                        isInternal: !isExternal,
                        isEFI: false,
                        partitions: currentPartitions,
                        isMounted: false
                    ))
                }
                
                // Parse new disk
                let components = line.components(separatedBy: ":")
                if components.count > 0 {
                    currentDisk = components[0].replacingOccurrences(of: "/dev/", with: "").trimmingCharacters(in: .whitespaces)
                    isExternal = line.lowercased().contains("external") || line.lowercased().contains("usb")
                    currentPartitions = []
                    
                    // Try to extract size
                    let sizePattern = #"\((\d+\.?\d*\s*[A-Z]{2})\)"#
                    if let range = line.range(of: sizePattern, options: .regularExpression) {
                        let sizeText = String(line[range])
                        currentSize = sizeText.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                    }
                }
            }
            // Look for partition info
            else if line.trimmingCharacters(in: .whitespaces).hasPrefix("0:") {
                let partitionComponents = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if partitionComponents.count >= 5 {
                    let partitionId = partitionComponents[0].replacingOccurrences(of: "0:", with: "")
                    let partitionName = partitionComponents[1]
                    let partitionType = partitionComponents[3]
                    var partitionSize = "Unknown"
                    
                    if partitionComponents.count > 5 {
                        partitionSize = partitionComponents[5]
                    }
                    
                    currentPartitions.append(PartitionInfo(
                        name: partitionName,
                        identifier: partitionId,
                        size: partitionSize,
                        type: partitionType,
                        mountPoint: "",
                        isEFI: partitionType.contains("EFI") || partitionName.contains("EFI"),
                        isMounted: false
                    ))
                }
            }
        }
        
        // Add last disk
        if let diskId = currentDisk {
            drives.append(DriveInfo(
                name: "Disk \(diskId)",
                identifier: diskId,
                size: currentSize,
                type: isExternal ? "USB/External" : "Internal",
                mountPoint: "",
                isInternal: !isExternal,
                isEFI: false,
                partitions: currentPartitions,
                isMounted: false
            ))
        }
        
        return drives
    }
    
    private func getMountInfo(for diskId: String) -> (mountPoint: String, isMounted: Bool) {
        let result = runCommand("diskutil info /dev/\(diskId) | grep 'Mount Point'")
        if result.success && !result.output.isEmpty {
            let components = result.output.components(separatedBy: ":")
            if components.count > 1 {
                let mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                if !mountPoint.isEmpty && mountPoint != "Not applicable" {
                    return (mountPoint, true)
                }
            }
        }
        return ("", false)
    }
    
    func mountDrive(_ diskId: String) -> (success: Bool, message: String, mountPoint: String) {
        // First check if already mounted
        let mountInfo = getMountInfo(for: diskId)
        if mountInfo.isMounted {
            return (true, "Drive already mounted at \(mountInfo.mountPoint)", mountInfo.mountPoint)
        }
        
        // Try to mount
        let mountResult = runCommand("diskutil mount /dev/\(diskId)")
        
        if mountResult.success {
            // Get new mount point
            let newMountInfo = getMountInfo(for: diskId)
            if newMountInfo.isMounted {
                return (true, "Successfully mounted at \(newMountInfo.mountPoint)", newMountInfo.mountPoint)
            } else {
                return (false, "Mount command succeeded but mount point not found", "")
            }
        } else {
            return (false, "Failed to mount: \(mountResult.error)", "")
        }
    }
    
    func unmountDrive(_ diskId: String) -> (success: Bool, message: String) {
        // Check if mounted
        let mountInfo = getMountInfo(for: diskId)
        if !mountInfo.isMounted {
            return (true, "Drive already unmounted")
        }
        
        // Try to unmount
        let unmountResult = runCommand("diskutil unmount /dev/\(diskId)")
        
        if unmountResult.success {
            return (true, "Successfully unmounted")
        } else {
            return (false, "Failed to unmount: \(unmountResult.error)")
        }
    }
    
    func mountEFIPartition(for diskId: String) -> (success: Bool, message: String, mountPoint: String) {
        // First, find EFI partition for this disk
        let findEFIResult = runCommand("""
        diskutil list /dev/\(diskId) | grep -i 'EFI.*FAT' | head -1
        """)
        
        guard findEFIResult.success && !findEFIResult.output.isEmpty else {
            return (false, "No EFI partition found for disk \(diskId)", "")
        }
        
        // Extract partition identifier (e.g., disk1s1)
        let lines = findEFIResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard lines.count >= 1 else {
            return (false, "Could not parse EFI partition info", "")
        }
        
        let efiPartitionId = lines[0].replacingOccurrences(of: "*", with: "")
        
        // Check if already mounted
        let efiMountInfo = getMountInfo(for: efiPartitionId)
        if efiMountInfo.isMounted {
            return (true, "EFI partition already mounted at \(efiMountInfo.mountPoint)", efiMountInfo.mountPoint)
        }
        
        // Mount EFI partition (may need sudo for EFI)
        let mountEFIResult = runCommand("sudo diskutil mount /dev/\(efiPartitionId)", needsSudo: true)
        
        if mountEFIResult.success {
            let newMountInfo = getMountInfo(for: efiPartitionId)
            if newMountInfo.isMounted {
                return (true, "EFI partition mounted at \(newMountInfo.mountPoint)", newMountInfo.mountPoint)
            } else {
                return (false, "Mount succeeded but mount point not found", "")
            }
        } else {
            return (false, "Failed to mount EFI: \(mountEFIResult.error)", "")
        }
    }
    
    func unmountAll() -> (success: Bool, message: String) {
        // Unmount all non-system volumes
        let result = runCommand("""
        diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | while read partition; do
            if diskutil info /dev/$partition 2>/dev/null | grep -q 'Mount Point.*/Volumes/'; then
                diskutil unmount /dev/$partition
            fi
        done
        """)
        
        return (result.success, result.success ? "All volumes unmounted" : "Failed to unmount some volumes")
    }
    
    func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status 2>/dev/null || echo 'Enabled'")
        return result.output.lowercased().contains("disabled")
    }
    
    func checkFullDiskAccess() -> Bool {
        let testResult = runCommand("ls /Volumes/ 2>&1")
        return !testResult.error.contains("Operation not permitted")
    }
}

// MARK: - Data Structures
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
    var isMounted: Bool
    
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
    var isMounted: Bool
    
    static func == (lhs: PartitionInfo, rhs: PartitionInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

struct SystemInfo {
    var macOSVersion: String = "Checking..."
    var buildNumber: String = "Checking..."
    var kernelVersion: String = "Checking..."
    var modelIdentifier: String = "Checking..."
    var processor: String = "Checking..."
    var memory: String = "Checking..."
    var bootMode: String = "Checking..."
}

// MARK: - Drive Manager
class DriveManager: ObservableObject {
    static let shared = DriveManager()
    private let shellHelper = ShellHelper.shared
    @Published var allDrives: [DriveInfo] = []
    @Published var isLoading = false
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            DispatchQueue.main.async {
                self.allDrives = drives
                self.isLoading = false
            }
        }
    }
    
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountDrive(drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.unmountDrive(drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func mountEFIPartition(for drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountEFIPartition(for: drive.identifier)
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountAll() -> (success: Bool, message: String) {
        let result = shellHelper.unmountAll()
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func getDriveBy(id: String) -> DriveInfo? {
        return allDrives.first { $0.identifier == id }
    }
}

// MARK: - Permission Manager (Fixed)
class PermissionManager {
    static let shared = PermissionManager()
    private let shellHelper = ShellHelper.shared
    
    private init() {}
    
    // MARK: - Main Fix All Permissions Function
    func fixAllPermissions() -> (success: Bool, report: String, needsRestart: Bool, manualSteps: [String]) {
        print("🛠️ Starting comprehensive permission fix...")
        
        var reportLines: [String] = ["=== SystemMaintenance Permission Fix Report ==="]
        var successSteps: [String] = []
        var failedSteps: [String] = []
        var manualSteps: [String] = []
        var needsRestart = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        reportLines.append("Generated: \(dateFormatter.string(from: Date()))")
        reportLines.append("")
        
        // Step 1: Check and fix app location
        reportLines.append("STEP 1: Application Location Check")
        let appLocationResult = checkAndFixAppLocation()
        reportLines.append(contentsOf: appLocationResult.report)
        if appLocationResult.success {
            successSteps.append("App Location")
            if appLocationResult.needsRestart {
                needsRestart = true
            }
        } else {
            failedSteps.append("App Location")
            manualSteps.append(contentsOf: appLocationResult.manualSteps)
        }
        reportLines.append("")
        
        // Step 2: Full Disk Access
        reportLines.append("STEP 2: Full Disk Access")
        let fdaResult = handleFullDiskAccess()
        reportLines.append(contentsOf: fdaResult.report)
        if fdaResult.success {
            successSteps.append("Full Disk Access")
        } else {
            failedSteps.append("Full Disk Access")
            manualSteps.append(contentsOf: fdaResult.manualSteps)
        }
        reportLines.append("")
        
        // Step 3: System Permissions
        reportLines.append("STEP 3: System File Permissions")
        let systemPermResult = fixSystemFilePermissions()
        reportLines.append(contentsOf: systemPermResult.report)
        if systemPermResult.success {
            successSteps.append("System Permissions")
        } else {
            failedSteps.append("System Permissions")
        }
        reportLines.append("")
        
        // Step 4: Disk Utility Permissions
        reportLines.append("STEP 4: Disk Utility Access")
        let diskUtilResult = fixDiskUtilityPermissions()
        reportLines.append(contentsOf: diskUtilResult.report)
        if diskUtilResult.success {
            successSteps.append("Disk Utility Access")
        } else {
            failedSteps.append("Disk Utility Access")
        }
        reportLines.append("")
        
        // Step 5: Kernel Extension Permissions
        reportLines.append("STEP 5: Kernel Extension Access")
        let kextResult = fixKextPermissions()
        reportLines.append(contentsOf: kextResult.report)
        if kextResult.success {
            successSteps.append("Kext Access")
        } else {
            failedSteps.append("Kext Access")
        }
        reportLines.append("")
        
        // Step 6: Reset Launch Services
        reportLines.append("STEP 6: System Cache Reset")
        let cacheResult = resetSystemCaches()
        reportLines.append(contentsOf: cacheResult.report)
        if cacheResult.success {
            successSteps.append("System Cache")
        } else {
            failedSteps.append("System Cache")
        }
        reportLines.append("")
        
        // Summary
        reportLines.append("=== SUMMARY ===")
        reportLines.append("Successful: \(successSteps.count) steps")
        reportLines.append("Failed: \(failedSteps.count) steps")
        reportLines.append("Manual Steps Required: \(manualSteps.count)")
        reportLines.append("Restart Needed: \(needsRestart ? "Yes" : "No")")
        reportLines.append("")
        
        if !successSteps.isEmpty {
            reportLines.append("✅ SUCCESSFUL STEPS:")
            for step in successSteps {
                reportLines.append("  • \(step)")
            }
        }
        
        if !failedSteps.isEmpty {
            reportLines.append("⚠️ FAILED STEPS:")
            for step in failedSteps {
                reportLines.append("  • \(step)")
            }
        }
        
        if !manualSteps.isEmpty {
            reportLines.append("🛠️ MANUAL STEPS REQUIRED:")
            for (index, step) in manualSteps.enumerated() {
                reportLines.append("  \(index + 1). \(step)")
            }
        }
        
        let overallSuccess = failedSteps.isEmpty && manualSteps.isEmpty
        
        return (overallSuccess, reportLines.joined(separator: "\n"), needsRestart, manualSteps)
    }
    
    // MARK: - Step 1: App Location
    private func checkAndFixAppLocation() -> (success: Bool, report: [String], needsRestart: Bool, manualSteps: [String]) {
        var report: [String] = []
        var manualSteps: [String] = []
        let needsRestart: Bool
        
        let appPath = Bundle.main.bundlePath
        let appName = (appPath as NSString).lastPathComponent
        
        report.append("Current location: \(appPath)")
        
        // Check if in Applications folder
        if appPath.contains("/Applications/") {
            report.append("✅ App is in Applications folder")
            
            // Fix permissions on existing app
            let commands = [
                "xattr -c \"\(appPath)\"",
                "chmod -R 755 \"\(appPath)\"",
                "chown -R $(whoami):staff \"\(appPath)\"",
                "xattr -d com.apple.quarantine \"\(appPath)\" 2>/dev/null || true"
            ]
            
            var allSuccess = true
            for command in commands {
                let result = shellHelper.runCommand(command)
                if result.success {
                    report.append("  ✅ \(command.components(separatedBy: " ").first ?? command)")
                } else {
                    report.append("  ⚠️ Failed: \(command)")
                    allSuccess = false
                }
            }
            
            needsRestart = false
            return (allSuccess, report, needsRestart, manualSteps)
        } else {
            report.append("⚠️ App is NOT in Applications folder")
            report.append("For Full Disk Access to work properly, app must be in /Applications/")
            
            manualSteps.append("Move \(appName) to /Applications/ folder")
            manualSteps.append("Remove old app from current location after moving")
            manualSteps.append("Grant Full Disk Access to the app in /Applications/")
            
            needsRestart = true
            return (false, report, needsRestart, manualSteps)
        }
    }
    
    // MARK: - Step 2: Full Disk Access
    private func handleFullDiskAccess() -> (success: Bool, report: [String], manualSteps: [String]) {
        var report: [String] = []
        var manualSteps: [String] = []
        
        // Test FDA
        let testCommands = [
            ("ls /Volumes", "List volumes"),
            ("ls /System/Library/Extensions", "List system extensions"),
            ("diskutil list", "List disks")
        ]
        
        var hasAccess = true
        for (command, description) in testCommands {
            let result = shellHelper.runCommand(command)
            if !result.success && result.error.contains("Operation not permitted") {
                report.append("❌ \(description): Permission denied")
                hasAccess = false
            } else {
                report.append("✅ \(description): Access granted")
            }
        }
        
        if hasAccess {
            report.append("✅ Full Disk Access appears to be working")
            return (true, report, manualSteps)
        } else {
            report.append("⚠️ Full Disk Access not fully granted")
            manualSteps.append("Open System Settings → Privacy & Security → Full Disk Access")
            manualSteps.append("Click '+' and select SystemMaintenance from /Applications/")
            manualSteps.append("Toggle the switch ON (make sure it's checked)")
            manualSteps.append("Restart SystemMaintenance")
            return (false, report, manualSteps)
        }
    }
    
    // MARK: - Step 3: System File Permissions
    private func fixSystemFilePermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let directories = [
            "/System/Library/Extensions",
            "/Library/Extensions",
            "/Library/Application Support"
        ]
        
        var successCount = 0
        var totalCount = 0
        
        for directory in directories {
            let commands = [
                "chmod -R 755 \"\(directory)\" 2>/dev/null || true",
                "chown -R root:wheel \"\(directory)\" 2>/dev/null || true",
                "touch \"\(directory)\" 2>/dev/null || true"
            ]
            
            for command in commands {
                totalCount += 1
                let result = shellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    successCount += 1
                }
            }
        }
        
        let successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) : 1.0
        let success = successRate >= 0.8
        
        report.append("Fixed permissions for \(successCount)/\(totalCount) operations (\(Int(successRate * 100))%)")
        
        return (success, report)
    }
    
    // MARK: - Step 4: Disk Utility Permissions
    private func fixDiskUtilityPermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let commands = [
            "sudo killall diskmanagementd 2>/dev/null || true",
            "sudo killall diskarbitrationd 2>/dev/null || true"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: true)
            if result.success {
                successCount += 1
            }
        }
        
        // Test diskutil access
        let testResult = shellHelper.runCommand("diskutil list 2>&1 | head -5")
        let hasAccess = testResult.success && !testResult.error.contains("Operation not permitted")
        
        if hasAccess {
            report.append("✅ Disk Utility access working")
            return (true, report)
        } else {
            report.append("⚠️ Disk Utility access may be limited")
            report.append("Error: \(testResult.error.prefix(100))")
            return (false, report)
        }
    }
    
    // MARK: - Step 5: Kext Permissions
    private func fixKextPermissions() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        // Check SIP status first
        let sipDisabled = shellHelper.isSIPDisabled()
        
        report.append("SIP Status: \(sipDisabled ? "Disabled ✓" : "Enabled ⚠️")")
        
        if !sipDisabled {
            report.append("Note: SIP must be disabled for kext loading")
            return (false, report)
        }
        
        // Fix kextcache permissions
        let commands = [
            "sudo chmod 755 /System/Library/Extensions",
            "sudo chmod 755 /Library/Extensions",
            "sudo touch /System/Library/Extensions",
            "sudo touch /Library/Extensions"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: true)
            if result.success {
                successCount += 1
            }
        }
        
        // Rebuild kernel cache
        report.append("Rebuilding kernel cache...")
        let cacheResult = shellHelper.runCommand("sudo kextcache -i /", needsSudo: true)
        
        if cacheResult.success {
            report.append("✅ Kernel cache rebuild initiated")
        } else {
            report.append("⚠️ Kernel cache rebuild may have issues")
            report.append("Error: \(cacheResult.error.prefix(100))")
        }
        
        let success = successCount >= 3
        return (success, report)
    }
    
    // MARK: - Step 6: System Cache Reset
    private func resetSystemCaches() -> (success: Bool, report: [String]) {
        var report: [String] = []
        
        let commands = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user",
            "sudo update_dyld_shared_cache -force 2>/dev/null || true",
            "sudo rm -rf /Library/Caches/* 2>/dev/null || true"
        ]
        
        var successCount = 0
        for command in commands {
            let result = shellHelper.runCommand(command, needsSudo: command.contains("sudo"))
            if result.success || result.error.isEmpty {
                successCount += 1
            }
        }
        
        report.append("Reset \(successCount)/\(commands.count) cache operations")
        
        return (successCount > 1, report)
    }
    
    // MARK: - Quick Permission Check
    func getPermissionStatusText() -> String {
        let appPath = Bundle.main.bundlePath
        let inApps = appPath.contains("/Applications/")
        let hasFDA = shellHelper.checkFullDiskAccess()
        let sipDisabled = shellHelper.isSIPDisabled()
        
        var status = "🔍 Permission Status:\n\n"
        status += "Application Location: \(inApps ? "✅ /Applications/" : "❌ Not in Applications")\n"
        status += "Full Disk Access: \(hasFDA ? "✅ Granted" : "❌ Not Granted")\n"
        status += "SIP Status: \(sipDisabled ? "✅ Disabled" : "⚠️ Enabled")\n"
        
        return status
    }
    
    // MARK: - Open System Settings Helper
    func openSystemSettings() {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "System Settings Opened"
                alert.informativeText = """
                Please:
                1. Go to Privacy & Security → Full Disk Access
                2. Click the lock icon (bottom left) to make changes
                3. Click '+' and select SystemMaintenance from /Applications/
                4. Make sure the checkbox is enabled
                5. Restart SystemMaintenance
                
                If SystemMaintenance is not in /Applications/, please move it there first.
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                
                alert.runModal()
            }
        }
    }
    
    // MARK: - Public method to show guide (not private)
    func showDetailedGuide() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "📋 Complete Permission Setup Guide"
            alert.informativeText = """
            1. APPLICATION LOCATION
               • SystemMaintenance MUST be in /Applications/ folder
               • If it's in Downloads or elsewhere, move it to Applications
               • Right-click the app → "Move to Applications"
            
            2. FULL DISK ACCESS
               • Open System Settings → Privacy & Security → Full Disk Access
               • Click the lock icon (bottom left), enter password
               • Click the '+' button
               • Navigate to /Applications/ → Select "SystemMaintenance.app"
               • Make sure the checkbox is checked (enabled)
            
            3. RESTART APPLICATION
               • Quit SystemMaintenance completely
               • Open it again from /Applications/
            
            4. SYSTEM INTEGRITY PROTECTION (SIP)
               For USB boot and kext installation, SIP should be disabled:
               • Restart Mac and hold Cmd+R (Recovery Mode)
               • Open Terminal from Utilities menu
               • Run: csrutil disable
               • Reboot
            
            TROUBLESHOOTING:
            • If drives not detected: Grant Full Disk Access
            • If can't mount EFI: Check SIP is disabled
            • If app crashes: Ensure it's in /Applications/
            • If "Operation not permitted": Re-grant Full Disk Access
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open System Settings")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.openSystemSettings()
            }
        }
    }
}

// MARK: - Permission Fix View
struct PermissionFixView: View {
    @Binding var isPresented: Bool
    @State private var fixInProgress = false
    @State private var fixComplete = false
    @State private var fixReport = ""
    @State private var needsRestart = false
    @State private var manualSteps: [String] = []
    @State private var showDetailedReport = false
    
    let permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "lock.shield")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Fix All Permissions")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Comprehensive permission repair for SystemMaintenance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
            
            Divider()
            
            if fixInProgress {
                FixInProgressView
            } else if fixComplete {
                FixCompleteView
            } else {
                InitialView
            }
            
            Spacer()
            
            // Footer
            HStack {
                Button("Quick Check") {
                    runQuickCheck()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.bordered)
                
                Button("Show Guide") {
                    permissionManager.showDetailedGuide()
                }
                .buttonStyle(.bordered)
                
                Button(fixInProgress ? "Fixing..." : "Start Fix") {
                    if !fixInProgress {
                        startFix()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(fixInProgress)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 700, height: 600)
    }
    
    private var InitialView: some View {
        VStack(spacing: 16) {
            Text("This will fix:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FixItem(icon: "folder", text: "Application location and permissions")
                FixItem(icon: "lock.open", text: "Full Disk Access setup")
                FixItem(icon: "gear", text: "System file permissions")
                FixItem(icon: "internaldrive", text: "Disk Utility access")
                FixItem(icon: "puzzlepiece", text: "Kernel extension permissions")
                FixItem(icon: "trash", text: "System cache reset")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            
            Text("⚠️ Some steps may require administrator password")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("Make sure SystemMaintenance is in your Applications folder for best results.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var FixInProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Fixing permissions...")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This may take a few minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressStep(step: "Application Location", isActive: true)
                ProgressStep(step: "Full Disk Access", isActive: true)
                ProgressStep(step: "System Permissions", isActive: true)
                ProgressStep(step: "Disk Utility", isActive: true)
                ProgressStep(step: "Kernel Extensions", isActive: true)
                ProgressStep(step: "System Cache", isActive: true)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    private var FixCompleteView: some View {
        VStack(spacing: 20) {
            Image(systemName: needsRestart ? "exclamationmark.triangle" : "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(needsRestart ? .orange : .green)
            
            Text(needsRestart ? "Manual Steps Required" : "Fix Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(needsRestart ? .orange : .green)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary:")
                        .font(.headline)
                    
                    if needsRestart {
                        Text("Please complete these manual steps:")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        ForEach(Array(manualSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(step)
                                    .font(.caption)
                            }
                            .padding(.leading, 8)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    if showDetailedReport {
                        Text("Detailed Report:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text(fixReport)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 300)
            
            HStack {
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fixReport, forType: .string)
                }
                .buttonStyle(.bordered)
                
                Button(showDetailedReport ? "Hide Details" : "Show Details") {
                    showDetailedReport.toggle()
                }
                .buttonStyle(.bordered)
                
                if needsRestart {
                    Button("Show Guide") {
                        permissionManager.showDetailedGuide()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
    }
    
    private func FixItem(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private func ProgressStep(step: String, isActive: Bool) -> some View {
        HStack {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(step)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
            Spacer()
            if isActive {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }
    
    private func startFix() {
        fixInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = permissionManager.fixAllPermissions()
            
            DispatchQueue.main.async {
                fixInProgress = false
                fixComplete = true
                fixReport = result.report
                needsRestart = result.needsRestart
                manualSteps = result.manualSteps
                
                if result.success && !needsRestart {
                    let alert = NSAlert()
                    alert.messageText = "Permissions Fixed Successfully"
                    alert.informativeText = "All permissions have been fixed. You may need to restart the application for changes to take full effect."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    private func runQuickCheck() {
        let status = permissionManager.getPermissionStatusText()
        
        let alert = NSAlert()
        alert.messageText = "Permission Status Check"
        alert.informativeText = status
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Fix Now")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            startFix()
        }
    }
}

// MARK: - Drive Detail View
struct DriveDetailView: View {
    let drive: DriveInfo
    @EnvironmentObject var driveManager: DriveManager
    @State private var showingMountAction = false
    @State private var showingUnmountAction = false
    @State private var showingEFIAction = false
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
                InfoRow(label: "Partitions:", value: "\(drive.partitions.count)")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Partition List
            if !drive.partitions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Partitions")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(drive.partitions) { partition in
                                PartitionRow(partition: partition)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if operationInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        if drive.isMounted {
                            unmountDrive()
                        } else {
                            mountDrive()
                        }
                    }) {
                        HStack {
                            Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                            Text(drive.isMounted ? "Unmount" : "Mount")
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(drive.isMounted ? .orange : .blue)
                    
                    // EFI Button (only show if drive has EFI partitions)
                    if drive.partitions.contains(where: { $0.isEFI }) {
                        Button("Mount EFI") {
                            mountEFIPartition()
                        }
                        .buttonStyle(.bordered)
                        .disabled(drive.isMounted)
                    }
                    
                    Button("Show in Finder") {
                        showInFinder()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!drive.isMounted || drive.mountPoint.isEmpty)
                }
                
                Spacer()
                
                Button("Refresh") {
                    driveManager.refreshDrives()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 500)
        .alert("Operation Result", isPresented: $showOperationAlert) {
            Button("OK") { }
        } message: {
            Text(operationMessage)
        }
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func PartitionRow(partition: PartitionInfo) -> some View {
        HStack {
            Image(systemName: partition.isEFI ? "puzzlepiece.fill" : "square.fill")
                .foregroundColor(partition.isEFI ? .purple : .gray)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(partition.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(partition.identifier)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(partition.size)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(partition.type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func mountDrive() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.mountDrive(drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func unmountDrive() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.unmountDrive(drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func mountEFIPartition() {
        operationInProgress = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = driveManager.mountEFIPartition(for: drive)
            DispatchQueue.main.async {
                operationInProgress = false
                operationMessage = result.message
                showOperationAlert = true
            }
        }
    }
    
    private func showInFinder() {
        guard !drive.mountPoint.isEmpty else { return }
        
        let url = URL(fileURLWithPath: drive.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Main Content View
@MainActor
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var showPermissionFixView = false
    @State private var selectedDrive: DriveInfo?
    @State private var showDriveDetail = false
    @StateObject private var driveManager = DriveManager.shared
    @State private var hasFullDiskAccess = false
    
    let shellHelper = ShellHelper.shared
    let permissionManager = PermissionManager.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    SystemMaintenanceView
                        .tabItem {
                            Label("System", systemImage: "gear")
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
        .sheet(isPresented: $showPermissionFixView) {
            PermissionFixView(isPresented: $showPermissionFixView)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive)
                .environmentObject(driveManager)
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
                
                // Drive Count
                VStack(alignment: .trailing, spacing: 2) {
                    let internalCount = driveManager.allDrives.filter { $0.isInternal }.count
                    let externalCount = driveManager.allDrives.filter { !$0.isInternal }.count
                    Text("\(internalCount) Internal • \(externalCount) External")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(driveManager.allDrives.count) Total Drives")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // SIP Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(shellHelper.isSIPDisabled() ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text("SIP: \(shellHelper.isSIPDisabled() ? "Disabled" : "Enabled")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(shellHelper.isSIPDisabled() ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(20)
                
                // Fix Permissions Button
                Button(action: {
                    showPermissionFixView = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Fix Permissions")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - System Maintenance View
    private var SystemMaintenanceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Permission Warning
                if !hasFullDiskAccess {
                    PermissionWarningSection
                }
                
                // Drive Management
                DriveManagementSection
                
                // Permission Fix Section
                PermissionFixSection
                
                // Quick Actions
                QuickActionsGrid
            }
            .padding()
        }
    }
    
    private var PermissionWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Permissions Required")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("Fix Now") {
                    showPermissionFixView = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            
            Text("SystemMaintenance needs Full Disk Access to detect and mount drives. Please grant access in System Settings > Privacy & Security > Full Disk Access.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var DriveManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Drive Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Unmount All") {
                        unmountAllDrives()
                    }
                    .buttonStyle(.bordered)
                    .disabled(driveManager.allDrives.allSatisfy { !$0.isMounted })
                    
                    Button(action: {
                        driveManager.refreshDrives()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(driveManager.isLoading)
                }
            }
            
            if driveManager.allDrives.isEmpty {
                EmptyDrivesView
            } else {
                DrivesListView
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
            
            if !hasFullDiskAccess {
                Text("Grant Full Disk Access to detect drives")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Try refreshing or connect a USB drive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Check USB Drives") {
                checkUSBDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var DrivesListView: some View {
        VStack(spacing: 8) {
            ForEach(driveManager.allDrives) { drive in
                DriveRow(drive: drive)
                    .onTapGesture {
                        selectedDrive = drive
                    }
            }
        }
    }
    
    private func DriveRow(drive: DriveInfo) -> some View {
        HStack {
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
                        .foregroundColor(.secondary)
                    
                    if !drive.mountPoint.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Spacer()
            
            // Mount/Unmount Button
            Button(action: {
                toggleMount(drive)
            }) {
                HStack {
                    Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        .font(.caption)
                    Text(drive.isMounted ? "Unmount" : "Mount")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(drive.isMounted ? .orange : .blue)
            
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
    
    private var PermissionFixSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Permission Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Quick Check") {
                    runQuickPermissionCheck()
                }
                .buttonStyle(.bordered)
            }
            
            let status = permissionManager.getPermissionStatusText()
            Text(status)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("Open System Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.bordered)
                
                Button("Show Guide") {
                    permissionManager.showDetailedGuide()
                }
                .buttonStyle(.bordered)
                
                Button("Fix All") {
                    showPermissionFixView = true
                }
                .buttonStyle(.borderedProminent)
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
                title: "Check USB",
                icon: "magnifyingglass",
                color: .green,
                action: checkUSBDrives
            )
            
            ActionButton(
                title: "System Info",
                icon: "info.circle",
                color: .purple,
                action: showSystemInfo
            )
            
            ActionButton(
                title: "Unmount All",
                icon: "eject",
                color: .orange,
                action: unmountAllDrives
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
                
                // Permission Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permission Status")
                        .font(.headline)
                    
                    let status = permissionManager.getPermissionStatusText()
                    Text(status)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drives Info
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Storage Drives")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(driveManager.allDrives.count) drives total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(driveManager.allDrives) { drive in
                            DriveInfoCard(drive: drive)
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
                
                if !drive.mountPoint.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            
            if !drive.partitions.isEmpty {
                Text("Partitions: \(drive.partitions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    showAlert(title: "Permissions Required", 
                             message: "Full Disk Access is required for drive detection. Use 'Fix Permissions' to resolve this.")
                }
            }
        }
    }
    
    private func toggleMount(_ drive: DriveInfo) {
        if drive.isMounted {
            let result = driveManager.unmountDrive(drive)
            showAlert(title: result.success ? "Unmounted" : "Error", 
                     message: result.message)
        } else {
            let result = driveManager.mountDrive(drive)
            showAlert(title: result.success ? "Mounted" : "Error", 
                     message: result.message)
        }
    }
    
    private func unmountAllDrives() {
        let result = driveManager.unmountAll()
        showAlert(title: result.success ? "Unmounted All" : "Error", 
                 message: result.message)
    }
    
    private func checkUSBDrives() {
        let usbDrives = shellHelper.findUSBDrives()
        
        if usbDrives.isEmpty {
            showAlert(title: "No USB Drives", 
                     message: "No USB drives detected.\n\nPlease ensure:\n1. USB drive is connected\n2. Try different USB port\n3. Check if drive appears in Disk Utility")
        } else {
            showAlert(title: "USB Drives Found", 
                     message: "Found \(usbDrives.count) USB drive(s):\n\n\(usbDrives.joined(separator: "\n"))")
        }
    }
    
    private func showSystemInfo() {
        let appPath = Bundle.main.bundlePath
        let inApps = appPath.contains("/Applications/")
        let hasFDA = shellHelper.checkFullDiskAccess()
        let sipDisabled = shellHelper.isSIPDisabled()
        
        var info = "=== System Information ===\n\n"
        info += "App Path: \(appPath)\n"
        info += "In Applications: \(inApps ? "Yes" : "No")\n"
        info += "Full Disk Access: \(hasFDA ? "Granted" : "Not Granted")\n"
        info += "SIP Status: \(sipDisabled ? "Disabled" : "Enabled")\n"
        info += "USB Drives: \(shellHelper.findUSBDrives().count)\n"
        info += "Total Drives: \(driveManager.allDrives.count)\n"
        info += "Mounted Drives: \(driveManager.allDrives.filter { $0.isMounted }.count)\n"
        
        showAlert(title: "System Information", message: info)
    }
    
    private func runQuickPermissionCheck() {
        let status = permissionManager.getPermissionStatusText()
        showAlert(title: "Permission Status", message: status)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
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