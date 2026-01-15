import SwiftUI
import AppKit

struct DriveManagementView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    @State private var showPermissionsAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main Content
            if driveManager.isLoading {
                loadingView
            } else if driveManager.allDrives.isEmpty {
                emptyStateView
            } else {
                contentView
            }
            
            // Footer with developer info
            footerView
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Permission Required", isPresented: $showPermissionsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Security Settings") {
                openSecurityPreferences()
            }
        } message: {
            Text("This app needs Full Disk Access to manage drives. Please grant permission in System Settings > Privacy & Security > Full Disk Access.")
        }
        .onAppear {
            checkPermissions()
            driveManager.refreshDrives()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drive Manager")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Mount and unmount storage drives")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    let mountedCount = driveManager.allDrives.filter { $0.isMounted }.count
                    let totalCount = driveManager.allDrives.count
                    Text("\(mountedCount)/\(totalCount) Mounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let mountSelected = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                    let unmountSelected = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                    if mountSelected > 0 {
                        Text("\(mountSelected) to mount")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if unmountSelected > 0 {
                        Text("\(unmountSelected) to unmount")
                            .font(.caption2)
                            .foregroundColor(.orange)
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
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading drives...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
            
            Text("Connect a drive and click Refresh")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Control Panel
            controlPanel
            
            // Drives List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(driveManager.allDrives) { drive in
                        DriveRowView(drive: drive, driveManager: driveManager)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                let mountCount = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                let unmountCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                
                if mountCount > 0 {
                    Text("\(mountCount) selected to mount")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if unmountCount > 0 {
                    Text("\(unmountCount) selected to unmount")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if mountCount > 0 || unmountCount > 0 {
                    Button("Clear Selection") {
                        driveManager.clearAllSelections()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            
            HStack {
                // Mount Button
                Button(action: mountSelected) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Mount Selected")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(driveManager.allDrives.filter { $0.isSelectedForMount }.isEmpty)
                
                // Unmount Button
                Button(action: unmountSelected) {
                    HStack {
                        Image(systemName: "eject.fill")
                        Text("Unmount Selected")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.allDrives.filter { $0.isSelectedForUnmount }.isEmpty)
                
                Spacer()
                
                // Quick Actions
                HStack(spacing: 8) {
                    Button(action: mountAllExternal) {
                        Image(systemName: "play.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .help("Mount all external drives")
                    
                    Button(action: unmountAllExternal) {
                        Image(systemName: "eject.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .help("Unmount all external drives")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        VStack(spacing: 8) {
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
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Drive Row View
    struct DriveRowView: View {
        let drive: DriveInfo
        @ObservedObject var driveManager: DriveManager
        
        var body: some View {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: driveIcon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                // Drive Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(drive.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if drive.isMounted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
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
                            .foregroundColor(typeColor)
                    }
                }
                
                Spacer()
                
                // Mount Point
                if !drive.mountPoint.isEmpty {
                    Text(drive.mountPoint)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // Status
                if drive.isMounted {
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons
                if canMount {
                    Button(action: { driveManager.toggleMountSelection(for: drive) }) {
                        Image(systemName: drive.isSelectedForMount ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(drive.isSelectedForMount ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForMount ? "Deselect for mount" : "Select to mount")
                } else if canUnmount {
                    Button(action: { driveManager.toggleUnmountSelection(for: drive) }) {
                        Image(systemName: drive.isSelectedForUnmount ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForUnmount ? "Deselect for unmount" : "Select to unmount")
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        
        private var driveIcon: String {
            if drive.isEFI {
                return "memorychip"
            } else if drive.isInternal {
                return "internaldrive"
            } else {
                return "externaldrive"
            }
        }
        
        private var iconColor: Color {
            if drive.isEFI {
                return .purple
            } else if drive.isInternal {
                return .blue
            } else {
                return .orange
            }
        }
        
        private var typeColor: Color {
            if drive.isEFI {
                return .purple
            } else if drive.type.contains("USB") {
                return .orange
            } else {
                return .secondary
            }
        }
        
        private var canMount: Bool {
            !drive.isMounted && !drive.isEFI
        }
        
        private var canUnmount: Bool {
            drive.isMounted && !drive.isInternal
        }
    }
    
    // MARK: - Helper Functions
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
    
    private func checkPermissions() {
        // Check if app has Full Disk Access
        let hasAccess = ShellHelper.checkFullDiskAccess()
        if !hasAccess {
            showPermissionsAlert = true
        }
    }
    
    private func openSecurityPreferences() {
        // Open System Settings to Full Disk Access
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Action Functions
    private func mountSelected() {
        let result = driveManager.mountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error", message: result.message)
        
        // Refresh after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            driveManager.refreshDrives()
        }
    }
    
    private func unmountSelected() {
        let result = driveManager.unmountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error", message: result.message)
        
        // Refresh after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            driveManager.refreshDrives()
        }
    }
    
    private func mountAllExternal() {
        let result = driveManager.mountAllExternal()
        showAlert(title: result.success ? "Success" : "Error", message: result.message)
        
        // Refresh after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            driveManager.refreshDrives()
        }
    }
    
    private func unmountAllExternal() {
        let result = driveManager.unmountAllExternal()
        showAlert(title: result.success ? "Success" : "Error", message: result.message)
        
        // Refresh after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            driveManager.refreshDrives()
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}