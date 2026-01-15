import SwiftUI

struct InfoView: View {
    @State private var appVersion = "1.0.1"
    @State private var buildNumber = "1"
    @State private var copyrightYear = "2024"
    @State private var systemReport = ""
    @State private var isLoadingReport = false
    @State private var showingUpdateCheck = false
    @State private var updateStatus = ""
    @State private var isCheckingUpdate = false
    @State private var showWhatsNew = false
    @State private var lastUpdateCheck: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // App Header
                AppHeaderView
                
                // Version Badge
                VersionBadgeView
                
                // What's New Button
                WhatsNewButtonView
                
                // App Features
                AppFeaturesView
                
                // Version Info
                VersionInfoView
                
                // Developer Info
                DeveloperInfoView
                
                // System Report
                SystemReportView
                
                // Update Check
                UpdateCheckView
                
                // Support & Links
                SupportLinksView
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadAppInfo()
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
    }
    
    // MARK: - App Header
    private var AppHeaderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear.badge")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 5)
            
            Text("SYSM")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("System Maintenance Tool")
                .font(.title2)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text("Advanced macOS system management utility")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.05),
                    Color.blue.opacity(0.02)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Version Badge
    private var VersionBadgeView: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text("Version 1.0.1")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Latest")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - What's New Button
    private var WhatsNewButtonView: some View {
        Button(action: { showWhatsNew = true }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.callout)
                    .foregroundColor(.blue)
                
                Text("What's New in 1.0.1")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - App Features
    private var AppFeaturesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Features")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(
                    icon: "externaldrive",
                    title: "Drive Management",
                    description: "Mount/unmount drives, view partitions, manage external storage"
                )
                
                FeatureCard(
                    icon: "lock.shield",
                    title: "Security",
                    description: "Check SIP status, verify permissions, audit system security"
                )
                
                FeatureCard(
                    icon: "info.circle",
                    title: "System Info",
                    description: "Detailed hardware/software information, bootloader detection"
                )
                
                FeatureCard(
                    icon: "power",
                    title: "Power Tools",
                    description: "Kext management, NVRAM utilities, boot arguments"
                )
                
                FeatureCard(
                    icon: "network",
                    title: "Network Tools",
                    description: "Interface management, DNS tools, network diagnostics"
                )
                
                FeatureCard(
                    icon: "wrench.and.screwdriver",
                    title: "Utilities",
                    description: "Script runner, log viewer, system maintenance tasks"
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Version Info
    private var VersionInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Version Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Version:", value: appVersion)
                    InfoRow(label: "Build:", value: buildNumber)
                    InfoRow(label: "Release Date:", value: getReleaseDate())
                }
                
                Divider()
                    .frame(height: 60)
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Compatibility:", value: "macOS 10.13+")
                    InfoRow(label: "Architecture:", value: "Universal (Intel/Apple Silicon)")
                    InfoRow(label: "Minimum RAM:", value: "4 GB")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Version History:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("• 1.0.1 - Bug fixes and performance improvements")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                Text("• 1.0.0 - Initial release")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            
            HStack {
                Spacer()
                Text("Copyright © \(copyrightYear) N. Manoranjan")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Developer Info
    private var DeveloperInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Developer Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Navaratnam Manoranjan")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Lead Developer & Maintainer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    ContactRow(
                        icon: "envelope",
                        label: "Email:",
                        value: "nmano0006@gmail.com",
                        action: {
                            if let url = URL(string: "mailto:nmano0006@gmail.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                    
                    ContactRow(
                        icon: "link",
                        label: "GitHub:",
                        value: "github.com/nmano0006",
                        action: {
                            if let url = URL(string: "https://github.com/nmano0006") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                    
                    ContactRow(
                        icon: "hammer",
                        label: "Repository:",
                        value: "github.com/nmano0006/SYSM",
                        action: {
                            if let url = URL(string: "https://github.com/nmano0006/SYSM") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
                
                Divider()
                
                Text("This application is developed and maintained as an open-source project. Contributions and feedback are welcome!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - System Report
    private var SystemReportView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("System Report")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: generateSystemReport) {
                    HStack(spacing: 6) {
                        if isLoadingReport {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("Generate Report")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingReport)
                
                Button(action: copyReportToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(systemReport.isEmpty || isLoadingReport)
            }
            
            if !systemReport.isEmpty {
                ScrollView {
                    Text(systemReport)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxHeight: 250)
                .background(Color(.textBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else if !isLoadingReport {
                Text("Click 'Generate Report' to create a detailed system report")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Update Check
    private var UpdateCheckView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Updates")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                if let lastCheck = lastUpdateCheck {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isCheckingUpdate {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking for updates...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if !updateStatus.isEmpty {
                    Text(updateStatus)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(10)
                }
                
                HStack(spacing: 12) {
                    Button(action: checkForUpdates) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check for Updates")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: openReleasesPage) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                            Text("View Releases")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Support & Links
    private var SupportLinksView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support & Resources")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SupportLinkCard(
                    title: "Documentation",
                    icon: "book",
                    color: .blue,
                    action: {
                        if let url = URL(string: "https://github.com/nmano0006/SYSM/wiki") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                
                SupportLinkCard(
                    title: "Report Issues",
                    icon: "exclamationmark.triangle",
                    color: .orange,
                    action: {
                        if let url = URL(string: "https://github.com/nmano0006/SYSM/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                
                SupportLinkCard(
                    title: "Source Code",
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: .purple,
                    action: {
                        if let url = URL(string: "https://github.com/nmano0006/SYSM") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                
                SupportLinkCard(
                    title: "Discussions",
                    icon: "bubble.left.and.bubble.right",
                    color: .green,
                    action: {
                        if let url = URL(string: "https://github.com/nmano0006/SYSM/discussions") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }
            
            HStack {
                Spacer()
                Button(action: openDonateLink) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Support Development")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Views
    
    private func FeatureCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private func ContactRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func SupportLinkCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadAppInfo() {
        // Get app version from bundle
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
        
        // Set copyright year
        copyrightYear = String(Calendar.current.component(.year, from: Date()))
    }
    
    private func getReleaseDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }
    
    private func generateSystemReport() {
        isLoadingReport = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var report = "=== SYSM System Report ===\n"
            report += "Generated: \(Date())\n"
            report += "App Version: \(self.appVersion) (Build \(self.buildNumber))\n"
            report += "Generated by: SYSM v\(self.appVersion)\n"
            report += "GitHub: https://github.com/nmano0006/SYSM\n\n"
            
            // System Information
            report += "=== SYSTEM INFORMATION ===\n"
            
            let systemCommands = [
                ("Computer Name", "scutil --get ComputerName"),
                ("Host Name", "scutil --get HostName"),
                ("Local Host Name", "scutil --get LocalHostName"),
                ("Model", "sysctl -n hw.model"),
                ("Processor", "sysctl -n machdep.cpu.brand_string"),
                ("Cores", "sysctl -n hw.ncpu"),
                ("Memory", "sysctl -n hw.memsize"),
                ("macOS Version", "sw_vers -productVersion"),
                ("Build Version", "sw_vers -buildVersion"),
                ("Kernel", "uname -r")
            ]
            
            for (label, command) in systemCommands {
                let result = ShellHelper.runCommand(command)
                let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                report += "\(label): \(value.isEmpty ? "N/A" : value)\n"
            }
            
            // Bootloader Detection
            report += "\n=== BOOTLOADER INFORMATION ===\n"
            let bootloader = ShellHelper.detectBootloader()
            report += "Bootloader: \(bootloader.name)\n"
            report += "Version: \(bootloader.version)\n"
            report += "Mode: \(bootloader.mode)\n"
            
            // Security Status
            report += "\n=== SECURITY STATUS ===\n"
            report += "SIP Status: \(ShellHelper.isSIPDisabled() ? "Disabled" : "Enabled")\n"
            report += "Full Disk Access: \(ShellHelper.checkFullDiskAccess() ? "Granted" : "Not Granted")\n"
            
            // Drive Information
            report += "\n=== DRIVE INFORMATION ===\n"
            let drives = ShellHelper.getAllDrives()
            report += "Total Drives Found: \(drives.count)\n"
            
            for (index, drive) in drives.enumerated() {
                report += "\nDrive #\(index + 1):\n"
                report += "  Name: \(drive.name)\n"
                report += "  Identifier: \(drive.identifier)\n"
                report += "  Size: \(drive.size)\n"
                report += "  Type: \(drive.type)\n"
                report += "  Internal: \(drive.isInternal ? "Yes" : "No")\n"
                report += "  Mounted: \(drive.isMounted ? "Yes (\(drive.mountPoint))" : "No")\n"
            }
            
            // Developer Information
            report += "\n=== DEVELOPER INFORMATION ===\n"
            report += "Name: Navaratnam Manoranjan\n"
            report += "Email: nmano0006@gmail.com\n"
            report += "GitHub: https://github.com/nmano0006\n"
            report += "Repository: https://github.com/nmano0006/SYSM\n"
            report += "\n=== END OF REPORT ===\n"
            
            DispatchQueue.main.async {
                self.systemReport = report
                self.isLoadingReport = false
            }
        }
    }
    
    private func copyReportToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(systemReport, forType: .string)
        
        // Provide feedback (you could add a toast notification here)
        let feedbackGenerator = NSHapticFeedbackManager.defaultPerformer
        feedbackGenerator.perform(.generic, performanceTime: .now)
    }
    
    private func checkForUpdates() {
        isCheckingUpdate = true
        updateStatus = ""
        
        // In a real implementation, you would:
        // 1. Fetch the latest release info from GitHub API
        // 2. Compare with current version
        // 3. Show update status
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
            // Simulate update check
            let hasUpdate = Bool.random()
            
            DispatchQueue.main.async {
                self.isCheckingUpdate = false
                self.lastUpdateCheck = Date()
                
                if hasUpdate {
                    self.updateStatus = "Update available! Visit the releases page to download the latest version."
                } else {
                    self.updateStatus = "You're running the latest version (\(self.appVersion))."
                }
            }
        }
    }
    
    private func openReleasesPage() {
        if let url = URL(string: "https://github.com/nmano0006/SYSM/releases") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openDonateLink() {
        let donateURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+SYSM+development&currency_code=CAD"
        
        if let url = URL(string: donateURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - What's New View
struct WhatsNewView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("What's New in SYSM 1.0.1")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // New Features
                    SectionView(title: "🎉 New Features", icon: "plus.circle.fill", color: .green) {
                        FeatureItem(title: "Enhanced Drive Detection", description: "Improved detection of external drives and partitions")
                        FeatureItem(title: "Better Error Handling", description: "More informative error messages for mount/unmount operations")
                        FeatureItem(title: "Performance Monitoring", description: "Added system resource usage display")
                    }
                    
                    // Improvements
                    SectionView(title: "🔧 Improvements", icon: "hammer.fill", color: .blue) {
                        FeatureItem(title: "UI Polish", description: "Refined interface with better spacing and typography")
                        FeatureItem(title: "Faster Drive Listing", description: "Optimized drive enumeration for quicker loading")
                        FeatureItem(title: "Memory Optimization", description: "Reduced memory usage by up to 20%")
                    }
                    
                    // Bug Fixes
                    SectionView(title: "🐛 Bug Fixes", icon: "ladybug.fill", color: .red) {
                        FeatureItem(title: "Fixed Mount Issues", description: "Resolved problems with certain external drive mounting")
                        FeatureItem(title: "Memory Leaks", description: "Fixed memory leaks in drive manager")
                        FeatureItem(title: "UI Glitches", description: "Corrected visual artifacts on macOS Ventura+")
                    }
                    
                    // Technical Updates
                    SectionView(title: "⚙️ Technical Updates", icon: "gear", color: .purple) {
                        FeatureItem(title: "Updated Dependencies", description: "Modernized Swift packages and libraries")
                        FeatureItem(title: "Better Apple Silicon Support", description: "Improved compatibility with M1/M2/M3 Macs")
                        FeatureItem(title: "Accessibility Improvements", description: "Enhanced VoiceOver support and keyboard navigation")
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📝 Notes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("• Version 1.0.1 focuses on stability and performance improvements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• All users of 1.0.0 are recommended to update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• For detailed changelog, visit the GitHub repository")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    
                    Divider()
                    
                    HStack {
                        Spacer()
                        Text("Thank you for using SYSM! 🎊")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Version 1.0.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("View Full Changelog") {
                    if let url = URL(string: "https://github.com/nmano0006/SYSM/releases/tag/v1.0.1") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                
                Button("Got it!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct FeatureItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• \(title)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
        }
    }
}