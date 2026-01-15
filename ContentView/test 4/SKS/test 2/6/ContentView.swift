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
    
    // Get ALL drives (mounted and unmounted)
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives (mounted and unmounted)...")
        
        var drives: [DriveInfo] = []
        var processedDisks: Set<String> = []
        
        // Get list of all disk devices
        let disksResult = runCommand("ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$' | sort -u")
        let diskIds = disksResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        print("📊 Found disk IDs: \(diskIds)")
        
        for diskId in diskIds {
            // Get disk info
            let diskInfo = getDiskInfo(diskId: diskId)
            
            // Check if already processed
            if !processedDisks.contains(diskInfo.identifier) {
                drives.append(diskInfo)
                processedDisks.insert(diskInfo.identifier)
            }
        }
        
        // Sort: mounted first, then by name
        drives.sort {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.name < $1.name
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDiskInfo(diskId: String) -> DriveInfo {
        print("📋 Getting info for disk: \(diskId)")
        
        // Check if disk is mounted and get mount point
        let mountCheck = runCommand("mount | grep \"/dev/\(diskId)\" | head -1")
        let isMounted = !mountCheck.output.isEmpty
        
        var mountPoint = ""
        var name = "Disk \(diskId)"
        var size = "Unknown"
        var isInternal = false
        var isUSB = false
        
        if isMounted {
            // Parse mount point from mount command
            let parts = mountCheck.output.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 3 {
                mountPoint = parts[2]
                
                // Determine name from mount point
                if mountPoint == "/" {
                    name = "System Disk"
                    isInternal = true
                } else if mountPoint.contains("/Volumes/") {
                    let volumeName = (mountPoint as NSString).lastPathComponent
                    name = volumeName.isEmpty ? "Disk \(diskId)" : volumeName
                    isInternal = mountPoint.contains("/System/Volumes/")
                }
            }
            
            // Get size for mounted disks
            if !mountPoint.isEmpty {
                let sizeResult = runCommand("df -h \"\(mountPoint)\" 2>/dev/null | tail -1")
                if sizeResult.success {
                    let parts = sizeResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        size = parts[1]
                    }
                }
            }
        } else {
            // For unmounted disks, try to get size from diskutil info
            let infoResult = runCommand("diskutil info /dev/\(diskId) 2>/dev/null | grep -E 'Size|Protocol'")
            if infoResult.success {
                let lines = infoResult.output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("Size") {
                        let components = line.components(separatedBy: ":")
                        if components.count > 1 {
                            size = components[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                    if line.contains("Protocol") && line.contains("USB") {
                        isUSB = true
                    }
                }
            }
            
            // Try to get disk name from potential volume name
            let nameResult = runCommand("diskutil info /dev/\(diskId) 2>/dev/null | grep 'Volume Name'")
            if nameResult.success && !nameResult.output.isEmpty {
                let components = nameResult.output.components(separatedBy: ":")
                if components.count > 1 {
                    let volumeName = components[1].trimmingCharacters(in: .whitespaces)
                    if !volumeName.isEmpty && volumeName != "Not applicable" {
                        name = volumeName
                    }
                }
            }
        }
        
        // Check if USB/External
        if !isInternal {
            let usbCheck = runCommand("""
            diskutil info /dev/\(diskId) 2>/dev/null | grep -E 'Protocol.*USB|Bus Protocol.*USB|Removable.*Yes' | head -1
            """)
            isUSB = !usbCheck.output.isEmpty
        }
        
        let driveType = isUSB ? "USB/External" : (isInternal ? "Internal" : "External")
        
        // Get partitions
        let partitions = getPartitionsForDisk(diskId: diskId)
        
        return DriveInfo(
            name: name,
            identifier: diskId,
            size: size,
            type: driveType,
            mountPoint: mountPoint,
            isInternal: isInternal,
            isEFI: false,
            partitions: partitions,
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    private func getPartitionsForDisk(diskId: String) -> [PartitionInfo] {
        var partitions: [PartitionInfo] = []
        
        // List partitions for this disk
        let lsResult = runCommand("ls /dev/\(diskId)s* 2>/dev/null || echo ''")
        let partitionIds = lsResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for partitionPath in partitionIds {
            let partitionId = (partitionPath as NSString).lastPathComponent
            
            // Get mount point
            let mountResult = runCommand("mount | grep \"/dev/\(partitionId) \" | awk '{print $3}'")
            let mountPoint = mountResult.output
            
            let isMounted = !mountPoint.isEmpty
            let isEFI = partitionId.contains("EFI") || mountPoint.contains("EFI")
            
            // Get partition name
            var partitionName = partitionId
            if isMounted {
                let nameResult = runCommand("diskutil info /dev/\(partitionId) 2>/dev/null | grep 'Volume Name'")
                if nameResult.success && !nameResult.output.isEmpty {
                    let components = nameResult.output.components(separatedBy: ":")
                    if components.count > 1 {
                        let name = components[1].trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty && name != "Not applicable" {
                            partitionName = name
                        }
                    }
                }
            }
            
            partitions.append(PartitionInfo(
                name: partitionName,
                identifier: partitionId,
                size: "Unknown",
                type: isEFI ? "EFI" : "Partition",
                mountPoint: mountPoint,
                isEFI: isEFI,
                isMounted: isMounted
            ))
        }
        
        return partitions
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
        
        // Get all unmounted external disks
        let unmountedResult = runCommand("""
        for disk in $(ls /dev/disk* 2>/dev/null | grep -E 'disk[0-9]+$'); do
            disk_name=$(basename $disk)
            if ! mount | grep -q "/dev/$disk_name"; then
                # Check if external
                if diskutil info $disk 2>/dev/null | grep -q 'Protocol.*USB\\|Bus Protocol.*USB\\|Removable.*Yes'; then
                    echo $disk_name
                fi
            fi
        done
        """)
        
        let diskIds = unmountedResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
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
        
        // Get all mounted external disks
        let mountedResult = runCommand("""
        mount | grep '/Volumes/' | grep -v '/System/Volumes/' | awk '{print $1}' | sed 's|/dev/||' | cut -d's' -f1 | sort -u
        """)
        
        let diskIds = mountedResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
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
    
    // Add missing debugDriveDetection method
    func debugDriveDetection() -> String {
        var debugInfo = "=== Drive Detection Debug Info ===\n\n"
        
        // Check for disk devices
        let diskCheck = runCommand("ls -la /dev/disk* 2>&1")
        debugInfo += "Disk devices in /dev:\n\(diskCheck.output)\n\n"
        
        // Check mount output
        let mountCheck = runCommand("mount 2>&1")
        debugInfo += "Current mounts:\n\(mountCheck.output)\n\n"
        
        // Check diskutil list
        let diskutilCheck = runCommand("diskutil list 2>&1")
        debugInfo += "Diskutil list:\n\(diskutilCheck.output)\n\n"
        
        // Check for specific disk info
        let systemDriveCheck = runCommand("diskutil info disk0 2>&1")
        debugInfo += "System disk (disk0) info:\n\(systemDriveCheck.output)\n\n"
        
        return debugInfo
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
    var isSelectedForMount: Bool
    var isSelectedForUnmount: Bool
    
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
                // Preserve selection state
                var updatedDrives: [DriveInfo] = []
                for var drive in drives {
                    drive.isSelectedForMount = self.mountSelection.contains(drive.identifier)
                    drive.isSelectedForUnmount = self.unmountSelection.contains(drive.identifier)
                    updatedDrives.append(drive)
                }
                self.allDrives = updatedDrives
                self.isLoading = false
            }
        }
    }
    
    func toggleMountSelection(for drive: DriveInfo) {
        if let index = allDrives.firstIndex(where: { $0.id == drive.id }) {
            allDrives[index].isSelectedForMount.toggle()
            
            if allDrives[index].isSelectedForMount {
                mountSelection.insert(drive.identifier)
                // Deselect from unmount if selected
                if allDrives[index].isSelectedForUnmount {
                    allDrives[index].isSelectedForUnmount = false
                    unmountSelection.remove(drive.identifier)
                }
            } else {
                mountSelection.remove(drive.identifier)
            }
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        if let index = allDrives.firstIndex(where: { $0.id == drive.id }) {
            allDrives[index].isSelectedForUnmount.toggle()
            
            if allDrives[index].isSelectedForUnmount {
                unmountSelection.insert(drive.identifier)
                // Deselect from mount if selected
                if allDrives[index].isSelectedForMount {
                    allDrives[index].isSelectedForMount = false
                    mountSelection.remove(drive.identifier)
                }
            } else {
                unmountSelection.remove(drive.identifier)
            }
        }
    }
    
    func selectAllForMount() {
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        for index in allDrives.indices {
            if !allDrives[index].isMounted {
                allDrives[index].isSelectedForMount = true
                allDrives[index].isSelectedForUnmount = false
                mountSelection.insert(allDrives[index].identifier)
            } else {
                allDrives[index].isSelectedForMount = false
                allDrives[index].isSelectedForUnmount = false
            }
        }
    }
    
    func selectAllForUnmount() {
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        for index in allDrives.indices {
            if allDrives[index].isMounted {
                allDrives[index].isSelectedForUnmount = true
                allDrives[index].isSelectedForMount = false
                unmountSelection.insert(allDrives[index].identifier)
            } else {
                allDrives[index].isSelectedForMount = false
                allDrives[index].isSelectedForUnmount = false
            }
        }
    }
    
    func clearAllSelections() {
        mountSelection.removeAll()
        unmountSelection.removeAll()
        
        for index in allDrives.indices {
            allDrives[index].isSelectedForMount = false
            allDrives[index].isSelectedForUnmount = false
        }
    }
    
    func mountSelectedDrives() -> (success: Bool, message: String) {
        let drivesToMount = allDrives.filter { $0.isSelectedForMount }
        let result = shellHelper.mountSelectedDrives(drives: drivesToMount)
        if result.success {
            refreshDrives()
            clearAllSelections()
        }
        return (result.success, result.message)
    }
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount }
        let result = shellHelper.unmountSelectedDrives(drives: drivesToUnmount)
        if result.success {
            refreshDrives()
            clearAllSelections()
        }
        return (result.success, result.message)
    }
    
    func mountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.mountAllExternalDrives()
        if result.success {
            refreshDrives()
        }
        return (result.success, result.message)
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.unmountAllExternalDrives()
        if result.success {
            refreshDrives()
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
    @EnvironmentObject var driveManager: DriveManager
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
                InfoRow(label: "Selected for Mount:", value: drive.isSelectedForMount ? "Yes" : "No")
                InfoRow(label: "Selected for Unmount:", value: drive.isSelectedForUnmount ? "Yes" : "No")
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
                    if drive.isMounted {
                        Button(action: {
                            driveManager.toggleUnmountSelection(for: drive)
                        }) {
                            HStack {
                                Image(systemName: drive.isSelectedForUnmount ? "eject.circle.fill" : "eject.circle")
                                Text(drive.isSelectedForUnmount ? "Deselect Unmount" : "Select to Unmount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(drive.isSelectedForUnmount ? .orange : .blue)
                    } else {
                        Button(action: {
                            driveManager.toggleMountSelection(for: drive)
                        }) {
                            HStack {
                                Image(systemName: drive.isSelectedForMount ? "play.circle.fill" : "play.circle")
                                Text(drive.isSelectedForMount ? "Deselect Mount" : "Select to Mount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(drive.isSelectedForMount ? .green : .blue)
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
        .frame(width: 500, height: 400)
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