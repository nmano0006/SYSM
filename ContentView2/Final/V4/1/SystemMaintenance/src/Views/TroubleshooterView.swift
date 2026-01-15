import SwiftUI

struct TroubleshooterView: View {
    @Binding var hasIssues: Bool
    @State private var issues = ["Drive fragmentation detected", "Outdated kexts found", "Audio configuration needed"]
    @State private var isFixing = false
    @State private var showDeveloperInfo = false
    @State private var showEnhancedDeveloperInfo = false
    @State private var showContactOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if hasIssues {
                    VStack(spacing: 20) {
                        // Earthquake shaking logo
                        EarthquakeLogoView(size: 100, intensity: 25, useDarkMode: true)
                        
                        Text("⚠️ System Issues Detected!")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        
                        Text("The following issues need attention:")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        ForEach(issues, id: \.self) { issue in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(issue)
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
                        }
                        
                        Button(action: {
                            fixAllIssues()
                        }) {
                            HStack {
                                if isFixing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 12, height: 12)
                                }
                                Text(isFixing ? "Fixing Issues..." : "Fix All Issues")
                                Image(systemName: "hammer.fill")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isFixing)
                        .padding(.top, 20)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(15)
                } else {
                    VStack(spacing: 25) {
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
                        
                        Button("Run Diagnostic") {
                            runDiagnostic()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 20)
                    }
                    .padding(40)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(15)
                }
                
                // System status cards
                VStack(alignment: .leading, spacing: 15) {
                    Text("System Status")
                        .font(.title2)
                        .padding(.bottom, 5)
                    
                    StatusCard(title: "Disk Health", status: .warning, icon: "externaldrive")
                    StatusCard(title: "Memory Usage", status: .good, icon: "memorychip")
                    StatusCard(title: "CPU Temperature", status: .good, icon: "thermometer")
                    StatusCard(title: "Network", status: .error, icon: "network")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                .padding(.top, 20)
                
                // Enhanced Developer Information Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Troubleshooter Developer")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("SYSM Diagnostic Tool")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Version badge - UPDATED to 1.0.1
                        Text("v1.0.1")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        
                        // Updated badge to show latest version
                        Text("Latest")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        
                        Button(action: {
                            showDeveloperInfo.toggle()
                        }) {
                            Image(systemName: showDeveloperInfo ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .help(showDeveloperInfo ? "Collapse developer info" : "Expand developer info")
                    }
                    
                    if showDeveloperInfo {
                        Divider()
                        
                        // Main developer info with enhanced details
                        VStack(alignment: .leading, spacing: 15) {
                            // Developer header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Navaratnam Manoranjan")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Lead System Diagnostics Engineer")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    // Version info update
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                        Text("SYSM v1.0.1 - Latest Release")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showEnhancedDeveloperInfo.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: showEnhancedDeveloperInfo ? "info.circle.fill" : "info.circle")
                                        Text("Details")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Contact information
                            VStack(alignment: .leading, spacing: 8) {
                                ContactRowView(
                                    icon: "envelope.fill",
                                    text: "nmano0006@gmail.com",
                                    type: .email
                                )
                                
                                ContactRowView(
                                    icon: "calendar",
                                    text: "Project Started: 2024",
                                    type: .info
                                )
                                
                                ContactRowView(
                                    icon: "hammer.fill",
                                    text: "Specialization: macOS System Diagnostics",
                                    type: .info
                                )
                                
                                ContactRowView(
                                    icon: "star.fill",
                                    text: "Experience: 5+ years in macOS development",
                                    type: .info
                                )
                            }
                            .padding(.vertical, 8)
                            
                            // Enhanced details section
                            if showEnhancedDeveloperInfo {
                                EnhancedDeveloperDetailsView()
                            }
                            
                            // Action buttons
                            HStack(spacing: 15) {
                                Button(action: {
                                    sendEmailFeedback()
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "envelope.fill")
                                        Text("Email")
                                    }
                                    .frame(minWidth: 80)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button(action: {
                                    copyContactInfo()
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "doc.on.doc.fill")
                                        Text("Copy")
                                    }
                                    .frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button(action: {
                                    showContactOptions.toggle()
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: showContactOptions ? "ellipsis.circle.fill" : "ellipsis.circle")
                                        Text("More")
                                    }
                                    .frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 10)
                            
                            // Additional contact options
                            if showContactOptions {
                                AdditionalContactOptionsView()
                            }
                            
                            // Copyright notice
                            Text("© \(Calendar.current.component(.year, from: Date())) Navaratnam Manoranjan. All rights reserved.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.blue.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue.opacity(0.3), .blue.opacity(0.1)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.top, 20)
                
                // Version 1.0.1 Updates Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        Text("What's New in 1.0.1")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("Latest")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureUpdateItem(icon: "externaldrive.fill", text: "Enhanced drive detection and management")
                        FeatureUpdateItem(icon: "speedometer", text: "Improved diagnostic performance")
                        FeatureUpdateItem(icon: "ant.fill", text: "Bug fixes and stability improvements")
                        FeatureUpdateItem(icon: "hammer.fill", text: "Better troubleshooting algorithms")
                    }
                    
                    Button(action: {
                        showVersionDetails()
                    }) {
                        HStack(spacing: 4) {
                            Text("View All Changes")
                            Image(systemName: "arrow.right.circle")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(15)
                .padding(.top, 10)
                
                // Quick Help Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("Need Help?")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Text("The troubleshooter is designed to diagnose and fix common macOS system issues. Version 1.0.1 includes enhanced detection algorithms and improved user experience.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 10) {
                        Link(destination: URL(string: "https://github.com/nmano0006/SYSM")!) {
                            Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Link(destination: URL(string: "https://github.com/nmano0006/SYSM/discussions")!) {
                            Label("Community", systemImage: "person.3.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Link(destination: URL(string: "https://github.com/nmano0006/SYSM/issues")!) {
                            Label("Issues", systemImage: "exclamationmark.bubble.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 5)
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(10)
                .padding(.top, 10)
            }
            .padding()
        }
        .toolbar {
            // Add developer badge to toolbar
            ToolbarItem(placement: .navigation) {
                DeveloperToolbarBadgeView()
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct ContactRowView: View {
        enum ContactType {
            case email, phone, link, info
        }
        
        let icon: String
        let text: String
        let type: ContactType
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .foregroundColor(colorForType)
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if type == .email || type == .link {
                    Button(action: handleAction) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(colorForType)
                    }
                    .buttonStyle(.plain)
                    .help(type == .email ? "Send email" : "Open link")
                }
            }
            .padding(.vertical, 4)
        }
        
        private var colorForType: Color {
            switch type {
            case .email: return .blue
            case .phone: return .green
            case .link: return .purple
            case .info: return .orange
            }
        }
        
        private var textColor: Color {
            type == .info ? .primary : colorForType
        }
        
        private func handleAction() {
            switch type {
            case .email:
                let mailto = "mailto:\(text)"
                if let url = URL(string: mailto) {
                    NSWorkspace.shared.open(url)
                }
            case .link:
                let urlString = text.hasPrefix("http") ? text : "https://\(text)"
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            default:
                break
            }
        }
    }
    
    struct EnhancedDeveloperDetailsView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Developer Profile")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    DetailRow(icon: "graduationcap.fill", text: "Education: BSc in Computer Science")
                    DetailRow(icon: "location.fill", text: "Location: Colombo, Sri Lanka")
                    DetailRow(icon: "briefcase.fill", text: "Focus: macOS Kernel Extensions & Drivers")
                    DetailRow(icon: "wrench.and.screwdriver.fill", text: "Tools: Xcode, Swift, Objective-C")
                    DetailRow(icon: "network", text: "Expertise: OpenCore, Hackintosh, System Recovery")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                Text("The troubleshooter uses advanced diagnostic algorithms to identify and resolve system issues. Version 1.0.1 includes improved performance and enhanced drive management capabilities.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    struct DetailRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 20)
                    .foregroundColor(.blue)
                
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
    }
    
    struct AdditionalContactOptionsView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Additional Contact Options")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    Button(action: {
                        reportBug()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 18))
                            Text("Bug Report")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        requestFeature()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 18))
                            Text("Feature")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        showDonationOptions()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18))
                            Text("Support")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: {
                    copyDeveloperFullProfile()
                }) {
                    HStack {
                        Image(systemName: "person.text.rectangle.fill")
                        Text("Copy Full Developer Profile")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 5)
            }
            .padding()
            .background(Color.blue.opacity(0.03))
            .cornerRadius(10)
            .padding(.top, 10)
        }
        
        private func reportBug() {
            let email = "nmano0006@gmail.com"
            let subject = "[SYSM v1.0.1] Bug Report"
            let body = """
            Bug Report for SYSM Troubleshooter v1.0.1
            
            macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
            
            Issue Description:
            
            Steps to Reproduce:
            1. 
            2. 
            3. 
            
            Expected Behavior:
            
            Actual Behavior:
            
            Additional Notes:
            """
            
            let mailto = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            if let url = URL(string: mailto) {
                NSWorkspace.shared.open(url)
            }
        }
        
        private func requestFeature() {
            let email = "nmano0006@gmail.com"
            let subject = "[SYSM v1.0.1] Feature Request"
            let body = """
            Feature Request for SYSM Troubleshooter v1.0.1
            
            Feature Description:
            
            Why is this feature needed:
            
            Suggested Implementation:
            
            Additional Notes:
            """
            
            let mailto = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            if let url = URL(string: mailto) {
                NSWorkspace.shared.open(url)
            }
        }
        
        private func showDonationOptions() {
            let alert = NSAlert()
            alert.messageText = "Support the Developer"
            alert.informativeText = "If you find SYSM 1.0.1 helpful, consider supporting further development. You can send support via PayPal to nmano0006@gmail.com"
            alert.addButton(withTitle: "Copy PayPal Email")
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("nmano0006@gmail.com", forType: .string)
            }
        }
        
        private func copyDeveloperFullProfile() {
            let profile = """
            ====== SYSM Troubleshooter Developer Profile ======
            
            Developer: Navaratnam Manoranjan
            Email: nmano0006@gmail.com
            Role: Lead System Diagnostics Engineer
            Specialization: macOS System Diagnostics & Optimization
            Location: Colombo, Sri Lanka
            
            Expertise:
            • macOS Kernel Extensions & Drivers
            • OpenCore Configuration
            • Hackintosh Systems
            • System Recovery Tools
            • Performance Optimization
            
            Tools & Technologies:
            • Xcode, Swift, Objective-C
            • macOS APIs & Frameworks
            • Terminal & Shell Scripting
            • System Diagnostics
            
            Current Version: 1.0.1
            Last Updated: December 2024
            
            ===========================================
            """
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(profile, forType: .string)
            
            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    struct FeatureUpdateItem: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    
    struct DeveloperToolbarBadgeView: View {
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Developer:")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("N. Manoranjan")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                // Version update
                Text("v1.0.1")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(3)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
    
    struct StatusCard: View {
        enum Status {
            case good, warning, error
            
            var color: Color {
                switch self {
                case .good: return .green
                case .warning: return .orange
                case .error: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .good: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                }
            }
        }
        
        let title: String
        let status: Status
        let icon: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Private Methods
    
    private func fixIssue(_ issue: String) {
        isFixing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let index = issues.firstIndex(of: issue) {
                issues.remove(at: index)
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
            issues.removeAll()
            hasIssues = false
            isFixing = false
        }
    }
    
    private func runDiagnostic() {
        isFixing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Simulate finding new issues
            issues = ["Temporary files accumulation", "Login items optimization"]
            hasIssues = true
            isFixing = false
        }
    }
    
    private func sendEmailFeedback() {
        let email = "nmano0006@gmail.com"
        let subject = "SYSM v1.0.1 Troubleshooter Feedback"
        let body = """
        Hello Developer,
        
        Here's my feedback about the SYSM Troubleshooter (v1.0.1):
        
        What I liked:
        
        Suggestions for improvement:
        
        Issues encountered:
        
        System Information:
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        
        Best regards,
        
        """
        
        let mailto = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: mailto) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func copyContactInfo() {
        let contactInfo = """
        Navaratnam Manoranjan
        Lead System Diagnostics Engineer
        Email: nmano0006@gmail.com
        Specialization: macOS System Diagnostics & Optimization
        Tool: SYSM Troubleshooter v1.0.1
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contactInfo, forType: .string)
        
        // Provide haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    private func showVersionDetails() {
        let alert = NSAlert()
        alert.messageText = "SYSM v1.0.1 - What's New"
        alert.informativeText = """
        ✨ Version 1.0.1 Updates:
        
        • Enhanced drive detection algorithms
        • Improved diagnostic performance
        • Better error handling and user feedback
        • Memory optimization for larger systems
        • Bug fixes for mount/unmount operations
        • UI improvements for better usability
        • Enhanced security checks
        • Better compatibility with macOS Sonoma
        
        For full changelog, visit the GitHub repository.
        """
        alert.addButton(withTitle: "View GitHub")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/nmano0006/SYSM/releases/tag/v1.0.1") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

struct TroubleshooterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TroubleshooterView(hasIssues: .constant(true))
                .frame(width: 900, height: 700)
                .preferredColorScheme(.light)
                .previewDisplayName("With Issues - Light")
            
            TroubleshooterView(hasIssues: .constant(false))
                .frame(width: 900, height: 700)
                .preferredColorScheme(.dark)
                .previewDisplayName("No Issues - Dark")
        }
    }
}