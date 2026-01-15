import SwiftUI
import AppKit

struct DriveManagementView: View {
    @State private var drives: [SimpleDrive] = []
    @State private var isLoading = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var debugInfo = ""
    @State private var showDebugInfo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drive Manager")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Troubleshooting Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(showDebugInfo ? "Hide Debug" : "Show Debug") {
                        showDebugInfo.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: loadDrivesWithDebug) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Scan")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning system for drives...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drives.isEmpty {
                emptyStateView
            } else {
                drivesListView
            }
            
            if showDebugInfo {
                debugInfoView
            }
            
            // Footer
            Divider()
            footerButtons
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("Status", isPresented: $showMessage) {
            Button("OK") { }
        } message: {
            Text(message)
        }
        .onAppear {
            loadDrivesWithDebug()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("System Diagnostic")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .center, spacing: 15) {
                Text("No drives detected. This could mean:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No drives are connected")
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Permission issues (even with Full Disk Access)")
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Sandbox restrictions")
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Text("Quick Tests - Click to run in Terminal:")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    TerminalCommandButton(command: "diskutil list", title: "List Disks")
                    TerminalCommandButton(command: "ls -la /Volumes", title: "List Volumes")
                    TerminalCommandButton(command: "whoami", title: "Check User")
                }
                
                Button("Click 'Show Debug' above to see detailed output") {
                    showDebugInfo = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 10)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var drivesListView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(drives) { drive in
                    DriveItemView(drive: drive, onAction: {
                        handleDriveAction(drive)
                    })
                }
            }
            .padding()
        }
    }
    
    private var debugInfoView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Text("Debug Output")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: copyDebugInfo) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(debugInfo.isEmpty)
                
                Button(action: clearDebugInfo) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(debugInfo.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            
            ScrollView {
                Text(debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled) // Allow text selection
                    .padding()
            }
            .frame(height: 250)
            .background(Color.black.opacity(0.02))
        }
    }
    
    private var footerButtons: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Developer: Navaratnam Manoranjan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("nmano0006@gmail.com")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        copyToClipboard("nmano0006@gmail.com")
                        message = "Email copied to clipboard"
                        showMessage = true
                    }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Button("Open Terminal") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                }
                .font(.caption)
                
                Button("Support Development") {
                    NSWorkspace.shared.open(URL(string: "https://paypal.me/nmanoranjan")!)
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    private func loadDrivesWithDebug() {
        isLoading = true
        drives.removeAll()
        debugInfo = ""
        
        DispatchQueue.global().async {
            var debugOutput = "=== SYSTEM DRIVE DIAGNOSTIC ===\n"
            debugOutput += "Timestamp: \(Date())\n\n"
            
            // Test basic permissions
            debugOutput += "1. BASIC PERMISSION TESTS:\n"
            debugOutput += "--------------------------------\n"
            
            let whoami = runCommand("whoami")
            debugOutput += "Current user: \(whoami.output)\n"
            debugOutput += "Command success: \(whoami.success)\n\n"
            
            let idCommand = runCommand("id")
            debugOutput += "User groups: \(idCommand.output)\n\n"
            
            // Test file system access
            debugOutput += "2. FILESYSTEM ACCESS TESTS:\n"
            debugOutput += "--------------------------------\n"
            
            let lsRoot = runCommand("ls / 2>&1 | head -5")
            debugOutput += "Can list root directory: \(lsRoot.success ? "YES" : "NO")\n"
            if !lsRoot.success {
                debugOutput += "Error: \(lsRoot.output)\n"
            }
            debugOutput += "\n"
            
            // Test diskutil access
            debugOutput += "3. DISKUTIL ACCESS TESTS:\n"
            debugOutput += "--------------------------------\n"
            
            let diskutilVersion = runCommand("diskutil version")
            debugOutput += "Diskutil version check: \(diskutilVersion.success ? "SUCCESS" : "FAILED")\n"
            debugOutput += "Output: \(diskutilVersion.output)\n\n"
            
            // Try to get disk list
            let diskList = runCommand("diskutil list")
            debugOutput += "Disk list command success: \(diskList.success)\n"
            debugOutput += "Output length: \(diskList.output.count) characters\n\n"
            
            if diskList.output.count < 100 {
                debugOutput += "WARNING: Very short output from diskutil list\n"
                debugOutput += "Full output: \(diskList.output)\n\n"
            } else {
                debugOutput += "First 500 chars of diskutil list:\n"
                debugOutput += String(diskList.output.prefix(500)) + "\n...\n\n"
            }
            
            // Check mounted volumes
            debugOutput += "4. MOUNTED VOLUMES CHECK:\n"
            debugOutput += "--------------------------------\n"
            
            let dfOutput = runCommand("df -h")
            debugOutput += "df command success: \(dfOutput.success)\n"
            
            // Parse df output for drives
            let dfLines = dfOutput.output.components(separatedBy: "\n")
            var foundDrivesCount = 0
            for line in dfLines {
                if line.contains("/dev/disk") && (line.contains("/Volumes/") || line.contains(" / ")) {
                    foundDrivesCount += 1
                    debugOutput += "Found: \(line)\n"
                }
            }
            debugOutput += "Total mounted drives found: \(foundDrivesCount)\n\n"
            
            // Now scan for drives using our method
            debugOutput += "5. DRIVE SCAN RESULTS:\n"
            debugOutput += "--------------------------------\n"
            
            let foundDrives = SimpleDrive.scanDrives()
            debugOutput += "Total drives detected by app: \(foundDrives.count)\n\n"
            
            for (index, drive) in foundDrives.enumerated() {
                debugOutput += "Drive #\(index + 1):\n"
                debugOutput += "  ID: \(drive.id)\n"
                debugOutput += "  Name: \(drive.name)\n"
                debugOutput += "  Size: \(drive.size)\n"
                debugOutput += "  Mounted: \(drive.isMounted)\n"
                debugOutput += "  Mount Point: \(drive.mountPoint)\n"
                debugOutput += "  Removable: \(drive.isRemovable)\n\n"
            }
            
            // Check for specific disks
            debugOutput += "6. SPECIFIC DISK CHECKS:\n"
            debugOutput += "--------------------------------\n"
            
            // Check disk0 (usually internal)
            let disk0 = runCommand("diskutil info disk0 2>&1")
            debugOutput += "disk0 (internal) accessible: \(disk0.success ? "YES" : "NO")\n"
            if disk0.success {
                debugOutput += "disk0 exists\n"
            }
            
            // Check disk1 (usually internal secondary)
            let disk1 = runCommand("diskutil info disk1 2>&1")
            debugOutput += "disk1 accessible: \(disk1.success ? "YES" : "NO")\n"
            
            // Check for external disks (disk2 and above)
            for i in 2...10 {
                let diskCheck = runCommand("diskutil info disk\(i) 2>&1")
                if diskCheck.success {
                    debugOutput += "disk\(i) exists\n"
                }
            }
            
            debugOutput += "\n=== END DIAGNOSTIC ===\n"
            
            DispatchQueue.main.async {
                self.debugInfo = debugOutput
                self.drives = foundDrives
                self.isLoading = false
                
                if foundDrives.isEmpty {
                    self.message = "Diagnostic complete: Found 0 drives. Check debug output."
                } else {
                    self.message = "Found \(foundDrives.count) drive(s)"
                }
                self.showMessage = true
            }
        }
    }
    
    private func handleDriveAction(_ drive: SimpleDrive) {
        isLoading = true
        
        DispatchQueue.global().async {
            let command = drive.isMounted ? 
                "diskutil unmount /dev/\(drive.id)" :
                "diskutil mount /dev/\(drive.id)"
            
            let result = runCommand(command)
            
            var actionDebug = "\n=== ACTION ATTEMPT ===\n"
            actionDebug += "Time: \(Date())\n"
            actionDebug += "Drive: \(drive.name) (\(drive.id))\n"
            actionDebug += "Action: \(drive.isMounted ? "UNMOUNT" : "MOUNT")\n"
            actionDebug += "Command: \(command)\n"
            actionDebug += "Success: \(result.success)\n"
            actionDebug += "Output: \(result.output)\n"
            actionDebug += "=== END ACTION ===\n"
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if result.success {
                    self.message = "Successfully \(drive.isMounted ? "unmounted" : "mounted") \(drive.name)"
                } else {
                    self.message = "Failed to \(drive.isMounted ? "unmount" : "mount"): \(result.output)"
                }
                
                self.showMessage = true
                self.debugInfo += actionDebug
                self.loadDrivesWithDebug()
            }
        }
    }
    
    private func copyDebugInfo() {
        copyToClipboard(debugInfo)
        message = "Debug info copied to clipboard"
        showMessage = true
    }
    
    private func clearDebugInfo() {
        debugInfo = ""
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

// MARK: - Terminal Command Button
struct TerminalCommandButton: View {
    let command: String
    let title: String
    
    var body: some View {
        Button(action: runInTerminal) {
            VStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 100, height: 60)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help("Run '\(command)' in Terminal")
    }
    
    private func runInTerminal() {
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: appleScript) {
            script.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}

// MARK: - Simple Drive Model
struct SimpleDrive: Identifiable {
    let id: String
    let name: String
    let size: String
    let isMounted: Bool
    let mountPoint: String
    let isRemovable: Bool
    
    static func scanDrives() -> [SimpleDrive] {
        var drives: [SimpleDrive] = []
        
        // Method 1: Get all disk identifiers
        let listCommand = "diskutil list | grep -o '/dev/disk[0-9]\\+' | sort -u"
        let listResult = runCommand(listCommand)
        let diskIds = listResult.output.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "/dev/", with: "")
        }.filter { !$0.isEmpty }
        
        for diskId in diskIds {
            // Get info for this disk
            let info = getDriveInfo(diskId)
            if !info.name.isEmpty && 
               !info.name.contains("EFI") && 
               !info.name.contains("Recovery") &&
               info.size != "0 B" && 
               info.size != "Zero KB" {
                drives.append(info)
            }
            
            // Also check partitions
            let partitionsCommand = "diskutil list /dev/\(diskId) | grep -o 'disk[0-9]\\+s[0-9]\\+'"
            let partitionsResult = runCommand(partitionsCommand)
            let partitions = partitionsResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for partition in partitions {
                if partition != diskId {
                    let partInfo = getDriveInfo(partition)
                    if !partInfo.name.isEmpty && 
                       !partInfo.name.contains("EFI") && 
                       !partInfo.name.contains("Recovery") &&
                       partInfo.size != "0 B" && 
                       partInfo.size != "Zero KB" {
                        drives.append(partInfo)
                    }
                }
            }
        }
        
        // Remove duplicates by ID
        var uniqueDrives: [SimpleDrive] = []
        var seenIds = Set<String>()
        
        for drive in drives {
            if !seenIds.contains(drive.id) {
                seenIds.insert(drive.id)
                uniqueDrives.append(drive)
            }
        }
        
        return uniqueDrives.sorted { d1, d2 in
            if d1.isMounted != d2.isMounted {
                return d1.isMounted
            }
            return d1.name < d2.name
        }
    }
    
    static func getDriveInfo(_ deviceId: String) -> SimpleDrive {
        let infoCommand = "diskutil info /dev/\(deviceId) 2>/dev/null"
        let result = runCommand(infoCommand)
        
        var name = ""
        var size = "Unknown"
        var mountPoint = ""
        var isMounted = false
        var isRemovable = true
        
        let lines = result.output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("Volume Name:") {
                let parts = trimmed.split(separator: ":")
                if parts.count > 1 {
                    let volumeName = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    if !volumeName.isEmpty && volumeName != "Not applicable" {
                        name = volumeName
                    }
                }
            } else if trimmed.hasPrefix("Volume Size:") || trimmed.hasPrefix("Disk Size:") {
                let parts = trimmed.split(separator: ":")
                if parts.count > 1 {
                    size = String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("Mount Point:") {
                let parts = trimmed.split(separator: ":")
                if parts.count > 1 {
                    let mp = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    if !mp.isEmpty && mp != "Not applicable" && !mp.contains("Not mounted") {
                        mountPoint = mp
                        isMounted = true
                    }
                }
            } else if trimmed.hasPrefix("Internal:") {
                let parts = trimmed.split(separator: ":")
                if parts.count > 1 {
                    let internalStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    isRemovable = !(internalStr.lowercased().contains("yes") || internalStr == "Yes")
                }
            }
        }
        
        if name.isEmpty {
            name = "Disk \(deviceId)"
        }
        
        return SimpleDrive(
            id: deviceId,
            name: name,
            size: size,
            isMounted: isMounted,
            mountPoint: mountPoint,
            isRemovable: isRemovable
        )
    }
}

// MARK: - Drive Item View
struct DriveItemView: View {
    let drive: SimpleDrive
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: driveIcon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(drive.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(drive.id)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(drive.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !drive.mountPoint.isEmpty {
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button(action: onAction) {
                Text(drive.isMounted ? "Eject" : "Mount")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .background(drive.isMounted ? Color.orange : Color.green)
            .foregroundColor(.white)
            .cornerRadius(6)
            .help(drive.isMounted ? "Eject this drive" : "Mount this drive")
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var driveIcon: String {
        drive.isRemovable ? "externaldrive.fill" : "internaldrive.fill"
    }
    
    private var iconColor: Color {
        drive.isRemovable ? .orange : .blue
    }
}

// MARK: - Helper function
func runCommand(_ command: String) -> (output: String, success: Bool) {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    
    do {
        try task.run()
    } catch {
        return ("Error: \(error.localizedDescription)", false)
    }
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    task.waitUntilExit()
    
    return (output.trimmingCharacters(in: .whitespacesAndNewlines), task.terminationStatus == 0)
}

struct DriveManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DriveManagementView()
    }
}