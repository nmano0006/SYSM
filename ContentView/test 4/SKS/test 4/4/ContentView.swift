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
        
        // Get mounted volumes from df -h
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        // Parse df output for mounted drives
        for line in dfLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.starts(with: "Filesystem") {
                continue
            }
            
            // Simple split - last component is mount point
            let components = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 6 else { continue }
            
            let devicePath = components[0]
            let size = components[1]
            let mountPoint = components[5...].joined(separator: " ")
            
            // Only process /dev/disk devices
            if devicePath.hasPrefix("/dev/disk") {
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
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
        
        // Now look for ALL partitions including unmounted ones
        print("🔍 Looking for all partitions...")
        
        // Get detailed disk list
        let listResult = runCommand("diskutil list")
        let lines = listResult.output.components(separatedBy: "\n")
        
        // First, look for EFI partitions specifically
        for line in lines {
            if line.contains("EFI") || line.contains("Microsoft Basic Data") || line.contains("Windows Recovery") {
                // Try to find partition identifiers in this line
                let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for word in words {
                    if word.hasPrefix("disk") && word.contains("s") && word.count >= 7 {
                        let partitionId = word
                        
                        // Skip if already in the list
                        if !drives.contains(where: { $0.identifier == partitionId }) {
                            
                            // Get detailed info
                            let drive = getDriveInfo(deviceId: partitionId)
                            
                            // Check if it's mounted
                            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                            let isActuallyMounted = !mountCheck.output.isEmpty
                            
                            // Check if it's an EFI partition
                            let isEFIPartition = line.contains("EFI") || 
                                                drive.type == "EFI" || 
                                                drive.name.contains("EFI") ||
                                                drive.name.contains("Microsoft Basic Data")
                            
                            if isEFIPartition {
                                let efiDrive = DriveInfo(
                                    name: "EFI System Partition (\(partitionId))",
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
                                print("🔐 Found EFI partition: \(partitionId) - Mounted: \(isActuallyMounted)")
                            }
                        }
                    }
                }
            }
        }
        
        // Look for all other partitions
        for line in lines {
            if line.contains("disk") && line.contains("s") && !line.contains("IDENTIFIER") {
                let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                for word in words {
                    if word.hasPrefix("disk") && word.contains("s") && word.count >= 7 {
                        let partitionId = word
                        
                        // Skip if already in the list
                        if !drives.contains(where: { $0.identifier == partitionId }) {
                            
                            // Check if it's mounted
                            let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                            let isActuallyMounted = !mountCheck.output.isEmpty
                            
                            if !isActuallyMounted {
                                let drive = getDriveInfo(deviceId: partitionId)
                                
                                // Skip empty or system partitions
                                if drive.size != "0 B" && 
                                   drive.size != "0B" && 
                                   drive.size != "Unknown" &&
                                   !drive.name.contains("Recovery") && 
                                   !drive.name.contains("VM") && 
                                   !drive.name.contains("Preboot") && 
                                   !drive.name.contains("Update") &&
                                   !drive.name.contains("Apple_APFS_ISC") {
                                    
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
                                    print("📦 Found unmounted: \(drive.name) (\(partitionId)) Size: \(drive.size)")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Manual EFI partition check - look for typical EFI partitions
        print("🔍 Manual EFI partition check...")
        let commonEFIPartitions = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1", 
                                  "disk0s2", "disk1s2", "disk2s2", "disk3s2", "disk4s2", "disk5s2"]
        
        for partitionId in commonEFIPartitions {
            if !drives.contains(where: { $0.identifier == partitionId }) {
                // Check if this partition exists
                let checkResult = runCommand("diskutil info /dev/\(partitionId) 2>/dev/null | head -5")
                if checkResult.success && !checkResult.output.contains("No such file or directory") {
                    let drive = getDriveInfo(deviceId: partitionId)
                    
                    // Check if it looks like an EFI partition
                    if drive.type == "EFI" || drive.name.contains("EFI") || drive.size == "209.7 MB" || drive.size == "210 MB" {
                        let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                        let isActuallyMounted = !mountCheck.output.isEmpty
                        
                        let efiDrive = DriveInfo(
                            name: "EFI System Partition (\(partitionId))",
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
                        print("🔐 Found potential EFI: \(partitionId)")
                    }
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
        
        // Parse diskutil info output
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
    
    // Mount single drive
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        var mountCommand = "diskutil mount /dev/\(drive.identifier)"
        var needsSudo = false
        
        // EFI and NTFS partitions need sudo
        if drive.isEFI || drive.type == "NTFS" {
            needsSudo = true
        }
        
        let result = runCommand(mountCommand, needsSudo: needsSudo)
        
        if result.success {
            // Check if actually mounted
            let verify = getDriveInfo(deviceId: drive.identifier)
            if verify.isMounted {
                return (true, "✅ \(drive.name) mounted successfully at \(verify.mountPoint)")
            } else {
                return (false, "⚠️ Mount command succeeded but drive not showing as mounted")
            }
        } else {
            return (false, "❌ Failed to mount \(drive.name): \(result.error)")
        }
    }
    
    // Unmount single drive
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        // Don't unmount system volumes
        if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
            return (false, "⚠️ Cannot unmount system volume: \(drive.name)")
        }
        
        let unmountCommand = "diskutil unmount /dev/\(drive.identifier)"
        let result = runCommand(unmountCommand)
        
        if result.success {
            return (true, "✅ \(drive.name) unmounted successfully")
        } else {
            return (false, "❌ Failed to unmount \(drive.name): \(result.error)")
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
        
        // Allow EFI partitions
        if drive.isEFI {
            return true
        }
        
        // Skip system partitions
        if drive.name.contains("Recovery") || 
           drive.name.contains("VM") || 
           drive.name.contains("Preboot") || 
           drive.name.contains("Update") ||
           drive.name.contains("Apple_APFS_ISC") {
            return false
        }
        
        return true
    }
    
    // Special function to find EFI partitions
    func findEFIPartitions() -> String {
        var messages: [String] = []
        messages.append("🔍 Searching for EFI partitions...")
        
        // Check diskutil list for EFI
        let listResult = runCommand("diskutil list | grep -A5 -B5 -i efi")
        if !listResult.output.isEmpty {
            messages.append("Found in diskutil list:")
            messages.append(listResult.output)
        } else {
            messages.append("No EFI partitions found in diskutil list")
        }
        
        // Check all disks for EFI-like partitions
        messages.append("\n🔍 Checking all disks for potential EFI partitions:")
        
        for disk in 0...10 {
            for slice in 1...4 {
                let partition = "disk\(disk)s\(slice)"
                let check = runCommand("diskutil info /dev/\(partition) 2>/dev/null | grep -i 'type\\|size\\|name'")
                if check.success && !check.output.isEmpty {
                    let lines = check.output.components(separatedBy: "\n")
                    var info: [String] = []
                    for line in lines {
                        if line.contains("Type") || line.contains("Size") || line.contains("Name") {
                            info.append(line.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    if !info.isEmpty {
                        messages.append("\(partition): \(info.joined(separator: ", "))")
                    }
                }
            }
        }
        
        return messages.joined(separator: "\n")
    }
    
    // Manual mount of specific partition
    func manualMount(partitionId: String) -> (success: Bool, message: String) {
        print("🔧 Manual mount of \(partitionId)")
        
        let result = runCommand("diskutil mount /dev/\(partitionId)", needsSudo: true)
        
        if result.success {
            return (true, "✅ Partition \(partitionId) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(partitionId): \(result.error)")
        }
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
        messages.append("EFI partitions: \(drives.filter { $0.isEFI }.count)")
        
        messages.append("\n📊 Detailed Drive List:")
        for drive in drives {
            let status = drive.isMounted ? "📌 MOUNTED at \(drive.mountPoint)" : "📦 UNMOUNTED"
            let efiMark = drive.isEFI ? "🔐 " : ""
            messages.append("• \(efiMark)\(drive.name) (\(drive.identifier)) - \(drive.size) - \(drive.type) - \(status)")
        }
        
        // EFI search
        messages.append("\n" + findEFIPartitions())
        
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
                print("🔄 Refreshed drives: \(self.allDrives.count) total")
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
    
    func manualMountEFI(partitionId: String) -> (success: Bool, message: String) {
        let result = shellHelper.manualMount(partitionId: partitionId)
        
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
    @State private var manualEFIInput = ""
    @State private var showManualEFIDialog = false
    
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
                    
                    DebugView
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
        .alert("EFI Search Results", isPresented: $driveManager.showEFISearch) {
            Button("OK") { }
        } message: {
            ScrollView {
                Text(driveManager.efiSearchResult)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
        }
        .alert("Manual EFI Mount", isPresented: $showManualEFIDialog) {
            TextField("Enter partition ID (e.g., disk0s1)", text: $manualEFIInput)
            Button("Cancel") { }
            Button("Mount") {
                mountManualEFI()
            }
        } message: {
            Text("Enter the partition identifier you want to mount as EFI")
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
                Text("Mount & Unmount Drives")
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
                
                // EFI Search Button
                Button(action: {
                    driveManager.searchForEFI()
                }) {
                    HStack {
                        Image(systemName: "memorychip")
                        Text("Find EFI")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.purple)
                
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
                    
                    Button(action: {
                        showManualEFIDialog = true
                    }) {
                        HStack {
                            Image(systemName: "wrench")
                            Text("Manual EFI")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.purple)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // EFI Notice
                if driveManager.allDrives.contains(where: { $0.isEFI }) {
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundColor(.purple)
                        Text("EFI partitions require administrator password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("How to find EFI?") {
                            driveManager.searchForEFI()
                        }
                        .font(.caption2)
                    }
                    .padding(.horizontal)
                }
                
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
            
            Text("Press Refresh or check Debug tab")
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
                if drive.isEFI {
                    Image(systemName: "memorychip")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 30)
                } else {
                    Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                        .font(.title2)
                        .foregroundColor(drive.isInternal ? .blue : .orange)
                        .frame(width: 30)
                }
                
                // Drive Info
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
                            .foregroundColor(drive.isEFI ? .purple : (drive.type == "NTFS" ? .red : (drive.isInternal ? .blue : .orange)))
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(drive.isMounted ? .orange : .green)
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
    
    private var DebugView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Debug & Tools")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button("Show Detailed Debug Info") {
                        showDebugView()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Search for EFI Partitions") {
                        driveManager.searchForEFI()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    
                    Button("Manual EFI Mount...") {
                        showManualEFIDialog = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                if !driveManager.allDrives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Drives (\(driveManager.allDrives.count)):")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(driveManager.allDrives) { drive in
                            HStack {
                                if drive.isEFI {
                                    Image(systemName: "memorychip")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: drive.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                                        .foregroundColor(drive.isInternal ? .blue : .orange)
                                }
                                
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
    
    private func canToggle(drive: DriveInfo) -> Bool {
        let shellHelper = ShellHelper.shared
        if drive.isMounted {
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            return shellHelper.canMountDrive(drive)
        }
    }
    
    // MARK: - Actions
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountAllExternal() {
        showAlert(title: "Info", message: "Use individual mount buttons for each drive")
    }
    
    private func unmountAllExternal() {
        showAlert(title: "Info", message: "Use individual unmount buttons for each drive")
    }
    
    private func mountManualEFI() {
        guard !manualEFIInput.isEmpty else { return }
        
        let result = driveManager.manualMountEFI(partitionId: manualEFIInput)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
        manualEFIInput = ""
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