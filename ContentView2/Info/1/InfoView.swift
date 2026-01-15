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
                
                // Quick Stats
                QuickStatsView
                
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Developed with ❤️ for the Hackintosh community")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Copyright © \(copyrightYear) SystemMaintenance")
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
    
    private func loadAppInfo() {
        // Get app version from Info.plist
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
        
        // Get current year
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        copyrightYear = formatter.string(from: Date())
    }
    
    private func getMemoryUsage() -> String {
        let shellHelper = ShellHelper.shared
        let memory = shellHelper.runCommand("sysctl -n hw.memsize").output
        if let memBytes = UInt64(memory), memBytes > 0 {
            let memGB = Double(memBytes) / 1_073_741_824.0
            return String(format: "%.1f GB", memGB)
        }
        return "Unknown"
    }
    
    private func getCPUUsage() -> String {
        let shellHelper = ShellHelper.shared
        let cpuUsage = shellHelper.runCommand("ps -A -o %cpu | awk '{s+=$1} END {print s}'").output
        if let usage = Double(cpuUsage) {
            return String(format: "%.1f%%", usage)
        }
        return "0%"
    }
    
    private func generateSystemReport() {
        isLoadingReport = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let shellHelper = ShellHelper.shared
            
            var report = "=== SystemMaintenance Report ===\n\n"
            report += "Generated: \(Date())\n"
            report += "App Version: \(self.appVersion) (Build \(self.buildNumber))\n\n"
            
            // System Info
            report += "=== System Information ===\n"
            let systemInfo = [
                ("Computer Name", shellHelper.runCommand("scutil --get ComputerName").output),
                ("Model", shellHelper.runCommand("sysctl -n hw.model").output),
                ("Processor", shellHelper.runCommand("sysctl -n machdep.cpu.brand_string").output),
                ("Cores", shellHelper.runCommand("sysctl -n hw.ncpu").output),
                ("Memory", shellHelper.runCommand("sysctl -n hw.memsize").output),
                ("macOS Version", shellHelper.runCommand("sw_vers -productVersion").output),
                ("Build Number", shellHelper.runCommand("sw_vers -buildVersion").output),
                ("Kernel Version", shellHelper.runCommand("uname -r").output),
                ("SIP Status", shellHelper.runCommand("csrutil status 2>/dev/null || echo 'Unknown'").output)
            ]
            
            for (label, value) in systemInfo {
                report += "\(label): \(value.isEmpty ? "Unknown" : value)\n"
            }
            
            // Drive Info
            report += "\n=== Drive Information ===\n"
            let drives = DriveManager.shared.allDrives
            report += "Total Drives: \(drives.count)\n"
            report += "Mounted: \(drives.filter { $0.isMounted }.count)\n"
            for drive in drives {
                report += "\n• \(drive.name)\n"
                report += "  ID: \(drive.identifier)\n"
                report += "  Size: \(drive.size)\n"
                report += "  Type: \(drive.type)\n"
                report += "  Mounted: \(drive.isMounted ? "Yes (\(drive.mountPoint))" : "No")\n"
            }
            
            // Network Info
            report += "\n=== Network Information ===\n"
            let networkInfo = [
                ("Hostname", shellHelper.runCommand("hostname").output),
                ("IP Address", shellHelper.runCommand("ipconfig getifaddr en0").output),
                ("MAC Address", shellHelper.runCommand("ifconfig en0 | grep ether | awk '{print $2}'").output)
            ]
            
            for (label, value) in networkInfo {
                report += "\(label): \(value.isEmpty ? "Unknown" : value)\n"
            }
            
            DispatchQueue.main.async {
                self.systemReport = report
                self.isLoadingReport = false
            }
        }
    }
    
    private func checkForUpdates() {
        // Placeholder for update checking logic
        let shellHelper = ShellHelper.shared
        _ = shellHelper.runCommand("echo 'Update check would run here'")
        
        // In a real app, you would:
        // 1. Check a remote URL for latest version
        // 2. Compare with current version
        // 3. Show update dialog if needed
        
        systemReport = "Update check functionality would be implemented here.\n\nThis would typically:\n1. Connect to update server\n2. Compare versions\n3. Download if newer version available\n4. Install update"
    }
}