// MARK: - AppleHDA Installation Tap
@MainActor
struct KextManagementView: View {
    @Binding var isInstallingKext: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var appleHDAStatus: String
    @Binding var appleHDAVersion: String?
    @Binding var appleALCStatus: String
    @Binding var appleALCVersion: String?
    @Binding var liluStatus: String
    @Binding var liluVersion: String?
    @Binding var efiPath: String?
    @Binding var kextSourcePath: String
    
    @State private var selectedKexts: Set<String> = []
    @State private var rebuildCacheProgress = 0.0
    @State private var isRebuildingCache = false
    @State private var showAudioKextsOnly = true
    
    // Complete list of kexts for Hackintosh
    let allKexts = [
        // Required for AppleHDA Audio
        ("Lilu", "1.6.8", "Kernel extension patcher - REQUIRED for audio", "https://github.com/acidanthera/Lilu", true),
        ("AppleALC", "1.8.7", "Audio codec support - REQUIRED for AppleHDA", "https://github.com/acidanthera/AppleALC", true),
        ("AppleHDA", "500.7.4", "Apple HD Audio driver", "Custom build", true),
        
        // Graphics
        ("WhateverGreen", "1.6.8", "Graphics patching and DRM fixes", "https://github.com/acidanthera/WhateverGreen", false),
        ("IntelGraphicsFixup", "1.3.1", "Intel GPU framebuffer patches", "https://github.com/lvs1974/IntelGraphicsFixup", false),
        
        // System
        ("VirtualSMC", "1.3.3", "SMC emulation for virtualization", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCProcessor", "1.3.3", "CPU monitoring for VirtualSMC", "https://github.com/acidanthera/VirtualSMC", false),
        ("SMCSuperIO", "1.3.3", "Super I/O monitoring", "https://github.com/acidanthera/VirtualSMC", false),
        
        // Network
        ("IntelMausi", "1.0.9", "Intel Ethernet controller support", "https://github.com/acidanthera/IntelMausi", false),
        ("AtherosE2200", "2.3.0", "Atheros Ethernet support", "https://github.com/Mieze/AtherosE2200Ethernet", false),
        ("RealtekRTL8111", "2.4.2", "Realtek Gigabit Ethernet", "https://github.com/Mieze/RTL8111_driver_for_OS_X", false),
        
        // Storage
        ("NVMeFix", "1.1.2", "NVMe SSD power management", "https://github.com/acidanthera/NVMeFix", false),
        ("SATA-unsupported", "1.0.0", "SATA controller support", "Various", false),
        
        // USB
        ("USBInjectAll", "0.8.3", "USB port mapping", "https://github.com/daliansky/OS-X-USB-Inject-All", false),
        ("XHCI-unsupported", "1.2.0", "XHCI USB controller support", "Various", false),
    ]
    
    var filteredKexts: [(String, String, String, String, Bool)] {
        if showAudioKextsOnly {
            return allKexts.filter { $0.4 } // Only audio-related
        }
        return allKexts
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // EFI Status
                if let efiPath = efiPath {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("EFI Ready for Installation")
                                .font(.headline)
                        }
                        Text("EFI Path: \(efiPath)/EFI/OC/Kexts/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("EFI Not Mounted")
                                .font(.headline)
                        }
                        Text("Mount EFI partition from System tab first")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Audio Kext Quick Install
                VStack(spacing: 12) {
                    Text("AppleHDA Audio Package")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 12) {
                        Button(action: installAudioPackage) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "speaker.wave.3.fill")
                                    Text("Install Audio Package")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                appleHDAStatus == "Installed" && appleALCStatus == "Installed" && liluStatus == "Installed" ?
                                Color.green.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isInstallingKext || efiPath == nil)
                        
                        Button(action: verifyAudioInstallation) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Verify Audio")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    if appleHDAStatus == "Installed" {
                        Text("✅ Audio kexts installed successfully!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                // Kext Source Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kext Source Selection")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Selection:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if kextSourcePath.isEmpty {
                                Text("No folder selected")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .italic()
                            } else {
                                Text(URL(fileURLWithPath: kextSourcePath).lastPathComponent)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(kextSourcePath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Browse for Folder") {
                                browseForKextFolder()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Browse for Kext File") {
                                browseForKextFile()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Text("Select a folder containing kexts OR select a specific .kext file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !kextSourcePath.isEmpty {
                        // Check if it's a folder or file
                        var isDirectory: ObjCBool = false
                        let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
                        
                        if exists {
                            HStack {
                                Image(systemName: isDirectory.boolValue ? "folder.fill" : "doc.fill")
                                    .foregroundColor(.blue)
                                Text(isDirectory.boolValue ? "Folder selected" : "Kext file selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: installSelectedKexts) {
                            HStack {
                                if isInstallingKext {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Installing...")
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Install Selected (\(selectedKexts.count))")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty ?
                                Color.blue.opacity(0.3) : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(selectedKexts.isEmpty || isInstallingKext || kextSourcePath.isEmpty)
                        
                        Button(action: uninstallKexts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Uninstall")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: rebuildCaches) {
                            HStack {
                                if isRebuildingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild Cache")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRebuildingCache)
                        
                        Button(action: {
                            showAudioKextsOnly.toggle()
                        }) {
                            HStack {
                                Image(systemName: showAudioKextsOnly ? "speaker.wave.3" : "square.grid.2x2")
                                Text(showAudioKextsOnly ? "Show All" : "Audio Only")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                if isRebuildingCache {
                    VStack(spacing: 8) {
                        ProgressView(value: rebuildCacheProgress, total: 100)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        Text("Rebuilding kernel cache... \(Int(rebuildCacheProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Kext Selection List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(showAudioKextsOnly ? "Audio Kexts" : "All Available Kexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedKexts = Set(filteredKexts.map { $0.0 })
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                        
                        Button("Clear All") {
                            selectedKexts.removeAll()
                        }
                        .font(.caption)
                        .disabled(isInstallingKext)
                    }
                    
                    ForEach(filteredKexts, id: \.0) { kext in
                        KextRow(
                            name: kext.0,
                            version: kext.1,
                            description: kext.2,
                            githubURL: kext.3,
                            isAudio: kext.4,
                            isSelected: selectedKexts.contains(kext.0),
                            isInstalling: isInstallingKext
                        ) {
                            toggleKextSelection(kext.0)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .onAppear {
                // Auto-select audio kexts
                if selectedKexts.isEmpty {
                    selectedKexts = Set(["Lilu", "AppleALC", "AppleHDA"])
                }
            }
        }
    }
    
    // MARK: - Kext Row Component
    struct KextRow: View {
        let name: String
        let version: String
        let description: String
        let githubURL: String
        let isAudio: Bool
        let isSelected: Bool
        let isInstalling: Bool
        let toggleAction: () -> Void
        
        var body: some View {
            HStack {
                Button(action: toggleAction) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? (isAudio ? .blue : .green) : .gray)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if isAudio {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Text(name)
                            .font(.body)
                            .fontWeight(isAudio ? .semibold : .regular)
                        Spacer()
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if githubURL != "Custom build" {
                    Button(action: {
                        if let url = URL(string: githubURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInstalling)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? (isAudio ? Color.blue.opacity(0.1) : Color.green.opacity(0.1)) : Color.clear)
            .cornerRadius(6)
        }
    }
    
    private func toggleKextSelection(_ kextName: String) {
        if selectedKexts.contains(kextName) {
            selectedKexts.remove(kextName)
        } else {
            selectedKexts.insert(kextName)
        }
    }
    
    private func browseForKextFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Kexts Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                kextSourcePath = url.path
                alertTitle = "Folder Selected"
                alertMessage = "Selected folder: \(url.lastPathComponent)"
                showAlert = true
            }
        }
    }
    
    private func browseForKextFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Kext File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        
        // IMPORTANT FIX: Allow all file types and manually check for .kext extension
        panel.allowedContentTypes = [UTType.item] // Allow all file types
        panel.allowsOtherFileTypes = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Check if the selected file has .kext extension
                if url.pathExtension.lowercased() == "kext" {
                    kextSourcePath = url.path
                    alertTitle = "Kext Selected"
                    alertMessage = "Selected kext file: \(url.lastPathComponent)"
                } else {
                    alertTitle = "Invalid File"
                    alertMessage = "Please select a .kext file. Selected file: \(url.lastPathComponent) has extension: \(url.pathExtension)"
                }
                showAlert = true
            }
        }
    }
    
    private func installAudioPackage() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select a folder containing kext files or a kext file first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing Audio Package..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directories
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            let _ = ShellHelper.runCommand("mkdir -p /System/Library/Extensions", needsSudo: true)
            
            // Check if source is a file or directory
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
            
            if !exists {
                DispatchQueue.main.async {
                    isInstallingKext = false
                    alertTitle = "Error"
                    alertMessage = "Selected path does not exist: \(kextSourcePath)"
                    showAlert = true
                }
                return
            }
            
            if isDirectory.boolValue {
                // Source is a directory - look for kexts
                messages.append("\nSearching for kexts in folder...")
                
                // Install Lilu.kext to EFI
                let liluSource = findKextInDirectory(name: "Lilu", directory: kextSourcePath)
                if let liluSource = liluSource {
                    messages.append("\n1. Installing Lilu.kext to EFI...")
                    let command = "cp -R \"\(liluSource)\" \"\(ocKextsPath)Lilu.kext\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    if result.success {
                        messages.append("✅ Lilu.kext installed to EFI")
                    } else {
                        messages.append("❌ Failed to install Lilu.kext: \(result.output)")
                        success = false
                    }
                } else {
                    messages.append("❌ Lilu.kext not found in: \(kextSourcePath)")
                    success = false
                }
                
                // Install AppleALC.kext to EFI
                let appleALCSource = findKextInDirectory(name: "AppleALC", directory: kextSourcePath)
                if let appleALCSource = appleALCSource {
                    messages.append("\n2. Installing AppleALC.kext to EFI...")
                    let command = "cp -R \"\(appleALCSource)\" \"\(ocKextsPath)AppleALC.kext\""
                    let result = ShellHelper.runCommand(command, needsSudo: true)
                    if result.success {
                        messages.append("✅ AppleALC.kext installed to EFI")
                    } else {
                        messages.append("❌ Failed to install AppleALC.kext: \(result.output)")
                        success = false
                    }
                } else {
                    messages.append("❌ AppleALC.kext not found in: \(kextSourcePath)")
                    success = false
                }
                
                // Install AppleHDA.kext to /System/Library/Extensions/
                let appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                if let appleHDASource = appleHDASource {
                    messages.append("\n3. Installing AppleHDA.kext to /System/Library/Extensions...")
                    // FIXED: Use the correct source path (the main kext bundle, not plugin)
                    let sourceKextPath = appleHDASource
                    let commands = [
                        "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                        "cp -R \"\(sourceKextPath)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                        "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                        "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                        "touch /System/Library/Extensions"
                    ]
                    
                    var appleHDASuccess = true
                    for cmd in commands {
                        let result = ShellHelper.runCommand(cmd, needsSudo: true)
                        if !result.success {
                            messages.append("❌ Failed: \(cmd)")
                            appleHDASuccess = false
                            break
                        }
                    }
                    
                    if appleHDASuccess {
                        messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                    } else {
                        success = false
                    }
                } else {
                    messages.append("❌ AppleHDA.kext not found in: \(kextSourcePath)")
                    success = false
                }
            } else {
                // Source is a file - check if it's a kext file
                if kextSourcePath.hasSuffix(".kext") {
                    let kextName = URL(fileURLWithPath: kextSourcePath).lastPathComponent.replacingOccurrences(of: ".kext", with: "")
                    messages.append("\nInstalling \(kextName).kext...")
                    
                    if kextName.lowercased() == "applehda" {
                        // Install AppleHDA to /System/Library/Extensions
                        messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(kextSourcePath)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                            "touch /System/Library/Extensions"
                        ]
                        
                        var appleHDASuccess = true
                        for cmd in commands {
                            let result = ShellHelper.runCommand(cmd, needsSudo: true)
                            if !result.success {
                                messages.append("❌ Failed: \(cmd)")
                                appleHDASuccess = false
                                break
                            }
                        }
                        
                        if appleHDASuccess {
                            messages.append("✅ AppleHDA.kext installed to /System/Library/Extensions")
                        } else {
                            success = false
                        }
                    } else {
                        // Install other kexts to EFI
                        messages.append("\nInstalling \(kextName).kext to EFI...")
                        let command = "cp -R \"\(kextSourcePath)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed to EFI")
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext: \(result.output)")
                            success = false
                        }
                    }
                } else {
                    messages.append("❌ Selected file is not a .kext file")
                    success = false
                }
            }
            
            // Rebuild kernel cache
            if success {
                messages.append("\n4. Rebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues: \(result.output)")
                }
            }
            
            // Update UI
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    // Check which kexts were installed
                    if isDirectory.boolValue {
                        liluStatus = "Installed"
                        liluVersion = "1.6.8"
                        appleALCStatus = "Installed"
                        appleALCVersion = "1.8.7"
                        appleHDAStatus = "Installed"
                        appleHDAVersion = "500.7.4"
                    } else if kextSourcePath.lowercased().contains("applehda") {
                        appleHDAStatus = "Installed"
                        appleHDAVersion = "500.7.4"
                    }
                    
                    alertTitle = "✅ Installation Complete"
                    messages.append("\n🎉 Installation complete! Please restart your system.")
                } else {
                    alertTitle = "⚠️ Installation Issues"
                    messages.append("\n❌ Some kexts may not have installed correctly.")
                }
                
                alertMessage = messages.joined(separator: "\n")
                showAlert = true
            }
        }
    }
    
    // FIXED: Improved findKextInDirectory function
    private func findKextInDirectory(name: String, directory: String) -> String? {
        let fileManager = FileManager.default
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: directory) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // First look for exact match of the kext bundle
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    // Check if it's a kext bundle with the exact name
                    if isDir.boolValue && item.lowercased() == "\(name.lowercased()).kext" {
                        return itemPath
                    }
                }
            }
            
            // If not found, look for partial matches (but only for kext bundles)
            for item in contents {
                let itemPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue && item.lowercased().contains(name.lowercased()) && item.hasSuffix(".kext") {
                        return itemPath
                    }
                }
            }
            
            // Check subdirectories (but avoid going into .kext bundles)
            for item in contents {
                let fullPath = "\(directory)/\(item)"
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    // Skip if it's a .kext bundle (we already checked those)
                    if !fullPath.hasSuffix(".kext") {
                        if let found = findKextInDirectory(name: name, directory: fullPath) {
                            return found
                        }
                    }
                }
            }
        } catch {
            print("Error searching for kext: \(error)")
        }
        
        return nil
    }
    
    private func verifyAudioInstallation() {
        var messages: [String] = ["Audio Installation Verification:"]
        
        // Check if kexts are loaded
        let liluLoaded = ShellHelper.checkKextLoaded("Lilu")
        let appleALCLoaded = ShellHelper.checkKextLoaded("AppleALC")
        let appleHDALoaded = ShellHelper.checkKextLoaded("AppleHDA")
        
        messages.append(liluLoaded ? "✅ Lilu.kext is loaded" : "❌ Lilu.kext is NOT loaded")
        messages.append(appleALCLoaded ? "✅ AppleALC.kext is loaded" : "❌ AppleALC.kext is NOT loaded")
        messages.append(appleHDALoaded ? "✅ AppleHDA.kext is loaded" : "❌ AppleHDA.kext is NOT loaded")
        
        // Check SIP
        let sipDisabled = ShellHelper.isSIPDisabled()
        messages.append(sipDisabled ? "✅ SIP is disabled" : "❌ SIP is enabled (required for AppleHDA)")
        
        // Check EFI
        if let efiPath = efiPath {
            messages.append("✅ EFI is mounted at: \(efiPath)")
            
            // Check if kexts exist in EFI
            let liluPath = "\(efiPath)/EFI/OC/Kexts/Lilu.kext"
            let appleALCPath = "\(efiPath)/EFI/OC/Kexts/AppleALC.kext"
            let appleHDAPath = "/System/Library/Extensions/AppleHDA.kext"
            
            let liluExists = FileManager.default.fileExists(atPath: liluPath)
            let appleALCExists = FileManager.default.fileExists(atPath: appleALCPath)
            let appleHDAExists = FileManager.default.fileExists(atPath: appleHDAPath)
            
            messages.append(liluExists ? "✅ Lilu.kext exists in EFI" : "❌ Lilu.kext missing from EFI")
            messages.append(appleALCExists ? "✅ AppleALC.kext exists in EFI" : "❌ AppleALC.kext missing from EFI")
            messages.append(appleHDAExists ? "✅ AppleHDA.kext exists in /S/L/E" : "❌ AppleHDA.kext missing from /S/L/E")
        } else {
            messages.append("❌ EFI is not mounted")
        }
        
        alertTitle = "Audio Verification"
        alertMessage = messages.joined(separator: "\n")
        showAlert = true
    }
    
    private func installSelectedKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        guard !kextSourcePath.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please select a folder containing kext files or a kext file first."
            showAlert = true
            return
        }
        
        isInstallingKext = true
        
        DispatchQueue.global(qos: .background).async {
            var messages: [String] = ["Installing selected kexts..."]
            var success = true
            
            let ocKextsPath = "\(efiPath)/EFI/OC/Kexts/"
            
            // Create directory
            let _ = ShellHelper.runCommand("mkdir -p \(ocKextsPath)", needsSudo: true)
            
            // Check if source is a file or directory
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: kextSourcePath, isDirectory: &isDirectory)
            
            if !exists {
                DispatchQueue.main.async {
                    isInstallingKext = false
                    alertTitle = "Error"
                    alertMessage = "Selected path does not exist: \(kextSourcePath)"
                    showAlert = true
                }
                return
            }
            
            for kextName in selectedKexts {
                if kextName == "AppleHDA" {
                    // Special handling for AppleHDA
                    messages.append("\nInstalling AppleHDA.kext to /System/Library/Extensions...")
                    
                    let appleHDASource: String?
                    if isDirectory.boolValue {
                        appleHDASource = findKextInDirectory(name: "AppleHDA", directory: kextSourcePath)
                    } else if kextSourcePath.lowercased().contains("applehda") {
                        appleHDASource = kextSourcePath
                    } else {
                        appleHDASource = nil
                    }
                    
                    if let appleHDASource = appleHDASource {
                        let commands = [
                            "rm -rf \"/System/Library/Extensions/AppleHDA.kext\"",
                            "cp -R \"\(appleHDASource)\" \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chown -R root:wheel \"/System/Library/Extensions/AppleHDA.kext\"",
                            "chmod -R 755 \"/System/Library/Extensions/AppleHDA.kext\"",
                            "touch /System/Library/Extensions"
                        ]
                        
                        var kextSuccess = true
                        for cmd in commands {
                            let result = ShellHelper.runCommand(cmd, needsSudo: true)
                            if !result.success {
                                messages.append("❌ Failed: \(cmd)")
                                kextSuccess = false
                                break
                            }
                        }
                        
                        if kextSuccess {
                            messages.append("✅ AppleHDA.kext installed")
                        } else {
                            success = false
                        }
                    } else {
                        messages.append("❌ AppleHDA.kext not found")
                        success = false
                    }
                } else {
                    // Other kexts go to EFI
                    messages.append("\nInstalling \(kextName).kext to EFI...")
                    
                    let kextSource: String?
                    if isDirectory.boolValue {
                        kextSource = findKextInDirectory(name: kextName, directory: kextSourcePath)
                    } else if kextSourcePath.lowercased().contains(kextName.lowercased()) {
                        kextSource = kextSourcePath
                    } else {
                        kextSource = nil
                    }
                    
                    if let kextSource = kextSource {
                        let command = "cp -R \"\(kextSource)\" \"\(ocKextsPath)\(kextName).kext\""
                        let result = ShellHelper.runCommand(command, needsSudo: true)
                        if result.success {
                            messages.append("✅ \(kextName).kext installed")
                        } else {
                            messages.append("❌ Failed to install \(kextName).kext")
                            success = false
                        }
                    } else {
                        messages.append("❌ \(kextName).kext not found")
                        success = false
                    }
                }
            }
            
            // Rebuild cache if AppleHDA was installed
            if selectedKexts.contains("AppleHDA") && success {
                messages.append("\nRebuilding kernel cache...")
                let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
                if result.success {
                    messages.append("✅ Kernel cache rebuilt")
                } else {
                    messages.append("⚠️ Kernel cache rebuild may have issues")
                }
            }
            
            DispatchQueue.main.async {
                isInstallingKext = false
                
                if success {
                    alertTitle = "Kexts Installed"
                    alertMessage = messages.joined(separator: "\n")
                } else {
                    alertTitle = "Installation Issues"
                    alertMessage = messages.joined(separator: "\n")
                }
                showAlert = true
            }
        }
    }
    
    private func uninstallKexts() {
        guard let efiPath = efiPath else {
            alertTitle = "Error"
            alertMessage = "EFI partition not mounted. Please mount it from the System tab first."
            showAlert = true
            return
        }
        
        alertTitle = "Uninstallation Instructions"
        alertMessage = """
        To uninstall kexts:
        
        1. EFI Kexts (Lilu, AppleALC, etc.):
           • Navigate to: \(efiPath)/EFI/OC/Kexts/
           • Delete the kext files you want to remove
           
        2. System Kexts (AppleHDA):
           • Open Terminal
           • Run: sudo rm -rf /System/Library/Extensions/AppleHDA.kext
           • Run: sudo kextcache -i /
           
        3. Update config.plist:
           • Remove kext entries from Kernel → Add
           • Save and restart
           
        WARNING: Removing AppleHDA will disable audio until reinstalled.
        """
        showAlert = true
    }
    
    private func rebuildCaches() {
        isRebuildingCache = true
        rebuildCacheProgress = 0
        
        DispatchQueue.global(qos: .background).async {
            let result = ShellHelper.runCommand("kextcache -i /", needsSudo: true)
            
            // Simulate progress
            for i in 0...100 {
                DispatchQueue.main.async {
                    rebuildCacheProgress = Double(i)
                }
                usleep(50000)
            }
            
            DispatchQueue.main.async {
                isRebuildingCache = false
                
                if result.success {
                    alertTitle = "Cache Rebuilt"
                    alertMessage = "Kernel cache rebuilt successfully!\nRestart your system for changes to take effect."
                } else {
                    alertTitle = "Cache Rebuild Failed"
                    alertMessage = "Failed to rebuild cache:\n\(result.output)"
                }
                showAlert = true
                rebuildCacheProgress = 0
            }
        }
    }
}