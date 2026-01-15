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
            // Try multiple methods for sudo
            print("🛡️ Attempting to run with sudo...")
            
            // Method 1: Try with osascript (AppleScript) - most reliable for GUI apps
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = """
            do shell script "\(escapedCommand)" \
            with administrator privileges \
            with prompt "Drive Manager needs to mount EFI partitions" \
            without altering line endings
            """
            
            let appleScriptCommand = "osascript -e '\(appleScript)'"
            print("🛡️ Method 1: Using AppleScript")
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
            print("📝 Error details: \(errorOutput)")
        }
        
        print("📝 Command output: \(output)")
        if !errorOutput.isEmpty {
            print("⚠️ Command error: \(errorOutput)")
        }
        print("✅ Command success: \(success)")
        
        return (output, errorOutput, success)
    }
    
    // New: Direct mount function that shows what commands to run
    func getManualEFIMountCommands(for partitionId: String) -> [String] {
        return [
            "sudo diskutil mount /dev/\(partitionId)",
            "sudo mount -t msdos /dev/\(partitionId) /Volumes/EFI",
            "sudo mount -t msdos -o noowners,rw /dev/\(partitionId) /Volumes/EFI"
        ]
    }
    
    // Test if sudo works
    func testSudoAccess() -> (success: Bool, message: String) {
        print("🔐 Testing sudo access...")
        
        let testCommand = "sudo -n true"
        let result = runCommand(testCommand)
        
        if result.success {
            return (true, "✅ Sudo password is cached (won't ask for password)")
        } else {
            // Try with AppleScript to see if it prompts
            let testWithPrompt = """
            osascript -e 'do shell script "whoami" with administrator privileges with prompt "Testing sudo access"'
            """
            let promptResult = runCommand(testWithPrompt)
            
            if promptResult.success {
                return (true, "✅ Sudo access available (will prompt for password)")
            } else {
                return (false, "❌ Cannot get sudo access. Error: \(promptResult.error)")
            }
        }
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
        
        // Get detailed info for all potential EFI partitions
        let allDisks = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1", 
                       "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                       "disk12s1", "disk13s1", "disk8s4s1", "disk8s2", "disk8s5", "disk8s6",
                       "disk9s4", "disk3s2", "disk3s3", "disk4s2", "disk5s2", "disk6s2",
                       "disk6s3", "disk6s4", "disk0s3"]
        
        for partitionId in allDisks {
            // Skip if already in list
            if !drives.contains(where: { $0.identifier == partitionId }) {
                let drive = getDriveInfo(deviceId: partitionId)
                
                // Check mount status
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isActuallyMounted = !mountCheck.output.isEmpty
                
                // Update mount point if actually mounted
                var updatedDrive = drive
                updatedDrive.isMounted = isActuallyMounted
                
                if isActuallyMounted {
                    // Extract mount point from mount command
                    let mountLine = mountCheck.output
                    if let range = mountLine.range(of: "on (.+?) \\(|$", options: .regularExpression) {
                        let mountInfo = mountLine[range]
                        if mountInfo.contains("on ") {
                            let parts = mountInfo.components(separatedBy: "on ")
                            if parts.count > 1 {
                                let mountPath = parts[1].components(separatedBy: " ").first ?? ""
                                updatedDrive.mountPoint = mountPath
                            }
                        }
                    }
                }
                
                drives.append(updatedDrive)
                
                if drive.isEFI {
                    print("🔐 Found EFI: \(partitionId) - Mounted: \(isActuallyMounted)")
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
                        if !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "NO NAME" {
                            name = value
                        }
                    case "Device / Media Name":
                        if (name == "Disk \(deviceId)" || name.isEmpty || name == "NO NAME") && !value.isEmpty && value != "Not applicable" && value != "(null)" {
                            name = value
                        }
                    case "Volume Size", "Disk Size", "Total Size":
                        if !value.isEmpty && value != "(null)" && !value.contains("(zero)") {
                            // Clean up the size format
                            if value.contains("(") {
                                let cleanSize = value.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? value
                                size = cleanSize
                            } else {
                                size = value
                            }
                        }
                    case "Mount Point":
                        mountPoint = value
                        isMounted = !value.isEmpty && value != "Not applicable" && value != "(null)" && value != "Not mounted"
                    case "Type (Bundle)":
                        if value.contains("EFI") || value.contains("msdos") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" || name == "Not applicable" {
                                name = "EFI System Partition"
                            }
                        } else if value.contains("ntfs") {
                            type = "NTFS"
                        } else if value.contains("hfs") {
                            type = "HFS+"
                        } else if value.contains("apfs") {
                            type = "APFS"
                        }
                    case "Partition Type":
                        if value.contains("EFI") {
                            isEFI = true
                            type = "EFI"
                            if name == "Disk \(deviceId)" || name == "NO NAME" || name == "Not applicable" {
                                name = "EFI System Partition"
                            }
                        }
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
    
    // Enhanced mount function with better error handling
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏫ Mounting drive: \(drive.name) (\(drive.identifier))")
        
        if drive.isMounted {
            return (true, "✅ \(drive.name) is already mounted")
        }
        
        // For EFI partitions, we need special handling
        if drive.isEFI {
            print("🔐 Mounting EFI partition...")
            
            // Test sudo access first
            let sudoTest = testSudoAccess()
            print("Sudo test: \(sudoTest.message)")
            
            if !sudoTest.success {
                return (false, "❌ Cannot get administrator access. Please try manual commands below.")
            }
            
            // Method 1: Try standard diskutil mount
            print("1️⃣ Trying: diskutil mount")
            let result1 = runCommand("diskutil mount /dev/\(drive.identifier)", needsSudo: true)
            
            if result1.success {
                // Verify mount
                let verify = runCommand("mount | grep '/dev/\(drive.identifier)'")
                if !verify.output.isEmpty {
                    return (true, "✅ \(drive.name) mounted successfully")
                }
            }
            
            // Method 2: Try manual mount
            print("2️⃣ Trying: manual mount to /Volumes/EFI")
            
            // Clean up first
            runCommand("sudo umount /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo rm -rf /Volumes/EFI 2>/dev/null", needsSudo: true)
            runCommand("sudo mkdir -p /Volumes/EFI 2>/dev/null", needsSudo: true)
            
            let result2 = runCommand("sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result2.success {
                return (true, "✅ \(drive.name) mounted at /Volumes/EFI")
            }
            
            // Method 3: Try with different options
            print("3️⃣ Trying: mount with rw,noowners options")
            let result3 = runCommand("sudo mount -t msdos -o rw,noowners /dev/\(drive.identifier) /Volumes/EFI 2>&1", needsSudo: true)
            
            if result3.success {
                return (true, "✅ \(drive.name) mounted with read-write access")
            }
            
            return (false, """
            ❌ Failed to mount EFI partition.
            
            💡 Try these manual Terminal commands:
            
            1. Open Terminal
            2. Run: sudo diskutil mount /dev/\(drive.identifier)
            
            If that doesn't work, try:
            sudo mount -t msdos /dev/\(drive.identifier) /Volumes/EFI
            
            You'll need to enter your password in Terminal.
            """)
        }
        
        // Regular mount for non-EFI
        let result = runCommand("diskutil mount /dev/\(drive.identifier)")
        
        if result.success {
            return (true, "✅ \(drive.name) mounted successfully")
        } else {
            return (false, "❌ Failed to mount \(drive.name): \(result.error)")
        }
    }
    
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        print("⏬ Unmounting drive: \(drive.name) (\(drive.identifier))")
        
        if !drive.isMounted {
            return (true, "✅ \(drive.name) is already unmounted")
        }
        
        if drive.mountPoint == "/" || drive.mountPoint.contains("/System/Volumes/") {
            return (false, "⚠️ Cannot unmount system volume")
        }
        
        let result = runCommand("diskutil unmount /dev/\(drive.identifier)")
        
        if result.success {
            return (true, "✅ \(drive.name) unmounted successfully")
        } else {
            return (false, "❌ Failed to unmount \(drive.name): \(result.error)")
        }
    }
    
    func mountEFIPartition(_ partitionId: String) -> (success: Bool, message: String) {
        print("🔐 Mounting EFI partition: \(partitionId)")
        
        // Get drive info first
        let drive = getDriveInfo(deviceId: partitionId)
        
        if !drive.isEFI {
            return (false, "❌ \(partitionId) is not an EFI partition")
        }
        
        return mountDrive(drive)
    }
    
    func findEFIPartitions() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Partition Search Results:")
        messages.append("=================================")
        
        // Check all potential EFI partitions
        let potentialEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1",
                           "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                           "disk12s1", "disk13s1"]
        
        var foundEFIs: [(String, String, Bool, String)] = []
        
        for partitionId in potentialEFIs {
            let drive = getDriveInfo(deviceId: partitionId)
            if drive.isEFI {
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isMounted = !mountCheck.output.isEmpty
                foundEFIs.append((partitionId, drive.name, isMounted, drive.size))
            }
        }
        
        if foundEFIs.isEmpty {
            messages.append("No EFI partitions found")
        } else {
            messages.append("Found \(foundEFIs.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted, size) in foundEFIs {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id): \(name) - \(size) - \(status)")
            }
        }
        
        return messages.joined(separator: "\n")
    }
    
    func performEFICheck() -> String {
        var messages: [String] = []
        messages.append("🔍 EFI Health Check:")
        messages.append("====================")
        
        // Test sudo access
        messages.append("🔐 Testing Administrator Access:")
        let sudoTest = testSudoAccess()
        messages.append(sudoTest.message)
        
        // Check for EFI partitions
        messages.append("\n🔐 EFI Partition Scan:")
        
        let potentialEFIs = ["disk0s1", "disk1s1", "disk2s1", "disk3s1", "disk4s1", "disk5s1",
                           "disk6s1", "disk7s1", "disk8s1", "disk9s1", "disk10s1", "disk11s1",
                           "disk12s1", "disk13s1"]
        
        var efiFound: [(String, String, Bool, String)] = []
        
        for partitionId in potentialEFIs {
            let drive = getDriveInfo(deviceId: partitionId)
            if drive.isEFI {
                let mountCheck = runCommand("mount | grep '/dev/\(partitionId)'")
                let isMounted = !mountCheck.output.isEmpty
                efiFound.append((partitionId, drive.name, isMounted, drive.size))
            }
        }
        
        if efiFound.isEmpty {
            messages.append("❌ No EFI partitions found")
        } else {
            messages.append("✅ Found \(efiFound.count) EFI partitions:")
            messages.append("")
            
            for (id, name, isMounted, size) in efiFound {
                let status = isMounted ? "✅ MOUNTED" : "❌ UNMOUNTED"
                messages.append("• \(id): \(name) - \(size) - \(status)")
            }
        }
        
        // Recommendations
        messages.append("\n💡 Recommendations:")
        
        if !sudoTest.success {
            messages.append("1. ⚠️ Administrator access issue detected")
            messages.append("2. You may need to run commands manually in Terminal")
            messages.append("3. Try these commands for disk1s1:")
            messages.append("   • sudo diskutil mount /dev/disk1s1")
            messages.append("   • sudo mount -t msdos /dev/disk1s1 /Volumes/EFI")
        } else if efiFound.isEmpty {
            messages.append("1. No EFI partitions detected")
            messages.append("2. Check if diskutil is working")
        } else {
            let unmountedEFIs = efiFound.filter { !$0.2 }
            if !unmountedEFIs.isEmpty {
                messages.append("1. You have \(unmountedEFIs.count) unmounted EFI partitions")
                messages.append("2. Try mounting disk1s1 first")
                messages.append("3. You'll be prompted for your password")
            }
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
    var mountPoint: String
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
    @Published var showEFICheck = false
    @Published var efiCheckResult = ""
    @Published var showManualCommands = false
    @Published var manualCommands = ""
    
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
    
    func mountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
        let result = shellHelper.mountDrive(drive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDrives()
        }
        
        return result
    }
    
    func unmountDrive(_ drive: DriveInfo) -> (success: Bool, message: String) {
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
    
    func showManualEFICommands(for partitionId: String) {
        let commands = shellHelper.getManualEFIMountCommands(for: partitionId)
        manualCommands = commands.joined(separator: "\n\n")
        showManualCommands = true
    }
    
    func searchForEFI() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shellHelper.findEFIPartitions()
            
            DispatchQueue.main.async {
                self.efiSearchResult = result
                self.showEFISearch = true
                self.isLoading = false
            }
        }
    }
    
    func performEFICheck() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shellHelper.performEFICheck()
            
            DispatchQueue.main.async {
                self.efiCheckResult = result
                self.showEFICheck = true
                self.isLoading = false
            }
        }
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
    @State private var showManualInstructions = false
    
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
            if alertTitle == "Error" && alertMessage.contains("manual Terminal") {
                Button("Show Manual Commands") {
                    showManualInstructions = true
                }
            }
        } message: {
            Text(alertMessage)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .alert("EFI Check Results", isPresented: $driveManager.showEFICheck) {
            Button("OK") { }
            Button("Refresh Drives") {
                driveManager.refreshDrives()
            }
        } message: {
            ScrollView {
                Text(driveManager.efiCheckResult)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 400)
        }
        .alert("Manual EFI Commands", isPresented: $showManualInstructions) {
            Button("OK") { }
            Button("Copy to Clipboard") {
                copyToClipboard(alertMessage)
            }
        } message: {
            ScrollView {
                Text(getManualCommands())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 300)
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
                        driveManager.performEFICheck()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("EFI Check")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: {
                        showManualInstructions = true
                    }) {
                        HStack {
                            Image(systemName: "terminal")
                            Text("Manual Commands")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Drive List
                if driveManager.allDrives.isEmpty {
                    EmptyDrivesView
                } else {
                    VStack(spacing: 8) {
                        // EFI Partitions Section
                        let efiDrives = driveManager.allDrives.filter { $0.isEFI }
                        if !efiDrives.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EFI Partitions (\(efiDrives.count))")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                
                                Text("Note: EFI mounting requires administrator password")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                ForEach(efiDrives) { drive in
                                    DriveCardView(drive: drive)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Regular Drives Section
                        let regularDrives = driveManager.allDrives.filter { !$0.isEFI }
                        if !regularDrives.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other Drives (\(regularDrives.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, efiDrives.isEmpty ? 0 : 20)
                                
                                ForEach(regularDrives) { drive in
                                    DriveCardView(drive: drive)
                                }
                            }
                            .padding(.horizontal)
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
                
                // EFI Check Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("EFI Health Check")
                            .font(.headline)
                    }
                    
                    Text("Check EFI status and permissions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        driveManager.performEFICheck()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Run EFI Check")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Your EFI Partitions Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("Your EFI Partitions")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        EFIPartitionRow(id: "disk0s1", size: "104.9 MB", type: "Windows", color: .blue)
                        EFIPartitionRow(id: "disk1s1", size: "209.7 MB", type: "SSD 860", color: .green)
                        EFIPartitionRow(id: "disk2s1", size: "209.7 MB", type: "macOS", color: .green)
                        EFIPartitionRow(id: "disk3s1", size: "209.7 MB", type: "pos drive", color: .green)
                        EFIPartitionRow(id: "disk11s1", size: "209.7 MB", type: "Installer", color: .green)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
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
                        Text("disk2s1 (macOS)").tag("disk2s1")
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
                    
                    Text("Note: You'll be prompted for your administrator password")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Manual Commands
                VStack(spacing: 12) {
                    Text("Manual Terminal Commands:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If automatic mounting fails, try these in Terminal:")
                            .font(.caption)
                        
                        ManualCommandRow(command: "sudo diskutil mount /dev/disk1s1")
                        ManualCommandRow(command: "sudo mount -t msdos /dev/disk1s1 /Volumes/EFI")
                        ManualCommandRow(command: "sudo mount -t msdos -o noowners,rw /dev/disk1s1 /Volumes/EFI")
                    }
                    
                    Button("Copy All Commands") {
                        copyManualCommands()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func EFIPartitionRow(id: String, size: String, type: String, color: Color) -> some View {
        HStack {
            Text("• \(id)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 70, alignment: .leading)
            
            Text(size)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70)
            
            Text(type)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
            
            Spacer()
            
            if let drive = driveManager.allDrives.first(where: { $0.identifier == id }) {
                Text(drive.isMounted ? "✅" : "❌")
                    .font(.caption)
                    .foregroundColor(drive.isMounted ? .green : .secondary)
            }
        }
    }
    
    private func ManualCommandRow(command: String) -> some View {
        HStack {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
            
            Button(action: {
                copyToClipboard(command)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.black.opacity(0.1))
        .cornerRadius(4)
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
                                .frame(maxWidth: 100)
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
    
    private func canToggle(drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            return true
        }
    }
    
    // MARK: - Helper Functions
    
    private func getManualCommands() -> String {
        return """
        Try these commands in Terminal:
        
        1. sudo diskutil mount /dev/disk1s1
        
        If that doesn't work:
        
        2. sudo mount -t msdos /dev/disk1s1 /Volumes/EFI
        
        If still doesn't work:
        
        3. sudo mount -t msdos -o noowners,rw /dev/disk1s1 /Volumes/EFI
        
        Steps:
        1. Open Terminal
        2. Copy and paste one command
        3. Press Enter
        4. Enter your password when prompted
        """
    }
    
    private func copyManualCommands() {
        copyToClipboard(getManualCommands())
        alertTitle = "Copied"
        alertMessage = "Commands copied to clipboard!"
        showAlert = true
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
