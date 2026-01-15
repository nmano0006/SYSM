import SwiftUI
import AppKit

struct DriveManagementView: View {
    @State private var drives: [SimpleDrive] = []
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
                    Text("Working Version - Using DF command")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: loadDrives) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
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
                    Text("Loading drives from system...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drives.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No Drives Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Click Refresh to scan again")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Test DF Command") {
                        testDFCommand()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(drives) { drive in
                            DriveItemView(drive: drive) {
                                handleDriveAction(drive)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Stats footer
            if !drives.isEmpty {
                Divider()
                HStack {
                    Text("Found \(drives.count) drive(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let mountedCount = drives.filter { $0.isMounted }.count
                    Text("\(mountedCount) mounted, \(drives.count - mountedCount) unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
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
                        .onTapGesture {
                            copyToClipboard("nmano0006@gmail.com")
                            showMessage(title: "Copied", message: "Email copied to clipboard")
                        }
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
            loadDrives()
        }
    }
    
    private func loadDrives() {
        isLoading = true
        
        DispatchQueue.global().async {
            let foundDrives = SimpleDrive.scanDrivesFromDF()
            
            DispatchQueue.main.async {
                self.drives = foundDrives
                self.isLoading = false
                
                if foundDrives.isEmpty {
                    self.showMessage(title: "Info", message: "No drives found in DF output")
                }
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
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if result.success {
                    self.showMessage(
                        title: "Success", 
                        message: "\(drive.isMounted ? "Unmounted" : "Mounted") \(drive.name) successfully"
                    )
                } else {
                    self.showMessage(
                        title: "Error", 
                        message: "Failed to \(drive.isMounted ? "unmount" : "mount"): \(result.output)"
                    )
                }
                
                // Refresh drives after action
                self.loadDrives()
            }
        }
    }
    
    private func testDFCommand() {
        let result = runCommand("df -h")
        showMessage(title: "DF Command Output", message: result.output)
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

// MARK: - Drive Model using DF output
struct SimpleDrive: Identifiable {
    let id: String
    let name: String
    let size: String
    let used: String
    let available: String
    let capacity: String
    let mountPoint: String
    let isMounted: Bool
    let isRemovable: Bool
    
    static func scanDrivesFromDF() -> [SimpleDrive] {
        var drives: [SimpleDrive] = []
        
        // Use df command to get mounted volumes
        let dfCommand = "df -h"
        let result = runCommand(dfCommand)
        
        let lines = result.output.components(separatedBy: "\n")
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // We need at least 6 columns: Filesystem, Size, Used, Avail, Capacity, Mounted on
            if parts.count >= 6 && parts[0].hasPrefix("/dev/disk") {
                let devicePath = parts[0]
                let size = parts[1]
                let used = parts[2]
                let available = parts[3]
                let capacity = parts[4]
                let mountPoint = parts[5...].joined(separator: " ")
                
                // Skip system volumes that we shouldn't touch
                if mountPoint.hasPrefix("/System/Volumes/") || 
                   mountPoint == "/" ||
                   mountPoint.hasPrefix("/Library/Developer/") {
                    continue
                }
                
                // Get device ID
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                
                // Get drive name from mount point
                var name = (mountPoint as NSString).lastPathComponent
                if name.isEmpty {
                    name = "Disk \(deviceId)"
                }
                
                // Determine if it's removable (not disk0, disk1 which are usually internal)
                let isRemovable = !deviceId.starts(with: "disk0") && !deviceId.starts(with: "disk1")
                
                let drive = SimpleDrive(
                    id: deviceId,
                    name: name,
                    size: size,
                    used: used,
                    available: available,
                    capacity: capacity,
                    mountPoint: mountPoint,
                    isMounted: true,
                    isRemovable: isRemovable
                )
                
                drives.append(drive)
            }
        }
        
        // Also look for unmounted drives using mount command
        let mountCommand = "mount | grep '/dev/disk'"
        let mountResult = runCommand(mountCommand)
        let mountLines = mountResult.output.components(separatedBy: "\n")
        
        for line in mountLines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 3 && parts[0].hasPrefix("/dev/disk") {
                let devicePath = parts[0]
                let mountPoint = parts[2]
                
                // Check if we already have this drive
                let deviceId = devicePath.replacingOccurrences(of: "/dev/", with: "")
                if !drives.contains(where: { $0.id == deviceId }) {
                    
                    // Skip system volumes
                    if mountPoint.hasPrefix("/System/Volumes/") || mountPoint == "/" {
                        continue
                    }
                    
                    var name = (mountPoint as NSString).lastPathComponent
                    if name.isEmpty {
                        name = "Disk \(deviceId)"
                    }
                    
                    let isRemovable = !deviceId.starts(with: "disk0") && !deviceId.starts(with: "disk1")
                    
                    let drive = SimpleDrive(
                        id: deviceId,
                        name: name,
                        size: "Unknown",
                        used: "Unknown",
                        available: "Unknown",
                        capacity: "Unknown",
                        mountPoint: mountPoint,
                        isMounted: true,
                        isRemovable: isRemovable
                    )
                    
                    drives.append(drive)
                }
            }
        }
        
        // Sort drives: mounted first, then by name
        return drives.sorted { d1, d2 in
            if d1.isMounted != d2.isMounted {
                return d1.isMounted
            }
            return d1.name.lowercased() < d2.name.lowercased()
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
            
            VStack(alignment: .leading, spacing: 6) {
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
                
                VStack(alignment: .leading, spacing: 2) {
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
                    
                    if drive.isMounted {
                        HStack(spacing: 8) {
                            Text("Used: \(drive.used)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("Avail: \(drive.available)")
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            Text("\(drive.capacity) full")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if drive.isMounted {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Button("Eject") {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Mount") {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
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