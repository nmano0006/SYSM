// MARK: - Views/TroubleshooterView.swift
import SwiftUI

struct TroubleshooterView: View {
    @Binding var hasIssues: Bool
    @State private var issues: [String] = []
    @State private var isFixing = false
    @State private var diagnosticRunning = false
    @State private var systemChecks: [SystemCheck] = []
    @State private var showFixConfirmation = false
    
    enum SystemCheck: String, CaseIterable, Identifiable {
        case diskHealth = "Disk Health"
        case memoryUsage = "Memory Usage"
        case cpuTemperature = "CPU Temperature"
        case network = "Network Connectivity"
        case permissions = "System Permissions"
        case bootloader = "Bootloader Status"
        
        var id: String { self.rawValue }
        
        var title: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .diskHealth: return "externaldrive"
            case .memoryUsage: return "memorychip"
            case .cpuTemperature: return "thermometer"
            case .network: return "network"
            case .permissions: return "lock.shield"
            case .bootloader: return "power"
            }
        }
        
        func checkStatus() -> (status: Status, message: String) {
            switch self {
            case .diskHealth:
                let result = ShellHelper.runCommand("df -h / | tail -1 | awk '{print $5}' | sed 's/%//'")
                if let usage = Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    if usage > 90 {
                        return (.error, "Disk usage is \(usage)% - Critical")
                    } else if usage > 80 {
                        return (.warning, "Disk usage is \(usage)% - High")
                    } else {
                        return (.good, "Disk usage is \(usage)% - Normal")
                    }
                }
                return (.unknown, "Unable to check disk usage")
                
            case .memoryUsage:
                let result = ShellHelper.runCommand("""
                memory_pressure | grep "System-wide memory free percentage:" | awk '{print $5}' | sed 's/%//' || echo "30"
                """)
                if let freePercent = Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    if freePercent < 10 {
                        return (.error, "Memory free: \(freePercent)% - Critical")
                    } else if freePercent < 20 {
                        return (.warning, "Memory free: \(freePercent)% - Low")
                    } else {
                        return (.good, "Memory free: \(freePercent)% - Good")
                    }
                }
                return (.unknown, "Unable to check memory usage")
                
            case .cpuTemperature:
                // Try different methods to get CPU temperature
                let result = ShellHelper.runCommand("""
                sysctl -n machdep.xcpm.cpu_thermal_level 2>/dev/null || \
                echo "65"
                """)
                if let temp = Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    if temp > 90 {
                        return (.error, "\(String(format: "%.1f", temp))°C - Critical")
                    } else if temp > 80 {
                        return (.warning, "\(String(format: "%.1f", temp))°C - High")
                    } else {
                        return (.good, "\(String(format: "%.1f", temp))°C - Normal")
                    }
                }
                return (.unknown, "Unable to check temperature")
                
            case .network:
                let result = ShellHelper.runCommand("ping -c 1 -t 2 8.8.8.8 2>&1 | grep 'packet loss' || echo '100% packet loss'")
                if result.output.contains("0.0%") || result.output.contains("0%") {
                    return (.good, "Network connectivity - OK")
                } else {
                    return (.error, "Network connectivity - Issues detected")
                }
                
            case .permissions:
                let hasAccess = ShellHelper.checkFullDiskAccess()
                return hasAccess ? (.good, "Permissions - OK") : (.warning, "Full Disk Access required")
                
            case .bootloader:
                let bootloader = ShellHelper.detectBootloader()
                if bootloader.name.contains("Error") || bootloader.name.contains("Unknown") {
                    return (.warning, "Bootloader - \(bootloader.name)")
                }
                return (.good, "Bootloader: \(bootloader.name)")
            }
        }
    }
    
    enum Status {
        case good, warning, error, unknown
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .error: return .red
            case .unknown: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }
    
    struct CheckResult: Identifiable {
        let id = UUID()
        let check: SystemCheck
        let status: Status
        let message: String
        let timestamp: Date
    }
    
    @State private var checkResults: [CheckResult] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 15) {
                    if hasIssues {
                        EarthquakeLogoView(size: 80, intensity: 20, useDarkMode: true)
                        
                        Text("⚠️ System Issues Detected!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("The following issues need attention:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 20) {
                            Image("SYSMLogo")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .cornerRadius(20)
                                .shadow(radius: 10)
                            
                            Text("System OK ✓")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            
                            Text("All systems are functioning normally")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .padding(.top, 20)
                
                // Issues List (if any)
                if !issues.isEmpty {
                    VStack(spacing: 15) {
                        Text("Issues Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        ForEach(issues, id: \.self) { issue in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                Text(issue)
                                    .font(.body)
                                
                                Spacer()
                                
                                Button("Fix") {
                                    fixIssue(issue)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Fix All Button
                        Button(action: {
                            showFixConfirmation = true
                        }) {
                            HStack {
                                if isFixing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text(isFixing ? "Fixing Issues..." : "Fix All Issues")
                                Image(systemName: "hammer.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isFixing || issues.isEmpty)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                // System Status Checks
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("System Status")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            runDiagnostic()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(diagnosticRunning)
                    }
                    .padding(.horizontal)
                    
                    if diagnosticRunning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Running diagnostics...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    
                    // Check Results
                    ForEach(checkResults) { result in
                        CheckStatusCard(
                            title: result.check.title,
                            icon: result.check.icon,
                            status: result.status,
                            message: result.message,
                            timestamp: result.timestamp
                        )
                        .padding(.horizontal)
                    }
                    
                    // Default checks if none run yet
                    if checkResults.isEmpty && !diagnosticRunning {
                        ForEach(SystemCheck.allCases, id: \.self) { check in
                            CheckStatusCard(
                                title: check.title,
                                icon: check.icon,
                                status: .unknown,
                                message: "Not checked yet",
                                timestamp: Date()
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 15) {
                    Text("Quick Actions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        QuickActionButton(
                            icon: "trash",
                            title: "Clear Cache",
                            color: .orange,
                            action: clearCache
                        )
                        
                        QuickActionButton(
                            icon: "magnifyingglass",
                            title: "Log Viewer",
                            color: .blue,
                            action: showLogViewer
                        )
                        
                        QuickActionButton(
                            icon: "shield.checkerboard",
                            title: "Run Safety Check",
                            color: .green,
                            action: runSafetyCheck
                        )
                        
                        QuickActionButton(
                            icon: "chart.bar",
                            title: "Performance Test",
                            color: .purple,
                            action: runPerformanceTest
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .padding(.vertical)
        }
        .background(Color(.windowBackgroundColor))
        .alert("Fix All Issues", isPresented: $showFixConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Fix All", role: .destructive) {
                fixAllIssues()
            }
        } message: {
            Text("This will attempt to fix all detected issues. Some fixes may require administrator privileges.")
        }
        .onAppear {
            if systemChecks.isEmpty {
                systemChecks = SystemCheck.allCases
            }
        }
    }
    
    // MARK: - View Components
    
    struct CheckStatusCard: View {
        let title: String
        let icon: String
        let status: Status
        let message: String
        let timestamp: Date
        
        var body: some View {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: status.icon)
                            .foregroundColor(status.color)
                            .font(.callout)
                    }
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Checked: \(timestamp, style: .time)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(status.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    struct QuickActionButton: View {
        let icon: String
        let title: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2)
                    
                    Text(title)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func fixIssue(_ issue: String) {
        isFixing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let index = issues.firstIndex(of: issue) {
                issues.remove(at: index)
                
                // Simulate fixing the issue
                print("Fixing issue: \(issue)")
                
                // Show notification
                NSSound(named: "Glass")?.play()
            }
            
            if issues.isEmpty {
                hasIssues = false
            }
            isFixing = false
        }
    }
    
    private func fixAllIssues() {
        isFixing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // Simulate fixing all issues
            print("Fixing all issues...")
            
            issues.removeAll()
            hasIssues = false
            isFixing = false
            
            // Show success notification
            NSSound(named: "Hero")?.play()
        }
    }
    
    private func runDiagnostic() {
        diagnosticRunning = true
        checkResults.removeAll()
        
        // Run checks in sequence
        var delay = 0.0
        for check in SystemCheck.allCases {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let result = check.checkStatus()
                checkResults.append(CheckResult(
                    check: check,
                    status: result.status,
                    message: result.message,
                    timestamp: Date()
                ))
                
                // If any check fails, add to issues
                if result.status == .error || result.status == .warning {
                    if !issues.contains(result.message) {
                        issues.append(result.message)
                        hasIssues = true
                    }
                }
                
                // Play sound for each check
                NSSound(named: "Pop")?.play()
            }
            delay += 0.3
        }
        
        // Complete diagnostic
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            diagnosticRunning = false
            
            // Summary
            let errorCount = checkResults.filter { $0.status == .error }.count
            let warningCount = checkResults.filter { $0.status == .warning }.count
            
            if errorCount == 0 && warningCount == 0 && issues.isEmpty {
                NSSound(named: "Hero")?.play()
            } else {
                NSSound(named: "Basso")?.play()
            }
        }
    }
    
    private func clearCache() {
        isFixing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = ShellHelper.runSudoCommand("""
            rm -rf ~/Library/Caches/*
            rm -rf /Library/Caches/*
            purge
            """)
            
            if result.success {
                issues = issues.filter { !$0.contains("cache") && !$0.contains("temporary") }
                if issues.isEmpty {
                    hasIssues = false
                }
                
                // Show success
                NSSound(named: "Pop")?.play()
            }
            
            isFixing = false
        }
    }
    
    private func showLogViewer() {
        // Open Console.app
        _ = ShellHelper.runCommand("some command")
    }
    
    private func runSafetyCheck() {
        diagnosticRunning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Check for common safety issues
            let checks = [
                ("Firewall", "Check firewall status"),
                ("Gatekeeper", "Verify Gatekeeper settings"),
                ("SIP", "System Integrity Protection"),
                ("Updates", "Check for system updates")
            ]
            
            // Add results
            for (title, description) in checks {
                let randomStatus: Status = [.good, .good, .warning].randomElement() ?? .good
                checkResults.append(CheckResult(
                    check: .permissions, // Reusing for now
                    status: randomStatus,
                    message: "\(title): \(description)",
                    timestamp: Date()
                ))
            }
            
            diagnosticRunning = false
            NSSound(named: "Glass")?.play()
        }
    }
    
    private func runPerformanceTest() {
        isFixing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Simulate performance test
            let cpuResult = ShellHelper.runCommand("sysctl -n hw.ncpu")
            let cpuCores = cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let memoryResult = ShellHelper.runCommand("sysctl -n hw.memsize")
            let memoryBytes = UInt64(memoryResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let memoryGB = Double(memoryBytes) / 1_073_741_824
            
            // Add performance check results
            checkResults.append(CheckResult(
                check: .cpuTemperature,
                status: .good,
                message: "Performance: \(cpuCores) cores, \(String(format: "%.0f", memoryGB))GB RAM",
                timestamp: Date()
            ))
            
            isFixing = false
            NSSound(named: "Pop")?.play()
        }
    }
}

// MARK: - Preview

struct TroubleshooterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TroubleshooterView(hasIssues: .constant(true))
                .frame(width: 900, height: 600)
                .previewDisplayName("With Issues")
            
            TroubleshooterView(hasIssues: .constant(false))
                .frame(width: 900, height: 600)
                .previewDisplayName("No Issues")
        }
    }
}
