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
    
    // Get all drives including EFI
    func getAllDrives() -> [DriveInfo] {
        print("🔍 Getting all drives...")
        
        var drives: [DriveInfo] = []
        
        // First get mounted drives from df -h
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.starts(with: "Filesystem") {
                continue
            }
            
            let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 6 else { continue }
            
            let devicePath = components[0]
            let size = components[1]
            let mountPoint = components[5...].joined(separator: " ")
            
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                let drive = getDriveInfo(deviceId: deviceId)
                let volumeName = (mountPoint as NSString).lastPathComponent
                var finalName = drive.name
                
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
                print("📌 Found mounted: \(updatedDrive.name) (\(deviceId))")
            }
        }
        
        // Now actively search for EFI partitions
        print("🔍 Actively searching for EFI partitions...")
        
        // Check diskutil list for EFI partitions
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        var currentDisk = ""
        
        for line in lines {
            // Find disk lines
            if line.contains("/dev/disk") {
                let components = line.components(separatedBy: " ")
                if let diskId = components.first(where: { $0.contains("disk") })?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = diskId
                }
            }
            
            // Look for EFI partitions
            if line.contains("EFI") || line.contains("Microsoft Basic Data") {
                let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                for word in words {
                    if word.hasPrefix("disk") && word.contains("s") && word.count >= 7 {
                        let partitionId = word
                        
                        // Skip if already in list
                        if !drives.contains(where: { $0.identifier == partitionId }) {
                            
                            let drive = getDriveInfo(deviceId: partitionId)
                            
                            // Check if it's an EFI partition
                            let isEFIPartition = line.contains("EFI") || 
                                                drive.type == "EFI" || 
                                                drive.name.contains("EFI") ||
                                                partitionId == "\(currentDisk)s1" // First partition is often EFI
                            
                            if isEFIPartition {
                                // Check if mounted
                                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                                let isActuallyMounted = !mountCheck.output.isEmpty
                                
                                let efiDrive = DriveInfo(
                                    name: "EFI (\(currentDisk))",
                                    identifier: partitionId,
                                    size: drive.size,
                                    type: "EFI",
                                    mountPoint: isActuallyMounted ? drive.mountPoint : "",
                                    isInternal: drive.isInternal,
                                    isEFI: true,
                                    partitions: drive.partitions,
                                    isMounted: isActuallyMounted,
                                    isSelectedForMount: false,
                                    isSelectedForUnmount: false
                                )
                                
                                drives.append(efiDrive)
                                print("🔐 Found EFI: \(partitionId) - Mounted: \(isActuallyMounted)")
                            }
                        }
                    }
                }
            }
        }
        
        // Manual check for common EFI partitions
        let commonEFIPartitions = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1", 
                                  "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1"]
        
        for partitionId in commonEFIPartitions {
            if !drives.contains(where: { $0.identifier == partitionId }) {
                let check = runCommand("diskutil info /dev/\(partitionId) 2>/dev/null | grep -i 'type.*efi\\|partition.*efi'")
                if check.success {
                    let drive = getDriveInfo(deviceId: partitionId)
                    let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                    let isActuallyMounted = !mountCheck.output.isEmpty
                    
                    let efiDrive = DriveInfo(
                        name: "EFI System Partition",
                        identifier: partitionId,
                        size: drive.size,
                        type: "EFI",
                        mountPoint: isActuallyMounted ? drive.mountPoint : "",
                        isInternal: drive.isInternal,
                        isEFI: true,
                        partitions: drive.partitions,
                        isMounted: isActuallyMounted,
                        isSelectedForMount: false,
                        isSelectedForUnmount: false
                    )
                    
                    drives.append(efiDrive)
                    print("🔐 Manual found EFI: \(partitionId)")
                }
            }
        }
        
        // Sort: EFI first, then mounted, then unmounted
        drives.sort {
            if $0.isEFI != $1.isEFI {
                return $0.isEFI && !$1.isEFI
            }
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        }
        
        print("✅ Total drives found: \(drives.count)")
        return drives
    }
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        let infoResult = runCommand("diskutil info /dev/\(deviceId) 2>/dev/null")
        
        var name = "Disk \(deviceId)"
        var size = "Unknown"
        var type = "Unknown"
        var mountPoint = ""
        var isInternal = true
        var isMounted = false
        var isEFI = false
        
        let lines = infoResult.output.components(separatedBy: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
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
                            name = "EFI System Partition"
                        } else if value.contains("ntfs") {
                            type = "NTFS"
                        } else if value.contains("hfs") {
                            type = "HFS+"
                        } else if value.contains("apfs") {
                            type = "APFS"
                        } else if value.contains("fat") {
                            type = "FAT32"
                        }
                    case "Protocol":
                        if value.contains("USB") {
                            isInternal = false
                        }
                    case "Internal":
                        isInternal = value.contains("Yes")
                    default:
                        break
                    }
                }
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
    
    // Mount drive (with special handling for EFI)
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        var mountCommand = "diskutil mount /dev/\(drive.identifier)"
        var needsSudo = false
        
        // EFI partitions need sudo and might need special handling
        if drive.isEFI {
            needsSudo = true
            // Try different mount methods for EFI
            let result = runCommand(mountCommand, needsSudo: true)
            
            if result.success {
                return (true, "✅ EFI partition mounted successfully")
            } else {
                // Try alternative method
                let altResult = runCommand("sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI 2>/dev/null", needsSudo: true)
                if altResult.success {
                    return (true, "✅ EFI mounted at /Volumes/EFI")
                } else {
                    return (false, "❌ Failed to mount EFI: Try: sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI")
                }
            }
        }
        
        // Regular mount for non-EFI
        let result = runCommand(mountCommand, needsSudo: needsSudo)
        
        if result.success {
            return (true, "✅ \(drive.name) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(drive.name)")
        }
    }
    
    // Unmount drive
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
            return (false, "⚠️ Cannot unmount system volume")
        }
        
        let unmountCommand = "diskutil unmount /dev/\(drive.identifier)"
        let result = runCommand(unmountCommand)
        
        if result.success {
            return (true, "✅ \(drive.name) unmounted successfully")
        } else {
            return (false, "❌ Failed to unmount \(drive.name)")
        }
    }
    
    // Special EFI mounting function
    func mountEFIPartition(_ partitionId: String) -> (success: Bool, message: String) {
        print("🔐 Mounting EFI partition: \(partitionId)")
        
        // First try standard diskutil mount
        let result1 = runCommand("diskutil mount /dev/\(partitionId)", needsSudo: true)
        
        if result1.success {
            return (true, "✅ EFI partition \(partitionId) mounted successfully")
        }
        
        // Try manual mount to /Volumes/EFI
        let result2 = runCommand("sudo mkdir -p /Volumes/EFI && sudo mount -t msdos /dev/\(partitionId) /Volumes/EFI", needsSudo: true)
        
        if result2.success {
            return (true, "✅ EFI mounted at /Volumes/EFI")
        }
        
        return (false, "❌ Failed to mount EFI partition \(partitionId)")
    }
    
    func findEFIPartitions() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Partition Search Results:")
        messages.append("=================================")
        
        // Get all disk info
        let listResult = runCommand("diskutil list")
        messages.append("Full disk list (simplified):")
        
        let lines = listResult.output.components(separatedBy: "\n")
        var foundEFIs: [(String, String)] = []
        
        for line in lines {
            if line.contains("EFI") || line.contains("Microsoft Basic Data") {
                let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for word in words {
                    if word.hasPrefix("disk") && word.contains("s") {
                        let partitionId = word
                        let drive = getDriveInfo(deviceId: partitionId)
                        
                        if line.contains("EFI") || drive.type == "EFI" {
                            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                            let status = mountCheck.output.isEmpty ? "UNMOUNTED" : "MOUNTED"
                            foundEFIs.append((partitionId, status))
                            messages.append("• \(partitionId): \(drive.size) - \(status)")
                        }
                    }
                }
            }
        }
        
        if foundEFIs.isEmpty {
            messages.append("No EFI partitions found")
        } else {
            messages.append("\n💡 Tip: Try mounting disk1s1, disk2s1, or disk3s1")
            messages.append("     These are your macOS drive EFI partitions")
        }
        
        return messages.joined(separator: "\n")
    }
    
    func debugMountIssues() -> String {
        var messages: [String] = []
        
        messages.append("🔍 Debug Information:")
        messages.append("=====================")
        
        let drives = getAllDrives()
        
        messages.append("Total drives: \(drives.count)")
        messages.append("Mounted: \(drives.filter { $0.isMounted }.count)")
        messages.append("Unmounted: \(drives.filter { !$0.isMounted }.count)")
        messages.append("EFI partitions: \(drives.filter { $0.isEFI }.count)")
        
        messages.append("\n📊 Drive List:")
        for drive in drives {
            let status = drive.isMounted ? "📌 MOUNTED" : "📦 UNMOUNTED"
            let efiMark = drive.isEFI ? "🔐 " : ""
            messages.append("• \(efiMark)\(drive.name) (\(drive.identifier)) - \(drive.size) - \(drive.type) - \(status)")
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
    @Published var showEFISearch = false
    @Published var efiSearchResult = ""
    
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
    
    func mountEFIPartition(_ partitionId: String) -> (success: Bool, message: String) {
        let result = shellHelper.mountEFIPartition(partitionId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func searchForEFI() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shellHelper.findEFIPartitions()
            
            DispatchQueue.main.async {
                self.efiSearchResult = result
                self.showEFISearch = true
            }
        }
    }
    
    func debugMountIssues() -> String {
        return shellHelper.debugMountIssues()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var selectedEFI = "disk1s1"
    
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
                    
                    EFIView
                        .tabItem {
                            Label("EFI Tools", systemImage: "memorychip")
                        }
                        .tag(1)
                    
                    DebugView
                        .tabItem {
                            Label("Debug", systemImage: "info.circle")
                        }
                        .tag(2)
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
        .alert("EFI Search Results", isPresented: $driveManager.showEFISearch) {
            Button("OK") { }
        } message: {
            ScrollView {
                Text(driveManager.efiSearchResult)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 400)
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
                Text("EFI & Drive Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    let efiCount = driveManager.allDrives.filter { $0.isEFI }.count
                    
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if efiCount > 0 {
                        Text("\(efiCount) EFI")
                            .font(.caption2)
                            .foregroundColor(.purple)
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
    
    private var DriveListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Mount Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        driveManager.searchForEFI()
                    }) {
                        HStack {
                            Image(systemName: "memorychip")
                            Text("Find EFI")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drive List
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
    
    private var EFIView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("EFI Partition Tools")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                // EFI Search Results
                VStack(spacing: 12) {
                    Text("Your EFI Partitions:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• disk0s1 - 104.9 MB - Windows drive EFI")
                        Text("• disk1s1 - 209.7 MB - macOS drive EFI (SSD 860)")
                        Text("• disk2s1 - 209.7 MB - macOS drive EFI")
                        Text("• disk3s1 - 209.7 MB - macOS drive EFI (pos 1/Pos 2)")
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("💡 First partition (s1) of each disk is usually the EFI partition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // EFI Mount Controls
                VStack(spacing: 12) {
                    Text("Mount EFI Partition:")
                        .font(.headline)
                    
                    Picker("Select EFI Partition:", selection: $selectedEFI) {
                        Text("disk1s1 (SSD 860)").tag("disk1s1")
                        Text("disk2s1").tag("disk2s1")
                        Text("disk3s1 (pos drive)").tag("disk3s1")
                        Text("disk0s1 (Windows)").tag("disk0s1")
                    }
                    .pickerStyle(.menu)
                    
                    Button(action: {
                        mountSelectedEFI()
                    }) {
                        HStack {
                            Image(systemName: "memorychip")
                            Text("Mount \(selectedEFI)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    
                    Text("Note: EFI mounting requires administrator password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Manual Command
                VStack(spacing: 12) {
                    Text("Manual EFI Commands:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terminal commands to mount EFI:")
                            .font(.caption)
                        
                        Text("sudo diskutil mount /dev/disk1s1")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text("sudo mount -t msdos /dev/disk1s1 /Volumes/EFI")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private var DebugView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Debug Information")
                    .font(.title)
                    .fontWeight(.bold)
                
                Button("Show Debug Info") {
                    showDebugView()
                }
                .buttonStyle(.borderedProminent)
                
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Drives:")
                            .font(.headline)
                        
                        ForEach(driveManager.allDrives.filter { $0.isEFI }) { drive in
                            EFIDebugCard(drive: drive)
                        }
                        
                        ForEach(driveManager.allDrives.filter { !$0.isEFI }) { drive in
                            DriveDebugCard(drive: drive)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func EFIDebugCard(drive: DriveInfo) -> some View {
        HStack {
            Image(systemName: "memorychip")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.name)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Text("\(drive.identifier) • \(drive.size)")
                    .font(.caption)
                
                if drive.isMounted {
                    Text(drive.mountPoint)
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Unmounted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                toggleDrive(drive)
            }) {
                Text(drive.isMounted ? "Unmount" : "Mount")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func DriveDebugCard(drive: DriveInfo) -> some View {
        HStack {
            Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                .foregroundColor(drive.type == "NTFS" ? .red : (drive.isInternal ? .blue : .orange))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.name)
                    .font(.headline)
                
                Text("\(drive.identifier) • \(drive.size) • \(drive.type)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if drive.isMounted {
                    Text(drive.mountPoint)
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
    }
    
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
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
                // Icon
                if drive.isEFI {
                    Image(systemName: "memorychip")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 30)
                } else {
                    Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                        .font(.title2)
                        .foregroundColor(drive.type == "NTFS" ? .red : (drive.isInternal ? .blue : .orange))
                        .frame(width: 30)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(drive.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if drive.isEFI {
                            Text("EFI")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    
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
                            .foregroundColor(drive.type == "NTFS" ? .red : .secondary)
                    }
                }
                
                Spacer()
                
                // Status
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
                
                // Action Button
                Button(action: {
                    toggleDrive(drive)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                        Text(drive.isMounted ? "Unmount" : "Mount")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(drive.isMounted ? .orange : (drive.isEFI ? .purple : .green))
                .disabled(!canToggle(drive: drive))
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(drive.isEFI ? Color.purple.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
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
    
    private func canToggle(drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            return true
        }
    }
    
    // MARK: - Actions
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountSelectedEFI() {
        let result = driveManager.mountEFIPartition(selectedEFI)
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