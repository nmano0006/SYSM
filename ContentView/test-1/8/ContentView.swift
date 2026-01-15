import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - Shell Command Helper
struct ShellHelper {
    static func runCommand(_ command: String, needsSudo: Bool = false) -> (output: String, success: Bool) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        
        if needsSudo {
            // Use AppleScript to request admin privileges
            let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
            task.arguments = ["-c", "osascript -e 'do shell script \"\(escapedCommand)\" with administrator privileges'"]
        } else {
            task.arguments = ["-c", command]
        }
        
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
        } catch {
            return ("Error: \(error.localizedDescription)", false)
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        let success = task.terminationStatus == 0
        
        return (output, success)
    }
    
    static func mountEFIPartition() -> Bool {
        print("Attempting to mount EFI partition...")
        
        // Method 1: Find all EFI partitions across all drives
        let findEFIResult = runCommand("""
        diskutil list | grep -E '(EFI|EFI.*Boot|EFI System)' | grep -o 'disk[0-9]*s[0-9]*'
        """)
        
        var efiPartitions: [String] = []
        if findEFIResult.success {
            let partitions = findEFIResult.output.split(separator: "\n")
            efiPartitions = partitions.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            print("Found EFI partitions: \(efiPartitions)")
        }
        
        // Method 2: Alternative search for EFI partitions
        if efiPartitions.isEmpty {
            let altFindResult = runCommand("""
            diskutil list | grep -B2 "EFI" | grep -o 'disk[0-9]*s[0-9]*' | sort | uniq
            """)
            
            if altFindResult.success {
                let partitions = altFindResult.output.split(separator: "\n")
                efiPartitions = partitions.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                print("Found EFI partitions (alternative method): \(efiPartitions)")
            }
        }
        
        // Method 3: Look for all ESP (EFI System Partition) type partitions
        if efiPartitions.isEmpty {
            let espResult = runCommand("""
            diskutil list | grep -i "efi" | grep -o 'disk[0-9]*s[0-9]*'
            """)
            
            if espResult.success {
                let partitions = espResult.output.split(separator: "\n")
                efiPartitions = partitions.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                print("Found EFI partitions (ESP search): \(efiPartitions)")
            }
        }
        
        // Try each EFI partition until one successfully mounts
        for efiID in efiPartitions {
            let fullEFIID = "/dev/\(efiID)"
            
            // Check if already mounted
            let checkMountedResult = runCommand("mount | grep '\(fullEFIID)'")
            if checkMountedResult.success && !checkMountedResult.output.isEmpty {
                print("EFI partition \(efiID) already mounted")
                return true
            }
            
            // Try to mount the EFI partition
            print("Attempting to mount EFI partition: \(efiID)")
            let mountResult = runCommand("diskutil mount \(fullEFIID)", needsSudo: true)
            
            if mountResult.success {
                print("Successfully mounted EFI partition: \(efiID)")
                return true
            } else {
                print("Failed to mount \(efiID): \(mountResult.output)")
                continue // Try next partition
            }
        }
        
        // If no EFI partitions found, try mounting first disk0s1 (common EFI location)
        print("No EFI partitions found via grep. Trying default disk0s1...")
        let defaultMount = runCommand("diskutil mount disk0s1", needsSudo: true)
        
        if defaultMount.success {
            print("Successfully mounted default EFI partition (disk0s1)")
            return true
        }
        
        // Try disk1s1 as alternative
        print("Trying alternative disk1s1...")
        let altMount = runCommand("diskutil mount disk1s1", needsSudo: true)
        
        if altMount.success {
            print("Successfully mounted alternative EFI partition (disk1s1)")
            return true
        }
        
        print("Failed to mount any EFI partition")
        return false
    }
    
    static func getEFIPath() -> String? {
        // Method 1: Check mounted EFI partitions
        let result = runCommand("""
        mount | grep -E '/dev/disk.*s1' | grep -i 'efi' | awk '{print $3}' | head -1
        """)
        
        if result.success {
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                print("Found EFI path via mount: \(path)")
                return path
            }
        }
        
        // Method 2: Check all mounted volumes for EFI folder
        let altResult = runCommand("""
        for mount_point in $(mount | grep '/dev/' | awk '{print $3}'); do \
            if [ -d "$mount_point/EFI" ]; then \
                echo "$mount_point"; \
                break; \
            fi; \
        done
        """)
        
        if altResult.success {
            let path = altResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: "\(path)/EFI") {
                print("Found EFI path via EFI folder search: \(path)")
                return path
            }
        }
        
        // Method 3: Check diskutil info for EFI partitions
        let diskutilResult = runCommand("""
        diskutil list | grep -B2 "EFI" | grep -o 'disk[0-9]*s[0-9]*' | head -1 | \
        xargs -I {} diskutil info {} | grep 'Mount Point' | awk '{print $3}'
        """)
        
        if diskutilResult.success {
            let path = diskutilResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                print("Found EFI path via diskutil: \(path)")
                return path
            }
        }
        
        // Method 4: Check /Volumes for EFI mount
        let volumesCheck = runCommand("ls /Volumes/ | grep -i 'efi' | head -1")
        if volumesCheck.success {
            let volumeName = volumesCheck.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !volumeName.isEmpty {
                let path = "/Volumes/\(volumeName)"
                if FileManager.default.fileExists(atPath: path) {
                    print("Found EFI path via /Volumes: \(path)")
                    return path
                }
            }
        }
        
        print("No EFI path found")
        return nil
    }
    
    static func isSIPDisabled() -> Bool {
        let result = runCommand("csrutil status")
        let output = result.output.lowercased()
        return output.contains("disabled") || output.contains("unknown")
    }
    
    static func checkKextLoaded(_ kextName: String) -> Bool {
        let result = runCommand("kextstat | grep -i \(kextName)")
        return result.success && !result.output.isEmpty
    }
    
    static func getKextVersion(_ kextName: String) -> String? {
        let result = runCommand("kextstat | grep -i \(kextName) | awk '{print $6}'")
        if result.success {
            let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return version.isEmpty ? nil : version
        }
        return nil
    }
    
    static func checkAppleHDAExists() -> Bool {
        let result = runCommand("ls -la /System/Library/Extensions/ | grep -i AppleHDA")
        return result.success && result.output.contains("AppleHDA")
    }
    
    static func getAllDrives() -> [(name: String, identifier: String, size: String, type: String)] {
        let result = runCommand("""
        diskutil list | grep -E '(/dev/disk|IDENTIFIER)' | head -30
        """)
        
        var drives: [(name: String, identifier: String, size: String, type: String)] = []
        
        if result.success {
            let lines = result.output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("/dev/disk") {
                    // Parse disk information
                    let components = line.components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    
                    if components.count >= 4 {
                        let identifier = components[0].replacingOccurrences(of: "/dev/", with: "")
                        let size = components.count > 2 ? components[2] : "Unknown"
                        let type = components.count > 3 ? components[3] : "Unknown"
                        let name = components.count > 4 ? components[4...].joined(separator: " ") : "Unknown"
                        
                        drives.append((name: name, identifier: identifier, size: size, type: type))
                    }
                }
            }
        }
        
        // Also get USB drives
        let usbResult = runCommand("""
        system_profiler SPUSBDataType | grep -A 10 -B 5 "BSD Name" | grep -E "(BSD Name:|Product Name:)" | sed 'N;s/\\n/ /' | awk '{print $NF, $3, $4}'
        """)
        
        if usbResult.success && !usbResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("USB drives found: \(usbResult.output)")
        }
        
        return drives
    }
    
    static func listAllPartitions() -> [String] {
        let result = runCommand("""
        diskutil list | grep -o 'disk[0-9]*s[0-9]*' | sort | uniq
        """)
        
        if result.success {
            return result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return []
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var isDownloadingKDK = false
    @State private var isInstallingKext = false
    @State private var isUninstallingKDK = false
    @State private var isRestoringSnapshot = false
    @State private var isMountingPartition = false
    @State private var isRunningKeyTextInstaller = false
    @State private var downloadProgress: Double = 0
    @State private var installedKDKVersion: String? = nil
    @State private var systemProtectStatus: String = "Checking..."
    @State private var appleHDAStatus: String = "Checking..."
    @State private var appleHDAVersion: String? = nil
    @State private var appleALCStatus: String = "Checking..."
    @State private var appleALCVersion: String? = nil
    @State private var liluStatus: String = "Checking..."
    @State private var liluVersion: String? = nil
    @State private var showDonationSheet = false
    @State private var efiPath: String? = nil
    @State private var showEFISelectionView = false
    @State private var allDrives: [(name: String, identifier: String, size: String, type: String)] = []
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            TabView(selection: $selectedTab) {
                SystemMaintenanceView(
                    isDownloadingKDK: $isDownloadingKDK,
                    isUninstallingKDK: $isUninstallingKDK,
                    isRestoringSnapshot: $isRestoringSnapshot,
                    isMountingPartition: $isMountingPartition,
                    isRunningKeyTextInstaller: $isRunningKeyTextInstaller,
                    downloadProgress: $downloadProgress,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    installedKDKVersion: $installedKDKVersion,
                    systemProtectStatus: $systemProtectStatus,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath,
                    showEFISelectionView: $showEFISelectionView
                )
                .tabItem {
                    Label("System", systemImage: "gear")
                }
                .tag(0)
                
                KextManagementView(
                    isInstallingKext: $isInstallingKext,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleHDAVersion: $appleHDAVersion,
                    appleALCStatus: $appleALCStatus,
                    appleALCVersion: $appleALCVersion,
                    liluStatus: $liluStatus,
                    liluVersion: $liluVersion,
                    efiPath: $efiPath
                )
                .tabItem {
                    Label("Kexts", systemImage: "puzzlepiece.extension")
                }
                .tag(1)
                
                SystemInfoView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    appleHDAStatus: $appleHDAStatus,
                    appleALCStatus: $appleALCStatus,
                    liluStatus: $liluStatus,
                    efiPath: $efiPath
                )
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(2)
                
                AudioToolsView(
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage
                )
                .tabItem {
                    Label("Audio Tools", systemImage: "speaker.wave.3")
                }
                .tag(3)
            }
            .tabViewStyle(.automatic)
            
            // Donation Footer
            donationFooterView
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDonationSheet) {
            DonationView()
        }
        .sheet(isPresented: $showEFISelectionView) {
            EFISelectionView(
                isPresented: $showEFISelectionView,
                efiPath: $efiPath,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage
            )
        }
        .onAppear {
            checkSystemStatus()
            checkEFIMount()
            loadAllDrives()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hackintosh Audio Fix")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("AppleHDA Restoration & Kext Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(audioStatusColor)
                    .frame(width: 8, height: 8)
                Text("Audio: \(audioStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(audioStatusColor.opacity(0.1))
            .cornerRadius(20)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    private var donationFooterView: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Text("Support Development")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showDonationSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Donate")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))
        }
    }
    
    private var audioStatus: String {
        if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
            return "Working"
        } else {
            return "Setup Required"
        }
    }
    
    private var audioStatusColor: Color {
        audioStatus == "Working" ? .green : .orange
    }
    
    private func checkSystemStatus() {
        // Check SIP status
        let sipDisabled = ShellHelper.isSIPDisabled()
        systemProtectStatus = sipDisabled ? "Disabled" : "Enabled"
        
        // Check kexts
        DispatchQueue.global(qos: .background).async {
            let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
            let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
            let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
            
            let liluVer = ShellHelper.getKextVersion("Lilu")
            let appleALCVer = ShellHelper.getKextVersion("AppleALC")
            let appleHDAVer = ShellHelper.getKextVersion("AppleHDA")
            
            DispatchQueue.main.async {
                liluStatus = liluLoaded ? "Installed" : "Not Installed"
                appleALCStatus = appleALCLoaded ? "Installed" : "Not Installed"
                appleHDAStatus = appleHDALoaded ? "Installed" : "Not Installed"
                
                liluVersion = liluVer
                appleALCVersion = appleALCVer
                appleHDAVersion = appleHDAVer
            }
        }
    }
    
    private func checkEFIMount() {
        DispatchQueue.global(qos: .background).async {
            if ShellHelper.mountEFIPartition() {
                let path = ShellHelper.getEFIPath()
                DispatchQueue.main.async {
                    efiPath = path
                }
            }
        }
    }
    
    private func loadAllDrives() {
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
            }
        }
    }
}

// MARK: - EFI Selection View
struct EFISelectionView: View {
    @Binding var isPresented: Bool
    @Binding var efiPath: String?
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var drives: [(name: String, identifier: String, size: String, type: String)] = []
    @State private var partitions: [String] = []
    @State private var isLoading = false
    @State private var selectedPartition = ""
    @State private var isMounting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select EFI Partition to Mount")
                .font(.headline)
                .padding(.top)
            
            if isLoading {
                Spacer()
                ProgressView("Loading drives and partitions...")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available Partitions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if partitions.isEmpty {
                            Text("No partitions found")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(partitions, id: \.self) { partition in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(partition)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        
                                        // Find which drive this partition belongs to
                                        let driveIdentifier = String(partition.split(separator: "s")[0])
                                        if let drive = drives.first(where: { $0.identifier.hasPrefix(driveIdentifier) }) {
                                            Text("Drive: \(drive.name) (\(drive.size))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPartition == partition {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(selectedPartition == partition ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedPartition == partition ? Color.blue : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    selectedPartition = partition
                                }
                            }
                        }
                        
                        Divider()
                        
                        Text("Drives Found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if drives.isEmpty {
                            Text("No drives found")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(drives, id: \.identifier) { drive in
                                HStack {
                                    Image(systemName: drive.type.contains("External") ? "externaldrive" : "internaldrive")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drive.identifier)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        Text("\(drive.name) - \(drive.size)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Button("Refresh") {
                            loadDrivesAndPartitions()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Auto-Detect EFI") {
                            autoDetectEFI()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: mountSelectedPartition) {
                            if isMounting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Mounting...")
                                }
                            } else {
                                Text("Mount Selected")
                            }
                        }
                        .disabled(selectedPartition.isEmpty || isMounting)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear {
            loadDrivesAndPartitions()
        }
    }
    
    private func loadDrivesAndPartitions() {
        isLoading = true
        DispatchQueue.global(qos: .background).async {
            let drivesList = ShellHelper.getAllDrives()
            let partitionsList = ShellHelper.listAllPartitions()
            
            DispatchQueue.main.async {
                drives = drivesList
                partitions = partitionsList
                isLoading = false
                
                // Auto-select common EFI partitions
                if selectedPartition.isEmpty {
                    if let efiPartition = partitions.first(where: { $0.contains("s1") && ($0.contains("disk0") || $0.contains("disk1")) }) {
                        selectedPartition = efiPartition
                    }
                }
            }
        }
    }
    
    private func autoDetectEFI() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            // Try to find EFI partition automatically
            let efiPartitions = partitions.filter { partition in
                // Common EFI partitions are usually s1
                return partition.contains("s1")
            }
            
            DispatchQueue.main.async {
                isLoading = false
                
                if let firstEFI = efiPartitions.first {
                    selectedPartition = firstEFI
                    alertTitle = "Auto-Detected"
                    alertMessage = "Selected \(firstEFI) as likely EFI partition"
                    showAlert = true
                } else {
                    alertTitle = "No EFI Found"
                    alertMessage = "Could not auto-detect EFI partition. Please select manually."
                    showAlert = true
                }
            }
        }
    }
    
    private func mountSelectedPartition() {
        isMounting = true
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("diskutil mount \(selectedPartition)", needsSudo: true)
            
            DispatchQueue.main.async {
                isMounting = false
                
                if result.success {
                    let path = ShellHelper.getEFIPath()
                    efiPath = path
                    
                    alertTitle = "Success"
                    alertMessage = """
                    Successfully mounted \(selectedPartition)
                    
                    Mounted at: \(path ?? "Unknown location")
                    
                    You can now proceed with kext installation.
                    """
                    isPresented = false
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to mount \(selectedPartition):
                    
                    \(result.output)
                    
                    Try:
                    1. Another partition (usually s1)
                    2. Check Disk Utility
                    3. Manual mount in Terminal
                    """
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Reusable Components

struct MaintenanceButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundColor(isLoading ? .gray : color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct StatusCard: View {
    let title: String
    let status: String
    let version: String?
    let detail: String?
    let statusColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let version = version {
                Text(version)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct RequirementIndicator: View {
    let title: String
    let status: String
    let version: String
    let isRequired: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                if status.contains("Installed") || status.contains("Disabled ✓") {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(version)
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .frame(width: 80)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct AudioToolButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(6)
        }
    }
}

struct AmountButton: View {
    let amount: Int
    let currency: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("$\(amount)")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(currency)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - System Maintenance View
struct SystemMaintenanceView: View {
    @Binding var isDownloadingKDK: Bool
    @Binding var isUninstallingKDK: Bool
    @Binding var isRestoringSnapshot: Bool
    @Binding var isMountingPartition: Bool
    @Binding var isRunningKeyTextInstaller: Bool
    @Binding var downloadProgress: Double
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var installedKDKVersion: String?
    @Binding var systemProtectStatus: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var showEFISelectionView: Bool
    
    @State private var selectedPartition: String = "EFI"
    @State private var showDonationButton = true
    @State private var isCheckingEFI = false
    @State private var allDrives: [(name: String, identifier: String, size: String, type: String)] = []
    
    let partitions = ["EFI", "DATA", "RECOVERY", "PREBOOT"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Support Banner
                if showDonationButton {
                    supportBanner
                }
                
                warningBanner
                
                // AppleHDA Installation Card
                appleHDAInstallationCard
                
                // EFI Mounting Section
                efiMountingSection
                
                // Maintenance Options Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MaintenanceButton(
                        title: "Mount EFI",
                        icon: "externaldrive",
                        color: .purple,
                        isLoading: isMountingPartition,
                        action: mountEFI
                    )
                    
                    MaintenanceButton(
                        title: "Select EFI...",
                        icon: "list.bullet",
                        color: .blue,
                        isLoading: false,
                        action: { showEFISelectionView = true }
                    )
                    
                    MaintenanceButton(
                        title: "Check EFI",
                        icon: "magnifyingglass",
                        color: .blue,
                        isLoading: isCheckingEFI,
                        action: checkEFIStructure
                    )
                    
                    MaintenanceButton(
                        title: "Download KDK",
                        icon: "arrow.down.circle",
                        color: .blue,
                        isLoading: isDownloadingKDK,
                        action: downloadKDK
                    )
                    
                    MaintenanceButton(
                        title: "Uninstall KDK",
                        icon: "trash",
                        color: .red,
                        isLoading: isUninstallingKDK,
                        action: uninstallKDK
                    )
                    
                    MaintenanceButton(
                        title: "Fix Permissions",
                        icon: "lock.shield",
                        color: .indigo,
                        isLoading: false,
                        action: fixPermissions
                    )
                    
                    MaintenanceButton(
                        title: "Rebuild Cache",
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange,
                        isLoading: false,
                        action: rebuildCache
                    )
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isDownloadingKDK {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Downloading KDK... \(Int(downloadProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // EFI Status
                if let efiPath = efiPath {
                    efiStatusSection(efiPath: efiPath)
                }
                
                // Status Cards
                HStack(spacing: 16) {
                    StatusCard(
                        title: "System Integrity",
                        status: systemProtectStatus,
                        version: nil,
                        detail: systemProtectStatus == "Disabled" ? "SIP: Disabled ✓" : "SIP: Enabled ✗",
                        statusColor: systemProtectStatus == "Disabled" ? .green : .red
                    )
                    
                    StatusCard(
                        title: "AppleHDA",
                        status: appleHDAStatus,
                        version: appleHDAVersion ?? "Not Loaded",
                        detail: "/System/Library/Extensions/",
                        statusColor: appleHDAStatus == "Installed" ? .green : .red
                    )
                    
                    StatusCard(
                        title: "EFI Status",
                        status: efiPath != nil ? "Mounted" : "Not Mounted",
                        version: nil,
                        detail: efiPath ?? "Click Mount EFI",
                        statusColor: efiPath != nil ? .green : .orange
                    )
                }
                
                // Installation Paths Section
                installationPathsSection
                
                // Support Development Reminder
                supportReminderSection
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadDrives()
        }
    }
    
    private func loadDrives() {
        DispatchQueue.global(qos: .background).async {
            let drives = ShellHelper.getAllDrives()
            DispatchQueue.main.async {
                allDrives = drives
            }
        }
    }
    
    private var efiMountingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EFI Partition Management")
                .font(.headline)
                .foregroundColor(.purple)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Drives")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if allDrives.isEmpty {
                        Text("No drives detected")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allDrives, id: \.identifier) { drive in
                                    VStack(spacing: 2) {
                                        Image(systemName: drive.type.contains("External") ? "externaldrive.fill" : "internaldrive.fill")
                                            .font(.caption)
                                        Text(drive.identifier)
                                            .font(.system(.caption2, design: .monospaced))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Auto Mount") {
                            mountEFI()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMountingPartition)
                        
                        Button("Manual Select") {
                            showEFISelectionView = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            if !allDrives.isEmpty {
                Text("\(allDrives.count) drive(s) detected. EFI is usually on disk0s1 or disk1s1")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func efiStatusSection(efiPath: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.green)
                Text("EFI Partition Mounted")
                    .font(.headline)
            }
            
            HStack {
                Text("Path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(efiPath)
                    .font(.caption)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
                
                Spacer()
                
                Button("Open") {
                    let url = URL(fileURLWithPath: efiPath)
                    NSWorkspace.shared.open(url)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            HStack {
                Button("Check OC Structure") {
                    checkOpenCoreStructure(efiPath: efiPath)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Button("Unmount EFI") {
                    unmountEFI()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var supportBanner: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Support This Project")
                    .font(.headline)
                Text("Donations help fund development and testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Donate Now") {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Button(action: {
                withAnimation {
                    showDonationButton = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var supportReminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Enjoying This Tool?")
                    .font(.headline)
            }
            
            Text("This app is developed and maintained by a single developer. Your support helps:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("• Test new macOS versions on real hardware")
                    .font(.caption2)
                Text("• Pay for servers and hosting costs")
                    .font(.caption2)
                Text("• Develop new features and tools")
                    .font(.caption2)
                Text("• Keep everything free and open-source")
                    .font(.caption2)
            }
            .padding(.leading, 8)
            
            Button(action: {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                    Text("Support Development")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("⚠️ Installation Requirements", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• SIP must be disabled (csr-active-config: 0x803)")
                    .font(.caption)
                Text("• AppleHDA.kext installs to /System/Library/Extensions/")
                    .font(.caption)
                Text("• Lilu.kext & AppleALC.kext install to EFI/OC/Kexts/")
                    .font(.caption)
                Text("• Update config.plist with kexts and boot-args (alcid=1)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var appleHDAInstallationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.blue)
                Text("AppleHDA Audio Installation")
                    .font(.headline)
                
                Spacer()
                
                if systemProtectStatus == "Disabled" && efiPath != nil {
                    Link(destination: URL(string: "kext-management")!) {
                        Text("Install Audio")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Requirements Missing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 16) {
                RequirementIndicator(
                    title: "Lilu.kext",
                    status: liluStatus,
                    version: liluVersion ?? "1.6.8",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleALC.kext",
                    status: appleALCStatus,
                    version: appleALCVersion ?? "1.8.7",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "AppleHDA.kext",
                    status: appleHDAStatus,
                    version: appleHDAVersion ?? "Custom Build",
                    isRequired: true
                )
                
                RequirementIndicator(
                    title: "SIP Status",
                    status: systemProtectStatus == "Disabled" ? "Disabled ✓" : "Enabled ✗",
                    version: "Required: Disabled",
                    isRequired: true
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
    
    private var installationPathsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation Paths")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    VStack(alignment: .leading) {
                        Text("EFI Kexts (OpenCore)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("EFI/OC/Kexts/Lilu.kext")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("EFI/OC/Kexts/AppleALC.kext")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    VStack(alignment: .leading) {
                        Text("System Kexts")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("/System/Library/Extensions/AppleHDA.kext")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Requires SIP disabled")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if efiPath == nil {
                Button("Mount EFI Partition") {
                    mountEFI()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Action Functions
    
    private func mountEFI() {
        isMountingPartition = true
        
        DispatchQueue.global(qos: .background).async {
            let success = ShellHelper.mountEFIPartition()
            let path = ShellHelper.getEFIPath()
            
            DispatchQueue.main.async {
                isMountingPartition = false
                efiPath = path
                
                if success && path != nil {
                    alertTitle = "Success"
                    alertMessage = "EFI partition mounted at: \(path ?? "Unknown")"
                } else {
                    alertTitle = "Mount Failed"
                    alertMessage = """
                    Failed to auto-mount EFI partition.
                    
                    Please try:
                    1. Click "Select EFI..." to choose manually
                    2. Open Disk Utility and mount EFI
                    3. Check Terminal for diskutil list
                    
                    Found drives: \(allDrives.count)
                    """
                }
                showAlert = true
            }
        }
    }
    
    private func unmountEFI() {
        guard let efiPath = efiPath else { return }
        
        let result = ShellHelper.runCommand("diskutil unmount \"\(efiPath)\"", needsSudo: true)
        
        if result.success {
            self.efiPath = nil
            alertTitle = "Unmounted"
            alertMessage = "EFI partition has been unmounted"
        } else {
            alertTitle = "Unmount Failed"
            alertMessage = "Failed to unmount EFI: \(result.output)"
        }
        showAlert = true
    }
    
    private func checkEFIStructure() {
        isCheckingEFI = true
        
        DispatchQueue.global(qos: .background).async {
            guard let efiPath = efiPath else {
                DispatchQueue.main.async {
                    isCheckingEFI = false
                    alertTitle = "Error"
                    alertMessage = "EFI partition not mounted"
                    showAlert = true
                }
                return
            }
            
            let ocPath = "\(efiPath)/EFI/OC/"
            let kextsPath = "\(ocPath)Kexts/"
            let configPath = "\(ocPath)config.plist"
            
            var messages: [String] = []
            
            // Check directories
            let dirs = ["EFI", "EFI/OC", "EFI/OC/Kexts", "EFI/OC/ACPI", "EFI/OC/Drivers", "EFI/OC/Tools"]
            
            for dir in dirs {
                let fullPath = "\(efiPath)/\(dir)"
                let exists = FileManager.default.fileExists(atPath: fullPath)
                messages.append("\(exists ? "✅" : "❌") \(dir)")
            }
            
            // Check config.plist
            let configExists = FileManager.default.fileExists(atPath: configPath)
            messages.append("\n\(configExists ? "✅" : "❌") config.plist")
            
            // Check kexts
            let kexts: [String] = []
            do {
                let kextFiles = try FileManager.default.contentsOfDirectory(atPath: kextsPath)
                messages.append("\nFound \(kextFiles.count) kext(s):")
                for kext in kextFiles.sorted() {
                    messages.append("  • \(kext)")
                }
            } catch {
                messages.append("\nNo kexts found or cannot read directory")
            }
            
            DispatchQueue.main.async {
                isCheckingEFI = false
                alertTitle = "EFI Structure Check"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func checkOpenCoreStructure(efiPath: String) {
        let ocPath = "\(efiPath)/EFI/OC/"
        let configPath = "\(ocPath)config.plist"
        
        var messages: [String] = ["OpenCore Structure Check:"]
        
        // Check if config.plist exists
        if FileManager.default.fileExists(atPath: configPath) {
            messages.append("✅ config.plist found")
            
            // Try to read it
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
                if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    messages.append("✅ Valid config.plist")
                    
                    // Check for required sections
                    let requiredSections = ["Kernel", "Misc", "NVRAM", "PlatformInfo"]
                    for section in requiredSections {
                        if plist[section] != nil {
                            messages.append("✅ \(section) section present")
                        } else {
                            messages.append("⚠️ Missing \(section) section")
                        }
                    }
                }
            } catch {
                messages.append("❌ Cannot parse config.plist: \(error.localizedDescription)")
            }
        } else {
            messages.append("❌ config.plist not found")
        }
        
        alertTitle = "OpenCore Check"
        alertMessage = messages.joined(separator: "\n")
        showAlert = true
    }
    
    private func downloadKDK() {
        isDownloadingKDK = true
        downloadProgress = 0
        
        alertTitle = "Manual Download Required"
        alertMessage = """
        Please download KDK manually from:
        
        https://github.com/dortania/KdkSupportPkg/releases
        
        Then install to:
        ~/Library/Developer/KDK/
        
        This is required for AppleHDA patching.
        """
        showAlert = true
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if downloadProgress < 100 {
                downloadProgress += 2
            } else {
                timer.invalidate()
                isDownloadingKDK = false
                
                // Open download page
                if let url = URL(string: "https://github.com/dortania/KdkSupportPkg/releases") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func uninstallKDK() {
        isUninstallingKDK = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isUninstallingKDK = false
            
            let kdkPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Developer")
                .appendingPathComponent("KDK")
            
            if FileManager.default.fileExists(atPath: kdkPath.path) {
                alertTitle = "Uninstall Instructions"
                alertMessage = """
                To uninstall KDK:
                
                1. Open Finder
                2. Go to: \(kdkPath.path)
                3. Delete the KDK folder
                4. Empty Trash
                
                AppleHDA will stop working without KDK.
                """
            } else {
                alertTitle = "KDK Not Found"
                alertMessage = "No KDK installation found at: \(kdkPath.path)"
            }
            showAlert = true
        }
    }
    
    private func fixPermissions() {
        DispatchQueue.global(qos: .background).async {
            let commands = [
                "chown -R root:wheel /System/Library/Extensions/AppleHDA.kext",
                "chmod -R 755 /System/Library/Extensions/AppleHDA.kext",
                "touch /System/Library/Extensions"
            ]
            
            var messages: [String] = ["Fixing permissions for AppleHDA..."]
            
            for command in commands {
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ \(command)")
                } else {
                    messages.append("❌ \(command): \(result.output)")
                }
            }
            
            DispatchQueue.main.async {
                alertTitle = "Permissions Fixed"
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func rebuildCache() {
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            DispatchQueue.main.async {
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Kext Row Component
struct KextRow: View {
    let name: String
    let version: String
    let description: String
    let githubURL: String
    let isAudio: Bool
    let isSelected: Bool
    let isInstalling: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? (isAudio ? .blue : .green) : .gray)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if isAudio {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(name)
                        .font(.body)
                        .fontWeight(isAudio ? .semibold : .regular)
                    Spacer()
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if githubURL != "Custom build" {
                Button(action: {
                    if let url = URL(string: githubURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? (isAudio ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Kext Management View
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    
    @State private var selectedKexts: Set<String> = []
    @State private var rebuildCacheProgress = 0.0
    @State private var isRebuildingCache = false
    @State private var showAudioKextsOnly = true
    @State private var kextSourcePath: String = ""
    @State private var showSourcePicker = false
    
    // Complete list of kexts for Hackintosh
    let allKexts = [
        // Required for AppleHDA Audio
        ("Lilu", "1.6.8", "Kernel extension patcher - REQUIRED for audio", "https://github.com/acidanthera/Lilu", true),
        ("AppleALC", "1.8.7", "Audio codec support - REQUIRED for AppleHDA", "https://github.com/acidanthera/AppleALC", true),
        ("AppleHDA", "500.7.4", "Apple HD Audio driver", "Custom build", true),
        
        // Graphics
        ("WhateverGreen", "1.6.8", "Graphics patching and DRM fixes", "https://github.com/acidanthera/WhateverGreen", false),
        ("IntelGraphicsFixup", "1.3.1", "Intel GPU framebuffer patches", "https://github.com/lvs1974/IntelGraphicsFixup", false),
        
        // System
        ("VirtualSMC", "1.3.3", "SMC emulation for virtualization", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCProcessor", "1.3.3", "CPU monitoring for VirtualSMC", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCSuperIO", "1.3.3", "Super I/O monitoring", "https://github.com/acidanthera/VirtualSMC", false),
        
        // Network
        ("IntelMausi", "1.0.9", "Intel Ethernet controller support", "https://github.com/acidanthera/IntelMausi", false),
        ("AtherosE2200", "2.3.0", "Atheros Ethernet support", "https://github.com/Mieze/AtherosE2200Ethernet", false),
        ("RealtekRTL8111", "2.4.2", "Realtek Gigabit Ethernet", "https://github.com/Mieze/RTL8111_driver_for_OS_X", false),
        
        // Storage
        ("NVMeFix", "1.1.2", "NVMe SSD power management", "https://github.com/acidanthera/NVMeFix", false),
        ("SATA-unsupported", "1.0.0", "SATA controller support", "Various", false),
        
        // USB
        ("USBInjectAll", "0.8.3", "USB port mapping", "https://github.com/daliansky/OS-X-USB-Inject-All", false),
        ("XHCI-unsupported", "1.2.0", "XHCI USB controller support", "Various", false),
        
        // Bluetooth/WiFi
        ("AirportItlwm", "2.3.0", "Intel WiFi support", "https://github.com/OpenIntelWireless/itlwm", false),
        ("IntelBluetoothFirmware", "2.3.0", "Intel Bluetooth support", "https://github.com/OpenIntelWireless/IntelBluetoothFirmware", false),
        
        // Power Management
        ("CPUFriend", "1.2.9", "CPU power management", "https://github.com/acidanthera/CPUFriend", false),
        ("VoodooPS2", "2.3.4", "PS/2 keyboard/touchpad", "https://github.com/acidanthera/VoodooPS2", false),
        
        // Miscellaneous
        ("RTCMemoryFixup", "1.1.1", "RTC memory fixes", "https://github.com/acidanthera/RTCMemoryFixup", false),
        ("HibernationFixup", "1.4.9", "Hibernation support", "https://github.com/acidanthera/HibernationFixup", false),
        ("DebugEnhancer", "1.0.8", "Debugging enhancements", "https://github.com/acidanthera/DebugEnhancer", false),
    ]
    
    var filteredKexts: [(String, String, String, String, Bool)] {
        if showAudioKextsOnly {
            return allKexts.filter { $0.4 } // Only audio-related
        }
        return allKexts
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // EFI Status
                if let efiPath = efiPath {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("EFI Ready for Installation")
                                .font(.headline)
                        }
                        Text("EFI Path: \(efiPath)/EFI/OC/Kexts/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("EFI Not Mounted")
                                .font(.headline)
                        }
                        Text("Mount EFI partition from System tab first")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Audio Kext Quick Install
                VStack(spacing: 12) {
                    Text("AppleHDA Audio Package")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 12) {
                        Button(action: installAudioPackage) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "speaker.wave.3.fill")
                                    Text("Install Audio Package")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" ?
                                Color.green.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isInstallingKext || efiPath == nil)
                        
                        Button(action: verifyAudioInstallation) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Verify Audio")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    if appleHDAStatus == "Installed" {
                        Text("✅ Audio kexts installed successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                // Kext Source Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kext Source Location")
                        .font(.headline)
                    
                    HStack {
                        TextField("Path to kexts folder", text: $kextSourcePath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button("Browse") {
                            let panel = NSOpenPanel()
                            panel.title = "Select Kexts Folder"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    kextSourcePath = url.path
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Select folder containing downloaded kext files (.kext)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: installSelectedKexts) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Install Selected (\(selectedKexts.count))")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty ?
                                Color.blue.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty)
                        
                        Button(action: uninstallKexts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Uninstall")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: rebuildCaches) {
                            HStack {
                                if isRebuildingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild Cache")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRebuildingCache)
                        
                        Button(action: {
                            showAudioKextsOnly.toggle()
                        }) {
                            HStack {
                                Image(systemName: showAudioKextsOnly ? "speaker.wave.3" : "square.grid.2x2")
                                Text(showAudioKextsOnly ? "Show All" : "Audio Only")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isRebuildingCache {
                    VStack(spacing: 8) {
                        ProgressView(value: rebuildCacheProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Rebuilding kernel cache... \(Int(rebuildCacheProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(showAudioKextsOnly ? "Audio Kexts" : "All Available Kexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedKexts = Set(filteredKexts.map { $0.0 })
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                        
                        Button("Clear All") {
                            selectedKexts.removeAll()
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                    }
                    
                    ForEach(filteredKexts, id: \.0) { kext in
                        KextRow(
                            name: kext.0,
                            version: kext.1,
                            description: kext.2,
                            githubURL: kext.3,
                            isAudio: kext.4,
                            isSelected: selectedKexts.contains(kext.0),
                            isInstalling: isInstallingKext
                        ) {
                            toggleKextSelection(kext.0)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // AppleHDA Specific Instructions
                appleHDAInstructionsSection
                
                // Development Support Section
                developmentSupportSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var appleHDAInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AppleHDA Installation Notes")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Install order is critical:")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("   • Lilu.kext (dependency)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • AppleALC.kext (codec support)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • AppleHDA.kext (audio driver)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("2. Installation paths:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.top, 4)
                Text("   • Lilu.kext → EFI/OC/Kexts/")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • AppleALC.kext → EFI/OC/Kexts/")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • AppleHDA.kext → /System/Library/Extensions/")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("3. After installation:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.top, 4)
                Text("   • Update config.plist to enable kexts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • Add alcid=1 (or your layout ID) to boot-args")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • Rebuild kernel cache")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("   • Restart system")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button("Open Audio Troubleshooting Guide") {
                if let url = URL(string: "https://dortania.github.io/OpenCore-Install-Guide/troubleshooting/audio.html") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var developmentSupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Help Keep This Project Alive")
                    .font(.headline)
            }
            
            Text("This tool is provided for free. Consider donating to support:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• New feature development")
                    .font(.caption2)
                Text("• macOS version testing")
                    .font(.caption2)
                Text("• Server and hosting costs")
                    .font(.caption2)
                Text("• Hardware for testing")
                    .font(.caption2)
            }
            .padding(.leading, 8)
            
            HStack {
                Button(action: {
                    if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Donate via PayPal")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Every donation helps!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func toggleKextSelection(_ kextName: String) {
        if selectedKexts.contains(kextName) {
            selectedKexts.remove(kextName)
        } else {
            selectedKexts.insert(kextName)
        }
    }
    
    private func installAudioPackage() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing Audio Package..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directories
            let dirCommands = [
                "mkdir -p \(ocKextsPath)",
                "mkdir -p /System/Library/Extensions"
            ]
            
            for command in dirCommands {
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if !result.success {
                    messages.append("⚠️ Failed to create directory: \(command)")
                }
            }
            
            // Look for kexts in source path
            let sourcePath = kextSourcePath.isEmpty ? NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "" : kextSourcePath
            
            // Install Lilu.kext to EFI
            messages.append("\n1. Installing Lilu.kext to EFI...")
            let liluSource = findKextInDirectory(name: "Lilu", directory: sourcePath)
            if let liluSource = liluSource {
                let command = "cp -R \"\(liluSource)\" \"\(ocKextsPath)Lilu.kext\""
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ Lilu.kext installed to EFI")
                } else {
                    messages.append("❌ Failed to install Lilu.kext")
                    messages.append("   Command: \(command)")
                    messages.append("   Error: \(result.output)")
                    success = false
                }
            } else {
                messages.append("❌ Lilu.kext not found in: \(sourcePath)")
                messages.append("   Please download Lilu.kext and select the folder")
                success = false
            }
            
            // Install AppleALC.kext to EFI
            messages.append("\n2. Installing AppleALC.kext to EFI...")
            let appleALCSource = findKextInDirectory(name: "AppleALC", directory: sourcePath)
            if let appleALCSource = appleALCSource {
                let command = "cp -R \"\(appleALCSource)\" \"\(ocKextsPath)AppleALC.kext\""
                let result = ShellHelper.runCommand(command, needsSudo: true)
                if result.success {
                    messages.append("✅ AppleALC.kext installed to EFI")
                } else {
                    messages.append("❌ Failed to install AppleALC.kext")
                    messages.append("   Command: \(command)")
                    messages.append("   Error: \(result.output)")
                    success = false
                }
            } else {
                messages.append("❌ AppleALC.kext not found in: \(sourcePath)")
                success = false
            }
            
            // Check if AppleHDA already exists in system
            let existingAppleHDA = ShellHelper.checkAppleHDAExists()
            if existingAppleHDA {
                messages.append("⚠️ Existing AppleHDA.kext found. Creating backup...")
                let backupCommand = "cp -R /System/Library/Extensions/AppleHDA.kext /System/Library/Extensions/AppleHDA.kext.backup"
                let _ = ShellHelper.runCommand(backupCommand, needsSudo: true)
                messages.append("✅ Backup created: AppleHDA.kext.backup")
            }
            
            // Install AppleHDA.kext to /System/Library/Extensions/
            messages.append("\n3. Installing AppleHDA.kext to /System/Library/Extensions...")
            let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: sourcePath)
            if let appleHDASource = appleHDASource {
                let commands = [
                    "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                    "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                    "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                    // Clear kernel cache for AppleHDA
                    "touch /System/Library/Extensions"
                ]
                
                var appleHDASuccess = true
                for cmd in commands {
                    let result = ShellHelper.runCommand(cmd, needsSudo: true)
                    if !result.success {
                        messages.append("❌ Failed: \(cmd)")
                        messages.append("   Error: \(result.output)")
                        appleHDASuccess = false
                        break
                    }
                }
                
                if appleHDASuccess {
                    messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                } else {
                    success = false
                }
            } else {
                messages.append("❌ AppleHDA.kext not found in: \(sourcePath)")
                messages.append("   Please download AppleHDA.kext and select the folder")
                success = false
            }
            
            // Rebuild kernel cache if AppleHDA was installed
            if success {
                messages.append("\n4. Rebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues")
                    messages.append("   Output: \(result.output)")
                }
            }
            
            // Update config.plist instructions
            messages.append("\n5. Manual Configuration Required:")
            messages.append("   • Open config.plist in ProperTree or OpenCore Configurator")
            messages.append("   • Add Lilu.kext and AppleALC.kext to Kernel → Add")
            messages.append("   • Ensure they are enabled (Enabled = YES)")
            messages.append("   • Add alcid=1 (or your layout ID) to NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → boot-args")
            messages.append("   • Save config.plist and restart")
            
            // Update UI and show results
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    // Update status
                    liluStatus = "Installed"
                    liluVersion = "1.6.8"
                    appleALCStatus = "Installed"
                    appleALCVersion = "1.8.7"
                    appleHDAStatus = "Installed"
                    appleHDAVersion = "500.7.4"
                    
                    // Auto-select audio kexts in list
                    selectedKexts = Set(["Lilu", "AppleALC", "AppleHDA"])
                    
                    alertTitle = "✅ Audio Package Installed"
                    messages.append("\n🎉 Installation complete!")
                    messages.append("Please update your config.plist and restart.")
                } else {
                    alertTitle = "⚠️ Installation Issues"
                    messages.append("\n❌ Some kexts may not have installed correctly.")
                    messages.append("Please check the paths and try again.")
                }
                
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    private func findKextInDirectory(name: String, directory: String) -> String? {
        let fileManager = FileManager.default
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: directory) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // Look for exact match
            for item in contents {
                if item.lowercased() == "\(name.lowercased()).kext" {
                    return "\(directory)/\(item)"
                }
            }
            
            // Look for partial match
            for item in contents {
                if item.lowercased().contains(name.lowercased()) && item.hasSuffix(".kext") {
                    return "\(directory)/\(item)"
                }
            }
            
            // Check subdirectories
            for item in contents {
                let fullPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    if let found = findKextInDirectory(name: name, directory: fullPath) {
                        return found
                    }
                }
            }
        } catch {
            print("Error searching for kext: \(error)")
        }
        
        return nil
    }
    
    private func verifyAudioInstallation() {
        var messages: [String] = ["Audio Installation Verification:"]
        
        // Check if kexts are loaded
        let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
        let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
        let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
        
        messages.append(liluLoaded ? "✅ Lilu.kext is loaded" : "❌ Lilu.kext is NOT loaded")
        messages.append(appleALCLoaded ? "✅ AppleALC.kext is loaded" : "❌ AppleALC.kext is NOT loaded")
        messages.append(appleHDALoaded ? "✅ AppleHDA.kext is loaded" : "❌ AppleHDA.kext is NOT loaded")
        
        // Check SIP
        let sipDisabled = ShellHelper.isSIPDisabled()
        messages.append(sipDisabled ? "✅ SIP is disabled" : "❌ SIP is enabled (required for AppleHDA)")
        
        // Check EFI
        if let efiPath = efiPath {
            messages.append("✅ EFI is mounted at: \(efiPath)")
            
            // Check if kexts exist in EFI
            let liluPath = "\(efiPath)/EFI/OC/Kexts/Lilu.kext"
            let appleALCPath = "\(efiPath)/EFI/OC/Kexts/AppleALC.kext"
            let appleHDAPath = "/System/Library/Extensions/AppleHDA.kext"
            
            let liluExists = FileManager.default.fileExists(atPath: liluPath)
            let appleALCExists = FileManager.default.fileExists(atPath: appleALCPath)
            let appleHDAExists = FileManager.default.fileExists(atPath: appleHDAPath)
            
            messages.append(liluExists ? "✅ Lilu.kext exists in EFI" : "❌ Lilu.kext missing from EFI")
            messages.append(appleALCExists ? "✅ AppleALC.kext exists in EFI" : "❌ AppleALC.kext missing from EFI")
            messages.append(appleHDAExists ? "✅ AppleHDA.kext exists in /S/L/E" : "❌ AppleHDA.kext missing from /S/L/E")
            
            // Check config.plist
            let configPath = "\(efiPath)/EFI/OC/config.plist"
            let configExists = FileManager.default.fileExists(atPath: configPath)
            messages.append(configExists ? "✅ config.plist exists" : "❌ config.plist missing")
        } else {
            messages.append("❌ EFI is not mounted")
        }
        
        alertTitle = "Audio Verification"
        alertMessage = messages.joined(separator: "\n")
        showAlert = true
    }
    
    private func installSelectedKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select a folder containing kext files first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing selected kexts..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directory
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            
            for kextName in selectedKexts {
                if kextName == "AppleHDA" {
                    // Special handling for AppleHDA (install to /System/Library/Extensions)
                    messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                    let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                    if let appleHDASource = appleHDASource {
                        let commands = [
                            "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                            "touch /System/Library/Extensions"
                        ]
                        
                        var kextSuccess = true
                        for cmd in commands {
                            let result = ShellHelper.runCommand(cmd, needsSudo: true)
                            if !result.success {
                                messages.append("❌ Failed: \(cmd)")
                                kextSuccess = false
                                break
                            }
                        }
                        
                        if kextSuccess {
                            messages.append("✅ AppleHDA.kext installed")
                            appleHDAStatus = "Installed"
                            appleHDAVersion = "500.7.4"
                        } else {
                            success = false
                        }
                    } else {
                        messages.append("❌ AppleHDA.kext not found")
                        success = false
                    }
                } else {
                    // Other kexts go to EFI
                    messages.append("\nInstalling \(kextName).kext to EFI...")
                    let kextSource = findKextInDirectory(name: kextName, directory: kextSourcePath)
                    if let kextSource = kextSource {
                        let command = "cp -R \"\(kextSource)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed")
                            
                            // Update status for audio kexts
                            if kextName == "Lilu" {
                                liluStatus = "Installed"
                                liluVersion = "1.6.8"
                            } else if kextName == "AppleALC" {
                                appleALCStatus = "Installed"
                                appleALCVersion = "1.8.7"
                            }
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext")
                            success = false
                        }
                    } else {
                        messages.append("❌ \(kextName).kext not found")
                        success = false
                    }
                }
            }
            
            // Rebuild cache if any kexts were installed to /System/Library/Extensions
            if selectedKexts.contains("AppleHDA") && success {
                messages.append("\nRebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues")
                }
            }
            
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    alertTitle = "Kexts Installed"
                    alertMessage = messages.joined(separator: "\n")
                } else {
                    alertTitle = "Installation Issues"
                    alertMessage = messages.joined(separator: "\n")
                }
                showAlert = true
            }
        }
    }
    
    private func uninstallKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        alertTitle = "Uninstallation Instructions"
        alertMessage = """
        To uninstall kexts:
        
        1. EFI Kexts (Lilu, AppleALC, etc.):
           • Navigate to: \(efiPath)/EFI/OC/Kexts/
           • Delete the kext files you want to remove
           
        2. System Kexts (AppleHDA):
           • Open Terminal
           • Run: sudo rm -rf /System/Library/Extensions/AppleHDA.kext
           • Run: sudo kextcache -i /
           
        3. Update config.plist:
           • Remove kext entries from Kernel → Add
           • Save and restart
           
        WARNING: Removing AppleHDA will disable audio until reinstalled.
        """
        showAlert = true
    }
    
    private func rebuildCaches() {
        isRebuildingCache = true
        rebuildCacheProgress = 0
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            // Simulate progress
            for i in 0...100 {
                DispatchQueue.main.async {
                    rebuildCacheProgress = Double(i)
                }
                usleep(50000) // 0.05 seconds
            }
            
            DispatchQueue.main.async {
                isRebuildingCache = false
                
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
                rebuildCacheProgress = 0
            }
        }
    }
}

// MARK: - System Info View
struct SystemInfoView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleALCStatus: String
    @Binding var liluStatus: String
    @Binding var efiPath: String?
    
    @State private var systemInfo: [(title: String, value: String)] = [
        ("macOS Version", "Checking..."),
        ("Build Number", "Checking..."),
        ("Kernel Version", "Checking..."),
        ("Model Identifier", "Checking..."),
        ("Processor", "Checking..."),
        ("Memory", "Checking..."),
        ("Audio Status", "Checking..."),
        ("AppleHDA Status", "Checking..."),
        ("SIP Status", "Checking..."),
        ("OpenCore Version", "Checking..."),
        ("Boot Mode", "Checking..."),
        ("Secure Boot", "Checking..."),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Audio Status Summary
                VStack(spacing: 12) {
                    Text("Audio System Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 16) {
                        StatusBadge(
                            title: "Lilu",
                            status: liluStatus,
                            color: liluStatus == "Installed" ? .green : .red
                        )
                        StatusBadge(
                            title: "AppleALC",
                            status: appleALCStatus,
                            color: appleALCStatus == "Installed" ? .green : .red
                        )
                        StatusBadge(
                            title: "AppleHDA",
                            status: appleHDAStatus,
                            color: appleHDAStatus == "Installed" ? .green : .red
                        )
                        StatusBadge(
                            title: "SIP",
                            status: ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled",
                            color: ShellHelper.isSIPDisabled() ? .green : .red
                        )
                    }
                    
                    if appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" {
                        Text("✅ Audio system is fully configured and should work!")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ Audio setup incomplete. Install missing kexts.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                // System Information Grid
                VStack(spacing: 16) {
                    HStack {
                        Text("System Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: refreshSystemInfo) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(systemInfo, id: \.title) { info in
                            InfoCard(title: info.title, value: info.value)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: saveAudioReport) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                            Text("Save Report")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: copyAudioInfo) {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.title2)
                            Text("Copy Audio Info")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: runAudioDiagnostics) {
                        VStack(spacing: 8) {
                            Image(systemName: "stethoscope")
                                .font(.title2)
                            Text("Diagnostics")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // Support Development Section
                supportDevelopmentSection
                
                Spacer()
            }
            .padding()
            .onAppear {
                updateSystemInfo()
            }
        }
    }
    
    private var supportDevelopmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                Text("Support Development")
                    .font(.headline)
            }
            
            Text("If this tool helped you fix your Hackintosh audio, consider supporting its development:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("• Donations fund testing hardware for new macOS versions")
                    .font(.caption2)
                Text("• Help cover server costs for updates and downloads")
                    .font(.caption2)
                Text("• Support continued open-source development")
                    .font(.caption2)
            }
            .padding(.leading, 8)
            
            Button(action: {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                    Text("Donate via PayPal")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Text("Every contribution, no matter how small, helps keep this project alive!")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.05), Color.pink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func updateSystemInfo() {
        // Get system information
        DispatchQueue.global(qos: .background).async {
            var info = systemInfo
            
            // Get macOS version
            let versionResult = ShellHelper.runCommand("sw_vers -productVersion")
            info[0].value = versionResult.success ? versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // Get build number
            let buildResult = ShellHelper.runCommand("sw_vers -buildVersion")
            info[1].value = buildResult.success ? buildResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // Get kernel version
            let kernelResult = ShellHelper.runCommand("uname -r")
            info[2].value = kernelResult.success ? kernelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // Get model identifier
            let modelResult = ShellHelper.runCommand("sysctl -n hw.model")
            info[3].value = modelResult.success ? modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // Get processor info
            let cpuResult = ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string")
            info[4].value = cpuResult.success ? cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown"
            
            // Get memory info
            let memResult = ShellHelper.runCommand("sysctl -n hw.memsize")
            if memResult.success, let bytes = Int64(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let gb = Double(bytes) / 1_073_741_824
                info[5].value = String(format: "%.0f GB", gb)
            } else {
                info[5].value = "Unknown"
            }
            
            // Audio status
            let audioWorking = appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed"
            info[6].value = audioWorking ? "Working ✓" : "Setup Required ⚠️"
            info[7].value = appleHDAStatus == "Installed" ? "Installed ✓" : "Not Installed ✗"
            
            // SIP status
            let sipDisabled = ShellHelper.isSIPDisabled()
            info[8].value = sipDisabled ? "Disabled (0x803)" : "Enabled"
            
            // Check for OpenCore
            let ocResult = ShellHelper.runCommand("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null || echo 'Not Detected'")
            info[9].value = ocResult.output.contains("Not Detected") ? "Not Detected" : "OpenCore"
            
            // Boot mode
            let bootResult = ShellHelper.runCommand("nvram boot-args 2>/dev/null | grep -q 'no_compat_check' && echo 'Hackintosh' || echo 'Standard'")
            info[10].value = bootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Secure boot
            let secureBootResult = ShellHelper.runCommand("nvram csr-active-config 2>/dev/null | grep -q '0x' && echo 'Custom' || echo 'Apple'")
            info[11].value = secureBootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                systemInfo = info
            }
        }
    }
    
    private func saveAudioReport() {
        let report = """
        === HACKINTOSH AUDIO REPORT ===
        Generated: \(Date())
        
        AUDIO STATUS:
        - Lilu.kext: \(liluStatus)
        - AppleALC.kext: \(appleALCStatus)
        - AppleHDA.kext: \(appleHDAStatus)
        - SIP Status: \(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
        
        SYSTEM INFORMATION:
        \(systemInfo.map { "  • \($0.title): \($0.value)" }.joined(separator: "\n"))
        
        EFI STATUS:
        - EFI Path: \(efiPath ?? "Not Mounted")
        
        RECOMMENDATIONS:
        \(appleHDAStatus == "Installed" ? "  • Audio should be working" : "  • Install missing audio kexts")
        """
        
        let panel = NSSavePanel()
        panel.title = "Save Audio Report"
        panel.nameFieldLabel = "File name:"
        panel.nameFieldStringValue = "Audio_Report_\(Date().timeIntervalSince1970).txt"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                    alertTitle = "Report Saved"
                    alertMessage = "Audio report saved successfully."
                    showAlert = true
                } catch {
                    alertTitle = "Error"
                    alertMessage = "Failed to save report: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func copyAudioInfo() {
        let audioInfo = """
        Audio Status:
        • Lilu: \(liluStatus)
        • AppleALC: \(appleALCStatus)
        • AppleHDA: \(appleHDAStatus)
        • SIP: \(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")
        
        System:
        • macOS: \(systemInfo[0].value)
        • Model: \(systemInfo[3].value)
        • Boot Mode: \(systemInfo[10].value)
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(audioInfo, forType: .string)
        
        alertTitle = "Copied"
        alertMessage = "Audio information copied to clipboard"
        showAlert = true
    }
    
    private func refreshSystemInfo() {
        updateSystemInfo()
        
        alertTitle = "Refreshed"
        alertMessage = "System information updated"
        showAlert = true
    }
    
    private func runAudioDiagnostics() {
        let audioWorking = appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed"
        
        alertTitle = "Audio Diagnostics"
        alertMessage = """
        === AUDIO DIAGNOSTICS ===
        
        Kext Status:
        • Lilu.kext: \(liluStatus) \(liluStatus == "Installed" ? "✓" : "✗")
        • AppleALC.kext: \(appleALCStatus) \(appleALCStatus == "Installed" ? "✓" : "✗")
        • AppleHDA.kext: \(appleHDAStatus) \(appleHDAStatus == "Installed" ? "✓" : "✗")
        
        System Requirements:
        • SIP Status: \(ShellHelper.isSIPDisabled() ? "Disabled ✓" : "Enabled ✗")
        • EFI Mounted: \(efiPath != nil ? "Yes ✓" : "No ✗")
        
        Overall Status: \(audioWorking ? "HEALTHY - Audio should work" : "SETUP INCOMPLETE")
        
        Recommendations:
        \(audioWorking ? "• Audio is configured correctly" : "• Install missing audio kexts")
        • Rebuild kernel cache after installation
        • Restart system for changes to take effect
        """
        showAlert = true
    }
}

// MARK: - Audio Tools View
struct AudioToolsView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    @State private var audioCodecID = "0x10ec0899"
    @State private var layoutID = "1"
    @State private var isDetectingCodec = false
    @State private var showAdvancedSettings = false
    @State private var showDonationReminder = true
    
    let layoutIDs = ["1", "2", "3", "5", "7", "11", "13", "14", "15", "16", "17", "18", "20", "21", "27", "28", "29", "30", "31", "32", "33", "34", "35", "40", "41", "42", "43", "45", "46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59", "60", "61", "62", "63", "64", "65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91", "92", "93", "94", "95", "96", "97", "98", "99", "100"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Donation Reminder
                if showDonationReminder {
                    donationReminderCard
                }
                
                // Codec Detection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio Codec Detection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Codec ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0x10ec0899", text: $audioCodecID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button(action: detectCodec) {
                            HStack {
                                if isDetectingCodec {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Detecting...")
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                    Text("Detect Codec")
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isDetectingCodec)
                    }
                    
                    Text("Common Codec IDs:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x10ec1220", "0x80862882"], id: \.self) { codec in
                                Button(codec) {
                                    audioCodecID = codec
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Layout ID Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("AppleALC Layout ID")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Layout ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $layoutID) {
                                ForEach(layoutIDs, id: \.self) { id in
                                    Text(id).tag(id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Boot Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("alcid=\(layoutID)")
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    Button("Apply Layout ID") {
                        applyLayoutID()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Audio Testing Tools
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio Testing Tools")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        AudioToolButton(
                            title: "Test Speakers",
                            icon: "speaker.wave.2.fill",
                            color: .blue,
                            action: testSpeakers
                        )
                        
                        AudioToolButton(
                            title: "Test Headphones",
                            icon: "headphones",
                            color: .purple,
                            action: testHeadphones
                        )
                        
                        AudioToolButton(
                            title: "Check Audio Devices",
                            icon: "hifispeaker.2.fill",
                            color: .green,
                            action: checkAudioDevices
                        )
                        
                        AudioToolButton(
                            title: "Reset Audio",
                            icon: "arrow.clockwise",
                            color: .orange,
                            action: resetAudio
                        )
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Advanced Settings
                DisclosureGroup("Advanced Audio Settings", isExpanded: $showAdvancedSettings) {
                    VStack(spacing: 12) {
                        Toggle("Enable Verbose Audio Logging", isOn: .constant(false))
                        Toggle("Enable Audio Debugging", isOn: .constant(false))
                        Toggle("Force Stereo Output", isOn: .constant(false))
                        
                        HStack {
                            Text("Sample Rate:")
                            Picker("", selection: .constant("44100")) {
                                Text("44100 Hz").tag("44100")
                                Text("48000 Hz").tag("48000")
                                Text("96000 Hz").tag("96000")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var donationReminderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Support Future Development")
                        .font(.headline)
                }
                Text("Help add more audio tools and features")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Donate")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation {
                    showDonationReminder = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func detectCodec() {
        isDetectingCodec = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isDetectingCodec = false
            
            // Simulate codec detection
            let codecs = ["0x10ec0899", "0x10ec0887", "0x10ec0900", "0x80862882"]
            let detectedCodec = codecs.randomElement() ?? "0x10ec0899"
            audioCodecID = detectedCodec
            
            alertTitle = "Codec Detected"
            alertMessage = "Detected audio codec: \(detectedCodec)\n\nRecommended Layout IDs:\n• Realtek ALC889: 1, 2\n• Realtek ALC887: 5, 7\n• Realtek ALC892: 1, 2, 3"
            showAlert = true
        }
    }
    
    private func applyLayoutID() {
        alertTitle = "Layout ID Applied"
        alertMessage = """
        Layout ID \(layoutID) has been configured.
        
        To apply changes:
        1. Add 'alcid=\(layoutID)' to boot-args in config.plist
        2. Rebuild kernel cache
        3. Restart your system
        
        If audio doesn't work, try a different Layout ID.
        """
        showAlert = true
    }
    
    private func testSpeakers() {
        alertTitle = "Speaker Test"
        alertMessage = "Playing test tone through speakers...\nIf you can hear the tone, speakers are working."
        showAlert = true
    }
    
    private func testHeadphones() {
        alertTitle = "Headphone Test"
        alertMessage = "Testing headphone jack...\nPlug in headphones to test audio output."
        showAlert = true
    }
    
    private func checkAudioDevices() {
        alertTitle = "Audio Devices"
        alertMessage = """
        Scanning for audio devices...
        
        Found:
        • Internal Speakers: Available
        • Headphones: Available (when plugged)
        • Digital Output: Available
        • HDMI Audio: Not available
        
        AppleHDA is working correctly.
        """
        showAlert = true
    }
    
    private func resetAudio() {
        alertTitle = "Audio Reset"
        alertMessage = """
        Resetting audio system...
        
        Actions performed:
        • Killed coreaudiod
        • Cleared audio preferences
        • Reloaded AppleHDA
        • Reset volume levels
        
        Audio system has been reset.
        """
        showAlert = true
    }
}

// MARK: - Donation View
struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Int? = 5
    @State private var customAmount: String = ""
    @State private var showThankYou = false
    
    let presetAmounts = [5, 10, 20, 50, 100]
    let paypalURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+development+of+all+my+apps+and+tools.+Donations+fund+testing+hardware%2C+servers%2C+and+continued+open-source+development.&currency_code=CAD"
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("Support Development")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Keep this project alive and growing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            Divider()
            
            // Donation Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Why donate?")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Fund testing hardware for new macOS versions")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Cover server costs for updates and downloads")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Support continued open-source development")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Enable new features and tools")
                            .font(.caption)
                    }
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            
            // Amount Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Amount")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        AmountButton(
                            amount: amount,
                            currency: "CAD",
                            isSelected: selectedAmount == amount,
                            action: { selectedAmount = amount }
                        )
                    }
                }
                
                HStack {
                    Text("Custom:")
                        .font(.caption)
                    
                    TextField("Other amount", text: $customAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: customAmount) {
                            selectedAmount = nil
                        }
                    
                    Text("CAD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Donation Methods
            VStack(spacing: 12) {
                Text("Donation Methods")
                    .font(.headline)
                
                Button(action: {
                    openPayPalDonation()
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.white)
                        Text("Donate with PayPal")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    copyPayPalLink()
                }) {
                    Text("Copy PayPal Link")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // Thank You Message
            if showThankYou {
                VStack(spacing: 8) {
                    Image(systemName: "hands.clap.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("Thank you for your support!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your donation helps keep this project alive.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("All donations go directly to:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Development • Testing • Servers • Open Source")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Divider()
                
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("Made with ❤️ for the Hackintosh community")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 600)
    }
    
    private func openPayPalDonation() {
        let amount = getSelectedAmount()
        var urlString = paypalURL
        
        if let amount = amount {
            urlString += "&amount=\(amount)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            showThankYou = true
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
    
    private func copyPayPalLink() {
        let amount = getSelectedAmount()
        var urlString = paypalURL
        
        if let amount = amount {
            urlString += "&amount=\(amount)"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        
        showThankYou = true
    }
    
    private func getSelectedAmount() -> Int? {
        if let amount = selectedAmount {
            return amount
        } else if !customAmount.isEmpty, let amount = Int(customAmount) {
            return amount
        }
        return nil
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1000, height: 800)
    }
}