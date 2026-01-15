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
    
    func debugDriveDetection() -> String {
        var debugInfo = "=== Drive Detection Debug ===\n\n"
        
        debugInfo += "1. Testing diskutil access:\n"
        let test1 = runCommand("diskutil list 2>&1 | head -5")
        debugInfo += "   Success: \(test1.success)\n"
        debugInfo += "   Error: \(test1.error.isEmpty ? "None" : test1.error)\n"
        debugInfo += "   Output: \(test1.output.isEmpty ? "EMPTY" : test1.output)\n\n"
        
        debugInfo += "2. Testing mount command:\n"
        let test2 = runCommand("mount | grep /Volumes/ | head -5")
        debugInfo += "   Output: \(test2.output.isEmpty ? "No mounted volumes" : test2.output)\n\n"
        
        debugInfo += "3. Testing /Volumes directory:\n"
        let test3 = runCommand("ls /Volumes/")
        debugInfo += "   Output: \(test3.output.isEmpty ? "Empty" : test3.output)\n\n"
        
        return debugInfo
    }
    
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Method 1: Get mounted drives from mount command
        let mountResult = runCommand("mount")
        let mountLines = mountResult.output.components(separatedBy: "\n")
        
        var processedDisks: Set<String> = []
        
        for line in mountLines {
            if line.contains("/dev/disk") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                if components.count >= 3 {
                    let diskPath = components[0]
                    let mountPoint = components[2]
                    
                    // Extract base disk (e.g., disk4 from disk4s4s1)
                    if let diskRange = diskPath.range(of: "disk[0-9]+", options: .regularExpression) {
                        let diskId = String(diskPath[diskRange])
                        
                        if !processedDisks.contains(diskId) {
                            let isInternal = !mountPoint.contains("/Volumes/") || mountPoint == "/"
                            
                            // Get size info
                            let size = getDiskSizeFromDF(diskId: diskId, mountPoint: mountPoint)
                            
                            // Determine name
                            let name: String
                            if mountPoint == "/" {
                                name = "System Disk"
                            } else if mountPoint.contains("/Volumes/") {
                                let volumeName = (mountPoint as NSString).lastPathComponent
                                name = volumeName.isEmpty ? "Disk \(diskId)" : volumeName
                            } else {
                                name = "Disk \(diskId)"
                            }
                            
                            // Check if USB/External
                            let isUSB = checkIfUSBDrive(mountPoint: mountPoint, name: name)
                            let driveType = isUSB ? "USB/External" : (isInternal ? "Internal" : "External")
                            
                            // Get partitions
                            let partitions = getPartitionsForDisk(diskId: diskId)
                            
                            drives.append(DriveInfo(
                                name: name,
                                identifier: diskId,
                                size: size,
                                type: driveType,
                                mountPoint: mountPoint,
                                isInternal: isInternal,
                                isEFI: false,
                                partitions: partitions,
                                isMounted: true,
                                isSelectedForUnmount: false
                            ))
                            
                            processedDisks.insert(diskId)
                        }
                    }
                }
            }
        }
        
        // Method 2: Check /Volumes for unmounted volumes
        let volumesResult = runCommand("ls -d /Volumes/* 2>/dev/null")
        let volumePaths = volumesResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for volumePath in volumePaths {
            let volumeName = (volumePath as NSString).lastPathComponent
            
            // Skip if already in our list
            if !drives.contains(where: { $0.name == volumeName }) {
                // Try to find disk info
                let dfResult = runCommand("df \"\(volumePath)\" 2>/dev/null | tail -1")
                if dfResult.success {
                    let parts = dfResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if !parts.isEmpty, let diskRange = parts[0].range(of: "disk[0-9]+", options: .regularExpression) {
                        let diskId = String(parts[0][diskRange])
                        
                        if !processedDisks.contains(diskId) {
                            let size = parts.count >= 2 ? parts[1] : "Unknown"
                            
                            drives.append(DriveInfo(
                                name: volumeName,
                                identifier: diskId,
                                size: size,
                                type: "External",
                                mountPoint: volumePath,
                                isInternal: false,
                                isEFI: false,
                                partitions: [],
                                isMounted: true,
                                isSelectedForUnmount: false
                            ))
                            
                            processedDisks.insert(diskId)
                        }
                    }
                }
            }
        }
        
        // Sort: external first, then internal
        drives.sort { 
            if $0.isInternal != $1.isInternal {
                return !$0.isInternal && $1.isInternal
            }
            return $0.name < $1.name
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDiskSizeFromDF(diskId: String, mountPoint: String) -> String {
        let dfResult = runCommand("df -h \"\(mountPoint)\" 2>/dev/null | tail -1")
        if dfResult.success {
            let parts = dfResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 2 {
                return parts[1]
            }
        }
        return "Unknown"
    }
    
    private func checkIfUSBDrive(mountPoint: String, name: String) -> Bool {
        // USB drives are typically mounted in /Volumes and not system volumes
        if mountPoint.contains("/Volumes/") {
            let systemVolumes = ["Preboot", "VM", "Update", "Data", "EFI", "iOS_", "com_apple"]
            return !systemVolumes.contains(where: { mountPoint.contains($0) || name.contains($0) })
        }
        return false
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
            
            // Get size
            let size = getPartitionSize(partitionId: partitionId)
            
            partitions.append(PartitionInfo(
                name: partitionId,
                identifier: partitionId,
                size: size,
                type: isEFI ? "EFI" : "Unknown",
                mountPoint: mountPoint,
                isEFI: isEFI,
                isMounted: isMounted
            ))
        }
        
        return partitions
    }
    
    private func getPartitionSize(partitionId: String) -> String {
        // Try to get size from mount point if mounted
        let mountResult = runCommand("mount | grep \"/dev/\(partitionId) \" | awk '{print $3}'")
        if !mountResult.output.isEmpty {
            let dfResult = runCommand("df -h \"\(mountResult.output)\" 2>/dev/null | tail -1")
            if dfResult.success {
                let parts = dfResult.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    return parts[1]
                }
            }
        }
        return "Unknown"
    }
    
    func mountDrive(_ diskId: String) -> (success: Bool, message: String, mountPoint: String) {
        print("⏫ Attempting to mount \(diskId)")
        
        // Check if already mounted
        let mountCheck = runCommand("mount | grep \"/dev/\(diskId)\" | head -1")
        if !mountCheck.output.isEmpty {
            let parts = mountCheck.output.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 3 {
                return (true, "Drive already mounted at \(parts[2])", parts[2])
            }
        }
        
        // Try to mount
        let mountResult = runCommand("diskutil mount /dev/\(diskId)")
        
        if mountResult.success {
            // Get new mount point
            let newMountCheck = runCommand("mount | grep \"/dev/\(diskId)\" | head -1")
            if !newMountCheck.output.isEmpty {
                let parts = newMountCheck.output.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 3 {
                    return (true, "Successfully mounted at \(parts[2])", parts[2])
                }
            }
            return (false, "Mount succeeded but mount point not found", "")
        } else {
            return (false, "Failed to mount: \(mountResult.error)", "")
        }
    }
    
    func unmountDrive(_ diskId: String) -> (success: Bool, message: String) {
        print("⏬ Attempting to unmount \(diskId)")
        
        // Check if mounted
        let mountCheck = runCommand("mount | grep \"/dev/\(diskId)\" | head -1")
        if mountCheck.output.isEmpty {
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
    
    func unmountAllSelected(drives: [DriveInfo]) -> (success: Bool, message: String) {
        print("⏬ Unmounting selected drives")
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for drive in drives where drive.isSelectedForUnmount && drive.isMounted {
            let result = unmountDrive(drive.identifier)
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): \(result.message)")
            } else {
                failedCount += 1
                messages.append("❌ \(drive.name): \(result.message)")
            }
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully unmounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "Failed to unmount all drives\n\n\(message)")
        } else {
            return (true, "No drives selected for unmount")
        }
    }
    
    func unmountAllExternalDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all external drives")
        
        // Get all mounted external drives
        let mountResult = runCommand("""
        mount | grep '/Volumes/' | grep -v '/System/Volumes/' | awk '{print $1}' | sed 's|/dev/||' | cut -d's' -f1 | sort -u
        """)
        
        let externalDisks = mountResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var successCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        for diskId in externalDisks {
            let result = unmountDrive(diskId)
            if result.success {
                successCount += 1
                messages.append("✅ Disk \(diskId): Unmounted")
            } else {
                failedCount += 1
                messages.append("❌ Disk \(diskId): \(result.message)")
            }
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "Successfully unmounted \(successCount) external drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "Unmounted \(successCount) drive(s), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && externalDisks.isEmpty {
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
        // Simple FDA check
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
    @Published var selectedForUnmount: Set<String> = []
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            DispatchQueue.main.async {
                // Preserve selection state
                var updatedDrives: [DriveInfo] = []
                for var drive in drives {
                    drive.isSelectedForUnmount = self.selectedForUnmount.contains(drive.identifier)
                    updatedDrives.append(drive)
                }
                self.allDrives = updatedDrives
                self.isLoading = false
            }
        }
    }
    
    func toggleUnmountSelection(for drive: DriveInfo) {
        if let index = allDrives.firstIndex(where: { $0.id == drive.id }) {
            allDrives[index].isSelectedForUnmount.toggle()
            
            if allDrives[index].isSelectedForUnmount {
                selectedForUnmount.insert(drive.identifier)
            } else {
                selectedForUnmount.remove(drive.identifier)
            }
        }
    }
    
    func selectAllForUnmount() {
        selectedForUnmount.removeAll()
        for index in allDrives.indices {
            allDrives[index].isSelectedForUnmount = true
            selectedForUnmount.insert(allDrives[index].identifier)
        }
    }
    
    func deselectAllForUnmount() {
        selectedForUnmount.removeAll()
        for index in allDrives.indices {
            allDrives[index].isSelectedForUnmount = false
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
    
    func unmountSelectedDrives() -> (success: Bool, message: String) {
        let drivesToUnmount = allDrives.filter { $0.isSelectedForUnmount }
        let result = shellHelper.unmountAllSelected(drives: drivesToUnmount)
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
                Text("Drive Management Tool")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Drive Count
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let selectedCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                    if selectedCount > 0 {
                        Text("\(selectedCount) Selected")
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
                
                // Selection Controls
                HStack(spacing: 8) {
                    Button("Select All") {
                        driveManager.selectAllForUnmount()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Clear All") {
                        driveManager.deselectAllForUnmount()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    unmountSelected()
                }) {
                    HStack {
                        Image(systemName: "eject")
                        Text("Unmount Selected")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.allDrives.filter { $0.isSelectedForUnmount }.isEmpty)
                
                Button(action: {
                    unmountAllExternal()
                }) {
                    HStack {
                        Image(systemName: "eject.fill")
                        Text("Unmount All External")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.allDrives.filter { !$0.isInternal && $0.isMounted }.isEmpty)
                
                Spacer()
                
                Button("Debug Info") {
                    showDebugInfoAlert()
                }
                .buttonStyle(.bordered)
                .font(.caption)
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
                
                let selectedCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                if selectedCount > 0 {
                    Text("\(selectedCount) selected")
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
        HStack {
            // Selection Checkbox
            Button(action: {
                driveManager.toggleUnmountSelection(for: drive)
            }) {
                Image(systemName: drive.isSelectedForUnmount ? "checkmark.square.fill" : "square")
                    .foregroundColor(drive.isSelectedForUnmount ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            
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
                title: "Select All",
                icon: "checkmark.square",
                color: .orange,
                action: {
                    driveManager.selectAllForUnmount()
                }
            )
            
            ActionButton(
                title: "Clear Selection",
                icon: "square",
                color: .gray,
                action: {
                    driveManager.deselectAllForUnmount()
                }
            )
            
            ActionButton(
                title: "Unmount External",
                icon: "eject",
                color: .red,
                action: unmountAllExternal
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
                        
                        Text("\(driveManager.allDrives.count) drives total")
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
    
    private func unmountSelected() {
        let result = driveManager.unmountSelectedDrives()
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
                    // Selection Toggle
                    Button(action: {
                        driveManager.toggleUnmountSelection(for: drive)
                    }) {
                        HStack {
                            Image(systemName: drive.isSelectedForUnmount ? "checkmark.square.fill" : "square")
                            Text(drive.isSelectedForUnmount ? "Deselect" : "Select")
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(drive.isSelectedForUnmount ? .orange : .blue)
                    
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
                .frame(width: 120, alignment: .leading)
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