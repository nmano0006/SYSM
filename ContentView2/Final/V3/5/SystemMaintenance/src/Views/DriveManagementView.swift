import SwiftUI
import AppKit

struct DriveManagementView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var selectedDrive: DriveInfo?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Status"
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HeaderView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Control Panel
                        ControlPanelView
                        
                        // Drives List
                        if driveManager.allDrives.isEmpty {
                            EmptyDrivesView
                        } else {
                            DrivesListView
                        }
                        
                        // Quick Actions
                        QuickActionsGrid
                        
                        // Developer Information with Donation Link
                        DeveloperInfoView
                            .padding(.top, 10)
                    }
                    .padding()
                }
            }
            
            if driveManager.isLoading {
                ProgressOverlay
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(item: $selectedDrive) { drive in
            DriveDetailView(drive: drive, driveManager: driveManager)
        }
        .onAppear {
            driveManager.refreshDrives()
        }
    }
    
    // MARK: - Developer Information View
    private var DeveloperInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Developer Information")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Text("Navaratnam Manoranjan")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                        
                        Text("nmano0006@gmail.com")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Button(action: {
                            copyEmailToClipboard()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Copy email")
                    }
                }
                
                Spacer()
                
                // PayPal Donation Button
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Support Development")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        openPayPalDonation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.pink)
                            
                            Text("Donate via PayPal")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .help("Support open-source development work")
                    
                    Text("Help fund testing & maintenance")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 100)
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Header View
    private var HeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drive Management")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Mount, unmount, and manage storage drives")
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
    
    // MARK: - Control Panel View
    private var ControlPanelView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Drive Controls")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Clear Selection Button
                Button("Clear All") {
                    driveManager.clearAllSelections()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(driveManager.mountSelection.isEmpty && driveManager.unmountSelection.isEmpty)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Mount Button
                Button(action: {
                    mountSelected()
                }) {
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
                Button(action: {
                    unmountSelected()
                }) {
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
                
                // Only "Select All to Unmount" button
                Button("Select All to Unmount") {
                    driveManager.selectAllForUnmount()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(driveManager.allDrives.filter { 
                    $0.isMounted && 
                    !$0.mountPoint.contains("/System/Volumes/") &&
                    $0.mountPoint != "/" &&
                    !$0.mountPoint.contains("home") &&
                    !$0.mountPoint.contains("private/var") &&
                    !$0.mountPoint.contains("Library/Developer")
                }.isEmpty)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Empty Drives View
    private var EmptyDrivesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Drives Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Connect a drive or check permissions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                driveManager.refreshDrives()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Drives List View
    private var DrivesListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Drives")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let mountCount = driveManager.allDrives.filter { $0.isSelectedForMount }.count
                let unmountCount = driveManager.allDrives.filter { $0.isSelectedForUnmount }.count
                if mountCount > 0 {
                    Text("\(mountCount) to mount")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if unmountCount > 0 {
                    Text("\(unmountCount) to unmount")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // List
            ForEach(driveManager.allDrives) { drive in
                DriveRow(drive: drive)
                    .onTapGesture {
                        selectedDrive = drive
                    }
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Drive Row
    private func DriveRow(drive: DriveInfo) -> some View {
        HStack(spacing: 8) {
            // Mount/Unmount Selection
            VStack(spacing: 2) {
                // Mount checkbox (only for unmounted drives)
                if !drive.isMounted {
                    Button(action: {
                        driveManager.toggleMountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForMount ? "play.circle.fill" : "play.circle")
                            .foregroundColor(drive.isSelectedForMount ? .green : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to mount")
                }
                
                // Unmount checkbox (only for mounted drives that are not system volumes)
                if drive.isMounted && 
                   !drive.mountPoint.contains("/System/Volumes/") &&
                   drive.mountPoint != "/" &&
                   !drive.mountPoint.contains("home") &&
                   !drive.mountPoint.contains("private/var") &&
                   !drive.mountPoint.contains("Library/Developer") {
                    
                    Button(action: {
                        driveManager.toggleUnmountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForUnmount ? "eject.circle.fill" : "eject.circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Select to unmount")
                }
            }
            .frame(width: 40)
            
            // Drive Icon
            Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                .font(.title3)
            
            // Drive Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(drive.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if drive.isMounted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
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
                        .foregroundColor(drive.isEFI ? .purple : (drive.type.contains("USB") ? .orange : .secondary))
                    
                    if !drive.mountPoint.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.mountPoint)
                            .font(.caption)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Status Badge
            if drive.isMounted {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Mounted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            } else {
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("Unmounted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Detail Button
            Button(action: {
                selectedDrive = drive
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Quick Actions Grid
    private var QuickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ActionButton(
                title: "Refresh All",
                icon: "arrow.clockwise",
                color: .blue,
                action: {
                    driveManager.refreshDrives()
                }
            )
            
            ActionButton(
                title: "Mount All External",
                icon: "play.circle",
                color: .green,
                action: {
                    mountAllExternal()
                }
            )
            
            ActionButton(
                title: "Unmount All External",
                icon: "eject.circle",
                color: .orange,
                action: {
                    unmountAllExternal()
                }
            )
            
            ActionButton(
                title: "Clear Selection",
                icon: "xmark.circle",
                color: .gray,
                action: {
                    driveManager.clearAllSelections()
                }
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Action Button Helper
    private func ActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
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
            .foregroundColor(color)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Progress Overlay
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
    
    // MARK: - Action Functions
    private func mountSelected() {
        let result = driveManager.mountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func unmountSelected() {
        let result = driveManager.unmountSelectedDrives()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func mountAllExternal() {
        let result = driveManager.mountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func unmountAllExternal() {
        let result = driveManager.unmountAllExternal()
        showAlert(title: result.success ? "Success" : "Error",
                 message: result.message)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Drive Detail View
struct DriveDetailView: View {
    let drive: DriveInfo
    @ObservedObject var driveManager: DriveManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: drive.isEFI ? "memorychip" : (drive.isInternal ? "internaldrive.fill" : "externaldrive.fill"))
                    .font(.largeTitle)
                    .foregroundColor(drive.isEFI ? .purple : (drive.isInternal ? .blue : .orange))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Text(drive.identifier)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(drive.size)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Mount Status Badge
                if drive.isMounted {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Mounted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                } else {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("Unmounted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            
            Divider()
            
            // Drive Info
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Type:", value: drive.type)
                InfoRow(label: "Internal:", value: drive.isInternal ? "Yes" : "No")
                InfoRow(label: "EFI:", value: drive.isEFI ? "Yes" : "No")
                InfoRow(label: "Mount Point:", value: drive.mountPoint.isEmpty ? "Not mounted" : drive.mountPoint)
                
                if let currentDrive = driveManager.getDriveBy(id: drive.identifier) {
                    InfoRow(label: "Selected for Mount:", value: currentDrive.isSelectedForMount ? "Yes" : "No")
                    InfoRow(label: "Selected for Unmount:", value: currentDrive.isSelectedForUnmount ? "Yes" : "No")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Mount/Unmount Toggle
                if let currentDrive = driveManager.getDriveBy(id: drive.identifier) {
                    
                    if drive.isMounted {
                        // Only show unmount option for non-system volumes
                        if !drive.mountPoint.contains("/System/Volumes/") &&
                           drive.mountPoint != "/" &&
                           !drive.mountPoint.contains("home") &&
                           !drive.mountPoint.contains("private/var") &&
                           !drive.mountPoint.contains("Library/Developer") {
                            
                            Button(action: {
                                driveManager.toggleUnmountSelection(for: currentDrive)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: currentDrive.isSelectedForUnmount ? "eject.circle.fill" : "eject.circle")
                                    Text(currentDrive.isSelectedForUnmount ? "Deselect Unmount" : "Select to Unmount")
                                }
                                .frame(minWidth: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(currentDrive.isSelectedForUnmount ? .orange : .blue)
                        } else {
                            Text("System Volume")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 180)
                        }
                    } else {
                        Button(action: {
                            driveManager.toggleMountSelection(for: currentDrive)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: currentDrive.isSelectedForMount ? "play.circle.fill" : "play.circle")
                                Text(currentDrive.isSelectedForMount ? "Deselect Mount" : "Select to Mount")
                            }
                            .frame(minWidth: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(currentDrive.isSelectedForMount ? .green : .blue)
                    }
                }
                
                Button("Show in Finder") {
                    showInFinder()
                }
                .buttonStyle(.bordered)
                .disabled(!drive.isMounted || drive.mountPoint.isEmpty)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func showInFinder() {
        guard !drive.mountPoint.isEmpty else { return }
        
        let url = URL(fileURLWithPath: drive.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Preview
struct DriveManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DriveManagementView()
            .frame(width: 1200, height: 800)
    }
}