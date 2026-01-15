// MARK: - Export Sheet View (FIXED)
struct ExportSheetView: View {
    let exportText: String
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false
    @State private var showSavePanel = false
    @State private var savePanelTarget: SaveTarget = .desktop
    @State private var savePanel: NSSavePanel?
    
    enum SaveTarget {
        case desktop
        case custom
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export System Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview:")
                    .font(.headline)
                    .padding(.horizontal)
                
                if exportText.isEmpty {
                    VStack {
                        Text("No data available")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(height: 200)
                } else {
                    ScrollView {
                        Text(exportText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            
            Divider()
            
            // Export buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Options:")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    ExportButton(
                        title: "Copy",
                        icon: "doc.on.doc",
                        color: .blue,
                        action: copyToClipboard,
                        isLoading: false
                    )
                    
                    ExportButton(
                        title: "Save to Desktop",
                        icon: "desktopcomputer",
                        color: .green,
                        action: { 
                            saveToDesktop()
                        },
                        isLoading: isSaving && savePanelTarget == .desktop
                    )
                    
                    ExportButton(
                        title: "Save As...",
                        icon: "folder",
                        color: .orange,
                        action: { 
                            saveAsCustom()
                        },
                        isLoading: isSaving && savePanelTarget == .custom
                    )
                    
                    ExportButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: .purple,
                        action: { 
                            sharingSystemInfo()
                        },
                        isLoading: false
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Spacer()
            
            // Status message
            if !saveAlertMessage.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        if saveAlertMessage.contains("✅") {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if saveAlertMessage.contains("❌") {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Text(saveAlertMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        
                        Spacer()
                        
                        Button("Clear") {
                            saveAlertMessage = ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
        }
        .frame(width: 800, height: 500)
        .onChange(of: showSavePanel) { newValue in
            if newValue {
                showSavePanelAction()
            }
        }
        .alert("Export Status", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { 
                saveAlertMessage = ""
            }
        } message: {
            Text(saveAlertMessage)
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if exportText.isEmpty {
            saveAlertMessage = "❌ No data available to copy"
            showSaveAlert = true
            return
        }
        
        let success = pasteboard.setString(exportText, forType: .string)
        
        if success {
            saveAlertMessage = "✅ System information copied to clipboard!"
        } else {
            saveAlertMessage = "❌ Failed to copy to clipboard"
        }
        
        showSaveAlert = true
        print("📋 Copied to clipboard: \(success)")
    }
    
    private func saveToDesktop() {
        guard !exportText.isEmpty else {
            saveAlertMessage = "❌ No data available to save"
            showSaveAlert = true
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "System_Info_\(dateString).txt"
        
        // Get desktop directory
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            saveAlertMessage = "❌ Cannot access Desktop directory"
            showSaveAlert = true
            return
        }
        
        let fileURL = desktopURL.appendingPathComponent(fileName)
        saveToURL(fileURL)
    }
    
    private func saveAsCustom() {
        guard !exportText.isEmpty else {
            saveAlertMessage = "❌ No data available to save"
            showSaveAlert = true
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save System Information"
        savePanel.message = "Choose where to save the system information report"
        savePanel.nameFieldLabel = "File name:"
        
        // Set default filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "System_Info_\(dateString).txt"
        
        // Set directory to Documents as default
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = documentsURL
        } else {
            savePanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }
        
        // Set allowed file types
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt", "text"]
        }
        
        // Set accessory view
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        let checkbox = NSButton(checkboxWithTitle: "Open after saving", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 0, width: 200, height: 32)
        accessoryView.addSubview(checkbox)
        savePanel.accessoryView = accessoryView
        
        // Show the panel
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                self.saveToURL(url)
                
                // Open file after saving if checkbox is checked
                if checkbox.state == .on {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                self.saveAlertMessage = "Save cancelled"
                self.showSaveAlert = true
            }
        }
    }
    
    private func saveToURL(_ url: URL) {
        print("💾 Attempting to save to: \(url.path)")
        
        isSaving = true
        
        do {
            // Check if file exists
            if FileManager.default.fileExists(atPath: url.path) {
                // Ask for confirmation to overwrite
                let alert = NSAlert()
                alert.messageText = "File Already Exists"
                alert.informativeText = "A file named \"\(url.lastPathComponent)\" already exists at this location. Do you want to replace it?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response != .alertFirstButtonReturn {
                    isSaving = false
                    saveAlertMessage = "Save cancelled"
                    showSaveAlert = true
                    return
                }
            }
            
            // Write the file
            try exportText.write(to: url, atomically: true, encoding: .utf8)
            
            // Verify the file was written
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            
            saveAlertMessage = "✅ Saved successfully!\nFile: \(url.lastPathComponent)\nSize: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))\nLocation: \(url.deletingLastPathComponent().path)"
            
            // Reveal in Finder
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            
        } catch {
            saveAlertMessage = "❌ Error saving file:\n\(error.localizedDescription)"
            print("❌ Save failed: \(error)")
        }
        
        isSaving = false
        showSaveAlert = true
    }
    
    private func sharingSystemInfo() {
        guard !exportText.isEmpty else {
            saveAlertMessage = "❌ No data available to share"
            showSaveAlert = true
            return
        }
        
        // Create a temporary file to share
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let tempFileURL = tempDir.appendingPathComponent("System_Info_\(dateString).txt")
        
        do {
            try exportText.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // Create sharing service
            let sharingServicePicker = NSSharingServicePicker(items: [tempFileURL])
            
            // Get the main window
            if let window = NSApplication.shared.windows.first {
                sharingServicePicker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
            }
            
            // Clean up temp file after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            
        } catch {
            saveAlertMessage = "❌ Failed to prepare file for sharing:\n\(error.localizedDescription)"
            showSaveAlert = true
        }
    }
    
    private func showSavePanelAction() {
        // This is a fallback method that can be called if needed
        saveAsCustom()
    }
}

// Button Component with loading state
struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let isLoading: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(color)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 100, height: 70)
            .background(color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help(title) // Tooltip
    }
}