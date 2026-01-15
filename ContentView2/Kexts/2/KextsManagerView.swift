import SwiftUI

struct KextsManagerView: View {
    @State private var kexts: [KextInfo] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedKext: KextInfo?
    @State private var showInfoAlert = false
    @State private var alertMessage = ""
    @State private var operationInProgress = false
    
    var filteredKexts: [KextInfo] {
        if searchText.isEmpty {
            return kexts
        } else {
            return kexts.filter { kext in
                kext.name.localizedCaseInsensitiveContains(searchText) ||
                kext.bundleID.localizedCaseInsensitiveContains(searchText) ||
                kext.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kernel Extensions")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: refreshKexts) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || operationInProgress)
            }
            .padding()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search kexts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
                Text("Loading kernel extensions...")
                    .foregroundColor(.secondary)
            } else if kexts.isEmpty {
                EmptyStateView
            } else {
                KextsListView
            }
            
            Spacer()
            
            // Quick Actions
            QuickActionsView
        }
        .onAppear {
            refreshKexts()
        }
        .alert("Kext Operation", isPresented: $showInfoAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var EmptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Kernel Extensions Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Connect to the system kernel or check permissions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                refreshKexts()
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var KextsListView: some View {
        // FIXED: Remove selection parameter or use a simple List
        List {
            ForEach(filteredKexts) { kext in
                KextRow(kext: kext)
                    .contextMenu {
                        Button(action: { loadKext(kext) }) {
                            Label("Load Kext", systemImage: "play.fill")
                        }
                        .disabled(kext.isLoaded || operationInProgress)
                        
                        Button(action: { unloadKext(kext) }) {
                            Label("Unload Kext", systemImage: "stop.fill")
                        }
                        .disabled(!kext.isLoaded || operationInProgress)
                        
                        Divider()
                        
                        Button(action: { showKextInfo(kext) }) {
                            Label("Show Info", systemImage: "info.circle")
                        }
                    }
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    private var QuickActionsView: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("Load All") {
                loadAllKexts()
            }
            .buttonStyle(.bordered)
            .disabled(filteredKexts.filter { !$0.isLoaded }.isEmpty || operationInProgress)
            
            Button("Unload All") {
                unloadAllKexts()
            }
            .buttonStyle(.bordered)
            .disabled(filteredKexts.filter { $0.isLoaded }.isEmpty || operationInProgress)
            
            Button("System Report") {
                generateKextReport()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private func KextRow(kext: KextInfo) -> some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(kext.isLoaded ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kext.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(kext.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(kext.version)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(kext.isLoaded ? "Loaded" : "Not Loaded")
                    .font(.caption2)
                    .foregroundColor(kext.isLoaded ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(kext.isLoaded ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func refreshKexts() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Use static ShellHelper methods instead of shared instance
            var loadedKexts: [KextInfo] = []
            
            // Get loaded kexts
            let loadedResult = ShellHelper.runCommand("kextstat | grep -v com.apple")
            let loadedLines = loadedResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in loadedLines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 7 {
                    let index = components[0]
                    let refs = components[1]
                    let address = components[2]
                    let size = components[3]
                    let wiredSize = components[4]
                    let name = components[5]
                    let version = components[6]
                    
                    let kext = KextInfo(
                        name: name,
                        bundleID: name,
                        version: version,
                        path: "Loaded in memory",
                        isLoaded: true,
                        index: index,
                        references: refs,
                        address: address,
                        size: size,
                        wiredSize: wiredSize
                    )
                    loadedKexts.append(kext)
                }
            }
            
            // Get kexts from /Library/Extensions and /System/Library/Extensions
            let extensionsResult = ShellHelper.runCommand("""
            find /Library/Extensions /System/Library/Extensions -name "*.kext" 2>/dev/null | head -50
            """)
            
            let kextPaths = extensionsResult.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for kextPath in kextPaths {
                // Extract kext info
                let name = (kextPath as NSString).lastPathComponent.replacingOccurrences(of: ".kext", with: "")
                
                // Check if already in loaded kexts
                if !loadedKexts.contains(where: { $0.name == name }) {
                    // Get bundle identifier
                    let infoPlistPath = "\(kextPath)/Contents/Info.plist"
                    let bundleIDResult = ShellHelper.runCommand("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"\(infoPlistPath)\" 2>/dev/null || echo 'Unknown'")
                    let bundleID = bundleIDResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Get version
                    let versionResult = ShellHelper.runCommand("/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \"\(infoPlistPath)\" 2>/dev/null || echo 'Unknown'")
                    let version = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let kext = KextInfo(
                        name: name,
                        bundleID: bundleID,
                        version: version,
                        path: kextPath,
                        isLoaded: false,
                        index: "",
                        references: "",
                        address: "",
                        size: "",
                        wiredSize: ""
                    )
                    loadedKexts.append(kext)
                }
            }
            
            DispatchQueue.main.async {
                self.kexts = loadedKexts.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.isLoading = false
            }
        }
    }
    
    private func loadKext(_ kext: KextInfo) {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: ShellHelper is now static
            
            if kext.path.isEmpty || kext.path == "Loaded in memory" {
                DispatchQueue.main.async {
                    alertMessage = "Cannot load kext: No path available"
                    showInfoAlert = true
                    operationInProgress = false
                }
                return
            }
            
            // NOTE: The runCommand method signature changed - needsSudo parameter is no longer available
            // You'll need to modify ShellHelper.runCommand or handle sudo differently
            let result = ShellHelper.runCommand("sudo kextload \"\(kext.path)\"")
            
            DispatchQueue.main.async {
                if result.success {
                    alertMessage = "Successfully loaded \(kext.name)"
                } else {
                    alertMessage = "Failed to load \(kext.name): \(result.output)"
                }
                showInfoAlert = true
                operationInProgress = false
                refreshKexts()
            }
        }
    }
    
    private func unloadKext(_ kext: KextInfo) {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Use static ShellHelper
            let result = ShellHelper.runCommand("sudo kextunload -b \(kext.bundleID)")
            
            DispatchQueue.main.async {
                if result.success {
                    alertMessage = "Successfully unloaded \(kext.name)"
                } else {
                    alertMessage = "Failed to unload \(kext.name): \(result.output)"
                }
                showInfoAlert = true
                operationInProgress = false
                refreshKexts()
            }
        }
    }
    
    private func loadAllKexts() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Use static ShellHelper
            var successCount = 0
            var failedCount = 0
            
            let kextsToLoad = self.filteredKexts.filter { !$0.isLoaded && !$0.path.isEmpty && $0.path != "Loaded in memory" }
            
            for kext in kextsToLoad {
                let result = ShellHelper.runCommand("sudo kextload \"\(kext.path)\"")
                if result.success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            DispatchQueue.main.async {
                if successCount > 0 && failedCount == 0 {
                    alertMessage = "Successfully loaded \(successCount) kext(s)"
                } else if successCount > 0 && failedCount > 0 {
                    alertMessage = "Loaded \(successCount) kext(s), failed \(failedCount)"
                } else {
                    alertMessage = "Failed to load any kexts"
                }
                showInfoAlert = true
                operationInProgress = false
                refreshKexts()
            }
        }
    }
    
    private func unloadAllKexts() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Use static ShellHelper
            var successCount = 0
            var failedCount = 0
            
            let kextsToUnload = self.filteredKexts.filter { $0.isLoaded }
            
            for kext in kextsToUnload {
                let result = ShellHelper.runCommand("sudo kextunload -b \(kext.bundleID)")
                if result.success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            DispatchQueue.main.async {
                if successCount > 0 && failedCount == 0 {
                    alertMessage = "Successfully unloaded \(successCount) kext(s)"
                } else if successCount > 0 && failedCount > 0 {
                    alertMessage = "Unloaded \(successCount) kext(s), failed \(failedCount)"
                } else {
                    alertMessage = "Failed to unload any kexts"
                }
                showInfoAlert = true
                operationInProgress = false
                refreshKexts()
            }
        }
    }
    
    private func showKextInfo(_ kext: KextInfo) {
        var infoText = "Name: \(kext.name)\n"
        infoText += "Bundle ID: \(kext.bundleID)\n"
        infoText += "Version: \(kext.version)\n"
        infoText += "Status: \(kext.isLoaded ? "Loaded" : "Not Loaded")\n"
        
        if kext.isLoaded {
            infoText += "\nLoaded Details:\n"
            infoText += "Index: \(kext.index)\n"
            infoText += "References: \(kext.references)\n"
            infoText += "Address: \(kext.address)\n"
            infoText += "Size: \(kext.size)\n"
            infoText += "Wired Size: \(kext.wiredSize)\n"
        }
        
        if !kext.path.isEmpty && kext.path != "Loaded in memory" {
            infoText += "\nPath: \(kext.path)\n"
        }
        
        alertMessage = infoText
        showInfoAlert = true
    }
    
    private func generateKextReport() {
        operationInProgress = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED: Use static ShellHelper
            
            var report = "=== Kext System Report ===\n\n"
            report += "Generated: \(Date())\n"
            report += "Total Kexts Found: \(self.kexts.count)\n"
            report += "Loaded Kexts: \(self.kexts.filter { $0.isLoaded }.count)\n"
            report += "Not Loaded: \(self.kexts.filter { !$0.isLoaded }.count)\n\n"
            
            report += "=== Loaded Kexts ===\n"
            for kext in self.kexts.filter({ $0.isLoaded }) {
                report += "\n• \(kext.name) (\(kext.bundleID))\n"
                report += "  Version: \(kext.version)\n"
                report += "  Index: \(kext.index), Refs: \(kext.references)\n"
                report += "  Address: \(kext.address), Size: \(kext.size)\n"
            }
            
            report += "\n\n=== Available Kexts (Not Loaded) ===\n"
            for kext in self.kexts.filter({ !$0.isLoaded }) {
                report += "\n• \(kext.name) (\(kext.bundleID))\n"
                report += "  Version: \(kext.version)\n"
                report += "  Path: \(kext.path)\n"
            }
            
            // Save to file
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("kext_report_\(Int(Date().timeIntervalSince1970)).txt")
            
            do {
                try report.write(to: fileURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(fileURL)
                    operationInProgress = false
                }
            } catch {
                DispatchQueue.main.async {
                    alertMessage = "Failed to save report: \(error.localizedDescription)"
                    showInfoAlert = true
                    operationInProgress = false
                }
            }
        }
    }
}

struct KextInfo: Identifiable, Hashable {  // ADD Hashable conformance
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let path: String
    let isLoaded: Bool
    let index: String
    let references: String
    let address: String
    let size: String
    let wiredSize: String
    
    // Add Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(bundleID)
    }
    
    // Add Equatable implementation (already required by Identifiable)
    static func == (lhs: KextInfo, rhs: KextInfo) -> Bool {
        return lhs.id == rhs.id
    }
}