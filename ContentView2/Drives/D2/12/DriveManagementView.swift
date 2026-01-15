import SwiftUI
import AppKit

struct DriveManagementView: View {
    @StateObject private var driveManager = DriveManager.shared
    @State private var showEFIToggle = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main Content
            if driveManager.isLoading {
                loadingView
            } else if driveManager.allDrives.isEmpty {
                emptyStateView
            } else {
                drivesListView
            }
            
            Divider()
            
            // Footer
            footerView
            
            // Donation & Credits Footer
            donationFooterView
        }
        .frame(minWidth: 900, minHeight: 700)
        .alert("Drive Manager", isPresented: $driveManager.showAlert) {
            Button("OK") { }
        } message: {
            Text(driveManager.alertMessage)
        }
        .onAppear {
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
                Text("Manage all drives including EFI partitions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Debug Button
            Button(action: {
                driveManager.testEFIDetection()
            }) {
                Label("Debug", systemImage: "ladybug")
            }
            .buttonStyle(.bordered)
            .help("Test EFI detection")
            
            // EFI Toggle
            Toggle("Show EFI", isOn: $showEFIToggle)
                .toggleStyle(.switch)
                .onChange(of: showEFIToggle) { oldValue, newValue in
                    driveManager.showEFIDrives = newValue
                    driveManager.refreshDrives()
                }
                .help("Show/Hide EFI partitions")
            
            // Refresh Button
            Button(action: {
                driveManager.refreshDrives()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(driveManager.isLoading)
        }
        .padding()
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning system for drives...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Drives Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try enabling 'Show EFI' or click Debug to test")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Debug Detection") {
                driveManager.testEFIDetection()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Drives List View
    private var drivesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // EFI Partitions Section
                let efiDrives = driveManager.allDrives.filter { $0.isEFI }
                if !efiDrives.isEmpty {
                    SectionHeader(
                        title: "EFI Partitions (\(efiDrives.count))",
                        icon: "lock.shield.fill",
                        color: .purple
                    )
                    
                    ForEach(efiDrives) { drive in
                        DriveCard(drive: drive)
                            .environmentObject(driveManager)
                    }
                }
                
                // Mounted Drives Section
                let mountedDrives = driveManager.allDrives.filter { $0.isMounted && !$0.isEFI }
                if !mountedDrives.isEmpty {
                    SectionHeader(
                        title: "Mounted Drives (\(mountedDrives.count))",
                        icon: "externaldrive.fill.badge.checkmark",
                        color: .green
                    )
                    
                    ForEach(mountedDrives) { drive in
                        DriveCard(drive: drive)
                            .environmentObject(driveManager)
                    }
                }
                
                // Unmounted Drives Section
                let unmountedDrives = driveManager.allDrives.filter { !$0.isMounted && !$0.isEFI }
                if !unmountedDrives.isEmpty {
                    SectionHeader(
                        title: "Unmounted Drives (\(unmountedDrives.count))",
                        icon: "externaldrive.fill.badge.xmark",
                        color: .orange
                    )
                    
                    ForEach(unmountedDrives) { drive in
                        DriveCard(drive: drive)
                            .environmentObject(driveManager)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            // Drive Statistics
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    StatBadge(
                        count: driveManager.allDrives.count,
                        label: "Total",
                        color: .blue
                    )
                    
                    StatBadge(
                        count: driveManager.allDrives.filter { $0.isEFI }.count,
                        label: "EFI",
                        color: .purple
                    )
                    
                    StatBadge(
                        count: driveManager.allDrives.filter { $0.isMounted }.count,
                        label: "Mounted",
                        color: .green
                    )
                    
                    StatBadge(
                        count: driveManager.mountSelection.count,
                        label: "To Mount",
                        color: .blue
                    )
                    
                    StatBadge(
                        count: driveManager.unmountSelection.count,
                        label: "To Unmount",
                        color: .orange
                    )
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 10) {
                Button("Select All Unmount") {
                    driveManager.selectAllForUnmount()
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.allDrives.filter { $0.isMounted && $0.canUnmount }.isEmpty)
                
                Button("Clear All") {
                    driveManager.clearAllSelections()
                }
                .buttonStyle(.bordered)
                .disabled(driveManager.mountSelection.isEmpty && driveManager.unmountSelection.isEmpty)
                
                Divider()
                    .frame(height: 20)
                
                Button("Mount Selected") {
                    let _ = driveManager.mountSelectedDrives()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(driveManager.mountSelection.isEmpty)
                
                Button("Unmount Selected") {
                    let _ = driveManager.unmountSelectedDrives()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(driveManager.unmountSelection.isEmpty)
                
                Divider()
                    .frame(height: 20)
                
                Menu {
                    Button("Mount All External") {
                        let _ = driveManager.mountAllExternal()
                    }
                    
                    Button("Unmount All External") {
                        let _ = driveManager.unmountAllExternal()
                    }
                    
                    Divider()
                    
                    Button("Refresh") {
                        driveManager.refreshDrives()
                    }
                    
                    Button("Debug") {
                        driveManager.testEFIDetection()
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
    
    // MARK: - Donation Footer View
    private var donationFooterView: some View {
        VStack(spacing: 6) {
            Divider()
            
            HStack {
                // Developer Credits
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drive Manager")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Developed by Navaratnam Manoranjan")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("nmano0006@gmail.com")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            if let url = URL(string: "mailto:nmano0006@gmail.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                }
                
                Spacer()
                
                // Donation Button
                Button(action: {
                    if let url = URL(string: "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+my+open-source+development+work.+Donations+help+fund+testing+devices%2C+server+costs%2C+and+ongoing+maintenance+for+all+my+projects.&currency_code=CAD") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                        Text("Support Development")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.pink.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Click to donate via PayPal")
                
                // Version Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Open Source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Free to use")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Spacer()
            
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Drive Card
struct DriveCard: View {
    let drive: DriveInfo
    @EnvironmentObject var driveManager: DriveManager
    
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
                    
                    // Badges
                    if drive.isEFI {
                        BadgeView(text: "EFI", color: .purple)
                    }
                    
                    if drive.isInternal && !drive.isEFI {
                        BadgeView(text: "Internal", color: .blue)
                    }
                    
                    if !drive.isInternal && !drive.isEFI {
                        BadgeView(text: "External", color: .orange)
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
                    Button(action: {
                        driveManager.toggleMountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForMount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(drive.isSelectedForMount ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForMount ? "Deselect for mounting" : "Select for mounting")
                }
                
                // Unmount Selection
                if drive.isMounted && drive.canUnmount {
                    Button(action: {
                        driveManager.toggleUnmountSelection(for: drive)
                    }) {
                        Image(systemName: drive.isSelectedForUnmount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(drive.isSelectedForUnmount ? .orange : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(drive.isSelectedForUnmount ? "Deselect for unmounting" : "Select for unmounting")
                }
                
                // Quick Action Button
                if drive.canMount || drive.canUnmount {
                    Button(action: {
                        if drive.isMounted {
                            driveManager.toggleUnmountSelection(for: drive)
                        } else {
                            driveManager.toggleMountSelection(for: drive)
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
                    .tint(drive.isMounted ? .orange : .green)
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

// MARK: - Badge View
struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Preview
struct DriveManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DriveManagementView()
    }
}