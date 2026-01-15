private func getOutputDirectory() -> String {
    if !outputPath.isEmpty {
        return outputPath
    }
    
    // CHANGE HERE: Use Desktop directory instead of Downloads
    let desktopDir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    let ssdtDir = desktopDir?.appendingPathComponent("Generated_SSDTs")
    
    // Create directory if it doesn't exist
    if let ssdtDir = ssdtDir {
        try? FileManager.default.createDirectory(at: ssdtDir, withIntermediateDirectories: true)
        return ssdtDir.path
    }
    
    // Fallback: If we can't get Desktop directory, use Desktop folder in home directory
    return NSHomeDirectory() + "/Desktop/Generated_SSDTs"
}