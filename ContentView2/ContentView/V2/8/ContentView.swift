// MARK: - Security & Permissions

static func checkFullDiskAccess() -> Bool {
    print("🔐 Checking Full Disk Access permissions...")
    
    // Method 1: Try to access a protected directory
    let testPath = "/Library/Application Support"
    let testCommand = "ls '\(testPath)' 2>&1 | head -5"
    let result = runCommand(testCommand)
    
    // Check for permission denied errors
    if result.output.contains("Operation not permitted") || 
       result.output.contains("Permission denied") {
        print("❌ Full Disk Access NOT granted")
        print("💡 Error message: \(result.output)")
        return false
    }
    
    // Method 2: Try to read system logs
    let logTest = runCommand("ls /var/log/system.log 2>&1")
    if logTest.output.contains("Operation not permitted") || 
       logTest.output.contains("Permission denied") {
        print("❌ No access to system logs")
        return false
    }
    
    // Method 3: Try to read TCC database location (indirect test)
    let tccCheck = runCommand("ls '/Library/Application Support/com.apple.TCC/' 2>&1 | head -3")
    
    // Method 4: Try to list users directory
    let usersCheck = runCommand("ls /Users 2>&1")
    
    // If we can access /Library/Application Support without permission errors, 
    // and we can list /Users, we likely have Full Disk Access
    if !result.output.contains("No such file") && 
       !usersCheck.output.contains("Permission denied") {
        print("✅ Full Disk Access appears to be granted")
        return true
    }
    
    print("⚠️ Unable to determine Full Disk Access status")
    return false
}