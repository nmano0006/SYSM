import SwiftUI
import AppKit

struct DriveManagementView: View {
    @State private var drives: [DriveInfo] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if isLoading {
                loadingView
            } else if drives.isEmpty {
                emptyStateView
            } else {
                drivesListView
            }
            
            footerView
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                openSecurityPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This app needs Full Disk Access to view and manage drives. Please enable it in System Settings.")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            checkPermissionsAndLoadDrives()
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drive Manager")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Simple drive mounting utility")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: checkPermissionsAndLoadDrives) {
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
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for drives...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Drives Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("1. Make sure a drive is connected")
                Text("2. Check if Full Disk Access is granted")
                Text("3. Try clicking Refresh")
            }
            .font(.callout)
            .foregroundColor(.secondary)
            
            Button("Check Permissions") {
                openSecurityPreferences()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var drivesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(drives) { drive in
                    DriveCard(drive: drive) {
                        toggleDrive(drive)
                    }
                }
            }
            .padding()
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer: Navaratnam Manoranjan")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 10))
                        Text("nmano0006@gmail.com")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        
                        Button(action: copyEmailToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Copy email")
                    }
                }
                
                Spacer()
                
                Button(action: openPayPalDonation) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                        Text("Support Development")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}

// MARK: - Drive Card Component
struct DriveCard: View {
    let drive: DriveInfo
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Drive Icon
            Image(systemName: driveIcon)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(drive.name)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
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
                        .foregroundColor(typeColor)
                }
                
                if !drive.mountPoint.isEmpty {
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: drive.isMounted ? "eject.fill" : "play.fill")
                    Text(drive.isMounted ? "Eject" : "Mount")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(drive.isMounted ? .borderedProminent.tint(.orange) : .borderedProminent.tint(.green))
            .help(drive.isMounted ? "Eject this drive" : "Mount this drive")
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var driveIcon: String {
        if drive.type.contains("USB") {
            return "externaldrive.fill.badge.usb"
        } else if drive.isInternal {
            return "internaldrive.fill"
        } else {
            return "externaldrive.fill"
        }
    }
    
    private var iconColor: Color {
        if drive.type.contains("USB") {
            return .orange
        } else if drive.isInternal {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var typeColor: Color {
        if drive.type.contains("USB") {
            return .orange
        } else if drive.isInternal {
            return .blue
        } else {
            return .secondary
        }
    }
}

// MARK: - Helper Functions
extension DriveManagementView {
    
    private func checkPermissionsAndLoadDrives() {
        // First check if we can see drives
        if !canAccessDrives() {
            showPermissionAlert = true
            return
        }
        
        loadDrives()
    }
    
    private func canAccessDrives() -> Bool {
        // Try to list volumes
        let command = "ls /Volumes 2>&1"
        let result = runCommand(command)
        
        if result.output.contains("Operation not permitted") {
            return false
        }
        
        // Try to run diskutil
        let diskutilResult = runCommand("diskutil list 2>&1")
        if diskutilResult.output.contains("Operation not permitted") {
            return false
        }
        
        return true
    }
    
    private func loadDrives() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let foundDrives = scanForDrives()
            
            DispatchQueue.main.async {
                self.drives = foundDrives
                self.isLoading = false
                
                if foundDrives.isEmpty {
                    self.alertMessage = "No mountable drives found. Make sure drives are connected and try again."
                    self.showAlert = true
                }
            }
        }
    }
    
    private func scanForDrives() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // Get mounted volumes first
        let mountedCommand = "df -h | grep '/dev/disk' | grep '/Volumes/'"
        let mountedResult = runCommand(mountedCommand)
        
        for line in mountedResult.output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 6 {
                let device = parts[0].replacingOccurrences(of: "/dev/", with: "")
                let mountPoint = parts[5]
                
                if !mountPoint.hasPrefix("/Volumes/") {
                    continue
                }
                
                let driveInfo = getDriveInfo(deviceId: device)
                if !driveInfo.name.contains("EFI") && !driveInfo.name.contains("Recovery") {
                    drives.append(driveInfo)
                }
            }
        }
        
        // Get unmounted disks
        let listCommand = "diskutil list | grep -E '^/dev/disk[0-9]+'"
        let listResult = runCommand(listCommand)
        
        for line in listResult.output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let device = parts.first?.replacingOccurrences(of: "/dev/", with: "") {
                // Skip if already in list
                if drives.contains(where: { $0.identifier == device }) {
                    continue
                }
                
                // Check if it's external
                let externalCheck = runCommand("diskutil info /dev/\(device) | grep -i 'Internal.*No'")
                if externalCheck.success {
                    let driveInfo = getDriveInfo(deviceId: device)
                    if !driveInfo.name.contains("EFI") && !driveInfo.isMounted {
                        drives.append(driveInfo)
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
    
    private func getDriveInfo(deviceId: String) -> DriveInfo {
        let infoCommand = "diskutil info /dev/\(deviceId)"
        let result = runCommand(infoCommand)
        
        var name = deviceId
        var size = "Unknown"
        var type = "External"
        var mountPoint = ""
        var isInternal = false
        var isMounted = false
        
        for line in result.output.components(separatedBy: "\n") {
            if line.contains("Volume Name:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    let volumeName = parts[1].trimmingCharacters(in: .whitespaces)
                    if !volumeName.isEmpty && volumeName != "Not applicable" {
                        name = volumeName
                    }
                }
            } else if line.contains("Disk Size:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    size = parts[1].trimmingCharacters(in: .whitespaces)
                }
            } else if line.contains("Mount Point:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    mountPoint = parts[1].trimmingCharacters(in: .whitespaces)
                    isMounted = !mountPoint.isEmpty && mountPoint != "Not applicable"
                }
            } else if line.contains("Internal:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    let internalStr = parts[1].trimmingCharacters(in: .whitespaces)
                    isInternal = internalStr.contains("Yes")
                    type = isInternal ? "Internal" : "External"
                }
            } else if line.contains("Protocol:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    let protocolType = parts[1].trimmingCharacters(in: .whitespaces)
                    if protocolType.contains("USB") {
                        type = "USB"
                    }
                }
            }
        }
        
        if name == deviceId {
            name = "Disk \(deviceId)"
        }
        
        return DriveInfo(
            name: name,
            identifier: deviceId,
            size: size,
            type: type,
            mountPoint: mountPoint,
            isInternal: isInternal,
            isEFI: false,
            partitions: [],
            isMounted: isMounted,
            isSelectedForMount: false,
            isSelectedForUnmount: false
        )
    }
    
    private func toggleDrive(_ drive: DriveInfo) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let command = drive.isMounted ? 
                "diskutil unmount /dev/\(drive.identifier)" :
                "diskutil mount /dev/\(drive.identifier)"
            
            let result = runCommand(command)
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if result.success {
                    self.alertMessage = "\(drive.isMounted ? "Ejected" : "Mounted") \(drive.name) successfully"
                    self.loadDrives() // Refresh the list
                } else {
                    self.alertMessage = "Failed to \(drive.isMounted ? "eject" : "mount") \(drive.name): \(result.output)"
                }
                
                self.showAlert = true
            }
        }
    }
    
    private func runCommand(_ command: String) -> (output: String, success: Bool) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            return ("Error: \(error)", false)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        
        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")
        return (combinedOutput, task.terminationStatus == 0)
    }
    
    private func copyEmailToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("nmano0006@gmail.com", forType: .string)
        
        // Provide haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    private func openPayPalDonation() {
        let paypalURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+my+open-source+development+work.+Donations+help+fund+testing+devices%2C+server+costs%2C+and+ongoing+maintenance+for+all+my+projects.&currency_code=CAD"
        
        if let url = URL(string: paypalURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openSecurityPreferences() {
        // Open System Settings to Privacy & Security
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }
}

struct DriveManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DriveManagementView()
    }
}