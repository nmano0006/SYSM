import SwiftUI

struct TroubleshooterView: View {
    @Binding var hasIssues: Bool
    @State private var issues = ["Drive fragmentation detected", "Outdated kexts found", "Audio configuration needed"]
    @State private var isFixing = false
    
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
            }
            .padding()
        }
    }
    
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

struct TroubleshooterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TroubleshooterView(hasIssues: .constant(true))
                .frame(width: 900, height: 600)
                .preferredColorScheme(.light)
                .previewDisplayName("With Issues - Light")
            
            TroubleshooterView(hasIssues: .constant(false))
                .frame(width: 900, height: 600)
                .preferredColorScheme(.dark)
                .previewDisplayName("No Issues - Dark")
        }
    }
}