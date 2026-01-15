import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit
import Combine

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
    @State private var searchText = ""
    
    var filteredDrives: [DriveInfo] {
        if searchText.isEmpty {
            return driveManager.allDrives
        } else {
            return driveManager.allDrives.filter { drive in
                drive.name.localizedCaseInsensitiveContains(searchText) ||
                drive.identifier.localizedCaseInsensitiveContains(searchText) ||
                drive.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var efiDrives: [DriveInfo] {
        filteredDrives.filter { $0.isEFI }
    }
    
    var regularDrives: [DriveInfo] {
        filteredDrives.filter { !$0.isEFI }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search drives...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main Content
                TabView(selection: $selectedTab) {
                    // Tab 1: All Drives
                    ScrollView {
                        VStack(spacing: 12) {
                            // EFI Section
                            if !efiDrives.isEmpty {
                                SectionView(
                                    title: "EFI Partitions (\(efiDrives.count))",
                                    icon: "memorychip",
                                    color: .purple
                                ) {
                                    ForEach(efiDrives) { drive in
                                        EnhancedDriveRow(drive: drive)
                                    }
                                }
                            }
                            
                            // Regular Drives Section
                            if !regularDrives.isEmpty {
                                SectionView(
                                    title: "Other Drives (\(regularDrives.count))",
                                    icon: "externaldrive",
                                    color: .blue
                                ) {
                                    ForEach(regularDrives) { drive in
                                        EnhancedDriveRow(drive: drive)
                                    }
                                }
                            }
                            
                            if filteredDrives.isEmpty {
                                EmptyStateView()
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("All Drives", systemImage: "externaldrive")
                    }
                    .tag(0)
                    
                    // Tab 2: EFI Tools
                    ScrollView {
                        EFIToolsView()
                            .padding()
                    }
                    .tabItem {
                        Label("EFI Tools", systemImage: "memorychip")
                    }
                    .tag(1)
                }
                .frame(minHeight: 500)
            }
            .navigationTitle("Drive Manager")
            .navigationSubtitle("EFI & Drive Management")
            .toolbar {
                ToolbarItemGroup {
                    Button(action: {
                        driveManager.refreshDrives()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Menu {
                        Button("Run EFI Check") {
                            driveManager.performEFICheck()
                        }
                        Button("Show Manual Commands") {
                            showManualInstructions = true
                        }
                    } label: {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                }
            }
        }
        .overlay {
            if driveManager.isLoading {
                LoadingOverlay()
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle.contains("Success") || alertTitle.contains("Error") {
                    driveManager.refreshDrives()
                }
            }
            if alertMessage.contains("manual") {
                Button("Show Commands") {
                    showManualInstructions = true
                }
            }
        } message: {
            Text(alertMessage)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .sheet(isPresented: $showManualInstructions) {
            ManualCommandsSheet()
        }
        .onAppear {
            driveManager.refreshDrives()
        }
    }
    
    // MARK: - Subviews
    
    private func SectionView<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: color.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func EnhancedDriveRow(drive: DriveInfo) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(drive.isEFI ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: drive.isEFI ? "memorychip" : 
                     (drive.isInternal ? "internaldrive" : "externaldrive"))
                    .foregroundColor(drive.isEFI ? .purple : 
                                   (drive.isInternal ? .blue : .orange))
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
                    
                    if !drive.type.isEmpty && drive.type != "Unknown" {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.type)
                            .font(.caption)
                            .foregroundColor(drive.type == "NTFS" ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Mount Status
            VStack(alignment: .trailing, spacing: 4) {
                if drive.isMounted {
                    Label("Mounted", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if !drive.mountPoint.isEmpty && drive.mountPoint != "/" {
                        Text(drive.mountPoint)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Label("Unmounted", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action Button
                Button(drive.isMounted ? "Unmount" : "Mount") {
                    toggleDrive(drive)
                }
                .buttonStyle(.bordered)
                .tint(drive.isEFI ? .purple : .blue)
                .disabled(!canToggle(drive: drive))
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func EmptyStateView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Click Refresh to scan for drives")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Refresh Scan") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    private func LoadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Scanning drives...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Looking for EFI partitions")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(radius: 10)
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func canToggle(drive: DriveInfo) -> Bool {
        if drive.isMounted {
            return drive.mountPoint != "/" && !drive.mountPoint.contains("/System/Volumes/")
        } else {
            return true
        }
    }
    
    private func toggleDrive(_ drive: DriveInfo) {
        let result = driveManager.toggleMountUnmount(for: drive)
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - EFI Tools View
struct EFIToolsView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedEFI = "disk1s1"
    @State private var showCommands = false
    
    var efiDrives: [DriveInfo] {
        driveManager.allDrives.filter { $0.isEFI }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("EFI Management Tools")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            // EFI Status Card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                    Text("EFI Status")
                        .font(.headline)
                    Spacer()
                    Text("\(efiDrives.filter { $0.isMounted }.count)/\(efiDrives.count) mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if efiDrives.isEmpty {
                    Text("No EFI partitions found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(efiDrives.prefix(3)) { drive in
                        HStack {
                            Text(drive.identifier)
                                .font(.system(.body, design: .monospaced))
                            Text("•")
                            Text(drive.name)
                            Spacer()
                            Text(drive.isMounted ? "✅" : "❌")
                                .foregroundColor(drive.isMounted ? .green : .secondary)
                        }
                        .font(.caption)
                    }
                    
                    if efiDrives.count > 3 {
                        Text("+ \(efiDrives.count - 3) more EFI partitions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Quick Mount
            VStack(spacing: 12) {
                Text("Quick Mount EFI")
                    .font(.headline)
                
                Picker("Select EFI:", selection: $selectedEFI) {
                    if efiDrives.isEmpty {
                        Text("No EFI found")
                    } else {
                        ForEach(efiDrives) { drive in
                            Text("\(drive.identifier) - \(drive.name)")
                                .tag(drive.identifier)
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(efiDrives.isEmpty)
                
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
                .disabled(efiDrives.isEmpty)
                
                Text("Requires administrator password")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            
            // Advanced Tools
            VStack(spacing: 12) {
                Text("Advanced Tools")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Run EFI Check") {
                        driveManager.performEFICheck()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Manual Commands") {
                        showCommands = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showCommands) {
            ManualCommandsSheet()
        }
    }
    
    private func mountSelectedEFI() {
        driveManager.mountEFIPartition(selectedEFI)
    }
}

// MARK: - Manual Commands Sheet
struct ManualCommandsSheet: View {
    let commands = [
        "sudo diskutil mount /dev/disk1s1",
        "sudo mount -t msdos /dev/disk1s1 /Volumes/EFI",
        "sudo mount -t msdos -o rw,noowners /dev/disk1s1 /Volumes/EFI",
        "sudo mkdir -p /Volumes/EFI 2>/dev/null",
        "sudo umount /Volumes/EFI 2>/dev/null"
    ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Manual Terminal Commands")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("If automatic mounting fails, try these commands in Terminal:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(commands, id: \.self) { command in
                        HStack {
                            Text(command)
                                .font(.system(.body, design: .monospaced))
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
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Copy All") {
                        copyToClipboard(commands.joined(separator: "\n"))
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 600, height: 500)
            .navigationTitle("Manual Commands")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 900, height: 700)
    }
}