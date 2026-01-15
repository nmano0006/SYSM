import SwiftUI
import AppKit

struct ExportSuccessView: View {
    @Binding var isPresented: Bool
    let fileURL: URL?
    let onDismiss: () -> Void
    
    @State private var showingFinderAlert = false
    @State private var finderAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 25) {
            // Header with icon
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: isPresented)
                
                Text("Export Successful!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("System information has been exported successfully")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // File information section
            VStack(spacing: 15) {
                Text("File Details:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let url = fileURL {
                    VStack(alignment: .leading, spacing: 10) {
                        // File name
                        HStack(alignment: .top) {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("File Name:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(url.lastPathComponent)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        
                        // File path
                        HStack(alignment: .top) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }
                        }
                        
                        // File size
                        HStack(alignment: .top) {
                            Image(systemName: "number")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("File Size:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(getFileSize(url: url))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    Text("No file information available")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                }
            }
            
            // Action buttons
            HStack(spacing: 15) {
                if fileURL != nil {
                    Button(action: {
                        openInFinder()
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Show in Finder")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: {
                        copyToClipboard()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Path")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.top, 10)
            
            // Main action button
            Button(action: {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 10)
            
            // Information footer
            if let url = fileURL {
                VStack(spacing: 5) {
                    Text("You can also find this file at:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(url.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        .onTapGesture {
                            copyToClipboard()
                        }
                        .help("Click to copy full path")
                }
                .padding(.top, 5)
            }
        }
        .padding(30)
        .frame(width: 500, height: 550)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(20)
        .shadow(radius: 20)
        .overlay(
            // Close button
            Button(action: {
                isPresented = false
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
            .padding(10),
            alignment: .topTrailing
        )
        .alert("Finder Error", isPresented: $showingFinderAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(finderAlertMessage)
        }
        .onAppear {
            // Log export success
            print("✅ ExportSuccessView appeared for file: \(fileURL?.path ?? "unknown")")
        }
    }
    
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                let bytes = fileSize.int64Value
                
                if bytes < 1024 {
                    return "\(bytes) bytes"
                } else if bytes < 1048576 {
                    let kb = Double(bytes) / 1024.0
                    return String(format: "%.1f KB", kb)
                } else {
                    let mb = Double(bytes) / 1048576.0
                    return String(format: "%.2f MB", mb)
                }
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return "Unknown size"
    }
    
    private func openInFinder() {
        guard let url = fileURL else { return }
        
        print("🔍 Opening in Finder: \(url.path)")
        
        // First check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            finderAlertMessage = "File not found at:\n\(url.path)"
            showingFinderAlert = true
            return
        }
        
        // Try to open in Finder
        DispatchQueue.global(qos: .userInitiated).async {
            let success = NSWorkspace.shared.activateFileViewerSelecting([url])
            
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully opened in Finder")
                    
                    // Show a brief success feedback
                    let feedbackGenerator = NSHapticFeedbackManager.defaultPerformer
                    feedbackGenerator.perform(.generic, performanceTime: .default)
                } else {
                    print("❌ Failed to open in Finder")
                    finderAlertMessage = "Could not open Finder. The file was saved at:\n\(url.path)"
                    showingFinderAlert = true
                }
            }
        }
    }
    
    private func copyToClipboard() {
        guard let url = fileURL else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Try to copy both the path and the file
        let fileURLs = [url] as NSArray
        
        if pasteboard.writeObjects(fileURLs) {
            // Also copy the path as text
            pasteboard.setString(url.path, forType: .string)
            
            print("📋 Copied to clipboard: \(url.path)")
            
            // Provide haptic feedback
            let feedbackGenerator = NSHapticFeedbackManager.defaultPerformer
            feedbackGenerator.perform(.generic, performanceTime: .default)
            
            // Show temporary success indicator
            showCopySuccess()
        } else {
            print("❌ Failed to copy to clipboard")
        }
    }
    
    private func showCopySuccess() {
        // This would be implemented as a toast or temporary overlay
        // For now, we'll just log it
        print("📋 Path copied to clipboard")
        
        // You could add a toast notification here
        let notification = NSUserNotification()
        notification.title = "Path Copied"
        notification.informativeText = "File path copied to clipboard"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// Preview for development
struct ExportSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ExportSuccessView(
                isPresented: .constant(true),
                fileURL: URL(fileURLWithPath: "/Users/username/Desktop/system-info-2024-01-10_12-30-45.txt"),
                onDismiss: { print("Dismissed") }
            )
            .frame(width: 500, height: 550)
            .previewDisplayName("Light Mode")
            
            ExportSuccessView(
                isPresented: .constant(true),
                fileURL: URL(fileURLWithPath: "/Users/username/Desktop/system-info-2024-01-10_12-30-45.txt"),
                onDismiss: { print("Dismissed") }
            )
            .frame(width: 500, height: 550)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            ExportSuccessView(
                isPresented: .constant(true),
                fileURL: nil,
                onDismiss: { print("Dismissed") }
            )
            .frame(width: 500, height: 550)
            .previewDisplayName("No File URL")
        }
    }
}

// Helper extension for haptic feedback
extension NSHapticFeedbackManager {
    static var defaultPerformer: NSHapticFeedbackPerformer {
        return NSHapticFeedbackManager.defaultPerformer(for: .generic)
    }
}