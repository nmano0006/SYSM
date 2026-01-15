// DriveManagementView.swift (Updated with EFI support)
import SwiftUI
import AppKit

struct DriveManagementView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var showEFIDrives = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drive Manager")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Complete drive management with EFI support")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // EFI Toggle
                Toggle("Show EFI Partitions", isOn: $showEFIDrives)
                    .onChange(of: showEFIDrives) { newValue in
                        driveManager.showEFIDrives = newValue
                        driveManager.refreshDrives()
                    }
                    .toggleStyle(.switch)
                    .padding(.trailing, 10)
                
                // Refresh Button
                Button(action: refreshDrives) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.isLoading)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            if driveManager.isLoading {
                loadingView
            } else if driveManager.allDrives.isEmpty {
                emptyStateView
            } else {
                drivesListView
            }
            
            // Action Buttons
            Divider()
            actionButtons
        }
        .frame(minWidth: 1000, minHeight: 700)
        .alert("Status", isPresented: $showMessage) {
            Button("OK") { }
        } message: {
            Text(message)
        }
        .onAppear {
            refreshDrives()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning system for drives...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Drives Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try enabling 'Show EFI Partitions' or click 'Refresh'")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Test Terminal Commands") {
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
                // EFI Drives Section (if shown)
                let efiDrives = driveManager.allDrives.filter { $0.isEFI }
                if showEFIDrives && !efiDrives.isEmpty {
                    SectionHeader(title: "EFI Partitions (\(efiDrives.count))", color: .purple, icon: "lock.shield.fill")
                    
                    ForEach(efiDrives) { drive in
                        DriveCard(drive: drive, onMount: {
                            handleMountAction(for: drive)
                        }, onUnmount: {
                            handleUnmountAction(for: drive)
                        })
                    }
                }
                
                // Mounted Drives Section
                let mountedDrives = driveManager.allDrives.filter { $0.isMounted && !$0.isEFI }
                if !mountedDrives.isEmpty {
                    SectionHeader(title: "Mounted Drives (\(mountedDrives.count))", color: .green, icon: "externaldrive.fill.badge.checkmark")
                    
                    ForEach(mountedDrives) { drive in
                        DriveCard(drive: drive, onMount: {
                            handleMountAction(for: drive)
                        }, onUnmount: {
                            handleUnmountAction(for: drive)
                        })
                    }
                }
                
                // Unmounted Drives Section
                let unmountedDrives = driveManager.allDrives.filter { !$0.isMounted && !$0.isEFI }
                if !unmountedDrives.isEmpty {
                    SectionHeader(title: "Unmounted Drives (\(unmountedDrives.count))", color: .orange, icon: "externaldrive.fill.badge.xmark")
                    
                    ForEach(unmountedDrives) { drive in
                        DriveCard(drive: drive, onMount: {
                            handleMountAction(for: drive)
                        }, onUnmount: {
                            handleUnmountAction(for: drive)
                        })
                    }
                }
            }
            .padding()
        }
    }
    
    private var actionButtons: some View {
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
            
            // Selection Info
            VStack(alignment: .trailing, spacing: 4) {
                let mountCount = driveManager.mountSelection.count
                let unmountCount = driveManager.unmountSelection.count
                
                if mountCount > 0 {
                    Text("\(mountCount) selected for mount")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                if unmountCount > 0 {
                    Text("\(unmountCount) selected for unmount")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if mountCount == 0 && unmountCount == 0 {
                    Text("No selections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 10) {
                Button("Select All Unmount") {
                    driveManager.selectAllForUnmount()
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.allDrives.filter { $0.canUnmount }.isEmpty)
                
                Button("Clear All") {
                    driveManager.clearAllSelections()
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.mountSelection.isEmpty && driveManager.unmountSelection.isEmpty)
                
                Divider()
                    .frame(height: 20)
                
                Button("Mount Selected") {
                    mountSelectedDrives()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(driveManager.mountSelection.isEmpty)
                
                Button("Unmount Selected") {
                    unmountSelectedDrives()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.unmountSelection.isEmpty)
                
                Divider()
                    .frame(height: 20)
                
                Menu {
                    Button("Mount All External") {
                        mountAllExternal()
                    }
                    
                    Button("Unmount All External") {
                        unmountAllExternal()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func refreshDrives() {
        driveManager.refreshDrives()
    }
    
    private func handleMountAction(for drive: DriveInfo) {
        driveManager.toggleMountSelection(for: drive)
    }
    
    private func handleUnmountAction(for drive: DriveInfo) {
        driveManager.toggleUnmountSelection(for: drive)
    }
    
    private func mountSelectedDrives() {
        isLoading = true
        let result = driveManager.mountSelectedDrives()
        isLoading = false
        showMessage(title: result.success ? "Success" : "Error", message: result.message)
    }
    
    private func unmountSelectedDrives() {
        isLoading = true
        let result = driveManager.unmountSelectedDrives()
        isLoading = false
        showMessage(title: result.success ? "Success" : "Error", message: result.message)
    }
    
    private func mountAllExternal() {
        isLoading = true
        DispatchQueue.global().async {
            let result = driveManager.mountAllExternal()
            DispatchQueue.main.async {
                isLoading = false
                showMessage(title: result.success ? "Success" : "Error", message: result.message)
            }
        }
    }
    
    private func unmountAllExternal() {
        isLoading = true
        DispatchQueue.global().async {
            let result = driveManager.unmountAllExternal()
            DispatchQueue.main.async {
                isLoading = false
                showMessage(title: result.success ? "Success" : "Error", message: result.message)
            }
        }
    }
    
    private func testTerminalCommands() {
        DispatchQueue.global().async {
            let commands = [
                ("diskutil list", "List all disks"),
                ("diskutil list | grep -E 'EFI.*EFI'", "EFI partitions"),
                ("mount | grep '/dev/disk'", "Mounted disks"),
                ("ls /Volumes", "Volumes directory"),
                ("df -h | head -20", "Disk usage (first 20)")
            ]
            
            var output = "Terminal Test Results:\n\n"
            
            for (command, description) in commands {
                output += "=== \(description) ===\n"
                output += "Command: \(command)\n"
                let result = ShellHelper.runCommand(command)
                output += "Output:\n\(result.output)\n\n"
            }
            
            DispatchQueue.main.async {
                showMessage(title: "Terminal Test", message: output)
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
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
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
    let drive: DriveInfo
    let onMount: () -> Void
    let onUnmount: () -> Void
    
    @StateObject private var driveManager = DriveManager.shared
    
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
                    
                    if drive.isEFI {
                        Text("EFI")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                    if drive.isInternal && !drive.isEFI {
                        Text("Internal")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
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
                            .foregroundColor(.secondary)
                    }
                    
                    if drive.isMounted {
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    } else {
                        Text("Not mounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Selection and Action Buttons
            HStack(spacing: 10) {
                // Mount Selection
                if !drive.isMounted && drive.canMount {
                    Button(action: onMount) {
                        Image(systemName: drive.isSelectedForMount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(drive.isSelectedForMount ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForMount ? "Deselect for mounting" : "Select for mounting")
                }
                
                // Unmount Selection
                if drive.isMounted && drive.canUnmount {
                    Button(action: onUnmount) {
                        Image(systemName: drive.isSelectedForUnmount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForUnmount ? "Deselect for unmounting" : "Select for unmounting")
                }
                
                // Action Button
                if drive.canMount || drive.canUnmount {
                    Button(action: {
                        if drive.isMounted {
                            onUnmount()
                        } else {
                            onMount()
                        }
                    }) {
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
                } else {
                    Text("System")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
    
    private var backgroundColor: Color {
        if drive.isSelectedForMount {
            return Color.blue.opacity(0.05)
        } else if drive.isSelectedForUnmount {
            return Color.orange.opacity(0.05)
        } else {
            return Color.gray.opacity(0.02)
        }
    }
    
    private var borderColor: Color {
        if drive.isSelectedForMount {
            return Color.blue.opacity(0.3)
        } else if drive.isSelectedForUnmount {
            return Color.orange.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Preview
struct DriveManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DriveManagementView()
    }
}