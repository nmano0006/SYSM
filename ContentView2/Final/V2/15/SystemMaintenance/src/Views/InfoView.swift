import SwiftUI

struct InfoView: View {
    @State private var appVersion = "1.0.0"
    @State private var buildNumber = "1"
    @State private var copyrightYear = "2024"
    @State private var systemReport = ""
    @State private var isLoadingReport = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // App Header
                AppHeaderView
                
                // Developer Information Section
                DeveloperInfoSection
                
                // Quick Stats
                QuickStatsView
                
                // Donate Section
                DonateSection
                
                // System Report
                SystemReportView
                
                // Links and Support
                LinksView
                
                // Credits
                CreditsView
            }
            .padding()
        }
        .onAppear {
            loadAppInfo()
        }
    }
    
    // MARK: - Developer Information Section
    private var DeveloperInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Developer Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Small author badge
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    
                    Text("By: N. Manoranjan")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                )
            }
            
            // Enhanced Author View
            EnhancedAuthorCardView()
                .frame(maxWidth: .infinity)
            
            // Additional developer notes
            VStack(alignment: .leading, spacing: 8) {
                Text("About the Developer")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("This app is developed and maintained by Navaratnam Manoranjan, an experienced macOS developer specializing in system utilities, OpenCore configurations, and Hackintosh solutions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                HStack(spacing: 16) {
                    // Contact button
                    Button(action: {
                        if let url = URL(string: "mailto:nmano0006@gmail.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                            Text("Contact")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // GitHub button
                    Button(action: {
                        if let url = URL(string: "https://github.com/nmano") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.caption)
                            Text("GitHub")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // Enhanced Author Card View (replaces EnhancedAuthorView)
    private func EnhancedAuthorCardView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Navaratnam Manoranjan")
                        .font(.title3.weight(.bold))
                    
                    Text("Lead Developer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Version badge
                Text("v2.7.8.1.0")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Contact info
            VStack(alignment: .leading, spacing: 8) {
                ContactRow(icon: "envelope.fill", text: "nmano0006@gmail.com", isEmail: true)
                ContactRow(icon: "chevron.left.forwardslash.chevron.right", text: "github.com/nmano", isLink: true)
            }
            
            // Copyright notice
            Text("© \(Calendar.current.component(.year, from: Date())) Navaratnam Manoranjan")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Contact Row component
    private func ContactRow(icon: String, text: String, isEmail: Bool = false, isLink: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isEmail || isLink ? .blue : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isEmail || isLink {
                Button(action: {
                    if isEmail {
                        // Open email client
                        if let url = URL(string: "mailto:\(text)") {
                            NSWorkspace.shared.open(url)
                        }
                    } else if isLink {
                        // Open website
                        let urlString = text.hasPrefix("http") ? text : "https://\(text)"
                        if let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var AppHeaderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear.badge")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("SystemMaintenance")
                .font(.largeTitle)
                    .fontWeight(.bold)
            
            Text("Version \(appVersion) (Build \(buildNumber))")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Advanced macOS System Management Tool")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
    }
    
    private var QuickStatsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick System Stats")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Drives", value: "\(DriveManager.shared.allDrives.count)", icon: "externaldrive", color: .blue)
                StatCard(title: "Memory", value: getMemoryUsage(), icon: "memorychip", color: .green)
                StatCard(title: "CPU", value: getCPUUsage(), icon: "cpu", color: .orange)
                StatCard(title: "Network", value: "Active", icon: "network", color: .purple)
                StatCard(title: "Audio", value: "Ready", icon: "speaker.wave.2", color: .red)
                StatCard(title: "Kexts", value: "Loaded", icon: "puzzlepiece", color: .teal)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var DonateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support Development")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Donate Card
                Button(action: {
                    openDonateLink()
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Donate via PayPal")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Support open-source development")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                // Benefits list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Donations help fund:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        BenefitItem(icon: "laptopcomputer", text: "Testing devices")
                        BenefitItem(icon: "server.rack", text: "Server costs")
                        BenefitItem(icon: "hammer.fill", text: "Maintenance")
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var SystemReportView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("System Report")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: generateSystemReport) {
                    Label("Generate", systemImage: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingReport)
            }
            
            if isLoadingReport {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating system report...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if !systemReport.isEmpty {
                ScrollView {
                    Text(systemReport)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var LinksView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Links & Support")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                LinkButton(title: "Documentation", icon: "book", url: "https://example.com/docs")
                LinkButton(title: "GitHub Repository", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/example/systemmaintenance")
                LinkButton(title: "Report Issue", icon: "exclamationmark.triangle", url: "https://github.com/example/systemmaintenance/issues")
                LinkButton(title: "Check for Updates", icon: "arrow.triangle.2.circlepath", action: checkForUpdates)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var CreditsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credits")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Simple Author Info View at the bottom
            SimpleAuthorInfoView()
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Developed with ❤️ for the macOS community")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Copyright © \(copyrightYear) Navaratnam Manoranjan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("All rights reserved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // Simple Author Info View
    private func SimpleAuthorInfoView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title section
            HStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text("OpenCore Configurator")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Name section
            HStack {
                Text("Developer:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Navaratnam Manoranjan")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.leading, 20)
            
            // Email section
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Text("nmano0006@gmail.com")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Optional copy button
                Button(action: {
                    copyToClipboard("nmano0006@gmail.com")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Copy email")
            }
            .padding(.leading, 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // You could add feedback here (like a toast notification)
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    // MARK: - Helper Views
    
    private func StatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func BenefitItem(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func LinkButton(title: String, icon: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func LinkButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func openDonateLink() {
        let donateURL = "https://www.paypal.com/donate/?business=H3PV9HX92AVMJ&no_recurring=0&item_name=Support+my+open-source+development+work.+Donations+help+fund+testing+devices%2C+server+costs%2C+and+ongoing+maintenance+for+all+my+projects.&currency_code=CAD"
        
        if let url = URL(string: donateURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func loadAppInfo() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        copyrightYear = formatter.string(from: Date())
    }
    
    private func getMemoryUsage() -> String {
        let memory = ShellHelper.runCommand("sysctl -n hw.memsize").output
        if let memBytes = UInt64(memory), memBytes > 0 {
            let memGB = Double(memBytes) / 1_073_741_824.0
            return String(format: "%.1f GB", memGB)
        }
        return "Unknown"
    }
    
    private func getCPUUsage() -> String {
        let cpuUsage = ShellHelper.runCommand("ps -A -o %cpu | awk '{s+=$1} END {print s}'").output
        if let usage = Double(cpuUsage) {
            return String(format: "%.1f%%", usage)
        }
        return "0%"
    }
    
    private func generateSystemReport() {
        isLoadingReport = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var report = "=== SystemMaintenance Report ===\n\n"
            report += "Generated: \(Date())\n"
            report += "App Version: \(self.appVersion) (Build \(self.buildNumber))\n"
            report += "Developer: Navaratnam Manoranjan\n"
            report += "Developer Email: nmano0006@gmail.com\n\n"
            
            // System Info
            report += "=== System Information ===\n"
            let systemInfo = [
                ("Computer Name", ShellHelper.runCommand("scutil --get ComputerName").output),
                ("Model", ShellHelper.runCommand("sysctl -n hw.model").output),
                ("Processor", ShellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output),
                ("Cores", ShellHelper.runCommand("sysctl -n hw.ncpu").output),
                ("Memory", ShellHelper.runCommand("sysctl -n hw.memsize").output),
                ("macOS Version", ShellHelper.runCommand("sw_vers -productVersion").output),
                ("Build Number", ShellHelper.runCommand("sw_vers -buildVersion").output),
                ("Kernel Version", ShellHelper.runCommand("uname -r").output),
                ("SIP Status", ShellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output)
            ]
            
            for (label, value) in systemInfo {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                report += "\(label): \(trimmedValue.isEmpty ? "Unknown" : trimmedValue)\n"
            }
            
            // Security Info
            report += "\n=== Security Status ===\n"
            report += "Full Disk Access: \(ShellHelper.checkFullDiskAccess() ? "✅ Granted" : "❌ Not Granted")\n"
            report += "SIP: \(ShellHelper.isSIPDisabled() ? "❌ Disabled" : "✅ Enabled")\n"
            
            // Drive Info
            report += "\n=== Drive Information ===\n"
            let drives = DriveManager.shared.allDrives
            report += "Total Drives: \(drives.count)\n"
            for (index, drive) in drives.enumerated() {
                report += "\(index + 1). \(drive.name) (\(drive.identifier)) - \(drive.type)\n"
                report += "   Size: \(drive.size), Mounted: \(drive.isMounted ? "Yes" : "No")\n"
                if drive.isMounted {
                    report += "   Mount Point: \(drive.mountPoint)\n"
                }
            }
            
            // Developer info footer
            report += "\n=== Developer Information ===\n"
            report += "Name: Navaratnam Manoranjan\n"
            report += "Role: Lead Developer\n"
            report += "Email: nmano0006@gmail.com\n"
            report += "GitHub: github.com/nmano\n"
            
            DispatchQueue.main.async {
                self.systemReport = report
                self.isLoadingReport = false
            }
        }
    }
    
    private func checkForUpdates() {
        systemReport = "Update check functionality would be implemented here.\n\nThis would typically:\n1. Connect to update server\n2. Compare versions\n3. Download if newer version available\n4. Install update"
    }
}