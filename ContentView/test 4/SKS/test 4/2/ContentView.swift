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
        
        guard !command.isEmpty else {
            print("❌ Empty command provided")
            return ("", "Empty command", false)
        }
        
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if needsSudo {
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = """
            do shell script "\(escapedCommand)" \
            with administrator privileges \
            with prompt "SystemMaintenance needs administrator access" \
            without altering line endings
            """
            
            let appleScriptCommand = "osascript -e '\(appleScript)'"
            print("🛡️ Running with sudo via AppleScript")
            task.arguments = ["-c", appleScriptCommand]
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
        
        if !success {
            print("❌ Command failed with exit code: \(task.terminationStatus)")
        }
        
        print("📝 Command output: \(output)")
        if !errorOutput.isEmpty {
            print("⚠️ Command error: \(errorOutput)")
        }
        print("✅ Command success: \(success)")
        
        return (output, errorOutput, success)
    }
    
    // Get only user-accessible drives
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // Get mounted volumes from df -h
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        // Parse df output for mounted drives
        for line in dfLines {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Skip header and empty lines
            if components.count < 6 || components[0] == "Filesystem" {
                continue
            }
            
            let devicePath = components[0]
            let mountPoint = components[5]
            let size = components[1]
            let used = components[2]
            let available = components[3]
            let capacity = components[4]
            
            // Only process /dev/disk devices
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                // Skip if it's the boot disk (mounted on /)
                if mountPoint == "/" {
                    print("⚠️ Skipping boot disk: \(deviceId)")
                    continue
                }
                
                // Skip System/Volumes mounts (these are system partitions)
                if mountPoint.contains("/System/Volumes/") {
                    print("⚠️ Skipping system volume: \(deviceId) at \(mountPoint)")
                    continue
                }
                
                // Skip /Library/Developer mounts
                if mountPoint.contains("/Library/Developer") {
                    print("⚠️ Skipping developer volume: \(deviceId) at \(mountPoint)")
                    continue
                }
                
                // Skip /private/var mounts
                if mountPoint.contains("/private/var") {
                    print("⚠️ Skipping private volume: \(deviceId) at \(mountPoint)")
                    continue
                }
                
                // Get drive info
                let drive = getDriveInfo(deviceId: deviceId)
                
                let volumeName = (mountPoint as NSString).lastPathComponent
                var finalName = drive.name
                
                // Use volume name from mount point if available
                if volumeName != "." && volumeName != "/" && !volumeName.isEmpty {
                    if finalName == "Disk \(deviceId)" || finalName.isEmpty || finalName == deviceId {
                        finalName = volumeName
                    }
                }
                
                let updatedDrive = DriveInfo(
                    name: finalName,
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
                
                drives.append(updatedDrive)
                print("📌 Found mounted: \(updatedDrive.name) (\(deviceId)) at \(mountPoint)")
            }
        }
        
        // Get ALL partitions from diskutil list for unmounted drives
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        for line in lines {
            // Look for partition lines
            if line.contains("disk") && line.contains("s") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                // Look for partition identifier pattern (diskXsY)
                for component in components {
                    if component.hasPrefix("disk") && component.contains("s") && component.count >= 7 {
                        let partitionId = component
                        
                        // Skip if already in mounted list
                        if !drives.contains(where: { $0.identifier == partitionId }) {
                            
                            // Check if it's actually mounted
                            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                            let isActuallyMounted = !mountCheck.output.isEmpty
                            
                            if !isActuallyMounted {
                                // Get drive info
                                let drive = getDriveInfo(deviceId: partitionId)
                                
                                // Skip system partitions
                                if drive.name.contains("Recovery") || 
                                   drive.name.contains("VM") || 
                                   drive.name.contains("Preboot") || 
                                   drive.name.contains("Update") ||
                                   drive.name.contains("Apple_APFS_ISC") ||
                                   drive.size == "0 B" ||
                                   drive.size == "0B" ||
                                   drive.size == "Unknown" {
                                    continue
                                }
                                
                                let unmountedDrive = DriveInfo(
                                    name: drive.name,
                                    identifier: partitionId,
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
                                
                                drives.append(unmountedDrive)
                                print("📌 Found unmounted: \(drive.name) (\(partitionId)) Size: \(drive.size)")
                            }
                        }
                    }
                }
            }
        }
        
        // Sort: mounted first, then unmounted, then by identifier
        drives.sort {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        print("📋 Getting info for device: \(deviceId)")
        
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null || echo 'Not Found'")
        
        var name = "Disk \(deviceId)"
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = true
        var isMounted = false
        var isEFI = false
        
        // If command failed, return basic info
        if infoResult.output == "Not Found" {
            return DriveInfo(
                name: name,
                identifier: deviceId,
                size: "Unknown",
                type: "Unknown",
                mountPoint: "",
                isInternal: true,
                isEFI: false,
                partitions: [],
                isMounted: false,
                isSelectedForMount: false,
                isSelectedForUnmount: false
            )
        }
        
        // Parse diskutil info output
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            // Parse key-value pairs
            if trimmedLine.contains(":") {
                let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    switch key {
                    case "Volume Name":
                        if !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                        
                    case "Device / Media Name":
                        if (name == "Disk \(deviceId)" || name.isEmpty) && !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                        
                    case "Volume Size", "Disk Size", "Total Size":
                        if !value.isEmpty && value != "(null)" && !value.contains("(zero)") {
                            size = value
                        }
                        
                    case "Mount Point":
                        mountPoint = value
                        isMounted = !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "Not mounted"
                        
                    case "Type (Bundle)":
                        if value.contains("EFI") || value.contains("msdos") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name.isEmpty {
                                name = "EFI System Partition"
                            }
                        } else if value.contains("ntfs") || value.contains("NTFS") {
                            type = "NTFS"
                        } else if value.contains("hfs") || value.contains("HFS") {
                            type = "HFS+"
                        } else if value.contains("apfs") || value.contains("APFS") {
                            type = "APFS"
                        } else if value.contains("fat") || value.contains("FAT") {
                            type = "FAT32"
                        }
                        
                    case "Protocol":
                        if !value.isEmpty && value != "(null)" {
                            type = value
                            if value.contains("USB") {
                                isInternal = false
                            }
                        }
                        
                    case "Internal":
                        isInternal = value.contains("Yes")
                        
                    case "Removable Media":
                        if value.contains("Yes") || value.contains("Removable") {
                            isInternal = false
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
        
        // If no type determined, guess based on name
        if type == "Unknown" {
            if name.contains("EFI") || deviceId.contains("EFI") {
                type = "EFI"
                isEFI = true
                name = "EFI System Partition"
            } else if name.contains("NTFS") {
                type = "NTFS"
            } else if name.contains("APFS") {
                type = "APFS"
            } else if name.contains("HFS") {
                type = "HFS+"
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
    
    // Mount single drive
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        let mountCommand = "diskutil mount /dev/\(drive.identifier)"
        let result = runCommand(mountCommand)
        
        if result.success {
            return (true, "✅ \(drive.name) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(drive.name): \(result.error)")
        }
    }
    
    // Unmount single drive
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        // Don't unmount boot volume
        if drive.mountPoint == "/" {
            return (false, "⚠️ Cannot unmount boot volume")
        }
        
        let unmountCommand = "diskutil unmount /dev/\(drive.identifier)"
        let result = runCommand(unmountCommand)
        
        if result.success {
            return (true, "✅ \(drive.name) unmounted successfully")
        } else {
            // Try force unmount
            let forceCommand = "diskutil unmount force /dev/\(drive.identifier)"
            let forceResult = runCommand(forceCommand)
            
            if forceResult.success {
                return (true, "✅ \(drive.name) force unmounted successfully")
            } else {
                return (false, "❌ Failed to unmount \(drive.name): \(result.error)")
            }
        }
    }
    
    // Mount all unmounted drives
    func mountAllDrives() -> (success: Bool, message: String) {
        print("⏫ Mounting all unmounted drives")
        
        let drives = getAllDrives()
        var messages: [String] = []
        var successCount = 0
        var failedCount = 0
        
        for drive in drives where !drive.isMounted && canMountDrive(drive) {
            let result = mountDrive(drive)
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): Mounted")
            } else {
                failedCount += 1
                messages.append("❌ \(drive.name): Failed")
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Mounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Mounted \(successCount), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "❌ Failed to mount any drives\n\n\(message)")
        } else {
            return (true, "ℹ️ No unmounted drives found")
        }
    }
    
    // Unmount all mounted drives (except boot and system)
    func unmountAllDrives() -> (success: Bool, message: String) {
        print("⏬ Unmounting all mounted drives")
        
        let drives = getAllDrives()
        var messages: [String] = []
        var successCount = 0
        var failedCount = 0
        
        for drive in drives where drive.isMounted && drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/") {
            let result = unmountDrive(drive)
            if result.success {
                successCount += 1
                messages.append("✅ \(drive.name): Unmounted")
            } else {
                failedCount += 1
                messages.append("❌ \(drive.name): Failed")
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let message = messages.joined(separator: "\n")
        
        if successCount > 0 && failedCount == 0 {
            return (true, "✅ Unmounted \(successCount) drive(s)\n\n\(message)")
        } else if successCount > 0 && failedCount > 0 {
            return (false, "⚠️ Unmounted \(successCount), failed \(failedCount)\n\n\(message)")
        } else if successCount == 0 && failedCount > 0 {
            return (false, "❌ Failed to unmount any drives\n\n\(message)")
        } else {
            return (true, "ℹ️ No mounted drives found")
        }
    }
    
    // Check if a drive can be mounted
    func canMountDrive(_ drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return false
        }
        
        if drive.size == "0 B" || drive.size == "0B" || drive.size == "Unknown" {
            return false
        }
        
        // Don't mount EFI partitions by default
        if drive.isEFI {
            return false
        }
        
        return true
    }
    
    func debugMountIssues() -> String {
        var messages: [String] = []
        
        messages.append("🔍 Debug Information:")
        messages.append("=====================")
        
        // Get all drives
        let drives = getAllDrives()
        
        messages.append("Total drives detected: \(drives.count)")
        messages.append("Mounted: \(drives.filter { $0.isMounted }.count)")
        messages.append("Unmounted: \(drives.filter { !$0.isMounted }.count)")
        
        messages.append("\n📊 Detailed Drive List:")
        for drive in drives {
            let status = drive.isMounted ? "📌 MOUNTED at \(drive.mountPoint)" : "📦 UNMOUNTED"
            messages.append("• \(drive.name) (\(drive.identifier)) - \(drive.size) - \(drive.type) - \(status)")
        }
        
        return messages.joined(separator: "\n")
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
    @Published var operationMessage = ""
    
    private init() {}
    
    func refreshDrives() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.shellHelper.getAllDrives()
            
            DispatchQueue.main.async {
                self.allDrives = drives
                self.isLoading = false
                print("🔄 Refreshed drives: \(self.allDrives.count) total")
            }
        }
    }
    
    // Simple one-click toggle
    func toggleMountUnmount(for drive: DriveInfo) -> (success: Bool, message: String) {
        if drive.isMounted {
            return unmountDrive(drive)
        } else {
            return mountDrive(drive)
        }
    }
    
    private func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountDrive(drive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    private func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.unmountDrive(drive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    // Batch operations
    func mountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.mountAllDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func unmountAllExternal() -> (success: Bool, message: String) {
        let result = shellHelper.unmountAllDrives()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshDrives()
        }
        
        return result
    }
    
    // Debug functions
    func debugMountIssues() -> String {
        return shellHelper.debugMountIssues()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @StateObject private var driveManager = DriveManager.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView
                
                TabView(selection: $selectedTab) {
                    DriveListView
                        .tabItem {
                            Label("Drives", systemImage: "externaldrive")
                        }
                        .tag(0)
                    
                    InfoView
                        .tabItem {
                            Label("Debug", systemImage: "info.circle")
                        }
                        .tag(1)
                }
            }
            
            if driveManager.isLoading {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { 
                if alertTitle == "Success" || alertTitle == "Error" {
                    driveManager.refreshDrives()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            driveManager.refreshDrives()
        }
    }
    
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drive Manager")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Mount & Unmount External Drives")
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
                
                // Debug Button
                Button("Debug") {
                    showDebugView()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    private var DriveListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Actions
                HStack(spacing: 12) {
                    Button(action: {
                        mountAllExternal()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Mount All")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: {
                        unmountAllExternal()
                    }) {
                        HStack {
                            Image(systemName: "eject.circle.fill")
                            Text("Unmount All")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drives List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    VStack(spacing: 8) {
                        ForEach(driveManager.allDrives) { drive in
                            DriveCardView(drive: drive)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Press Debug button to see detailed information")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func DriveCardView(drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Drive Icon
                Image(systemName: driveIcon(for: drive))
                    .font(.title2)
                    .foregroundColor(driveColor(for: drive))
                    .frame(width: 30)
                
                // Drive Name and Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
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
                            .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                    }
                }
                
                Spacer()
                
                // Status Badge
                if drive.isMounted {
                    VStack(alignment: .trailing) {
                        Text("Mounted")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        if !drive.mountPoint.isEmpty && drive.mountPoint != "/" {
                            Text(drive.mountPoint)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 150)
                        }
                    }
                } else {
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Mount/Unmount Button
                Button(action: {
                    toggleDrive(drive)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        Text(drive.isMounted ? "Unmount" : "Mount")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(drive.isMounted ? .orange : .green)
                .disabled(!canToggle(drive: drive))
                .help(drive.isMounted ? "Unmount this drive" : "Mount this drive")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func driveIcon(for drive: DriveInfo) -> String {
        if drive.isEFI {
            return "memorychip"
        } else if drive.isInternal {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
        }
    }
    
    private func driveColor(for drive: DriveInfo) -> Color {
        if drive.isEFI {
            return .purple
        } else if drive.isInternal {
            return .blue
        } else {
            return .orange
        }
    }
    
    private func canToggle(drive: DriveInfo) -> Bool {
        let shellHelper = ShellHelper.shared
        if drive.isMounted {
            // Don't unmount boot volume or system volumes
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            // Only mount drives that can be mounted
            return shellHelper.canMountDrive(drive)
        }
    }
    
    private var InfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Drive Information")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                Button("Show Debug Info") {
                    showDebugView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Drives (\(driveManager.allDrives.count) total):")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(driveManager.allDrives) { drive in
                            HStack {
                                Image(systemName: driveIcon(for: drive))
                                    .foregroundColor(driveColor(for: drive))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(drive.name)
                                        .font(.headline)
                                    
                                    Text("\(drive.identifier) • \(drive.size) • \(drive.type)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if !drive.mountPoint.isEmpty {
                                        Text("Mount: \(drive.mountPoint)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(drive.isMounted ? "✓" : "○")
                                    .foregroundColor(drive.isMounted ? .green : .gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
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
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
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
    
    private func showDebugView() {
        let debugInfo = driveManager.debugMountIssues()
        alertTitle = "Debug Information"
        alertMessage = debugInfo
        showAlert = true
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