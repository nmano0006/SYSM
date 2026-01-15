static func mountFromUSBBoot(partition: String) -> (output: String, success: Bool) {
    print("=== Attempting to mount from USB boot: \(partition) ===")
    
    // Try multiple methods to mount from USB boot
    
    // Method 1: Try without sudo first (might work on some USB configurations)
    let result1 = runCommand("diskutil mount \(partition)")
    if result1.success {
        print("✅ Mounted \(partition) without sudo")
        return result1
    }
    
    // Method 2: Try with direct diskutil mount
    let result2 = runCommand("/usr/sbin/diskutil mount \(partition)")
    if result2.success {
        print("✅ Mounted \(partition) with direct diskutil")
        return result2
    }
    
    // Method 3: Try mounting as read-only first
    let result3 = runCommand("diskutil mount readonly \(partition)")
    if result3.success {
        print("✅ Mounted \(partition) as read-only")
        
        // Try to remount as read-write
        let _ = runCommand("diskutil mount \(partition)")
        return result3
    }
    
    // Method 4: Last resort - use hdiutil
    let result4 = runCommand("hdiutil attach -nomount \(partition)")
    if result4.success && !result4.output.isEmpty {
        let device = result4.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let mountResult = runCommand("mkdir -p /Volumes/EFI_USB && mount -t msdos \(device) /Volumes/EFI_USB")
        
        if mountResult.success {
            print("✅ Mounted \(partition) using hdiutil at /Volumes/EFI_USB")
            return ("Mounted at /Volumes/EFI_USB", true)
        }
    }
    
    // If all methods fail, return error
    let errorMessage = """
    ❌ Failed to mount \(partition) from USB boot.
    
    Possible solutions:
    1. Open Terminal and run: sudo diskutil mount \(partition)
    2. Check Disk Utility for the EFI partition
    3. Reboot and try again
    4. The EFI partition may already be in use
    
    Last error: \(result1.output)
    """
    return (errorMessage, false)
}