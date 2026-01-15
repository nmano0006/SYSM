import SwiftUI
import AppKit

struct DriveManagementView: View {
    @State private var drives: [Drive] = []
    @State private var isLoading = false
    @State private var message = ""
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drive Manager")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Complete drive management")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: scanAllDrives) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan All")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
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
            
            // Footer
            Divider()
            footerButtons
        }
        .frame(minWidth: 900, minHeight: 700)
        .alert("Status", isPresented: $showMessage) {
            Button("OK") { }
        } message: {
            Text(message)
        }
        .onAppear {
            scanAllDrives()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Drives Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Click 'Scan All' to search for drives")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Run Terminal Test") {
                testTerminalCommands()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var drivesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Mounted drives section
                let mountedDrives = drives.filter { $0.isMounted && !$0.isSystemVolume }
                if !mountedDrives.isEmpty {
                    SectionHeader(title: "Mounted Drives (\(mountedDrives.count))", color: .green)
                    
                    ForEach(mountedDrives) { drive in
                        DriveCard(drive: drive, onAction: {
                            handleDriveAction(drive)
                        })
                    }
                }
                
                // Unmounted drives section
                let unmountedDrives = drives.filter { !$0.isMounted && !$0.isSystemVolume && $0.canMount }
                if !unmountedDrives.isEmpty {
                    SectionHeader(title: "Unmounted Drives (\(unmountedDrives.count))", color: .orange)
                    
                    ForEach(unmountedDrives) { drive in
                        DriveCard(drive: drive, onAction: {
                            handleDriveAction(drive)
                        })
                    }
                }
                
                // System volumes (read-only)
                let systemVolumes = drives.filter { $0.isSystemVolume }
                if !systemVolumes.isEmpty {
                    SectionHeader(title: "System Volumes (\(systemVolumes.count))", color: .gray)
                    
                    ForEach(systemVolumes) { drive in
                        SystemDriveCard(drive: drive)
                    }
                }
            }
            .padding()
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
                        showMessage(title: "Copied", message: "Email copied to clipboard")
                    }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let mountedCount = drives.filter { $0.isMounted && !$0.isSystemVolume }.count
                let totalCount = drives.filter { !$0.isSystemVolume }.count
                Text("\(mountedCount)/\(totalCount) mountable drives")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Support Development") {
                    NSWorkspace.shared.open(URL(string: "https://paypal.me/nmanoranjan")!)
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    private func scanAllDrives() {
        isLoading = true
        
        DispatchQueue.global().async {
            let foundDrives = Drive.scanAllDrives()
            
            DispatchQueue.main.async {
                self.drives = foundDrives
                self.isLoading = false
                
                let mountableCount = foundDrives.filter { !$0.isSystemVolume }.count
                self.message = "Found \(foundDrives.count) drives (\(mountableCount) mountable)"
                self.showMessage = true
            }
        }
    }
    
    private func handleDriveAction(_ drive: Drive) {
        isLoading = true
        
        DispatchQueue.global().async {
            let success: Bool
            let actionMessage: String
            
            if drive.isMounted {
                // Unmount
                let result = Drive.unmountDrive(drive.id)
                success = result.success
                actionMessage = result.message
            } else {
                // Mount
                let result = Drive.mountDrive(drive.id)
                success = result.success
                actionMessage = result.message
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.showMessage(
                        title: "Success",
                        message: actionMessage
                    )
                } else {
                    self.showMessage(
                        title: "Error",
                        message: actionMessage
                    )
                }
                
                // Refresh after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.scanAllDrives()
                }
            }
        }
    }
    
    private func testTerminalCommands() {
        DispatchQueue.global().async {
            let commands = [
                ("diskutil list", "List all disks"),
                ("mount | grep '/dev/disk'", "Mounted disks"),
                ("ls /Volumes", "Volumes directory"),
                ("df -h | head -20", "Disk usage (first 20)")
            ]
            
            var output = "Terminal Test Results:\n\n"
            
            for (command, description) in commands {
                output += "=== \(description) ===\n"
                output += "Command: \(command)\n"
                let result = runCommand(command)
                output += "Output:\n\(result.output)\n\n"
            }
            
            DispatchQueue.main.async {
                self.showMessage(title: "Terminal Test", message: output)
            }
        }
    }
    
    private func showMessage(title: String, message: String) {
        self.message = message
        self.showMessage = true
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}

// MARK: - Drive Card
struct DriveCard: View {
    let drive: Drive
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            Image(systemName: drive.iconName)
                .font(.title2)
                .foregroundColor(drive.iconColor)
                .frame(width: 40)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(drive.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(drive.id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if drive.isRemovable {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("Removable")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                    
                    if drive.isMounted {
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                        
                        if let usage = drive.usageInfo {
                            HStack(spacing: 8) {
                                Text("Used: \(usage.used)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                
                                Text("Free: \(usage.free)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                
                                Text("\(usage.percent) used")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Text("Not mounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: onAction) {
                HStack(spacing: 6) {
                    Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                    Text(drive.isMounted ? "Eject" : "Mount")
                }
                .frame(minWidth: 100)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .background(drive.isMounted ? Color.orange : Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
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
}

// MARK: - System Drive Card (Read-only)
struct SystemDriveCard: View {
    let drive: Drive
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundColor(.gray)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(drive.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(drive.id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("System")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("System Volume")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.gray.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Drive Model
struct Drive: Identifiable {
    let id: String
    let name: String
    let size: String
    let mountPoint: String
    let isMounted: Bool
    let isRemovable: Bool
    let isSystemVolume: Bool
    let canMount: Bool
    let usageInfo: (used: String, free: String, percent: String)?
    
    var displayName: String {
        if name.isEmpty || name == id {
            return "Disk \(id)"
        }
        return name
    }
    
    var iconName: String {
        if isRemovable {
            return "externaldrive.fill"
        } else {
            return "internaldrive.fill"
        }
    }
    
    var iconColor: Color {
        if isRemovable {
            return .orange
        } else {
            return .blue
        }
    }
    
    // Scan all drives using multiple methods
    static func scanAllDrives() -> [Drive] {
        var drives: [Drive] = []
        
        // Method 1: Get mounted drives from df
        let dfResult = runCommand("df -h")
        let dfLines = dfResult.output.components(separatedBy: "\n")
        
        for line in dfLines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 6 && parts[0].hasPrefix("/dev/disk") {
                let deviceId = parts[0].replacingOccurrences(of: "/dev/", with: "")
                let size = parts[1]
                let used = parts[2]
                let free = parts[3]
                let percent = parts[4]
                let mountPoint = parts[5...].joined(separator: " ")
                
                let isSystem = mountPoint.hasPrefix("/System/Volumes/") || 
                               mountPoint == "/" ||
                               mountPoint.hasPrefix("/Library/Developer/")
                
                // Get drive name
                var name = ""
                let infoResult = runCommand("diskutil info /dev/\(deviceId)")
                for infoLine in infoResult.output.components(separatedBy: "\n") {
                    if infoLine.contains("Volume Name:") {
                        let components = infoLine.components(separatedBy: ":")
                        if components.count > 1 {
                            name = components[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
                
                if name.isEmpty {
                    name = mountPoint.components(separatedBy: "/").last ?? ""
                }
                
                // Check if removable
                let isRemovable = !deviceId.starts(with: "disk0") && !deviceId.starts(with: "disk1")
                
                let drive = Drive(
                    id: deviceId,
                    name: name,
                    size: size,
                    mountPoint: mountPoint,
                    isMounted: true,
                    isRemovable: isRemovable,
                    isSystemVolume: isSystem,
                    canMount: !isSystem,
                    usageInfo: (used: used, free: free, percent: percent)
                )
                
                if !drives.contains(where: { $0.id == deviceId }) {
                    drives.append(drive)
                }
            }
        }
        
        // Method 2: Get unmounted partitions from diskutil list
        let listResult = runCommand("diskutil list")
        let listLines = listResult.output.components(separatedBy: "\n")
        var currentDisk = ""
        
        for line in listLines {
            if line.contains("/dev/disk") && !line.contains("s") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let disk = parts.first?.replacingOccurrences(of: "/dev/", with: "") {
                    currentDisk = disk
                }
            }
            
            if line.contains(currentDisk) && line.contains("s") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let partition = parts.first, partition.hasPrefix(currentDisk) {
                    // Check if we already have this drive
                    if !drives.contains(where: { $0.id == partition }) {
                        // Get partition info
                        let infoResult = runCommand("diskutil info /dev/\(partition)")
                        
                        var name = ""
                        var size = "Unknown"
                        var mountPoint = ""
                        var isMounted = false
                        
                        for infoLine in infoResult.output.components(separatedBy: "\n") {
                            if infoLine.contains("Volume Name:") {
                                let components = infoLine.components(separatedBy: ":")
                                if components.count > 1 {
                                    name = components[1].trimmingCharacters(in: .whitespaces)
                                }
                            } else if infoLine.contains("Disk Size:") || infoLine.contains("Volume Size:") {
                                let components = infoLine.components(separatedBy: ":")
                                if components.count > 1 {
                                    size = components[1].trimmingCharacters(in: .whitespaces)
                                }
                            } else if infoLine.contains("Mount Point:") {
                                let components = infoLine.components(separatedBy: ":")
                                if components.count > 1 {
                                    mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                                    isMounted = !mountPoint.isEmpty && 
                                               mountPoint != "Not applicable" &&
                                               !mountPoint.contains("Not mounted")
                                }
                            }
                        }
                        
                        // Skip if it's a weird partition or already mounted
                        if name.contains("EFI") || name.contains("Recovery") || 
                           name.contains("VM") || name.contains("Preboot") || 
                           name.contains("Update") || size == "0 B" || size == "Zero KB" {
                            continue
                        }
                        
                        if name.isEmpty {
                            name = "Partition \(partition)"
                        }
                        
                        let isRemovable = !partition.starts(with: "disk0") && !partition.starts(with: "disk1")
                        let isSystem = mountPoint.hasPrefix("/System/Volumes/") || mountPoint == "/"
                        
                        let drive = Drive(
                            id: partition,
                            name: name,
                            size: size,
                            mountPoint: mountPoint,
                            isMounted: isMounted,
                            isRemovable: isRemovable,
                            isSystemVolume: isSystem,
                            canMount: true,
                            usageInfo: nil
                        )
                        
                        drives.append(drive)
                    }
                }
            }
        }
        
        // Method 3: Check for external unmounted disks
        let externalResult = runCommand("""
        diskutil list | grep -E '^/dev/disk[0-9]+' | while read line; do
            disk=$(echo "$line" | awk '{print $1}' | sed 's|/dev/||')
            info=$(diskutil info /dev/$disk 2>/dev/null)
            if echo "$info" | grep -q 'Internal.*No'; then
                echo "$disk"
            fi
        done
        """)
        
        let externalDisks = externalResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for diskId in externalDisks {
            if !drives.contains(where: { $0.id == diskId }) {
                let infoResult = runCommand("diskutil info /dev/\(diskId)")
                
                var name = ""
                var size = "Unknown"
                var mountPoint = ""
                var isMounted = false
                
                for infoLine in infoResult.output.components(separatedBy: "\n") {
                    if infoLine.contains("Volume Name:") || infoLine.contains("Device / Media Name:") {
                        let components = infoLine.components(separatedBy: ":")
                        if components.count > 1 {
                            let value = components[1].trimmingCharacters(in: .whitespaces)
                            if !value.isEmpty && value != "Not applicable" {
                                name = value
                            }
                        }
                    } else if infoLine.contains("Disk Size:") {
                        let components = infoLine.components(separatedBy: ":")
                        if components.count > 1 {
                            size = components[1].trimmingCharacters(in: .whitespaces)
                        }
                    } else if infoLine.contains("Mount Point:") {
                        let components = infoLine.components(separatedBy: ":")
                        if components.count > 1 {
                            mountPoint = components[1].trimmingCharacters(in: .whitespaces)
                            isMounted = !mountPoint.isEmpty && 
                                       mountPoint != "Not applicable" &&
                                       !mountPoint.contains("Not mounted")
                        }
                    }
                }
                
                if name.isEmpty {
                    name = "External Disk \(diskId)"
                }
                
                let drive = Drive(
                    id: diskId,
                    name: name,
                    size: size,
                    mountPoint: mountPoint,
                    isMounted: isMounted,
                    isRemovable: true,
                    isSystemVolume: false,
                    canMount: !isMounted,
                    usageInfo: nil
                )
                
                drives.append(drive)
            }
        }
        
        // Remove duplicates and sort
        var uniqueDrives: [Drive] = []
        var seenIds = Set<String>()
        
        for drive in drives {
            if !seenIds.contains(drive.id) {
                seenIds.insert(drive.id)
                uniqueDrives.append(drive)
            }
        }
        
        // Sort: mounted non-system first, then unmounted, then system
        return uniqueDrives.sorted { d1, d2 in
            if d1.isSystemVolume != d2.isSystemVolume {
                return !d1.isSystemVolume
            }
            if d1.isMounted != d2.isMounted {
                return d1.isMounted
            }
            return d1.displayName.lowercased() < d2.displayName.lowercased()
        }
    }
    
    static func mountDrive(_ deviceId: String) -> (success: Bool, message: String) {
        let result = runCommand("diskutil mount /dev/\(deviceId)")
        
        if result.success {
            return (true, "Mounted drive \(deviceId) successfully")
        } else {
            // Try alternative method
            let altResult = runCommand("diskutil mountDisk /dev/\(deviceId)")
            if altResult.success {
                return (true, "Mounted using alternative method")
            } else {
                return (false, "Failed to mount: \(result.output)")
            }
        }
    }
    
    static func unmountDrive(_ deviceId: String) -> (success: Bool, message: String) {
        let result = runCommand("diskutil unmount /dev/\(deviceId)")
        
        if result.success {
            return (true, "Unmounted drive \(deviceId) successfully")
        } else {
            // Try force unmount
            let forceResult = runCommand("diskutil unmount force /dev/\(deviceId)")
            if forceResult.success {
                return (true, "Force unmounted successfully")
            } else {
                return (false, "Failed to unmount: \(result.output)")
            }
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