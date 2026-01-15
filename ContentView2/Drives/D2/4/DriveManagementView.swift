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
                    Text("Debug Mode - Shows diagnostic info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Debug") {
                        showDebugInfo.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: loadDrivesWithDebug) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
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
                    Text("Scanning for drives...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drives.isEmpty {
                emptyStateView
            } else {
                drivesListView
            }
            
            if showDebugInfo && !debugInfo.isEmpty {
                Divider()
                ScrollView {
                    Text(debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.05))
            }
            
            // Footer
            Divider()
            HStack {
                VStack(alignment: .leading) {
                    Text("Developer: Navaratnam Manoranjan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("nmano0006@gmail.com")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button("Support Development") {
                    NSWorkspace.shared.open(URL(string: "https://paypal.me/nmanoranjan")!)
                }
                .font(.caption)
            }
            .padding()
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
            Image(systemName: "ladybug.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Drives Found in Debug Mode")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Diagnostic Steps:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("1. ✅ Full Disk Access is enabled")
                    Text("2. Click 'Debug' button to see raw output")
                    Text("3. Check Terminal commands below:")
                        .padding(.top, 5)
                }
                .font(.body)
                
                Text("Try these commands in Terminal:")
                    .font(.headline)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("$ diskutil list")
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("$ ls -la /Volumes")
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("$ df -h")
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
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
    
    private func loadDrivesWithDebug() {
        isLoading = true
        drives.removeAll()
        debugInfo = ""
        
        DispatchQueue.global().async {
            var debugOutput = "=== DEBUG OUTPUT ===\n\n"
            
            // Test 1: Try basic commands
            debugOutput += "Test 1: Running 'whoami'\n"
            let whoami = runCommand("whoami")
            debugOutput += "Result: \(whoami.output)\nSuccess: \(whoami.success)\n\n"
            
            // Test 2: Try listing volumes
            debugOutput += "Test 2: Running 'ls /Volumes'\n"
            let lsVolumes = runCommand("ls /Volumes")
            debugOutput += "Result: \(lsVolumes.output)\nSuccess: \(lsVolumes.success)\n\n"
            
            // Test 3: Try diskutil list
            debugOutput += "Test 3: Running 'diskutil list'\n"
            let diskutilList = runCommand("diskutil list")
            debugOutput += "Success: \(diskutilList.success)\n"
            debugOutput += "Output length: \(diskutilList.output.count) characters\n\n"
            
            // Test 4: Try df command
            debugOutput += "Test 4: Running 'df -h'\n"
            let df = runCommand("df -h")
            debugOutput += "Success: \(df.success)\n"
            debugOutput += "Output length: \(df.output.count) characters\n\n"
            
            // Now scan for drives
            let foundDrives = SimpleDrive.scanDrives()
            debugOutput += "=== DRIVE SCAN RESULTS ===\n"
            debugOutput += "Found \(foundDrives.count) drives\n\n"
            
            for (index, drive) in foundDrives.enumerated() {
                debugOutput += "Drive \(index + 1):\n"
                debugOutput += "  ID: \(drive.id)\n"
                debugOutput += "  Name: \(drive.name)\n"
                debugOutput += "  Size: \(drive.size)\n"
                debugOutput += "  Mounted: \(drive.isMounted)\n"
                debugOutput += "  Mount Point: \(drive.mountPoint)\n"
                debugOutput += "  Removable: \(drive.isRemovable)\n\n"
            }
            
            // Get detailed disk info for all disks
            debugOutput += "=== DETAILED DISK INFO ===\n"
            let listAll = runCommand("diskutil list")
            let lines = listAll.output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("/dev/disk") {
                    debugOutput += line + "\n"
                }
            }
            
            DispatchQueue.main.async {
                self.debugInfo = debugOutput
                self.drives = foundDrives
                self.isLoading = false
                
                if foundDrives.isEmpty {
                    self.message = "Debug: Found 0 drives. Check debug output above."
                    self.showMessage = true
                } else {
                    self.message = "Found \(foundDrives.count) drives"
                    self.showMessage = true
                }
            }
        }
    }
    
    private func handleDriveAction(_ drive: SimpleDrive) {
        isLoading = true
        
        DispatchQueue.global().async {
            var actionDebug = "=== DRIVE ACTION ===\n"
            actionDebug += "Drive: \(drive.name) (\(drive.id))\n"
            actionDebug += "Action: \(drive.isMounted ? "Unmount" : "Mount")\n\n"
            
            let command = drive.isMounted ? 
                "diskutil unmount /dev/\(drive.id)" :
                "diskutil mount /dev/\(drive.id)"
            
            actionDebug += "Command: \(command)\n"
            
            let result = runCommand(command)
            
            actionDebug += "Success: \(result.success)\n"
            actionDebug += "Output: \(result.output)\n"
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if result.success {
                    self.message = "\(drive.isMounted ? "Unmounted" : "Mounted") \(drive.name) successfully"
                } else {
                    self.message = "Failed: \(result.output)"
                }
                
                self.showMessage = true
                
                // Update debug info
                self.debugInfo += "\n\n" + actionDebug
                
                // Refresh drives
                self.loadDrivesWithDebug()
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
        
        // Method 1: Check mounted volumes first
        let dfResult = runCommand("df -h")
        let lines = dfResult.output.components(separatedBy: "\n")
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 6, parts[0].hasPrefix("/dev/disk") {
                let device = parts[0].replacingOccurrences(of: "/dev/", with: "")
                let mountPoint = parts[5]
                
                if mountPoint.hasPrefix("/Volumes/") || mountPoint == "/" {
                    let info = getDriveInfo(device)
                    if !info.name.isEmpty && !info.name.contains("EFI") {
                        drives.append(info)
                    }
                }
            }
        }
        
        // Method 2: Check diskutil list for unmounted drives
        let diskutilResult = runCommand("diskutil list")
        let diskLines = diskutilResult.output.components(separatedBy: "\n")
        var currentDisk = ""
        
        for line in diskLines {
            if line.contains("/dev/disk") && !line.contains("s") { // Main disk, not partition
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let disk = parts.first?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = disk
                }
            }
            
            if line.contains(currentDisk) && line.contains("s") { // Partition
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let partition = parts.first, partition.hasPrefix(currentDisk) {
                    // Check if we already have this drive
                    if !drives.contains(where: { $0.id == partition }) {
                        let info = getDriveInfo(partition)
                        if !info.name.isEmpty && !info.name.contains("EFI") && !info.name.contains("Recovery") {
                            drives.append(info)
                        }
                    }
                }
            }
        }
        
        return drives.sorted { d1, d2 in
            if d1.isMounted != d2.isMounted {
                return d1.isMounted
            }
            return d1.name < d2.name
        }
    }
    
    static func getDriveInfo(_ deviceId: String) -> SimpleDrive {
        let infoCommand = "diskutil info /dev/\(deviceId)"
        let result = runCommand(infoCommand)
        
        var name = ""
        var size = "Unknown"
        var mountPoint = ""
        var isMounted = false
        var isRemovable = true
        
        for line in result.output.components(separatedBy: "\n") {
            if line.contains("Volume Name:") {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count > 1 && parts[1] != "Not applicable" {
                    name = parts[1]
                }
            } else if line.contains("Disk Size:") || line.contains("Volume Size:") {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count > 1 {
                    size = parts[1]
                }
            } else if line.contains("Mount Point:") {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count > 1 && parts[1] != "Not applicable" && !parts[1].contains("Not mounted") {
                    mountPoint = parts[1]
                    isMounted = true
                }
            } else if line.contains("Internal:") {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count > 1 && parts[1].lowercased().contains("yes") {
                    isRemovable = false
                }
            } else if line.contains("Protocol:") {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count > 1 && parts[1].contains("USB") {
                    isRemovable = true
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
    
    static func mount(_ deviceId: String) -> String {
        let result = runCommand("diskutil mount /dev/\(deviceId)")
        if result.success {
            return "Mounted successfully"
        } else {
            return "Failed to mount: \(result.output)"
        }
    }
    
    static func unmount(_ deviceId: String) -> String {
        let result = runCommand("diskutil unmount /dev/\(deviceId)")
        if result.success {
            return "Unmounted successfully"
        } else {
            return "Failed to unmount: \(result.output)"
        }
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
                Text(drive.name)
                    .font(.body)
                    .fontWeight(.medium)
                
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
            
            VStack(alignment: .trailing, spacing: 4) {
                if drive.isMounted {
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onAction) {
                    Text(drive.isMounted ? "Eject" : "Mount")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .background(drive.isMounted ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
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
        if !drive.isRemovable {
            return "internaldrive.fill"
        } else if drive.id.contains("disk0") || drive.id.contains("disk1") {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
        }
    }
    
    private var iconColor: Color {
        if !drive.isRemovable {
            return .blue
        } else if drive.id.contains("disk0") || drive.id.contains("disk1") {
            return .blue
        } else {
            return .orange
        }
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
        return ("Error: \(error)", false)
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